/* smartMenu.js 智能上下文菜单插件 */ 

   // String.prototype.replaceAll = function(s1,s2){  
  //           return this.replace(new RegExp(s1,"gm"),s2);    
  //  }

(function ($) {
    var D = $(document).data("func", {});
    $.smartMenu = $.noop;
    $.fn.smartMenu = function (data, options) {
        var B = $("body"), defaults = {
            name: "",
            obj: "",
            offsetX: 2,
            offsetY: 2,
            textLimit: 20,
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
  		symbol:'',
  		isgroup:'yes',
  		bind_confine:'no',
      showNumberTip:'no',
  		from:''
    }, 
      params = $.extend(defaults, options || {}),
    	select_id ='',
      _this = $(this),
      sea_cha = '',
      range, range2, node_index;
    	_this.unbind('keyup').bind('keyup', keyhandel);
      _this.css("color", params.defaultcolor);
      var createdom =function(name ,phone ,employuuid ,name_employid, photo, mail){
	        var html="" , a = '' ;
          if(phone || phone !== '') a = '<span class="member_phone"> ('+ phone +')</span>'; 
          if(mail || mail !== '') a = '<span class="member_mail"> ('+ mail +')</span>'; 
          html = ['<li class="member_icon" name="' + name + '" mail ="'+ mail +'" phone="' + phone + '" uuid= "' + employuuid + '">',
                  '<img src="'+ photo +'" width="30" height="30">',
                  '<span class="member_name">'+ name_employid +'</span>' + a,
                  '</li>'].join("");
	        return html;
      };
   var getselectionpos = function (textBox) {        
        var start = 0, 
            data = '', 
            str = '',
            rng,
            lastIndex,
            srng;
        if (window.getSelection) {
            sel = window.getSelection();
            if (sel.getRangeAt && sel.rangeCount) {
               range = sel.getRangeAt(0);
            }
            data = range['commonAncestorContainer']['data'];
            data = data.slice(0, range['startOffset']);
            lastIndex = data.lastIndexOf('@');
            if(lastIndex >= 0) str = data.slice(lastIndex+1);
        } else if (document.selection){
            rng = document.body.createTextRange();
            rng.moveToElementText(textBox);
            range2 = document.selection.createRange();
            range2.setEndPoint("StartToStart", rng);
            data = range2.htmlText;
            lastIndex = data.lastIndexOf('@');            
            if(lastIndex >= 0){
              data = data.slice(lastIndex);      
              if(data.indexOf('</BUTTON>') >=0 || data.indexOf('</button>')>=0) {      
                str = '';
              }else{
                str = data.indexOf('<') > 0 ? data.slice(1,data.lastIndexOf('<')) : data.slice(1); 
              }
            }else{
              str ='';
            }
        }
        return str;
    }
function insertAfter(newEl, targetEl){
    var parentEl = targetEl.parentNode;    
    if(parentEl.lastChild == targetEl){
       parentEl.appendChild(newEl);
    }else{
       parentEl.insertBefore(newEl,targetEl.nextSibling);
    }            
}
function isOrContainsNode(ancestor, descendant) {
    var node = descendant;
    node_index = 0;
    while (node) {
        if (node === ancestor) {
            return true;
        }
        node = node.parentNode;
        node_index++;
    }
    return false;
}
function appendHtmlToDiv(textBox, node, str, id) {
    var sel,  html, text;
    var containerNode = document.getElementById($(textBox).attr('id'));
    if (window.getSelection) {
        sel = window.getSelection();
        var space = document.createTextNode("\u00a0");
        if (sel.getRangeAt && sel.rangeCount) {
            if (isOrContainsNode(containerNode, range.commonAncestorContainer)) {
                range.insertNode(node);
            } else {    
                containerNode.appendChild(node); 
            }
            insertAfter(space ,node);
            text = $(range.commonAncestorContainer).html();
            if(text == '@' + str){
               $(range.commonAncestorContainer).remove();
            }else{       
               text = text.replace('@'+str + '<button', '<button');
               $(range.commonAncestorContainer).html(text); 
            }      
        }
        containerNode.blur();
        range.setStartAfter(document.getElementById(id));
        range.setEndAfter(document.getElementById(id));
        getSelection().addRange(range);
        containerNode.focus();
    } else if (document.selection && document.selection.createRange) {        
           range3 = document.selection.createRange();
        if (isOrContainsNode(containerNode, range3.parentElement())) {
            html = (node.nodeType == 3) ? node.data + '&nbsp;' : node.outerHTML + '&nbsp;';
           range3.pasteHTML(html);
        } else {
            containerNode.appendChild(node);
            containerNode.innerHTML += '&nbsp;';
        }
        containerNode.innerHTML = containerNode.innerHTML.replace('@'+str , '');
    }
}
   var seatipcontent = function(obj, value, str, target) {
       var html = '', reg = /[\u4E00-\u9FA5\uF900-\uFA2D]/, flag = reg.test(str), mail = '', h1;
       if(params.from === 'weibo'){
          $(obj).find('.seatips').remove();
          $(obj).append('<div class="seatips" contenteditable="false" style="display:none;"></div>');
       }else{
          params.target.find(".seatips").html('').hide();          
       }
       params.search_up_dwon = 0;
		   if(params.symbol === ';' && str.indexOf('@') == 0) str = str.slice(1);
     	 if ('' !== str) {
          for (var i = 0; i < employer_status.length; i++) {	
          	  mail = (params.from === 'sendMail' ? employer_status[i].mail :'')
              phone = (params.from === 'sendMail' ? '' : employer_status[i].phone.mobile)
              if (flag) {
                if (employer_status[i].name_employid.indexOf(str) === 0)
					      html += createdom(employer_status[i].name ,phone , employer_status[i].uuid ,employer_status[i].name_employid , employer_status[i].photo, mail);
              } else {
                if (employer_status[i].convertname.indexOf(str.toUpperCase()) === 0)
              	html += createdom(employer_status[i].name , phone , employer_status[i].uuid ,employer_status[i].name_employid, employer_status[i].photo, mail);
              }
        }
				if(params.isgroup == 'yes'){
				   for( var key in groupsArray ){
					   if (flag) {
						  if (groupsArray[key].name.indexOf(str) === 0)
               html += createdom( groupsArray[key].name , '' , '', groupsArray[key].name, '/images/gruop_img.png');
						} else {
						  if (groupsArray[key].convertname.indexOf(str.toUpperCase()) === 0)
               html += createdom( groupsArray[key].name , '' , '', groupsArray[key].name, '/images/gruop_img.png');
						}
				   }
				} 
          if ('' !== html) {
                if (params.symbol === '@') {					
                   target.find(".seatips").eq(0).html(html)
                   if(params.from === 'weibo'){
                    h1 = parseInt(target.find(".seatips").eq(0).height(), 10)+1;
                    target.find(".seatips").eq(0).css('bottom', -h1);
                   }
                   target.find(".seatips").eq(0).show();					
                } else {
                   target.find(".seatips").eq(0).html(html).show();
                }
                clickhandle(obj, str, target);
            } else {
                target.find(".seatips").html('').hide();
                params.search_up_dwon = 0;
            }
        } else {
            target.find(".seatips").html('').hide();
            params.search_up_dwon = 0;
        }
    }
    function clickhandle(obj, str, target) {
        target.find('.seatips li').unbind('click').bind('click', function () {
            var _this = $(this),
                value = $(obj).html(),
                val = _this.find('.member_name').text(),
                add_id = _this.attr('uuid'),
                name = _this.attr('name'), 
                phone =  _this.attr('phone'),
                mail =  _this.attr('mail'),
                senduid;
                _this.parent().html('').hide();
                switch(params.from){
                   case 'weibo':  
                      var newDiv = document.createElement("button");
                      var id = 'select'+ parseInt(Math.random()*10E20);
                      $(newDiv).addClass('tag').attr({'contenteditable':'false','id':id, onclick:'return false;'}).text('@'+ val); 
                      appendHtmlToDiv(obj, newDiv, str, id);
                      break;
                   case 'meeting':
                      var ok   = function(phone){meetingController.addto_current_list(name, phone);};
                      var fail = function(){LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_INVALID+"!", 5, 2000);};
                      userPhoneManage.userSelectPhone(add_id, [] ,ok,fail);
                     // meetingController.addto_current_list(name, phone);        
                      obj.value = '';
                      break;
                   case 'voip':
                   //   if (phone.length == 0){
                    //      LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_INVALID+"!", 5, 2000);
                   //  }else{


                   //       obj.value = phone;                     
                   //       $(obj).attr({'sendid': add_id ,'phone':phone,'name': name});
                    //  }
                var ok   = function(phone){$(obj).val(phone).attr({'phone': phone,'name': name});};
                var fail = function(){LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_INVALID+"!", 5, 2000);};
                userPhoneManage.userSelectPhone(add_id,["extension"],ok,fail);


                      break;
                   case 'shortmsg':
                      phone.length > 0 ? $(obj).val(phone + '[' + name + ']').blur() : (parent.LWORK.msgbox.show(name + " 没有登记电话号码!", 5, 2000), $(obj).val(''));
                      break;
                   case 'sendMail':
                      mail.length > 0 ? $(obj).val(mail + '[' + name + ']').blur() : (parent.LWORK.msgbox.show(name + " 没有登记邮箱地址!", 5, 2000), $(obj).val(''));
                      break;                      
                   case 'addmembertogroup':
                   case 'invite':
                      $(obj).val(add_id + '[' + name+ ']').blur();
                      break;
                   default:
                      break;
                }
        })
    }
	function number_tip(target, value ,obj){
		if($.cookie('history_num')){
		  var hisrtory_tel = $.cookie('history_num').split('&');
		  var html=""
		  for(var i =0; i< hisrtory_tel.length ; i++){
			  if('' === hisrtory_tel[i]) continue;		         
			  if(hisrtory_tel[i].indexOf(value) === 0){
			   html += ['<li class="member_icon"><img src="/images/photo/hybrid.bmp" width="30" height="30">' + hisrtory_tel[i] + '</span>'].join("");
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
  ifNotInnerClick(['member_icon', 'seatips', 'peer_inputer', 'video_input','lwork_mes', 'inputTxt' , 'inputbox'], function(){ 
    $('.seatips').hide();
  });	

    if(navigator.userAgent.indexOf("MSIE")>0) { 
       document.onkeydown=function(){
         if(13 == event.keyCode || 40 == event.keyCode || 38 == event.keyCode ){
           if(_this.find('.seatips').css('display') == 'block'){     
             return false;
           }
    　　 }    
    　} 
    }else{ 
      window.onkeydown=function(){
         if(13 == event.keyCode || 40 == event.keyCode || 38 == event.keyCode ){
          if(_this.find('.seatips').css('display') == 'block'){
           return false;
          }
    　  }
      } 
    }
    function keyhandel(e) {
       var value , start = 0, index, str,
	       target = params.target,
         s_len = target.find(".seatips li").length,
         e = e || window.event,
         keycode = e.which;
       switch (keycode) {
            case 40:
              // e.preventDefault();
               if (s_len > 0) {
                  var tp = params.search_up_dwon;
                  target.find(".seatips li").removeClass("current");
                  if (params.search_up_dwon > s_len - 1)
                      params.search_up_dwon = 0;     
                  target.find(".seatips li").eq(tp).addClass("current");
                  params.search_up_dwon = tp + 1;
               }             
                break;
            case 38:
                //e.preventDefault(); 
                var tp = params.search_up_dwon;
                if (s_len > 0) {
                   target.find(".seatips li").removeClass("current");
                   if (params.search_up_dwon < 0)
                       params.search_up_dwon = s_len - 1;            
                       target.find(".seatips li").eq(tp).addClass("current");
                       params.search_up_dwon = tp - 1;
                }                
                break;
            case 13:
                e.preventDefault(); 
                if (s_len > 0) {
                    target.find(".seatips li.current").click();
                }
                break;      
            default:
                if (params.symbol !== '@') {
                   str = value = $(this).val();
                   start = value.length;
                   index = value.lastIndexOf(';');
                }else {
                   value = $(this).html();
                   str = getselectionpos(this);
                   if(params.bind_confine === 'yes');{
                       confine(target.attr('id') ==='tasks' ? 1000 : 300,{
                          'oConBox':$(this),
                          'oSendBtn': target.find('.sendBtn'),
                          'oMaxNum': target.find('.maxNum:first'),
                          'oCountTxt': target.find('.countTxt:first'),
                          'editdiv':true
                       });
                   }
               }               
                if (str.indexOf(' ') >= 0 || str === '') {
                    target.find(".seatips").html('').hide();
                    params.search_up_dwon = 0;
                    return false;
                }
				if(params.showNumberTip === 'yes') {
					var patrn=/^[0-9]{1,20}$/; 
					if (patrn.exec(value)){
						number_tip(target, value, this);		  
					   return false;
					}
			  }
			    seatipcontent(this, value, str, target);				
          break;
        }
    }
}
// 文本框插件
$.fn.searchInput = function (options) {
    var defaults = {
        color: "#343434",
        defaultcolor: "#666666",
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

$(".lwork_mes").on($.browser.msie?"beforepaste":"paste",function(e){
       var _this = $(this); 
       $("#pasteTextarea").focus();       
       setTimeout(function(){ 
          _this.html(_this.html() + '<pre>' + $("#pasteTextarea").val().replaceAll('<', '< ')+ '</pre>');  
          _this.focus();  
         $("#pasteTextarea").val('');
       },0); 
});

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
              '<li class="suggest_item" type="tasks" keyword="' + keyword + '">' + lw_lang.ID_SEARCH_FOR + '<span class="search_keyword">' + keyword + '</span>' + lw_lang.ID_SEARCH_ABOUT +'<span class="search_type">'+ lw_lang.ID_CO_WORK + '</span>'+ '</li>',
              '<li class="suggest_item" type="topics" keyword="' + keyword + '">' +  lw_lang.ID_SEARCH_FOR + '<span class="search_keyword">' + keyword + '</span>' + lw_lang.ID_SEARCH_ABOUT +'<span class="search_type">'+ lw_lang.ID_WEIBO +'</span>'+ '</li>',
              '<li class="suggest_item" type="documents" keyword="' + keyword + '">' + lw_lang.ID_SEARCH_FOR + '<span class="search_keyword">' + keyword + '</span>' + lw_lang.ID_SEARCH_ABOUT +'<span class="search_type">'+ lw_lang.ID_FILE + '</span>'+ '</li>',
              '<li class="suggest_item" type="questions" keyword="' + keyword + '">' + lw_lang.ID_SEARCH_FOR + '<span class="search_keyword">' + keyword + '</span>' + lw_lang.ID_SEARCH_ABOUT +'<span class="search_type">'+ lw_lang.ID_QA + '</span>'+ '</li>',
              '<li class="suggest_item" type="polls" keyword="' + keyword + '">' + lw_lang.ID_SEARCH_FOR + '<span class="search_keyword">' + keyword + '</span>' + lw_lang.ID_SEARCH_ABOUT + '<span class="search_type">'+ lw_lang.ID_BALLOT +'</span>'+ '</li>',
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
       var _this = $(this);
           str = _this.val(),
           target = params.target;
           _this.val(str);
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

  /*上传*/
  function FormSubmit(index, dlBox, formBox, type, val, filetype){
    var List = dlBox.find('dl').eq(index);
    var FormL = formBox.find('form').eq(index);
    FormL.ajaxForm({    
       beforeSend: function() {
        List.removeClass('queue').addClass('uping');
        List.find('.Dsa').text('准备上传...');
        List.find('.Dopt').text('').unbind('click').bind('click', function(){
             return false;
        })
       },
       uploadProgress: function(event, position, total, percentComplete){
          var percentVal = percentComplete + '%';
              List.find('.Dsa').text(percentVal);
              List.find('.inline_mask').show().width(percentVal);
              List.find('.Dopt').addClass('delete').text('').unbind('click').bind('click', function(){
                FormL.clearForm();
                FormL.remove();
                $(this).parent().parent().remove();   
                DiskUpSub(dlBox, formBox, type, val, filetype);         
             });              
          if(percentComplete == 100){
             List.find('.inline_mask').hide();
             List.find('.Dsa').text('处理中..');
             List.removeClass('uping').addClass('dealing');
             DiskUpSub(dlBox, formBox, type, val, filetype);
          }
       },
       complete: function(xhr) {
         var data = xhr['responseText'] && JSON.parse(xhr['responseText']);
          List.find('.Dopt').addClass('delete').text('').unbind('click').bind('click', function(){
                 $(this).parent().parent().remove();
                 FormL.remove();
          }); 
         List.removeClass('uping').removeClass('dealing');
         if(!dlBox.find('.uping').length && !dlBox.find('.dealing').length){
            removePageTips(dlBox.parent());
         }
         if(!data || data['status'] === 'failed'){           
             List.addClass('failed');
             DiskUpSub(dlBox, formBox, type, val, filetype); 
             List.find('.Dsa').text('上传失败');
             List.find('.reupload').show().text('重新上传').unbind('click').bind('click', function(){
                  $(this).fadeOut();
                  List.removeClass('failed').addClass('queue');
                  FormL.find('.submit_sharefile').submit();
             });
             if(!data) List.find('.reupload').hide();
         }else{
           List.addClass('success'); 
           List.parents().find('.sendBtn').eq(0).removeClass('disabledBtn');
           List.find('.Dsa').text('上传成功');
           upHandle(data, type, List, val, FormL, filetype)
         }

      },
      error: function(xhr) {
        console.log('ajaxForm xhr:',xhr);
      }
    });
  }
  function upHandle(data, type, List, val, FormL, filetype){
    var attr;
    switch(type){
      case 'documents':
          var opt = {uuid:uuid, file_name:data['name'], file_id:(data['doc_id']).toString(), file_size:data['length'].toString(), content:'', members:[], 't':new Date().getTime()}; 
          loadContent.publish('documents', opt, $('#file_share_container'));
          setTimeout(function(){
            List.slideUp(400,function(){ $(this).remove(); });
            FormL.remove();
          },10000)
          break;
      case 'email':  
          List.attr('data',data['url']);
          break;
      default:    
          type == 'images' ? attr = data['file_name']:(filetype=='jpg'? attr= data['file_name']:attr ='/lw_download.yaws?fid='+data['doc_id']+'&&'+getFileName(val) + '&&' + data['length'] + '&&' + data['create_time']);
          List.attr('data',attr);
          break;
    }
  }
  function pageTips(target, text){
      target.find('.pageTips').remove();
      target.append('<span class="pageTips">'+ text +'</span>'); 
  }
  function removePageTips(target){
      target.find('.pageTips').remove();    
  }
  function sharefiles_handle(obj, type){
    var val = $(obj).val(),
     filename = getFileName(val),
     filetype = getFileType(filename);
     if(filetype == 'jpg'|| filetype == 'png' || filetype == 'jpeg' || filetype == 'gif'|| filetype == 'bmp'){ 
       filetype = 'jpg' ;
     if(type !== 'documents')
       $(obj).parent().attr('action', '/lw_pic_upload.yaws');
     }
    if(type === 'email'){
       $(obj).parent().attr('action', "/mail_upload.yaws");
    }
     if(type === 'images'){
        if(filetype !== 'jpg'){
           pageTips($(obj).parent(), '请上传图片文件！');
           return false;
       }
     }
    removePageTips($(obj).parent());
    var dl = FileListDom(filename, filetype ),
     Dbox = (type == 'documents' ? $('#WebDiskBox') : $(obj).parent().parent().parent()),
     List = Dbox.find('.fileList'),
     z_index = parseInt($(obj).css('z-index')),
     parObj = $(obj).parent(), flag = 1, 
     formBox =  $(obj).parent().parent();
     formBox.find('form').each(function(i){
        if(val == $(this).attr('filepath')){
          pageTips($(obj).parent(), '您选择的文件已包含在列表中！');
          flag = 0; 
          return;
         }
     }) 
     if(flag === 0) return false;
     List.append(dl);
     Dbox.show().find('.fileList').show();
     Dbox.find('.Bm').show().prev().hide();
     List.find('dl:last').attr('filePath', val);
     List.find('dl:last').find('.Dopt').text('取消').unbind('click').bind('click',function(){ 
          $(this).parent().parent().remove();
          parObj.remove();
     })
     parObj.clone(true).appendTo(formBox);
     parObj.attr('filePath', val);
     parObj.next().find('.DiskFile').css('z-index', z_index +1);
     DiskUpSub(Dbox, formBox, type, val, filetype);
  }
  function DiskUpSub(dlBox, formBox, type, val, filetype){
    var submObj = dlBox.find('.queue').eq(0);
    var filePath = ""
    if(dlBox.find('.uping').length == 0){
      if(submObj.length>0){
        filePath = submObj.attr('filepath');
        formBox.find('form').each(function(i){
            if(filePath == $(this).attr('filepath')){
               submObj.find('.Dsa').text('请稍候...');
               FormSubmit(i, dlBox, formBox, type, val, filetype);
               $(this).find('.submit_sharefile').submit();
               return;
            }
        })
      }
    }
  }
  function FileListDom(filename, filetype){
    return ['<dl class="queue">',
              '<dd>',
                '<i class="file_icon '+ filetype +'" ></i>',
                '<span class="Dfn">'+ filename +'</span>',
                '<span class="Dsa ">排队中...</span>',  
                '<span class="Dfz">60k</span>',
                '<span class="Dopt"></span>',
                '<span class="reupload"></span>',                
              '</dd>',
              '<div class="inline_mask"></div>',
            '</dl>'].join('');
  }

  (function(){
    var DiskBox = $('#WebDiskBox');
        DiskBox.find('.Bm').click(function(){
           var _this =$(this);
           DiskBox.find('.fileList').slideUp(100, function(){
             _this.hide().prev().css('display','inline-block');
           });
          
        })
        DiskBox.find('.Bb').click(function(){
           var _this =$(this);
           DiskBox.find('.fileList').slideDown(100, function(){
             _this.hide().next().css('display','inline-block');
           });
        })  
        DiskBox.find('.Bc').click(function(){
           var _this =$(this);
          // if(DiskBox.find('dl').length == 0)
              DiskBox.hide();
        })
  })();

// 图片上传插件		   
$.fn.upload_file = function (options) {
  var defaults = { tips_css:'upload_img_tip',filetype:'image' , type: 'file' , contian_images :'yes', contian_attachment : 'no' ,'start': 'image' },   params = $.extend(defaults, options || {});
	var _this = $(this);
	var txt , css_btn,  up_cs ='' ,  up_cs1='' , display = 'none' , display1 = 'none';
	params.filetype === 'image'? (up_cs = 'share_menu_on', display = 'block'): (up_cs1 = 'share_menu_on', display1 = 'block');
    $(this).bind('click',handle);
    function createContentDom(css, display, action){
      return ['<div class="'+ css +'" style="display:'+ display +'">',
                 '<div class="file_share_form2">',
                    '<span class="uploadfile_btn">'+ lw_lang.ID_CHOOSEFile +'</span>',
                    '<span style="padding-top: 10px;color: #cd6500;">'+ lw_lang.ID_UPLOAD_TIP +'</span>',     
                    '<div class="sharefile_handle">',
                    '<form enctype="multipart/form-data" action ="'+ action +'" method="post">',
                         '<input type="file" class="DiskFile" name="upld" link="'+ css +'" onchange="sharefiles_handle(this, \''+css+'\')"/>',
                         '<input type="submit" value="submit_files" class="submit_sharefile"  style="display:none" />',
                     '</form>',
                     '</div>',
                     '<div class="fileList"></div>',
                   '</div>',
              '</div>'].join('') 
    }

    function createDom(i,css){					
        var html ='',  html1 = '', html2 = '', imgT = '', attT = '' ;	
    		if(params.contian_images === 'yes'){	
    			imgT  = '<li class="totaskmenu '+ up_cs +' " link="up_iamges">'+ lw_lang.ID_UPLOAD_IMAGE +'</li>';	
          html1 = createContentDom("up_iamges", display, "/lw_pic_upload.yaws");
    		}else{		   
    			display1 = 'block' ;
    			up_cs1 = 'share_menu_on';		  
    		}
    		if(params.contian_attachment === 'yes'){			
    		   attT  = '<li class="totaskmenu '+ up_cs1 +'" link="up_attachment">'+ lw_lang.ID_UPLOAD_FILE +'</li>';		   		  
    		   html2 = createContentDom("up_attachment", display1, "/lw_upload.yaws?size_limit=10000000");
    	  }
    	  html = ['<div class="'+ css +'">',
    		          '<div class="share_top clearfix">', 
    			        '<ul class="share_menu clearfix">' + imgT + attT,
    			        '</ul></div>',
    			      '<div class="tips_content">'].join('');

    		return  html += html1 + html2 +	'</div></div>';
    }

    function showtip(obj, html){
        var offset = obj.offset(), top, left, objBox;
        var tipHtml=['<div class="uploadtip">',
                          '<div class="close"><a href="###" class="del">×</a></div>',
                          '<div class="floatCorner_top" style="">',
                             '<span class="corner corner_1">◆</span>',
                             '<span  class="corner corner_2">◆</span>',
                          '</div>',
                        '<div class="upltips">' + html+ '</div>',
                     '</div>'].join("");

    		if(obj.parent().find('.uploadtip').length == 0){
    			obj.after(tipHtml);
          objBox = obj.parent().find('.uploadtip'); 
    			objBox.find('.floatCorner_top').removeClass('float_corner2 float_corner3 float_corner4').addClass("float_corner3  float_corner5");
          objBox.fadeIn(400, function(){
    			  if( params.start !== 'image')
    				$('.uploadtip').find('.totaskmenu ').eq(1).click();
    			});
    			objBox.find('.del').die('click').live('click', totips.hidetips);
    		  objBox.find('.share_menu').find('li').click(function(){
        			$(this).addClass('share_menu_on').siblings().removeClass('share_menu_on');
        			var linkhref = $(this).attr('link');
        			if(linkhref === 'up_iamges'){
        				  $('.up_iamges').fadeIn();
        				  $('.up_attachment').hide();	
        				  $('.uploadtip').find('.float_corner5').animate({ left:20 }, 300);
        				  params.filetype = 'image' ;
        			}else{
        				    $('.up_iamges').hide();							
        				    $('.up_attachment').fadeIn();	
        				    $('.uploadtip').find('.float_corner5').animate({ left:75 }, 300);
        				    params.filetype = 'attachment' ;
        			}
    		  })
    	  }
    }

    function handle(){
    		var _this = $(this), filetype ,filename;
    		if( _this.parent().find('.upltips').length > 0 ){
    			 _this.hasClass('upload_image') ?  $('.totaskmenu').eq(0).click():  $('.totaskmenu').eq(1).click();
    			 return false;			
    		}	
    		var html = createDom(5, params.tips_css);
    		showtip(_this, html);
    		var obj  = _this.parent().find('.upltips') 
    		obj.find('.gobackupload').click(function(){		
    			 $(this).hide().next().show().next().show();
                 $(this).prev().hide();
                 return false;
    		})
        obj.find('.gobacklist').click(function(){     
             $(this).hide().prev().show().prev().show();
             $(this).next().hide();
             return false;
        })
        $('.uploadtip').find('.del').eq(0).click(function(){
           if($(this).parent().parent().find('.success').length ==0){
             $('.uploadtip').remove();
           }else{
             LWORK.msgbox.show("需清空上传列表才能关闭窗口！", 4, 1000);      
           }
        })
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

$.fn.getPreText = function () {
    var ce = $("<pre />").html(this.html());
    if ($.browser.webkit)
      ce.find("div").replaceWith(function() { return "\n" + this.innerHTML; });
    if ($.browser.msie)
      ce.find("p").replaceWith(function() { return this.innerHTML + "<br>"; });
    if ($.browser.mozilla || $.browser.opera || $.browser.msie)
      ce.find("br").replaceWith("\n");
    return ce.text();
};