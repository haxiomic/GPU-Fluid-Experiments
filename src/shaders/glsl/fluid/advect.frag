uniform sampler2D velocity;
uniform sampler2D target;
uniform float dt;
uniform float rdx; //reciprocal of grid scale, used to scale velocity into simulation domain

varying vec2 texelCoord;
varying vec2 p;//aspect space

void main(void){
  //texelCoord refers to the center of the texel! Not a corner!
  
  vec2 tracedPos = p - dt * rdx * texture2D(velocity, texelCoord ).xy; //aspect space

  //Bilinear Interpolation of the target field value at tracedPos
  //convert from aspect space to texel space (0 -> 1 | x & y)
  tracedPos = aspectToTexelSpace(tracedPos);

  gl_FragColor = texture2D(target, tracedPos);
}