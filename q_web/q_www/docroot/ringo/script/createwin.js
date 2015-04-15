//创建窗体
var Core = _cache = {};
Core.config = {
	createIndexid:1,		//z-index初始值
	windowMinWidth:150,		//窗口最小宽度
	windowMinHeight:56		//窗口最小高度
};

Core.init = function(update){
	var _top = Core.config.shortcutTop;
	var _left = Core.config.shortcutLeft;
	var windowHeight = $("#desk").height();
	$(window).bind('resize',function(){
		if($(window).width()<800 || $(window).height()<400){
		  LWORK.msgbox.show("The window size is too small to give a good display effect!", 1, 2000);
		}
		//由于图标不会太多，所以resize里的方法是对样式直接修改，当然也可以重建li
		$('#contactBox').find('.cb_con').height($(window).height() - 300) 	
		if(oScrollbar) oScrollbar.tinyscrollbar_update();
		_top = Core.config.shortcutTop;
		_left = Core.config.shortcutLeft;
		windowHeight = $("#desk").height();		
		//智能修改每个窗口的定位
		$("#desk div.window-container").each(function(){
			currentW = $(window).width() - $(this).width();
			currentH = $(window).height() - $(this).height();			
			_l = $(this).data("info").left/$(this).data("info").emptyW*currentW >= currentW ? currentW : $(this).data("info").left/$(this).data("info").emptyW*currentW;
			_l = _l <= 0 ? 0 : _l;
			_t = $(this).data("info").top/$(this).data("info").emptyH*currentH >= currentH ? currentH : $(this).data("info").top/$(this).data("info").emptyH*currentH;
			_t = _t <= 0 ? 0 : _t;
			$(this).animate({"left":_l+"px","top":_t+"px"},500);
		});
		
	}).bind('load',function(){
		$('.bgloader').fadeOut(1000);
	});
	
	//绑定窗口点击事件
	Core.container();
	//绑定窗口移动事件
	Core.bindWindowMove();
	//绑定任务栏点击事件	
	
//	$('.task-window').delegate('li','click',function(){Core.taskwindow($(this));}).delegate('li','contextmenu',function(){
		//展示自定义右键菜单
//		Core.taskwindowrightmenu($(this));
		//屏蔽浏览器自带右键菜单
//		return false;
//	});

};

Core.create = function(opt){
	var defaults = {
			 'width'	:450,
			 'height': 490,
			 'num'	:Date.parse(new Date()),
			 'id'    : opt.id, 
			 'photo' : 'images/comwin-icon.png' ,
			 'name'  : 'Unkown' ,
			 'status': 'Offline' ,
			 'Signature': 'No signature',
			 'content':'',
			 'resize': true,
			 'fixed': false,			 
			 'type':'p2p',
			 'service':'chat',
			 'onCloseCallback':function(){}	
    };			
	var options = $.extend(defaults, opt || {});		
	var window_warp = 'window_'+options.id+'_warp';
	var window_inner = 'window_'+options.id+'_inner';
	
	//判断窗口是否已打开
	var iswindowopen = 0;	
	$('.task-window li').each(function(){
		if($(this).attr('window')==options.id){
			iswindowopen = 1;
			//改变任务栏样式
			$('.task-window li b').removeClass('focus');
			$(this).children('b').addClass('focus');
			//改变窗口样式
			$('.window-container').removeClass('window-current');
			$('#'+window_warp).addClass('window-current').css({'z-index':Core.config.createIndexid}).show();
			//改变窗口遮罩层样式
			Core.config.createIndexid += 1;
		}
	});
	
	if(iswindowopen == 0){		
		//增加背景遮罩层		
		_cache.MoveLayOut = GetLayOutBox();								
	//	$('.window-frame').children('div').eq(0).show();			
		$('.task-window li b').removeClass('focus');
		$('.window-container').removeClass('window-current');	
		//任务栏，窗口等数据
		var winH = $(window).height(),
		 winW = $(window).width(),
		 top = (winH -options.height-100)/2 <= 0 ? 0 : (winH -options.height-100)/2,
		 left = (winW-options.width-500)/2   <= 0 ? 0 : (winW -options.width-500)/2 ,
		 maxLen = Math.floor((winH - (top + options.height))/50) + 2,
		 winLen =  parseInt($('.window-container').length),
		 len = (winLen <= maxLen ? winLen : Math.floor(winLen%maxLen));	
		 if(!options.fixed){	 
			 top = top + 50*len ;
			 left = left + 50*len;
		 }else{
			 top = ((winH -options.height)/2 <= 0 ? 0 : (winH -options.height)/2)-150;
			 left = (winW-options.width)/2   <= 0 ? 0 : (winW -options.width)/2 ;
	     }
		 
		_cache.taskTemp = {"id":options.id, "title":options.name, "photo":options.photo ,  "statuscss": (options.status == 'Online' || options.type == 'mp' || options.resize != true ? 'online' : 'offline')};	
     	_cache.windowTemp = {"width":options.width,"height":options.height,"top":top,"left":left,"emptyW":$(window).width()-options.width,"emptyH":$(window).height()-options.height,"zIndex":Core.config.createIndexid,"id":options.id,"name":options.name,"photo":options.photo ,"status":options.status, "statuscss": (options.status == 'Online' ? 'online' : 'offline') ,"Signature":options.Signature, type: options.type , service: options.service};		 
		_cache.resizeTemp = {"t":"left:0;top:-3px;width:100%;height:5px;z-index:1;cursor:n-resize","r":"right:-3px;top:0;width:5px;height:100%;z-index:1;cursor:e-resize","b":"left:0;bottom:-3px;width:100%;height:5px;z-index:1;cursor:s-resize","l":"left:-3px;top:0;width:5px;height:100%;z-index:1;cursor:w-resize","rt":"right:-3px;top:-3px;width:10px;height:10px;z-index:2;cursor:ne-resize","rb":"right:-3px;bottom:-3px;width:10px;height:10px;z-index:2;cursor:se-resize","lt":"left:-3px;top:-3px;width:10px;height:10px;z-index:2;cursor:nw-resize","lb":"left:-3px;bottom:-3px;width:10px;height:10px;z-index:2;cursor:sw-resize"};
		//新增任务栏
		$('.task-window').append(FormatModel(taskTemp,_cache.taskTemp));
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
		$('#desk').append(ele);
		setTimeout(function(){ $("#"+window_warp).addClass('stack'); }, 10);
		//绑定窗口上各个按钮事件	
		$("#"+window_warp).data("info",_cache.windowTemp);
		if(options.content && '' !=options.content){
			options.content.appendTo($("#"+window_warp).find('.comWin_box'))			
		}else{
		    Core.changeDisplayMode(options.id, options.type , options.service);
		}		
		Core.config.createIndexid += 1;
		//Core.bindWindowResize($('#'+window_warp));
		Core.handle(options.id, options.onCloseCallback);
	}
};


