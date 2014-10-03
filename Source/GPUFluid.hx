package;

import gltoolbox.render.RenderTarget2Phase;
import gltoolbox.render.RenderTarget;
import lime.graphics.GLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLTexture;
import lime.math.Vector2;
import lime.utils.Float32Array;
import shaderblox.ShaderBase;

class GPUFluid{
	var gl:GLRenderContext;
	public var width  (default, null) : Int;
	public var height (default, null) : Int;

	public var cellSize (default, set) : Float;
	public var solverIterations         : Int;

	public var aspectRatio (default, null) : Float;

	//Render Targets
	public var velocityRenderTarget   (default, null) : RenderTarget2Phase;
	public var pressureRenderTarget   (default, null) : RenderTarget2Phase;
	public var divergenceRenderTarget (default, null) : RenderTarget;
	public var dyeRenderTarget        (default, null) : RenderTarget2Phase;

	//User Shaders
	public var applyForcesShader (default, set) : ApplyForces;
	public var updateDyeShader   (default, set) : UpdateDye;

	//Internal Shaders
	var advectShader                    : Advect = new Advect();
	var divergenceShader                : Divergence = new Divergence();
	var pressureSolveShader             : PressureSolve = new PressureSolve();
	var pressureGradientSubstractShader : PressureGradientSubstract = new PressureGradientSubstract();

	//Geometry
	var textureQuad : GLBuffer;

	public function new(gl:GLRenderContext, width:Int, height:Int, cellSize:Float = 8, solverIterations:Int = 18){
		this.gl = gl;
		this.width = width;
		this.height = height;
		this.solverIterations = solverIterations;
		this.aspectRatio = this.width/this.height;
		this.cellSize = cellSize;

		var texture_float_linear_supported = true;
		//setup gl
		#if js //load floating point extension
			 //(no need for this unless we use linearFactory - for performance and compatibility, it's best to avoid this extension if possible!)
			if(gl.getExtension('OES_texture_float_linear') == null) texture_float_linear_supported = false;
			if(gl.getExtension('OES_texture_float') == null) null;
		#end

		//geometry
		//	inner quad, for main fluid shaders
		textureQuad = gltoolbox.GeometryTools.getCachedTextureQuad();

		//create texture
		//	seems to run slightly faster with rgba instead of rgb in Chrome?
		var nearestFactory = gltoolbox.TextureTools.createTextureFactory(gl.RGBA, gl.FLOAT , gl.NEAREST);

		velocityRenderTarget = new RenderTarget2Phase(width, height, nearestFactory);
		pressureRenderTarget = new RenderTarget2Phase(width, height, nearestFactory);
		divergenceRenderTarget = new RenderTarget(width, height, nearestFactory);
		dyeRenderTarget = new RenderTarget2Phase(
			width,
			height,
			gltoolbox.TextureTools.createTextureFactory(
				gl.RGB, gl.FLOAT, 
				texture_float_linear_supported ? gl.LINEAR : gl.NEAREST
			)
		);

		//texel-space parameters
		updateCoreShaderUniforms(advectShader);
		updateCoreShaderUniforms(divergenceShader);
		updateCoreShaderUniforms(pressureSolveShader);
		updateCoreShaderUniforms(pressureGradientSubstractShader);
	}

	public function step(dt:Float){
		gl.viewport(0, 0, this.width, this.height);

		//inner quad
		gl.bindBuffer(gl.ARRAY_BUFFER, textureQuad);

		advect(velocityRenderTarget, dt);

		applyForces(dt);

		computeDivergence();
		solvePressure();
		subtractPressureGradient();

		updateDye(dt);
		advect(dyeRenderTarget, dt);
	}

	public inline function resize(width:Int, height:Int){
		velocityRenderTarget.resize(width, height);
		pressureRenderTarget.resize(width, height);
		divergenceRenderTarget.resize(width, height);
		dyeRenderTarget.resize(width, height);
		this.width = width;
		this.height = height;
	}

	public inline function clear(){
		velocityRenderTarget.clear(gl.COLOR_BUFFER_BIT);
		pressureRenderTarget.clear(gl.COLOR_BUFFER_BIT);
		dyeRenderTarget.clear(gl.COLOR_BUFFER_BIT);
	}

	public function simToClipSpaceX(simX:Float) return simX/(this.cellSize * this.aspectRatio);
	public function simToClipSpaceY(simY:Float) return simY/(this.cellSize);

