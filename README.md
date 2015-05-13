#Cross-platform GPU fluid simulation
----
Branch using [snow](http://snowkit.org/) instead of lime.

###[Demo](http://haxiomic.github.io/GPU-Fluid-Experiments/html5/)

##Building
Install the latest version of haxe from [haxe.org](http://haxe.org/)

Install the dependencies:
'flow' build tool and 'snow' library (more info on http://snowkit.org):

	haxelib git snow https://github.com/underscorediscovery/snow.git
	haxelib git flow https://github.com/underscorediscovery/flow.git

'shaderblox' and 'gltoolbox':

	haxelib git shaderblox https://github.com/haxiomic/shaderblox.git
	haxelib git gltoolobox https://github.com/haxiomic/GLToolbox.git

and you should be good to go

cd into the project root and run 

	haxelib run flow run web

to build and run (it'll start a server and open a web browser)

That is a bit much to type out frequently so it’s worth making an alias, I use 

	alias fweb=“haxelib run flow run web --timeout 0”

Then you can build and run with 'fweb'.

(**Make sure you use my fork of shaderblox**)