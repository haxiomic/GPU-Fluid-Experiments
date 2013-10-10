import openfl.Assets;
import openfl.gl.GLUniformLocation;
import xgl.Program;

//Shader Classes
class TextureProgram extends Program{
	public var texture:GLUniformLocation;	

	public function new(){
		super(Assets.getText("shaders/pass_through.vert"),
			  Assets.getText("shaders/display_texture.frag"));
	}
}