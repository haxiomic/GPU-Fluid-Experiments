uniform vec2 invresolution; //(same for both the pressure and divergence textures)
uniform sampler2D pressure;
uniform sampler2D divergence;
uniform float alpha;//alpha = -(dx)^2, where dx = grid cell size

varying vec2 texCoord;
varying vec2 p;

void main(void){
  // left, right, bottom, and top x samples
  //texelSize = 1./resolution;

  vec2 L = texture2D(pressure, texCoord - vec2(invresolution.x, 0)).xy;
  vec2 R = texture2D(pressure, texCoord + vec2(invresolution.x, 0)).xy;
  vec2 B = texture2D(pressure, texCoord - vec2(0, invresolution.y)).xy;
  vec2 T = texture2D(pressure, texCoord + vec2(0, invresolution.y)).xy;

  vec2 bC = texture2D(divergence, texCoord).xy;

  gl_FragColor = vec4( (L + R + B + T + alpha * bC) * .25, 0, 1 );//rBeta = .25
}