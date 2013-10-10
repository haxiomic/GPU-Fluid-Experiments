/* Converts to clip space, given resolution of display in pixel space */ 
uniform vec2 invresolution;
attribute vec2 position;
varying vec2 texCoord;

void main() {
	texCoord = position*invresolution;
	
	vec2 pixel = 2.0*texCoord - 1.0;	//from 0->w to -1, 1 (clip space)
	gl_Position = vec4(pixel, 0.0, 1.0 );	
}
