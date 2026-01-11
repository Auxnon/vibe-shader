// Raymarched Beveled Tetrahedron with Refraction
// ShaderToy compatible - paste this into shadertoy.com

#define MAX_STEPS 100
#define MAX_DIST 100.0
#define SURF_DIST 0.001
#define PI 3.14159265359

// Rotation matrix
mat2 rot2D(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

// Tetrahedron SDF
float sdTetrahedron(vec3 p, float r) {
    float md = max(max(-p.x - p.y - p.z, p.x + p.y - p.z),
                   max(-p.x + p.y + p.z, p.x - p.y + p.z));
    return (md - r) / sqrt(3.0);
}

// Beveled Tetrahedron - combine tetrahedron with smooth rounding
float sdBeveledTetrahedron(vec3 p, float size, float bevel) {
    float tet = sdTetrahedron(p, size);
    return tet - bevel;
}

// Plane SDF
float sdPlane(vec3 p, vec3 n, float h) {
    return dot(p, n) + h;
}

// Scene SDF
float GetDist(vec3 p) {
    // Beveled tetrahedron positioned above the plane
    vec3 tetPos = p - vec3(0.0, 0.8, 0.0);
    
    // Rotate the tetrahedron
    tetPos.xz *= rot2D(iTime * 0.3);
    tetPos.yz *= rot2D(iTime * 0.2);
    
    float tetrahedron = sdBeveledTetrahedron(tetPos, 0.5, 0.15);
    
    // Flat plane underneath
    float plane = sdPlane(p, vec3(0.0, 1.0, 0.0), 0.5);
    
    return min(tetrahedron, plane);
}

// Get the distance to the tetrahedron only (for refraction)
float GetTetrahedronDist(vec3 p) {
    vec3 tetPos = p - vec3(0.0, 0.8, 0.0);
    tetPos.xz *= rot2D(iTime * 0.3);
    tetPos.yz *= rot2D(iTime * 0.2);
    return sdBeveledTetrahedron(tetPos, 0.5, 0.15);
}

// Raymarching function
float RayMarch(vec3 ro, vec3 rd, float maxDist) {
    float dO = 0.0;
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        float dS = GetDist(p);
        dO += dS;
        if(dO > maxDist || abs(dS) < SURF_DIST) break;
    }
    return dO;
}

// Calculate normal
vec3 GetNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    vec3 n = vec3(
        GetDist(p + e.xyy) - GetDist(p - e.xyy),
        GetDist(p + e.yxy) - GetDist(p - e.yxy),
        GetDist(p + e.yyx) - GetDist(p - e.yyx)
    );
    return normalize(n);
}

