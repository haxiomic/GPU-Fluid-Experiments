/*
Todo
Need a better, more general way to track opengl instances
Understand resize issue on mac os x


Bug fixes to main distro:
nme/project/opengl/OGLExport.cpp
	uncommented:
		case: GL_FRAMEBUFFER_BINDING

	repalced to fix uniformMatrix#fv fails:
		677: if (size==count*count*4)

nme/project/opengl/OGL.h
	added:
		#ifndef GL_FRAMEBUFFER_BINDING
		#define GL_FRAMEBUFFER_BINDING 0x8CA6
		#endif
*/

import flash.display.BitmapData;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Matrix;
import flash.geom.Matrix3D;
import flash.geom.Rectangle;
import flash.Lib;

import openfl.display.OpenGLView;
import openfl.gl.GLBuffer;
import openfl.gl.GL;
import openfl.gl.GLFramebuffer;
import openfl.gl.GLProgram;
import openfl.gl.GLTexture;
import openfl.gl.GLUniformLocation;
import openfl.utils.Float32Array;
import openfl.Assets;
import openfl.utils.Int16Array;
import openfl.utils.UInt8Array;

import xgl.GLUtils;
import xgl.Program;
import DisplayPrograms;


class Main extends Sprite {
	//OpenGL
	private var view:OpenGLView;
	//Shaders
	private var displayTexture:TextureProgram = null;
	//Geometry
	private var displayQuad:GLBuffer = null; 
	//Framebuffers
	private var screenBuffer:GLFramebuffer = null;	//null for all platforms exlcuding ios, where it references the defaultFramebuffer (UIStageView.mm)
	//Track GL instances
	private var programs:Array<Program>;
	private var buffers:Array<GLBuffer>;
	private var frameBuffers:Array<GLFramebuffer>;
	private var textures:Array<GLTexture>;

	//Nape rigid body physics
	var physicsSim:PhysicsTest;
	//Fluid
	var fluidSim:Fluid;

	//Physics GL rendering
	var napeGLRenderer:NapeGLRenderer;

	public function new(){
		super();
		if(!OpenGLView.isSupported){
			throw "OpenGL not supported :[";
			return;
		}

		//Initate vars
		programs = new Array<Program>();
		buffers = new Array<GLBuffer>();
		frameBuffers = new Array<GLFramebuffer>();
		textures = new Array<GLTexture>();

		view = new OpenGLView();
		addChild(view);
		initGL();//Must be called as soon as OpenGLView is created 

		//Setup physics
		physicsSim = new PhysicsTest(stage.stageWidth, stage.stageHeight);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, physicsSim.mouseDownHandler);
		stage.addEventListener(MouseEvent.MOUSE_UP, physicsSim.mouseUpHandler);
		stage.addEventListener(MouseEvent.MOUSE_MOVE, physicsSim.mouseMoveHandler);

		//Setup fluid sim
		var size:Array<Int> = fluidSimSize();
		fluidSim = new Fluid(size[0], size[1]);

		//Drawing
		setupDrawingGL();

		napeGLRenderer = new NapeGLRenderer(Std.int(stage.stageWidth/1), Std.int(stage.stageHeight/1), stage.stageWidth, stage.stageHeight);

		//Event Listeners
		//this.addEventListener(Event.ENTER_FRAME, mainLoop);
		stage.addEventListener(Event.RESIZE, resizeView);

		view.render = mainLoop;

		//Accelerometer
		if(flash.sensors.Accelerometer.isSupported){
			var acc:flash.sensors.Accelerometer = new flash.sensors.Accelerometer();
			acc.addEventListener(flash.events.AccelerometerEvent.UPDATE, function(e:flash.events.AccelerometerEvent){

				physicsSim.space.gravity.setxy(e.accelerationY*500, e.accelerationX*500);

			}); 
		}
	}

	inline function fluidSimSize():Array<Int>{
		var f:Float = 1/1;
		#if js 	f = 1/5; #end
		#if ios f = 1/7; #end 

		var simSize:Array<Int> = new Array<Int>();
		simSize[0] = Std.int(stage.stageWidth *f);
		simSize[1] = Std.int(stage.stageHeight *f);
		return simSize;
	}


	function resizeView(?e:Event){
		trace("Stage resized");
		//Remove framebuffers

		//On desktop, this seems to kill the openGL window, so lets set it up again
		//#! needs investigating on other systems
		#if desktop
			disposeGL();
			setupDrawingGL();
			fluidSim.disposeGL();
		#end

		var size:Array<Int> = fluidSimSize();
		fluidSim.setSimSize(size[0], size[1]);
	}

	function initGL(){
		//Grab default screenbuffer
		#if ios
			screenBuffer = new GLFramebuffer(GL.version, GL.getParameter(GL.FRAMEBUFFER_BINDING));//GL.getParameter(GL.FRAMEBUFFER_BINDING) was enabled because of chaneges to OGLExport.cpp
		#end
		#if cpp
			@:cppFileCode("#include <opengl/OGLExport.cpp>")
			untyped __cpp__("int wdrwr = 0");
			//untyped __cpp__("int val;glGetIntegerv(0x8CA6,&val)")
		#end

	}

	function setupDrawingGL(){
		initDisplayGeometry();
		initShaders();
	}

	function initDisplayGeometry(){
		//Display to Screen Quad
		displayQuad = GL.createBuffer();
		GL.bindBuffer(GL.ARRAY_BUFFER, displayQuad);
		GL.bufferData(GL.ARRAY_BUFFER, GLUtils.quad, GL.STATIC_DRAW);
		buffers.push(displayQuad);
	}

	function initShaders(){
		displayTexture = new TextureProgram();
		programs.push(displayTexture);
	}

	var dt:Float;
	inline function mainLoop(?rect:Rectangle){
		dt = 1/60;

		physicsSim.step(dt);

		//fluidSim.step(dt);

		napeGLRenderer.draw(physicsSim.space);

		renderTextureToScreen(napeGLRenderer.display);	//nape
		//renderTextureToScreen(fluidSim.dye.read);		//fluid
	}

	inline function renderTextureToScreen(texture:GLTexture){
		GL.viewport (0,0, Std.int (stage.stageWidth), Std.int (stage.stageHeight));

		//Set to display program
		GL.useProgram(displayTexture.glProgram);
		//Set display quad as active geometry
		GL.bindBuffer (GL.ARRAY_BUFFER, displayQuad);
		GL.vertexAttribPointer(displayTexture.vertexPosition, 2, GL.FLOAT, false, 0, 0);
		//Set texture to draw
			//Set '0' as the active texture, we don't actually need this because 0 is the default active texture.
		GL.activeTexture(GL.TEXTURE0);
			//Push our texture into gpu texture0
		GL.bindTexture(GL.TEXTURE_2D, texture);
			//Tell fragment uniform that our texture can be found in texture0
		GL.uniform1i(displayTexture.texture, 0);

		//Select screen buffer
		GL.bindFramebuffer(GL.FRAMEBUFFER, screenBuffer);
		GL.drawArrays (GL.TRIANGLES, 0, 6);
	}

	function disposeGL(){
		//Remove framebuffers
		for(f in frameBuffers){
			if(f!=null)GL.deleteFramebuffer(f);
		}
		//clear textures
		for(t in textures){
			if(t!=null) GL.deleteTexture(t);
		}
		//clear geometry
		for(b in buffers){
			if(b!=null) GL.deleteBuffer(b);
		}
		//clear programs
		for(p in programs){
			GL.deleteProgram(p.glProgram);
		}
	}
}

