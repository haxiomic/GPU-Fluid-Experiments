uniform sampler2D diffusion;
uniform sampler2D velocity;
uniform float alpha;//alpha = v * (dx)^2/dnt, where dx = grid cell size
uniform float beta; // beta = 1/(4 + alpha)
varying vec2 texelCoord;

void main(void){
	// left, right, bottom, and top x samples
  //texelSize = 1./resolution;
  vec2 L = sampleVelocity(diffusion, texelCoord - vec2(invresolution.x, 0));
  vec2 R = sampleVelocity(diffusion, texelCoord + vec2(invresolution.x, 0));
  vec2 B = sampleVelocity(diffusion, texelCoord - vec2(0, invresolution.y));
  vec2 T = sampleVelocity(diffusion, texelCoord + vec2(0, invresolution.y));

  vec2 bC = texture2D(velocity, texelCoord).xy;

  gl_FragColor = vec4( (L + R + B + T + alpha * bC) * beta, 0, 1 );
}