/*
aspectRatio = w/h

#Coordinate Spaces

    Clip Space,     -1 -> 1 | x & y

    Aspect Space,   -aspectRatio -> aspectRatio | x
                                        -1 -> 1 | y
        * Same as clip space but maintains aspect ratio by fixing height

    Sim Space,      (Aspect Space) * cellSize
        * Used for the flow velocity, this is the space the physics takes place in

    Texel Space,    0 -> 1 | x & y
        * Texture coordinates for use in texture2D

    Pixel Space,    0 -> w | x
                    0 -> h | y
*/

#define PRESSURE_BOUNDARY
#define VELOCITY_BOUNDARY

uniform vec2 invresolution;
uniform float aspectRatio;

vec2 clipToAspectSpace(vec2 p){
    return vec2(p.x * aspectRatio, p.y);
}

vec2 aspectToTexelSpace(vec2 p){
    return vec2(p.x / aspectRatio + 1.0 , p.y + 1.0)*.5;
}

//sampling pressure texture factoring in boundary conditions
float samplePressue(sampler2D pressure, vec2 coord){
    vec2 cellOffset = vec2(0.0, 0.0);

    //pure Neumann boundary conditions: 0 pressure gradient across the boundary
    //dP/dx = 0
    //walls
    #ifdef PRESSURE_BOUNDARY
    if(coord.x < 0.0)      cellOffset.x = 1.0;
    else if(coord.x > 1.0) cellOffset.x = -1.0;
    if(coord.y < 0.0)      cellOffset.y = 1.0;
    else if(coord.y > 1.0) cellOffset.y = -1.0;
    #endif

    return texture2D(pressure, coord + cellOffset * invresolution).x;
}

//sampling velocity texture factoring in boundary conditions
vec2 sampleVelocity(sampler2D velocity, vec2 coord){
    vec2 cellOffset = vec2(0.0, 0.0);
    vec2 multiplier = vec2(1.0, 1.0);

    //free-slip boundary: the average flow across the boundary is restricted to 0
    //avg(uA.xy, uB.xy) dot (boundary normal).xy = 0
    //walls
    #ifdef VELOCITY_BOUNDARY
    if(coord.x<0.0){
        cellOffset.x = 1.0;
        multiplier.x = -1.0;
    }else if(coord.x>1.0){
        cellOffset.x = -1.0;
        multiplier.x = -1.0;
    }
    if(coord.y<0.0){
        cellOffset.y = 1.0;
        multiplier.y = -1.0;
    }else if(coord.y>1.0){
        cellOffset.y = -1.0;
        multiplier.y = -1.0;
    }
    #endif

    return multiplier * texture2D(velocity, coord + cellOffset * invresolution).xy;
}