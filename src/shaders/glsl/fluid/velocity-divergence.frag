uniform sampler2D velocity;	//vector fields
uniform float halfrdx;	// .5*1/gridscale

varying vec2 texelCoord;


void main(void){
	//compute the divergence according to the finite difference formula
 	//texelSize = 1/resolution
	vec2 L = sampleVelocity(velocity, texelCoord - vec2(invresolution.x, 0));
	vec2 R = sampleVelocity(velocity, texelCoord + vec2(invresolution.x, 0));
	vec2 B = sampleVelocity(velocity, texelCoord - vec2(0, invresolution.y));
	vec2 T = sampleVelocity(velocity, texelCoord + vec2(0, invresolution.y));

	gl_FragColor = vec4( halfrdx * ((R.x - L.x) + (T.y - B.y)), 0, 0, 1);
}
