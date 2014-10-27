#Cross-platform GPU fluid simulation
----
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

####Building
First install the build tool **aether** from haxelib \*

```haxelib install aether```

Then setup the aether command with 

```haxelib run aether setup```

This creates an command alias so that ```aether``` executes ```haxelib run aether```.

Next, make sure you've got the dependancies installed:
```
haxelib install lime
haxelib git gltoolbox https://github.com/haxiomic/GLToolbox.git
haxelib git shaderblox https://github.com/haxiomic/shaderblox.git
```
Now you should be go to go, cd into the gpu fluid directory and run
```
aether test html5
```
A browser should open with the result (*test* is aether's build and run command.)

\* *haxe just produces the javascript but aether handles the html template as well as the iOS and android project files when targeting mobile. Currently, lime is undergoing an overhaul so mobile targets are not working.*

---------------

####Can I build for C++ and mobile targets?
C++ Yes, mobile not yet. The lime library isn't quite finished, so it's not a super smooth process, follow the instructions on [lime's git page](https://github.com/openfl/lime/) to build lime's native binaries and then run
```aether test mac``` or ```aether test windows``` or ```aether test linux```.
