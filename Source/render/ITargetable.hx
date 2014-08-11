package render;

import lime.graphics.GLRenderContext;

interface ITargetable{
	private var gl(default, null):GLRenderContext;
	public var width(default, null):Int;
	public var height(default, null):Int;
	public function activate():Void;
	public function clear():Void;
}