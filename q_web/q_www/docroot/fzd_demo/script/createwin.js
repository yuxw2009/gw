//创建窗体

var commonTemplate =  [
    '<div id="window_{id}_warp" class="LworkV_commonwin window-container window-current"  window="{id}" style="width:{width}px; height:{height}px;bottom:{bottom}px;right:{right}px;z-index:{zIndex}">',
      '<dl class="comwin_header header">',
        '<dd class="cm_l"></dd>',
        '<dd class="cm_c">',
          '<span class="cm_title">{name}</span>',
          '<div class="cm_btn"><a href="###" class="cw_close"></a></div>',
        '</dd>',
      '</dl>',
      '<dl class="comwinCon">',           
        '<dd class="comWin_box">',
        '</dd>',
      '</dl>',
    '</div>'].join('')


//窗口拖动模板
var resizeTemp = '<div resize="{resize_type}" style="position:absolute;overflow:hidden;background:url(images/transparent.gif) repeat;display:block;{css}" class="resize"></div>';



var Core = _cache = {};
Core.config = {
	createIndexid:1,		//z-index初始值
	windowMinWidth:150,		//窗口最小宽度
	windowMinHeight:56		//窗口最小高度
};


Core.create = function(opt){
	var defaults = {
			 'width'	:450,
			 'height': 490,
			 'num'	:Date.parse(new Date()),
			 'id'    : opt.id, 
			 'photo' : 'images/comwin-icon.png' ,
			 'name'  : '未知' ,
			 'status': '离线' ,
			 'Signature': '没有签名',
			 'content':'',
			 'resize': true,
			 'fixed': false,			 
			 'type':'p2p',
			 'service':'chat',
			 'from':opt.from,
			 'onCloseCallback':function(){}	
    };			
	var options = $.extend(defaults, opt || {});		
	var window_warp = 'window_'+options.id+'_warp';
	var window_inner = 'window_'+options.id+'_inner';
	var bottom = 50 ,  right = 15  ;
	var winH = $(window).height();
	var winW = $(window).width();

		//任务栏，窗口等数据
		if(options.from == 'server'){
			bottom  = (winH -options.height)/2 ;
		     right = (winW-options.width)/2;
		}

		
		
     	_cache.windowTemp = {"width":options.width,"height":options.height,"bottom":bottom,"right":right,"emptyW":$(window).width()-options.width,"emptyH":$(window).height()-options.height,"zIndex":Core.config.createIndexid,"id":options.id,"name":options.name,"photo":options.photo ,"status":options.status, "statuscss": (options.status == '在线' ? 'online' : 'offline') ,"Signature":options.Signature, type: options.type , service: options.service};		 
		_cache.resizeTemp = {"t":"left:0;top:-3px;width:100%;height:5px;z-index:1;cursor:n-resize","r":"right:-3px;top:0;width:5px;height:100%;z-index:1;cursor:e-resize","b":"left:0;bottom:-3px;width:100%;height:5px;z-index:1;cursor:s-resize","l":"left:-3px;top:0;width:5px;height:100%;z-index:1;cursor:w-resize","rt":"right:-3px;top:-3px;width:10px;height:10px;z-index:2;cursor:ne-resize","rb":"right:-3px;bottom:-3px;width:10px;height:10px;z-index:2;cursor:se-resize","lt":"left:-3px;top:-3px;width:10px;height:10px;z-index:2;cursor:nw-resize","lb":"left:-3px;bottom:-3px;width:10px;height:10px;z-index:2;cursor:sw-resize"};
		
		//新增窗口
		var ele = "";
		if(options.resize){
			//添加窗口缩放模板
			for(var k in _cache.resizeTemp){
				ele += FormatModel(resizeTemp,{resize_type:k,css:_cache.resizeTemp[k]});
			}	
			if(options.type == 'p2p'){
				ele = FormatModel(FormatModel(p2pchatwinTemplate,{resize:ele}),_cache.windowTemp);
			}else{
				ele = FormatModel(FormatModel(mpchatwinTemplate,{resize:ele}),_cache.windowTemp);
			}
		}else{		  	
			ele = FormatModel(FormatModel(commonTemplate,{resize:ele}),_cache.windowTemp);
		}		
		$('body').append(ele);
		//绑定窗口上各个按钮事件	
		$("#"+window_warp).data("info",_cache.windowTemp);	

		options.content.appendTo($("#"+window_warp).find('.comWin_box'));
/*		var ringFile = lworkVideoDomain+"/images/digit_ring.mp3";
		var ringDom=$('<video id="soundControl" src="'+ringFile+'" playcount="3" width="0" height="0" ></video>');
		ringDom.appendTo($("#"+window_warp));*/
		Core.config.createIndexid += 1;
		//Core.bindWindowResize($('#'+window_warp));
		Core.handle(options.id, options.onCloseCallback);
		Core.bindWindowMove();
		Core.resize();

};


