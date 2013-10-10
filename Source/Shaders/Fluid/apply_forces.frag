uniform vec2 invresolution;
uniform sampler2D velocity;
uniform float time;
uniform vec2 mouse;

varying vec2 texCoord;

void main(void){
  vec2 center = vec2(.5,.5);
  vec2 d = mouse-texCoord;
  
  vec4 v = texture2D(velocity, texCoord);

  if(length(d)<.03){
    v.xyz += vec3(cos(time*2.), sin(time*2.), cos(time*1.5))*.1;
  }
    

  gl_FragColor = v;
}