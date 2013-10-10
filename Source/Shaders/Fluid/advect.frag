uniform vec2 invresolution;
uniform sampler2D velocity;
uniform sampler2D advected;
uniform float dt;
uniform float rdx; //recipricol of grid scale, used to scale velocity into simulation domain

//scale between velocity and dye?
uniform vec2 AByV;

varying vec2 texCoord;

void main(void){
  //texCoord is relative size of texture we're writing to
  //texCoord refers to the center of the texel! Not a corner!
  //velocity should be in relative terms not pixels
    //A velocity of 1 means it spans the entire dimention of the texture
  vec2 tracedPos = texCoord - dt * rdx * AByV * texture2D(velocity, texCoord / AByV).xy;

  //Bilinear Interpolation of the velocity at tracedPos 
  tracedPos /= invresolution;  //To texel coords
  vec4 st;
  st.xy = floor(tracedPos-.5)+.5; //left & bottom cell centers
  st.zw = st.xy+1.;               //right & top centers

  vec2 t = tracedPos - st.xy;

  st*=invresolution.xyxy;

  vec4 tex11 = texture2D(advected, st.xy);
  vec4 tex21 = texture2D(advected, st.zy);
  vec4 tex12 = texture2D(advected, st.xw);
  vec4 tex22 = texture2D(advected, st.zw);

  //need to bilerp this result
  gl_FragColor = mix(mix(tex11, tex21, t.x), mix(tex12, tex22, t.x), t.y);
}