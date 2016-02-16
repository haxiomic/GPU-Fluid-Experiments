package;

import haxe.Timer;

import snow.modules.opengl.GL;
import snow.types.Types;

import gltoolbox.render.RenderTarget;
import shaderblox.ShaderBase;
import shaderblox.uniforms.UVec2.Vector2;

typedef UserConfig = {}

class Main extends snow.App{
	// var gl = GL;
	//Simulations
	var fluid:GPUFluid;
	var particles:GPUParticles;
	//Geometry
	var textureQuad:GLBuffer = null; 
	//Framebuffers
	var screenBuffer:GLFramebuffer = null;	//null for all platforms excluding ios, where it references the defaultFramebuffer (UIStageView.mm)
	//Render Targets
	var offScreenTarget:RenderTarget;
	//Shaders
	var screenTextureShader   : ScreenTexture;
	var renderParticlesShader : ColorParticleMotion;
	var updateDyeShader       : MouseDye;
	var mouseForceShader      : MouseForce;
	//Window
	var isMouseDown:Bool = false;
	var mousePointKnown:Bool = false;
	var lastMousePointKnown:Bool = false;
	var mouse = new Vector2();
	var mouseFluid = new Vector2();
	var lastMouse = new Vector2();
	var lastMouseFluid = new Vector2();
	var time:Float;
	var lastTime:Float;
	//Drawing
	var renderParticlesEnabled:Bool = true;
	var renderFluidEnabled:Bool = true;
	//
	var performanceMonitor:PerformanceMonitor;
	//Parameters
	var particleCount:Int;
	var fluidScale:Float;
	var fluidIterations(default, set):Int;
	var offScreenScale:Float;
	var offScreenFilter:Int;
	var simulationQuality(default, set):SimulationQuality;

	static inline var OFFSCREEN_RENDER = false;//seems to be faster when on!
	
	public function new () {

		performanceMonitor = new PerformanceMonitor(35, null, 2000);

		simulationQuality = Medium;

		#if desktop
		simulationQuality = High;
		#elseif ios
		simulationQuality = iOS;
		#end

		#if js
		performanceMonitor.fpsTooLowCallback = lowerQualityRequired; //auto adjust quality

		//Extract quality parameter, ?q= and set simulation quality
		var urlParams = js.Web.getParams();
		if(urlParams.exists('q')){
			var q = StringTools.trim(urlParams.get('q').toLowerCase());
			//match enum
			for(e in Type.allEnums(SimulationQuality)){
				var name = Type.enumConstructor(e).toLowerCase();
				if(q == name){
					simulationQuality = e;
					performanceMonitor.fpsTooLowCallback = null; //disable auto quality adjusting
					break;
				}
			}
		}
		//Extract iterations
		if(urlParams.exists('iterations')){
			var iterationsParam = Std.parseInt(urlParams.get('iterations'));
			if(Std.is(iterationsParam, Int))
				fluidIterations = iterationsParam;
		}
		#end
	}

	override function config( config:AppConfig ) : AppConfig {
		
		#if js
		config.runtime.prevent_default_context_menu = false;
		#end
		config.window.borderless = true;
		config.window.fullscreen = true;
		config.window.title = "GPU Fluid";
		//for some reason, window width and height are set initially from config in browsers and 
		//ignores true size
		#if js
		config.window.width = js.Browser.window.innerWidth;
		config.window.height = js.Browser.window.innerHeight;
		#end

		config.render.antialiasing = 0;


	    return config;
	}

	override function ready(){

		init();

	}

	function init():Void {
		GL.disable(GL.DEPTH_TEST);
		GL.disable(GL.CULL_FACE);
		GL.disable(GL.DITHER);

        #if ios screenBuffer = GL.getParameter(GL.FRAMEBUFFER_BINDING); #end

		textureQuad = gltoolbox.GeometryTools.createQuad(0, 0, 1, 1);

		if(OFFSCREEN_RENDER){
			offScreenTarget = new RenderTarget(
				Math.round(app.runtime.window_width()*offScreenScale),
				Math.round(app.runtime.window_height()*offScreenScale),
				gltoolbox.TextureTools.createTextureFactory({
					channelType: GL.RGB,
					dataType: GL.UNSIGNED_BYTE,
					filter: offScreenFilter
				})
			);
		}

		screenTextureShader = new ScreenTexture();
		renderParticlesShader = new ColorParticleMotion();
		updateDyeShader = new MouseDye();
		mouseForceShader = new MouseForce();

		updateDyeShader.mouse.data = mouseFluid;
		updateDyeShader.lastMouse.data = lastMouseFluid;
		mouseForceShader.mouse.data = mouseFluid;
		mouseForceShader.lastMouse.data = lastMouseFluid;

		var cellScale = 32;
		fluid = new GPUFluid(Math.round(app.runtime.window_width()*fluidScale), Math.round(app.runtime.window_height()*fluidScale), cellScale, fluidIterations);
		fluid.updateDyeShader = updateDyeShader;
		fluid.applyForcesShader = mouseForceShader;

		particles = new GPUParticles(particleCount);
		//scale from fluid's velocity field to clipSpace, which the particle velocity uses
		particles.flowScaleX = 1/(fluid.cellSize * fluid.aspectRatio);
		particles.flowScaleY = 1/fluid.cellSize;
		particles.dragCoefficient = 1;

		#if ios
		renderParticlesShader.POINT_SIZE = "4.0";
		#end

		lastTime = haxe.Timer.stamp();
	}

