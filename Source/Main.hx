package;

import haxe.Timer;

import lime.app.Application;
import lime.graphics.opengl.*;
import lime.graphics.GLRenderContext;
import lime.graphics.RenderContext;
import lime.math.Vector2;
import lime.ui.KeyCode;
import lime.utils.Float32Array;
import shaderblox.ShaderBase;

class Main extends Application {
	var gl:GLRenderContext;
	//Simulations
	var fluid:GPUFluid;
	var particles:GPUParticles;
	//Geometry
	var textureQuad:GLBuffer = null; 
	//Framebuffers
	var screenBuffer:GLFramebuffer = null;	//null for all platforms exlcuding ios, where it references the defaultFramebuffer (UIStageView.mm)
	//Shaders
	var screenTextureShader   : ScreenTexture;
	var renderParticlesShader : ColorParticleMotion;
	var updateDyeShader       : MouseDye;
	var mouseForceShader      : MouseForce;
	//UI
	var isMouseDown:Bool = false;
	var mouse = new Vector2();
	var mouseVelocity = new Vector2();
	var mouseClipSpace = new Vector2();
	var mouseVelocityClipSpace = new Vector2();

	var time:Float;
	
	public function new () {
		super();
	}
	
	public override function init (context:RenderContext):Void {
		switch (context) {
			case OPENGL (gl):
				this.gl = gl;
				#if ios //grab default screenbuffer
					screenBuffer = new GLFramebuffer(gl.version, gl.getParameter(gl.FRAMEBUFFER_BINDING));
				#end
				textureQuad = gltoolbox.GeometryTools.createQuad(gl, 0, 0, 1, 1);

				screenTextureShader = new ScreenTexture();
				renderParticlesShader = new ColorParticleMotion();
				updateDyeShader = new MouseDye();
				mouseForceShader = new MouseForce();

				updateDyeShader.mouseClipSpace.data = mouseClipSpace;
				updateDyeShader.mouseVelocityClipSpace.data = mouseVelocityClipSpace;
				mouseForceShader.mouseClipSpace.data = mouseClipSpace;
				mouseForceShader.mouseVelocityClipSpace.data = mouseVelocityClipSpace;

				fluid = new GPUFluid(gl, Math.round(window.width), Math.round(window.height), 8, 16);
				fluid.updateDyeShader = updateDyeShader;
				fluid.applyForcesShader = mouseForceShader;

				particles = new GPUParticles(gl);
				particles.flowScale = 1/fluid.cellSize;
				particles.dragCoefficient = 1;
			default:
				trace('RenderContext \'$context\' not supported');
		}
	}

