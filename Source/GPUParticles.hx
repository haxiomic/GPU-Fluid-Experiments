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

	public var flowVelocityField:GLTexture;

	var textureQuad:GLBuffer;

	public function new(gl:GLRenderContext /*, max:Int*/){
		this.gl = gl;
		//we'll need floating point textures
		#if js //load floating point extension
		gl.getExtension('OES_texture_float');
		#end
		#if !js
		gl.enable(gl.VERTEX_PROGRAM_POINT_SIZE);//enable gl_PointSize (auto enabled in webgl)
		#end

		//quad for writing to textures
		textureQuad = GeometryTools.createQuad(gl, 0, 0, 1, 1);

		//setup particle data
		var dataWidth:Int = 1024;
		var dataHeight:Int = dataWidth;

		//create particle data texture
		particleData = new RenderTarget2Phase(gl, gltoolbox.TextureTools.FloatTextureFactoryRGBA, dataWidth, dataHeight);

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

		//write initial data
		reset();
	}

	@:noStack
	public inline function step(dt:Float){
		//set position and velocity uniforms
		stepParticlesShader.dt.data = dt;

		stepParticlesShader.particleData.data = particleData.readFromTexture;
		stepParticlesShader.advectEnabled.data = (flowVelocityField != null);
		stepParticlesShader.flowVelocityField.data = flowVelocityField;

		renderShader(stepParticlesShader, particleData);
	}

	public inline function reset(){
		renderShader(inititalConditionsShader, particleData);
	}

	inline function renderShader(shader:ShaderBase, target:RenderTarget2Phase){
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
}

@:vert('
	attribute vec2 vertexPosition;
	varying vec2 texelCoord;

	void main() {
		texelCoord = vertexPosition;
		gl_Position = vec4(vertexPosition*2.0 - vec2(1.0, 1.0), 0.0, 1.0 );//converts to clip space	
	}
')
@:frag('
	varying vec2 texelCoord;
')
class TextureShader extends ShaderBase{}

@:frag('
	uniform float dt;
	uniform sampler2D particleData;

	vec2 p = texture2D(particleData, texelCoord).rg;
	vec2 v = texture2D(particleData, texelCoord).ba;
')
class ParticleBase extends TextureShader{}

@:frag('
	void main(){
		vec2 ip = vec2((texelCoord.x)*2.0-1.0, (texelCoord.y)*2.-1.);
		vec2 iv = vec2(0,0);
		gl_FragColor = vec4(ip, iv);
	}
')
class InitialConditions extends TextureShader{}

@:frag('
	uniform bool advectEnabled;
	uniform float dragCoefficient;
	uniform sampler2D flowVelocityField;

	void main(){
		if(advectEnabled){
			vec2 vf = texture2D(flowVelocityField, (p+1.)*.5).rg*(1./8.);
			vec2 dv = vf - v;
			// v+=dv*dt*2.;
			v = vf;
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

	vec2 p = texture2D(particleData, particleUV).rg;
	vec2 v = texture2D(particleData, particleUV).ba;
	
	void set();

	void main(){
		color = vec4(1.0, 1.0, 1.0, 1.0);
		set();
	}

	void set(){
		gl_PointSize = 1.0;
		gl_Position = vec4(p, 0.0, 1.0);
	}
')
@:frag('
	varying vec4 color;

	void main(){
		gl_FragColor = vec4(color);
	}
')
class RenderParticles extends ShaderBase{}