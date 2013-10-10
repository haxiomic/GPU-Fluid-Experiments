/*
TODO

Remove updateRenderObjectList from draw, replace with add and remove renderObjects function
Need correct units for velocity map 
*/

import flash.Lib;
import nape.phys.Body;
import nape.shape.Polygon;
import nape.shape.Shape;
import nape.space.Space;

import openfl.Assets;
import openfl.gl.GL;
import openfl.gl.GLBuffer;
import openfl.gl.GLTexture;
import openfl.gl.GLUniformLocation;
import openfl.utils.Float32Array;

import xgl.GLUtils;
import xgl.RenderTarget;


class NapeGLRenderer{
	public var render:RenderTarget;
	public var display:GLTexture;

	private var renderObjects:Map< Body, RenderObject >;
	private var program:MapVelocityProgram;
	private var w:Int;
	private var h:Int;
	private var viewWidth:Float;
	private var viewHeight:Float;

	//utility vars
	var matrix2x2:Float32Array;

	public function new(displayTextureWidth:Int, displayTextureHeight:Int, ?viewWidthInNapeSpace:Float, ?viewHeightInNapeSpace:Float){
		this.w = displayTextureWidth;
		this.h = displayTextureHeight;
		this.viewWidth = (viewWidthInNapeSpace!=null ? viewWidthInNapeSpace : displayTextureWidth);
		this.viewHeight = (viewHeightInNapeSpace!=null ? viewHeightInNapeSpace : this.viewWidth);

		matrix2x2 = new Float32Array(4);
		renderObjects = new Map< Body, RenderObject >();

		setupGL();
	}

	private function setupGL(){
		var tex:GLTexture = GLUtils.createNPOTTexture(w, h, GL.RGB, GL.UNSIGNED_BYTE, GL.NEAREST, null);
		render = new RenderTarget(tex);
		
		display = render.read;

		program = new MapVelocityProgram();
		GL.useProgram(program.glProgram);
		GL.uniform2f(program.invresolution, (w/viewWidth)*(1/w), (h/viewHeight)*(1/h));
	}

	public function draw(space:Space){
		updateRenderObjectList(space);

		GL.disable(GL.CULL_FACE);
		GL.viewport (0,0, w, h);

		GL.bindFramebuffer(GL.FRAMEBUFFER, render.FBO );

		GL.clearColor (0, 0, 0, 1);
		GL.clear (GL.COLOR_BUFFER_BIT);

		GL.useProgram(program.glProgram);


		var co:Float, si:Float;
		for(o in renderObjects){
			for(s in o.shapes){

				//Compute transformation matrix
				//rotation
				co = Math.cos(o.body.rotation);
				si = Math.sin(o.body.rotation);
				matrix2x2[0] =  co;
				matrix2x2[1] =  si;
 
				matrix2x2[2] = -si;
				matrix2x2[3] =  co;

				//ultra slow in html5 debug ?
				GL.uniformMatrix2fv(program.rotation, false, matrix2x2);
				GL.uniform2f(program.translation, o.body.position.x, o.body.position.y);
				GL.uniform1f(program.angV, o.body.angularVel);
				GL.uniform2f(program.vel, o.body.velocity.x, o.body.velocity.y);
				
				GL.bindBuffer(GL.ARRAY_BUFFER, s.buffer);
				GL.vertexAttribPointer(program.vertexPosition, 2, GL.FLOAT, false, 0, 0);
				GL.drawArrays(GL.TRIANGLES, 0, s.vertexCount);
			}
		}

	}

	inline function updateRenderObjectList(space:Space){
		var ro:RenderObject;
		var rs:RenderShape;
		//search for additive changes
		for(b in space.bodies){
			ro = renderObjects.get(b);
			if(ro == null){
				//add renderObject
				ro = new RenderObject();
				ro.body = b;

				for(s in b.shapes){
					ro.shapes.push(convertShape(s));
				}

				renderObjects.set(b, ro);
			}

			ro.touched = true;
		}
		//search for reductions
		for(ro in renderObjects){
			if(ro.touched==false){
				ro.dispose();
				renderObjects.remove(ro.body);
			}else{
				ro.touched = false;
			}
		}
	}

