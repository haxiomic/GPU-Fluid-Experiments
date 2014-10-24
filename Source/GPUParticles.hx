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
	public var flowScaleX(get, set):Float;
	public var flowScaleY(get, set):Float;
	public var flowVelocityField(get, set):GLTexture;

	public var count(default, null):Int;

	var textureQuad:GLBuffer;

	public function new(gl:GLRenderContext, count:Int = 524288){
		this.gl = gl;

		#if js //load floating point texture extension
		gl.getExtension('OES_texture_float');
		#end
		#if !js
		gl.enable(gl.VERTEX_PROGRAM_POINT_SIZE);//enable gl_PointSize (auto enabled in webgl)
		#end

		//quad for writing to textures
		textureQuad = GeometryTools.getCachedTextureQuad();

		//create shaders
		inititalConditionsShader = new InitialConditions();
		stepParticlesShader = new StepParticles();

		//set params
		this.dragCoefficient = 1;
		this.flowScaleX = 1;
		this.flowScaleY = 1;

		//trigger creation of particle textures
		setCount(count);

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

	public function setCount(newCount:Int):Int{
		//setup particle data
		var dataWidth:Int = Math.ceil( Math.sqrt(newCount) );
		var dataHeight:Int = dataWidth;

		//create particle data texture
		if(this.particleData != null){
			this.particleData.resize(dataWidth, dataHeight);
		}else{
			this.particleData = new RenderTarget2Phase(dataWidth, dataHeight, gltoolbox.TextureTools.floatTextureFactoryRGBA);
		}

		
		//create particle vertex buffers that direct vertex shaders to particles to texel coordinates
		if(this.particleUVs != null) gl.deleteBuffer(this.particleUVs);//clear old buffer
		this.particleUVs = gl.createBuffer();

		var arrayUVs = new Array<Float>();
		for(i in 0...dataWidth){
			for(j in 0...dataHeight){
				arrayUVs.push(i/dataWidth);
				arrayUVs.push(j/dataHeight);
			}
		}

		gl.bindBuffer(gl.ARRAY_BUFFER, this.particleUVs);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(arrayUVs), gl.STATIC_DRAW);
		gl.bindBuffer(gl.ARRAY_BUFFER, null);

		return this.count = newCount;
	}

	inline function renderShaderTo(shader:ShaderBase, target:RenderTarget2Phase){
		gl.viewport(0, 0, target.width, target.height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, target.writeFrameBufferObject);

		gl.bindBuffer(gl.ARRAY_BUFFER, textureQuad);

		shader.activate(true, true);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		shader.deactivate();

		target.swap();
	}

	inline function get_dragCoefficient()   return stepParticlesShader.dragCoefficient.data;
	inline function get_flowScaleX()        return stepParticlesShader.flowScale.data.x;
	inline function get_flowScaleY()        return stepParticlesShader.flowScale.data.y;
	inline function get_flowVelocityField() return stepParticlesShader.flowVelocityField.data;

	inline function set_dragCoefficient(v:Float)        return stepParticlesShader.dragCoefficient.data = v;
	inline function set_flowScaleX(v:Float)             return stepParticlesShader.flowScale.data.x = v;
	inline function set_flowScaleY(v:Float)             return stepParticlesShader.flowScale.data.y = v;
	inline function set_flowVelocityField(v:GLTexture)  return stepParticlesShader.flowVelocityField.data = v;
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
class PlaneTexture extends ShaderBase{}

@:frag('
	void main(){
		vec2 ip = vec2((texelCoord.x), (texelCoord.y)) * 2.0 - 1.0;
		vec2 iv = vec2(0,0);
		gl_FragColor = vec4(ip, iv);
	}
')
class InitialConditions extends PlaneTexture{}

@:frag('
	uniform float dt;
	uniform sampler2D particleData;
')
class ParticleBase extends PlaneTexture{}

@:frag('
	uniform float dragCoefficient;
	uniform vec2 flowScale;
	uniform sampler2D flowVelocityField;

	void main(){
		vec2 p = texture2D(particleData, texelCoord).xy;
		vec2 v = texture2D(particleData, texelCoord).zw;

		vec2 vf = texture2D(flowVelocityField, (p+1.)*.5).xy * flowScale;//(converts clip-space p to texel coordinates)
		v += (vf - v) * dragCoefficient;

		p+=dt*v;
		gl_FragColor = vec4(p, v);
	}
')
class StepParticles extends ParticleBase{}

@:vert('
	uniform sampler2D particleData;
	attribute vec2 particleUV;
	varying vec4 color;
	
	void main(){
		vec2 p = texture2D(particleData, particleUV).xy;
		vec2 v = texture2D(particleData, particleUV).zw;
		gl_PointSize = 1.0;
		gl_Position = vec4(p, 0.0, 1.0);

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