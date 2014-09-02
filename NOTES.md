TODO:
	- Use power of two textures in fluid for speed
	- handle resize
	- deal with cellSize and pressureIterations
	- there's an issue with GPUParticles's aspect ratio
	- need fallback for interpolation when OES_texture_float_linear is not supported (simply bilerp in relevant shaders controlled by glsl define)
	- gpu particles needs improving, initial conditions: ie, the positions should not be determined by position in memory
	- fix memory leak issue in html -> does one exist?

- Reading rigid body force data back to CPU with gl.readpixels:
	- [http://concord-consortium.github.io/lab/experiments/webgl-gpgpu/webgl.html]()
	- Since readpixels requires RGBA format, floats must be packed into RGBA format (http://stackoverflow.com/questions/17981163/webgl-read-pixels-from-floating-point-render-target)

BUGS in Other Things:
	- Chrome, if missing OES_texture_float_linear, chrome errors incorrectly missing OES_float_linear
	- Haxe bool != operator does not invert