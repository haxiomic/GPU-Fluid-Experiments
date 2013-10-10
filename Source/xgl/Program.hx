package xgl;

import haxe.ds.StringMap;
import openfl.gl.GL;
import openfl.gl.GLProgram;
import openfl.gl.GLUniformLocation;
import xgl.GLUtils;

/* #! Implement array access to get and set uniforms, eg: shader['time'] = 0;*/
@:rtti //support runtime type information
class Program
{
	//--Core--
	//Vertex
	//attributes
	public var uniforms:StringMap<ShaderUniform>;	//complete list of uniforms
	public var glProgram(default, null):GLProgram;

	//Core attributes
	public var vertexPosition:Int;

	private function new(vertexShader:String, fragmentShader:String, precision:Int = 0){
		uniforms = new StringMap<ShaderUniform>();

		//Setup shaders (http://www.opengl.org/sdk/docs/manglsl/)
		//Handle precision
		var precisionString:String = "";

		//Cannont use precision on desktop
		#if desktop
			precision = -1;
		#end

		switch (precision) {
			case -1:					//Let shader decide
				precisionString = "";	
			case 0:
				precisionString = GLUtils.highpfloat;
			case 1:
				precisionString = GLUtils.mediumpfloat;
			case 2:
				precisionString = GLUtils.lowpfloat;
			default:
				precisionString = GLUtils.highpfloat;
		}

		vertexShader = precisionString + vertexShader;
		fragmentShader = precisionString + fragmentShader;

		//Create program
		glProgram = GLUtils.createProgram(vertexShader, fragmentShader);

		//Shader - cpu link
		vertexPosition = GL.getAttribLocation(glProgram, "position");
		GL.enableVertexAttribArray(vertexPosition);
		
		//GL.vertexAttribPointer(vertexPosition, 2, GL.FLOAT, false, 0, 0);
		//This means that "position" will now handel the ARRAY_BUFFER, the '2' being the number of values to a point. (2D) 
		//glVertexAttribPointer specifies the location and data format of the array of generic vertex attributes at index index to use when rendering

		//Extract uniforms
		extractUniforms(vertexShader);
		extractUniforms(fragmentShader);

	//	super(GL.version, glProgram.id);, can't use this trick in webgl :[
	}

	/*@:to inline public function toGLProgram():GLProgram{
		return this.glProgram;
	}*/

	inline public function uniformLocation(name:String):GLUniformLocation{
		return uniforms.get(name).location;
	}

	// public function setUniform(name:String, v:Dynamic){
	// 	uniforms.get(name).autoSet(v);
	// }

	private function extractUniforms(shader:String){
		//Finds uniform variables in shader, adds to store with location
		var uniformClassFields:Array<String> = new Array<String>();

		//Finds all the class fields of type GLUniformLocation, these are then filled with the location in the shader if they match the name
		var rtti : String = untyped Reflect.field(Type.getClass(this),'__rtti');
		var x = Xml.parse(rtti).firstElement();	//Class element
		for(n in x.elements()){
			var fieldName:String = n.nodeName;
			var typeElement:Xml = n.elementsNamed("t").next();
			if(typeElement==null)continue;

			var typePath = typeElement.get("path");
			//Extract last part of path
			var re = ~/.*\.(\w+)$/;
			re.match(typePath);
			var typeName = re.matched(1);

			if(typeName == "GLUniformLocation")
				uniformClassFields.push(fieldName);
		}


		//Non-array Uniforms
		//eg: uniform int imageCount;
		var r = ~/(uniform)\s+([a-z0-9_]*)\s+([a-z0-9_]*)?\s*;/i;
		  
		var str = shader;
		var name:String;
		var type:String;
		var location:GLUniformLocation;
		while(r.match(str)){
			type = r.matched(2);
			name = r.matched(3);

			if(!uniforms.exists(name)){
				location = openfl.gl.GL.getUniformLocation(glProgram, name);
				uniforms.set( name, new ShaderUniform(type, name, location));

				//Fill fast access core uniforms
				for(f in uniformClassFields)
					if(f==name)Reflect.setField(this, f, location);
			
			}

		    str = r.matchedRight();
		}

		//Match uniform arrays
		r = ~/(uniform)\s+([a-z0-9_]*)\s+([a-z0-9_]*)(\[([0-9]+)\])?\s*;/i;

		str = shader;
		var arraySize:Int;
		while(r.match(str)){
			type = r.matched(2);
			name = r.matched(3);
			arraySize = Std.parseInt(r.matched(5));

			if(!uniforms.exists(name)){
				location = openfl.gl.GL.getUniformLocation(glProgram, name);
				uniforms.set( name, new ShaderUniform(type, name, location, arraySize));

				//Fill fast access core uniforms
				for(f in uniformClassFields)
					if(f==name)Reflect.setField(this, f, location);
			}
			
		    str = r.matchedRight();
		}
	}
}

class ShaderUniform{
	/* Todo:
	#! picking glUniform based on type */ 

	public var typeStr(default, null):String;
	public var name(default, null):String;
	public var location:GLUniformLocation;

	private var prim:Int = -1;
	private var dimentions(default, null):Int;
	private var arraySize:Int;

	public function new(typeStr:String, name:String, location:GLUniformLocation, ?arraySize){
		this.typeStr = typeStr;
		this.name = name;
		this.location = location;
	}
/*
	inline public function autoSet(value:Dynamic):Void{
		//glUniform{1|2|3|4}{f|i|ui}(v)
		//glUniformMatrix{2|3|4|2x3|3x2|2x4|4x2|3x4|4x3}fv
		//Sampler2D => uniform1i
	}

	static var typeMap:StringMap<Int> = [
		'bool'   => 0,
		'int'    => 1,
		'float'  => 2,
		'double' => 3,
		'vec'    => 4,
		'mat'    => 5
	];

	static var primMap:StringMap<Int> = [
		'f'  => 0,
		'i'  => 1,
		'ui' => 2,
	];

	//static public var types:Array;
	bool
	int
	uint
	float
	double
	//dimentional
	bvec n
	ivec n
	uvec n
	vec n
	dvec n
	//matricies
	//all matricies are floating point, mat or double dmat
	mat n
	mat nxm
	dmat n
	dmat nxm
	*/
}