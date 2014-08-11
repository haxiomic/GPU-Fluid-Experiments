package render;

import render.ITargetable;

import lime.graphics.GLRenderContext;
import lime.graphics.opengl.GLFramebuffer;
import lime.graphics.opengl.GLTexture;

class RenderTarget implements ITargetable{
	var gl:GLRenderContext;
	public var width 			 (default, null):Int;
	public var height 			 (default, null):Int;
	public var frameBufferObject (default, null):GLFramebuffer;
	public var texture           (default, null):GLTexture;

	public inline function new(gl:GLRenderContext, texture:Dynamic, width:Int, height:Int){
		//texture is either a GLTexture or a function Void->GLTexture
		this.gl = gl;
		this.width = width;
		this.height = height;
		this.texture = Reflect.isFunction(texture) ? texture(width, height) : texture;

		this.frameBufferObject = gl.createFramebuffer();

		//attach texture to frame buffer object's color component	
		gl.bindFramebuffer(gl.FRAMEBUFFER, this.frameBufferObject);
		gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.texture, 0);

		clear();
	}

	public inline function activate(){
		gl.bindFramebuffer(gl.FRAMEBUFFER, frameBufferObject);
	}

	public inline function clear(){
		gl.bindFramebuffer(gl.FRAMEBUFFER, frameBufferObject);
		//clear white
		gl.clearColor (0, 0, 0, 1);
		gl.clear (gl.COLOR_BUFFER_BIT);
	}
}

