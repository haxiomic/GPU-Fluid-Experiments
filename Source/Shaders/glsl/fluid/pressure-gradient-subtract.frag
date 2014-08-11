uniform vec2 invresolution;
uniform sampler2D pressure;
uniform sampler2D velocity;
uniform float halfrdx;

varying vec2 texelCoord;
varying vec2 p;

void main(void){
  float L = texture2D(pressure, texelCoord - vec2(invresolution.x, 0)).x;
  float R = texture2D(pressure, texelCoord + vec2(invresolution.x, 0)).x;
  float B = texture2D(pressure, texelCoord - vec2(0, invresolution.y)).x;
  float T = texture2D(pressure, texelCoord + vec2(0, invresolution.y)).x;

  vec2 v = texture2D(velocity, texelCoord).xy;

  gl_FragColor = vec4(v - halfrdx*vec2(R-L, T-B), 0, 1);
}