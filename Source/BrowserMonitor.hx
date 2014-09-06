package;

import lime.app.Application;

class BrowserMonitor{
	public var browserName(default, null):String;
	public var userAgent(default, null):String;

	public var windowWidth(default, null):Int;
	public var windowHeight(default, null):Int;

	public var averageFPS(default, null):Float = 0;
	public var averageFrameTime(default, null):Float = 0; //ms

	public var mouseClicks(default, null):Int = 0;

	public var userData:Dynamic = {};

	var beginTime:Float;
	var timeSamples:Int = 0;
	var serverURL:String;

	public function new(?app:Application, ?serverURL:String = null){
		#if !js
		return;
		#end
		this.serverURL = serverURL;
		this.userAgent = js.Browser.navigator.userAgent; 
		this.browserName = js.Lib.eval("
			(function(){
			    var ua= navigator.userAgent, tem, 
			    M= ua.match(/(opera|chrome|safari|firefox|msie|trident(?=\\/))\\/?\\s*(\\d+)/i) || [];
			    if(/trident/i.test(M[1])){
			        tem=  /\\brv[ :]+(\\d+)/g.exec(ua) || [];
			        return 'IE '+(tem[1] || '');
			    }
			    if(M[1]=== 'Chrome'){
			        tem= ua.match(/\\bOPR\\/(\\d+)/)
			        if(tem!= null) return 'Opera '+tem[1];
			    }
			    M= M[2]? [M[1], M[2]]: [navigator.appName, navigator.appVersion, '-?'];
			    if((tem= ua.match(/version\\/(\\d+)/i))!= null) M.splice(1, 1, tem[1]);
			    return M.join(' ');
			})();
		");

		this.windowWidth = js.Browser.window.innerWidth;
		this.windowHeight = js.Browser.window.innerHeight;

		lime.ui.MouseEventManager.onMouseUp.add(function(x:Float, y:Float, button:Int){
			mouseClicks++;
		});
	}

	public function sendReportAfterTime(seconds:Int){
		haxe.Timer.delay(this.sendReport, seconds * 1000 );
	}

	public function sendReport(){
		if(serverURL == null)return;
		var data = createReportJSON();
		var request = new js.html.XMLHttpRequest();
		request.open('POST', serverURL, true);
		request.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
		request.send(data);
	}

	public inline function isSafari():Bool return (~/Safari/i).match(browserName);
	public inline function isChrome():Bool return (~/Chrome/i).match(browserName);
	public inline function isFirefox():Bool return (~/Firefox/i).match(browserName);

	public inline function addDt(dt_ms:Float){
		if((dt_ms > 8.3) && (dt_ms < (1000/5))){
			averageFrameTime = (averageFrameTime/(1+1/timeSamples)) + (dt_ms/(timeSamples+1));
			averageFPS = 1000/averageFrameTime;
			timeSamples++;
		}
	}

	inline function createReportJSON(){
		return haxe.Json.stringify({
			browserName      : browserName,
			userAgent        : userAgent,
			windowWidth      : windowWidth,
			windowHeight     : windowHeight,
			averageFPS       : Math.round(averageFPS * 100)/100,
			// averageFrameTime : averageFrameTime + ' ms',
			timeSamples      : timeSamples,
			mouseClicks      : mouseClicks,
			userData         : userData
		});
	}
}