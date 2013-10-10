attribute vec3 position;
varying vec2 texCoord;

void main() {
	texCoord = position.xy;
	gl_Position = vec4( position, 1.0 );	
}