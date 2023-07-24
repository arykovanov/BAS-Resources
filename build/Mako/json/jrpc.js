function ErrorType(t,e,r){for(var s in r=r||{},this.e=new Error(""),this.message=t,this.errno=e,r.e&&r.e.message&&(this.e.orgMsg=r.message,this.e.orgErrno=r.errno,r=r.e),r)try{this.e[s]=r[s]}catch(t){}}function XMLHttpRequestWrapper(){var e;try{this.xmlhttp=new ActiveXObject("Microsoft.XMLHTTP")}catch(t){try{this.xmlhttp=new XMLHttpRequest}catch(t){e=t}}if(!this.xmlhttp)throw new ErrorType("No XMLHttpRequest support in browser",1e3,e);this.$$bindOnreadystatechange()}function JRpc(t,e,r){this.bimode=1==r,this.$url=t;new XMLHttpRequestWrapper;if(e&&("function"==typeof e||"object"==typeof e&&"function"==typeof e.onResponse)){r={rpc:this,a:e,onResponse:function(t,e){if(delete this.rpc.$noCheck,t){for(var r=e.procs,s=0;s<r.length;s++)this.rpc.$addMethod(r[s]);JRpc.$execResponse(this.a,!0)}else JRpc.$execResponse(this.a,!1,e)}};this.$noCheck=!0,this.$send("system.describe",r)}else if(null==e||1==e)for(var s=this.$send("system.describe").procs,o=0;o<s.length;o++)this.$addMethod(s[o])}XMLHttpRequestWrapper.prototype.$$bindOnreadystatechange=function(){var t=this;this.xmlhttp.onreadystatechange=function(){t.$$onreadystatechange()};try{req.xmlhttp.onerror=function(){t.$$onerror()}}catch(t){}},XMLHttpRequestWrapper.prototype.$$onreadystatechange=function(){if(4==this.xmlhttp.readyState){try{this.xmlhttp.status&&(this.status=this.xmlhttp.status),this.$exception={}}catch(t){this.$exception=t}(!this.status||1e3<this.status)&&(this.status=-1)}this.onreadystatechange&&this.onreadystatechange(this.xmlhttp.readyState)},XMLHttpRequestWrapper.prototype.$$onerror=function(){this.xmlhttp.status=-1,this.onreadystatechange(4)},XMLHttpRequestWrapper.prototype.getResponseHeader=function(e){try{return this.xmlhttp.getResponseHeader(e)}catch(t){throw new ErrorType("getResponseHeader('"+e+"') failed",1001,t)}},XMLHttpRequestWrapper.prototype.getResponseText=function(){try{return this.xmlhttp.responseText}catch(t){throw new ErrorType("getResponseText failed",1002,t)}},XMLHttpRequestWrapper.prototype.getRresponseXML=function(){try{return this.xmlhttp.responseXML}catch(t){throw new ErrorType("getRresponseXML failed",1003,t)}},XMLHttpRequestWrapper.prototype.open=function(t,e){try{switch(arguments.length){case 2:this.xmlhttp.open(t,e);break;case 3:this.xmlhttp.open(t,e,arguments[2]);break;default:this.xmlhttp.open(t,e,arguments[2],arguments[3],arguments[4])}}catch(t){throw new ErrorType("Failed: open url "+e+" :",1004,t)}},XMLHttpRequestWrapper.prototype.setRequestHeader=function(t,e){try{this.xmlhttp.setRequestHeader(t,e)}catch(t){throw new ErrorType("setRequestHeader failed",1005,t)}},XMLHttpRequestWrapper.prototype.send=function(t){try{this.xmlhttp.send(t);try{this.xmlhttp.status&&(this.status=this.xmlhttp.status)}catch(t){}}catch(t){throw new ErrorType("send failed",1006,t)}},XMLHttpRequestWrapper.prototype.abort=function(){try{this.xmlhttp.abort()}catch(t){}},JRpc.$execResponse=function(t,e,r,s){"object"==typeof t?t.onResponse(e,r,s):t(e,r,s)},JRpc.prototype.$mkRpcMethod=function(t,e){for(var r=this,s=t.split("."),o=0;o<s.length-1;o++)var p=s[o],r=r[p]||(r[p]=new Object,r[p]);r[s[o]]=e},JRpc.prototype.$addMethod=function(t){var e=this;this.$mkRpcMethod(t,function(){return e.$call(t,arguments)})},JRpc.prototype.$call=function(t,e){var r;if(e.length){var s=0,o=e[0];if(("function"==typeof o||"object"==typeof o&&"function"==typeof o.onResponse)&&(r=o,s=1),e.length>s)for(var p=s,n=[],a=0;p<e.length;a++,p++)n[a]=e[p]}return this.$rpc(t,r,n)},JRpc.prototype.$checkRpcResp=function(t){if(t.error){var e=new ErrorType("Server error",2e3,t.error);try{e.message=t.error.message,e.code=t.error.code,e.error=t.error.error}catch(e){}throw e}return t.result},JRpc.prototype.$rpc=function(t,e,r){t=this.$send(t,e,r);if(!e)return this.$checkRpcResp(t)},JRpc.prototype.$onreadystatechange=function(t){if(4==t){var e,r,t=this.$respObj;if(200==this.status){try{if(!(e=this.$rpc.bimode?BiJson.deserialize(this.getResponseText()):JSON.parse(this.getResponseText())))throw new ErrorType("Cannot parse",2002,0);var s=this.$rpc;s.$noCheck||(e=s.$checkRpcResp(e)),r=!0}catch(t){e=t}try{r?JRpc.$execResponse(t,!0,e):JRpc.$execResponse(t,!1,e,200)}catch(t){alert(t)}}else{this.$exception.message||(this.$exception.message="RPC failed: "+this.status);try{this.$exception.status=this.status,JRpc.$execResponse(t,!1,this.$exception,this.status)}catch(t){alert(t)}}}},JRpc.prototype.$send=function(e,t,r){var s;try{var o='{"version":"1.1","method":"'+e+'"',p=(r&&(o=this.bimode?o+',"params":'+BiJson.serialize(r):o+',"params":'+JSON.stringify(r)),o+="}",new XMLHttpRequestWrapper);if(t?(p.onreadystatechange=JRpc.prototype.$onreadystatechange,p.$respObj=t,p.$rpc=this,p.open("POST",this.$url)):p.open("POST",this.$url,!1),p.setRequestHeader("Content-Type","application/json"),p.setRequestHeader("PrefAuth","digest"),p.send(o),t)return;if(p.status&&200!=p.status)throw"HTTP status "+p.status;if(!(s=this.bimode?BiJson.deserialize(p.getResponseText()):JSON.parse(p.getResponseText())))throw"Cannot parse JSON server response"}catch(t){t=new ErrorType("Calling "+e+" failed",2004,t);try{t.status=p.status}catch(t){}throw t}return s},JRpc.prototype._call=function(t){var e;if(1<arguments.length){var r=1;if("object"==typeof arguments[1]&&"function"==typeof arguments[1].onResponse&&(e=arguments[1],r=2),r<arguments.length)for(var s=[],o=r,p=0;o<arguments.length;p++,o++)s[p]=arguments[o]}return this.$rpc(t,e,s)};