	override function update( dt:Float ){
		dt = 0.016;//@!
		//Physics
		//interaction
		updateDyeShader.isMouseDown.set(isMouseDown && lastMousePointKnown);
		mouseForceShader.isMouseDown.set(isMouseDown && lastMousePointKnown);

		//step physics
		fluid.step(dt);

		particles.flowVelocityField = fluid.velocityRenderTarget.readFromTexture;
		if(renderParticlesEnabled) particles.step(dt);

		updateLastMouse();
	}

	override function tick (delta:Float):Void {
		// time = haxe.Timer.stamp();
		// var dt = time - lastTime; //60fps ~ 0.016
		// lastTime = time;

		//Render
		//render to offScreen
		if(OFFSCREEN_RENDER){
			GL.viewport (0, 0, offScreenTarget.width, offScreenTarget.height);
			GL.bindFramebuffer(GL.FRAMEBUFFER, offScreenTarget.frameBufferObject);
		}else{
			GL.viewport (0, 0, app.runtime.window_width(), app.runtime.window_height());
			GL.bindFramebuffer(GL.FRAMEBUFFER, screenBuffer);
		}

		GL.clearColor(0,0,0,1);
		GL.clear(GL.COLOR_BUFFER_BIT);

		// additive blending
		GL.enable(GL.BLEND);
		GL.blendFunc( GL.SRC_ALPHA, GL.SRC_ALPHA );
		GL.blendEquation(GL.FUNC_ADD);

		if(renderParticlesEnabled) renderParticles();
		if(renderFluidEnabled) renderTexture(fluid.dyeRenderTarget.readFromTexture);

		GL.disable(GL.BLEND);

		//render offScreen texture to screen
		if(OFFSCREEN_RENDER){
			GL.viewport (0, 0, app.runtime.window_width(), app.runtime.window_height());
			GL.bindFramebuffer(GL.FRAMEBUFFER, screenBuffer);
			renderTexture(offScreenTarget.texture);
		}
	}

	inline function renderTexture(texture:GLTexture){
		GL.bindBuffer (GL.ARRAY_BUFFER, textureQuad);

		screenTextureShader.texture.data = texture;
		
		screenTextureShader.activate(true, true);
		GL.drawArrays(GL.TRIANGLE_STRIP, 0, 4);
		screenTextureShader.deactivate();
	}

	inline function renderParticles():Void{
		//set vertices
		GL.bindBuffer(GL.ARRAY_BUFFER, particles.particleUVs);

		//set uniforms
		renderParticlesShader.particleData.data = particles.particleData.readFromTexture;

		//draw points
		renderParticlesShader.activate(true, true);
		GL.drawArrays(GL.POINTS, 0, particles.count);
		renderParticlesShader.deactivate();
	}

	function updateSimulationTextures(){
		//only resize if there is a change
		var w:Int, h:Int;
		w = Math.round(app.runtime.window_width()*fluidScale); h = Math.round(app.runtime.window_height()*fluidScale);
		if(w != fluid.width || h != fluid.height) fluid.resize(w, h);

		w = Math.round(app.runtime.window_width()*offScreenScale); h = Math.round(app.runtime.window_height()*offScreenScale);
		if(w != offScreenTarget.width || h != offScreenTarget.height) offScreenTarget.resize(w, h);

		if(particleCount != particles.count) particles.setCount(particleCount);
	}

