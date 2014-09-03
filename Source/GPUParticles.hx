package;

import gltoolbox.GeometryTools;
import gltoolbox.render.RenderTarget2Phase;
import lime.graphics.GLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLTexture;
import lime.math.Vector2;
import lime.utils.Float32Array;
import shaderblox.ShaderBase;

class GPUParticles{
	var gl:GLRenderContext;

	public var particleData:RenderTarget2Phase;
	public var particleUVs:GLBuffer;

	public var inititalConditionsShader:InitialConditions;
	public var stepParticlesShader:StepParticles;

	public var dragCoefficient(get, set):Float;
	public var flowScale(get, set):Float;
	public var flowEnabled(get, set):Bool;
	public var flowVelocityField(get, set):GLTexture;

	var textureQuad:GLBuffer;

	public function new(gl:GLRenderContext, max:Int = 524288){
		this.gl = gl;

		#if js //load floating point texture extension
		gl.getExtension('OES_texture_float');
		#end
		#if !js
		gl.enable(gl.VERTEX_PROGRAM_POINT_SIZE);//enable gl_PointSize (auto enabled in webgl)
		#end

		//quad for writing to textures
		textureQuad = GeometryTools.createQuad(gl, 0, 0, 1, 1);

		//setup particle data
		var dataWidth:Int = Math.ceil( Math.sqrt(max) );
		var dataHeight:Int = dataWidth;

		//create particle data texture
		particleData = new RenderTarget2Phase(gl, gltoolbox.TextureTools.floatTextureFactoryRGBA, dataWidth, dataHeight);

		//create particle vertex buffers
		var arrayUVs = new Array<Float>();
		for(i in 0...dataWidth){
			for(j in 0...dataHeight){
				arrayUVs.push(i/dataWidth);
				arrayUVs.push(j/dataHeight);
			}
		}

		particleUVs = gl.createBuffer();
		gl.bindBuffer(gl.ARRAY_BUFFER, particleUVs);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(arrayUVs), gl.STATIC_DRAW);
		gl.bindBuffer(gl.ARRAY_BUFFER, null);

		//create shaders
		inititalConditionsShader = new InitialConditions();
		stepParticlesShader = new StepParticles();

		//set params
		this.dragCoefficient = 1;
		this.flowScale = 1;
		this.flowEnabled = false;

		//write initial data
		reset();
	}

	public inline function step(dt:Float){
		//set position and velocity uniforms
		stepParticlesShader.dt.data = dt;

		stepParticlesShader.particleData.data = particleData.readFromTexture;
		renderShaderTo(stepParticlesShader, particleData);
	}

	public inline function reset(){
		renderShaderTo(inititalConditionsShader, particleData);
	}

	inline function renderShaderTo(shader:ShaderBase, target:RenderTarget2Phase){
		gl.viewport(0, 0, target.width, target.height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, target.writeFrameBufferObject);

		gl.clearColor(0,0,0,1);
		gl.clear(gl.COLOR_BUFFER_BIT);

		gl.bindBuffer(gl.ARRAY_BUFFER, textureQuad);

		shader.activate(true, true);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		shader.deactivate();

		target.swap();
	}


	inline function get_dragCoefficient()   return stepParticlesShader.dragCoefficient.data;
	inline function get_flowScale()         return stepParticlesShader.flowScale.data;
	inline function get_flowEnabled()       return stepParticlesShader.flowEnabled.data;
	inline function get_flowVelocityField() return stepParticlesShader.flowVelocityField.data;

	inline function set_dragCoefficient(v:Float)       return stepParticlesShader.dragCoefficient.data = v;
	inline function set_flowScale(v:Float)             return stepParticlesShader.flowScale.data = v;
	inline function set_flowEnabled(v:Bool)            return stepParticlesShader.flowEnabled.data = v;
	inline function set_flowVelocityField(v:GLTexture){
		if(v!=null)	this.flowEnabled = true;
		else 		this.flowEnabled = false;
		return stepParticlesShader.flowVelocityField.data = v;
	}
}

@:vert('
	attribute vec2 vertexPosition;
	varying vec2 texelCoord;

	void main(){
		texelCoord = vertexPosition;
		gl_Position = vec4(vertexPosition*2.0 - vec2(1.0, 1.0), 0.0, 1.0 );//converts to clip space	
	}
')
@:frag('
	varying vec2 texelCoord;
')
class TextureShader extends ShaderBase{}

@:frag('
	void main(){
		vec2 ip = vec2((texelCoord.x)*2.0-1.0, (texelCoord.y)*2.0 - 1.0);
		vec2 iv = vec2(0,0);
		gl_FragColor = vec4(ip, iv);
	}
')
class InitialConditions extends TextureShader{}

@:frag('
	uniform float dt;
	uniform sampler2D particleData;

	vec2 p = texture2D(particleData, texelCoord).xy;
	vec2 v = texture2D(particleData, texelCoord).zw;
')
class ParticleBase extends TextureShader{}

@:frag('
	uniform bool flowEnabled;
	uniform float dragCoefficient;
	uniform float flowScale;
	uniform sampler2D flowVelocityField;

	void main(){
		if(flowEnabled){
			vec2 vf = texture2D(flowVelocityField, (p+1.)*.5).xy * flowScale;//(converts clip-space p to texel coordinates)
			v += (vf - v) * dragCoefficient;
		}

		p+=dt*v;
		gl_FragColor = vec4(p, v);
	}
')
class StepParticles extends ParticleBase{}

@:vert('
	uniform sampler2D particleData;
	attribute vec2 particleUV;
	varying vec4 color;

	vec2 p = texture2D(particleData, particleUV).xy;
	vec2 v = texture2D(particleData, particleUV).zw;
	
	void set(){
		gl_PointSize = 1.0;
		gl_Position = vec4(p, 0.0, 1.0);
	}

	void main(){
		set();

		color = vec4(1.0, 1.0, 1.0, 1.0);
	}
')
@:frag('
	varying vec4 color;

	void main(){
		gl_FragColor = vec4(color);
	}
')
class RenderParticles extends ShaderBase{}