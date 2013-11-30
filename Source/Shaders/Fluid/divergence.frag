uniform vec2 invresolution;
uniform sampler2D field;	//vector fields
uniform float halfrdx;	// .5*1/gridscale

varying vec2 texCoord;
varying vec2 p;

void main(void){
	//compute the divergence according to the finite difference formula
 	//texelSize = 1/resolution
	vec4 L = texture2D(field, texCoord - vec2(invresolution.x, 0));
	vec4 R = texture2D(field, texCoord + vec2(invresolution.x, 0));
	vec4 B = texture2D(field, texCoord - vec2(0, invresolution.y));
	vec4 T = texture2D(field, texCoord + vec2(0, invresolution.y));

	gl_FragColor = vec4( vec2(halfrdx * ((R.x - L.x) + (T.y - B.y))), 0, 1);
}

