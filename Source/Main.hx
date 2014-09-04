package;

import gltoolbox.render.RenderTarget;
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
	//Render Targets
	var offScreenTarget:RenderTarget;
	//Shaders
	var screenTextureShader   : ScreenTexture;
	var renderParticlesShader : ColorParticleMotion;
	var updateDyeShader       : MouseDye;
	var mouseForceShader      : MouseForce;
	//Window
	var isMouseDown:Bool = false;
	var mouse = new Vector2();
	var mouseClipSpace = new Vector2();
	var lastMouse = new Vector2();
	var lastMouseClipSpace = new Vector2();

	var time:Float;
	var lastTime:Float;

	var renderParticlesEnabled:Bool = true;
	var renderFluidEnabled:Bool = true;
	
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
				var isSafari  = (~/Safari/i).match(browserString);
				if(isSafari){
					// this.init = function(c:RenderContext){}		//nop out graphics calls
					// this.render = function(c:RenderContext){}
					alert("There's a bug with Safari's GLSL compiler, until I can track down what triggers it, this only works in Chrome and Firefox :[");
					return;
				}
			}
		#end
	}

	public override function init (context:RenderContext):Void {
		switch (context) {
			case OPENGL (gl):
				this.gl = gl;
				gl.disable(gl.DEPTH_TEST);
				gl.disable(gl.CULL_FACE);
				gl.disable(gl.DITHER);

				#if ios //grab default screenbuffer
					screenBuffer = new GLFramebuffer(gl.version, gl.getParameter(gl.FRAMEBUFFER_BINDING));
				#end
				textureQuad = gltoolbox.GeometryTools.createQuad(gl, 0, 0, 1, 1);

				offScreenTarget = new RenderTarget(gl, 
					gltoolbox.TextureTools.customTextureFactory(
						gl.RGBA,
						gl.UNSIGNED_BYTE,
						gl.NEAREST
					),
					Math.round(window.width/1),
					Math.round(window.height/1)
				);

				screenTextureShader = new ScreenTexture();
				renderParticlesShader = new ColorParticleMotion();
				updateDyeShader = new MouseDye();
				mouseForceShader = new MouseForce();

				updateDyeShader.mouseClipSpace.data = mouseClipSpace;
				updateDyeShader.lastMouseClipSpace.data = lastMouseClipSpace;
				mouseForceShader.mouseClipSpace.data = mouseClipSpace;
				mouseForceShader.lastMouseClipSpace.data = lastMouseClipSpace;

				var scaleFactor = 1/2;
				var fluidIterations = 20;
				var fluidScale = 32;

				#if js
					scaleFactor = 1/5;
					fluidIterations = 18;
				#end
				
				fluid = new GPUFluid(gl, Math.round(window.width*scaleFactor), Math.round(window.height*scaleFactor), fluidScale, fluidIterations);
				fluid.updateDyeShader = updateDyeShader;
				fluid.applyForcesShader = mouseForceShader;

				particles = new GPUParticles(gl, 262144);
				particles.flowScaleX = fluid.simToClipSpaceX(1);
				particles.flowScaleY = fluid.simToClipSpaceY(1);
				particles.dragCoefficient = 1;
			default:
				trace('RenderContext \'$context\' not supported');
		}

		updateLastMouse();

		lastTime = haxe.Timer.stamp();
	}

	public override function render (context:RenderContext):Void {
		time = haxe.Timer.stamp();
		var dt = time - lastTime; //60fps ~ 0.016
		lastTime = time;

		//update mouse velocity
		updateDyeShader.isMouseDown.set(isMouseDown);
		mouseForceShader.isMouseDown.set(isMouseDown);

		//step physics
		fluid.step(dt);

		particles.flowVelocityField = fluid.velocityRenderTarget.readFromTexture;
		particles.step(dt);

		//render to offScreen
		gl.viewport (0, 0, offScreenTarget.width, offScreenTarget.height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, offScreenTarget.frameBufferObject);
		// gl.viewport (0, 0, window.width, window.height);
		// gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);

		gl.clearColor(0,0,0,1);
		gl.clear(gl.COLOR_BUFFER_BIT);

		// additive blending
		gl.enable(gl.BLEND);
		gl.blendFunc( gl.SRC_ALPHA, gl.SRC_ALPHA );
		gl.blendEquation(gl.FUNC_ADD);

		if(renderFluidEnabled) renderTexture(fluid.dyeRenderTarget.readFromTexture);
		if(renderParticlesEnabled) renderParticles();

		gl.disable(gl.BLEND);

		//render offScreen texture to screen
		gl.viewport (0, 0, window.width, window.height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);
		renderTexture(offScreenTarget.texture);

		updateLastMouse();
	}

	inline function renderTexture(texture:GLTexture){
		gl.bindBuffer (gl.ARRAY_BUFFER, textureQuad);

		screenTextureShader.texture.data = texture;
		
		screenTextureShader.activate(true, true);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		screenTextureShader.deactivate();
	}

	inline function renderParticles():Void{
		//set vertices
		gl.bindBuffer(gl.ARRAY_BUFFER, particles.particleUVs);

		//set uniforms
		renderParticlesShader.particleData.data = particles.particleData.readFromTexture;

		//draw points
		renderParticlesShader.activate(true, true);
		//additive blending between particles
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

	inline function updateLastMouse(){
		lastMouse.setTo(mouse.x, mouse.y);
		lastMouseClipSpace.setTo(
			windowToClipSpaceX(lastMouse.x),
			windowToClipSpaceY(lastMouse.y)
		);
	}

	override function onKeyUp( keyCode : Int , modifier : Int ){
		switch (keyCode) {
			case KeyCode.R:
				reset();
			case KeyCode.P:
				renderParticlesEnabled = !renderParticlesEnabled;
			case KeyCode.F:
				renderFluidEnabled = !renderFluidEnabled;
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
		color = vec4(vec3(0.5, 0.3, 0.13)*0.1+cvec*1., 1.0);
	}
')
class ColorParticleMotion extends GPUParticles.RenderParticles{}

@:frag('
	#pragma include("Source/shaders/glsl/geom.glsl")

	uniform bool isMouseDown;
	uniform vec2 mouseClipSpace;
	uniform vec2 lastMouseClipSpace;

	void main(){
		//color.xyz *= 0.995;
		color.xyz += (0.0 - color.xyz)*0.01;
		if(isMouseDown){			
			vec2 mouse = clipToSimSpace(mouseClipSpace);
			vec2 lastMouse = clipToSimSpace(lastMouseClipSpace);
			vec2 mouseVelocity = -(lastMouse - mouse)*dx/dt;

			// float l = distanceToSegment(mouse, lastMouse, p);
			//compute tapered distance to mouse line segment
			float projection;
			float l = distanceToSegment(mouse, lastMouse, p, projection);
			float taperFactor = 1.0;//1 => 0 at lastMouse, 0 => no tapering
			float projectedFraction = 1.0 - clamp(projection / distance(mouse, lastMouse), 0.0, 1.0)*taperFactor;

			float R = 0.05;
			float m = exp(-l/R);
			m *= m;
 			
 			float s = length(mouseVelocity);
			float x = clamp(sqrt(s)*0.05, 0., 1.);
			color.r += m * (exp(-pow((x+0.15)*3., 2.))*.5 + pow((x-0.46)*1.85, 5.));
			color.g += m * (x*x*x*x);
			color.b += m * (x*x);
		}

		gl_FragColor = color;
	}
')
class MouseDye extends GPUFluid.UpdateDye{}

@:frag('
	#pragma include("Source/shaders/glsl/geom.glsl")

	uniform bool isMouseDown;
	uniform vec2 mouseClipSpace;
	uniform vec2 lastMouseClipSpace;

	void main(){
		v.xy *= 0.999;

		if(isMouseDown){
			vec2 mouse = clipToSimSpace(mouseClipSpace);
			vec2 lastMouse = clipToSimSpace(lastMouseClipSpace);
			vec2 mouseVelocity = -(lastMouse - mouse)*dx/dt;
				
			//compute tapered distance to mouse line segment
			float projection;
			float l = distanceToSegment(mouse, lastMouse, p, projection);
			float taperFactor = 0.5;//1 => 0 at lastMouse, 0 => no tapering
			float projectedFraction = 1.0 - clamp(projection / distance(mouse, lastMouse), 0.0, 1.0)*taperFactor;

			float R = 0.015;
			float m = exp(-l/R); //drag coefficient
			m *= projectedFraction * projectedFraction;

			// float maxSpeed = 10.04 * dx / dt;
			vec2 tv = mouseVelocity;//clamp(mouseVelocity, -maxSpeed, maxSpeed);
			v += (tv - v)*m;
		}

		gl_FragColor = vec4(v, 0, 1.);
	}
')
class MouseForce extends GPUFluid.ApplyForces{}