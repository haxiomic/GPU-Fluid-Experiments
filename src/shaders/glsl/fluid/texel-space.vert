/* 
Takes TextureQuad vertex coordinates 
* Converts to clip-space for display 
* Converts to aspect-space for use in fragment shaders 
	(to maintain aspect ratio)
*/
attribute vec2 vertexPosition;

uniform float aspectRatio;

varying vec2 texelCoord;

/*
--- Simulation Position ---
Aspect space coordinates is clip space where aspect ratio is maintained and height is fixed at 1
*/
varying vec2 p;//aspect space

void main() {
	texelCoord = vertexPosition;
	
	vec2 clipSpace = 2.0*texelCoord - 1.0;	//from 0->1 to -1, 1 (clip space)
	
	p = vec2(clipSpace.x * aspectRatio, clipSpace.y);

	gl_Position = vec4(clipSpace, 0.0, 1.0 );	
}
