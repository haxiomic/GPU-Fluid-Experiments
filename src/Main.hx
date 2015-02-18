package;

import haxe.Timer;

import snow.render.opengl.GL;
import snow.input.Input;
import snow.types.Types;
import snow.utils.Float32Array;
import snow.window.Window;
import snow.App;
import snow.types.Types;

import gltoolbox.render.RenderTarget;
import shaderblox.ShaderBase;

class Main extends App {
	var gl = GL;
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
	var mouseClipSpace = new Vector2();
	var lastMouse = new Vector2();
	var lastMouseClipSpace = new Vector2();
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

	var window:Window;

	static inline var OFFSCREEN_RENDER = true;//seems to be faster when on!
	
	public function new () {
		super();

		performanceMonitor = new PerformanceMonitor(35, null, 2000);

		simulationQuality = High;

		#if desktop
		simulationQuality = UltraHigh;
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
		config.web.no_context_menu = false;
		#if !desktop
			config.window.borderless = true;
			config.window.fullscreen = true;
		#end
	    return config;
	}

	override function ready(){
		this.window = app.window;

        //hacky work around to make sure we only init after the window dimensions are set
        //#! bug: 
        //	- window dimensions when fullscreen are not set at ready()
        //	- window events are not firing correctly in mac (eg, created not firing)
        var windowInitialized = false;
        this.window.onevent = function(?e:WindowEvent){
        	trace(e.type, WindowEventType.created);
        	switch (e.type) {
        		case WindowEventType.created, WindowEventType.size_changed, WindowEventType.shown:
        			if(!windowInitialized){
						init();
				        this.window.onrender = render;
	        			windowInitialized = true;
        			}
        		default: null;
        	}
        }
	}

	function init():Void {

		gl.disable(gl.DEPTH_TEST);
		gl.disable(gl.CULL_FACE);
		gl.disable(gl.DITHER);

        #if ios screenBuffer = GL.getParameter(GL.FRAMEBUFFER_BINDING); #end

		textureQuad = gltoolbox.GeometryTools.createQuad(0, 0, 1, 1);

		offScreenTarget = new RenderTarget(
			Math.round(window.width*offScreenScale),
			Math.round(window.height*offScreenScale),
			gltoolbox.TextureTools.createTextureFactory(
				gl.RGB,
				gl.UNSIGNED_BYTE,
				offScreenFilter
			)
		);

		screenTextureShader = new ScreenTexture();
		renderParticlesShader = new ColorParticleMotion();
		updateDyeShader = new MouseDye();
		mouseForceShader = new MouseForce();

		updateDyeShader.mouseClipSpace.data = mouseClipSpace;
		updateDyeShader.lastMouseClipSpace.data = lastMouseClipSpace;
		mouseForceShader.mouseClipSpace.data = mouseClipSpace;
		mouseForceShader.lastMouseClipSpace.data = lastMouseClipSpace;

		var cellScale = 32;
		fluid = new GPUFluid(Math.round(window.width*fluidScale), Math.round(window.height*fluidScale), cellScale, fluidIterations);
		fluid.updateDyeShader = updateDyeShader;
		fluid.applyForcesShader = mouseForceShader;

		particles = new GPUParticles(particleCount);
		particles.flowScaleX = fluid.simToClipSpaceX(1);
		particles.flowScaleY = fluid.simToClipSpaceY(1);
		particles.dragCoefficient = 1;

		#if js
		/*
		//Google Analytics
		//on pageview
		untyped ga('send', 'pageview', {
			  'dimension2':  Std.string(gl.getExtension('OES_texture_float_linear') != null),
			  'dimension3':  Std.string(gl.getExtension('OES_texture_float') != null)
		});
		
		var clickCount = 0;
		lime.ui.MouseEventManager.onMouseUp.add(function(x:Float, y:Float, button:Int) clickCount++);
		//after a short time has elapsed
		haxe.Timer.delay(function(){
			var fps = performanceMonitor.fpsAverage;
			untyped ga('set', {
				'metric1': Math.round(fps != null ? fps : 0),
				'metric2': particleCount,
				'metric3': fluidIterations,
				'metric4': fluidScale,
				'metric5': fluid.width * fluid.height,
				'metric6': clickCount,
				'dimension1': Type.enumConstructor(simulationQuality),
			});
		}, 6000);

		//dat.GUI
		//create controls
		var gui = new dat.GUI({autoPlace: true});
		//particle count
		var particleCountGUI = gui.add(particles, 'count').name('Particle Count').listen();
		particleCountGUI.__li.className = particleCountGUI.__li.className+' disabled';
		untyped particleCountGUI.__input.disabled = true;//	disable editing
		//quality
		gui.add(this, 'simulationQuality', Type.allEnums(SimulationQuality)).onChange(function(v){
			js.Browser.window.location.href = StringTools.replace(js.Browser.window.location.href, js.Browser.window.location.search, '') + '?q=' + v;//remove query string
		}).name('Quality').listen();
		//fluid iterations
		gui.add(this, 'fluidIterations', 1, 50).name('Solver Iterations').onChange(function(v) fluidIterations = v);
		//rest particles
		gui.add({f:particles.reset}, 'f').name('Reset Particles');
		//stop fluid
		gui.add({f:fluid.clear}, 'f').name('Stop Fluid');

		//view source
		var viewSourceGUI = gui.add({f:function(){
			js.Browser.window.open('http://github.com/haxiomic/GPU-Fluid-Experiments', '_blank');
		}}, 'f').name('View Source');
		viewSourceGUI.__li.className = 'cr link footer';//remove any other classes
		//	add github icon
		var githubIconEl = js.Browser.document.createElement('span');
		githubIconEl.className = 'icon-github';
		githubIconEl.style.lineHeight = viewSourceGUI.__li.clientHeight + 'px';
		viewSourceGUI.domElement.parentElement.appendChild(githubIconEl);
		// //twitter
		var twitterGUI = gui.add({f:function(){
			js.Browser.window.open('http://twitter.com/haxiomic', '_blank');
		}}, 'f').name('@haxiomic');
		twitterGUI.__li.className = 'cr link footer';//remove any other classes
		// //	add twitter icon
		var twitterIconEl = js.Browser.document.createElement('span');
		twitterIconEl.className = 'icon-twitter';
		twitterIconEl.style.lineHeight = twitterGUI.__li.clientHeight + 'px';
		twitterGUI.domElement.parentElement.appendChild(twitterIconEl);
		*/
		#end

		lastTime = haxe.Timer.stamp();
	}