	public inline function advect(target:RenderTarget2Phase, dt:Float){
		advectShader.dt.set(dt);
		//set velocity and texture to be advected
		advectShader.target.set(target.readFromTexture);
		advectShader.velocity.set(velocityRenderTarget.readFromTexture);

		renderShaderTo(advectShader, target);

		target.swap();
	}

	inline function applyForces(dt:Float){
		if(applyForcesShader == null)return;
		//set uniforms
		applyForcesShader.dt.set(dt);
		applyForcesShader.velocity.set(velocityRenderTarget.readFromTexture);
		//render
		renderShaderTo(applyForcesShader, velocityRenderTarget);
		velocityRenderTarget.swap();
	}

	inline function computeDivergence(){
		divergenceShader.velocity.set(velocityRenderTarget.readFromTexture);
		renderShaderTo(divergenceShader, divergenceRenderTarget);
	}

	inline function solvePressure(){
		pressureSolveShader.divergence.set(divergenceRenderTarget.texture);
		pressureSolveShader.activate(true, true);

		for (i in 0...solverIterations) {
			pressureSolveShader.pressure.set(pressureRenderTarget.readFromTexture);
			//(not using renderShaderTo to allow for minor optimization)
			pressureSolveShader.setUniforms();
			pressureRenderTarget.activate();
			gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
			pressureRenderTarget.swap();
		}
		
		pressureSolveShader.deactivate();
	}

	inline function subtractPressureGradient(){
		pressureGradientSubstractShader.pressure.set(pressureRenderTarget.readFromTexture);
		pressureGradientSubstractShader.velocity.set(velocityRenderTarget.readFromTexture);

		renderShaderTo(pressureGradientSubstractShader, velocityRenderTarget);
		velocityRenderTarget.swap();
	}

	inline function updateDye(dt:Float){
		if(updateDyeShader==null)return;
		//set uniforms
		updateDyeShader.dt.set(dt);
		updateDyeShader.dye.set(dyeRenderTarget.readFromTexture);
		//render
		renderShaderTo(updateDyeShader, dyeRenderTarget);
		dyeRenderTarget.swap();
	}

	inline function renderShaderTo(shader:ShaderBase, target:gltoolbox.render.ITargetable){
		shader.activate(true, true);
		target.activate();
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		shader.deactivate();
	}

	inline function updateCoreShaderUniforms(shader:FluidBase){
		if(shader==null)return;
		//set uniforms
		shader.aspectRatio.set(this.aspectRatio);
		shader.invresolution.data.x = 1/this.width;
		shader.invresolution.data.y = 1/this.height;
	}

	inline function set_applyForcesShader(v:ApplyForces):ApplyForces{
		this.applyForcesShader = v;
		this.applyForcesShader.dx.data = this.cellSize;
		updateCoreShaderUniforms(this.applyForcesShader);
		return this.applyForcesShader;
	}

	inline function set_updateDyeShader(v:UpdateDye):UpdateDye{
		this.updateDyeShader = v;
		this.updateDyeShader.dx.data = this.cellSize;
		updateCoreShaderUniforms(this.updateDyeShader);
		return this.updateDyeShader;
	}

	inline function set_cellSize(v:Float):Float{
		//shader specific
		cellSize = v;
		advectShader.rdx.set(1/cellSize);
		divergenceShader.halfrdx.set(0.5*(1/cellSize));
		pressureGradientSubstractShader.halfrdx.set(0.5*(1/cellSize));
		pressureSolveShader.alpha.set(-cellSize*cellSize);
		return cellSize; 
	}
}

@:vert('#pragma include("Source/shaders/glsl/fluid/texel-space.vert")')
@:frag('#pragma include("Source/shaders/glsl/fluid/fluid-base.frag")')
class FluidBase extends ShaderBase{}

@:frag('#pragma include("Source/shaders/glsl/fluid/advect.frag")')
class Advect extends FluidBase{}

@:frag('#pragma include("Source/shaders/glsl/fluid/velocity-divergence.frag")')
class Divergence extends FluidBase{}

@:frag('#pragma include("Source/shaders/glsl/fluid/pressure-solve.frag")')
class PressureSolve extends FluidBase{}

@:frag('#pragma include("Source/shaders/glsl/fluid/pressure-gradient-subtract.frag")')
class PressureGradientSubstract extends FluidBase{}

@:frag('
	uniform sampler2D velocity;
	uniform float dt;
	uniform float dx;

	varying vec2 texelCoord;
	varying vec2 p;
')
class ApplyForces extends FluidBase{}

@:frag('
	uniform sampler2D dye;
	uniform float dt;
	uniform float dx;

	varying vec2 texelCoord;
	varying vec2 p;
')
class UpdateDye extends FluidBase{}