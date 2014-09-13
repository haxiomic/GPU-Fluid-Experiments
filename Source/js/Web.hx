package js;

import haxe.ds.StringMap;

class Web{
	static public function getParams():StringMap<String>{
		var result = new StringMap<String>();

		var paramObj = js.Lib.eval("
			(function() {
			    var match,
			        pl     = /\\+/g,  // Regex for replacing addition symbol with a space
			        search = /([^&=]+)=?([^&]*)/g,
			        decode = function (s) { return decodeURIComponent(s.replace(pl, ' ')); },
			        query  = window.location.search.substring(1);

			    var urlParams = {};
			    while (match = search.exec(query))
			       urlParams[decode(match[1])] = decode(match[2]);
			    return urlParams;
			})();
		");

		for(f in Reflect.fields(paramObj)) result.set(f, Reflect.field(paramObj, f));
		return result;
	}
}