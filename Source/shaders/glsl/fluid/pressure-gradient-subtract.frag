uniform sampler2D pressure;
uniform sampler2D velocity;
uniform float halfrdx;

varying vec2 texelCoord;

void main(void){
  float L = samplePressue(pressure, texelCoord - vec2(invresolution.x, 0));
  float R = samplePressue(pressure, texelCoord + vec2(invresolution.x, 0));
  float B = samplePressue(pressure, texelCoord - vec2(0, invresolution.y));
  float T = samplePressue(pressure, texelCoord + vec2(0, invresolution.y));

  vec2 v = texture2D(velocity, texelCoord).xy;

  gl_FragColor = vec4(v - halfrdx*vec2(R-L, T-B), 0, 1);
}