	function set_simulationQuality(quality:SimulationQuality):SimulationQuality{
		switch (quality) {
			case UltraHigh:
				particleCount = 1 << 20;
				fluidScale = 1/2;
				fluidIterations = 30;
				offScreenScale = 1/1;
				offScreenFilter = GL.NEAREST;
			case High:
				particleCount = 1 << 20;
				fluidScale = 1/4;
				fluidIterations = 20;
				offScreenScale = 1/1;
				offScreenFilter = GL.NEAREST;
			case Medium:
				particleCount = 1 << 18;
				fluidScale = 1/4;
				fluidIterations = 18;
				offScreenScale = 1/1;
				offScreenFilter = GL.NEAREST;
			case Low:
				particleCount = 1 << 16;
				fluidScale = 1/5;
				fluidIterations = 14;
				offScreenScale = 1/1;
				offScreenFilter = GL.NEAREST;
			case UltraLow:
				particleCount = 1 << 14;
				fluidScale = 1/6;
				fluidIterations = 12;
				offScreenScale = 1/2;
				offScreenFilter = GL.NEAREST;
			case iOS:
				particleCount = 1 << 14;
				fluidScale = 1/10;
				fluidIterations = 6;
				offScreenScale = 1/2;
				offScreenFilter = GL.LINEAR;
		}
		return simulationQuality = quality;
	}

	function set_fluidIterations(v:Int):Int{
		fluidIterations = v;
		if(fluid != null) fluid.solverIterations = v;
		return v;
	}

	var qualityDirection:Int = 0;
	function lowerQualityRequired(magnitude:Float){
		if(qualityDirection>0)return;
		qualityDirection = -1;
		var qualityIndex = Type.enumIndex(this.simulationQuality);
		var maxIndex = Type.allEnums(SimulationQuality).length - 1;
		if(qualityIndex >= maxIndex)return;

		if(magnitude < 0.5) qualityIndex +=1;
		else                qualityIndex +=2;

		if(qualityIndex > maxIndex)qualityIndex = maxIndex;

		var newQuality = Type.createEnumIndex(SimulationQuality, qualityIndex);
		trace('Average FPS: '+performanceMonitor.fpsAverage+', lowering quality to: '+newQuality);
		this.simulationQuality = newQuality;
		updateSimulationTextures();
	}

	//!# Requires better upsampling before use!
	function higherQualityRequired(magnitude:Float){
		if(qualityDirection<0)return;
		qualityDirection = 1;

		var qualityIndex = Type.enumIndex(this.simulationQuality);
		var minIndex = 0;
		if(qualityIndex <= minIndex)return;

		if(magnitude < 0.5) qualityIndex -=1;
		else                qualityIndex -=2;

		if(qualityIndex < minIndex)qualityIndex = minIndex;

		var newQuality = Type.createEnumIndex(SimulationQuality, qualityIndex);
		trace('Raising quality to: '+newQuality);
		this.simulationQuality = newQuality;
		updateSimulationTextures();
	}


	//---- Interface ----//

	function reset():Void{
		particles.reset();	
		fluid.clear();
	}

	//coordinate conversion
	inline function windowToClipSpaceX(x:Float) return (x/app.runtime.window_width())*2 - 1;
	inline function windowToClipSpaceY(y:Float) return ((app.runtime.window_height()-y)/app.runtime.window_height())*2 - 1;

	override function onmousedown( x : Float , y : Float , button : Int, _, _){
		this.isMouseDown = true; 
	}
	override function onmouseup( x : Float , y : Float , button : Int, _, _){
		this.isMouseDown = false;
	}

	override function onmousemove( x : Float , y : Float , xrel:Int, yrel:Int, _, _) {
		mouse.set(x, y);
		mouseFluid.set(
			fluid.clipToAspectSpaceX(windowToClipSpaceX(x)),
			fluid.clipToAspectSpaceY(windowToClipSpaceY(y))
		);
		mousePointKnown = true;
	}

	inline function updateLastMouse(){
		lastMouse.set(mouse.x, mouse.y);
		lastMouseFluid.set(
			fluid.clipToAspectSpaceX(windowToClipSpaceX(mouse.x)),
			fluid.clipToAspectSpaceY(windowToClipSpaceY(mouse.y))
		);
		lastMousePointKnown = true && mousePointKnown;
	}

	// override function ontouchdown(x:Float,y:Float,touch_id:Int,_){
	// 	updateTouchCoordinate(x,y);
	// 	updateLastMouse();
	// 	this.isMouseDown = true; 
	// }

	// override function ontouchup(x:Float,y:Float,touch_id:Int,_){
	// 	updateTouchCoordinate(x,y);
	// 	this.isMouseDown = false;
	// }

	// override function ontouchmove(x:Float,y:Float,dx:Float,dy:Float,touch_id:Int,_){
	// 	updateTouchCoordinate(x,y);
	// }