	function render (?w:snow.window.Window):Void {
		time = haxe.Timer.stamp();
		var dt = time - lastTime; //60fps ~ 0.016
		lastTime = time;

		// performanceMonitor.recordFrameTime(dt);

		//update mouse velocity
		if(lastMousePointKnown){
			updateDyeShader.isMouseDown.set(isMouseDown);
			mouseForceShader.isMouseDown.set(isMouseDown);
		}

		//step physics
		fluid.step(dt);

		particles.flowVelocityField = fluid.velocityRenderTarget.readFromTexture;
		if(renderParticlesEnabled) particles.step(dt);

		//render to offScreen
		if(OFFSCREEN_RENDER){
			gl.viewport (0, 0, offScreenTarget.width, offScreenTarget.height);
			gl.bindFramebuffer(gl.FRAMEBUFFER, offScreenTarget.frameBufferObject);
		}else{
			gl.viewport (0, 0, window.width, window.height);
			gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);
		}

		gl.clearColor(0,0,0,1);
		gl.clear(gl.COLOR_BUFFER_BIT);

		// additive blending
		gl.enable(gl.BLEND);
		gl.blendFunc( gl.SRC_ALPHA, gl.SRC_ALPHA );
		gl.blendEquation(gl.FUNC_ADD);

		if(renderParticlesEnabled) renderParticles();
		if(renderFluidEnabled) renderTexture(fluid.dyeRenderTarget.readFromTexture);

		gl.disable(gl.BLEND);

