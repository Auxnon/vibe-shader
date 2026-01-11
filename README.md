# vibe-shader
Test potential of hands-off 3D

## Raymarched Beveled Tetrahedron with Refraction

This project contains a GLSL shader featuring a raymarched beveled tetrahedron with light refraction effects, creating a prism-like rainbow pattern on a flat plane underneath.

### Features
- **Raymarching**: Efficient 3D rendering using signed distance functions (SDFs)
- **Beveled Tetrahedron**: Smooth, rounded edges on a rotating tetrahedron
- **Refraction**: Chromatic aberration simulating prism effects with rainbow caustics
- **Glass-like Material**: Fresnel reflections and transparency
- **ShaderToy Compatible**: Uses standard ShaderToy uniforms (iResolution, iTime, iMouse)

### Running Locally

Simply open `index.html` in a modern web browser. The shader will run automatically with WebGL.

```bash
# Option 1: Direct file open
open index.html  # macOS
xdg-open index.html  # Linux
start index.html  # Windows

# Option 2: Use a local server (recommended)
python3 -m http.server 8000
# Then navigate to http://localhost:8000
```

### Running on ShaderToy

1. Go to [https://www.shadertoy.com/new](https://www.shadertoy.com/new)
2. Copy the entire contents of `shader.glsl`
3. Paste it into the ShaderToy editor
4. Click the play button to see your shader in action!

### Technical Details

**Raymarching Technique**: The shader uses sphere tracing to render 3D scenes defined by signed distance functions.

**Beveled Tetrahedron**: Implemented using a tetrahedron SDF with smooth subtraction to create beveled edges.

**Refraction Simulation**: 
- Chromatic aberration with different indices of refraction for RGB channels
- Ray tracing through the glass tetrahedron
- Exit rays cast onto the plane below to create rainbow caustics

**Performance**: Optimized for real-time rendering at 60fps on modern GPUs.

### Files
- `index.html` - Standalone HTML file with embedded shader and JavaScript
- `shader.glsl` - ShaderToy-compatible GLSL shader code
