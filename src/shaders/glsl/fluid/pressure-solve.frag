uniform sampler2D pressure;
uniform sampler2D divergence;
uniform float alpha;//alpha = -(dx)^2, where dx = grid cell size

varying vec2 texelCoord;

void main(void){
  // left, right, bottom, and top x samples
  //texelSize = 1./resolution;
  float L = samplePressue(pressure, texelCoord - vec2(invresolution.x, 0));
  float R = samplePressue(pressure, texelCoord + vec2(invresolution.x, 0));
  float B = samplePressue(pressure, texelCoord - vec2(0, invresolution.y));
  float T = samplePressue(pressure, texelCoord + vec2(0, invresolution.y));

  float bC = texture2D(divergence, texelCoord).x;

  gl_FragColor = vec4( (L + R + B + T + alpha * bC) * .25, 0, 0, 1 );//rBeta = .25
}