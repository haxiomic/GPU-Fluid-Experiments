package xgl;

import openfl.gl.GL;
import openfl.gl.GLFramebuffer;
import openfl.gl.GLTexture;

class RenderTarget{
	public var FBO:GLFramebuffer;
	public var read:GLTexture;

	public function new(texture:GLTexture){
		read = texture;

		FBO = GL.createFramebuffer();

		GL.bindFramebuffer(GL.FRAMEBUFFER, FBO);
		GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, read, 0);
		if(GL.checkFramebufferStatus(GL.FRAMEBUFFER) != GL.FRAMEBUFFER_COMPLETE)trace("fbo not complete");
		GL.clearColor (0, 0, 0, 1);
		GL.clear (GL.COLOR_BUFFER_BIT);
	}
}