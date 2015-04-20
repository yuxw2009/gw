/* smartMenu.js 智能上下文菜单插件 */ 
(function ($) {
    var D = $(document).data("func", {});
    $.smartMenu = $.noop;
    $.fn.smartMenu = function (data, options) {
        var B = $("body"), defaults = {
            name: "",
            obj: "",
            offsetX: 2,
            offsetY: 2,
            textLimit: 6,
            beforeShow: $.noop,
            afterShow: $.noop
        };
        var params = $.extend(defaults, options || {});
        var htmlCreateMenu = function (datum) {
            var dataMenu = datum || data, nameMenu = datum ? Math.random().toString() : params.name, htmlMenu = "", htmlCorner = "", clKey = "smart_menu_";
            if ($.isArray(dataMenu) && dataMenu.length) {
                htmlMenu = '<div id="smartMenu_' + nameMenu + '" class="' + clKey + 'box">' +
								'<div class="' + clKey + 'body">' +
									'<ul class="' + clKey + 'ul">';
                $.each(dataMenu, function (i, arr) {
                    if ($.isArray(arr)) {
                        $.each(arr, function (j, obj) {
                            var text = obj.text, htmlMenuLi = "", strTitle = "", rand = Math.random().toString().replace(".", "");
                            if (text) {
                                if (text.length > params.textLimit) {
                                    text = text.slice(0, params.textLimit) + "…";
                                    strTitle = ' title="' + obj.text + '"';
                                }
                                if ($.isArray(obj.data) && obj.data.length) {
                                    htmlMenuLi = '<li class="' + clKey + 'li" data-hover="true">' + htmlCreateMenu(obj.data) +
										'<a href="javascript:" class="' + clKey + 'a"' + strTitle + ' data-key="' + rand + '"><i class="' + clKey + 'triangle"></i>' + text + '</a>' +
									'</li>';
                                } else {
                                    htmlMenuLi = '<li class="' + clKey + 'li">' +
										'<a href="javascript:" class="' + clKey + 'a' + i + '"' + strTitle + ' data-key="' + rand + '">' + text + '</a>' +
									'</li>';
                                }
                                htmlMenu += htmlMenuLi;
                                var objFunc = D.data("func");
                                objFunc[rand] = obj.func;
                                D.data("func", objFunc);
                            }
                        });
                    }
                });

                htmlMenu = htmlMenu + '</ul>' +
									'</div>' +
								'</div>';
            }
            return htmlMenu;
        }, funSmartMenu = function () {
            var idKey = "#smartMenu_", clKey = "smart_menu_", jqueryMenu = $(idKey + params.name);
            if (!jqueryMenu.size()) {
                $("body").append(htmlCreateMenu());
                //事件
                $(idKey + params.name + " a").bind("click", function () {
                    var key = $(this).attr("data-key"),
						callback = D.data("func")[key];
                    if ($.isFunction(callback)) {
                        callback.call(D.data("trigger"));
                    }
                    $.smartMenu.hide();
                    return false;
                });
                $(idKey + params.name + " li").each(function () {
                    var isHover = $(this).attr("data-hover"), clHover = clKey + "li_hover";
                    if (isHover) {
                        $(this).hover(function () {
                            $(this).addClass(clHover).children("." + clKey + "box").show();
                            $(this).children("." + clKey + "a").addClass(clKey + "a_hover");
                        }, function () {
                            $(this).removeClass(clHover).children("." + clKey + "box").hide();
                            $(this).children("." + clKey + "a").removeClass(clKey + "a_hover");
                        });
                    }
                });
                return $(idKey + params.name);
            }
            return jqueryMenu;
        };
        $(document).click(function () {
            $.smartMenu.remove();
        })
        $("#start_zone,#tab_zone,#widget_calendarnotepadcontent").unbind("mouseenter").bind("mouseenter", function () {
            $.smartMenu.remove();    
        })
        $(this).each(function () {
            //var title = params.obj.attr("title");
            this.oncontextmenu = function (e) {
                //回调
                if ($.isFunction(params.beforeShow)) {
                    params.beforeShow.call(this);
                }
                e = e || window.event;
                //阻止冒泡
                e.cancelBubble = true;
                if (e.stopPropagation) {
                    e.stopPropagation();
                }
                //隐藏当前上下文菜单，确保页面上一次只有一个上下文菜单
                $.smartMenu.hide();
                var st = D.scrollTop();
                var jqueryMenu = funSmartMenu();
                if (jqueryMenu) {

                  //  params.obj.attr("title", "");
                    jqueryMenu.css({
                        display: "block",
                        left: e.clientX + params.offsetX,
                        top: e.clientY + st + params.offsetY
                    });

                    D.data("target", jqueryMenu);
                    D.data("trigger", this);
                    //回调
                    if ($.isFunction(params.afterShow)) {
                        params.afterShow.call(this);
                    }
                    return false;
                }
            };
        });
        if (!B.data("bind")) {
            B.bind("click", $.smartMenu.hide).data("bind", true);
        }
    };
    $.extend($.smartMenu, {
        hide: function () {
            var target = D.data("target");
            if (target && target.css("display") === "block") {
                target.hide();
            }
        },
        remove: function () {
            var target = D.data("target");
            if (target) {
                target.remove();
            }
        }
    });
	
//人员搜索插件
$.fn.membersearch = function (options) {
    var defaults = {
		target:$('#task'),
		search_up_dwon:0,
		symbol:'@',
		isgroup:'yes',
		Words_detection:'yes',
		from:'',
		appendcontainer:''
    },
     params = $.extend(defaults, options || {}),
	 select_id ='',
     _this = $(this);
	 _this.bind('keyup', keyhandel);
     _this.css("color", params.defaultcolor);
   var createdom =function(name ,phone ,employuuid ,name_employid){
	  var html=""
      html = ['<li class="member_icon" name="' + name + '" phone="' + phone + '" uuid= "' + employuuid + '">' + name_employid + '</li>'].join("");
	  return html;
   };
   var seatipcontent = function(obj, value, index, str, start, target) {		
        var html = '',
		    reg = /[\u4E00-\u9FA5\uF900-\uFA2D]/,
		    flag = reg.test(str);
        params.target.find(".seatips").html('').hide();
        params.search_up_dwon = 0;
         var pos = $(obj).getCaretPosition();
		 if ('' !== str) {
            for (var i = 0; i < employer_status.length; i++) {				
                if (flag) {
                    if (employer_status[i].name_employid.indexOf(str) === 0)
					html += createdom( employer_status[i].name , employer_status[i].phone , employer_status[i].uuid ,employer_status[i].name_employid);
                } else {
                    if (employer_status[i].convertname.indexOf(str.toUpperCase()) === 0)
                	html += createdom( employer_status[i].name , employer_status[i].phone , employer_status[i].uuid ,employer_status[i].name_employid);
                }
            }
				if(params.isgroup == 'yes'){
				   for( var key in groupsArray ){
					   if (flag) {
							if (groupsArray[key].name.indexOf(str) === 0)
							 html += ['<li class="group_icon" name="' + groupsArray[key].name + '>' + groupsArray[key].name + '</li>'].join("");
						} else {
							if (groupsArray[key].convertname.indexOf(str.toUpperCase()) === 0)
							html += ['<li class="group_icon" name="' + groupsArray[key].name + '">' + groupsArray[key].name + '</li>'].join("");
						}
				   }
				} 
          if ('' !== html) {
                if (params.symbol === '@') {					
                    target.find(".seatips").eq(0).html(html).css({
                        left: obj.offsetLeft + pos.left,
                        top: obj.offsetTop + pos.top
                    }).show();
					
                } else {
                    target.find(".seatips").html(html).show();
                }
                clickhandle(obj, value, index, start, target);
            } else {
                target.find(".seatips").html('').hide();
                params.search_up_dwon = 0;
            }
        } else {
            target.find(".seatips").html('').hide();
            params.search_up_dwon = 0;
        }
    }
	
	function number_tip(target, value ,obj){
	if($.cookie('history_num')){
	  var hisrtory_tel = $.cookie('history_num').split('&');
	  var html=""
	  console.log(hisrtory_tel)
	  for(var i =0; i< hisrtory_tel.length ; i++){
		  if('' === hisrtory_tel[i]) continue;		  
		  if(hisrtory_tel[i].indexOf(value) === 0){
           html += ['<li class="member_icon">' + hisrtory_tel[i] + '</li>'].join("");
		  }
	   }
	       target.find(".seatips").html(html).show();	
		   this.search_up_dwon = 0;	   
		   target.find('.member_icon').unbind('click').bind('click', function(){			
			   $(obj).val($(this).text());
			   target.find(".seatips").html('').hide();
		  })
	  }
	}	
    ifNotInnerClick(['member_icon', 'seatips', 'peer_inputer', 'video_input','lwork_mes', 'inputTxt' , 'inputbox'], function(){ $('.seatips').hide();});
    function keyhandel(e) {
       var value = $(this).val(), start = 0, index, str ,
	       target = params.target;	 		   
		   params.search_up_dwon = 0;	
	   if (params.symbol !== '@') {
            start = value.length;         
            index = value.lastIndexOf(';');	
        } else {			
            start = loadContent.getselectionpos(this);		
            value = value.slice(0, start);           
            index = value.lastIndexOf('@');
			if(params.Words_detection === 'yes')
			confine({ 'oConBox': target.find('.lwork_mes'), 'oSendBtn': target.find('.sendBtn'), 'oMaxNum': target.find('.maxNum:first'), 'oCountTxt': target.find('.countTxt:first') });
			if(index<0) return false;
		}
        str = value.slice(index + 1);
        if (str.indexOf(' ') >= 0) {
            target.find(".seatips").html('').hide();
            params.search_up_dwon = 0;
            return false;
        }
        var s_len = target.find(".seatips li").length,
			keycode = e.which,
			e = e || window.event;
        switch (keycode) {
            case 40:
                if (s_len > 0) {
                    target.find(".seatips li").removeClass("current");
                    if (params.search_up_dwon > s_len - 1)
                        params.search_up_dwon = 0;
                    var tp = params.search_up_dwon;
                    target.find(".seatips li").eq(tp).addClass("current");
                    ++params.search_up_dwon;
                }
                break;
            case 38:
                if (s_len > 0) {
                    target.find(".seatips li").removeClass("current");
                    --params.search_up_dwon;
                    if (params.search_up_dwon < 0)
                        params.search_up_dwon = s_len - 1;
                        target.find(".seatips li").eq(params.search_up_dwon).addClass("current");
                }
                break;
            case 13:
                if (s_len > 0) {
                    target.find(".seatips li.current").click();
                }
                break;
            default:
                if (s_len > 0) {
                    target.find(".seatips li").removeClass("current").eq(0).addClass("current");
                }
				if(params.Words_detection === 'yes') {
					var patrn=/^[0-9]{1,20}$/; 
					if (patrn.exec(value)){
						number_tip(target, value, this);		  
					   return false;
					}
			     }				
			    seatipcontent(this, value, index, str, start, target);				
                break;
        }
    }
    function clickhandle(obj, value, index, start, target) {
        target.find('.seatips li').die('click').live('click', function () {
			var value = obj.value,
                val = $(this).text(),			          
                pre = value.substr(0, index + 1),
                post = value.substr(start),
                add_id = $(this).attr('uuid'),
                name = $(this).attr('name'), 
				phone =  $(this).attr('phone'),
                flag = true,
			    senduid;
                post = post.replace(/(^\s*)|(\s*$)/g, "");
            if (params.symbol === ';') {
			   if('' === params.appendcontainer){
				  if(pre.indexOf(val)<0){		  			
					$(obj).val( pre + val + ';');
				     senduid = $(obj).attr('sendid');				
	                '' === senduid? senduid = add_id :(senduid.indexOf(add_id)<0 ? senduid += ',' +add_id : senduid = senduid );
		     	    $(obj).attr('sendid', senduid);
				  }else{
					  $(obj).focus().val(pre);
				  }			
			  }else if(params.appendcontainer === 'no'){
					meetingController.addto_current_list(name, phone);		
					obj.value = '';							  
		      }else if(params.appendcontainer === 'datameeting'){
					datameetingController.addto_current_list(name, add_id);		
					obj.value = '';							  
		      }else{
					if (value.indexOf(val) >= 0) {	
						obj.focus();	
					} else {
						params.appendcontainer.find('li').each(function () {
							var temp_id = $(this).attr('uuid');												
							if (temp_id === add_id) {
								flag = false;
								return false;
							 }
						})
						if (flag) {
							var a = '<li uuid= "' + add_id + '"> ' + val + '  <a href="###" class="del_member">×</a></li>';
							params.appendcontainer.append(a);
							params.appendcontainer.find('li').hover(function () {
								$(this).find('.del_member').show();
							}, function () {
								$(this).find('.del_member').hide();
							})
							$('.del_member').click(function () {
								$(this).parent().remove();
							})
						   obj.value = '';
						}
					}
			   }
            } else if(params.symbol === ','){				
			    obj.value = val ;				
				$(obj).attr({'sendid': add_id ,'phone':phone});	
			} else if(params.from === 'msg'){
                if (phone.length > 0){
                    var newRcvr = phone + '[' + name + ']';		
					pre = pre.slice(0,pre.length-1);		
                    var addStr = (pre.length === 0 || pre[pre.length - 1] === ';') ? newRcvr : ';' + newRcvr;					
                    $(obj).focus().val(pre + addStr + post);
                }else{
                    LWORK.msgbox.show(name + " 没有登记电话号码!", 5, 2000);
                }
            }else {	
				$(obj).focus().val(pre + val + post + ' ');
            }
			    $(this).parent().html('').hide();
        })
    }
}

// 文本框插件			   
$.fn.searchInput = function (options) {
    var defaults = {
        color: "#343434",
        defaultcolor: "#999",
        defalutText: ""
    },
        params = $.extend(defaults, options || {}),
	    _this = $(this);
    _this.css("color", params.defaultcolor);
    _this.focus(function () {
	 if ("" === _this.val() || _this.val() === params.defalutText){		
        _this.val("");
        _this.css("color", params.color);
	  }
    }).blur(function () {
        if ("" == _this.val()) {
            _this.css("color", params.defaultcolor);
            _this.val(params.defalutText);
        }
    })
}

// 联系人筛选插件		   
$.fn.filter_addressbook = function (options) {
    var defaults = {container: $('#search_employer') },   params = $.extend(defaults, options || {}), _this = $(this);
	var reg = /[\u4E00-\u9FA5\uF900-\uFA2D]/; 
	 _this.bind('keyup', keyhandel);
   function keyhandel(e){	
		 var str = $(this).val();
		  var flag = reg.test(str);
		 var employer_temp = new Array();
		 if ('' !== str) {
			for (var i = 0; i < employer_status.length; i++) {				
				 if (flag) {
					  if (employer_status[i].name_employid.indexOf(str) === 0)
					    employer_temp.push(employer_status[i].uuid);
					} else {
					  if (employer_status[i].convertname.indexOf(str.toUpperCase()) === 0)
					   employer_temp.push(employer_status[i].uuid);
					}
			}
			employer_temp.length >0 ? loadContent.showemployer(employer_temp , params.container): params.container.html('<div style="text-align:center">通讯录中没有"'+ str+'"相关同事</div>');
	   }else{	
		 params.container.hide().siblings().fadeIn();
		 $('.contact_tab').find('.search_members').hide().siblings().fadeIn();
	   }   
  }
}


$.fn.autoTextarea = function(options) {
    var defaults={
        maxHeight:null,//文本框是否自动撑高，默认：null，不自动撑高；如果自动撑高必须输入数值，该值作为文本框自动撑高的最大高度
        minHeight:$(this).height() //默认最小高度，也就是文本框最初的高度，当内容高度小于这个高度的时候，文本以这个高度显示
    };
    var opts = $.extend({},defaults,options);
    return $(this).each(function() {
        $(this).bind("paste cut keydown keyup",function(){
            var height,style=this.style;
            this.style.height =  opts.minHeight + 'px';
            //console.log('scrollHeight='+this.scrollHeight+';clientHeight='+this.clientHeight+';minHeight='+opts.minHeight+';rows='+this.rows);
            if (this.scrollHeight > opts.minHeight) {
                if (opts.maxHeight && this.scrollHeight > opts.maxHeight) {
                    height = opts.maxHeight;
                    style.overflowY = 'scroll';
                } else {
                    height = this.scrollHeight + 16;
                    style.overflowY = 'hidden';
                }
                style.height = height  + 'px';
            }
        });
    });
};


//分类搜索建议插件
$.fn.searchSuggest = function (options) {
    var defaults = {
        target:$('#search_box'),
        defaultcolor: "#999",
        search_up_dwon:0
    },
     params = $.extend(defaults, options || {}),
     _this = $(this);
     _this.bind('keyup', keyhandle);
     _this.css("color", params.defaultcolor);
     
    var createdom =function(keyword){
        var html="";
        html = ['',
              '<li class="suggest_item" type="tasks" keyword="' + keyword + '">' + '搜索' + '<span class="search_keyword">' + keyword + '</span>相关的' + '<span class="search_type">'+ '工作协同</span>'+ '</li>',
              '<li class="suggest_item" type="topics" keyword="' + keyword + '">' + '搜索' + '<span class="search_keyword">' + keyword + '</span>相关的' + '<span class="search_type">'+ '企业微博</span>'+ '</li>',
              '<li class="suggest_item" type="documents" keyword="' + keyword + '">' + '搜索' + '<span class="search_keyword">' + keyword + '</span>相关的' + '<span class="search_type">'+ '网盘文件</span>'+ '</li>',
              '<li class="suggest_item" type="questions" keyword="' + keyword + '">' + '搜索' + '<span class="search_keyword">' + keyword + '</span>相关的' + '<span class="search_type">'+ '知识问答</span>'+ '</li>',
              '<li class="suggest_item" type="news" keyword="' + keyword + '">' + '搜索' + '<span class="search_keyword">' + keyword + '</span>相关的' + '<span class="search_type">'+ '新闻消息</span>'+ '</li>',
              '<li class="suggest_item" type="polls" keyword="' + keyword + '">' + '搜索' + '<span class="search_keyword">' + keyword + '</span>相关的' + '<span class="search_type">'+ '集体决策</span>'+ '</li>',
              ''].join("");
        return html;
    };
     
    var suggestsContent = function(obj, str) {
        var html = '';
        params.target.find(".suggests").html('').hide();
        params.search_up_dwon = 0;
        //var pos = $(obj).getCaretPosition();
        if ('' !== str) {
            html = createdom(str);                 
            params.target.find(".suggests").eq(0).html(html).show();

            clickhandle();
        }
    }
        
    function keyhandle(e) {
       var str = $(this).val(),
           target = params.target;
        /*
        if (str.indexOf(' ') >= 0){
            LWORK.msgbox.show("搜索关键字不能包含空格！", 3, 1000);
            str = str.slice(0, str.length - 1);  
        }*/          
        
        $(this).val(str);

        var s_len = target.find(".suggests li").length,
            keycode = e.which,
            e = e || window.event;
        switch (keycode) {
            case 40:
                target.find(".suggests li").removeClass("current");
                if (params.search_up_dwon > s_len - 1)
                    params.search_up_dwon = 0;
                var tp = params.search_up_dwon;
                target.find(".suggests li").eq(tp).addClass("current");
                ++params.search_up_dwon;
                break;
            case 38:
                target.find(".suggests li").removeClass("current");
                --params.search_up_dwon;
                if (params.search_up_dwon < 0)
                    params.search_up_dwon = s_len - 1;
                target.find(".suggests li").eq(params.search_up_dwon).addClass("current");
                break;
            case 13:
                target.find(".suggests li.current").click();
                break;
            default:
                suggestsContent(this, str);                
                target.find(".suggests li").removeClass("current").eq(0).addClass("current");                
                params.search_up_dwon = 0;              
                break;
        }
    }
    function clickhandle() {
        params.target.find('.suggests li').die('click').live('click', function () {
            var type = $(this).attr('type'),
                keyword = $(this).attr('keyword');
            loadContent.searchContent(type, keyword);
            params.target.find('#search_input').val('');
            $(this).parent().html('').hide();
        })
    }
}
})(jQuery);