// Calculate lighting
float GetLight(vec3 p, vec3 lightPos) {
    vec3 l = normalize(lightPos - p);
    vec3 n = GetNormal(p);
    
    float dif = clamp(dot(n, l), 0.0, 1.0);
    
    // Soft shadows
    float d = RayMarch(p + n * SURF_DIST * 2.0, l, length(lightPos - p));
    if(d < length(lightPos - p)) dif *= 0.3;
    
    return dif;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    vec3 col = vec3(0.0);
    
    // Camera setup
    vec3 ro = vec3(0.0, 1.0, -3.0);
    vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));
    
    // Raymarch
    float d = RayMarch(ro, rd, MAX_DIST);
    
    if(d < MAX_DIST) {
        vec3 p = ro + rd * d;
        vec3 n = GetNormal(p);
        
        // Check if we hit the tetrahedron or plane
        float tetDist = GetTetrahedronDist(p);
        
        if(tetDist < SURF_DIST * 2.0) {
            // Tetrahedron - transparent glass with refraction
            vec3 lightPos = vec3(2.0, 3.0, -2.0);
            
            // Fresnel effect for reflectivity
            float fresnel = pow(1.0 - abs(dot(rd, n)), 3.0);
            
            // Calculate refracted rays with chromatic aberration
            float ior = 1.5;
            vec3 refractRayR = refract(rd, n, 1.0 / (ior + 0.05));
            vec3 refractRayG = refract(rd, n, 1.0 / ior);
            vec3 refractRayB = refract(rd, n, 1.0 / (ior - 0.05));
            
            // March through the tetrahedron for each color channel
            vec3 refractedColor = vec3(0.0);
            
            for(int channel = 0; channel < 3; channel++) {
                vec3 refRd = channel == 0 ? refractRayR : (channel == 1 ? refractRayG : refractRayB);
                
                // Start inside the tetrahedron
                vec3 refRo = p + refRd * SURF_DIST * 3.0;
                
                // March to find exit point
                float d2 = 0.0;
                vec3 p2 = refRo;
                for(int j = 0; j < 50; j++) {
                    p2 = refRo + refRd * d2;
                    float dist = GetTetrahedronDist(p2);
                    if(dist > SURF_DIST) break; // Exited the tetrahedron
                    d2 += 0.02;
                    if(d2 > 3.0) break;
                }
                
                // Refract again when exiting
                vec3 n2 = GetNormal(p2);
                float iorExit = channel == 0 ? (ior + 0.05) : (channel == 1 ? ior : (ior - 0.05));
                vec3 exitRd = refract(refRd, -n2, iorExit);
                
                // See what the exiting ray hits
                float exitD = RayMarch(p2 + exitRd * SURF_DIST * 3.0, exitRd, MAX_DIST);
                
                if(exitD < MAX_DIST) {
                    vec3 exitP = p2 + exitRd * exitD;
                    float exitTetDist = GetTetrahedronDist(exitP);
                    
                    if(exitTetDist > SURF_DIST * 2.0) {
                        // Hit the plane - create rainbow effect
                        vec2 planeUV = exitP.xz;
                        float intensity = 0.7 + 0.3 * sin(planeUV.x * 2.0 + planeUV.y * 2.0);
                        refractedColor[channel] = intensity;
                    } else {
                        // Hit background
                        refractedColor[channel] = 0.1;
                    }
                } else {
                    // Hit nothing - use background
                    refractedColor[channel] = 0.05;
                }
            }
            
            // Reflection component
            vec3 reflectRd = reflect(rd, n);
            float reflectD = RayMarch(p + n * SURF_DIST * 2.0, reflectRd, MAX_DIST);
            vec3 reflectCol = vec3(0.02, 0.02, 0.05);
            if(reflectD < MAX_DIST) {
                vec3 reflectP = p + reflectRd * reflectD;
                float reflectLight = GetLight(reflectP, lightPos);
                reflectCol = vec3(0.15, 0.25, 0.35) * reflectLight;
            }
            
            // Mix refraction and reflection based on fresnel
            col = mix(refractedColor, reflectCol, fresnel * 0.4);
            
            // Add glass tint
            col *= vec3(0.95, 0.97, 1.0);
            
            // Add edge highlights for glass effect
            float edge = smoothstep(0.0, 1.0, fresnel);
            col += vec3(0.3, 0.4, 0.6) * edge * 0.2;
            
        } else {
            // Plane
            vec3 lightPos = vec3(2.0, 3.0, -2.0);
            float dif = GetLight(p, lightPos);
            
            // Base plane color with checkerboard
            float checker = mod(floor(p.x * 2.0) + floor(p.z * 2.0), 2.0);
            vec3 planeColor = mix(vec3(0.05, 0.05, 0.08), vec3(0.08, 0.08, 0.12), checker);
            
            // Add caustics from refraction
            vec3 causticColor = vec3(0.0);
            
            // Sample rays from tetrahedron to see if they hit this point
            vec3 tetCenter = vec3(0.0, 0.8, 0.0);
            vec3 toTet = normalize(tetCenter - p);
            float distToTet = length(tetCenter - p);
            
            if(distToTet < 2.0) {
                // Add rainbow caustic pattern
                float caustic = 0.0;
                caustic += sin(p.x * 8.0 + p.z * 6.0) * 0.5 + 0.5;
                caustic *= exp(-distToTet * 0.5);
                
                causticColor = vec3(
                    sin(p.x * 10.0) * 0.5 + 0.5,
                    sin(p.x * 10.0 + 2.0) * 0.5 + 0.5,
                    sin(p.x * 10.0 + 4.0) * 0.5 + 0.5
                ) * caustic * 0.3;
            }
            
            col = planeColor * (dif * 0.5 + 0.5) + causticColor;
        }
    } else {
        // Background gradient
        col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), uv.y * 0.5 + 0.5);
    }
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    fragColor = vec4(col, 1.0);
}
