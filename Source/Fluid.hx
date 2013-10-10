/* 
 --- Fluid ---
http://http.developer.nvidia.com/GPUGems/gpugems_ch38.html

Interpolation Functions
https://github.com/visionworkbench/visionworkbench/tree/master/src/vw/GPU/Shaders/Interp

To update the interior fragments, we render a quadrilateral that covers all but a one-pixel border on the perimeter of the frame buffer.
We render four line primitives to update the boundary cells.
We apply separate fragment programs to interior and border fragments. 

---- On Coordinates ---
texCoord represents the texel centers because of the interpolation that happens as a result of being
a varying! (Same for gl_FragCoord). The bottom left coordinate (unit space) of the cell can be found like so:

	texCoord-(1./(2.*resolution))

where (1./(2*resolution)) finds half the pixel width

-> (0,0) in vertex coordinates !=> (0,0) texCoord
	[ (0,0) in vertex coordinates => texCoord-(half texel size) ]
-----------------------

// Apply the first 3 operators in Equation 12.
u = advect(u);
u = diffuse(u);
u = addForces(u);
// Now apply the projection operator to the result.
p = computePressure(u);
u = subtractPressureGradient(u, p);

dx = grid spacing, 
rdx = 1/grid spacing

Investigate staggered grid (see fluid_notes.pdf)
eg, store velocity (only) at center of edges rather than at the center of the squares

#! todo
Convert to new grasshopper shaders
Should dye be a floating point?
Add particle advection
Proper mouse/interaction/force handling
replace npot textures with pot textures for speed
better design http://prideout.net/blog/?p=58
fix openFL call to GL.bindFramebuffer(..., null), on ios this should bind to 'defaultFramebuffer' found in UIStageView.mm 
check out float packing functions https://github.com/MegaJiXiang/InfiniSurv/blob/master/ArtResources/Shaders/Fluid_Diffusion.fsh for fallback
*/
import flash.Lib;

import openfl.gl.GLBuffer;
import openfl.gl.GL;
import openfl.gl.GLFramebuffer;
import openfl.gl.GLProgram;
import openfl.gl.GLTexture;
import openfl.gl.GLUniformLocation;
import openfl.utils.Float32Array;
import openfl.utils.Int16Array;
import openfl.utils.UInt8Array;

import xgl.GLUtils;
import xgl.Program;
import xgl.RenderTarget;
import xgl.RenderTarget2P;

class Fluid {
	//Shaders
	private var advect:FluidPrograms.Advect = null;
	private var applyForces:FluidPrograms.ApplyForces = null;
	private var calculateDiv:FluidPrograms.Divergence = null;
	private var pressureSolve:FluidPrograms.PressureSolver = null;
	private var pgradientSubtract:FluidPrograms.PGradientSubtract = null;
	private var edgeBoundary:FluidPrograms.EdgeBoundary = null;
	//Scene
	private var programs:Array<Program>;
	private var buffers:Array<GLBuffer>;
	private var frameBuffers:Array<GLFramebuffer>;
	private var textures:Array<GLTexture>;
	//Geometry
	private var displayQuad:GLBuffer = null; 
	private var boundaryBuffer:GLBuffer = null;
	private var innerQuadBuffer:GLBuffer = null;
	//Render Targets
	public var dye:RenderTarget2P;
	public var velocity:RenderTarget2P;
	public var pressure:RenderTarget2P;
	public var divergence:RenderTarget;

	//Fluid Sim
	private var simWidth:Int;
	private var simHeight:Int; 
	private var cellSize:Float = 2;

	private var time:Float;

	public function new (w:Int, h:Int) {
		this.simWidth  = w;
		this.simHeight = h;

		//Initate vars
		programs       = new Array<Program>();
		buffers        = new Array<GLBuffer>();
		frameBuffers   = new Array<GLFramebuffer>();
		textures       = new Array<GLTexture>();

		//Setup GL
		initGL();
		setupSimulationGL();
	}

	private function initGL(){
		//OpenGL Settings
		GL.lineWidth(1.0);

		//Load floating point extension in browser
		#if js
			//untyped __js__("openfl.gl.GL.nmeContext.getExtension('OES_texture_float');");
			GL.nmeContext.getExtension('OES_texture_float');
		#end
	}