window.LWORK=window.LWORK || {};
LWORK.dom = {getById: function(id) {
        return document.getElementById(id);
    },get: function(e) {
        return (typeof (e) == "string") ? document.getElementById(e) : e;
    },createElementIn: function(tagName, elem, insertFirst, attrs) {
        var _e = (elem = LWORK.dom.get(elem) || document.body).ownerDocument.createElement(tagName || "div"), k;
        if (typeof (attrs) == 'object') {
            for (k in attrs) {
                if (k == "class") {
                    _e.className = attrs[k];
                } else if (k == "style") {
                    _e.style.cssText = attrs[k];
                } else {
                    _e[k] = attrs[k];
                }
            }
        }
        insertFirst ? elem.insertBefore(_e, elem.firstChild) : elem.appendChild(_e);
        return _e;
    },getStyle: function(el, property) {
        el = LWORK.dom.get(el);
        if (!el || el.nodeType == 9) {
            return null;
        }
        var w3cMode = document.defaultView && document.defaultView.getComputedStyle, computed = !w3cMode ? null : document.defaultView.getComputedStyle(el, ''), value = "";
        switch (property) {
            case "float":
                property = w3cMode ? "cssFloat" : "styleFloat";
                break;
            case "opacity":
                if (!w3cMode) {
                    var val = 100;
                    try {
                        val = el.filters['DXImageTransform.Microsoft.Alpha'].opacity;
                    } catch (e) {
                        try {
                            val = el.filters('alpha').opacity;
                        } catch (e) {
                        }
                    }
                    return val / 100;
                } else {
                    return parseFloat((computed || el.style)[property]);
                }
                break;
            case "backgroundPositionX":
                if (w3cMode) {
                    property = "backgroundPosition";
                    return ((computed || el.style)[property]).split(" ")[0];
                }
                break;
            case "backgroundPositionY":
                if (w3cMode) {
                    property = "backgroundPosition";
                    return ((computed || el.style)[property]).split(" ")[1];
                }
                break;
        }
        if (w3cMode) {
            return (computed || el.style)[property];
        } else {
            return (el.currentStyle[property] || el.style[property]);
        }
    },setStyle: function(el, properties, value) {
        if (!(el = LWORK.dom.get(el)) || el.nodeType != 1) {
            return false;
        }
        var tmp, bRtn = true, w3cMode = (tmp = document.defaultView) && tmp.getComputedStyle, rexclude = /z-?index|font-?weight|opacity|zoom|line-?height/i;
        if (typeof (properties) == 'string') {
            tmp = properties;
            properties = {};
            properties[tmp] = value;
        }
        for (var prop in properties) {
            value = properties[prop];
            if (prop == 'float') {
                prop = w3cMode ? "cssFloat" : "styleFloat";
            } else if (prop == 'opacity') {
                if (!w3cMode) {
                    prop = 'filter';
                    value = value >= 1 ? '' : ('alpha(opacity=' + Math.round(value * 100) + ')');
                }
            } else if (prop == 'backgroundPositionX' || prop == 'backgroundPositionY') {
                tmp = prop.slice(-1) == 'X' ? 'Y' : 'X';
                if (w3cMode) {
                    var v = LWORK.dom.getStyle(el, "backgroundPosition" + tmp);
                    prop = 'backgroundPosition';
                    typeof (value) == 'number' && (value = value + 'px');
                    value = tmp == 'Y' ? (value + " " + (v || "top")) : ((v || 'left') + " " + value);
                }
            }
            if (typeof el.style[prop] != "undefined") {

                el.style[prop] = value + (typeof value === "number" && !rexclude.test(prop) ? 'px' : '');
                bRtn = bRtn && true;
            } else {
                bRtn = bRtn && false;
            }
        }
        return bRtn;
    },getScrollTop: function(doc) {
        var _doc = doc || document;
        return Math.max(_doc.documentElement.scrollTop, _doc.body.scrollTop);
    },getClientHeight: function(doc) {
        var _doc = doc || document;
        return _doc.compatMode == "CSS1Compat" ? _doc.documentElement.clientHeight : _doc.body.clientHeight;
    }
};

