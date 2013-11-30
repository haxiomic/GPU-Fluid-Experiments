import openfl.Assets;
import openfl.gl.GLUniformLocation;
import xgl.Program;

//Shader Classes
class Advect extends Program{
	public var invresolution:GLUniformLocation;
	public var aspectRatio:GLUniformLocation;
	public var velocity:GLUniformLocation;	
	public var advected:GLUniformLocation;	
	public var dt:GLUniformLocation;	
	public var rdx:GLUniformLocation;		//grid scale

	public function new(){
		super(Assets.getText("shaders/fluid/pixel_space.vert"),
			  Assets.getText("shaders/fluid/advect.frag"));
	}
}

class ApplyForces extends Program{
	public var invresolution:GLUniformLocation;
	public var aspectRatio:GLUniformLocation;
	public var velocity:GLUniformLocation;
	public var time:GLUniformLocation;	
	public var mouse:GLUniformLocation;	

	public function new(){
		super(Assets.getText("shaders/fluid/pixel_space.vert"),
			  Assets.getText("shaders/fluid/apply_forces.frag"));
	}
}

class Divergence extends Program{
	public var invresolution:GLUniformLocation;
	public var aspectRatio:GLUniformLocation;
	public var field:GLUniformLocation;
	public var halfrdx:GLUniformLocation;

	public function new(){
		super(Assets.getText("shaders/fluid/pixel_space.vert"),
			  Assets.getText("shaders/fluid/divergence.frag"));
	}
}

class PressureSolver extends Program{
	public var invresolution:GLUniformLocation;
	public var aspectRatio:GLUniformLocation;
	public var pressure:GLUniformLocation;
	public var divergence:GLUniformLocation;
	public var alpha:GLUniformLocation;

	public function new(){
		super(Assets.getText("shaders/fluid/pixel_space.vert"),
			  Assets.getText("shaders/fluid/pressure_solve.frag"));
	}
}

class PGradientSubtract extends Program{
	public var invresolution:GLUniformLocation;
	public var aspectRatio:GLUniformLocation;
	public var pressure:GLUniformLocation;
	public var velocity:GLUniformLocation;
	public var halfrdx:GLUniformLocation;

	public function new(){
		super(Assets.getText("shaders/fluid/pixel_space.vert"),
			  Assets.getText("shaders/fluid/pressure_gradient_subtract.frag"));
	}
}

