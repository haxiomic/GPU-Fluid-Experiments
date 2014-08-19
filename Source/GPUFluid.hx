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

	var cellSize = 8;
	var pressureIterations = 20;

	//Render Targets
	public var dyeRenderTarget        (default, null) : RenderTarget2Phase;
	public var velocityRenderTarget   (default, null) : RenderTarget2Phase;
	public var pressureRenderTarget   (default, null) : RenderTarget2Phase;
	public var divergenceRenderTarget (default, null) : RenderTarget;

	//Shaders
	var advectShader                    : AdvectShader;
	var applyForcesShader               : ApplyForcesShader;
	var divergenceShader                : DivergenceShader;
	var pressureSolveShader             : PressureSolveShader;
	var pressureGradientSubstractShader : PressureGradientSubstractShader;

	//Geometry
	var innerQuadBuffer:GLBuffer;
	var boundaryBuffer:GLBuffer;

	public function new(gl:GLRenderContext, width:Int, height:Int){
		this.gl = gl;
		this.width = width;
		this.height = height;

		//setup gl
		#if js //load floating point extension
			gl.getExtension('OES_texture_float');
		#end

		//geometry
		//	inner quad, for main fluid shaders
		innerQuadBuffer = gl.createBuffer();
		gl.bindBuffer(gl.ARRAY_BUFFER, innerQuadBuffer);
		gl.bufferData(gl.ARRAY_BUFFER, innerQuadArray(this.width, this.height), gl.STATIC_DRAW);
		//	1px boundary for boundary shader
		boundaryBuffer = gl.createBuffer();
		gl.bindBuffer(gl.ARRAY_BUFFER, boundaryBuffer);
		gl.bufferData(gl.ARRAY_BUFFER, boundaryArray(this.width, this.height), gl.STATIC_DRAW);

		//create texture
		var simulationTextureFactory = function(gl:GLRenderContext, width:Int, height:Int):GLTexture{
			//create basic non-power of two texture
			var type = gl.RGB;
			var dataKind = gl.FLOAT;
			#if ios dataKind = 0x8D61; #end//GL_HALF_FLOAT_OES for iOS, as most don't seem to support GL_FLOAT
			var filter = gl.NEAREST;

			var tex:GLTexture = gl.createTexture();
			gl.bindTexture (gl.TEXTURE_2D, tex);

			//set params
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter); 
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter); 
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

			gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
			//set data
			gl.texImage2D (gl.TEXTURE_2D, 0, type, width, height, 0, type, dataKind, null);
			return tex;
		}

		dyeRenderTarget = new RenderTarget2Phase(gl, simulationTextureFactory, width, height);
		velocityRenderTarget = new RenderTarget2Phase(gl, simulationTextureFactory, width, height);
		pressureRenderTarget = new RenderTarget2Phase(gl, simulationTextureFactory, width, height);
		divergenceRenderTarget = new RenderTarget(gl, simulationTextureFactory, width, height);

		//create shaders
		advectShader = new AdvectShader();
		applyForcesShader = new ApplyForcesShader();
		divergenceShader = new DivergenceShader();
		pressureSolveShader = new PressureSolveShader();
		pressureGradientSubstractShader = new PressureGradientSubstractShader();

		//set uniforms
		var invWidth:Float = 1/this.width;
		var invHeight:Float = 1/this.height;
		var aspectRatio = width/height;

		var invresolution = new Vector2(1/this.width , 1/this.height);

		advectShader.invresolution.set(invresolution);
		applyForcesShader.invresolution.set(invresolution); 
		divergenceShader.invresolution.set(invresolution); 
		pressureSolveShader.invresolution.set(invresolution); 
		pressureGradientSubstractShader.invresolution.set(invresolution); 

		advectShader.aspectRatio.set(aspectRatio);
		applyForcesShader.aspectRatio.set(aspectRatio); 
		divergenceShader.aspectRatio.set(aspectRatio); 
		pressureSolveShader.aspectRatio.set(aspectRatio); 
		pressureGradientSubstractShader.aspectRatio.set(aspectRatio);

		advectShader.rdx.set(1/cellSize);
		divergenceShader.halfrdx.set(0.5*(1/cellSize));
		pressureGradientSubstractShader.halfrdx.set(0.5*(1/cellSize));
		pressureSolveShader.alpha.set(-cellSize*cellSize);
	}

	public function step(dt:Float){
		gl.viewport(0,0,width,height);
		gl.lineWidth(1.0);

		//inner quad
		gl.bindBuffer(gl.ARRAY_BUFFER, innerQuadBuffer);

		advect(velocityRenderTarget, dt);
		advect(dyeRenderTarget, dt);

		applyUserInteraction(dt);

		computeDivergence();
		solvePressure();
		subtractPressureGradient();
	}

	inline function advect(target:RenderTarget2Phase, dt:Float){
		advectShader.dt.set(dt);
		//set velocity and texture to be advected
		advectShader.target.set(target.readFromTexture);
		advectShader.velocity.set(velocityRenderTarget.readFromTexture);

		renderShaderTo(advectShader, target);

		target.swap();
	}

	inline function applyUserInteraction(dt:Float){
		//mouse force
		var time = haxe.Timer.stamp();

		applyForcesShader.velocity.set(velocityRenderTarget.readFromTexture);
		applyForcesShader.time.set(time);

		applyForcesShader.mouse.data.x = Math.cos(time/2)*.8;
		applyForcesShader.mouse.data.y = Math.sin(time/Math.exp(1))*.8;

		renderShaderTo(applyForcesShader, velocityRenderTarget);

		velocityRenderTarget.swap();

		//mouse dye
		applyForcesShader.velocity.set(dyeRenderTarget.readFromTexture);
		applyForcesShader.time.set(time);

		applyForcesShader.mouse.data.x = Math.cos(time/2)*.8;
		applyForcesShader.mouse.data.y = Math.sin(time/Math.exp(1))*.8;

		renderShaderTo(applyForcesShader, dyeRenderTarget);

		dyeRenderTarget.swap();
	}

	inline function computeDivergence(){
		divergenceShader.field.set(velocityRenderTarget.readFromTexture);
		renderShaderTo(divergenceShader, divergenceRenderTarget);
	}

	inline function solvePressure(){
		pressureSolveShader.divergence.set(divergenceRenderTarget.texture);
		pressureSolveShader.activate(true, true);

		// pressureRenderTarget.clearRead();
		for (i in 0...pressureIterations) {
			pressureSolveShader.pressure.set(pressureRenderTarget.readFromTexture);
			//(not using renderShaderTo to allow for optimization)
			pressureSolveShader.setUniforms();
			pressureRenderTarget.activate();
			gl.drawArrays(gl.TRIANGLES, 0, 6);
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

	inline function renderShaderTo(shader:ShaderBase, target:gltoolbox.render.ITargetable){
		shader.activate(true, true);
		target.activate();
		gl.drawArrays(gl.TRIANGLES, 0, 6);
		shader.deactivate();
	}

	//Static Geometry
	function innerQuadArray(width:Int, height:Int)return new Float32Array(//absolute coordinates wrt texture size (not unit)
		[
			1.0, 	   1.0,
			width-1.0, 1.0,
			1.0,	   height-1.0,

			width-1.0, 1.0,
			width-1.0, height-1.0,
			1.0, 	   height-1.0
		]
	);
	function boundaryArray(width:Int, height:Int)return new Float32Array(//OGL centers lines on the boundary between pixels
		[
	     0.5      , 0,          0.5,       height,     //left
	     0        , height-0.5, width,     height-0.5, //top
	     width-0.5, height,     width-0.5, 0,          //right
	     width    , 0.5,        0,         0.5         //bottom
		]
	);
}

@:vert('#pragma include("Source/shaders/glsl/fluid/texel-space.vert")')
@:frag('#pragma include("Source/shaders/glsl/fluid/advect.frag")')
class AdvectShader extends ShaderBase{}

@:vert('#pragma include("Source/shaders/glsl/fluid/texel-space.vert")')
@:frag('#pragma include("Source/shaders/glsl/fluid/apply-forces.frag")')
class ApplyForcesShader extends ShaderBase{}

@:vert('#pragma include("Source/shaders/glsl/fluid/texel-space.vert")')
@:frag('#pragma include("Source/shaders/glsl/fluid/divergence.frag")')
class DivergenceShader extends ShaderBase{}

@:vert('#pragma include("Source/shaders/glsl/fluid/texel-space.vert")')
@:frag('#pragma include("Source/shaders/glsl/fluid/pressure-solve.frag")')
class PressureSolveShader extends ShaderBase{}

@:vert('#pragma include("Source/shaders/glsl/fluid/texel-space.vert")')
@:frag('#pragma include("Source/shaders/glsl/fluid/pressure-gradient-subtract.frag")')
class PressureGradientSubstractShader extends ShaderBase{}