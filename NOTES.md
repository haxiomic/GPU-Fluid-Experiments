TODO:
	- fix memory leak issue in html -> does one exist?
		!! Theory: when the particles pile up, fewer gpu cores are used to render, since particles require a texture lookup, the same core running many lookups becomes slow!
			-> Firefox handles this much better than chrome?
			-> Blending factors into it a little
			-> Improved a lot by using NEAREST velocity texture

		-> Only seems to occur with particles! Reset fixes the issue???
		what on earth?
		-> seems to get worse when particles are on top of one another ?
			=> depth testing?
	- handle resize
	- need fallback for interpolation when OES_texture_float_linear is not supported (simply bilerp in relevant shaders controlled by glsl define)
	- fallback to power of two textures in fluid for speed / compatibility in gltoolbox

- Reading rigid body force data back to CPU with gl.readpixels:
	- [http://concord-consortium.github.io/lab/experiments/webgl-gpgpu/webgl.html]()
	- Since readpixels requires RGBA format, floats must be packed into RGBA format (http://stackoverflow.com/questions/17981163/webgl-read-pixels-from-floating-point-render-target)

BUGS in Other Things:
	- Chrome, if missing OES_texture_float_linear, chrome errors incorrectly missing OES_float_linear
	- Haxe bool != operator does not invert