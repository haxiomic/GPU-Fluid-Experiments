package;

import haxe.ds.Vector;

class PerformanceMonitor{
	public var fpsAverage(get, null):Float;
	public var fpsVariance(get, null):Float;
	public var fpsStandardDeviation(get, null):Float;

	public var lowerBoundFPS:Float;
	public var upperBoundFPS:Null<Float>;

	public var fpsIgnoreBounds:Array<Float> = [5, 180]; 

	public var fpsTooLowCallback:Float->Void = null;
	public var fpsTooHighCallback:Float->Void = null;

	var fpsSample:RollingSample;

	var lowerBoundEnterTime:Null<Float> = null;
	var upperBoundEnterTime:Null<Float> = null;
	var thresholdTime_ms:Float;

	public function new(lowerBoundFPS:Float = 30, ?upperBoundFPS:Float, thresholdTime_ms:Float = 3000, fpsSampleSize:Int = 30){
		this.lowerBoundFPS = lowerBoundFPS;
		this.upperBoundFPS = upperBoundFPS;
		this.thresholdTime_ms = thresholdTime_ms;
		this.fpsSample = new RollingSample(fpsSampleSize);
	}

	public inline function recordFrameTime(dt_seconds:Float) if(dt_seconds>0) recordFPS(1/dt_seconds);
	public inline function recordFPS(fps:Float){
		//clip readings
		if(fps < fpsIgnoreBounds[0] && fps > fpsIgnoreBounds[1]) return;
		fpsSample.add(fps);
		//check if sample is completed
		if(fpsSample.sampleCount < fpsSample.length) return;

		var now = haxe.Timer.stamp() * 1000;

		if(fpsSample.average < lowerBoundFPS){
			if(lowerBoundEnterTime == null)lowerBoundEnterTime = now;

			if((now - lowerBoundEnterTime) >= thresholdTime_ms && fpsTooLowCallback != null){
				fpsTooLowCallback((lowerBoundFPS - fpsSample.average) / lowerBoundFPS);
				fpsSample.clear();
				lowerBoundEnterTime = null;
			}

		}else if(fpsSample.average > upperBoundFPS){
			if(upperBoundEnterTime == null)upperBoundEnterTime = now;

			if((now - upperBoundEnterTime) >= thresholdTime_ms && fpsTooHighCallback != null){
				fpsTooHighCallback((fpsSample.average - upperBoundFPS) / upperBoundFPS);
				fpsSample.clear();
				upperBoundEnterTime = null;
			}
		}else{
			lowerBoundEnterTime = null;
			upperBoundEnterTime = null;	
		}

	}

	inline function get_fpsAverage():Float return fpsSample.average;
	inline function get_fpsVariance():Float return fpsSample.variance;
	inline function get_fpsStandardDeviation():Float return fpsSample.standardDeviation;
}

class RollingSample{
	public var average(default, null):Float = 0;
	public var variance(get, null):Float = 0;
	public var standardDeviation(get, null):Float = 0;
	public var sampleCount(default, null):Int = 0;
	public var length(default, null):Int;

	var samples:Vector<Float>;
	var pos:Int = 0;
	var m2:Float = 0;//sum of squares of differences from the (current) mean

	public function new(length:Int){
		this.samples = new Vector<Float>(length);
	}

	public function add(v:Float):Int{
		//http://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
		var delta:Float;

		//we need to check if we've already wrapped round
		if(this.sampleCount >= this.samples.length){
			//remove bottom of stack from mean
			var bottomValue = this.samples.get(pos);
			delta = bottomValue - this.average;
			this.average -= delta/(this.sampleCount-1);
			m2 -= delta*(bottomValue - this.average);
		}else this.sampleCount++;

		//add new value to mean
		delta = v - this.average;
		this.average += delta/(this.sampleCount);
		m2 += delta*(v - this.average);

		this.samples.set(pos, v);
		pos++;

		pos %= this.samples.length;//positive wrap around
		return pos;
	}

	public function clear(){
		for (i in 0...this.samples.length) this.samples.set(i, 0);
		this.average = 0;
		this.variance = 0;
		this.standardDeviation = 0;
		this.sampleCount = 0;
		this.m2 = 0;
	}

	function get_variance():Float return this.m2/(this.sampleCount-1);
	function get_standardDeviation():Float return Math.sqrt(this.variance);
	function get_length():Int return this.samples.length;
}