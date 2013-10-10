package xgl;

import flash.display.BitmapData;
import flash.utils.ByteArray;
import openfl.gl.GL;
import openfl.gl.GLProgram;
import openfl.gl.GLTexture;
import openfl.utils.ArrayBufferView;
import openfl.utils.Float32Array;
import openfl.utils.Int32Array;
import openfl.utils.UInt8Array;

class GLUtils 
{
	//OpenGL Utils
	public static inline var highpfloat:String = "precision highp float;";
	public static inline var mediumpfloat:String = "precision mediump float;";
	public static inline var lowpfloat:String = "precision lowp float;";

	public static var quad:Float32Array = new Float32Array ([ 
													  -1.0,-1.0,
													   1.0,-1.0,
													  -1.0, 1.0,

													   1.0,-1.0,
													   1.0, 1.0,
													  -1.0, 1.0 ]);

	public static inline function createProgram(vertexShaderGLSL:String, fragmentShaderGLSL:String):GLProgram{
		//Create empty program object
		var program = GL.createProgram();

		//Create shader objects
		var vShader = GL.createShader(GL.VERTEX_SHADER);
		var fShader = GL.createShader(GL.FRAGMENT_SHADER);

		//Fill will GLSL
		GL.shaderSource(vShader, vertexShaderGLSL);
		GL.shaderSource(fShader, fragmentShaderGLSL);

		//Compile
		GL.compileShader(vShader);
		GL.compileShader(fShader);

		//Check if compiled
		if(GL.getShaderParameter(vShader, GL.COMPILE_STATUS)==0)
			trace(GL.getShaderInfoLog(vShader));

		if(GL.getShaderParameter(fShader, GL.COMPILE_STATUS)==0)
			trace(GL.getShaderInfoLog(fShader));

		//attach shaders
		GL.attachShader(program, vShader);
		GL.attachShader(program, fShader);

		//Link
		GL.linkProgram(program);

		//If a shader object to be deleted is attached to a program object, it will be flagged for deletion, but it will not be deleted until it is no longer attached to any program object, for any rendering context (i.e., it must be detached from wherever it was attached before it will be deleted).
		GL.deleteShader(vShader);
		GL.deleteShader(fShader);

		GL.detachShader(program, vShader);
		GL.detachShader(program, fShader);

		if(GL.getProgramParameter(program, GL.LINK_STATUS)==0){
			trace (GL.getProgramInfoLog (program));
			trace ("VALIDATE_STATUS: " + GL.getProgramParameter (program, GL.VALIDATE_STATUS));
			trace ("ERROR: " + GL.getError ());
		}

		return program;
	}

	public static inline function createImageTexture(bitmapData:BitmapData, alpha:Bool = false):GLTexture{
		var type = ( alpha? GL.RGBA : GL.RGB);
		return createNPOTTexture(bitmapData.width, bitmapData.height, type, GL.UNSIGNED_BYTE, GL.LINEAR, (alpha ? bitmapDataToRGBAUInt8(bitmapData) : bitmapDataToRGBUInt8(bitmapData)) );
	}

	public static inline function createNPOTTexture(W:Int, H:Int, type:Int, dataKind = GL.FLOAT, filter = GL.NEAREST, ?data:UInt8Array):GLTexture{
		var tex:GLTexture = GL.createTexture();
		GL.bindTexture (GL.TEXTURE_2D, tex);
		GL.pixelStorei(GL.UNPACK_ALIGNMENT, 1);
		GL.texImage2D (GL.TEXTURE_2D, 0, type, W, H, 0, type, dataKind, data);
		//set params
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter); 
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter); 
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
		return tex;
	}

	//#! This conversion is pretty slow
	public static inline function bitmapDataToRGBUInt8(bitmapData:BitmapData):UInt8Array{
		var W:Int = bitmapData.width;
		var H:Int = bitmapData.height;
		var buf:UInt8Array = new UInt8Array(W*H*3);
		var color:UInt; 
		var i:Int;
		var j:Int;

		var bytes:ByteArray = bitmapData.getPixels(bitmapData.rect);

		//This is mega slow :[, times for a 912 × 912 image
		for(r in 0 ... H){
			for(c in 0 ... W){
				i = r*W + c;
				j = ((H-1)-r)*W + c;
				//(H-1-r) flips the image along y

				bytes.position = j*4;
				color = bytes.readInt();
				//images in javascript have the format RGBA, whilst in C++ and flash it is ARGB
				//eg: R  G  B  A
				//	  24 16 8  0
				#if !js
				buf[i*3] = 		color >> 16 & 0xFF;
				buf[i*3+1] = 	color >> 8 & 0xFF;
				buf[i*3+2] = 	color >> 0 & 0xFF;
				#else
				buf[i*3] = 		color >> 24 & 0xFF;
				buf[i*3+1] = 	color >> 16 & 0xFF;
				buf[i*3+2] = 	color >> 8 & 0xFF;
				#end
			}
		}

		return buf;
	}
	public static inline function bitmapDataToRGBAUInt8(bitmapData:BitmapData):UInt8Array{
		var W:Int = bitmapData.width;
		var H:Int = bitmapData.height;
		var buf:UInt8Array = new UInt8Array(W*H*4);
		var color:UInt; 
		var i:Int, j:Int;

		var bytes:ByteArray = bitmapData.getPixels(bitmapData.rect);
		for(r in 0 ... H){
			for(c in 0 ... W){
				i = r*W + c;
				j = ((H-1)-r)*W + c;

				bytes.position = j*4;
				color = bytes.readInt();
				#if !js 	//images in javascript have the format RGBA, whilst in C++ and flash it is ARGB
				buf[i*4+0] = 	color >> 16 & 0xFF;//red
				buf[i*4+1] = 	color >> 8  & 0xFF;//green
				buf[i*4+2] = 	color >> 0  & 0xFF;//blue
				buf[i*4+3] = 	color >> 24 & 0xFF;//alpha
				#else
				buf[i*4+0] = 	color >> 24 & 0xFF;	//red
				buf[i*4+1] = 	color >> 16  & 0xFF;//green
				buf[i*4+2] = 	color >> 8  & 0xFF;	//blue
				buf[i*4+3] = 	color >> 0 & 0xFF;	//alpha
				#end
			}
		}

		return buf;
	}
}