Core.resize = function(update){
	var _top = Core.config.shortcutTop;
	var _left = Core.config.shortcutLeft;
	$(window).bind('resize',function(){
		_top = Core.config.shortcutTop;
		_left = Core.config.shortcutLeft;
		//智能修改每个窗口的定位
		$("div.window-container").each(function(){
			currentW = $(window).width() - $(this).width();
			currentH = $(window).height() - $(this).height();			
			_l = $(this).data("info").right/$(this).data("info").emptyW*currentW >= currentW ? currentW : $(this).data("info").right/$(this).data("info").emptyW*currentW;
			_l = _l <= 0 ? 0 : _l;
			_t = $(this).data("info").bottom/$(this).data("info").emptyH*currentH >= currentH ? currentH : $(this).data("info").bottom/$(this).data("info").emptyH*currentH;
			_t = _t <= 0 ? 0 : _t;
			$(this).animate({"right":_l+"px","bottom":_t + 10 +"px"},500);
		});
		
	})
	Core.bindWindowMove();
};

//最小化，最大化，还原，双击，关闭，刷新
Core.handle = function(winID, onCloseCallback){
    var target =  $('#window_'+winID+'_warp');	
	var video = document.getElementById('p2pvideo_'+ 96 +'_big');
	var updateStyle = function(obj){
		//改变窗口样式
		$('.window-container').removeClass('window-current');
		obj.addClass('window-current').css({'z-index':Core.config.createIndexid});
		Core.config.createIndexid += 1;
	};
	
	target.find('.cw_min').unbind('click').bind('click',function(e){
		var obj = $(this).parents(".window-container");
		updateStyle(obj);
		//最小化
		//阻止冒泡
		e.stopPropagation();
		obj.fadeOut();
		//改变任务栏样式
		$('#taskTemp_'+obj.attr('window')).find('b').removeClass('focus');
	});

	target.find('.cw_close').unbind('click').bind('click', function(){
		//  var obj = $(this).parents(".window-container");
		//	  updateStyle(obj);
		//	  $('#taskTemp_'+obj.attr('window')).remove();
		//	  obj.fadeOut("500", function(){
//				  obj.html('').remove();	
				  onCloseCallback();
		 //     });		
	});
	
	   target.find('.fullscreen').click(function(){ 
          video.webkitRequestFullScreen(); // webkit类型的浏览器
       //   video.mozRequestFullScreen();  // FireFox浏览器
       });
        video.addEventListener('timeupdate', function() {
           var curTime = Math.floor(video.currentTime);
           var hour = parseInt(curTime / 3600);// 分钟数      
           var min = parseInt(curTime / 60);// 分钟数
           var sec = parseInt(curTime % 60);
           var txt = (parseInt(hour, 10) < 10 ? '0' + hour : hour)  + ":" + (parseInt(min, 10) < 10 ? '0' + min : min)  + ":" + (parseInt(sec, 10) < 10 ? '0' + sec : sec); 

		   target.find('.videoCurrentTime').text(txt);
        }, true);	

}




