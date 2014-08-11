package render;

import lime.graphics.GLRenderContext;
import lime.graphics.opengl.GLFramebuffer;
import lime.graphics.opengl.GLTexture;

class RenderTarget2Phase implements ITargetable{
	var gl:GLRenderContext;
	public var width 			 (default, null):Int;
	public var height 			 (default, null):Int;
	public var writeFrameBufferObject (default, null):GLFramebuffer;
	public var writeToTexture         (default, null):GLTexture;
	public var readFrameBufferObject  (default, null):GLFramebuffer;
	public var readFromTexture        (default, null):GLTexture;

	public inline function new(gl:GLRenderContext, textureFactory:Int->Int->GLTexture, width:Int, height:Int){
		this.gl = gl;
		this.width = width;
		this.height = height;
		this.writeToTexture  = textureFactory(width, height);
		this.readFromTexture = textureFactory(width, height);

		this.writeFrameBufferObject = gl.createFramebuffer();
		this.readFrameBufferObject  = gl.createFramebuffer();

		//attach texture to frame buffer object's color component
		gl.bindFramebuffer(gl.FRAMEBUFFER, this.writeFrameBufferObject);
		gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.writeToTexture, 0);

		//attach texture to frame buffer object's color component
		gl.bindFramebuffer(gl.FRAMEBUFFER, this.readFrameBufferObject);
		gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.readFromTexture, 0);

		clear();
	}

	public inline function activate(){
		gl.bindFramebuffer(gl.FRAMEBUFFER, writeFrameBufferObject);
	}

	var tmpFBO:GLFramebuffer;
	var tmpTex:GLTexture;
	public inline function swap(){
		tmpFBO                 = writeFrameBufferObject;
		writeFrameBufferObject = readFrameBufferObject;
		readFrameBufferObject  = tmpFBO;

		tmpTex          = writeToTexture;
		writeToTexture  = readFromTexture;
		readFromTexture = tmpTex;
	}

	public inline function clear(){
		clearRead();
		clearWrite();
	}

	public inline function clearRead(){
		gl.bindFramebuffer(gl.FRAMEBUFFER, readFrameBufferObject);
		gl.clearColor (0, 0, 0, 1);
		gl.clear (gl.COLOR_BUFFER_BIT);
	}

	public inline function clearWrite(){
		gl.bindFramebuffer(gl.FRAMEBUFFER, writeFrameBufferObject);
		gl.clearColor (0, 0, 0, 1);
		gl.clear (gl.COLOR_BUFFER_BIT);
	}
}