	//needs to be leak proof as it is called on resize
	private function setupSimulationGL(){
		// -- Render to Texture --
		var W:Int    = simWidth;
		var H:Int    = simHeight;
		var dataKind = GL.FLOAT;
		#if ios dataKind = 0x8D61; #end //GL_HALF_FLOAT_OES for iOS, as most iPad2 doesn't support GL_FLOAT

		//Initiate
		function pushTarget2P(t:RenderTarget2P){
			frameBuffers.push(t.writeFBO);
			frameBuffers.push(t.readFBO);
			textures.push(t.write);
			textures.push(t.read);
		}
		function pushTarget(t:RenderTarget){
			frameBuffers.push(t.FBO);
			textures.push(t.read);
		}
		var simTexture:Void->GLTexture = function():GLTexture{
			return GLUtils.createNPOTTexture(W, H, GL.RGB, dataKind, GL.NEAREST, null);
		}

		velocity   = new RenderTarget2P(simTexture);
		pushTarget2P(velocity);

		pressure   = new RenderTarget2P(simTexture);
		pushTarget2P(pressure);

		dye        = new RenderTarget2P(simTexture);
		pushTarget2P(dye);

		divergence = new RenderTarget(simTexture());
		pushTarget(divergence);

		//Shaders
		initShaders();

		setProgramsParams();

		//Geometry
		initFluidRenderGeometry(simWidth, simHeight);
	}

	private function initShaders(){
		advect            = new FluidPrograms.Advect();
		programs.push(advect);

		applyForces       = new FluidPrograms.ApplyForces();
		programs.push(applyForces);

		calculateDiv      = new FluidPrograms.Divergence();
		programs.push(calculateDiv);

		pressureSolve     = new FluidPrograms.PressureSolver();
		programs.push(pressureSolve);

		pgradientSubtract = new FluidPrograms.PGradientSubtract();
		programs.push(pgradientSubtract);

		edgeBoundary      = new FluidPrograms.EdgeBoundary();
		programs.push(edgeBoundary);
	}

	private function setProgramsParams(){
		//resolution
		var invSimWidth:Float = 1/simWidth;
		var invSimHeight:Float = 1/simHeight;

		GL.useProgram(advect.glProgram);
		GL.uniform2f(advect.invresolution, invSimWidth, invSimHeight);
		GL.useProgram(applyForces.glProgram);
		GL.uniform2f(applyForces.invresolution, invSimWidth, invSimHeight);
		GL.useProgram(calculateDiv.glProgram);
		GL.uniform2f(calculateDiv.invresolution, invSimWidth, invSimHeight);
		GL.useProgram(pressureSolve.glProgram);
		GL.uniform2f(pressureSolve.invresolution, invSimWidth, invSimHeight);
		GL.useProgram(pgradientSubtract.glProgram);
		GL.uniform2f(pgradientSubtract.invresolution, invSimWidth, invSimHeight);
		GL.useProgram(edgeBoundary.glProgram);
		GL.uniform2f(edgeBoundary.invresolution, invSimWidth, invSimHeight);

		//grid scale
		GL.useProgram(advect.glProgram);
		GL.uniform1f(advect.rdx, 1/cellSize);	 //grid scale multiplier
		GL.useProgram(calculateDiv.glProgram);
		GL.uniform1f(calculateDiv.halfrdx, 0.5*(1/cellSize));	
		GL.useProgram(pressureSolve.glProgram);
		GL.uniform1f(pressureSolve.alpha, -(cellSize*cellSize));	
		GL.useProgram(pgradientSubtract.glProgram);
		GL.uniform1f(pgradientSubtract.halfrdx, 0.5*(1/cellSize));
	}

	private function initFluidRenderGeometry(textureWidth, textureHeight){
		//For fluid texture, #! need to think carefully about dynamic size
		var coords:Float32Array;
		//1px boundary for boundary shader
		boundaryBuffer = GL.createBuffer();
		GL.bindBuffer(GL.ARRAY_BUFFER, boundaryBuffer);
		//Each line must be offset by .5 pixels perpendicular to it's direction.
		//OpenGL centers lines on the boundary between pixels, which isn't very helpful
		//in this case
		coords = new Float32Array(
			[
		     0.5,              0,                 0.5,              textureHeight,     //left
		     0,                textureHeight-0.5, textureWidth,     textureHeight-0.5, //top
		     textureWidth-0.5, textureHeight,     textureWidth-0.5, 0,                 //right
		     textureWidth,     0.5,               0,                0.5                //bottom
			]
		);
		GL.bufferData(GL.ARRAY_BUFFER, coords, GL.STATIC_DRAW);
		buffers.push(boundaryBuffer);

		//Inner quad, for main fluid shaders
		innerQuadBuffer = GL.createBuffer();
		GL.bindBuffer(GL.ARRAY_BUFFER, innerQuadBuffer);
		coords = new Float32Array(
			[
				1.0              , 1.0,
				textureWidth-1.0 , 1.0,
				1.0              , textureHeight-1.0,

				textureWidth-1.0 , 1.0,
				textureWidth-1.0 , textureHeight-1.0,
				1.0              , textureHeight-1.0
			]
		);
		GL.bufferData(GL.ARRAY_BUFFER, coords, GL.STATIC_DRAW);
		buffers.push(innerQuadBuffer);
	}

