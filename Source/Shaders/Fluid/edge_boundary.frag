uniform vec2 invresolution;
uniform sampler2D field;
uniform vec2 offset;//in texels
uniform float multiplier;	//-1 for velocity, 1 for pressure
varying vec2 texCoord;

void main(void){
	//select offset pixel
	gl_FragColor = vec4(multiplier * texture2D(field, texCoord+offset*invresolution).xy, 0, 1); 
}