LWORK.string = {RegExps: {trim: /^\s+|\s+$/g,ltrim: /^\s+/,rtrim: /\s+$/,nl2br: /\n/g,s2nb: /[\x20]{2}/g,URIencode: /[\x09\x0A\x0D\x20\x21-\x29\x2B\x2C\x2F\x3A-\x3F\x5B-\x5E\x60\x7B-\x7E]/g,escHTML: {re_amp: /&/g,re_lt: /</g,re_gt: />/g,re_apos: /\x27/g,re_quot: /\x22/g},escString: {bsls: /\\/g,sls: /\//g,nl: /\n/g,rt: /\r/g,tab: /\t/g},restXHTML: {re_amp: /&amp;/g,re_lt: /&lt;/g,re_gt: /&gt;/g,re_apos: /&(?:apos|#0?39);/g,re_quot: /&quot;/g},write: /\{(\d{1,2})(?:\:([xodQqb]))?\}/g,isURL: /^(?:ht|f)tp(?:s)?\:\/\/(?:[\w\-\.]+)\.\w+/i,cut: /[\x00-\xFF]/,getRealLen: {r0: /[^\x00-\xFF]/g,r1: /[\x00-\xFF]/g},format: /\{([\d\w\.]+)\}/g},commonReplace: function(s, p, r) {
        return s.replace(p, r);
    },format: function(str) {
        var args = Array.prototype.slice.call(arguments), v;
        str = String(args.shift());
        if (args.length == 1 && typeof (args[0]) == 'object') {
            args = args[0];
        }
        LWORK.string.RegExps.format.lastIndex = 0;
        return str.replace(LWORK.string.RegExps.format, function(m, n) {
            v = LWORK.object.route(args, n);
            return v === undefined ? m : v;
        });
    }};


LWORK.object = {
	routeRE: /([\d\w_]+)/g,
	route: function(obj, path) {
        obj = obj || {};
        path = String(path);
        var r = LWORK.object.routeRE, m;
        r.lastIndex = 0;
        while ((m = r.exec(path)) !== null) {
            obj = obj[m[0]];
            if (obj === undefined || obj === null) {
                break;
            }
        }
        return obj;
    }};



var ua = LWORK.userAgent = {}, agent = navigator.userAgent;
ua.ie = 9 - ((agent.indexOf('Trident/5.0') > -1) ? 0 : 1) - (window.XDomainRequest ? 0 : 1) - (window.XMLHttpRequest ? 0 : 1);
if (typeof (LWORK.msgbox) == 'undefined') {
    LWORK.msgbox = {};
}
LWORK.msgbox._timer = null;
LWORK.msgbox.loadingAnimationPath = LWORK.msgbox.loadingAnimationPath || ("loading.gif");
LWORK.msgbox.show = function(msgHtml, type, timeout, opts) {
    if (typeof (opts) == 'number') {
        opts = {topPosition: opts};
    }
    opts = opts || {};
    var _s = LWORK.msgbox,
	 template = '<span class="zeng_msgbox_layer" style="display:none;z-index:10000;" id="mode_tips_v2"><span class="gtl_ico_{type}"></span>{loadIcon}{msgHtml}<span class="gtl_end"></span></span>', loading = '<img src="' + (opts.customIcon || _s.loadingAnimationPath) + '" alt="" />', typeClass = [0, 0, 0, 0, "succ", "fail", "clear"], mBox, tips;
    _s._loadCss && _s._loadCss(opts.cssPath);
    mBox = LWORK.dom.get("q_Msgbox") || LWORK.dom.createElementIn("div", document.body, false, {className: "zeng_msgbox_layer_wrap"});
    mBox.id = "q_Msgbox";
    mBox.style.display = "";
    mBox.innerHTML = LWORK.string.format(template, {type: typeClass[type] || "hits",msgHtml: msgHtml || "",loadIcon: type == 6 ? loading : ""});
    _s._setPosition(mBox, timeout, opts.topPosition);
};
LWORK.msgbox._setPosition = function(tips, timeout, topPosition) {
    timeout = timeout || 5000;
    var _s = LWORK.msgbox, bt = LWORK.dom.getScrollTop(), ch = LWORK.dom.getClientHeight(), t = Math.floor(ch / 2) - 40;
    LWORK.dom.setStyle(tips, "top", ((document.compatMode == "BackCompat" || LWORK.userAgent.ie < 7) ? bt : 0) + ((typeof (topPosition) == "number") ? topPosition : t) + "px");
    clearTimeout(_s._timer);
    tips.firstChild.style.display = "";
    timeout && (_s._timer = setTimeout(_s.hide, timeout));
};
LWORK.msgbox.hide = function(timeout) {
    var _s = LWORK.msgbox;
    if (timeout) {
        clearTimeout(_s._timer);
        _s._timer = setTimeout(_s._hide, timeout);
    } else {
        _s._hide();
    }
};
LWORK.msgbox._hide = function() {
    var _mBox = LWORK.dom.get("q_Msgbox"), _s = LWORK.msgbox;
    clearTimeout(_s._timer);
    if (_mBox) {
        var _tips = _mBox.firstChild;
        LWORK.dom.setStyle(_mBox, "display", "none");
    }
}; 


// 图片上传插件		   
$.fn.upload_file = function (options) {
    var defaults = { tips_css:'upload_img_tip',filetype:'image' , type: 'file' , contian_attachment : 'no' ,'start': 'image' },   params = $.extend(defaults, options || {});
	$(this).bind('click',handle);	
	var txt , css_btn,  up_cs ='' ,  up_cs1='' , display = 'none' , display1 = 'none';
	 params.filetype === 'image'? (up_cs = 'share_menu_on', display = 'block'): (up_cs1 = 'share_menu_on', display1 = 'block');
	function createDom(i,css){
      var  html2 = ''; a ='';
		if(params.contian_attachment === 'yes'){			
		   a = '<li class="totaskmenu '+ up_cs1 +'" link="up_attachment">上传附件</li>';
		   html2 = ['<div class="up_attachment" style="display:'+ display1 +'">',
						'<div class="uploadimages_loading"><img src = "/images/loading.gif" style="border:none;"/>文件正在上传...</div>',
						'<div class="del_uploadimages"></div>',
						'<div class="show_uploaedimages"></div>',						
						'<form  enctype="multipart/form-data" action ="/lw_upload.yaws?size_limit=10000000" method="post">',
						'<div class="file_share_form2">',
						'<div class="file-wrapper">',
						'<input type="file" name="upld" id="upload_attachment"/>',
						'<span class="uploadfile_btn"></span>',
						'<div style="padding-top: 10px;color: #cd6500;">可上传小于10M文件，大文件通过网盘分享</div>',
						'<input type="submit" value="submit_files" class="submit_imgaes"  style="display:none" />',
						'</div></div></form></div>'].join("")
		 }		
		return  html = ['<div class="'+ css +'">',
						'<div class="share_top clearfix">', 
						'<ul class="share_menu clearfix">',
						'<li class="totaskmenu '+ up_cs +' " link="up_iamges">上传图片</li>'+ a +'',
						'</ul></div>',		
						'<div class="tips_content">',
							'<div class="up_iamges" style="display:'+ display +'">',						  
							'<div class="uploadimages_loading"><img src = "/images/loading.gif" style="border:none;"/>文件正在上传...</div>',
							'<div class="del_uploadimages"></div>',
							'<div class="show_uploaedimages"></div>',								
							'<form  enctype="multipart/form-data" action ="/lw_pic_upload.yaws" method="post">',
							'<div class="file_share_form2">',
							'<div class="file-wrapper">',
							'<input type="file" name="upld" id="upload_images"/>',
							'<span class="uploadimages_btn"></span>',
							'<input type="submit" value="submit_files" class="submit_imgaes"  style="display:none" />',
							'</div></div></form></div>'+ html2 +'',									
	                        '</div></div>'			
				].join("");
	}
    function showtip(obj, html){
        var tipHtml=['<div class="uploadtip"><div class="close"><a href="###" class="del">×</a></div>',
                    '<div class="floatCorner_top" style=""><span class="corner corner_1">◆</span><span  class="corner corner_2">◆</span></div>',
                    '<div class="upltips">',
                    '' + html + '',
                    '</div></div>'].join("");
        var offset = obj.offset();
		var top, left;		       
		if(obj.parent().find('.uploadtip').length == 0){
			$('.uploadtip').html('');
			obj.after(tipHtml);
			$('.uploadtip').find('.floatCorner_top').removeClass('float_corner2 float_corner3 float_corner4').addClass("float_corner3  float_corner5");
			$('.uploadtip').fadeIn(400, function(){
			  if( params.start !== 'image')
				$('.uploadtip').find('.totaskmenu ').eq(1).click();
			 });      
			$('.uploadtip').find('.del').die('click').live('click', totips.hidetips);			
		 $('.uploadtip').find('.share_menu').find('li').click(function(){
			  $(this).addClass('share_menu_on').siblings().removeClass('share_menu_on');
			    var linkhref = $(this).attr('link');
				if(linkhref === 'up_iamges'){
				   $('.up_iamges').fadeIn();
				   $('.up_attachment').hide();	
				   $('.uploadtip').find('.float_corner5').animate({ right:235 }, 300);
				   params.filetype = 'image' ;				   
				}else{
				   $('.up_iamges').hide();							
				   $('.up_attachment').fadeIn();	
				   $('.uploadtip').find('.float_corner5').animate({ right:175 }, 300);
				    params.filetype = 'attachment' ;
				}
		  })
	  }
    }
    function handle(){
		var _this = $(this);
		var filetype ,filename;
		if( _this.parent().find('.upltips').length > 0 ){
			_this.hasClass('upload_image') ?  $('.totaskmenu').eq(0).click():  $('.totaskmenu').eq(1).click();
			return false;			
		}	
		var html = createDom(5, params.tips_css);
		showtip(_this, html);	
		var obj  = $('.upltips') ;
		obj.find('.del_uploadimages').click(function(){
			 $(this).hide();
			 obj.find('form').show();
			 obj.find('.show_uploaedimages').hide();
             $('.uploadtip').find('.close').show();
		})
        $('.uploadtip').find('.del').eq(0).click(function(){
             $('.uploadtip').remove();
        })
	   document.getElementById('upload_images').onchange = function(){
               changehandle(obj.find('.up_iamges'));
		}
	   obj.find('.up_iamges').find('form').ajaxForm({
		     complete: function(xhr) {
                ajaxform(xhr, obj.find('.up_iamges'));
			 }
		});
		if(params.contian_attachment === 'yes'){			
		   document.getElementById('upload_attachment').onchange = function(){
				   changehandle(obj.find('.up_attachment'));
		   }		
		   obj.find('.up_attachment').find('form').ajaxForm({
				 complete: function(xhr) {
					ajaxform(xhr, obj.find('.up_attachment'));
				 }
			});		
		}
		function changehandle(target){
				var $val = target.find('input[type=file]').val(),
				valArray = $val.split('\\');
				filename = valArray[valArray.length - 1];
		        filetype = loadContent.filetype_handle(filename);
		        filetype = filetype.replace(/(^\s*)|(\s*$)/g, "");					
				target.find('form').hide();
                target.find('.uploadimages_loading').show();
			 if(params.filetype === 'image'){
			    if(filetype !== 'jpg' && filetype !== 'png'&& filetype !== 'jpeg' && filetype !== 'gif'&& filetype !== 'bmp'){
				   LWORK.msgbox.show("请上传不超过1M图片文件！", 2, 1500); 
				   return false;
				 }
			}
			   target.find('.submit_imgaes').click();
		}
		function ajaxform(xhr, target){			
				 var data = JSON.parse(xhr['responseText']);
				 target.find('input[type=file]').val('');	
				if(data['status'] === 'failed'){					
					    LWORK.msgbox.show("文件传送失败！", 1, 1500);							
						target.find('.del_uploadimages').click();
						target.find('.uploadimages_loading').hide();					
					}else{	
					    var url = ( params.filetype === 'image' ? data['file_name'] : '/lw_download.yaws?fid='+ data['doc_id'] );										
						 target.find('.tips_top_content').text(txt + '预览');
						 target.find('.' + css_btn).hide();
						 target.find('.uploadimages_loading').hide();
						 target.find('.show_uploaedimages').show();	
						 target.find('.del_uploadimages').show();
						 $('.uploadtip').find('.close').hide();
					  if(filetype === 'jpg' || filetype === 'png'||filetype === 'jpeg' || filetype === 'gif' ||  filetype === 'bmp'){
						 target.find('.show_uploaedimages').html('<img src = "'+  url +'" style="border:none;"/>');
						 target.find('.show_uploaedimages img').LoadImage(true, 200,200,'/images/loading.gif');				 				 
					  }else{
						 target.find('.show_uploaedimages').text(filename);				  
					  }
					      upload_images['target'] = $('.tab_item').find('.curent').attr('link')
					  	if( params.filetype === 'image' ) {							
						   upload_images['upload_images_url'] = url;
						}else{
						   upload_images['attachment_name'] = filename;
						   upload_images['attachment_url'] = url;
						   upload_images['filesize'] = data['length'];				   
						   upload_images['createtime'] = data['create_time'];	
						}		
				   }			
		}
		   return false;
   }
}
//自动缩放图片插件
jQuery.fn.LoadImage=function(scaling,width,height,loadpic){
     if(loadpic==null)loadpic="/imges/loading.gif";
     return this.each(function(){
        var t=$(this);
        var src=$(this).attr("src")
        var img=new Image();
        img.src=src;
        //自动缩放图片
        var autoScaling=function(){
         if(scaling){
          if(img.width>0 && img.height>0){ 
                if(img.width/img.height>=width/height){ 
                    if(img.width>width){ 
                        t.width(width); 
                        t.height((img.height*width)/img.width); 
                    }else{ 
                        t.width(img.width); 
                        t.height(img.height); 
                    } 
                } 
                else{ 
                    if(img.height>height){ 
                        t.height(height); 
                        t.width((img.width*height)/img.height); 
                    }else{ 
                        t.width(img.width); 
                        t.height(img.height); 
                    } 
                } 
            } 
         } 
        }
        //处理ff下会自动读取缓存图片
        if(img.complete){
         autoScaling();
           return;
        }
        $(this).attr("src","");
		$('.img_loading').remove();
        var loading=$("<img class=\"img_loading\" alt=\"加载中...\" title=\"图片加载中...\" src=\""+loadpic+"\" />"); 		
	    t.hide();
        t.after(loading);
        $(img).load(function(){
             autoScaling();
             loading.remove();
             t.attr("src",this.src);
             t.show();			 
        });
   } );
 }
// 
//// 多图片幻灯片显示
//var ID = function(id){
//	return document.getElementById(id);
//};
//var cache = {};
//var fnPicShow = function(urlArr,curId){
//	var id = curId, l = urlArr.length;
//	//alert(id);
//	var prev, next;
//	if(id === 0){
//		prev = "";	
//	}else{
//		prev = id-1;	
//	}
//	if(id === l-1){
//		next = "";	
//	}else{
//		next = id+1;	
//	}
//	//滚动高度
//	var sTop = function() {   
//		var scrollPos = 0;   
//		var d = document.documentElement, b = document.body, w = window;
//		if (typeof w.pageYOffset !== "undefined") {   
//		 scrollPos = w.pageYOffset;   
//		}   
//		else if (typeof document.compatMode !== "undefined" && document.compatMode !== "BackCompat") {   
//		 scrollPos = d.scrollTop;   
//		}   
//		else if (typeof b !== "undefined") {   
//		 scrollPos = b.scrollTop;   
//		}   
//		return scrollPos; 
//	}();
//	//显示区域的高度和宽度
//	var cHeight = function(){
//		if(document.all){
//			return document.compatMode == "CSS1Compat"? document.documentElement.clientHeight : document.body.clientHeight;
//		}else{
//			return self.innerHeight;
//		}
//	}();
//	var cWidth = function(){
//		if(document.all){
//			return document.compatMode == "CSS1Compat"? document.documentElement.clientWidth : document.body.clientWidth;
//		}else{
//			return self.innerWidth;
//		}
//	}();
//	
//	var blankHeight = cHeight > document.body.scrollHeight? cHeight : document.body.scrollHeight;
//	
//	//创建空div
//	var boxdiv = document.createElement("div");
//	boxdiv.id = "appendBox";
//	if(!ID("appendBox")){
//		document.getElementsByTagName("body")[0].appendChild(boxdiv);
//	}else{
//		ID("appendBox").style.display = "block";
//	}
//	//图片预加载
//	ID("appendBox").innerHTML = '<div id="blank" style="width:100%; height:'+blankHeight+'px; background:black; position:absolute; left:0; top:0; opacity:0.4; filter:alpha(opacity=40); z-index:1999;"></div><div style="position:absolute; z-index:2100; padding:18px; background:white; left:'+((cWidth-100)/2 - 18)+'px; top:'+(sTop + (cHeight-100)/2 - 18)+'px;" id="appendPicBox"><div style="line-height:20px; padding:40px 0; text-align:center;">图片加载中……</div></div>';
//	
//	var preloader = new Image();
//	preloader.src = urlArr[id];
//	//图片的高宽
//	var w = preloader.width, h = preloader.height;
//	if(!w){
//		preloader.onload = function() {
//			//获取图片的宽度
//			w = preloader.width;
//			h = preloader.height;
//			cache["cache_"+id] = true;
//			callback();
//		};
//	}
//	var callback = function(){
//		var scale = w/h;
//		if(w > cWidth){
//			w = cWidth - 40;
//			h = w/scale;
//		}
//		if(h > cHeight){
//			h = cHeight - 40;
//			w = h * scale;
//		}
//		ID("appendBox").innerHTML = ['<div id="blank" style="width:100%; height:'+blankHeight+'px; background:black; position:absolute; left:0; top:0; opacity:0.4; filter:alpha(opacity=40); z-index:1999;"></div>',
//		'<div style="position:absolute; z-index:2000; padding:18px; background:white;min-width:300px; height:200px; vertical-align:middle; display:table; text-align:center;" id="appendPicBox">',
//		'<img id="theShowPic" src="'+urlArr[id]+'" />',
//		'<span id="closePicBtn" style="position:absolute; right:-3px; top:-2px; z-index:2000; cursor:pointer; font-size:12px; background:black; color:white; opacity:0.8; padding:1px 2px;-moz-border-radius:2px;-webkit-border-radius:2px;border-radius:2px;">关闭</span>',
//		'<a title="查看上一张图片" id="picPrev" hidefocus="true" href="javascript:void(0);" rel="'+prev+'" style="width:50%; height:100%; background:url(xx.jpg); left:0; top:0; position:absolute; outline:0;"></a>',
//		'<a title="查看下一张图片" id="picNext" href="javascript:void(0);" rel="'+next+'" hidefocus="true" style="width:50%; height:100%; background:url(xx.jpg); right:0; top:0; position:absolute; outline:0;"></a>',
//		
//		'<div id="picPrevRemind" style="position:absolute; width:56px; left:18px; top:-8000px;"><div style="border-bottom:3px solid; border-top-color:#fff; border-bottom-color:#fff; border-right:3px dotted transparent; border-left:none;"></div>',
//		'<div style="padding-left:5px; background:white; line-height:24px; font-size:14px; color:#666666;">上一张</div>',
//		'<div style="border-top:3px solid; border-top-color:#fff; border-bottom-color:#fff; border-right:3px dotted transparent; border-left:none;"></div>',
//		'</div>',
//		'<div id="picNextRemind" style="position:absolute; width:56px; right:18px; top:-8000px;">',
//		'<div style="border-bottom:3px solid; border-top-color:#fff; border-bottom-color:#fff; border-left:3px dotted transparent; border-right:none;"></div>',
//		'<div style="padding-right:5px; text-align:right; background:white; line-height:24px; font-size:14px; color:#666666;">下一张</div>',
//		'<div style="border-top:3px solid; border-top-color:#fff; border-bottom-color:#fff; border-left:3px dotted transparent; border-right:none;"></div>',
//		'</div>',
//		'</div>'].join('');	
//		$('#theShowPic').LoadImage(true, 600,600,'/images/loading.gif');
//		//给左右切换区域定宽
//		ID("picPrev").style.height = ID("picNext").style.height = h + 18 + "px";
//		ID("picPrev").style.width = ID("picNext").style.width = w/2 + 18 + "px";
//		//居中定位
//		var t = sTop + (cHeight-h)/2 - 18, l = (cWidth-w)/2 - 18;
//           alert($("#appendBox").width())
//		   
//		ID("appendPicBox").style.left = l + "px";
//		ID("appendPicBox").style.top = t + "px";
//		
//		//显示左右箭头
//		ID("picPrev").onmouseover = function(){
//			if(this.rel){
//				ID(this.id + "Remind").style.top = h/3 + "px";	
//				this.title = "查看上一张图片";
//			}else{
//				this.title = "这是第一张图片";
//			}
//		};
//		ID("picNext").onmouseover = function(){
//			if(this.rel){
//				ID(this.id + "Remind").style.top = h/3 + "px";	
//				this.title = "查看下一张图片";	
//			}else{
//				this.title = "这是最后一张图片";	
//			}
//		};
//		ID("picPrev").onmouseout = function(){
//			ID(this.id + "Remind").style.top = "-8000px";	
//		};
//		ID("picNext").onmouseout = function(){
//			ID(this.id + "Remind").style.top = "-8000px";	
//		};
//		ID("picPrev").onclick = function(){
//			var rel = this.rel;
//			if(rel !== ""){
//				rel = parseInt(rel);
//				fnPicShow(urlArr,rel);	
//			}
//			return false;
//		};
//		ID("picNext").onclick = function(){
//			var rel = parseInt(this.rel);
//			if(rel){
//				fnPicShow(urlArr,rel);	
//			}
//			return false;
//		};
//		//关闭
//		ID("blank").onclick = function(){
//			ID("appendBox").style.display = "none";
//		};
//		ID("closePicBtn").onclick = function(){
//			ID("appendBox").style.display = "none";
//		};
//	}
//	if(cache["cache_"+id] || w){
//		callback();
//	}
//};
//
