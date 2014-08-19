package;

import haxe.Timer;

import lime.app.Application;
import lime.graphics.opengl.*;
import lime.graphics.GLRenderContext;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.utils.Float32Array;
import shaderblox.ShaderBase;

class Main extends Application {
	var gl:GLRenderContext;
	//Shaders
	var screenTextureShader = new ScreenTexture();
	var renderParticlesShader = new ColorParticleMotion();
	//Geometry
	var textureQuad:GLBuffer = null; 
	//Framebuffers
	var screenBuffer:GLFramebuffer = null;	//null for all platforms exlcuding ios, where it references the defaultFramebuffer (UIStageView.mm)

	var fluid:GPUFluid;
	var particles:GPUParticles;
	
	public function new () {
		super();
	}
	
	public override function init (context:RenderContext):Void {
		switch (context) {
			case OPENGL (gl):
				this.gl = gl;
				#if ios //grab default screenbuffer
					screenBuffer = new GLFramebuffer(gl.version, gl.getParameter(gl.FRAMEBUFFER_BINDING));
				#end
				textureQuad = gltoolbox.GeometryTools.createQuad(gl, 0, 0, 1, 1);

				screenTextureShader = new ScreenTexture();
				renderParticlesShader = new ColorParticleMotion();

				fluid = new GPUFluid(gl, Math.round(window.width), Math.round(window.height));
				particles = new GPUParticles(gl);
			default:
				trace('RenderContext \'$context\' not supported');
		}
	}

	public override function render (context:RenderContext):Void {
		fluid.step(1/60);

		particles.flowVelocityField = fluid.velocityRenderTarget.readFromTexture;
		particles.step(1/60);

		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);
		gl.clearColor(0,0,0,1);
		gl.clear(gl.COLOR_BUFFER_BIT);

		// renderTextureToScreen(fluid.dyeRenderTarget.readFromTexture);
		renderParticlesToScreen();
	}

	inline function renderTextureToScreen(texture:GLTexture){
		gl.viewport (0, 0, window.width, window.height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);

		gl.bindBuffer (gl.ARRAY_BUFFER, textureQuad);

		screenTextureShader.texture.data = texture;
		
		screenTextureShader.activate(true, true);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		screenTextureShader.deactivate();
	}

	inline function renderParticlesToScreen():Void{
		gl.viewport(0, 0, window.width, window.height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);

		//set vertices
		gl.bindBuffer(gl.ARRAY_BUFFER, particles.particleUVs);

		//set uniforms
		renderParticlesShader.particleData.data = particles.particleData.readFromTexture;

		//draw points
		renderParticlesShader.activate(true, true);
		gl.enable(gl.BLEND);
		gl.blendFunc( gl.SRC_ALPHA, gl.SRC_ALPHA );
		gl.blendEquation(gl.FUNC_ADD);
		gl.drawArrays(gl.POINTS, 0, particles.particleData.width*particles.particleData.height);
		gl.disable(gl.BLEND);
		renderParticlesShader.deactivate();
	}

	override function onKeyUp( keyCode : Int , modifier : Int ){
		switch (keyCode) {
			case KeyCode.R:
				trace('reset');
				particles.reset();
		}
	}
}


@:vert('#pragma include("Source/shaders/glsl/no-transform.vert")')
@:frag('#pragma include("Source/shaders/glsl/quad-texture.frag")')
class ScreenTexture extends ShaderBase {}

@:vert('
	void main(){
		//generate color
		vec2 v = texture2D(particleData, particleUV).ba;
		float lv = length(v);
		vec3 cvec = vec3(sin(lv/3.0)*1.5-lv*lv*0.7, lv*lv*30.0, lv+lv*lv*10.0);
		color = vec4(vec3(0.5, 0.3, 0.13)*0.3+cvec*1., 1.);

		set();
	}
')
class ColorParticleMotion extends GPUParticles.RenderParticles{}