uniform sampler2D texture;
varying vec2 texelCoord;

void main(void){
	gl_FragColor = abs(texture2D(texture, texelCoord));
}