	function convertShape(shape:Shape):RenderShape{
		var ta:Array<Float> = new Array<Float>();//temporary vertex store
	/*	-- Fast circle algorithm, use if triangularDecomposition gets a bit slow for the number of circles
		inline function tri(a:Point2D,b:Point2D,c:Point2D){
			ta.push(a.x);ta.push(a.y);
			ta.push(b.x);ta.push(b.y);
			ta.push(c.x);ta.push(c.y);
		}

		if(shape.isCircle()){
			
			var n = 20;//n must be greater than 3

			var v:Array<Point2D> = new Array<Point2D>();
			var r:Float = shape.castCircle.radius;

			for (i in 0...n) {
				v.push({x:Math.cos(i*2*Math.PI/n)*r,
					    y:Math.sin(i*2*Math.PI/n)*r});
			}

			//Divide up into triangles
			var A,B,C;
			//--- Red ---
			A = 1;
			B = A+1;
			C = 0;
			tri(v[A], v[B], v[C]);

			C = n; 

			while(true){
				A++;B++;C--;
				if(B>=C)break;
				tri(v[A], v[B], v[C]);
			}
			if(n>3){
				//--- Blue ---
				A = n-1;
				B = 0;
				C = 2;
				tri(v[A], v[B], v[C]);

				B = n;

				while(true){
					A--;B--;C++;
					if(A<=C)break;
					tri(v[A], v[B], v[C]);
				}
			}

		}else{
			var triangles:nape.geom.GeomPolyList = new nape.geom.GeomPoly(shape.castPolygon.localVerts).triangularDecomposition(false);

			triangles.foreach(function(obj:nape.geom.GeomPoly){
				for(v in obj){
					ta.push(v.x);ta.push(v.y);
				}
				obj.dispose();
			});
		}*/
		var poly:nape.shape.Polygon;

		if(shape.isCircle()){
			var r:Float = shape.castCircle.radius;
			poly = new Polygon(Polygon.regular(r, r, 20));
		}else{
			poly = shape.castPolygon;
		}

		var triangles:nape.geom.GeomPolyList = new nape.geom.GeomPoly(poly.localVerts).triangularDecomposition(false);

		triangles.foreach(function(obj:nape.geom.GeomPoly){
			for(v in obj){
				ta.push(v.x);ta.push(v.y);
			}
			obj.dispose();
		});

		var buffer:GLBuffer = GL.createBuffer();
		GL.bindBuffer(GL.ARRAY_BUFFER, buffer);
		GL.bufferData(GL.ARRAY_BUFFER , new Float32Array(ta) , GL.STATIC_DRAW);

		return new RenderShape(buffer, Std.int(ta.length/2));
	}
}

typedef Point2D = {
	var x : Float;
	var y : Float;
}

class RenderObject{
	public var body:Body;
	public var shapes:Array<RenderShape>;

	@:allow(NapeGLRenderer) private var touched:Bool = false;
	//custom body draw params here

	public function new(){
		shapes = new Array<RenderShape>();
	}

	public function dispose(){
		for(s in shapes){
			s.vertexCount = 0;
			GL.deleteBuffer(s.buffer);
			shapes.remove(s);
		}
		body = null;
	}
}

class RenderShape{
	public var buffer:GLBuffer = null;
	public var vertexCount:Int = 0;
	
	public function new(buffer:GLBuffer, vertexCount:Int){
		this.buffer = buffer;
		this.vertexCount = vertexCount;
	}
}

class MapVelocityProgram extends xgl.Program{
	public var invresolution:GLUniformLocation;
	public var rotation:GLUniformLocation;
	public var translation:GLUniformLocation;
	public var angV:GLUniformLocation;
	public var vel:GLUniformLocation;

	public function new(){
		//create obstical-velocity map
		super(//Vert
			  "
				uniform vec2 invresolution;
				uniform mat2 rotation;
				uniform vec2 translation;
				uniform float angV;
				uniform vec2 vel;
				attribute vec2 position;

				varying vec2 v;
				void main(void){
					vec2 worldSpaceRotation =  rotation * position;

					vec2 pp = vec2(-worldSpaceRotation.y, worldSpaceRotation.x);
					v = pp*angV+vel;

					//from 0->w to -1, 1 (clip space)
					vec2 clipSpace = ((worldSpaceRotation+translation)*invresolution)*2.0 - 1.0;
					clipSpace.y *= -1.0;//flip y

					gl_Position = vec4(clipSpace, 0, 1);
				}
			  ",
			  //Frag
			  "
				varying vec2 v;
			    void main(void){
			    	gl_FragColor = vec4(1, abs(v*.02), 1);
			    }
			  ");
	}

	/*private static var basicTransform:String = 
		  "
			uniform vec2 invresolution;
			uniform mat2 rotation;
			uniform vec2 translation;
			attribute vec2 position;

			void main(void){
				vec2 worldSpace =  rotation * position + translation;

				//from 0->w to -1, 1 (clip space)
				vec2 clipSpace = (worldSpace*invresolution)*2.0 - 1.0;
				clipSpace.y *= -1.0;//flip y

				gl_Position = vec4(clipSpace, 0, 1);
			}
		  ";*/
}