//显示桌面
Core.showDesktop = function(){
	$(".task-window li b").removeClass("focus");
	$("#desk").find(".window-container").hide();
};

//点击窗口
Core.container = function(){
	$(document).delegate('.window-container','click',function(){
		var obj = $(this);		
		var taskItem = $('#taskTemp_' + obj.attr('window'));
		//改变任务栏样式
		$('.task-window li b').removeClass('focus');
		taskItem.find('b').addClass('focus');
		//改变窗口样式
		$('.window-container').removeClass('window-current');
		obj.addClass('window-current').css({'z-index':Core.config.createIndexid});		
			var img =  taskItem.find('img');
			var span = taskItem.find('span');	
			if(img.data('src')){
			   img.attr('src', img.data('src'));		
			   span.text(span.data('text')).removeClass('newMsg');	
			}		
			//改变窗口遮罩层样式
			//$('.window-frame').children('div').eq(0).show();
			//obj.find('.window-frame').children('div').eq(0).hide();
			Core.config.createIndexid += 1;
	});
};

//最小化，最大化，还原，双击，关闭，刷新
Core.handle = function(winID, onCloseCallback){
    var target =  $('#window_'+winID+'_warp');	
	var updateStyle = function(obj){
		//改变窗口样式
		$('.window-container').removeClass('window-current');
		obj.addClass('window-current').css({'z-index':Core.config.createIndexid});
		Core.config.createIndexid += 1;
	};
	var updataConHeight = function(obj){
		obj.find('.chatWin_con').height(obj.height() -262 );
		if(obj.find('.ribbonBox').length>0 && obj.find('.ribbonBox').css('display') != 'none'){
		 obj.find('.chatWin_conbox').width( obj.width() - obj.find('.ribbonBox').width());				
		}
	}
	target.find('.cw_min').unbind('click').bind('click',function(e){
		var obj = $(this).parents(".window-container");
		updateStyle(obj);
		//最小化
		//阻止冒泡
		e.stopPropagation();
		obj.fadeOut();
		//改变任务栏样式
		$('#taskTemp_'+obj.attr('window')).find('b').removeClass('focus');
	})
	target.find('.cw_max').unbind('click').bind('click',function(){
		var obj = $(this).parents(".window-container");
		updateStyle(obj);
		//最大化
		obj.css({top:'20px',bottom:'20px', left:'10px', right:'290px', width: ($('#desk').width() - 300) + 'px', height:'auto'});
		updataConHeight(obj);
		$(this).hide().next(".cw_revert").show();
		//ie6iframeheight(obj);
		 LWORK.msgbox.show("Press F11 to enjoy the full screen mode", 4, 2000);
		 return false;
	})
	target.find('.cw_revert').unbind('click').bind('click', function(){	
		var obj = $(this).parents(".window-container");	
		updateStyle(obj);
		//还原
		obj.css({width:obj.data("info").width+"px",height:obj.data("info").height+"px",left:obj.data("info").left+"px",top:obj.data("info").top+"px"});
		updataConHeight(obj);
		$(this).hide().prev(".cw_max").show();
		return false;
	})	
	target.find('.header').unbind('dblclick').bind('dblclick', function(){
		var obj = $(this).parents(".window-container");
		var _this = $(this);
		updateStyle(obj);
		if(_this.find(".cw_max").css("display") !== 'none'){
			_this.find(".cw_max").click();
		}else{
			_this.find(".cw_revert").click();
		}
	})	
	target.find('.cw_close').unbind('click').bind('click', function(){
		  var obj = $(this).parents(".window-container");
			  updateStyle(obj);
			  $('#taskTemp_'+obj.attr('window')).remove();
			  obj.fadeOut("500", function(){
				  obj.html('').remove();	
				  onCloseCallback();
		      });		
	})	
	
    $('.taskmenu').unbind('click').bind('click',function(){
		var _this =$(this);
		var window_id = _this.attr("window");
		var win_box = $('#window_' + window_id + '_warp');
		var img = _this.find('img');
		var span = _this.find('span');	
		if(img.data('src')){
		   img.attr('src', img.data('src'));		
		   span.text(span.data('text')).removeClass('newMsg');	
		}	
		if(_this.find('b').hasClass('focus')){
			_this.removeClass('focus');
			win_box.find('.cw_min').click();
		}else{
			 _this.find('b').addClass('focus');
			 if(win_box.css('display') === 'none'){
			   win_box.fadeIn(300, function(){ win_box.find('.header').click(); });
			 }else{
			   win_box.find('.header').click();	 
			 }
		}
	});		
}

