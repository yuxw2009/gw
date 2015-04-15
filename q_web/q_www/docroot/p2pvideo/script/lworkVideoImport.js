function lw_loadStyleSheet(e) {
	var t = document.createElement("link");
	t.setAttribute("rel", "stylesheet");
	t.setAttribute("type", "text/css");
	t.setAttribute("href", e);
	document.getElementsByTagName("head")[0].appendChild(t)
}

//开始加载
var lworkVideoDomain  = 'http://116.228.53.181';
lw_loadStyleSheet(lworkVideoDomain + "/style/style.css");