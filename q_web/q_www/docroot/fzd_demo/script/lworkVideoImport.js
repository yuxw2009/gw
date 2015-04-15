function lw_loadStyleSheet(e) {
  var t = document.createElement("link");
  t.setAttribute("rel", "stylesheet");
  t.setAttribute("type", "text/css");
  t.setAttribute("href", e);
  document.getElementsByTagName("head")[0].appendChild(t);
}

var lworkVideoDomain = "http://58.221.59.169";
var lwqnDir = lworkVideoDomain+"/qn_demo";
//开始加载
lw_loadStyleSheet(lwqnDir + "/style/style.css");
/*JSLoader.loadJavaScript(lworkVideoDomain + "/script/jquery-1.6.3.min.js");
JSLoader.loadJavaScript(lworkVideoDomain + "/script/createwin.js");
JSLoader.loadJavaScript(lworkVideoDomain + "/script/webrtc.js");
JSLoader.loadJavaScript(lworkVideoDomain + "/script/restconnection.js");
JSLoader.loadJavaScript(lworkVideoDomain + "/script/restchannel.js");
JSLoader.loadJavaScript(lworkVideoDomain + "/script/p2pdemo.js");
JSLoader.loadJavaScript(lworkVideoDomain + "/script/tipsplugin.js");
*/