Core.confirm = function(text, callback){
	var html = ['<div class="winAlertContent">'+ text +'</div>',
               '<div class="selopt"> <a href="###" class="btn aui_state_highlight cofirmBtn">OK</a> <a href="###" class="btn cancelAddBtn">Cancel</a> </div>'].join('');
	var cancel = function(){ $('.maskFixed').fadeOut(400, function(){ $(this).remove(); }); }
    Core.create({ 'id': 'alertWin', 'name': 'Tips' , fixed:true, 'resize':false,  'content': $(html),  height: 133 ,  'onCloseCallback': cancel });
    var winBox = $('#window_alertWin_warp');
    $('<div class="maskFixed"></div>').css('z-index', parseInt(winBox.css('z-index'))-1).appendTo('body');	
	winBox.find('.cw_min').hide();

	winBox.find('.cancelAddBtn').bind('click',  function(){
	    winBox.find('.cw_close').click();	
	});

	winBox.find('.cofirmBtn').bind('click',  function(){
		 callback(winBox);
	     winBox.find('.cw_close').click();	
	});
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
			//鼠标贴屏幕左侧20px内
			if(e.clientX <= 20){
				_w = (lay.width()/2)+"px";
				_h = "100%";
				_l = 0;
				_t = 0;
			}
			//鼠标贴屏幕右侧20px内
			if(e.clientX >= (lay.width()-21)){
				_w = (lay.width()/2)+"px";
				_h = "100%";
				_l = (lay.width()/2)+"px";
				_t = 0;
			}
			//窗口贴屏幕顶部10px内
			if(_t <= 10){
				_t = 0;
			}
			//窗口贴屏幕底部60px内
			if(_t >= (lay.height()-60)){
				_t = (lay.height()-60)+"px";
				if(e.clientX <= 20){
					_w = (lay.width()/2)+"px";
					_h = "100%";
					_l = 0;
					_t = 0;
				}
			}
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

Core.changeDisplayMode = function(winID, type, service){
	var winBox =  $('#window_'+winID+'_warp');	
	var info = winBox.data('info');
	var oldService = winBox.data('info').service;
    if(winBox.find('.ribbonBox').css('display') !== 'none' && service == oldService ) return false;	
    winBox.data('info').service = service ;
	 var ribWidth =  winBox.find('.ribbonBox').width();	
	 var setmpWidth = function(width, ribWidth){	
		  var ribWidth , winWidth;
		  if(winBox.find('.ribbonBox').css('display') == 'none'){
			 ribWidth = width ;
			 winWidth = width;
		  }else{
			 ribWidth = ribWidth + width;	
			 winWidth  = width ;
		  }
		 info.width =  winBox.width()+ winWidth;		 
		 winBox.width(winBox.width()+winWidth);		 
		 winBox.data('info', info);					 
		 winBox.find('.chatWin_conbox').width( winBox.width() - ribWidth);	
		 winBox.find('.ribbonBox').show().width(ribWidth);
	}
	switch(type){
		case 'p2p':
		  	 if(service == 'chat'){
	             if(oldService == 'video') setmpWidth(-405, ribWidth);
				 if(oldService == 'audio') setmpWidth(-175, ribWidth);
				  winBox.find('.ribbonBox').hide();
			 }else if(service == 'video'){
				 if(oldService == 'chat') setmpWidth(405, ribWidth);
				 if(oldService == 'audio') setmpWidth(230, ribWidth);
				 winBox.find('.videomenu').show().siblings().hide();
				 winBox.find('.video').show().siblings().hide();
			 }else if(service == 'audio'){
			    if(oldService == 'chat') setmpWidth(175, ribWidth);
				if(oldService == 'video') setmpWidth(-230, ribWidth);
				 winBox.find('.audiomenu').show().siblings().hide();
				 winBox.find('.audio').show().siblings().hide();
			 }
		     break;
		case 'mp':
			 if(service == 'chat'){
				 if(oldService == 'chat') setmpWidth(175, ribWidth);
				 if(oldService == 'video') setmpWidth(-230 ,ribWidth);
				 winBox.find('.discusMem').show().siblings().hide();
				 winBox.find('.TabDiscusMem').show().siblings().hide(); 	
				 winBox.find('.Disabled_video').hide();			 
			 }else{	
			     if(oldService == 'chat') setmpWidth(230, ribWidth);
				 winBox.find('.discusMem').hide().siblings().show();
				 winBox.find('.TabDiscusMem').show().siblings().show(); 
				 winBox.find('.Disabled_video').show();			
		     }
		   break;
   }
}

Core.changeWindowTitle = function(sID, newTitle){
	var winBox =  $('#window_'+sID+'_warp');
	winBox.find('.chatObj_name').html(newTitle);
	winBox.find('.eiditDiscusGroupName').val('Edit name');
	$('#taskTemp_'+sID).find('.task_title').html(newTitle);
	return false;
}


Core.onNewMsg = function(sID){
	var taskItem =  $('#taskTemp_'+sID), 
	 img = taskItem.find('img'),
	 span = taskItem.find('span');
	 if(taskItem.find('b').hasClass('focus')) return false;	
	 if(!img.data('src')){
	   img.data('src' , img.attr('src') )
	   span.data('text', span.text())
	 }
	 img.attr('src','images/Buddy-Chat.gif');	
	 span.text( span.text() + '(New Message)').addClass('newMsg');	
	 
     return true;
};

Core.updatePeerInChatWindow = function(sID, UUID, Attr, Val){
	var winBox =  $('#window_'+sID+'_warp');
	var chat_obj = winBox.find('.chat_obj');
	var memberItem =  winBox.find('.friend_item_' + UUID);		
	      switch (Attr){
            case "presence":
				if (Val == 'offline'){
					memberItem.removeClass('online').addClass('offline');	
					memberItem.appendTo(memberItem.parent());						
					if(chat_obj.find('.status').length >0){
					  $('#taskTemp_' + sID).removeClass('online').addClass('offline');	
                	  chat_obj.removeClass('online').addClass('offline');
					  chat_obj.find('.status').text('Offline'); 
					}			
                }else{	
					 memberItem.removeClass('offline').addClass('online');
					 memberItem.prependTo(memberItem.parent());					  
					if(chat_obj.find('.status').length >0){
					   $('#taskTemp_' + sID).removeClass('offline').addClass('online');
                	   chat_obj.removeClass('offline').addClass('online');
					   chat_obj.find('.status').text('Online'); 
					}
                }
                break;				
            case "signature":	
			  if(chat_obj.find('.status').length >0)		
                chat_obj.find('.Signature').text(Val);
                break;
            case "nick_name":
			  if(chat_obj.find('.status').length >0)
                chat_obj.find('.chatObjText').text(Val);
			    memberItem.find('.friendname').text(Val);				
                break;
            case "photo":
			   if(chat_obj.find('.status').length >0)
                chat_obj.find('img').attr('src', Val);
		        memberItem.find('img').attr('src', Val);							
                break;
            default:
                break;
        }
}


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

