attribute vec2 vertexPosition;
varying vec2 texelCoord;

void main() {
	texelCoord = vertexPosition;
	gl_Position = vec4(vertexPosition*2.0 - vec2(1.0, 1.0), 0.0, 1.0 );//converts to clip space	
}