	// function updateTouchCoordinate(x:Float, y:Float){
	// 	x = x*app.runtime.window_width();
	// 	y = y*app.runtime.window_height();
	// 	mouse.set(x, y);
	// 	mouseFluid.set(
	// 		windowToClipSpaceX(x),
	// 		windowToClipSpaceY(y)
	// 	);
	// 	mousePointKnown = true;
	// }


	var lshiftDown = false;
	var rshiftDown = false;
	override function onkeydown( keyCode : Int, _, _, _, _, _){
		switch (keyCode) {
			case Key.lshift: 
				lshiftDown = true;
			case Key.rshift: 
				rshiftDown = true;
		}
	}
	
	override function onkeyup( keyCode : Int , _, _, _, _, _){
		switch (keyCode) {
			case Key.key_r:
				if(lshiftDown || rshiftDown) particles.reset();
				else reset();
			case Key.key_p:
				renderParticlesEnabled = !renderParticlesEnabled;
			case Key.key_d:
				renderFluidEnabled = !renderFluidEnabled;
			case Key.key_s:
				fluid.clear();
			case Key.lshift: 
				lshiftDown = false;
			case Key.rshift: 
				rshiftDown = false;
		}
	}
}

enum SimulationQuality{
	UltraHigh;
	High;
	Medium;
	Low;
	UltraLow;
	iOS;
}


@:vert('#pragma include("src/shaders/glsl/no-transform.vert")')
@:frag('#pragma include("src/shaders/glsl/quad-texture.frag")')
class ScreenTexture extends ShaderBase {}

@:vert('
	const float POINT_SIZE = 1.0;
	void main(){
		vec2 p = texture2D(particleData, particleUV).xy;
		vec2 v = texture2D(particleData, particleUV).zw;
		gl_PointSize = POINT_SIZE;
		gl_Position = vec4(p, 0.0, 1.0);
		float speed = length(v);
		float x = clamp(speed * 2.0, 0., 1.);
		color.rgb = (
				mix(vec3(40.4, 0.0, 35.0) / 300.0, vec3(0.2, 47.8, 100) / 100.0, x)
				+ (vec3(63.1, 92.5, 100) / 100.) * x*x*x * .1
		);
		color.a = 1.0;
	}
')
class ColorParticleMotion extends GPUParticles.RenderParticles{}

@:frag('
	#pragma include("src/shaders/glsl/geom.glsl")
	uniform bool isMouseDown;
	uniform vec2 mouse; //aspect space coordinates
	uniform vec2 lastMouse;
	void main(){
		vec4 color = texture2D(dye, texelCoord);
		color.r *= (0.9797);
		color.g *= (0.9494);
		color.b *= (0.9696);

		if(isMouseDown){			
			vec2 mouseVelocity = (mouse - lastMouse)/dt;
			
			//compute tapered distance to mouse line segment
			float projection;
			float l = distanceToSegment(mouse, lastMouse, p, projection);
			float taperFactor = 0.6;
			float projectedFraction = 1.0 - clamp(projection, 0.0, 1.0)*taperFactor;
			float R = 0.025;
			float m = exp(-l/R);
			
			float speed = length(mouseVelocity);
			float x = clamp((speed * speed * 0.02 - l * 5.0) * projectedFraction, 0., 1.);
			color.rgb += m * (
				mix(vec3(2.4, 0, 5.9) / 60.0, vec3(0.2, 51.8, 100) / 30.0, x)
					+ (vec3(100) / 100.) * pow(x, 9.)
			);
		}

		gl_FragColor = color;
	}
')
class MouseDye extends GPUFluid.UpdateDye{}

@:frag('
	#pragma include("src/shaders/glsl/geom.glsl")
	uniform bool isMouseDown;
	uniform vec2 mouse; //aspect space coordinates
	uniform vec2 lastMouse;
	void main(){
		vec2 v = texture2D(velocity, texelCoord).xy;
		v.xy *= 0.999;
		if(isMouseDown){
			vec2 mouseVelocity = -(lastMouse - mouse)/dt;
			// mouse = mouse - (lastMouse - mouse) * 2.0;//predict mouse position
				
			//compute tapered distance to mouse line segment
			float projection;
			float l = distanceToSegment(mouse, lastMouse, p, projection);
			float taperFactor = 0.6;//1 => 0 at lastMouse, 0 => no tapering
			float projectedFraction = 1.0 - clamp(projection, 0.0, 1.0)*taperFactor;
			float R = 0.015;
			float m = exp(-l/R); //drag coefficient
			m *= projectedFraction * projectedFraction;
			vec2 targetVelocity = mouseVelocity * dx * 1.4;
			v += (targetVelocity - v)*m;
		}
		gl_FragColor = vec4(v, 0, 1.);
	}
')
class MouseForce extends GPUFluid.ApplyForces{}