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

	public var cellSize (default, null) : Float;
	public var solverIterations         : Int;

	var aspectRatio:Float;

	//Render Targets
	public var velocityRenderTarget   (default, null) : RenderTarget2Phase;
	public var pressureRenderTarget   (default, null) : RenderTarget2Phase;
	public var divergenceRenderTarget (default, null) : RenderTarget;
	public var dyeRenderTarget        (default, null) : RenderTarget2Phase;

	//Public Shaders
	public var applyForcesShader (default, set) : ApplyForces;
	public var updateDyeShader   (default, set) : UpdateDye;

	//Internal Shaders
	var advectShader                    : Advect;
	var divergenceShader                : Divergence;
	var pressureSolveShader             : PressureSolve;
	var pressureGradientSubstractShader : PressureGradientSubstract;

	//Geometry
	var renderQuad : GLBuffer;

	public function new(gl:GLRenderContext, width:Int, height:Int, cellSize:Float = 8, solverIterations:Int = 18){
		this.gl = gl;
		this.width = width;
		this.height = height;
		this.cellSize = cellSize;
		this.solverIterations = solverIterations;
		this.aspectRatio = this.width/this.height;

		//setup gl
		#if js //load floating point extension
			gl.getExtension('OES_texture_float_linear');
			gl.getExtension('OES_texture_float');
		#end

		//geometry
		//	inner quad, for main fluid shaders
		renderQuad = gltoolbox.GeometryTools.createQuad(gl, 0, 0, width, height, gl.TRIANGLE_STRIP);

		//create texture
		//seems to run fast with rgba instead of rgb
		var linearFactory = gltoolbox.TextureTools.customTextureFactory(gl.RGBA, gl.FLOAT , gl.LINEAR);
		var nearestFactory = gltoolbox.TextureTools.customTextureFactory(gl.RGBA, gl.FLOAT , gl.NEAREST);

		velocityRenderTarget = new RenderTarget2Phase(gl, linearFactory, width, height);
		pressureRenderTarget = new RenderTarget2Phase(gl, nearestFactory, width, height);
		divergenceRenderTarget = new RenderTarget(gl, nearestFactory, width, height);
		dyeRenderTarget = new RenderTarget2Phase(gl, linearFactory, width, height);

		//create shaders
		advectShader = new Advect();
		divergenceShader = new Divergence();
		pressureSolveShader = new PressureSolve();
		pressureGradientSubstractShader = new PressureGradientSubstract();

		//texel-space parameters
		passBaseUniforms(advectShader);
		passBaseUniforms(divergenceShader);
		passBaseUniforms(pressureSolveShader);
		passBaseUniforms(pressureGradientSubstractShader);

		//shader specific
		advectShader.rdx.set(1/cellSize);
		divergenceShader.halfrdx.set(0.5*(1/cellSize));
		pressureGradientSubstractShader.halfrdx.set(0.5*(1/cellSize));
		pressureSolveShader.alpha.set(-cellSize*cellSize);
	}

	public function step(dt:Float){
		gl.viewport(0,0,width,height);

		//inner quad
		gl.bindBuffer(gl.ARRAY_BUFFER, renderQuad);

		advect(velocityRenderTarget, dt);

		applyForces(dt);

		computeDivergence();
		solvePressure();
		subtractPressureGradient();

		updateDye(dt);
		advect(dyeRenderTarget, dt);
	}

	inline function advect(target:RenderTarget2Phase, dt:Float){
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

	inline function passBaseUniforms(shader:FluidBase){
		if(shader==null)return;
		//set uniforms
		shader.aspectRatio.set(aspectRatio);
		shader.invresolution.data.x = 1/width;
		shader.invresolution.data.y = 1/height;
	}

	inline function set_applyForcesShader(v:ApplyForces):ApplyForces{
		this.applyForcesShader = v;
		this.applyForcesShader.dx.data = this.cellSize;
		passBaseUniforms(this.applyForcesShader);
		return this.applyForcesShader;
	}

	inline function set_updateDyeShader(v:UpdateDye):UpdateDye{
		this.updateDyeShader = v;
		this.updateDyeShader.dx.data = this.cellSize;
		passBaseUniforms(this.updateDyeShader);
		return this.updateDyeShader;
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

	vec2 v = texture2D(velocity, texelCoord).xy;
')
class ApplyForces extends FluidBase{}

@:frag('
	uniform sampler2D dye;
	uniform float dt;
	uniform float dx;

	varying vec2 texelCoord;
	varying vec2 p;

	vec4 color = texture2D(dye, texelCoord);
')
class UpdateDye extends FluidBase{}