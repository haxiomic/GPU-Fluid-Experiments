#Cross-platform GPU fluid simulation

Branch using [snow](http://snowkit.org/) instead of lime.

###[Demo](http://haxiomic.github.io/GPU-Fluid-Experiments/html5/)

If you have an idea and you want to collaborate, feel free to get in touch with me [haxiomic@gmail.com](mailto:haxiomic@gmail.com)

##Building
Install the latest version of haxe from [haxe.org](http://haxe.org/)

Install the dependencies:
'flow' build tool and 'snow' library (more info on http://snowkit.org):

	haxelib git snow https://github.com/underscorediscovery/snow.git
	haxelib git flow https://github.com/underscorediscovery/flow.git

'shaderblox' and 'gltoolbox':

	haxelib git shaderblox https://github.com/haxiomic/shaderblox.git
	haxelib git gltoolbox https://github.com/haxiomic/GLToolbox.git

and you should be good to go

cd into the project root and to build and run execute:

	haxelib run flow run web

(it'll start a server and open a web browser)

That is a bit much to type out frequently so it’s worth making an alias, on OS X I use

	alias fweb=“haxelib run flow run web --timeout 0”

Then you can build and run with 'fweb'.

If you're on windows, there's some instructions on how to make an alias to flow here [underscorediscovery.github.io/flow/#install-the-flow-shortcut](http://underscorediscovery.github.io/flow/#install-the-flow-shortcut).


------------------------------

You can build it as a native desktop application which will run a little faster:

install hxcpp:

	haxelib install hxcpp

from the project root run

	haxelib run flow run