	public function step(dt:Float){
		time = Lib.getTimer()/1000;

		//--- Velocity Field ---
		GL.viewport (0, 0, simWidth, simHeight);

		//Set geometry
		GL.bindBuffer(GL.ARRAY_BUFFER, innerQuadBuffer);

		selfAdvection(dt);
		dyeAdvection(dt);
		//diffusion();
		applyMouseForces();
		addMouseDye();
		//Compute Pressure
		computeDivergence();
		solvePressure();
		subtractPressureGradient();
	}

	private inline function selfAdvection(dt:Float){		
		GL.useProgram(advect.glProgram);
		GL.vertexAttribPointer(advect.vertexPosition, 2, GL.FLOAT, false, 0, 0);

		//in-> set advection velocity texture
		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, velocity.read);
		GL.uniform1i(advect.velocity, 0);
		GL.activeTexture(GL.TEXTURE1);
		GL.bindTexture(GL.TEXTURE_2D, velocity.read);
		GL.uniform1i(advect.advected, 1);

		//Set other params
		GL.uniform1f(advect.dt, dt);
		GL.uniform2f(advect.AByV, 1, 1);	 	 

		//Framebuffer 
		GL.bindFramebuffer(GL.FRAMEBUFFER, velocity.writeFBO);
		GL.drawArrays (GL.TRIANGLES, 0, 6);
		//Always call swap after a change to the velocity field
		velocity.swap();
	}

	private inline function dyeAdvection(dt:Float){
		GL.useProgram( advect.glProgram );
		GL.vertexAttribPointer( advect.vertexPosition, 2, GL.FLOAT, false, 0, 0);

		//Velocity
		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, velocity.read);
		GL.uniform1i( advect.velocity, 0);

		//Dye
		GL.activeTexture(GL.TEXTURE1);
		GL.bindTexture(GL.TEXTURE_2D, dye.read);
		GL.uniform1i( advect.advected, 1);

		//Set other params
		GL.uniform1f(advect.dt, dt);
		GL.uniform2f(advect.AByV, 1, 1);//#! set to ratio of resolution: A.resolution/V.resolution

		GL.bindFramebuffer(GL.FRAMEBUFFER, dye.writeFBO);
		GL.drawArrays(GL.TRIANGLES, 0, 6);

		dye.swap();
	}

	private inline function applyMouseForces(){
		GL.useProgram(applyForces.glProgram);
		GL.vertexAttribPointer(applyForces.vertexPosition, 2, GL.FLOAT, false, 0, 0);
		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, velocity.read);
		GL.uniform1i(applyForces.velocity, 0);
		GL.uniform1f(applyForces.time, time);	
		//GL.uniform2f(applyForces.mouse, (stage.mouseX)/stage.stageWidth, (stage.stageHeight-stage.mouseY)/stage.stageHeight);	 	 
		GL.uniform2f(applyForces.mouse, (Math.sin(time/2)/3)+.5, (Math.sin(time/1.79+0.3*time)/3)+.5);	 	 

		GL.bindFramebuffer(GL.FRAMEBUFFER, velocity.writeFBO);
		GL.drawArrays (GL.TRIANGLES, 0, 6);
		//Always call swap after a change to the velocity field
		velocity.swap();
	}

	private inline function addMouseDye(){
		GL.useProgram(applyForces.glProgram);
		GL.vertexAttribPointer(applyForces.vertexPosition, 2, GL.FLOAT, false, 0, 0);
		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, dye.read);
		GL.uniform1i(applyForces.velocity, 0);
		GL.uniform1f(applyForces.time, time);	
		//GL.uniform2f(applyForces.mouse, (stage.mouseX)/stage.stageWidth, (stage.stageHeight-stage.mouseY)/stage.stageHeight);	 	 
		GL.uniform2f(applyForces.mouse, (Math.sin(time/2)/3)+.5, (Math.sin(time/1.79+0.3*time)/3)+.5);	 	 

		GL.bindFramebuffer(GL.FRAMEBUFFER, dye.writeFBO);
		GL.drawArrays (GL.TRIANGLES, 0, 6);
		//Always call swap after a change to the velocity field
		dye.swap();
	}

	private inline function computeDivergence(){
		//We need to write to a temporary texture to pass to the jacobi solver
		GL.useProgram(calculateDiv.glProgram);
		GL.vertexAttribPointer(calculateDiv.vertexPosition, 2, GL.FLOAT, false, 0, 0);
		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, velocity.read);
		GL.uniform1i(calculateDiv.field, 0);

		GL.bindFramebuffer(GL.FRAMEBUFFER, divergence.FBO);
		GL.drawArrays(GL.TRIANGLES, 0, 6);
	}

	private inline function solvePressure(){
		//#! weird behavior on OS X
		GL.useProgram(pressureSolve.glProgram);
		GL.vertexAttribPointer(pressureSolve.vertexPosition, 2, GL.FLOAT, false, 0, 0);

		//Divergence Texture
		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, divergence.read);
		GL.uniform1i(pressureSolve.divergence, 0);

		//Clear pressure 
		GL.bindFramebuffer(GL.FRAMEBUFFER, pressure.readFBO);
		GL.clearColor (0, 0, 0, 1);
		GL.clear (GL.COLOR_BUFFER_BIT);

		for (i in 0...20) {
			GL.activeTexture(GL.TEXTURE1);
			GL.bindTexture(GL.TEXTURE_2D, pressure.read);
			GL.uniform1i(pressureSolve.pressure, 1);

			GL.bindFramebuffer(GL.FRAMEBUFFER, pressure.writeFBO);
			GL.drawArrays(GL.TRIANGLES, 0, 6);
			pressure.swap();
		}
	}

	private inline function subtractPressureGradient(){
		GL.useProgram(pgradientSubtract.glProgram);
		GL.vertexAttribPointer(pgradientSubtract.vertexPosition, 2, GL.FLOAT, false, 0, 0);

		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, pressure.read);
		GL.uniform1i(pgradientSubtract.pressure, 0);

		GL.activeTexture(GL.TEXTURE1);
		GL.bindTexture(GL.TEXTURE_2D, velocity.read);
		GL.uniform1i(pgradientSubtract.velocity, 1);

		GL.bindFramebuffer(GL.FRAMEBUFFER, velocity.writeFBO);
		GL.drawArrays(GL.TRIANGLES, 0, 6);
		velocity.swap();
	}

	private inline function edgeBoundaries(){
		//order: left top right bottom
		/*GL.useProgram(edgeBoundary.glProgram);
		GL.vertexAttribPointer(edgeBoundary.vertexPosition, 2, GL.FLOAT, false, 0, 0);
		//Velocity pass
		GL.bindFramebuffer(GL.FRAMEBUFFER, velocity.readFBO);
		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, velocity.read);
		GL.uniform1i(edgeBoundary.field, 0);
		GL.uniform1f(edgeBoundary.multiplier, -1);

		//left
		GL.uniform2f(edgeBoundary.offset, 1, 0);
		GL.drawArrays(GL.LINES, 0, 2);
		//top
		GL.uniform2f(edgeBoundary.offset, 0, -1);
		GL.drawArrays(GL.LINES, 2, 2);
		//right
		GL.uniform2f(edgeBoundary.offset, -1, 0);
		GL.drawArrays(GL.LINES, 4, 2);
		//bottom
		GL.uniform2f(edgeBoundary.offset, 0, 1);
		GL.drawArrays(GL.LINES, 6, 2);

		//Pressure pass
		GL.bindFramebuffer(GL.FRAMEBUFFER, pressure.readFBO);
		GL.bindTexture(GL.TEXTURE_2D, pressure.read);
		GL.uniform1f(edgeBoundary.multiplier, 1);

		//left
		GL.uniform2f(edgeBoundary.offset, 1, 0);
		GL.drawArrays(GL.LINES, 0, 2);
		//top
		GL.uniform2f(edgeBoundary.offset, 0, -1);
		GL.drawArrays(GL.LINES, 2, 2);
		//right
		GL.uniform2f(edgeBoundary.offset, -1, 0);
		GL.drawArrays(GL.LINES, 4, 2);
		//bottom
		GL.uniform2f(edgeBoundary.offset, 0, 1);
		GL.drawArrays(GL.LINES, 6, 2);*/
	}
	
	public inline function setSimSize(w:Int, h:Int){
		simWidth = w;
		simHeight = h;

		//#! We don't actually want to dispose - we'll lose the fluid state!!!!
		//	 how do we preserve? Taking into account OS X resize death bug,
		//	 GL.readPixels maybe, but not yet implemented
		//#! need to handle removing/ resizing / creating geometry & textures
		disposeGL();
		setupSimulationGL();
	} 

	public function disposeGL(){
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

