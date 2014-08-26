uniform sampler2D velocity;
uniform sampler2D target;
uniform float dt;
uniform float rdx; //reciprocal of grid scale, used to scale velocity into simulation domain

varying vec2 texelCoord;
varying vec2 p;

void main(void){
  //texelCoord refers to the center of the texel! Not a corner!
  
  vec2 tracedPos = p - dt * rdx * texture2D(velocity, texelCoord ).xy;

  //Bilinear Interpolation of the target field value at tracedPos 
  tracedPos = simToTexelSpace(tracedPos)/invresolution; // texel coordinates
  
  vec4 st;
  st.xy = floor(tracedPos-.5)+.5; //left & bottom cell centers
  st.zw = st.xy+1.;               //right & top centers

  vec2 t = tracedPos - st.xy;

  st*=invresolution.xyxy; //to unitary coords
  
  vec4 tex11 = texture2D(target, st.xy );
  vec4 tex21 = texture2D(target, st.zy );
  vec4 tex12 = texture2D(target, st.xw );
  vec4 tex22 = texture2D(target, st.zw );

  //need to bilerp this result
  gl_FragColor = mix(mix(tex11, tex21, t.x), mix(tex12, tex22, t.x), t.y);
}