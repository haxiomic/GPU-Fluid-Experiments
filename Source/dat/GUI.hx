package dat;

//see https://github.com/dataarts/dat.gui

extern class GUI {
	public function new(?params:Dynamic):Void;
	@:overload(function(object:Dynamic, property:String, min:Float, max:Float):GUI{})
	@:overload(function(object:Dynamic, property:String, ?args:Dynamic):GUI{})
	public function add(object:Dynamic, property:String, ?args:Array<Dynamic>):GUI;
	public function addColor(object:Dynamic, property:String):GUI;
	public function remove(controller:Dynamic):GUI;
	public function destroy():GUI;
	public function addFolder(name:String):GUI;
	public function open():GUI;
	public function close():GUI;
	public function onResize():GUI;
	@:overload(function(objects:Array<Dynamic>):GUI{})
	public function remember(?object:Dynamic):GUI;
	public function getRoot():GUI;
	public function getSaveObject():GUI;
	public function save():GUI;
	public function saveAs(presetName:String):GUI;
	public function revert(gui:GUI):GUI;
	public function listen(?controller:Dynamic):GUI;
	public function name(name:String):GUI;
	//Controller
	public function onChange(fnc:Dynamic):GUI;
	public function onFinishChange(fnc:Dynamic):GUI;
	public function setValue(newValue:Dynamic):GUI;
	public function getValue():GUI;
	public function updateDisplay():GUI;
	public function isModified():GUI;
	//FunctionController
	public function fire():GUI;
	//NumberController
	public function min(v:Float):GUI;
	public function max(v:Float):GUI;
	public function step(v:Float):GUI;
}

