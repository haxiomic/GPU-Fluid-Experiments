/*
TODO
* Remove FlowVelocityField (or add it as optional with a const bool)
* Ensure POT textures by choosing dimensions carefully from the count
 	(eg: change: var dataWidth:Int = Math.ceil( Math.sqrt(newCount) );)
 	* currently requiring POT square, we need an alogo to find nearest pot rectangle
*/


package;

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

import gltoolbox.GeometryTools;
import gltoolbox.render.RenderTarget2Phase;
import shaderblox.ShaderBase;


class GPUParticles{
	// var gl = GL;

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

	public function new(count:Int){
		#if js //load floating point texture extension
		GL.getExtension('OES_texture_float');
		#end
		#if !js
		GL.enable(GL.VERTEX_PROGRAM_POINT_SIZE);//enable gl_PointSize (always enabled in webgl)
		#end

		//quad for writing to textures
		textureQuad = GeometryTools.getCachedUnitQuad();

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
			this.particleData = new RenderTarget2Phase(dataWidth, dataHeight, gltoolbox.TextureTools.createFloatTextureRGBA);
		}

		//create particle vertex buffers that direct vertex shaders to particles to texel coordinates
		if(this.particleUVs != null) GL.deleteBuffer(this.particleUVs);//clear old buffer

		this.particleUVs = GL.createBuffer();

		var arrayUVs = new Float32Array(dataWidth*dataHeight*2);//flattened by columns
		var index:Int;
		for(i in 0...dataWidth){
			for(j in 0...dataHeight){
				index = (i*dataHeight + j)*2;
				arrayUVs[index] = i/dataWidth;
				arrayUVs[++index] = j/dataHeight;
			}
		}

		GL.bindBuffer(GL.ARRAY_BUFFER, this.particleUVs);
		GL.bufferData(GL.ARRAY_BUFFER, arrayUVs, GL.STATIC_DRAW);
		GL.bindBuffer(GL.ARRAY_BUFFER, null);

		return this.count = newCount;
	}

	inline function renderShaderTo(shader:ShaderBase, target:RenderTarget2Phase){
		GL.viewport(0, 0, target.width, target.height);
		GL.bindFramebuffer(GL.FRAMEBUFFER, target.writeFrameBufferObject);

		GL.bindBuffer(GL.ARRAY_BUFFER, textureQuad);

		shader.activate(true, true);
		GL.drawArrays(GL.TRIANGLE_STRIP, 0, 4);
		shader.deactivate();

		target.swap();
	}

	inline function get_dragCoefficient()   return stepParticlesShader.dragCoefficient.data;
	inline function get_flowScaleX()         return stepParticlesShader.flowScale.data.x;
	inline function get_flowScaleY()         return stepParticlesShader.flowScale.data.y;
	inline function get_flowVelocityField() return stepParticlesShader.flowVelocityField.data;

	inline function set_dragCoefficient(v:Float)       return stepParticlesShader.dragCoefficient.data = v;
	inline function set_flowScaleX(v:Float)             return stepParticlesShader.flowScale.data.x = v;
	inline function set_flowScaleY(v:Float)             return stepParticlesShader.flowScale.data.y = v;
	inline function set_flowVelocityField(v:GLTexture){
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

		p += dt*v;
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