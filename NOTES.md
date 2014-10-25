NOTES:
	- Editable particle count - use url params and reload to avoid texture allocation issue?
		-> let u/CaptainObliviousity and u/8lbIceBag know when complete

	! avoid normalizing 0 vectors / any cases of bad math, even if the algo avoids them, they case problems on some machines http://www.reddit.com/r/InternetIsBeautiful/comments/2gkunq/fluid_and_particles_in_webgl/ckk3jrp
	
	- Texture lookups outside function void main() are not standard - this caused issues on many GPUs!

TODO:
	- need fallback for interpolation when OES_texture_float_linear is not supported (simply bilerp in relevant shaders controlled by glsl define)
		(this is an issue on iOS webgl)
		> http://codeflow.org/entries/2013/feb/22/how-to-write-portable-webgl/#how-to-deal-with-no-linear-filtering-support

	- Shaderblox: Precision
				  Defines
				  Super functions
	- fix memory leak issue in html -> does one exist?
		!! Theory: when the particles pile up, fewer gpu cores are used to render, since particles require a texture lookup, the same core running many lookups becomes slow!
			-> Firefox handles this much better than chrome?
			-> Blending factors into it a little
			-> Improved a lot by using NEAREST velocity texture

		-> Only seems to occur with particles! Reset fixes the issue???
		what on earth?
		-> seems to get worse when particles are on top of one another ?
			=> depth testing?
	- fallback to power of two textures in fluid for speed / compatibility in gltoolbox
	- fluid shouldn't really manage the dye, nor should particles manage advection

- Reading rigid body force data back to CPU with gl.readpixels:
	- [http://concord-consortium.github.io/lab/experiments/webgl-gpgpu/webgl.html]()
	- Since readpixels requires RGBA format, floats must be packed into RGBA format (http://stackoverflow.com/questions/17981163/webgl-read-pixels-from-floating-point-render-target)

BUGS in Other Things:
	- Chrome, if missing OES_texture_float_linear, chrome errors incorrectly 'missing OES_float_linear'
	- Haxe Map.set should return the item set? (for chaining)
	- haxe.Timer.delay not working on c++?
	- Type.createInstance - why is there an argument limit? There's no reason for there to be one.