//动态加载JS与CSS文件库
function JSLoaderEnvironment(){
  // Default
  this.prefix="/assets/";
  var _remote=false;
  var s=0;
  var _script_tags=document.getElementsByTagName("script");
  var endsWith=function(str, substr){
    return (str && str.indexOf(substr) == (str.length-substr.length));
  };
  for(s=0;s<_script_tags.length;++s){ 
    var src=_script_tags[s].src;
    var src_orig=src;
    if(src){
      if(src.indexOf("://")>-1)
	{
	  src=src.substring(src.indexOf("://")+3);
	  src=src.substring(src.indexOf("/"));
	}
      if(endsWith(src,"jsloader.js")  || endsWith(src,"jsloader-debug.js")) {
		// If the domain is remote, assume we're running in hosted mode
		_remote=(src_orig.indexOf(document.domain)==-1);
		if(_remote) src=src_orig;
	  
	  this.prefix=src.substring(0, src.lastIndexOf("/")+1);
      }
    }
  }
  /**
   * @private
   */
  this.suffix=".js";

  this.makeJSLoaderPath=function(m,p,r,suff){

    if(!p && !r) return this.stripExternalRef(m);

    return this.prefix+m+"/"+p+"/incr/versions/"+r+ ((suff)?this.suffix:"");
  }
  this.makePath=function(m,p,r){
    if(!p && !r) return this.stripExternalRef(m);
    return this.prefix + m +"/" + p + "/" + r + "/";
  }
  
  this.env=new Object();
  this.loaders=new Object();
  this.setEnv=function(k,v){ 
    this.env[k]=v;
  }
  this.getEnv=function(k){ return this.env[k];}
  this._loadedJSLoaders=new Object();
  this.normalize=function(m,p,r){ return (m+"__"+p+"__"+r).toLowerCase();};
  this.isLoaded=function(m,p,r){
    var xkey=this.normalize(m,p,r);
    return(this._loadedJSLoaders[xkey]!=null);
  };
  this.getLoader=function(m,p,r){
    var key=this.normalize(m,p,r);
    var loader=this.loaders[key];
    if(loader) {
      return loader;
    }
    else {
      loader=new JSSubLoader(this,this.makeJSLoaderPath(m,p,r,false)+"/");
      var __path=this.makePath(m,p,r);
      this.setEnv(p.toUpperCase()+"_PATH",__path);
      this.loaders[key]=loader;
      return loader;
    }
  }
  this.load=function(m,p,r){
    var key=this.normalize(m,p,r);
    var url=this.makeJSLoaderPath(m,p,r,true); 
    try{
      if(this.isLoaded(m,p,r)) {
	return;
      }
      this.loadJavaScript(url);
      this._loadedJSLoaders[key]="true";
    } catch (e){ this.handleError(e); }
  };
  this.loadJavaScript=function (url){
    url = this.stripExternalRef(url);
    document.writeln("<scri"+"pt src='"+url+"' type='text/javascript' charset='utf-8'></sc"+"ript>");
  };

  this.loadStyleSheet=function(url){
    url = this.stripExternalRef(url);
    document.writeln("<li"+"nk rel='stylesheet' href='"+url+"' type='text/css' charset='utf-8'></li"+"nk>");
  };
  this.stripExternalRef=function(s){
    var exprs = [/\.\.+/g,/\/\/+/g,/\\\\+/g,/\:+/g,/\'+/g,/\%+/g];
    // If it's hosted, we relax the protocol related regex
    exprs = [/\.\.+/g,/\\\\+/g,/\'+/g,/\%+/g];
    
    if (_remote)
    
    for(var i=0; i<exprs.length; i++)
      {
	s = s.replace(exprs[i], '');
      }

    return s;
  }
  /**
   *  Overwritable error handler
   */
  this.handleError=function(e) {
  }
 
  return this;
};
function JSSubLoader(env_, prefix_){

  this.environment=env_;

  this.prefix=prefix_;


  this.loaded=new Object();

  this.normalize=function(str){ return str.toLowerCase(); }
  

  this.loadAll=function(pkgs_){
    for(i=0;i<pkgs_.length;++i) this.load(pkgs_[i]);
  };

  this.load=function(pkg){
    var p=this.normalize(pkg);
    if (this.loaded[p]) {
      return;
    }
    this.loaded[p]=pkg;
    this.environment.loadJavaScript(prefix_+pkg+".js");
  };
};

lw_JSLoader = new JSLoaderEnvironment();
//动态加载代码结束

//开始加载
var lworkVideoDomain  = "https://www.dianpingcall.com";
lw_JSLoader.loadJavaScript(lworkVideoDomain+"/script/lw2fzd.130905.js")