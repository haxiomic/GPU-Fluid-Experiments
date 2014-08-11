attribute vec2 aVertexPosition;
varying vec2 texelCoord;

void main() {
	texelCoord = aVertexPosition.xy;
	gl_Position = vec4(aVertexPosition, 0.0, 1.0 );	
}