	public override function render (context:RenderContext):Void {
		// var now = haxe.Timer.stamp();
		// var dt = now - time;
		// time = now;
		updateDyeShader.isMouseDown.set(isMouseDown);
		mouseForceShader.isMouseDown.set(isMouseDown);
		//step physics
		fluid.step(1/60);

		particles.flowVelocityField = fluid.velocityRenderTarget.readFromTexture;
		particles.step(1/60);

		//clear screen
		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);
		gl.clearColor(0,0,0,1);
		gl.clear(gl.COLOR_BUFFER_BIT);
		//render
		// renderTextureToScreen(fluid.dyeRenderTarget.readFromTexture);
		renderParticlesToScreen();
	}

	inline function renderTextureToScreen(texture:GLTexture){
		gl.viewport (0, 0, window.width, window.height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);

		gl.bindBuffer (gl.ARRAY_BUFFER, textureQuad);

		screenTextureShader.texture.data = texture;
		
		screenTextureShader.activate(true, true);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		screenTextureShader.deactivate();
	}

	inline function renderParticlesToScreen():Void{
		gl.viewport(0, 0, window.width, window.height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);

		//set vertices
		gl.bindBuffer(gl.ARRAY_BUFFER, particles.particleUVs);

		//set uniforms
		renderParticlesShader.particleData.data = particles.particleData.readFromTexture;

		//draw points
		renderParticlesShader.activate(true, true);
		gl.enable(gl.BLEND);
		gl.blendFunc( gl.SRC_ALPHA, gl.SRC_ALPHA );
		gl.blendEquation(gl.FUNC_ADD);
		gl.drawArrays(gl.POINTS, 0, particles.particleData.width*particles.particleData.height);
		gl.disable(gl.BLEND);
		renderParticlesShader.deactivate();
	}

	function reset():Void{
		particles.reset();	
	}

	//coordinate conversion
	inline function windowToClipSpaceX(x:Float)return (x/window.width)*2 - 1;
	inline function windowToClipSpaceY(y:Float)return ((window.height-y)/window.height)*2 - 1;

	override function onMouseDown( x : Float , y : Float , button : Int ) this.isMouseDown = true;
	override function onMouseUp( x : Float , y : Float , button : Int )   this.isMouseDown = false;
	var firstMousePoint = true;
	var mouseMoveTime:Float;
	override function onMouseMove( x : Float , y : Float , button : Int ) {
		var now = haxe.Timer.stamp();

		if(!firstMousePoint){
			// var dt = now - mouseMoveTime;
			var dt = 1/60;
			mouseVelocity.setTo((x - mouse.x)/dt, (y - mouse.y)/dt);
		}

		mouse.setTo(x, y);
		mouseClipSpace.setTo(
			windowToClipSpaceX(x),
			windowToClipSpaceY(y)
		);
		mouseVelocityClipSpace.setTo(
			(mouseVelocity.x/window.width)*2,
			-(mouseVelocity.y/window.height)*2
		);

		firstMousePoint = false;
		mouseMoveTime = now;
	}

	override function onKeyUp( keyCode : Int , modifier : Int ){
		switch (keyCode) {
			case KeyCode.R:
				reset();
		}
	}
}


@:vert('#pragma include("Source/shaders/glsl/no-transform.vert")')
@:frag('#pragma include("Source/shaders/glsl/quad-texture.frag")')
class ScreenTexture extends ShaderBase {}

@:vert('
	void main(){
		//generate color
		vec2 v = texture2D(particleData, particleUV).ba;
		float lv = length(v);
		vec3 cvec = vec3(sin(lv/3.0)*1.5-lv*lv*0.7, lv*lv*30.0, lv+lv*lv*10.0);
		color = vec4(vec3(0.5, 0.3, 0.13)*0.3+cvec*1., 1.);

		set();
	}
')
class ColorParticleMotion extends GPUParticles.RenderParticles{}

@:frag('
	uniform bool isMouseDown;
	uniform vec2 mouseClipSpace;				//clipSpace
	uniform vec2 mouseVelocityClipSpace;

	vec2 mouse = clipToSimSpace(mouseClipSpace);
	vec2 mouseVelocity = clipToSimSpace(mouseVelocityClipSpace);
	float mouseSpeed = length(mouseVelocity);

	void main(){
		if(isMouseDown){			
			vec2 displacement = mouse - p;
			float l = length(displacement);
			float R = 0.05;
			float m = dt*exp(-l/R);
			
			color.r += m*3.;
		}

		gl_FragColor = color;
	}
')
class MouseDye extends GPUFluid.UpdateDye{}

@:frag('
	uniform bool isMouseDown;
	uniform vec2 mouseClipSpace;				//clipSpace
	uniform vec2 mouseVelocityClipSpace;

	vec2 mouse = clipToSimSpace(mouseClipSpace);
	vec2 mouseVelocity = clipToSimSpace(mouseVelocityClipSpace);
	float mouseSpeed = length(mouseVelocity);

	void main(){
		if(isMouseDown){
			vec2 displacement = mouse - p;
			float l = length(displacement);
			float R = 0.08;
			float m = dt*exp(-l/R);

			v += (mouseVelocity*200. - v)*m*m*10.;
		}

		gl_FragColor = vec4(v, 0, 1.);
	}
')
class MouseForce extends GPUFluid.ApplyForces{}