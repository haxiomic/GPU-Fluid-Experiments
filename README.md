#Cross-platform GPU fluid simulation
----
Using [snow](http://snowkit.org/) instead of lime, **make sure you use my fork of shaderblox and the latest gltoolbox**

Experimenting coupling a CPU-based rigid body simulation with a GPU-based fluid simulation in OpenGL ES. 

###[Demo](http://haxiomic.github.io/GPU-Fluid-Experiments/html5/)

(Rigid body integration is still in the works)

####Todo
- Switch to MAC (staggerd) grid
- Establish efficient pipeline for reading forces to CPU (via glReadPixels)

####Requires:
- [lime](https://github.com/openfl/lime/) ♥
- [gltoolbox](http://github.com/haxiomic/gltoolbox)
- [my fork of shaderblox](http://github.com/haxiomic/shaderblox) (by [Sunjammer](https://github.com/Sunjammer))
- [Haxe 3.1.3](http://haxe.org/)
