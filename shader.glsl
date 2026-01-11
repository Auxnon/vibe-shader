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
    
    float tetrahedron = sdBeveledTetrahedron(tetPos, 0.5, 0.08);
    
    // Flat plane underneath
    float plane = sdPlane(p, vec3(0.0, 1.0, 0.0), 0.5);
    
    return min(tetrahedron, plane);
}

// Get the distance to the tetrahedron only (for refraction)
float GetTetrahedronDist(vec3 p) {
    vec3 tetPos = p - vec3(0.0, 0.8, 0.0);
    tetPos.xz *= rot2D(iTime * 0.3);
    tetPos.yz *= rot2D(iTime * 0.2);
    return sdBeveledTetrahedron(tetPos, 0.5, 0.08);
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

// Refraction ray direction
vec3 refract2(vec3 I, vec3 N, float eta) {
    float k = 1.0 - eta * eta * (1.0 - dot(N, I) * dot(N, I));
    if (k < 0.0) {
        return reflect(I, N);
    } else {
        return eta * I - (eta * dot(N, I) + sqrt(k)) * N;
    }
}

// Get color with chromatic aberration for prism effect
vec3 getRefractionColor(vec3 ro, vec3 rd, float ior) {
    vec3 col = vec3(0.0);
    
    // March to find the tetrahedron
    float d = 0.0;
    vec3 p;
    for(int i = 0; i < MAX_STEPS; i++) {
        p = ro + rd * d;
        float dist = GetTetrahedronDist(p);
        d += dist;
        if(d > MAX_DIST || abs(dist) < SURF_DIST) break;
    }
    
    if(d < MAX_DIST) {
        // We hit the tetrahedron
        vec3 n = GetNormal(p);
        
        // Chromatic aberration - different IOR for RGB channels
        vec3 rdR = refract2(rd, n, 1.0 / (ior + 0.02));
        vec3 rdG = refract2(rd, n, 1.0 / ior);
        vec3 rdB = refract2(rd, n, 1.0 / (ior - 0.02));
        
        // March refracted rays through the tetrahedron
        vec3 colors[3];
        vec3 refractedRays[3];
        refractedRays[0] = rdR;
        refractedRays[1] = rdG;
        refractedRays[2] = rdB;
        
        for(int channel = 0; channel < 3; channel++) {
            vec3 refRd = refractedRays[channel];
            vec3 refRo = p + refRd * SURF_DIST * 2.0;
            
            // March inside the tetrahedron
            float d2 = 0.0;
            vec3 p2;
            for(int j = 0; j < MAX_STEPS; j++) {
                p2 = refRo + refRd * d2;
                float dist = -GetTetrahedronDist(p2); // Negative for inside
                d2 += abs(dist);
                if(d2 > 5.0 || abs(dist) < SURF_DIST) break;
            }
            
            // Exit the tetrahedron
            vec3 n2 = -GetNormal(p2);
            float iorExit = channel == 0 ? (ior + 0.02) : (channel == 1 ? ior : (ior - 0.02));
            vec3 exitRd = refract2(refRd, n2, iorExit);
            
            // Check what the exiting ray hits on the plane
            vec3 exitRo = p2 + exitRd * SURF_DIST * 2.0;
            float planeT = -(exitRo.y + 0.5) / exitRd.y;
            
            if(planeT > 0.0) {
                vec3 planeHit = exitRo + exitRd * planeT;
                
                // Create colorful pattern on plane based on position
                float pattern = sin(planeHit.x * 3.0) * sin(planeHit.z * 3.0) * 0.5 + 0.5;
                colors[channel] = vec3(pattern);
            } else {
                colors[channel] = vec3(0.1);
            }
        }
        
        col = vec3(colors[0].r, colors[1].g, colors[2].b);
    }
    
    return col;
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
            // Tetrahedron - make it glass-like with transparency
            vec3 lightPos = vec3(2.0, 3.0, -2.0);
            float dif = GetLight(p, lightPos);
            
            // Fresnel effect
            float fresnel = pow(1.0 - abs(dot(rd, n)), 3.0);
            
            // Reflection
            vec3 reflectRd = reflect(rd, n);
            float reflectD = RayMarch(p + n * SURF_DIST * 2.0, reflectRd, MAX_DIST);
            vec3 reflectCol = vec3(0.1);
            if(reflectD < MAX_DIST) {
                vec3 reflectP = p + reflectRd * reflectD;
                float reflectLight = GetLight(reflectP, lightPos);
                reflectCol = vec3(0.2, 0.4, 0.8) * reflectLight;
            }
            
            // Combine with fresnel
            col = mix(vec3(0.9, 0.95, 1.0), reflectCol, fresnel * 0.5);
            col += vec3(dif * 0.3);
            
        } else {
            // Plane - show refraction pattern
            vec3 lightPos = vec3(2.0, 3.0, -2.0);
            float dif = GetLight(p, lightPos);
            
            // Base plane color
            vec3 planeColor = vec3(0.05, 0.05, 0.08);
            
            // Add rainbow caustics from refraction
            vec3 refractionCol = getRefractionColor(ro, rd, 1.5);
            
            col = planeColor * dif + refractionCol * 2.0;
        }
    } else {
        // Background gradient
        col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), uv.y * 0.5 + 0.5);
    }
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    fragColor = vec4(col, 1.0);
}
