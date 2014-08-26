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
	var mouseClipSpace = new Vector2();
	var mouseVelocityClipSpace = new Vector2();

	var time:Float;
	
	public function new () {
		super();

		//check and halt Safari browser
		#if js
			untyped{
				var browserString = js.Lib.eval("
					(function(){
					    var ua= navigator.userAgent, tem, 
					    M= ua.match(/(opera|chrome|safari|firefox|msie|trident(?=\\/))\\/?\\s*(\\d+)/i) || [];
					    if(/trident/i.test(M[1])){
					        tem=  /\\brv[ :]+(\\d+)/g.exec(ua) || [];
					        return 'IE '+(tem[1] || '');
					    }
					    if(M[1]=== 'Chrome'){
					        tem= ua.match(/\\bOPR\\/(\\d+)/)
					        if(tem!= null) return 'Opera '+tem[1];
					    }
					    M= M[2]? [M[1], M[2]]: [navigator.appName, navigator.appVersion, '-?'];
					    if((tem= ua.match(/version\\/(\\d+)/i))!= null) M.splice(1, 1, tem[1]);
					    return M.join(' ');
					})();
				");
				var isSafari  = (~/Safari/igm).match(browserString);
				if(isSafari){
					this.init = function(c:RenderContext){}
					this.render = function(c:RenderContext){}
					alert("There's a bug with Safari's GLSL compiler, until I can track it down, this only works in Chrome and Firefox :[");
					return;
				}
			}
		#end
	}

	var lastMouse = new Vector2();
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

				var scaleFactor = 1/1;
				#if js
					scaleFactor = 1/4;
				#end

				fluid = new GPUFluid(gl, Math.round(window.width*scaleFactor), Math.round(window.height*scaleFactor), 8, 18);
				fluid.updateDyeShader = updateDyeShader;
				fluid.applyForcesShader = mouseForceShader;

				particles = new GPUParticles(gl);
				particles.flowScale = 1/fluid.cellSize;
				particles.dragCoefficient = 1;
			default:
				trace('RenderContext \'$context\' not supported');
		}

		lastMouse.x = mouse.x;
		lastMouse.y = mouse.y;
	}

	var dt:Float = 0.016;
	public override function render (context:RenderContext):Void {
		//update mouse velocity
		mouseVelocityClipSpace.x = (mouse.x - lastMouse.x);
		mouseVelocityClipSpace.y = -(mouse.y - lastMouse.y);

		updateDyeShader.isMouseDown.set(isMouseDown);
		mouseForceShader.isMouseDown.set(isMouseDown);

		//step physics
		fluid.step(dt);

		particles.flowVelocityField = fluid.velocityRenderTarget.readFromTexture;
		particles.step(dt);

		//clear screen
		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);
		gl.clearColor(0,0,0,1);
		gl.clear(gl.COLOR_BUFFER_BIT);
		//additive blending
		gl.enable(gl.BLEND);
		gl.blendFunc( gl.SRC_ALPHA, gl.SRC_ALPHA );
		gl.blendEquation(gl.FUNC_ADD);

		//render
		renderTextureToScreen(fluid.dyeRenderTarget.readFromTexture);
		renderParticlesToScreen();

		gl.disable(gl.BLEND);

		lastMouse.x = mouse.x;
		lastMouse.y = mouse.y;
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
		//additive blending
		// gl.enable(gl.BLEND);
		// gl.blendFunc( gl.SRC_ALPHA, gl.SRC_ALPHA );
		// gl.blendEquation(gl.FUNC_ADD);

		gl.drawArrays(gl.POINTS, 0, particles.particleData.width*particles.particleData.height);

		// gl.disable(gl.BLEND);
		renderParticlesShader.deactivate();
	}

	function reset():Void{
		particles.reset();	
	}

	//coordinate conversion
	inline function windowToClipSpaceX(x:Float)return (x/window.width)*2 - 1;
	inline function windowToClipSpaceY(y:Float)return ((window.height-y)/window.height)*2 - 1;

	override function onMouseDown( x : Float , y : Float , button : Int ){
		this.isMouseDown = true;
	}
	override function onMouseUp( x : Float , y : Float , button : Int ){
		this.isMouseDown = false;
	}

	override function onMouseMove( x : Float , y : Float , button : Int ) {
		mouse.setTo(x, y);
		mouseClipSpace.setTo(
			windowToClipSpaceX(x),
			windowToClipSpaceY(y)
		);
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
		set();
		//generate color
		vec2 v = texture2D(particleData, particleUV).ba;
		float lv = length(v);

		vec3 cvec = vec3(sin(lv/3.0)*1.5-lv*lv*0.7, lv*lv*30.0, lv+lv*lv*10.0);
		color = vec4(vec3(0.5, 0.3, 0.13)*0.1+cvec*1., 1.);
	}
')
class ColorParticleMotion extends GPUParticles.RenderParticles{}

@:frag('
	uniform bool isMouseDown;
	uniform vec2 mouseClipSpace;				//clipSpace
	uniform vec2 mouseVelocityClipSpace;

	vec2 mouse = clipToSimSpace(mouseClipSpace);
	vec2 mouseVelocity = clipToSimSpace(mouseVelocityClipSpace);

	void main(){
		if(isMouseDown){			
			vec2 displacement = mouse - p;
			float l = length(displacement);
			float R = 0.05;
			float m = exp(-l/R);
			m*=m;
				
			color.r += m*.1;
			color.g += m*.5;
			color.b += m*.2;
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

	void main(){
		if(isMouseDown){
			vec2 displacement = mouse - p;
			float l = length(displacement);
			float R = 0.025;
			float m = exp(-l/R); //drag coefficient
			m*=m;

			v += (mouseVelocity*1.1 - v)*m;
		}

		gl_FragColor = vec4(v, 0, 1.);
	}
')
class MouseForce extends GPUFluid.ApplyForces{}