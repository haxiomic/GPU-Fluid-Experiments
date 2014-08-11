package;

import haxe.Timer;

import lime.app.Application;
import lime.graphics.opengl.*;
import lime.graphics.GLRenderContext;
import lime.graphics.RenderContext;
import lime.utils.Float32Array;

import shaders.ScreenTextureShader;

class Main extends Application {
	//Shaders
	var screenTextureShader = new ScreenTextureShader();
	//Geometry
	var displayQuad:GLBuffer = null; 
	//Framebuffers
	var screenBuffer:GLFramebuffer = null;	//null for all platforms exlcuding ios, where it references the defaultFramebuffer (UIStageView.mm)

	var fluid:GPUFluid;
	
	public function new () {
		super();
	}
	
	public override function init (context:RenderContext):Void {
		switch (context) {
			case OPENGL (gl):
				initScreenRender(gl);

				fluid = new GPUFluid(gl, Math.round(window.width), Math.round(window.height));
			default:
				trace('RenderContext \'$context\' not supported');
		}
	}

	public override function render (context:RenderContext):Void {
		switch (context) {
			case OPENGL(gl):
				fluid.step(1/60);
				renderTextureToScreen(gl, fluid.dyeRenderTarget.readFromTexture);
			default:
		}
	}

	inline function initScreenRender(gl:GLRenderContext){
		#if ios //grab default screenbuffer
			screenBuffer = new GLFramebuffer(gl.version, gl.getParameter(gl.FRAMEBUFFER_BINDING));
		#end
		displayQuad = gl.createBuffer();
		var vertices:Array<Float> = [
		  	-1.0,-1.0,
		  	 1.0,-1.0,
		  	-1.0, 1.0,

		  	 1.0,-1.0,
		  	 1.0, 1.0,
		  	-1.0, 1.0 
		];

		gl.bindBuffer(gl.ARRAY_BUFFER, displayQuad);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW);
		gl.bindBuffer(gl.ARRAY_BUFFER, null);

		screenTextureShader = new ScreenTextureShader();
	}

	inline function renderTextureToScreen(gl:GLRenderContext, texture:GLTexture){
		gl.viewport (0, 0, window.width, window.height);

		screenTextureShader.texture.data = texture;
		screenTextureShader.activate();

		gl.bindBuffer (gl.ARRAY_BUFFER, displayQuad);
		screenTextureShader.setAttributes();

		gl.bindFramebuffer(gl.FRAMEBUFFER, screenBuffer);
		gl.drawArrays(gl.TRIANGLES, 0, 6);

		screenTextureShader.deactivate();
	}
}