//绑定窗口移动事件
Core.bindWindowMove = function(){
	$(document).delegate(".header","mousedown",function(e){
		var target = e.target;
		if (target.tagName === 'a' || target.tagName === 'A'||target.tagName === 'span' || target.tagName === 'SPAN'||target.tagName === 'input' || target.tagName === 'INPUT') {
			return false;	
		}
		var obj = $(this).parents(".window-container");
		//改变窗口为选中样式
		$( "body" ).addClass( "noSelect" );		
		$('.window-container').removeClass('window-current');
		obj.addClass('window-current').css({'z-index':Core.config.createIndexid});
		Core.config.createIndexid += 1;
		
		x = e.screenX;	//鼠标位于屏幕的left
		y = e.screenY;	//鼠标位于屏幕的top
		sT = obj.offset().top;
		sL = obj.offset().left;
		//增加背景遮罩层
		//_cache.MoveLayOut = GetLayOutBox();
		var lay = ($.browser.msie) ? _cache.MoveLayOut : $(window);	
		//绑定鼠标移动事件
		lay.bind("mousemove",function(e){
			//_cache.MoveLayOut.show();
			//强制把右上角还原按钮隐藏，最大化按钮显示			
			//obj.find(".ha-revert").hide().prev(".ha-max").show();			
			eX = e.screenX;	//鼠标位于屏幕的left
			eY = e.screenY;	//鼠标位于屏幕的top
			lessX = eX - x;	//距初始位置的偏移量
			lessY = eY - y;	//距初始位置的偏移量
			_l = sL + lessX;
			_t = sT + lessY;
			_w = obj.data("info").width;
			_h = obj.data("info").height;
			obj.css({width:_w,height:_h,left:_l,top:_t});			
			obj.find('.chatWin_con').height(obj.height() -262 );
			if(obj.find('.ribbonBox').length>0 && obj.find('.ribbonBox').css('display') != 'none'){				
			 obj.find('.chatWin_conbox').width( obj.width() - obj.find('.ribbonBox').width());				
			}
			//obj.css({left:_l,top:_t-1});
			obj.data("info",{width:obj.data("info").width,height:obj.data("info").height,left:obj.offset().left,top:obj.offset().top,emptyW:$(window).width()-obj.data("info").width,emptyH:$(window).height()-obj.data("info").height , type:obj.data("info").type  , service: obj.data("info").service});
		//	ie6iframeheight(obj);
		});
		
		//绑定鼠标抬起事件
		lay.unbind("mouseup").bind("mouseup",function(e){
			var target = e.target;	
			$( "body" ).removeClass( "noSelect" );
		//	_cache.MoveLayOut.hide();
			if($.browser.msie){
				_cache.MoveLayOut[0].releaseCapture();
			}
			$(this).unbind("mousemove");
		});
		
		if($.browser.msie){
			_cache.MoveLayOut[0].setCapture();
		}
		
	});
};