		//render offScreen texture to screen
		if(OFFSCREEN_RENDER){
			gl.viewport (0, 0, window.width, window.height);
			gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);
			renderTexture(offScreenTarget.texture);
		}

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
		gl.drawArrays(gl.POINTS, 0, particles.count);
		renderParticlesShader.deactivate();
	}

	function updateSimulationTextures(){
		//only resize if there is a change
		var w:Int, h:Int;
		w = Math.round(window.width*fluidScale); h = Math.round(window.height*fluidScale);
		if(w != fluid.width || h != fluid.height) fluid.resize(w, h);

		w = Math.round(window.width*offScreenScale); h = Math.round(window.height*offScreenScale);
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
				particleCount = 1 << 16;
				fluidScale = 1/10;
				fluidIterations = 8;
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
	inline function windowToClipSpaceX(x:Float)return (x/window.width)*2 - 1;
	inline function windowToClipSpaceY(y:Float)return ((window.height-y)/window.height)*2 - 1;

	#if !mobile
	override function onmousedown( x : Float , y : Float , button : Int, _, _){
		this.isMouseDown = true; 
	}
	override function onmouseup( x : Float , y : Float , button : Int, _, _){
		this.isMouseDown = false;
	}

	override function onmousemove( x : Float , y : Float , xrel:Int, yrel:Int, _, _) {
		mouse.set(x, y);
		mouseClipSpace.set(
			windowToClipSpaceX(x),
			windowToClipSpaceY(y)
		);
		mousePointKnown = true;
	}
	#end

	function updateTouchCoordinate(x:Float, y:Float){
		x = x*window.width;
		y = y*window.height;
		mouse.set(x, y);
		mouseClipSpace.set(
			windowToClipSpaceX(x),
			windowToClipSpaceY(y)
		);
		mousePointKnown = true;
	}
	override function ontouchdown(x,y,_,_){
		updateTouchCoordinate(x,y);
		updateLastMouse();
		this.isMouseDown = true; 
	}

	override function ontouchup(x,y,_,_){
		updateTouchCoordinate(x,y);
		this.isMouseDown = false;
	}

	override function ontouchmove(x:Float,y:Float,_,_,_,_){
		updateTouchCoordinate(x,y);
	}


	inline function updateLastMouse(){
		lastMouse.set(mouse.x, mouse.y);
		lastMouseClipSpace.set(
			windowToClipSpaceX(mouse.x),
			windowToClipSpaceY(mouse.y)
		);
		lastMousePointKnown = true && mousePointKnown;
	}


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

typedef Vector2 = shaderblox.uniforms.UVec2.Vector2;

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
	void main(){
		vec2 p = texture2D(particleData, particleUV).xy;
		vec2 v = texture2D(particleData, particleUV).zw;
		gl_PointSize = 1.0;
		gl_Position = vec4(p, 0.0, 1.0);
		float speed = length(v);
		float x = clamp(speed * 1.0, 0., 1.);
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
	uniform vec2 mouseClipSpace;
	uniform vec2 lastMouseClipSpace;

	void main(){
		vec4 color = texture2D(dye, texelCoord);

		color.r *= (0.9797);
		color.g *= (0.9494);
		color.b *= (0.9696);
		if(isMouseDown){			
			vec2 mouse = clipToSimSpace(mouseClipSpace);
			vec2 lastMouse = clipToSimSpace(lastMouseClipSpace);
			vec2 mouseVelocity = -(lastMouse - mouse)/dt;
			
			//compute tapered distance to mouse line segment
			float projection;
			float l = distanceToSegment(mouse, lastMouse, p, projection);
			float taperFactor = 0.6;
			float projectedFraction = 1.0 - clamp(projection / distance(mouse, lastMouse), 0.0, 1.0)*taperFactor;

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
	uniform vec2 mouseClipSpace;
	uniform vec2 lastMouseClipSpace;

	void main(){
		vec2 v = texture2D(velocity, texelCoord).xy;

		v.xy *= 0.999;

		if(isMouseDown){
			vec2 mouse = clipToSimSpace(mouseClipSpace) ;
			vec2 lastMouse = clipToSimSpace(lastMouseClipSpace);
			vec2 mouseVelocity = -(lastMouse - mouse)/dt;

			// mouse = mouse - (lastMouse - mouse) * 2.0;//predict mouse position
				
			//compute tapered distance to mouse line segment
			float projection;
			float l = distanceToSegment(mouse, lastMouse, p, projection);
			float taperFactor = 0.6;//1 => 0 at lastMouse, 0 => no tapering
			float projectedFraction = 1.0 - clamp(projection / distance(mouse, lastMouse), 0.0, 1.0)*taperFactor;

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