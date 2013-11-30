uniform vec2 invresolution;
uniform sampler2D velocity;
uniform float time;
uniform vec2 mouse;

varying vec2 texCoord;
varying vec2 p;

void main(void){
  vec4 v = texture2D(velocity, texCoord);
  
  vec2 d = mouse - p;
  if(length(d)<.1){
    v.xyz += vec3(cos(time*2.), sin(time*2.), cos(time*1.5))*.1;
  }
    
  gl_FragColor = v;
}