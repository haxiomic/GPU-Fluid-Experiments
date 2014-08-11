uniform sampler2D texture;
varying vec2 texelCoord;

void main(void){
	gl_FragColor = clamp(abs(texture2D(texture, (texelCoord+1.)/2.)), 0., 1.);//-1 -> 1 to 0 -> 1 
}