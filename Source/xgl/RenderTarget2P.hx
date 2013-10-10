//#! Should subclass RenderTarget?

package xgl;

import openfl.gl.GL;
import openfl.gl.GLFramebuffer;
import openfl.gl.GLTexture;

class RenderTarget2P{
	public var FBO:GLFramebuffer;		//Alias of writeFBO
	public var writeFBO:GLFramebuffer;
	public var readFBO:GLFramebuffer;
	public var write:GLTexture;
	public var read:GLTexture;

	public function new(createTextureCallback:Void->GLTexture){
		write = createTextureCallback();
		read  = createTextureCallback();

		writeFBO = GL.createFramebuffer();
		readFBO  = GL.createFramebuffer();
		FBO = writeFBO;

		GL.bindFramebuffer(GL.FRAMEBUFFER, writeFBO);
		GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, write, 0);
		if(GL.checkFramebufferStatus(GL.FRAMEBUFFER) != GL.FRAMEBUFFER_COMPLETE)trace("fbo not complete");
		GL.clearColor (0, 0, 0, 1);
		GL.clear (GL.COLOR_BUFFER_BIT);

		GL.bindFramebuffer(GL.FRAMEBUFFER, readFBO);
		GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, read, 0);
		if(GL.checkFramebufferStatus(GL.FRAMEBUFFER) != GL.FRAMEBUFFER_COMPLETE)trace("fbo not complete");
		GL.clearColor (0, 0, 0, 1);
		GL.clear (GL.COLOR_BUFFER_BIT);
	}

	var _tmpFBO:GLFramebuffer;
	var _tmpTex:GLTexture;
	public inline function swap(){
		_tmpFBO  = writeFBO;
		writeFBO = readFBO;
		readFBO  = _tmpFBO;

		_tmpTex  = write;
		write    = read;
		read     = _tmpTex;
	}
}