//绑定窗口缩放事件
Core.bindWindowResize = function(obj){	
	for(rs in _cache.resizeTemp){
		bindResize(rs);
	}
	function bindResize(r){		
		obj.find("div[resize='"+r+"']").bind("mousedown",function(e){
			//增加背景遮罩层
			_cache.MoveLayOut = GetLayOutBox();
			var lay = ($.browser.msie)? _cache.MoveLayOut : $(window);	
			cy = e.clientY;
			cx = e.clientX;
			h = obj.height();
			w = obj.width();
			lay.unbind("mousemove").bind("mousemove",function(e){
				_cache.MoveLayOut.show();
				_t = e.clientY;
				_l = e.clientX;
				//窗口贴屏幕顶部10px内
				if(_t <= 10){
					_t = 0;
				}
				//窗口贴屏幕底部60px内
				if(_t >= (lay.height()-60)){
					_t = (lay.height()-60);
				}
				
				if(_l <= 1){
					_l = 1;
				}
				if(_l >= (lay.width()-2)){
					_l = (lay.width()-2);
				}
			    //$('.window-frame').children('div').eq(0).hide();
				//obj.find('.window-frame').children('div').eq(0).show();
				switch(r){
					case "t":
						if(h+cy-_t > Core.config.windowMinHeight){
							obj.css({height:(h+cy-_t)+"px",top:_t+"px"});
						}
					break;
					case "r":
						if(w-cx+_l > Core.config.windowMinWidth){
							obj.css({width:(w-cx+_l)+"px"});
						}
					break;
					case "b":
						if(h-cy+_t > Core.config.windowMinHeight){
							obj.css({height:(h-cy+_t)+"px"});
						}
					break;
					case "l":
						if(w+cx-_l > Core.config.windowMinWidth){
							obj.css({width:(w+cx-_l)+"px",left:_l+"px"});
						}
					break;
					case "rt":
						if(h+cy-_t > Core.config.windowMinHeight){
							obj.css({height:(h+cy-_t)+"px",top:_t+"px"});
						}
						if(w-cx+_l > Core.config.windowMinWidth){
							obj.css({width:(w-cx+_l)+"px"});
						}
					break;
					case "rb":
						if(w-cx+_l > Core.config.windowMinWidth){
							obj.css({width:(w-cx+_l)+"px"});
						}
						if(h-cy+_t > Core.config.windowMinHeight){
							obj.css({height:(h-cy+_t)+"px"});
						}
					break;
					case "lt":
						if(w+cx-_l > Core.config.windowMinWidth){
							obj.css({width:(w+cx-_l)+"px",left:_l+"px"});
						}
						if(h+cy-_t > Core.config.windowMinHeight){
							obj.css({height:(h+cy-_t)+"px",top:_t+"px"});
						}
					break;
					case "lb":
						if(w+cx-_l > Core.config.windowMinWidth){
							obj.css({width:(w+cx-_l)+"px",left:_l+"px"});
						}
						if(h-cy+_t > Core.config.windowMinHeight){
							obj.css({height:(h-cy+_t)+"px"});
						}
					break;
				}
			//	ie6iframeheight(obj);
				//更新窗口宽高缓存
				obj.data("info",{width:obj.width(),height:obj.height(),left:obj.offset().left,top:obj.offset().top, emptyW:$(window).width()-obj.width(),emptyH:$(window).height()-obj.height()});
			});
			//绑定鼠标抬起事件
			lay.unbind("mouseup").bind("mouseup",function(){
				_cache.MoveLayOut.hide();
				if($.browser.msie){
					_cache.MoveLayOut[0].releaseCapture();
				}
				$(this).unbind("mousemove");
			});
			if($.browser.msie){
				_cache.MoveLayOut[0].setCapture();
			}
		});
	}
};


//模板格式化（正则替换）
var FormatModel = function(str,model){
	for(var k in model){
		var re = new RegExp("{"+k+"}","g");
		str = str.replace(re,model[k]);
	}
	return str;
};

//透明遮罩层
var GetLayOutBox = function(){
	if(!_cache.LayOutBox){
		_cache.LayOutBox = $('<div style="z-index:1000000003;display:none;cursor:default;background:none;height:100%;left:0;position:absolute;top:0;width:100%;filter:alpha(opacity=0);-moz-opacity:0;opacity:0"><div style="height:100%;width:100%"></div></div>');
		$(document.body).append(_cache.LayOutBox);
	}
	return _cache.LayOutBox;
};


function lwork_create_video_win(opts){
    if($('#window_LworkVideoCS_warp').length>0){
        $('#window_LworkVideoCS_warp').remove();
    }
    Core.create(opts);
}
