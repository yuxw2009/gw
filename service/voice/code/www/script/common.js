var time;
var uuid="51";
var company;
var name2user = {};
var departmentArray = {};
var employer_status = new Array();
var subscriptArray = {};
var groupsArray = {}
var g_blinkid = 0;
var comt_index = "-1";
var upload_images ={'target':'', 'upload_images_url': '', 'attachment_name':'', 'attachment_url':'', 'filesize':'', 'createtime':''};
var current_page_index = { 'file_share_container':'1', 'mysend_msg':'1', 'current_task':'1', 'finish_msg':'1','topic_msg':'1', 'polls_msg':'1', 'questions_msg':'1' }
var allow_loading = 0;

$(window).bind("scroll", function (event){
    var top = document.documentElement.scrollTop + document.body.scrollTop;	
    var textheight = $(document).height();	
    if(textheight - top - $(window).height() <= 100) { if (allow_loading >= 1) { return; }
      allow_loading++;
   	  loadContent.loadmore_msg();
    }
});

//var urlArr = new Array();	
function correctPhoneNumber(phone) {
    phone = phone.replace(/-/g, "");
    phone = phone.replace(/ /g, "");
    phone = phone.replace(/\(/g, "");
    phone = phone.replace(/\)/g, "");
    phone = phone.replace("+", "00");
    if (phone.substring(0, 2) == "00") {
        return phone;
    }
    if (phone[0] == "0") {
        return "0086" + phone.substring(1);
    }
    return "0086" + phone;
}
var totips =  {	
	showtip: function(obj, html ,top , left, Direction , id_conner){	
		var id ;
		id_conner ? id =  'floattips' +  id_conner :( id =  'floattips' , $('#floattips').remove());
		var floattips = ['<div id="'+id+'">',
				'<div class="close"><a href="###" class="del">×</a></div>',
				'<div class="floatCorner_top" style=""><span class="corner corner_1">◆</span><span  class="corner corner_2">◆</span></div>',
				'<div class="totips"></div>',
				'</div>'].join("");
			$('body').append(floattips);
			var obj_container = $('#' + id);					
			var offset, top, left, tipswidth, css = "" , addleft, addtop;			
			offset = obj.offset() ;
			obj_container.find('.totips').html(html);			
			tipswidth =obj_container.width();			
			switch(Direction){
			 case 'down':
			    css = "float_corner2" ;
				addtop = top ;
				addleft = tipswidth + left ;
			    break;
			 case 'top':
			    css = "float_corner4";
				addtop = top ;
				addleft =  tipswidth - left;			 
			    break;
			 case 'left':
			    css = "float_corner3  float_corner5";
				addtop = top ;
				addleft =  tipswidth - left;	 
			    break;
			 default:
			    css = "float_corner3";
				addtop = top ;
				addleft =  tipswidth - left;
			}								
			obj.length > 0 ? top = parseInt(offset.top, 10) + addtop : top = 123;
			obj.length > 0 ? left = parseInt(offset.left, 10) - addleft : left = 50;
			obj_container.css({ top: top + 'px', left: left + 'px'}).show();			
			obj_container.find('.floatCorner_top').removeClass('float_corner2 float_corner3 float_corner4').addClass(css);			
			obj_container.find('.del').die('click').live('click', function(){totips.hidetips(id_conner)});
	},
	hidetips: function(id_conner){
			var id_1 =  id_conner ?  'floattips' +  id_conner : 'floattips';
	        $('#' + id_1).html('').remove();		 
	}
};
var isPhoneNum = function(str){
    var reg = /^(([+]{1}|(0){2})(\d){1,3})?((\d){10,12})+$/;
    return reg.test(str.replace(/[\(\)\- ]/ig, ''));
};
var mobile_test = function (str) {
    reg = /^[+]{0,1}(0){2}(\d){1,3}[ ]?([-]?((\d)|[ ]){11})+$/,
	flag_2 = reg.test(str);
    return flag_2;
};

var array = {
    sort_Aarray: function (a, b) {
        return a.convertname > b.convertname ? 1 : -1
    },
	updateArrayfun: function(temp_id,arr1 ,offline , online){       
        var subtag;
	    var link_href = $('.contact_tab').find('.curent').attr('link');
            temp_id = temp_id.toString();
            subtag = subscriptArray[temp_id];
			employid = arr1[subtag].employid;				
			if(arr1[subtag].status  === offline){
			   arr1[subtag].status = online;			   
		       if(link_href === 'recontact'){
			     $('#recontact').addClass('isupdate')				 
			   }else{
				 var obj = $('.' + employid).parent().parent().find('.structre');		
				 obj.addClass('isupdate');	
			   }
			}
			return arr1;
	},
    updataArray: function (arr, arr2, arr1) {
		var temp_id , k;
		var link_href = $('.contact_tab').find('.curent').attr('link');
        if (arr.length > 0) {
            for (var i = 0; i < arr.length; i++) {
			   temp_id = arr[i];
			   arr1 =  array.updateArrayfun(temp_id, arr1 ,'offline' , 'online')
		        k = loadContent.employstatus_sub(temp_id);	
			   if(link_href === 'org_structure')
			   loadContent.fill_members_sub_tonji(employer_status[k]['department_id'] ,departmentArray); 				   
            }
        }
        if (arr2.length > 0) {
            for (var i = 0; i < arr2.length; i++) {
                temp_id = arr2[i];
				arr1 =  array.updateArrayfun(temp_id, arr1 ,'online' , 'offline');
			    k = loadContent.employstatus_sub(temp_id);	
			   if(link_href === 'org_structure')
			   loadContent.fill_members_sub_tonji(employer_status[k]['department_id'] ,departmentArray); 						
            }
        }
		loadContent.updateemployer();
        return arr1;
    }
}
//输入字符限制
function confine(opt, flag) {
    var oConBox = opt.oConBox, oSendBtn = opt.oSendBtn, oMaxNum = opt.oMaxNum, oCountTxt = opt.oCountTxt, oTmp = "", i = 0, maxNum = 300, iLen = 0;
    for (i = 0; i < oConBox.val().length; i++) iLen += oConBox.val().charAt(i).charCodeAt() > 255 ? 1 : 0.5;
    var num = maxNum - Math.floor(iLen);
    if (flag !== 1) {
        oMaxNum.text(Math.abs(maxNum - Math.floor(iLen)));
        num > 0 ? (num != maxNum ? (oCountTxt.text("\u8fd8\u80fd\u8f93\u5165"), oMaxNum.css('color', "#828282"), oSendBtn.removeClass('disabledBtn'), loadContent.bSend = true) : (oSendBtn.addClass('disabledBtn'), loadContent.bSend = false)) : (oCountTxt.text("\u5df2\u8d85\u51fa"), oMaxNum.css('color', "red"), oSendBtn.addClass('disabledBtn'), loadContent.bSend = false)
    } else {
        oMaxNum.text(Math.abs(Math.floor(iLen)));
        ((iLen > 0) && (iLen <= 140)) ? (oMaxNum.css('color', "#313131"), oSendBtn.removeClass('disabledBtn'), loadContent.bSend = true) : (oMaxNum.css('color', "red"), oSendBtn.addClass('disabledBtn'), loadContent.bSend = false);
    }
}
function contact_scroll(){
	$('#contact').jscroll({
		W: "10px",
		Bg: "#fff"
	}); 	
}
function ifNotInnerClick(clickEventAccepterList, callback){
    var func = function(e){
        var isInnerEvent = false;
        var eTarget = e.target ? e.target : (e.srcElement ? e.srcElement : null);
        if (eTarget && eTarget.nodeType && (eTarget.nodeType === 3)) { // defeat Safari bug
            eTarget = eTarget.parentNode;
        }
        for (var i = 0; i < clickEventAccepterList.length; i++){
            if ($(eTarget).hasClass(clickEventAccepterList[i])){
                isInnerEvent = true;
                break;
            }
        }
        if (!isInnerEvent && (callback)){
            callback(function(){
                $(document).unbind('click');
                $(document).unbind('contextmenu');});
        }
    };
    $(document).unbind('click').bind('click', func);
    $(document).unbind('contextmenu').bind('contextmenu', func);
}

function artDiaglogConfirm(title, msg, idPrefix, okOpt, cancelOpt){
    var returnVal = false;
    var dialog = art.dialog({
        title: title,
        content: msg,
        id: idPrefix + '_confirm_dialog',
        lock: true,
        fixed: true,
        width: 300,
        height: 60,
        cancel: false,
        button: [{  name: okOpt['name'],
                    focus: true,
                    callback: okOpt['cb']
                 },{name:cancelOpt['name'],
                    callback: cancelOpt['cb']
                }]
    });
    return returnVal;
}

var voip_ws_status = false;
function createWSConnection(){
    function ws_ok(){
        voip_ws_status = true;
      //  console.log("ws connection ok...");
    }
    function ws_broken(){
        voip_ws_status = false;
     //   console.log("ws connection broken...");
		/*
        var dialog = art.dialog({
                title: "web socket已断开",
                content: "是否重新建立web socket连接？",
                id: 'ws_broken_confirm_dialog',
                lock: true,
                fixed: true,
                width: 300,
                height: 60,
                cancel: true,
                button: [{
                 name: '确定',
                 focus: true,
                 callback:  function(){voip_client.connect(ws_ok, ws_broken);}
                }]
            });*/
    }
	  try{
         voip_client.connect(ws_ok, ws_broken);
	  }catch(e){ $('#alert').slideDown();}
}
//用javascript进行声音播放控制
function ManageSoundControl(action ,src ,num) {
    $('#soundControl').remove(); 
    if(action == "play") {
        var ebsound = '<embed id="soundControl" src="'+ src +'" mastersound hidden="true" loop="'+ (num ? num : "false")+'" autostart="true" type="audio/mpeg"></embed>';
        $('.lwork').prepend(ebsound);
    }else if(action == "stop") {
       //$('#soundControl').remove();
    }
}

function loadContent() {
    this.search_up_dwon = 0;
    this.error_time = 0;
    this.interval_time = 0;
    this.bSend = false;
    this.target = $('#task');
    this.opt_item = 1;
	this.g_blinkswitch = 0;
    this.myFocus = new Focus();
    this.curTag = "allFocuses";
}
loadContent.prototype = {
    bind: function (target, fun, type) {
        if (type === 'id' && $('#' + target).length > 0) {
            $('#' + target).unbind('click').bind('click', fun);
        } else {
            if ($('.' + target).length > 0) {
                $('.' + target).unbind('click').bind('click', fun);
            }
        }
        return false;
    },
    init: function () {
        loadContent.bind('goback', loadContent.goback, 'id');
        loadContent.bind('tab_item li', loadContent.modeswitch, 'class');
		loadContent.bind('contact_tab a', loadContent.loadaddressbook, 'class');
        loadContent.bind('editg_btn', loadContent.modifygroup, 'class');
        loadContent.bind('nuread_comt', loadContent.loadunreadcomt, 'class');
        loadContent.bind('startVedio', loadContent.startVedio, 'class');
        loadContent.bind('endVedio', loadContent.endVedio, 'class');
        loadContent.bind('nuread_msg', loadContent.loadunreadmsg, 'class');
        loadContent.bind('vedio_notice', loadContent.vedio_noticehandle, 'class');
        loadContent.bind('datameeting_notice', loadContent.datameeting_noticehandle, 'class');
        loadContent.bind('voip_start', loadContent.voipStart, 'id');
        loadContent.bind('voip_stop', loadContent.voipStop, 'id');
        loadContent.initrequest();
        loadContent.dynamichandle();
        loadContent.navigator_check();
		loadContent.modify_images();
		loadContent.upload_file();
	    $('input').each(function () {
            var txt = $(this).val()
            $(this).searchInput({
                defalutText: txt
            });
        })
	   var val =  $('#questions').find('.lwork_mes').val();
	   $('#questions').find('.description_input').searchInput({
			defalutText: '详细描述'
		});
	   $('#questions').find('.lwork_mes').searchInput({
			defalutText: val
		});
	   $('.Interrupt').click(function(){ 	   
		   if($.cookie('company') &&  $.cookie('account') &&  $.cookie('password') ){
			 var data = {'company': $.cookie('company'), 'account': $.cookie('account'),'password':  $.cookie('password'), 't': new Date().getTime()};
			 $.post('/lwork/auth/login', JSON.stringify(data),function(data){			 
			  if(data.status === 'ok'){				  
				 window.location = "lwork.yaws?uuid=" + data['uuid'];               
			  }else{
				 window.location = "index.html";     
			  }
			})
		   }		
		 })
       $('#shortmsg').find('.receivers').searchInput({defalutText: '手机号码/@同事/@群组(分号";"隔开)'});
       $('#shortmsg').find('.shortmsg_content').searchInput({defalutText: "输入短信内容"});
	   
	   $('#alert').find('.close , .concel').click(function(){  $('#alert').slideUp(); })
    },
	employstatus_sub: function(arry_itme){
	   return subscriptArray[arry_itme.toString()];	
	},
    dynamichandle: function () {
        $('.dynamic').find('li').mouseover(function () {
            var _this = $(this);
            _this.siblings().find('.detail').hide();
            _this.find('.detail').show();
			if(notification) notification.cancel();	
            return false;
        })
		$('.dynamic').find('li').click(function () {
            var _this = $(this);
            var mode = _this.attr('mode');
            var type = _this.attr('type');
            $('.tab_item').find('.' + mode).find('a').click();			
            switch (type) {
                case 'new_comt':
                    $('#' + mode).find('li.newcomt').click();
                    $('#' + mode).find('.nuread_comt').click();
                    break;
                case 'new_msg2':
                    $('#' + mode).find('.nuread_msg').click();
                    break;
                case 'taskfinish':
                    $('.dynamic').find('.notice').hide();
					$('.dynamic').find('.notice').find('.new_num').text(0);
                    $('#' + mode).find('li').eq(3).click();
                    break;
                default:
                    $('#' + mode).find('li').eq(0).click();
                    $('#' + mode).find('.nuread_msg').click();
                    break;
            }
            return false;
        })
        $('#container').mouseenter(function () {
            $('.dynamic').find('.detail').hide();
            return false;
        })
    },
    tabswithch: function (obj) {
        var linkhref = obj.attr('link');
        var obj_link = $('#' + linkhref);
        obj.parent().siblings().find('a').removeClass('curent').parent().removeClass('li_current');;
        obj.siblings().removeClass('curent').parent().removeClass('li_current');;		
        obj.addClass('curent').parent().addClass('li_current');
        obj_link.siblings().hide();
	   linkhref === 'org_structure' || linkhref === 'group_list' || linkhref === 'recontact' ? ( $('.jscroll-c').css('top',0) , obj_link.fadeIn(400,contact_scroll)) : obj_link.fadeIn();
   	   return linkhref;
    },
    loadaddressbook: function () {		
		 var linkhref = loadContent.tabswithch($(this));
		 totips.hidetips();
         linkhref === 'group_list' ?  $('.group_btn').show() : $('.group_btn').hide();		 
		 if(linkhref === 'recontact'){
			 var obj = $('#recontact');
		     if(obj.attr('isupdate') !== 'yes'){
			    loadContent.showemployer(groupsArray['recontact']['members'], obj);
				obj.attr('isupdate','yes')		 
		     }
		 }
    },
    modeswitch: function () {
		var _this = $(this).find('a')
        var linkhref = loadContent.tabswithch(_this);
        var obj_link = $('#' + linkhref);
		var temp_obj = $('.tab_item');
        loadContent.target = obj_link;
		totips.hidetips();
		totips.hidetips('share');
        obj_link.find('.sendBtn').unbind('click').bind('click', loadContent.sendBtn);
		if(_this.parent().parent().attr('mode') === 'more_detail'){
			var obj = temp_obj.find('.more_item').prev();
			var html = obj.clone(true);	
			var html2 = _this.parent().clone(true);
			temp_obj.find('a').removeClass('curent');			 
			obj.remove();
			_this.parent().remove();
			temp_obj.find('.more_item').before(html2);
			temp_obj.find('.more_detail').append(html).hide().find('a').removeClass('curent');
		}
        obj_link.find('.lwork_mes').membersearch({
            target: $('#' + linkhref)
        });
        $.cookie('current_tab', linkhref);
		loadContent.loadmsg_handle(linkhref, "1");
    },
	loadmore_msg: function(){
		var link_href, comtlink, page_index ;	
		    link_href = $('.tab_item').find('.curent').attr('link');
			if(link_href === 'questions') return ;
		if(link_href !== 'tasks'){
		   var obj = $('#'+ link_href).find('.menu').find('.curent');    
		   var status = obj.attr('status');
		   if( status !== 'unread'){
			 comtlink = $('.tab_item').find('.curent').attr('comtlink');		
			 page_index = parseInt(current_page_index[comtlink] ) + 1;
			 if(page_index == 0) return ;
		     loadContent.loadmsg_handle(link_href, page_index, 1);
		   }
		}else{
		   var obj = $('.task_menu').find('.curent');    
		   var status = obj.attr('status'),
		       type = obj.attr('type');
			   comtlink = obj.attr('link');
			 if( status !== 'reply' ){
		       page_index = parseInt(current_page_index[comtlink] ) + 1;
			   if(page_index == 0) return ;				 	   
			   loadContent.loadmsg('tasks', type, status, comtlink ,page_index, 2);
			 }
		}		
	},
	loadmsg_handle: function(linkhref, page_index, flag ,callback){
		var loadmore = flag && '' !== flag ? flag : '' ;		
		var obj_link = loadContent.target ;
		var val = obj_link.find('.lwork_mes').val();
		if(!callback)  callback = function(){};				
        switch (linkhref) {
            case 'documents':
                if ('no' === $('#file_share_container').attr('containdom')|| '' !== loadmore) {
                    loadContent.loadmsg('documents', 'none', 'read', 'file_share_container', page_index, 2 , callback);
                    $('#file_share_container').attr('containdom', 'yes');
                }
                break;				
            case 'tasks':
                obj_link.find('.task_menu li').unbind('click').bind('click', loadContent.taskitemclick);
                if ('no' === $('#current_task').attr('containdom')|| '' !== loadmore) {
                    loadContent.loadmsg('tasks', 'assigned', 'unfinished', 'current_task',  page_index, 2,  callback);
                    $('#current_task').attr('containdom', 'yes');
                }
			    obj_link.find('.upload_image').upload_file({ contian_attachment : 'yes'});
		        obj_link.find('.upload_attachment').upload_file({'start': 'attachment', contian_attachment : 'yes'});
                break;
            case 'topics':
			    obj_link.find('.upload_image').upload_file({  contian_attachment : 'no'});
                obj_link.find('.menu li').unbind('click').bind('click', loadContent.contentmenuhandle);		
                if ('no' === $('#topic_msg').attr('containdom') || '' !== loadmore) {					
                    loadContent.loadmsg('topics', 'none', 'all', 'topic_msg', page_index, 2, callback);
                    $('#topic_msg').attr('containdom', 'yes');
                }
                break;
            case 'polls':			
			 obj_link.find('.upload_image').upload_file({  contian_attachment : 'no'});
             obj_link.find('input[type=text]').bind('focus', loadContent.focusHandle);
                if ('no' === $('#polls_msg').attr('containdom')|| '' !== loadmore) {
                    loadContent.loadmsg('polls', 'none', 'all', 'polls_msg', page_index, 2, callback);
                    $('#polls_msg').attr('containdom', 'yes');
                }
				obj_link.find('.lwork_mes').searchInput({
					defalutText: val
				});			
                break;
            case 'meeting':	
			    if ('no' === obj_link.attr('containdom')) {
                    meetingController.checkActive();
					 meetingController.load_history();
					obj_link.find('.inputText').membersearch({
						target: $('#' + linkhref),
						appendcontainer: 'no',
						isgroup: 'no',
						symbol: ';'
					})
				   obj_link.attr('containdom', 'yes');
			    }
                break;			

            case 'video':
                obj_link.find('.video_input').membersearch({
                    target: $('#' + linkhref),
					isgroup: 'no',
                    symbol: ','
                });
                break;
            case 'questions':  
                loadContent.loadmsg('questions', 'none', 'all', 'questions_msg', page_index, 2,  callback);
                break;
            case 'focus':
                loadContent.loadfocus('focus', 'none', 'all', 'focus_msg', page_index, 2,  callback );
                break;
            case 'recycle':
                loadContent.loadrecycle('recycle', 'none', 'all', 'recycled_msg', page_index, 2,  callback );
                break;
			case 'voip':			
			    obj_link.find('.peerNum').membersearch({
                    target: $('#' + linkhref),
					isgroup: 'no',
                    symbol: ','
                });
				break;
            case 'shortmsg':
                $('#loading').hide();
                obj_link.find('#sendShortMsg').unbind('click').bind('click', loadContent.sendShortMsg);
                obj_link.find('#view_shortmsg_history').unbind('click').bind('click', loadContent.viewHistoricalShortMsg);
                obj_link.find('.shortmsg_content').eq(0).unbind('keyup').bind('keyup', loadContent.checkShortMsgInput);
                obj_link.find('.receivers').membersearch({
                    target: $('#' + linkhref),  
					Words_detection: 'no', 
				    isgroup: 'no',
					from: 'msg',					      
                    symbol: '@'
                });
                obj_link.find('.receivers').autoTextarea({maxHeight:150});
                break;
            case 'datameeting':	
			    if ('no' === obj_link.attr('containdom')) {
					 datameetingController.load_history();
					obj_link.find('.inputText').membersearch({
						target: $('#' + linkhref),
						appendcontainer: 'datameeting',
						isgroup: 'no',
						symbol: ';'
					})
				   obj_link.attr('containdom', 'yes');
			    }
                break;				
            default:
               
        }
	},
    taskitemclick: function () {
        var obj = $(this);
        var linkhref = loadContent.tabswithch(obj),
		    status = obj.attr('status'),
		    type = obj.attr('type');

        if (status != 'reply') {
            if ('no' === $('#' + linkhref).attr('containdom')) {
                loadContent.loadmsg('tasks', type, status, linkhref ,'1');
                $('#' + linkhref).attr('containdom', 'yes');
            }
        } else {
            if ('no' === $('#' + linkhref).find('.newcomt_wrap').attr('containdom')) {
                loadContent.loadnewcomt('tasks', linkhref);
                $('#' + linkhref).find('.newcomt_wrap').attr('containdom', 'yes');
            }
        }
    },
    contentmenuhandle: function () {
        var obj = $(this);
        var linkhref = loadContent.tabswithch(obj),
			status = obj.attr('status'),
			mode = obj.attr('mode'),
			type = obj.attr('type');
        var obj_link = $('#' + linkhref);
        if (status === 'all') {
            if ('no' === $('#' + linkhref).attr('containdom')) {
                loadContent.loadmsg(mode, type, status, linkhref);
                $('#' + linkhref).attr('containdom', 'yes');
            }
        } else {
            loadContent.loadnewcomt(mode, linkhref);
        }
        return false;
    },    //初始化获取群组
    navigator_check: function () {
        var isChrome = window.navigator.userAgent.indexOf("Chrome") !== -1;		 
        if (!isChrome)
		     $('#alert').fadeIn();
//		else{
//			 var ua = navigator.userAgent.toLowerCase();
//			 var version = ua.match(/chrome\/([\d.]+)/)[1];
//			 var str = version.split('.');
//			 if(parseInt(str[0],10) < 24 && parseInt(str[2],10) < 1305){	
//			        $('#alert').fadeIn();	
//			 }
//		}
    },
    initrequest: function () {
        if (uuid) {
//			uuid = $.cookie('uuid').toString();	
//            company = $.cookie('company').toString();
//            $('#loading').show();
            var meeting = $('.meeting');
            var aref = meeting.find('a');
            aref.click();
        }
    },
	create_structure: function(departments){
	  var department_id; 	  
	  function createDom(opt){
		  var dom ="<ul>";
		  for(var j = 0 ; j< opt.length ; j++){
		    dom += ['<li class="department  department_'+ opt[j]['department_id'] +'"> <a class="structre"  department_id = "'+ opt[j]['department_id'] +'" href="###"><span class="members_name"  title = "' + opt[j]['department_name'] + '">'+ opt[j]['department_name'] +'</span><span class="members_tongji"></span></a><span class="send_department"  titile="@该部门"></span></li>'].join("");
		    name2user[opt[j]['department_name']] = {'department_id': opt[j]['department_id']};
		  }
		    dom +="</ul>";
		 return dom;
	  }
	  for(var i = 0; i< departments.length ; i++){
		  department_id = departments[i]['department_id'];		  
		  switch (department_id) {
            case 'top':
	             $('#org_structure').html(createDom(departments[i]['sub_departments']))
			     break;
			default:			      
				 $('.department_' + department_id).append(createDom(departments[i]['sub_departments']));
			     break;
		   }
	  }
	},
    loaddepartment: function (data) {
	   var obj = $('#modifyperinof');
	   obj.find('img').attr('src',data['photo'])
	   $('.preview_img').find('img').attr('src',data['photo'])
       obj.find('.name').text(data['name'] + data['employee_id'] );
       obj.find('.department').text(data['department']);
       obj.find('.telephone').val(data['phone']);
       obj.find('.email').val(data['mail']);  
    },
    loadallgroupmember: function (group_id) {
        api.group.get_members(uuid, group_id, function (data) {
            if (data.status === 'ok') {
                var value, len, str;
                var temp = {}, temp1 = {}, convertname;
                var getmembers = new Array;
				len = data.members.length;
                for (var i = 0; i < len; i++) {
                    value = data.members[i];
                    convertname = ConvertPinyin(value.name);
                    temp = { 'uuid': value.member_id, 'name': value.name, 'employid': value.empolyee_id, 'phone': value.phone, 'department': value.department, 'mail': value.mail,'photo': value.photo, 'convertname': convertname.toUpperCase(), 'name_employid': value.name + value.empolyee_id, 'status': value.status , 'department_id': value.department_id };
                    employer_status.push(temp);
                    name2user[value.name + value.empolyee_id] = {'uuid': value.member_id};
					departmentArray[value.department_id] = {'members': {}};	
                }
				loadContent.updategroupsArray();
                employer_status = employer_status.sort(array.sort_Aarray);	
                for (var i = 0; i < employer_status.length; i++) {
                    subscriptArray[employer_status[i].uuid] = i;
					for( var key in departmentArray){
						if(key == employer_status[i].department_id){
							 departmentArray[key]['members'][employer_status[i].uuid] = employer_status[i].uuid;							 
						}
				    }
                }				
			   loadContent.fill_members_tonji(departmentArray);
			  // loadContent.fill_members_tonji(groupsArray);			   
                if ($.cookie('current_tab')) {
                    var current_tab = $.cookie("current_tab");
                    $('.' + current_tab).find('a').click();
                } else {
					$('.focus').find('a').click();
                }
				meetingController.checkActive();
				datameetingController.checkActive();
                loadContent.load_interval();
				$('.sea_member_input').filter_addressbook();
                time = setInterval(loadContent.load_interval, 12000);
				loadContent.blinkNewMsg();

            }
        })
    },	
	fill_members_tonji: function(arr){		
		  for (var key_1 in arr){	
            loadContent.fill_members_sub_tonji(key_1 , arr);
		 }		
	},
	fill_members_sub_tonji: function(key_1 ,arr){
			var num_1 =0 , num_2 = 0;
			if(key_1 !=='recontact'){
				for (var key_2 in arr[key_1]['members']){
					  num_1++ ;
					  var k = loadContent.employstatus_sub(key_2);				
					  if( employer_status[k].status === 'online') num_2++ ;	
				}
				$('.department_' + key_1).find('.members_tongji').text('['+ num_2 +'/'+ num_1 +']');
			}		
		
    },
	updategroupsArray: function(){
	  for (var key in  groupsArray)	{
		 if(key !== 'all'){
			 var members = groupsArray[key]['members'];
			 var new_members = {}
			 for (var i=0; i< members.length; i++){
				new_members[members[i]] = (members[i]).toString();
			 }
		 }
		 groupsArray[key]['members'] = new_members;
	   }
	},
    showemployer: function (arr,container) {
        var html = '', html2 = '';
		var temp_id , subtag;
        var newarr = new Array(); 
	    for (var key in arr){			
			subtag = subscriptArray[arr[key]];
		    newarr.push(employer_status[subtag]);
	    }
		newarr = newarr.sort(array.sort_Aarray);

        for (var i=0 ; i < newarr.length; i++) {
		  if(newarr[i]){	
             if (newarr[i].status === 'online') {
                html += ['<li class="online employer_list ' + newarr[i].employid + '"><img src="' + newarr[i].photo + '" width="38" height="38"/><a href="###" name="' + newarr[i].name + '" phone="' + newarr[i].phone + '" class="sendmsn" uuid="' + newarr[i].uuid + '"><span class="employ_name">' + newarr[i].name + '</span><span class="employ_phone">' + newarr[i].employid  + '</span></a></li>'
					 ].join("");
             } else {
                html2 += ['<li class="offline employer_list ' + newarr[i].employid + '"><img src="' + newarr[i].photo + '" width="38" height="38"/><a href="###" name="' + newarr[i].name + '" phone="' + newarr[i].phone + '" class="sendmsn" uuid="' + newarr[i].uuid + '"><span class="employ_name">' + newarr[i].name + '</span><span class="employ_phone">' + newarr[i].employid + '</span></a></li>'
					 ].join("");
             }
		  }
        }
        html += ['' + html2 + ''].join("");
		if(container.attr('id') !== 'search_employer'){			
	      container.find('ul').length > 0 ? container.find('ul').html(html) :container.append('<ul>' + html + '</ul>');
          container.find('ul').slideDown(400,contact_scroll);	
		  var Firefox = window.navigator.userAgent.indexOf("Firefox") !== -1
         if (Firefox) $('.offline').find('img').css('opacity', '0.4');	
		 }else{
			container.siblings().hide();
			$('.contact_tab').find('.search_members').show().siblings().hide();
			container.html('<ul>' + html + '</ul>').fadeIn(400,contact_scroll);
		 }		
        loadContent.bind('employer_list', loadContent.sendmessage, 'class');
        loadContent.memberdetail();		
    },	
	
	updateemployer: function(phone){
        var link_href = $('.contact_tab').find('.curent').attr('link');	
		if(link_href == 'recontact'){	
		    var obj = $('#recontact');
			if(obj.hasClass('isupdate')){
		      loadContent.showemployer(groupsArray['recontact']['members'], obj);
			  obj.removeClass('isupdate','no');
			}
		}else{
			$('#' + link_href).find('.isupdate').each(function(){
				var _this = $(this).parent();
				var department_id ;
				if(_this.find('ul').css('display')=='block'){
					var department_id = _this.find('.structre').attr('department_id') ;
			link_href == 'group_list' ? loadContent.showemployer(groupsArray[department_id]['members'], _this) : loadContent.showemployer(departmentArray[department_id]['members'] , _this);
				   _this.find('.structre').removeClass('isupdate','no');
				   return false;
				}
			})
		}
	},
	org_structure_itemclick: function(){
		var _this = $(this),
		   ul = _this.parent().find('ul').eq(0),
		   department_id = _this.attr('department_id'),				
		   isupdate = _this.hasClass('isupdate'),
		   html ="" ,	
		   link_href = $('.contact_tab').find('a.curent').attr('link'), 
           loademployer = function (){	
		   if(link_href == 'group_list'){
			   loadContent.showemployer(groupsArray[department_id]['members'], _this.parent())
		   }else{
			  if(departmentArray[department_id]){				  
				  loadContent.showemployer(departmentArray[department_id]['members'] , _this.parent()) 
			   } 
		   }
		}
		totips.hidetips();
		$('.contianer_contact').find('li').removeClass('li_current');
		$('.contianer_contact').find('a').removeClass('current currentbg');		
		_this.parent().siblings().find('ul').slideUp();	
		_this.addClass('currentbg current');
		if(ul.length > 0){		
		  ul.css('display') === 'none' ? (isupdate ? loademployer() :  ul.slideDown(400,contact_scroll)): (ul.slideUp(400, contact_scroll) ,  _this.removeClass('currentbg'));
		}else{		 
          loademployer();
		}
		  return false;
	},
    memberdetail: function () {
        var timeout;
        $('.employer_list').unbind('mouseover').bind('mouseover', function () {		
		 if($('#totips').find('.gen_confirm').length == 0){
            var obj = $(this).find('.sendmsn');
            var employer_uuid = obj.attr('uuid');			
            var current_mode = $('.contact_tab').find('.curent').attr('link');						
            var group_id = obj.parent().parent().prev().prev().attr('department_id');			
			group_id ? group_id = group_id : group_id = groupsArray['recontact']['employer_uuid'];
            var hide = function(){
				 if($('#floattips').find('.tipcontent').length > 0) totips.hidetips();
			}
            var i = subscriptArray[employer_uuid];
			var html = loadContent.createtipsDom(i , 'tipcontent');			
			current_mode === 'org_structure' ? html += '</div>' : html += '<div id="delgroupmember" class="delgroupmember" title = "删除成员"></div></div>';
            timeout = setTimeout( function () {
			    totips.showtip(obj, html,-55, 10, 'down');				
			   $('#delgroupmember').die('click').live('click', function () {
					api.group.delete_members(uuid, group_id.toString(), employer_uuid, function (data) {			
						groupsArray[group_id] ? delete groupsArray[group_id]['members'][employer_uuid]: delete groupsArray['recontact']['members'][employer_uuid];					
						hide();
						obj.parent().remove();
						LWORK.msgbox.show("删除成功！", 4, 1000);					
					}, function () { LWORK.msgbox.show("服务器繁忙，请稍后再试！", 1, 2000); $('#loading').hide(); });
				});	
				$('#article').mouseenter(hide);
				$('#floattips').mouseleave(hide);
				$('.tips_buttom').find('a').die('click').live('click', function () {
					var link_obj = $(this).parent().attr('class');				
					$('.tab_item').find('.' + link_obj).click();
					obj.click();
					hide();					
				});				
			}, 1000);
		  }		  
        }).bind('mouseout', function () { clearTimeout(timeout); });
    }, //自定义组添加右键菜单
	createtipsDom: function(i ,css){
		
	    return  html = ['<div class="'+ css +'">',
		            '<img src="' + employer_status[i].photo + '" width="48" height="48">',
		            '<ul class="tipsdetail"><li>姓名： ' + employer_status[i].name + '</li>',
					'<li>工号： ' +  employer_status[i].employid + '</li>',
					'<li>部门： ' + employer_status[i].department + '</li>',
					'<li>邮箱： ' + employer_status[i].mail + '</li>',
					'<li>电话： ' + employer_status[i].phone + '</li></ul>',
					'<div class="tips_buttom"><ul>',
					'<li class="tasks" title="发起工作"><a href="###"></a></li>',					
					'<li class="topics" title="发起微博"><a href="###"></a></li>',
					'<li class="polls" title="发起投票"><a href="###"></a></li>',						
					'<li class="meeting" title="发起会议"><a href="###"></a></li>',
					'<li class="shortmsg" title="手机短信"><a href="###"></a></li>',					
					'<li class="voip" title="网络电话"><a href="###"></a></li>',
					'</ul></div>'	
					].join("");
					
	},
	contentmemberdetail: function(){
	  var timeout;
	  $('.lanucher').bind('mouseover', function () {
		  var _this = $(this);
		  var employ_uuid = _this.attr('employer_uuid');
		  
	      var i = subscriptArray[employ_uuid];	  
		  if(!employer_status[i]) return ;
		  var html =  loadContent.createtipsDom(i, 'tipcontent2');		
	      var hide = function(){ if($('#floattips').find('.tipcontent2').length > 0) totips.hidetips(); }		
		  
		 timeout = setTimeout(function () { totips.showtip( _this, html , -198 ,207,'top');		
				$('#floattips ').mouseleave(hide);
				$('#nav').mouseenter(hide);
				$('#contact ').mouseenter(hide);
				_this.parent().parent().siblings().mouseenter(hide);
				_this.parent().parent().find('.pagefoot').mouseenter(hide);
				$('.tips_buttom').find('a').die('click').live('click', function () {
					var link_obj = $(this).parent().attr('class');
					$('.tab_item').find('.' + link_obj).click();	
					loadContent.fill_text(employ_uuid);
					hide();					
				});
		 }, 1000);		    
	  })
	   $('.personal_icon').bind('mouseover', function () {	
		 $(this).next().find('.lanucher').mouseover();	   
	   })
	   $('.lanucher , .personal_icon').bind('mouseout', function () { clearTimeout(timeout); });
	  
	},
    personalgroup_handle: function () {		
			   $('.structre').mouseenter(function(){
				  $('.send_department').hide();
				  $(this).next().show();
				})
				$('.contactbox').mouseleave(function(){			
				  $('.send_department').hide();	
				})
			   $('.send_department').click(function(){
				   var target = loadContent.target;
				   var _this = $(this);
				   var  txt = _this.prev().find('.members_name').text();
				   var current_id = target.attr('id');
				    if(current_id === "documents")
				      target = $('#floattipsshare');					 
				    if(current_id !== "questions"){
	                  target.find('.lwork_mes').focus();
                      mesText = target.find('.lwork_mes').val();
                      target.find('.lwork_mes').val(mesText + ' @' + txt + ' ');
                      if (current_id === 'shortmsg'){
                        loadContent.addGroup2ShortMsgReceivers(txt);
                      }	
				   }
				   return false;				   
				})		
		
		
        var imageMenu1Data = [
                [{ text: "添加成员",
                    func: function () {
						var _this = $(this);
						var group_id = _this.attr('department_id');
						var group_name = _this.text();
                        loadContent.modifygroup(group_id , group_name , _this);
                    }
                }],
                [{ text: "修改组名",
                    func: function () {
                        var a = '<div class="modifygroupname"><input type="text" class="menutext2" value="" name="menutext2"><span class="editCurrentItem" style="display: inline;"><a class="add_comint" href="###"></a><a class="cancle_btn" href="###"></a></span></div>';
                        var obj = $(this);
						var old_name = obj.text();						
						var group_id = obj.attr('department_id');						  
                        loadContent.opt_item = 0;
                        obj.hide().after(a);                 
                        $('.modifygroupname').find('input').val(old_name).focus();
                        $('.modifygroupname').find('.cancle_btn').bind('click', function () {
                            $('.modifygroupname').prev().show();
                            $('.modifygroupname').remove();
                            loadContent.opt_item = 1;
                        });
                        $('.modifygroupname').find('.add_comint').bind('click', function () {          
                            var new_name = $('.modifygroupname').find('input').val();
							var convertname;				
							for (var key in groupsArray) {
								
								if (new_name == groupsArray[key]['name'] || new_name.toUpperCase() === 'RECENT' ) {
								    LWORK.msgbox.show("已包含该组", 2, 1000);
									$('.modifygroupname').find('input').focus();
									return false;
								}
							}
						  if ('' !== new_name && '输入组名/不能与现有的组重复' !== new_name && new_name.indexOf(' ') < 0) {
                             api.group.rename_group(uuid, group_id.toString(), new_name, function (data) {
                                if (data.status === 'ok') {
                                    $('.modifygroupname').prev().text(new_name).show();
                                    $('.modifygroupname').remove();
                                    loadContent.opt_item = 1;
									convertname = ConvertPinyin(new_name);
									delete name2user[old_name];
									name2user[new_name] = {'group_id': group_id};	
							     	groupsArray[group_id]['name'] = new_name;
									groupsArray[group_id]['convertname'] = convertname.toUpperCase();
                                    LWORK.msgbox.show("修改成功！", 4, 1000);
                                }
                            });
						  }else{
							  LWORK.msgbox.show("组名不能包含空格和为空", 2, 1000);
							  $('.modifygroupname').find('input').focus();
						  }
                        });
                    }
                }],
                [{
                    text: "删除该组",
                    func: function () {
                        var obj = $(this);
						var group_id = obj.attr('department_id');				
                        loadContent.createGeneralConfirm(obj, '您确定要删除该组吗？', '', function() {
                            api.group.delete_group(uuid, group_id.toString(), function (data) {
                                if (data.status === 'ok') {
                                    obj.parent().remove();
                                    if ($('#group_list').find('li').length <= 0) $('.mygroup').hide();
                                    LWORK.msgbox.show("删除成功！", 4, 1000);
                                 //   delete name2user[groupsArray[group_id.toString()]['name']];
                                    delete groupsArray[group_id.toString()];
                                    $('#group_list').find('a').eq(0).click();
                                }
                            });
                        });
                    }
                }]
            ];
        //遍历自定义组，添加右键
     $("#group_list a").each(function () {
            var obj = $(this);
            var imageMenu = imageMenu1Data;
            obj.smartMenu(imageMenu, {
                name: "application",
                obj: obj,
                beforeShow: function () { if(obj.parent().find('ul').css('display') !==  'block') obj.click(); 
				}
            });
        });
    },
	upload_file: function(){
		$('#share_file').click(function(){
		 var upload_filecontent = document.getElementById('upload_filecontent');	 
		 var dialog = art.dialog({
            title: '文件上传',
            content: upload_filecontent,
            id: 'upload_filecontent_dialog',
            lock: true,
            fixed: true,
            width: 400,
            height: 100,
			button: [{
			  name: '完成',
			  focus: true,
		      callback:  function(){
				  form_index = -1;				  
				  $('#upload_filecontent').find('.upload_main').html('');
				}
			}]			
           });	
		   $('.aui_close').hide();	
	     })
	},
    creategroup: function () {
        var creatgroupbox = document.getElementById('creatgroupbox');
        var obj = $('#creatgroupbox');		
		var fun = function () {
            var groupname = obj.find('input').val();
            for (var key in groupsArray) {
                if (groupname == groupsArray[key]['name'] || groupname.toUpperCase() === 'RECENT') {
                    obj.find('.modify_tips').text('已包含该组').show();
                    $('#creatgroupbox').find('input').focus();
                    return false;
                }
            }
            if ('' !== groupname && '输入组名/不能与现有的组重复' !== groupname && groupname.indexOf(' ') < 0) {
                api.group.create_group(uuid, groupname, 'ww', function (data) {					
                    var a = $('<li class="department  department_'+ data['group_id'] +'"> <a href="###" department_id="' + data['group_id'] + '" class="group structre"><span class="members_name" title = "' + groupname + '">' + groupname + '</span><span class="members_tongji"></span></a> <span class="send_department"  titile="@该部门"></span></li>');
 				    $('#group_list').append(a).parent().show();
				    loadContent.bind('structre', loadContent.org_structure_itemclick, 'class');
                    obj.find('input').val('');
                    LWORK.msgbox.show("添加成功！", 4, 1000);					
					if(!($('.mygroup_contact').hasClass('curent'))){
						 $('.mygroup_contact').click();
					}
			  		name2user[groupname] = {'group_id':data['group_id']};
                    var convertname = ConvertPinyin(groupname);
                    groupsArray[data['group_id'].toString()] = { 'name': groupname, 'members': {}, 'convertname': convertname.toUpperCase() };
                    //绑定右键					
                    loadContent.personalgroup_handle();
					 a.find('a').click();					
                });
            } else {
                $('#creatgroupbox').find('.modify_tips').text('组名不能为空并且不能包含空格').show();
                $('#creatgroupbox').find('input').focus();
				return false;
            }
        }
	   var dialog = art.dialog({
            title: '新建组',
            content: creatgroupbox,
            id: 'creategroup_dialog',
            lock: true,
            fixed: true,
            width: 300,
            height: 120,
			cancel: true,
			button: [{
			  name: '确定',
			  focus: true,
			  callback:  fun
			}]			
        });		
        obj.find('input').keyup(function () { obj.find('.modify_tips').hide(); })
        obj.find('input').searchInput({
            defalutText: "输入组名/不能与现有的组重复"
        });
        obj.find('input').keyup(function () { $('#creatgroupbox').find('.tips').hide(); }) 
    },
    modifygroup: function (group_id, group_name, _this) {
        var modifygroupbox = document.getElementById('modifygroupbox');
		var fun = function () {
            var temp = new Array();
            var temp_item, temp_str = '';	
            $('#addmemberlist').find('li').each(function () {
                temp_item = ($(this).attr('uuid').toString());
                temp.push(temp_item);				
				groupsArray[group_id.toString()]['members'][temp_item] = temp_item ;
            });	
            api.group.add_members(uuid, group_id.toString(), temp, function (data) {
                $('#add_member').val('通过拼音或汉字搜索添加成员');
                $('#addmemberlist').html('');
				loadContent.showemployer(groupsArray[group_id.toString()]['members'], _this.parent());
            });
        };
        var dialog = art.dialog({
            title: '增加群组成员',
            content: modifygroupbox,
            id: 'addgroupmembers',
            lock: true,	
            fixed: true,
            width: 410,
            height: 300,
			cancel: true,
			button: [{
			  name: '确定',
			  focus: true,
			  callback:  fun
			}]	
        });
        $('#add_member').membersearch({
            target: $('#modifygroupbox'),
            isgroup: 'no',
            appendcontainer: $('#addmemberlist'),
            symbol: ';'
        });
        $('#add_member').searchInput({
            defalutText: "通过拼音或汉字搜索添加成员"
        });		

    },
    format_message_content: function (content, the_class) {
        var regexp = /((ftp|http|https):\/\/(\w+:{0,1}\w*@)?([A-Za-z0-9][\w#!:.?+=&%@!\-\/]+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?)/gi;
		content = content.replace(/(^\s*)|(\s*$)/g, "");	
        content = content.replace(/</g, '<span> <</span>');
        content = content.replace(regexp, '<a class="' + the_class + '" target="_blank" href="$1">$1</a>');	
        content = content.replace(/(@[^\s]+)\s*/g, '<span class="' + the_class + '">$1</span>');
		return	content.replace(/\n/g, '<br\>');	 ;	
    },
    format_message: function (header, content, footer, links, cb) {
        var container = $('<dl class="message_container"/>');
        content = loadContent.format_message_content(content, 'linkuser');
        var header_div = $('<dt class="message_header">' + header + '</dt>');
        var content_div = $('<dd class="message_content">' + content + '</dd>');
        var footer_div = $('<dd class="message_footer">' + footer + '</dd>');
        var link_container = $('<dd class="pagefoot"/>');
        $.each(links, function (key, value) {
            if ($.isFunction(value)) {
                var a = $(sprintf('<a href="###">%s</a>', key)).click(function (e) {
                    e.preventDefault();
                    value();
                });
                link_container.append(a);
            } else if (typeof (value) == 'string') {
                link_container.append(sprintf('<a href="%s">%s</a>', value, key));
            }
        });
        container.append(header_div).append(content_div).append(footer_div).append(link_container);
        return container;
    },
    sendmessage: function () {
        var _this = $(this).find('.sendmsn');
		var emmployer_uuid =  _this.attr('uuid');
        loadContent.fill_text(emmployer_uuid);
		$('.seatips').hide();
        return false;
    },
	fill_text: function(emmployer_uuid){
        var target = loadContent.target;
		var id = target.attr('id');	
		var i = loadContent.employstatus_sub(emmployer_uuid);
		var mesText;
		var txt = employer_status[i]['name_employid'];
		var phone =  employer_status[i]['phone'];
        var name =  employer_status[i]['name'];				
        switch (id) {
            case 'meeting':
			   if (isPhoneNum(phone)){
			      meetingController.addto_current_list(name, phone);
                }else{
                    LWORK.msgbox.show(name + " 没有登记电话号码!", 5, 2000);
                }
       
                break;
			case 'documents':
			    var new_target = $('#floattipsshare')
		        new_target.find('.lwork_mes').focus();
                mesText = new_target.find('.lwork_mes').val();
                new_target.find('.lwork_mes').val(mesText + ' @' + txt + ' ');
                confine({ 'oConBox': new_target.find('.lwork_mes'), 'oSendBtn': new_target.find('.sendBtn'), 'oMaxNum': new_target.find('.maxNum:first'), 'oCountTxt': new_target.find('.countTxt:first') });
			    break;	
            case 'datameeting':
//                alert("adafdas");
                datameetingController.addto_current_list(name, emmployer_uuid);
                break;
            case 'questions':
                break;				
            case 'video':
                target.find('.video_input').css('color', '#343434').val(txt).attr('sendid', emmployer_uuid);
                break;
            case 'voip':
                if (isPhoneNum(phone)){
			        target.find('.peerNum').val(txt).attr('phone', phone);
                }else{
                    LWORK.msgbox.show(name + " 没有登记电话号码!", 5, 2000);
                }
                break;
            case 'shortmsg':
                if (isPhoneNum(phone)){
                    var newPhone = phone + '[' + name + ']';
                    var txtOld = target.find('.receivers').eq(0).focus().val();
                    var addStr = ((txtOld.length === 0) || (txtOld[txtOld.length - 1] === ';')) ? newPhone : ';' + newPhone;
                    var txtnew = txtOld + addStr;
                    target.find('.receivers').val(txtnew);
                }else{
                    LWORK.msgbox.show(name + " 没有登记电话号码!", 5, 2000);
                }
                break;				
            default:
                target.find('.lwork_mes').focus();
                mesText = target.find('.lwork_mes').val();
                target.find('.lwork_mes').val(mesText + ' @' + txt + ' ');
                confine({ 'oConBox': target.find('.lwork_mes'), 'oSendBtn': target.find('.sendBtn'), 'oMaxNum': target.find('.maxNum:first'), 'oCountTxt': target.find('.countTxt:first') });
                break;
        }
	},
    voipEstablish: function(peerNum, familiarName){
        var peerDisplay = familiarName === '' ? peerNum : familiarName;
        voip_startmedia(function(){     
            var peerRingCallback = function(){
                    $('#voip').find('.voip_call_status').eq(0).empty().append('与<span class="peerNumStr">'+peerDisplay+'</span>通话中...').show();
                    $('#voip').find('.peer_status').css('background-position', 'left -2370px');
                };
            var peerHangupCallback = function(){
                    LWORK.msgbox.show("对端已挂机", 4, 2000);
                    loadContent.voipClear();
                };/**/
            voip_webcall(peerNum,peerRingCallback, peerHangupCallback);
            $('#voip').find('input.peerNum').hide();
            $('#voip').find('.voip_call_status').eq(0).empty().append('正在与<span class="peerNumStr">'+peerDisplay+'</span>建立呼叫...').show();
            $('#voip').find('.peer_status').css('background-position', 'left -2370px');
            $('#voip_start').hide();
            $('#voip_stop').show();
        });
    },
    voipClear: function(){
        $('#voip').find('input.peerNum').eq(0).val('').blur().focus();
        $('#voip').find('input.peerNum').show();
        $('#voip').find('.voip_call_status').eq(0).text('').hide();
        $('#voip').find('.peer_status').css('background-position', 'left -2330px');
        $('#voip_start').show();
        $('#voip_stop').hide();     
    },
    voipStart: function(){
        var peerNum = $('#voip').find('input.peerNum').eq(0).focus().val();
        var familiarName = '';
		var history_num = '' ;
        if (peerNum === ''){
            LWORK.msgbox.show("请填写被叫号码", 3, 1000);
            return false;
        }/*else if(!isPhoneNum(peerNum)){
            if (name2user[peerNum]){		
                var eIndex = loadContent.employstatus_sub(name2user[peerNum].uuid);
                familiarName = employer_status[eIndex].name;
                peerNum = $('#voip').find('input.peerNum').eq(0).attr('phone');
            }else{
                LWORK.msgbox.show("所填号码有误，请重新填写", 3, 1000);
                $('#voip').find('input.peerNum').eq(0).val('').focus();
                return false;
            }*/
        }else{
			   if( $.cookie('history_num')){
				  history_num =  $.cookie('history_num'); 
			   }			
		      '' === history_num ? history_num = peerNum +'&' : history_num += '&' + peerNum;	  	
			   		     
			  if(history_num !== '')		  
			  $.cookie('history_num',history_num, {expires: 30});
		}
//        peerNum = correctPhoneNumber(peerNum);
        loadContent.voipEstablish(peerNum, familiarName);
        return false;
    },
    voipStop: function(){
        voip_hangup();
        loadContent.voipClear();
        return false;
    },
    startVedio: function () {
        var _this = $(this);
        var to = $('#video').find('.video_input').attr('sendid');
        if (to) {
            to = to.toString();
            var opt = { from: uuid, to: to };    
			var i = loadContent.employstatus_sub(to);
            var status = employer_status[i]['status'];			
            var employ_uuid = (employer_status[i]['uuid']).toString();
			if (employ_uuid === uuid) { LWORK.msgbox.show("不能给自己发起视频", 3, 2000); $('#video').find('.video_input').val('').focus(); return false; }
			  try{
               status === 'online' ? (	$('#video').find('.endVedio').attr('to',to), ws.connect(opt) , $('#video').find('.video_input').attr('disabled', true), $('#video').find('.startVedio').hide().next().show()) : LWORK.msgbox.show("对方不在线，不能发起视频，还是电话沟通吧！", 3, 2000);
			 }catch(e){ $('#alert').slideDown();}
	    } else {
            LWORK.msgbox.show("向谁发起视频呢？", 3, 2000);
        }
    },
    endVedio: function () {		
		var to = $(this).attr('to');
        $('#video').find('.video_input').attr('disabled', false);
        $('#video').find('.endVedio').hide().prev().show();
		$('#video').find('.navigator_tips').hide();
		$('#video').find('.video_input').val('搜索/右边选择联系人').css('color' , '#999');		
        vid1.src = '';
        vid2.src = '';
		send_message({command:'hangup', from:uuid, to:to.toString() });	
		return false;	
    },
    addGroup2ShortMsgReceivers: function(groupname){
        var target = loadContent.target;
        var groupName = '@' + groupname;
        var txtOld = target.find('.receivers').eq(0).focus().val();
        var addStr = ((txtOld.length === 0) || (txtOld[txtOld.length - 1] === ';')) ? groupName : ';' + groupName;
        var txtnew = txtOld + addStr;
        target.find('.receivers').val(txtnew);
    },
    sendShortMsg: function(){
        var target = loadContent.target;
        var receiversStr = target.find('.receivers').eq(0).focus().val();
        var msgContent = target.find('textarea.shortmsg_content').eq(0).focus().val();
        if (msgContent.length < 1){
            LWORK.msgbox.show("短信内容不能为空！", 5, 1000);
            return false;
        }
        if (receiversStr.length < 1){
            LWORK.msgbox.show("接收者手机号码不能为空！", 5, 1000);
            return false;
        }
        function expandGroups(rcvrs){
            var i = 0;
            var noNums = new Array();
            var invalidGroups = new Array();
            while(i < rcvrs.length){
                if (rcvrs[i][0] === '@'){
                    var groupName = rcvrs[i].substring(1); 
                    rcvrs.splice(i, 1);
                    if ((typeof (name2user[groupName]) === 'object') && (name2user[groupName].group_id || name2user[groupName].department_id)){
                        var arr = name2user[groupName].group_id ? groupsArray : departmentArray;
                        var id = name2user[groupName].group_id ? name2user[groupName].group_id : name2user[groupName].department_id;
                        for(var key in arr[id]['members']){
                            var temp_uuid =arr[id]['members'][key];
                            var person = employer_status[loadContent.employstatus_sub(temp_uuid)];
                            if (person.phone.length < 1){
                                noNums.push(groupName+'/'+person.name);
                            }else{
                                rcvrs.push(person.phone + '[' + person.name + ']');
                            }
                        } 
                    }else{
                        invalidGroups.push(groupName);
                    }
                }else{
                    i++;
                }
            }
            return {'ok':rcvrs, 'invalidGroups':invalidGroups, 'noNums':noNums};
        }
        function filterInvalidPhoneNums(rcvrs){
            var i = 0;
            var invalidReceivers = new Array();
            while(i < rcvrs.length){
                if (!isPhoneNum(rcvrs[i]["phone"])){
                    invalidReceivers.push(rcvrs[i]["phone"]+(rcvrs[i]["name"].length > 0 ? '['+rcvrs[i]["name"]+']':''));
                    rcvrs.splice(i,1);
                }
                i++
            }
            return {'ok':rcvrs, 'invalidNums':invalidReceivers};
        }
        function filterRepeations(rcvrs){
            var i = 0;
            while(i < rcvrs.length){
                for (var j = 0; j < i; j++){
                    if (rcvrs[j]["phone"] === rcvrs[i]["phone"]){
                        rcvrs.splice(i);
                        break;
                    }
                }
                i++;
            }
            return rcvrs;
        }

        var receiverList = receiversStr.split(';');
        var expanded = expandGroups(receiverList);
        receiverList = expanded['ok'].map(function(elem){
            var nameS = elem.indexOf('['), nameE = elem.indexOf(']');
            var nameStr = (nameS < 0 || nameE < 0 || nameS >= nameE) ? "" : elem.substring(nameS + 1, nameE);
            var phoneStr = nameS < 0 ? elem : elem.substring(0, nameS);
            return {"phone":phoneStr, "name":nameStr};
        });
        var filtered = filterInvalidPhoneNums(receiverList);
        receiverList = filtered['ok'].map(function(elem){return {"phone":correctPhoneNumber(elem["phone"]), "name":elem["name"]};});
        receiverList = filterRepeations(receiverList);
        if (receiverList.length < 1){
            LWORK.msgbox.show('你填写的短信接收者不对，请核对后再发送！', 5, 1000); 
            return false;
        }
        var html = "";
        if (expanded['invalidGroups'].length > 0){
            html += '<div class="confirm_dialog_item">下面的群组名不对：</div>';
            html += '<div class="confirm_dialog_txt">' + expanded['invalidGroups'].join(";") + '</div>';
        }
        if (expanded['noNums'].length > 0){
            html += '<div class="confirm_dialog_item">下面的群组用户没有登记电话号码：</div>';
            html += '<div class="confirm_dialog_txt">' + expanded['noNums'].join(";") + '</div>';
        }
        if (filtered['invalidNums'].length > 0){
            html += '<div class="confirm_dialog_item">下面的接收者/电话号码不对：</div>';
            html += '<div class="confirm_dialog_txt">' + filtered['invalidNums'].join(";") + '</div>';
        }
        if (html.length > 0){
            artDiaglogConfirm('请确认', 
                html + "<h4>是否忽略这些接收者并继续发送？</h4>", 
                'smsReceivers',
                {'name':'是，忽略', 'cb':function(){loadContent.doSendShortMsg(receiverList, msgContent);}}, 
                {'name':'否，我再改一下', 'cb':function(){}});
        }else {
            loadContent.doSendShortMsg(receiverList, msgContent);
        }
        return false;
    },
    doSendShortMsg: function(receivers, msg){
        var target = loadContent.target;
        var me = employer_status[loadContent.employstatus_sub(uuid)];
        var sig = '来自:' + me.name + me.employid + '-' + company;
        api.sms.send(uuid, receivers, msg, sig, function(data){
            if (data['fails'].length > 0){
                art.dialog.alert("向"+data['fails'].join("、") + "的发送失败了，请确认这些接收号码的正确性！");
            }else{
                LWORK.msgbox.show("短信已发送成功！", 4, 1000);
            }
            target.find('.receivers').eq(0).val('').focus().blur();
            target.find('textarea.shortmsg_content').eq(0).val('').focus().blur();
        });
    },
    createSmsHistoryItemDom: function(item){
        var receiversDisplay = item.members.map(function(receiver){return '<span class="linkuser">' + receiver.name + '</span>' +  receiver.phone;}).join("、");
        var receiversDataRecord = item.members.map(function(receiver){return receiver.phone + (receiver.name.length > 0 ? '[' + receiver.name + ']' : '');}).join(";")
        var html = ['<dl class="msg_item_1" style="display:block">',
		            '<dd><span class="shortmsg_content_1">短信内容：</span><span>' + item.content  + '</span></dd>',	
                    '<dd class =""><span class="shortmsg_object_1">发送对象：</span><span>' + receiversDisplay + '</span></dd>', 
					'<dd><span class="shortmsg_time_1">发送时间：</span>' + item.timestamp + '</dd>',		
                    '<dd class="pagefoot" style="clear:both">',
                    '<a href="###" class="reSendSMS" receivers="' + receiversDataRecord + '">重新发送</a>',
                    '</dd></dl>'].join("");
        return html;
    },
    viewHistoricalShortMsg: function(){
        api.sms.history(uuid, function(data){
            //var data = get_test_sms_history();
            var history = data["history"];

            if (history.length === 0){
                LWORK.msgbox.show("没有已发送短信记录！", 3, 1000);
            }else{
                $('.shortmsg_history_list').eq(0).html('');
                for (i = 0; i < history.length; i++){
                    $('.shortmsg_history_list').eq(0).append(loadContent.createSmsHistoryItemDom(history[i]));
                }
                loadContent.bind('reSendSMS', loadContent.toResendSMS, 'class');
            }
            return false;
        });
    },
    toResendSMS: function(obj){
        var receivers = $(this).attr('receivers');
        var content = $(this).parent().parent().find('span').eq(1).text();
        $('#shortmsg').find('textarea.receivers').eq(0).focus().val(receivers);
        $('#shortmsg').find('textarea.shortmsg_content').eq(0).focus().val(content);
        return false;
    },
    checkShortMsgInput: function(){
        var i = 0, iLen = 0, txt = $(this).val();
        for (i = 0; i < txt.length; i++){
            //iLen += txt.charAt(i).charCodeAt() > 255 ? 1 : 0.5;
            iLen += 1;
        }
        var maxNum = 120 - Math.floor(iLen);
        if (maxNum < 0){
            $(this).val(txt.substring(0, txt.length - 1));
            maxNum = 0;
        }
        $('#shortmsg').find('.maxNum').eq(0).text(maxNum);
        return false;
    },
	getmembers: function(msg_content){
	   var	members = new Array(), to = "";
	   var object = loadContent.replacecontent(msg_content)['to'];
	   for (var key in object) {
            members.push(object[key]);          
		   to === '' ? to = object[key] : to += ',' + object[key];
        }	   
	   return members
	},
    sendBtn: function () {
        var target = loadContent.target;
        var targetid = target.attr('id');
	    var msg_content = target.find('.lwork_mes').val();
        var opt = {};		
        if (!target.find('.sendBtn').hasClass('disabledBtn')) {			
			var images ,filename;
			totips.hidetips();
			if(upload_images.target === targetid){
				filename = ('' == upload_images.attachment_name ? '' : upload_images.attachment_name);											   
			}else{
			    images = '';
				filename = '';
			}
               msg_content = loadContent.replacecontent(msg_content)['msg_content'];
            var members =  loadContent.getmembers(msg_content);
            switch (targetid) {
                case 'tasks':
                    $('#tasks').find('.menu').find('li').eq(1).click();
                    opt = { uuid: uuid, content: msg_content, members: members, image:upload_images,  't': new Date().getTime() };
                    loadContent.publish('tasks', opt, $('#mysend_msg'));
                    break;
                case 'topics':	
                    opt = { uuid: uuid, content: msg_content, members: members, image:upload_images, 't': new Date().getTime() };
                    loadContent.publish('topics', opt, $('#topic_msg'));
                    break;
                case 'polls':
                    var option = loadContent.polls_item();
                    if (option.length < 2) { LWORK.msgbox.show("集体决策不能少于两个选项！", 1, 2000); return false; }
                    opt = { uuid: uuid, type: 'single', content: msg_content, members: members, image:upload_images,  options: option, 't': new Date().getTime() };
                    loadContent.publish('polls', opt, $('#polls_msg'));
                    break;
                case 'questions':
                    var description = target.find('.description_input').val();
                    var tags = target.find('.ask_tag').val();
                    if ('' === msg_content || msg_content == '问题') return false;
                    if (description === '详细描述') { description = ''; }
                    if ('打个标签便于今后查找，可以设置5个标签，空格分开' == tags) tags = '';
                    opt = { uuid: uuid, title: msg_content, tags: tags, content: description, 't': new Date().getTime() };
                    loadContent.publish('questions', opt, $('#questions_msg'));
                    target.find('.ask_tag').val('标签：最多5个标签，用空格');
                    target.find('.description_input').val('详细描述');
                    target.find('.description_input').searchInput({
                        defalutText: '详细描述'
                    });
                    target.find('.ask_tag').searchInput({
                        defalutText: '打个标签便于今后查找，可以设置5个标签，空格分开'
                    });
                    break;
                default:
			    	break;
            }
        }
        return false;
    },
    publish: function (type, opt, container) {
        var target = loadContent.target;
       		target.find('.lwork_mes').focus().val('');
			api.content.publish(type, opt, function (data) {
		var msg ={
			content: opt['content'],
			entity_id: data['entity_id'],
			from: uuid,
            owner_id: uuid,
			image: opt['image'],
			replies: 0,
			traces:0,
			timestamp: data['timestamp'],
			file_id: opt['file_id'],
			file_length: opt['file_size'],
			name: opt['file_name'],
			title: opt['title'],
			finished_time: opt['finished_time'],
			options: opt['options'],
			status: 'not_voted',
			attachment: opt['attachment'], 
			attachment_name: opt['attachment_name'],
            create_time:data['timestamp']
		} 
		var html = (type != 'documents' ? html =  loadContent.createContent(msg, type, 'owned' , 'owned', container.attr('id'), 'none') : '<ul>' + loadContent.create_sharefile(msg) + '</ul>');
			container.prepend(html);
            container.find('dl').eq(0).slideDown('slow', function () {
				if(type == 'tasks'){
				   loadContent.sendMessage_task(opt['members'], opt['content']);
				}else{
				   LWORK.msgbox.show("发布成功！", 4, 1000);
				}
				upload_images ={'target':'', 'upload_images_url': '', 'attachment_name':''};
				container.find('.nocontent').hide();
                if ($('#polls_option').length > 0) {
					$('#polls_option').find('img').attr({'src' : '/images/update_pic.png' , 'source':''});
					$('#polls_option').find('input[type=file]').val('');
                    $('#polls_option').find('input[type=text]').each(function (i) {
                        if (i >= 3) {
                            $(this).parent().html('').remove();
                        } else {
                            var text = '选项' + String.fromCharCode(65 + i);			
                            $(this).val(text);
                            $(this).searchInput({
                                defalutText: text
                            });
                        }

                    });
                }
            });
			$('.uploadtip').html('').remove();			
            loadContent.bindMsgRecycler(container.attr('id'));
			loadContent.bindloadImage();
            loadContent.bindMsgHandlers();
		
        });
    },
	sendMessage_task: function(members, content){
		var me = '';
		var offline_content = '';
		var sendphone = new Array();
		var offline_members = '';
		var name_num = 0;

		for(var i=0; i < members.length; i++){
		  me = employer_status[loadContent.employstatus_sub(members[i])];
          if(me){
		   if(me['status'] === 'offline'){	
			 if('' != me['phone']){
		        sendphone.push({'phone':me['phone'], 'name':me['name']});
			 }else{
				'' == offline_members ?   offline_members  = me['name'] : offline_members  += '、' + me['name'] ;
				name_num ++ ;
			 } 
		   }
		  }else{
			  var members_sub = departmentArray[members[i]];
			  for(var key in members_sub['members']){
				   me = employer_status[loadContent.employstatus_sub(members_sub['members'][key])];
				 	 if(me['status'] === 'offline'){						 
						 if('' != me['phone']){			
						    sendphone.push({'phone':me['phone'], 'name':me['name']});
						 }else{							
						    if(name_num < 4){
						       '' === offline_members ? offline_members  = me['name'] : offline_members  += '、' + me['name'] ;
							   name_num ++
							 }
						 }						  
					 } 
			  }			  
		  }
		}
		if('' !== offline_members) offline_members = offline_members + '等没有登记手机号，不能向其发送！';	   
		if(sendphone.length > 0){
			var dialog = art.dialog({
				title: '短信提醒',
				content: '是否需要短信提醒不在线同事查收这条任务？<br/>' + offline_members ,
				width: '300px',
				button: [{
				  name: '提醒',
				  callback: function () {
					   loadContent.doSendShortMsg(sendphone ,'工作协同：' + content );
					},
					focus: true
				},{
				  name: '取消'
				}]
			});	
		}
		
	},
    bindMsgHandlers: function(){
        loadContent.bind('comment', loadContent.commentmes, 'class');
        loadContent.bind('invitecolleagues', loadContent.invitecolleagues, 'class');
        loadContent.bind('taskstatus', loadContent.taskstatus, 'class');
        loadContent.bind('pollsBtn', loadContent.pollstatus, 'class');
        loadContent.bind('results', loadContent.pollsresult, 'class');
        loadContent.bind('trace', loadContent.loadtrace, 'class');
        loadContent.bind('setFocus', loadContent.setFocus, 'class');
        loadContent.bind('cancelFocus', loadContent.cancelFocus, 'class');
        loadContent.bind('add_new_tag', loadContent.editTag, 'class');
        loadContent.bind('edit_focus_tag',loadContent.editTag, 'class');
        loadContent.bind('filter_tag', loadContent.filterTag, 'class');
        loadContent.bind('recycle_msg_btn', loadContent.deleteMsg, 'class');
        loadContent.bind('gotonetwork', loadContent.gotonetwork, 'class');	
		loadContent.contentmemberdetail();
		loadContent.bind_images_scaling();
    },
	bindloadImage: function(){
		$('.pagecontent_img img').LoadImage(true, 100,100,'/images/loading.gif');		
	    $('.poll_img img').LoadImage(true, 60,60,'/images/loading.gif');	
	},
	bind_images_scaling: function(){
		$('.pagecontent_img img , .poll_img img').bind('click',function(){
			var _this = $(this);			
			var url = _this.attr('source');
			    url = loadContent.getpicphoto(url, 'B');
		    _this.parent().hide().next().show().find('img').attr('src' ,url);			
			_this.parent().next().show().find('img').LoadImage(true, 480,500,'/images/loading.gif');
		   return false;
		 })
		 
		$('.bigimag_content').bind('click',function(){
			var _this = $(this);
		    _this.parent().hide().prev().show();
		   return false;
		 })
		 $('.lwork_slideup').click(function(){
		   $(this).parent().next().click();	 
		})
	},
    bindMsgRecycler: function(container){
        $('#' + container).find('.msg_item').each(function(){
            $(this).mouseover(function(){$(this).find('.recycle_msg_btn').css("display", "inline");});
            $(this).mouseleave(function(){$(this).find('.recycle_msg_btn').css("display", "none");});
        });
    },
    createGeneralConfirm: function(touch, question, supllement, cb){
        var hide = function () {
        if( $('#floattips').find('.gen_confirm').length>0)
                totips.hidetips();
            return false;
        }
        if( $('#floattips').find('.gen_confirm').length>0){return false;}
        var html = '<div class="gen_confirm">';
	    $('#floattips').find('.tipcontent').remove();
        html += '<div class="gen_confirm_question">' + question + '</div>';
        html += '<div class="gen_confirm_supllement">' + supllement + '</div>';
        html += '<div class="gen_confirm_btns"><a href="###" class="gen_confirm_yes">确定</a><a href="###" class="gen_confirm_no">取消</a></div>';
        html += '</div>';
        totips.showtip(touch, html, 25, 90);
        ifNotInnerClick(['gen_confirm', 'gen_confirm_question', 'gen_confirm_supllement', 
                        'gen_confirm_btns','gen_confirm_yes', 'gen_confirm_no'], function(releaseFunc){hide();if (releaseFunc){releaseFunc();}});
        $('.gen_confirm').find('.del').unbind('click').bind('click', hide);
        $('.gen_confirm').find('.gen_confirm_no').unbind('click').bind('click', hide);
        $('.gen_confirm').find('.gen_confirm_yes').unbind('click').bind('click', function(){
            if (cb){cb();}
            hide();
        });
        return false;
    },
    createTagsMgtDom: function(){
        var no_tag_tip = '<div class="no_tag_tip">给你的关注加个标签吧，可以更方便查看关注哦！</div>';
        var tagsStatistics = loadContent.myFocus.getTagsStatistics();
        $('.focus_num').text(tagsStatistics["allFocuses"]);
        if(tagsStatistics["allFocuses"] === 0){
            $('.tag_mgt').hide();
            return false;
        }
        $('.tag_mgt').show();
        if (tagsStatistics["allFocuses"] === tagsStatistics["untagedFocuses"]){
            $('.tag_mgt').html('<div class="no_tag_tip">给你的关注加个标签吧，可以更方便查看关注哦！</div>');
            loadContent.displaySelectedFocuses("allFocuses");
            loadContent.curTag = "allFocues";
        }else{
            $('.tag_mgt').html('<ul class="menu tags_list"></ul><div class="tag_mgt_btn_ragion"><a id="tag_mgt_btn" curMode="view" href="###" class="viewing">管理标签</a> </div>');
            $('.tags_list').append(loadContent.createTagTab("allFocuses", tagsStatistics["allFocuses"]));
            $('.tags_list').append(loadContent.createTagTab("untagedFocuses", tagsStatistics["untagedFocuses"]));
            for (t in tagsStatistics){
                if ((t != "allFocuses") && (t != "untagedFocuses")){
                    $('.tags_list').append(loadContent.createTagTab(t, tagsStatistics[t]));
                }
            }
            loadContent.bind('tag_tab', loadContent.selectFocusByTag, 'class');
            loadContent.bind('tag_mgt_btn', loadContent.mngFocusTags, 'id');
        }
        return false;
    },
    createFocusMsgDom: function(focusData){
        var html = "", itemHtml = "", cancelFocusBtnHtml = "";
        var owner, content, entity, entityType;
        var msg = focusData;
        for (var i = 0; i < msg.length; i++) {
            entity = msg[i].content;
            entityType = msg[i].type;               
            itemHtml =  loadContent.createContent(entity, entityType, 'none' , 'all', 'focus_msg', 'block');
            html += loadContent.insertFocusTagRegion(itemHtml, msg[i]["timestamp"], msg[i].type, entity['entity_id'], msg[i]["tags"]); 
        }
        $('#focus_msg').html(html);
		loadContent.getdelete_name($('#focus_msg'));
        loadContent.bindMsgHandlers();
		loadContent.bindloadImage();
    },
    createTagInputer: function(){
        return '<span class="tag_inputer" style="display:none;"><input class="input_tag_txt"></input><a href="###" class="input_tag_yes">确定</a><a href="###" class="input_tag_no">取消</a></span>';
    },
    createFocusBtn: function(type, msgid){
        if ( type === 'tasks' || type === 'topics'){
            if (loadContent.myFocus.isMsgIn(type, msgid)){
                return '<a href="###" type="' + type + '"  msgid="' + msgid + '"  titile="取消关注" class="cancelFocus">取消关注</a>';
            }else{
                return '<a href="###" type="' + type + '"  msgid="' + msgid + '"  titile="关注" class="setFocus">关注</a>';
            }
        }else{
            return "";
        }
    },
    createTagTab: function(tag, count){
        var tagTxt, tagType, tagEditable;
        var html = "";
        tag === "allFocuses" ? (tagTxt = "全部", tagType = "reservedTag", tagEditable = "") : (tag === "untagedFocuses" ? (tagTxt = "未加标签", tagType = "reservedTag", tagEditable = "") : (tagTxt = tag, tagType = "specifiedTag", tagEditable = " tagEditable"));
        var tagView = '<span class="tag_view" style="display:inline;"><span class="tag_name">' + tagTxt + '</span><span class="tag_count">(' + count + ')</span></span>';
        var tagEditor = '<span class="tag_editor" style="display:none;"><a class="tag_batch_edit" href="###"><span class="tag_name">' + tagTxt + '</span><span class="tag_count">(' + count + ')</span></a><a class="tag_batch_delete"></a></span>';
        return '<li class="tag_tab ' + tagEditable + '"' +' id="' + tag + '" tagType="' + tagType + '" href="###">' + tagView + tagEditor + loadContent.createTagInputer() + '</li>';   
    },
    insertFocusTagRegion: function(itemHtml, focusTime, msg_type, msg_id, tags){
        var tag = (tags.length > 0) ? tags[0] : "";
        var tag_html = '<span class="focus_tag_panel" curTag="' + tag + '"><a href="###" class="tag_btn ' + (tag === "" ? "add_new_tag" : "filter_tag") + '">' + (tag === "" ? "+加标签" : tag) + '</a>' + '<a href="###" class="edit_focus_tag" style="display:' + (tag === "" ? "none;":"inline;") + '"></a></span>';
        var txt = '<dd class="focus_tag_region" msgtype="' + msg_type + '" msgid="' + msg_id + '" tag="' + tag + '">' + '标签：' + loadContent.createTagInputer() + tag_html + '<span class="focus_time_txt">关注：' + focusTime + '</span></dd>';
        return itemHtml.replace('<dd class="pagefoot">', txt + '<dd class="pagefoot">');
    },
    updateTag2Msg: function(old_Tag, new_Tag){
        var oldTag = (old_Tag === "") ? "untagedFocuses" : old_Tag;
        var newTag = (new_Tag === "") ? "untagedFocuses" : new_Tag;
        var tagsStatistics = loadContent.myFocus.getTagsStatistics();

        loadContent.createTagsMgtDom();
        if (tagsStatistics[oldTag] > 0){
            $('.tag_mgt').find('#' + oldTag).click();
        }else{
            $('.tag_mgt').find('#' + newTag).click();
        }
        return false;
    },
    checkTagInput: function(Obj){
        var str = Obj.val();
        if (str.length > 0){
            if ((str[str.length - 1] === " ") || str.length > 12){
                str = str.substr(0, str.length - 1);
            }
            Obj.val(str);
        }
        return false;
    },
    editTag: function(){
        var tagRegion = $(this).parent().parent();
        var type = tagRegion.attr('msgtype');
        var msgid = tagRegion.attr('msgid');
        var oldTag = tagRegion.attr('tag');
        $('#focus_msg').find('.curEditing').each(function(){
            $(this).parent().parent().find('.input_tag_no').click();
            $(this).removeClass('curEditing')
        });
        $(this).addClass('curEditing');
        tagRegion.find('.focus_tag_panel').css("display", "none");
        tagRegion.find('.tag_inputer').css("display", "inline");
        tagRegion.find('.input_tag_txt').val(oldTag).focus();
        tagRegion.find('.input_tag_yes').bind('click', function(){
            var tagTxt = tagRegion.find('.input_tag_txt').val();
            if (tagTxt != oldTag){
                api.focus.setFocus(uuid, [{"type":type, "entity_id":msgid, "tags":(tagTxt === "" ? [] : [tagTxt])}], function(){
                    loadContent.myFocus.setFocus(type, msgid, (tagTxt === "" ? [] : [tagTxt]));
                    var tagBtn = tagRegion.find('.tag_btn');
                    if (tagTxt != ""){
                        tagBtn.removeClass('add_new_tag').addClass('filter_tag').text(tagTxt);
                        tagRegion.find('.edit_focus_tag').css('display', 'inline');
                    }
                    else{
                        tagBtn.addClass('add_new_tag').removeClass('filter_tag').text('+加标签');
                        tagRegion.find('.edit_focus_tag').css('display', 'none');
                    }
                    tagRegion.attr('tag', tagTxt);
                    loadContent.updateTag2Msg(oldTag, tagTxt);
                    loadContent.bindMsgHandlers();
                });
            }
            tagRegion.find('.focus_tag_panel').css("display", "inline");
            tagRegion.find('.tag_inputer').css("display", "none");
            return false;
        });
        tagRegion.find('.input_tag_no').bind('click', function(){
            tagRegion.find('.input_tag_txt').val(oldTag);
            tagRegion.find('.focus_tag_panel').css("display", "inline");
            tagRegion.find('.tag_inputer').css("display", "none");
            return false;
        });
        tagRegion.find('.input_tag_txt').bind('keyup', function(){
            loadContent.checkTagInput($(this));
            return false;
        });
        return false;
    },
    filterTag: function(){
        var tagRegion = $(this).parent().parent();
        var tag = tagRegion.attr('tag');
        var innertag = (tag === "" ? "untagedFocuses" : tag);
        $('.tags_list').find('#' + innertag).click();
        $('#focus_msg').find('.curEditing').each(function(){
            $(this).parent().parent().find('.input_tag_no').click();
            $(this).removeClass('curEditing')
        });
        return false;
    },
    batchDeleteTag: function(tagTab){
        loadContent.createGeneralConfirm(tagTab, '你确定要删除当前标签吗?', '删除标签不会把具有该标签的消息从关注中删除。', function(){
            var oldTag = tagTab.attr('id');
            loadContent.batchModifyTag(oldTag, "", function(){
                var tagsStatistics = loadContent.myFocus.getTagsStatistics();
                $('#untagedFocuses').find('.tag_count').text('(' + tagsStatistics["untagedFocuses"].toString() + ')');
                tagTab.remove();
                $('#untagedFocuses').click();
            });
        });
        return false;
    },
    batchModifyTag: function(oldTag, newTag, cb){
        var items = new Array();
        var msgs = loadContent.myFocus.getMsgsWithTag(oldTag);
        for (var i = 0; i < msgs.length; i++){
            var tags = loadContent.myFocus.getTags(msgs[i]["type"], msgs[i]["msgid"]);
            var oldTagIndex = tags.indexOf(oldTag);
            if (newTag == ""){
                tags.splice(oldTagIndex, 1);
            }else{
                tags[oldTagIndex] = newTag;
            }
            items.push({"type":msgs[i]["type"], "entity_id":msgs[i]["msgid"], "tags":tags});
        }

        api.focus.setFocus(uuid, items, function(){
            loadContent.myFocus.batchModifyTag(oldTag, newTag);
            $('#focus_msg').find('.focus_tag_region').each(function(){
                if ($(this).attr('tag') === oldTag){
                    $(this).find('.focus_tag_panel').attr('curTag', newTag);
                    var tagBtn = $(this).find('.tag_btn').text(newTag);
                    if (newTag != ""){
                        tagBtn.removeClass('add_new_tag').addClass('filter_tag').text(newTag);
                        $(this).find('.edit_focus_tag').css('display', 'inline');
                    }
                    else{
                        tagBtn.addClass('add_new_tag').removeClass('filter_tag').text('+加标签');
                        $(this).find('.edit_focus_tag').css('display', 'none');
                    }
                    $(this).attr('tag', newTag);
                }
            });
            loadContent.bindMsgHandlers();
            cb();
        });
        return false;
    },
    toMaintainTags: function(){
        var Obj = $('.tags_list');
        Obj.find('.tagEditable').find('.tag_view').css('display', 'none');
        Obj.find('.tagEditable').find('.tag_editor').css('display', 'inline');
        Obj.find('.tagEditable').find('.tag_inputer').css('display', 'none');
        Obj.find('.tagEditable').find('.tag_batch_edit').unbind('click').bind('click', function(){
            var preEditingTag = $('.tags_list').find('.curEditingTag');
            if (preEditingTag.length > 0){
                preEditingTag.find('.input_tag_no').click();
                preEditingTag.removeClass('curEditingTag');
            }
            var curItem = $(this).parent().parent();
            curItem.addClass('curEditingTag');
            $(this).parent().css('display', 'none');
            var oldTag = curItem.attr('id');
            var inputer = curItem.find('.tag_inputer');
            inputer.css('display', 'inline');
            inputer.find('.input_tag_txt').val(oldTag).focus();         
            inputer.find('.input_tag_txt').unbind('keyup').bind('keyup', function(){
                loadContent.checkTagInput($(this));
                return false;
            });
            inputer.find('.input_tag_yes').unbind('click').bind('click', function(){
                var newTag = $(this).parent().find('.input_tag_txt').val();
                if (newTag === ""){
                    LWORK.msgbox.show("标签不能为空！", 5, 1000);
                }else{
                    if (newTag != oldTag){
                        loadContent.batchModifyTag(oldTag, newTag, function(){
                            curItem.find('.tag_name').text(newTag);
                            curItem.attr('id', newTag);
                            curItem.click();
                            return false;
                        });
                    }
                    $(this).parent().parent().removeClass('curEditingTag');
                    $(this).parent().css('display', 'none');
                    $(this).parent().parent().find('.tag_editor').css('display', 'inline');
                }
                return false;
            });
            inputer.find('.input_tag_no').unbind('click').bind('click', function(){
                $(this).parent().parent().removeClass('curEditingTag');
                $(this).parent().css('display', 'none');
                $(this).parent().parent().find('.tag_editor').css('display', 'inline');
                return false;
            });

            return false;
        });
        Obj.find('.tagEditable').find('.tag_batch_delete').unbind('click').bind('click', function(){
            loadContent.batchDeleteTag($(this).parent().parent());
            return false;
        });

        return false;
    },
    toViewTags: function(){
        var Obj = $('.tags_list');
        Obj.find('.tag_view').css('display', 'inline');
        Obj.find('.tag_editor').css('display', 'none');
        Obj.find('.tag_inputer').css('display', 'none');
        return false;
    },
    mngFocusTags: function()
    {
        var Obj = $(this);
        var tagsRegion = Obj.parent().parent().find('tags_list');
        var oldMode = Obj.attr('curMode')
        switch (oldMode){
            case "view":
                loadContent.toMaintainTags();
                Obj.removeClass("viewing").addClass("maintaining");
                Obj.attr('curMode', "maintain").text("退出管理");
                break;
            case "maintain":
                loadContent.toViewTags();
                Obj.removeClass("maintaining").addClass("viewing");
                Obj.attr('curMode', "view").text("管理标签");
                break;
            default:
                break;
        }
        return false;
    },
    selectFocusByTag: function(){
        var Obj = $(this);
        var tag = Obj.attr('id');
        loadContent.curTag = tag;
        Obj.parent().find('.curent').removeClass('curent');
        Obj.addClass('curent');
        loadContent.displaySelectedFocuses(tag);
    },
    displaySelectedFocuses: function(tag){
        var msgs = loadContent.myFocus.getMsgsWithTag(tag);
        $('#focus_msg').find('dl').each(function(){$(this).hide();})
        for (var i = 0; i < msgs.length; i++){
            $('#focus_msg').find('dl').each(function(){
                if (($(this).attr("msg_type") == msgs[i]["type"]) && ($(this).attr("task_id") == parseInt(msgs[i]["msgid"]))){
                    $(this).show();
                }
            })
        }
        $('#focus_msg').find('.curEditing').each(function(){
            $(this).parent().parent().find('.input_tag_no').click();
            $(this).removeClass('curEditing')
        });
        return false;
    },
    fetchFocusData: function(cb){
        api.content.load_msg('focus', uuid.toString(), 'none', 'all', '' , '' , function (data) {
            loadContent.myFocus.init(data['focus']);
            if (cb){
                cb(data['focus']);
            }
        });
    },
    deleteMsg: function(){
        var msg_item = $(this).parent().parent();
        var type = msg_item.attr("msg_type");
        var msgid = msg_item.attr("task_id");
        var ownership = msg_item.attr("ownership");
        if (loadContent.myFocus.isMsgIn(type, msgid)){
            LWORK.msgbox.show("删除之前请先取消关注！", 1, 1000);
        }else{
            api.content.del(uuid, [{"type":type, "ownership":ownership, "entity_id":msgid}], function(){
                LWORK.msgbox.show("删除成功！", 4, 1000);
                msg_item.remove();
            });
        }
    },
    recoverMsg: function(){
        var msg_item = $(this).parent().parent();
        var type = msg_item.attr("msg_type");
        var msgid = msg_item.attr("task_id");
        var ownership = msg_item.attr("ownership");
        api.content.recover(uuid, [{"type":type, "ownership":ownership, "entity_id":msgid}], function(){
            LWORK.msgbox.show("已恢复！", 4, 1000);
			type === 'documents' ? msg_item.parent().remove() : msg_item.html('').remove();					
            if ($('#recycled_msg').find('.msg_item').length === 0 && $('#recycled_msg').find('.hover').length === 0  ){
                $('#recycled_msg').html('<div class="nocontent">您的回收站已清空</div>');
            }			
        });
        return false;
    },
    removeMsg: function(){
        var msg_item = $(this).parent().parent();
        loadContent.createGeneralConfirm($(this), '你确认要永久删除这条消息吗？', '永久删除后将无法查看该消息。', function(){
            var type = msg_item.attr("msg_type");
            var msgid = msg_item.attr("task_id");
            var ownership = msg_item.attr("ownership");
            api.content.remove(uuid, [{"type":type, "ownership":ownership, "entity_id":msgid}], function(){
                LWORK.msgbox.show("已永久删除！", 4, 1000);
				console.log('删除')
				  type === 'documents' ? msg_item.parent().html('').remove() : msg_item.html('').remove();				  				
                if ($('#recycled_msg').find('.msg_item').length === 0 && $('#recycled_msg').find('.hover').length === 0 ){
                    $('#recycled_msg').html('<div class="nocontent">您的回收站已清空</div>');
                }
            });
        });
        return false;
    },
    removeAllMsgs: function(){
	
        var items = new Array();		
        $('#recycled_msg').find('.msg_item').each(function(){
            var type = $(this).attr("msg_type");
            var msgid = $(this).attr("task_id");
            var ownership = $(this).attr("ownership");
            items.push({"type":type, "ownership":ownership, "entity_id":msgid});
        });	
        $('#recycled_msg').find('.uname').each(function(){
            var type = $(this).attr("msg_type");
            var msgid = $(this).attr("task_id");
            var ownership = $(this).attr("ownership");
            items.push({"type":type, "ownership":ownership, "entity_id":msgid});
        });	
	
        if (items.length > 0){
            loadContent.createGeneralConfirm($(this), '你确认要清空回收站吗？', '清空回收站将永久删除这些消息。', function(){
				
                api.content.remove(uuid, items, function(){
                    LWORK.msgbox.show("所有消息已永久删除！", 4, 1000);
                    $('#recycled_msg').html('<div class="nocontent">您的回收站已清空</div>');
                });
            });
        }
        return false;
    },
    loadrecycle: function(mode, type, status, continer, flag) {
        $('#loading').show();
        api.content.load_msg(mode, uuid.toString(), type, status, '', '', function (data) {
            var msg = data[mode];
            //var msg = get_test_recycle_data();
            var owner, content, entity;
            var html = "";
            if (msg.length > 0) {
                $('#' + continer).find('.nocontent').hide();
                for (var i = 0; i < msg.length; i++) {
					 entity = msg[i]["content"];
					if(msg[i]["type"] !== 'documents'){               				
                      html +=  loadContent.createContent(entity, msg[i]["type"], type , status, continer, 'block');
					}else{
					  html += loadContent.create_sharefile(entity);	
					}
                }				
                $('#loading').hide();
                $('#' + continer).html(html);
				loadContent.getdelete_name($('#' + continer));
                $('#' + continer).find('.pagefoot').each(function(){
                    $(this).find('a').remove();
                    $(this).append('<a href="###" class="recoverMsg">恢復</a><a href="###" class="removeMsg">永久刪除</a>');
                });
				
                $('#' + continer).find('.opts').each(function(){
                    $(this).find('a').remove();
                    $(this).append('<a href="###" class="recoverMsg">恢復</a><a href="###" class="removeMsg">永久刪除</a>');
                });
                loadContent.bind('recoverMsg', loadContent.recoverMsg, 'class');
                loadContent.bind('removeMsg', loadContent.removeMsg, 'class');
                loadContent.bindMsgHandlers();
				loadContent.bindloadImage();
			    loadContent.bind('delete_all', loadContent.removeAllMsgs, 'id');		
            } else {
                $('#loading').hide();
                $('#' + continer).html('<div class="nocontent">您的回收站已清空</div>');
            }
     
        }, function () { LWORK.msgbox.show("服务器繁忙，请稍后再试！", 1, 2000); $('#loading').hide(); });
        return false; 
    },
    loadfocus: function(mode, type, status, continer, flag) {
        $('#loading').show();
        loadContent.fetchFocusData(function(focusData){
            if (focusData.length > 0) {
                $('#' + continer).find('.nocontent').remove(); 
                loadContent.createFocusMsgDom(focusData);
            } 
            else {
                $('#' + continer).html('<div class="nocontent">你还没有关注任何微博和任务呢！ 对于重要的微博或者任务，赶紧关注一下哦！</div>');
            }
            loadContent.createTagsMgtDom();
            $('.tag_mgt').find('#allFocuses').click();
            $('#loading').hide();
            return false;
        }); 
    },
   getdelete_name: function(obj){
	   var employ_uuids = '';
	     obj.find('.delete_uuid').each(function(){
		 var employer = $(this).attr('employer_uuid');
		 '' === employ_uuids ?   employ_uuids = employer :  employ_uuids += ',' + employer;		  	
		})
		$.getJSON('/lwork/auth/names?uuids=' + employ_uuids, function(data) {
			var con = data['results'];
			var len = con.length ;
			for(var i = 0; i< len; i++){
			  $('.delete_' + con[i].uuid).text(con[i].name);
			  $('.comt_name_' + con[i].uuid).attr('name', con[i].name + con[i].eid);
			}
		});		
   },	
    loadmsg: function (mode, type, status, continer, page_index , flag , callback) {
	   $('<div class="loadmore_msg" style="text-align:center; padding:10px ;"><img src = "/images/uploading.gif" style="vertical-align:bottom;"/><span>正在加载...</span></div>').appendTo($('#' + continer));	
       api.content.load_msg(mode, uuid, type, status, page_index, '20' , function (data) {
            var msg = data[mode];
            var owner, content;
            var html = "";
			var unread = '<div class="readed_hr"><span class="readed_line"></span><span class="readed_content"> 之前看到这里了哟~ </span><span class="readed_line"></span></div>';
            if (msg.length > 0) {	
		        $('#' + continer).find('.nocontent').hide();
				if( mode != 'documents'){
					for (var i = 0; i < msg.length; i++) 
					  html += loadContent.createContent(msg[i], mode, type , status, continer, 'block');		
					  if(flag && mode !== 'questions' ){
						if(flag === 1){
						  $('#' + continer).prepend(html + unread);
						  $('.dynamic').find('.' + mode).find('.new_msg_num').text(0).parent().hide();
						  loadContent.dynamic_itemdisplay(mode);
						  $('#' + mode).find('.nuread_msg').fadeOut();
					   }else{	
						 $('#' + continer).append(html); 
						 current_page_index[continer] = page_index ;
						 loadContent.getdelete_name($('#' + continer));		
					   }
					  }else{
						 $('#' + continer).html(html); 
					  }	
				 }else{					 
					html = '<ul>' 
					for (var i = 0; i < msg.length; i++) {
						 html += loadContent.create_sharefile(msg[i]);
					}
					html += '</ul>';		
				   if(flag){
					 flag === 1 ? $('#' + continer).prepend(html + unread) :( $('#' + continer).append(html) ,  current_page_index[continer] = page_index );								  
				    }else{
					 $('#' + continer).html(html);  
				    }				
					loadContent.fileshow_handle();													 
				 }
				if(callback) callback();
				$('#' + continer).find('.loadmore_msg').remove();	
                $('#' + continer).find('.readed_hr').html('').remove();
				allow_loading = 0;
                loadContent.bindMsgRecycler(continer);
				loadContent.bindloadImage();
                loadContent.bindMsgHandlers();		
            } else {
			  $('#' + continer).find('.loadmore_msg').remove();
			   allow_loading = 0;
			  if(flag){
				if(flag === 2){
				 current_page_index[continer] = -1 ;
			   }						  
			  }else{
                 $('#loading').hide();
                 $('#' + continer).html('<div class="nocontent">您当前没有任何内容</div>');
				 if(callback) callback();
			  }	
            }
        }, function () { LWORK.msgbox.show("服务器繁忙，请稍后再试！", 1, 2000); $('#loading').hide(); });
        return false;
    },
    loadnewcomt: function (mode, continer) {
        api.content.loadnewcomt(mode, uuid.toString(), function (data) {			
            var msg = data['replies'], owner, html = "", content, delete_css = "" ,comt_name_uuid = '';				
            if (msg.length > 0) {
                for(var i = 0; i < msg.length; i++) {
                    var reply = msg[i]['reply'] , topic = msg[i]['topic'] , dialog="";
					var reply_content = reply.content , delete_css = '';
					var employer, delete_uuid = ''; 
					if(typeof(loadContent.employstatus_sub(reply.from)) !== 'undefined'){
					   employer =employer_status[loadContent.employstatus_sub(reply.from)];
					   owner = employer['name'];
					   photo = employer['photo'];
					   name_employid = employer['name_employid'];
					}else{
					  owner = '未知';
					  delete_css = 'delete_uuid';		  
					  photo = '/images/photo/defalt_photo.gif';
					  delete_uuid = 'delete_' + reply.from;
					  name_employid = '未知'
					  comt_name_uuid = 'comt_name_' + reply.from;
					}
					if(reply.to && '-1' !== (reply.to).toString() && uuid !== (reply.to).toString()){
			    	  dialog = '<a href="###" task_id = "'+ topic['entity_id'] +'"  findex="' + reply.findex + '"  mode="'+ mode +'" class="sub_dialog" style="float:right;padding-right:10px;">查看对话</a>';
					}					
					reply_content = reply_content.replace(':', ' ');
					reply_content = 	loadContent.format_message_content(reply_content, 'linkuser');						
					html += ['<dl id="'+ topic['entity_id'] +' + newcomt_content'+ i +'sub">',
					      '<dt class="sub_dt"><img src="'+ photo +'" width="48" height="48"/></dt>',
				 		  '<dd class="sub_dd"><span employer_uuid="'+ reply.from +'" class="lanucher '+ delete_css +' '+ delete_uuid +'">' + owner + '</span>：' + reply_content,
						  '<div class="float_corner float_corner_top"> <span class="corner corner_1" style="color:#FBFBFB">◆</span> <span class="corner corner_2" style="color:#E1E4E5">◆</span> </div></dd>',
						 ].join("");
					html += loadContent.createContent(topic, mode, 'owned' , status, continer + i, 'block');
                    html += '<dd class="sub_newcomt"><span class="gray">' + reply.timestamp + '</span><a href="###" findex = "'+ reply.findex +'" name="'+ name_employid +'" mode="'+mode+'" sendid="' +topic['entity_id'] +'" name="" class="sub_newcomment '+ comt_name_uuid +'">回复 </a>'+ dialog +'</dd>'
				    html += '</dl>'
				    loadContent.target.find('.' + topic['entity_id']).find('.unreadcomt').text(topic.replies);										
                }				
				
                $('#' + continer).find('.newcomt_wrap').html(html);		
				 loadContent.getdelete_name($('#' + continer).find('.newcomt_wrap'));		
                $('#' + mode).find('.nuread_comt').fadeOut();
                $('.dynamic').find('.' + mode).find('.new_msg_comt').text(0).parent().hide();
                loadContent.dynamic_itemdisplay(mode);
				loadContent.bind('sub_newcomment', loadContent.new_commentmes, 'class');
				loadContent.bind('sub_dialog', loadContent.load_dialog, 'class');
                loadContent.bindMsgHandlers();
				loadContent.bindloadImage();
            } else {
                $('#' + continer).find('.newcomt_wrap').html('<div class="nocontent">您当前没有新回复</div>');
                $('#' + mode).find('.nuread_comt').fadeOut();
            }
        });
    },		
    createContent: function (msg, mode, type, status, linkhref, display, flag ) {	
        var html = "", bt, appendhtml, f, txt, txt2;
		var employer , employer_uuid , owner , photo , delete_css = "", delete_uuid = '';	
		var delete_employ_uuids = '';
		    employer_uuid = msg['from'].toString();		
		var title = '';
		if(typeof(loadContent.employstatus_sub(msg['from'])) !== 'undefined'){	
		   employer =employer_status[loadContent.employstatus_sub(msg['from'])] ;
	       owner = employer['name'];
		   photo = employer['photo'];
		}else{
		  owner = '未知';
		  delete_css = 'delete_uuid';		  
		  photo = '/images/photo/defalt_photo.gif';
		  delete_uuid = 'delete_' + msg['from'];
		  title = '该员工已删除';
		}		
        mode === 'documents' ? txt = "分享" : txt = "邀请";
        mode === 'questions' ? txt2 = "回答" : txt2 = "回复";		
        var e = '<a class="trace"  mode="' + mode + '"  taskid ="' + msg['entity_id'] + '" link ="' + linkhref + '" href="###">动态(<span class = "unreadtrace">' + msg['traces']+ '</span>)</a>',
		    a = '<a href="###" mode="' + mode + '" link ="' + linkhref + '"  sendid ="' +  msg['entity_id'] + '" class="comment">' + txt2 + ' (<span class = "unreadcomt">' + msg['replies'] + '</span>)</a>',
		    b = '<a href="###" mode="' + mode + '"  link ="' + linkhref + '"  sendid ="' +  msg['entity_id'] + '"  titile="' + txt + '" class="invitecolleagues">' + txt + '</a>',			  
			g = '<a href="/lw_download.yaws?fid=' + msg['file_id'] + '" titile="文件下载" target="_blank" class="downloadfile">下载</a>',			  
		    c = '<a href="###" titile="标记完成" class="taskstatus">完成</a>',
            r = '<div class="recycle_item"><a href="###" class="recycle_msg_btn" style="display:none" title="删除此消息"></a></div>';
            focusBtn = loadContent.createFocusBtn(mode, msg['entity_id']);
        switch (mode) {
            case 'tasks':
                status === 'finished' ? (( employer_uuid === uuid) ? f = e + a : f = focusBtn + e + a)  : ( employer_uuid === uuid ? f = e + a + b + c : f = focusBtn + e + a + b );
                status === 'finished' ? r : r = '';
                bt = '工作';
                if (flag && flag === 1) f = e + a;
                break;
            case 'polls':
                bt = '投票';
                f = e + b;
                break;
            case 'questions':
                bt = '问答';
                f = a;
                r = '';
                break;
            default:
                bt = '微博';
                f = focusBtn + a + b;
                break;
        }
        msg['finished_time'] ? m = '<span class="gray">' + msg['timestamp'] + '</span>&nbsp;&nbsp;&nbsp;&nbsp;完成：<span class="fininshtime">' + msg['finished_time'] + ' </span>' : m = '<span class="gray">' + msg['timestamp'] + '</span>';
        msg['delete_time'] ? m += '&nbsp;&nbsp;&nbsp;&nbsp;删除：<span class="fininshtime">' + msg['delete_time'] + ' </span>' : m += '';
        html = ['<dl class="msg_item ' +  msg['entity_id'] + '" style="display:' + display + '" id="' +  msg['entity_id'] + linkhref + '" task_id="' +  msg['entity_id'] + '" msg_type="' + mode + '" ownership="' + (employer_uuid === uuid ? 'assign' : 'relate')+'">',
                '' + r + '',
				'<dd class="personal_icon"><img src ="' + photo + '" width="48" height="48"/></dd>', 
		        '' + loadContent.msgcontent(msg, owner, employer_uuid , delete_css, delete_uuid, title) + '',
		        '<dd class="pagefoot"><span class="msg_time">'+ bt +'：' + m + ' </span>' + f + '</dd><div class="tracewrap" style="display:none;">',
				'<div class="float_corner float_corner_top" style=""><span class="corner corner_1">◆</span> <span class="corner corner_2">◆</span></div>',
				'<div class="trace_content"></div></div>',
				'</dl>'].join("");
                return html;
    },
	gotonetwork: function(){
		 var _this = $(this);
		 var file_name = _this.parent().prev().find('span').eq(0).text();
		 var file_size = _this.attr('filesize') ? _this.attr('filesize') : '2000';
		 var url = _this.prev().attr('href');
		 var str = url.split('=');
	     var opt = {uuid:uuid, 'file_name':file_name, 'file_id':str[1], 'file_size': file_size, 'content':'', 'members':[], 't':new Date().getTime()}; 
         loadContent.publish('documents', opt, $('#file_share_container'));
		 LWORK.msgbox.show("已经将附件保存到网盘！", 4, 1000);		
		 _this.hide();
	},
    msgcontent: function (msg, owner, employer_uuid, delete_css ,delete_uuid, title) {
        var html = "", a, display, css, txt,
		 images = '',
	     img_dom='',
		 attachment = msg['attachment_name'] ? msg['attachment_name'] :'',
		 filetype =  '',
		 content =  loadContent.format_message_content(msg.content, 'linkuser'),	
		 attachment_dom  = '',
		 source_imag = '';
		if(msg['image']){			
			if(typeof(msg['image']) === 'object'){
				 if(msg['image']['upload_images_url'] !== ''){
					  images = loadContent.getpicphoto(msg['image']['upload_images_url'], 'S');
					  source_imag = msg['image']['upload_images_url'];
				 }
				 if(msg['image']['attachment_name'] !== ''){				 
				   var filetype = loadContent.filetype_handle(msg['image']['attachment_name']); 
				   var show_len = '',  size = '';
				   if(msg['image']['filesize']){
					      size = msg['image']['filesize'];
					      show_len = parseFloat(msg['image']['filesize']);
						  show_len = show_len / 1024;
					      show_len > 1024 ? show_len = (show_len / 1024).toFixed(2) + 'MB' : show_len = show_len.toFixed(2) + 'KB';
						  show_len = '<span style="padding-left:10px;">('+ show_len +')</span>';			   
				   }
				   attachment_dom = ['<div class="pagecontent_attachment"><div class="attachment_header">附件：</div>',
				                     '<div class="attachment_content"><div href="'+  msg['image']['attachment_url'] +'" class="attachment '+ filetype +'"><span>'+ msg['image']['attachment_name'] +'</span>'+ show_len +'</div>',
									 '<div class="download_attachment"><a class=""  target="_blank"  href="'+  msg['image']['attachment_url'] +'" >下载</a>',
									 '<a class="gotonetwork" filesize = "'+ size +'"  href="###" >转到网盘</a></a>',
									 '</div></div>'].join("");
				 }
			}else{
				if(msg['image'].indexOf('share;')>=0){
				  var str = msg['image'].split(';');			  
				  var filetype = loadContent.filetype_handle(str[1]);
				  attachment_dom = '<div class="pagecontent_attachment"><div class="attachment_header">通过网盘分享文件：</div><div class="attachment_content"><span href="'+  str[2] +'" class="attachment '+ filetype +'">'+ str[1] +'</span><div class="download_attachment"><a class=""  target="_blank"  href="'+  str[2] +'" >下载</a></div></div></div>';
				}else{
				  images = loadContent.getpicphoto(msg['image'], 'S');
				  source_imag = msg['image'];
				}
			}
		}
		var img_dom = '' === images? '' : '<div class="pagecontent_img"><img src ="'+images +'" source="'+ source_imag +'"/></div><div class="bigimages"><div class="select_map_btn"><a href="###" class="lwork_slideup">收起</a><a href="'+ source_imag +'" target="_blank" class="lwork_bingmap">查看原图</a></div><div class="bigimag_content"><img src =""/></div></div>';
        var opt_img ;
		if (msg['title']) {
            html = '<dd class="pagecontent"><span employer_uuid="' +employer_uuid +'" title="'+ title +'"  class="lanucher '+ delete_css +'  '+ delete_uuid +'">' + owner + '</span>：' + msg['title'] + '';
            if ('' !== content) 
               html += '<div class="ask_description">' + content + '</div>' + img_dom + attachment_dom;  
        } else {
            html = '<dd class="pagecontent"><span employer_uuid="'+employer_uuid+'" title="'+ title +'" class="lanucher '+ delete_css +' '+ delete_uuid +'">' + owner + '</span>：<pre> ' + content + '</pre>' + img_dom + attachment_dom;
        }				  	
        if (msg['options']) {
            var obj = msg['options'];
            for (var i = 0; i < obj.length; i++) {
                msg.status.value === obj[i].label ? a = '<input label ="' + obj[i].label + '" name="' + msg['entity_id'] + 'polls" type="radio" checked value="" />' : a = '<input label ="' + obj[i].label + '" name="' +  msg['entity_id'] + 'polls" type="radio" value="" />';
			    msg.status.status === 'voted' ? (css = 'disabledBtn', txt = '已投票') : (css = 'pollsBtn', txt = '投票');
                employer_uuid == uuid ? display = 'inline' : (msg.status.status === 'voted' ? display = 'inline' : display = 'none');
			    opt_img = loadContent.getpicphoto(obj[i]['image'], 'S');
                html += [
			      '<li>' + a + '<span class="pollsitem">' + obj[i].content + '</span>',
			      '<div class="poll_img"><img src="'+ opt_img +'" source = "'+ obj[i]['image'] +'"/></div><div class="bigimages"><div class="bigimag_content"><img src =""/></div></div>',
			      '<div class="vote_count ' + obj[i].label + '"><div class="bar bg"><div class="bar_inner bg2"></div></div><div class="number c_tx3"></div></div></li>'
			    ].join("");
            }
            html += ['</dd><dd class="vote_dd"><a class="' + css + '"  msg_id="' + msg['entity_id'] + '"  href="###">' + txt + '</a>',
				      '<a msg_id="' + msg['entity_id'] + '" class="results" style="display:' + display + ';" href="###">查看结果</a>'
					].join("");

        } else {
            html += '</dd>';
        }
        return html;
    },
	create_sharefile: function(msg){
		var show_len = parseFloat(msg['file_length']);
			sharer = employer_status[loadContent.employstatus_sub(msg['from'])].name;
			show_len = show_len / 1024;
		var openfile  = "";
		if (show_len > 1024) {
			show_len = (show_len / 1024).toFixed(2) + 'MB';
		} else {
			show_len = show_len.toFixed(2) + 'KB';
		}	
		var filetype = loadContent.filetype_handle(msg['name']);
		var ownership = (msg['from']).toString() === uuid ? 'assign' : 'relate'
				
//		if(filetype === 'jpg' || filetype === 'png' ){
//		     openfile =  '<a href="/lw_download.yaws?fid=' + msg.file_id + '" target="_blank" class="linkFile preview">预览</a>';
//	      }
//		
	    html = ['<li class="hover">',
		     '<i class="file_icon '+ filetype +'"></i>',
			 '<em class="uname"  task_id = "'+msg['entity_id']+'"  msg_type="documents" ownership="'+ ownership +'" ><a href="###" class="sharefilename">' + msg['name'] + '</a>',	
			 '<span class="opts">'+ openfile +'<a href="/lw_download.yaws?fid=' + msg.file_id + '" target="_blank" class="downloadFile">下载</a>',
			 '<a href="javascript:void(0);" class="linkFile sharefiles">分享</a><a href="javascript:void(0);" class="linkFile delfile">删除</a></span></em>',
			 '<span class="fsize file_gray"> ' + show_len + '</span>',			  
			 '<span class="fdate file_gray"> ' + msg.timestamp + '</span></li>'		  
			 ].join("");			 
	    return html;
	},
	filetype_handle: function(filename){
		var str = filename.split('.');
		return css = (str[str.length-1]).toLowerCase();	
	},	
	del_file: function(){
 		 var _this = $(this);
		 var msgid = _this.parent().parent().attr('task_id');
		 var ownership = _this.parent().parent().attr('ownership');
        loadContent.createGeneralConfirm($(this), '你确定要删除这个文件吗？', '文件删除后会造成你之前共享的同事不能下载该文件。', function(){
		   api.content.del(uuid, [{"type":'documents', "ownership":ownership, "entity_id":msgid.toString()}], function(){
				LWORK.msgbox.show("删除成功！", 4, 1000);
				_this.parent().parent().parent().html('').remove();
			});	     
        });
        return false;		
	},
	fileshow_handle : function(){
		$('.preview').click(function(){
			var url = $(this).next().attr('href');
			if( $('#previe_img').length > 0)
				$('#previe_img').remove();	
			$('body').append('<div id="previe_img"><img src="'+ url +'" /></div>');
			var content = document.getElementById('previe_img');
		})
	    loadContent.bind('sharefiles', loadContent.fileshare_handle, 'class');
	    loadContent.bind('delfile', loadContent.del_file, 'class');
	},
	fileshare_handle: function(){
		var _this = $(this);
		var url  = _this.prev().attr('href');
		var file_name = _this.parent().prev().text();
		var type = "topics"	;
		var contianer = $('#topic_msg');
		var html = ['<div class="share_top clearfix">',
		  '<ul class="share_menu clearfix">',
		  '<li class="totaskmenu share_menu_on" mode = "topics">分享到企业微博</li>',
		  '<li class="totaskmenu"  mode = "tasks">分享到工作协同</li>',
		  '</ul></div>',		  
		  '<div class="share_content"> <span class="remindSpan"><span class="countTxt"> 还能输入</span><span class="maxNum">300</span><span>个字</span></span>',
          '<textarea name="" cols=""  rows="1" class="lwork_mes" sendid=""></textarea>',
          '<a class="sendBtn" style="width:60px;" href="###">分享</a>',
          '<div class="seatips"></div>',
          '</div></div>'].join("");
	      totips.showtip(_this, html, 30 ,290, '' , 'share');	
		  var obj_link = $('#floattipsshare');
		  obj_link.find('.close').bind('click', function(){totips.hidetips('share')})
		  obj_link.find('.lwork_mes').focus().val('通过网盘分享文件，下载下来看看吧~ \n'); 
		  obj_link.find('.lwork_mes').membersearch({
			  target: obj_link
		  });
		  obj_link.find('.share_menu').find('li').click(function(){
			  $(this).addClass('share_menu_on').siblings().removeClass('share_menu_on');
			  type = $(this).attr('mode');
			  type == 'tasks' ?(contianer = $('#mysend_msg'), obj_link.find('.lwork_mes').focus().val('通过网盘分享文件，下载下来看看吧~\n')):(contianer = $('#topic_msg') ,obj_link.find('.lwork_mes').focus().val('通过网盘分享文件，下载下来看看吧~ \n')); 	
		  })
		  obj_link.find('.sendBtn').click(function(){
			 var msg_content =  obj_link.find('.lwork_mes').val(); 
			 var members =  loadContent.getmembers(msg_content);	 
			 var image ='share;' + file_name + ';' + url ;
			 var opt = { uuid: uuid, content:msg_content , members: members, image: image, 't': new Date().getTime()}; 
             loadContent.publish(type, opt, contianer );
			 totips.hidetips('share');
		  })
         ifNotInnerClick(['totips', 'share_top', 'sendBtn', 'sharefiles','totaskmenu', 'share_menu', 'share_content' ,'remindSpan' ,'lwork_mes', 'seatips' ,'maxNum', 'countTxt', 'member_icon','floatCorner_top','corner'
		 ], function(releaseFunc){totips.hidetips('share');if (releaseFunc){releaseFunc();}});	
	},
    commentmes: function () {
        var _this = $(this);
        var taskid = _this.attr('sendid');
        linkhref = taskid + _this.attr('link');
        obj = $('#' + linkhref);				
	    obj =_this.parent().parent();
        $('.invite ,.tracewrap, .newcomtWrap').hide();
        mode = _this.attr('mode');		
        if (obj.find('.comtWrap').length <= 0) {
            loadContent.createcomtinput(obj, taskid, 'comtWrap', mode, linkhref);						
            loadContent.loadcomt(mode, taskid, linkhref);
            loadContent.bind(linkhref + '_comtWrapbtn', loadContent.sendcomt, 'id');			
        } else {
            loadContent.loadcomt(mode, taskid, linkhref);
            obj.find('.comtWrap').css('display') == 'block' ? obj.find('.comtWrap').slideUp() : obj.find('.comtWrap').slideDown();
        }
    },	
    new_commentmes: function () {
        var _this = $(this);
        var taskid = _this.attr('sendid');
        linkhref = taskid + _this.attr('link');	
		var	name = _this.attr('name'), mode = _this.attr('mode'), index = _this.attr('findex');	
	    obj =_this.parent().parent();
        $('.invite ,.tracewrap , .comtWrap').hide();
        if (obj.find('.newcomtWrap').length <= 0) {
            loadContent.createcomtinput(obj, taskid, 'newcomtWrap', mode, linkhref);
			_this.parent().parent().find('.comtInput').val('回复@'+name+':');
			comt_index = index ;
			loadContent.bind(linkhref + '_newcomtWrapbtn', loadContent.sendcomt, 'id');
        } else {
            loadContent.loadcomt(mode, taskid, linkhref);
            obj.find('.newcomtWrap').css('display') == 'block' ? obj.find('.newcomtWrap ').slideUp() : obj.find('.newcomtWrap').slideDown();
        }
    },
    loadcomt: function (mode, task_id, linkhref) {		
        var opt, msg_id;
        opt = { uuid: uuid, entity_id: task_id, 't': new Date().getTime() };
        api.content.load_comt(mode, opt, function (data) {
            var obj = data['replies'],
		         html = '';
            for (var i = 0; i < obj.length; i++) {	
                html += loadContent.createcomtdom(obj[i], task_id ,mode);
            }
            $('#' + linkhref).find('.comtcontent').html(html);
			
			loadContent.getdelete_name($('#' + linkhref));
			loadContent.contentmemberdetail();
		    loadContent.bind('sub_comment', loadContent.subcomt_handle, 'class');
			loadContent.bind('sub_dialog', loadContent.load_dialog, 'class');
        });
    },	
    load_dialog: function () {
		var _this = $(this)		
		var mode = _this.attr('mode'), task_id = _this.attr('task_id') , index = _this.attr('findex');
        opt = { uuid: uuid, entity_id: task_id, index:index, 't': new Date().getTime() };
        api.content.load_dialog(mode, opt, function (data) {			
            var obj = data['replies'], html = '';
            for (var i = 0; i < obj.length; i++) {	
                html += loadContent.createcomtdom(obj[i], task_id, mode);
            }
		   var dialog = art.dialog({
					title: '查看对话',
					content: html,
					id: mode + '_dialoga',
					lock: true,
					fixed: true,
					width: 500,
					button: [{
					 name: '关闭'
					}]
		   });
        });
    },
    createcomtdom: function (obj, task_id, mode) {
		var content = obj.content;
		var temp , name ,photo , delete_css = '', delete_uuid = '' ;
		if(typeof(loadContent.employstatus_sub(obj.from)) !== 'undefined'){
		   temp = employer_status[loadContent.employstatus_sub(obj.from)];		
		   	photo = temp['photo'];	
			name = temp['name'];
			name_employid = temp['name_employid'];
		}else{
			name = '未知';
			photo = '/images/photo/defalt_photo.gif';	
			name_employid = '未知';
			delete_css = 'delete_uuid';	
			delete_uuid = 'delete_' + obj.from ;			
		}
		var dialog ='';	
	    if(obj.to && '-1' !== (obj.to).toString() && ( uuid != (obj.to).toString() ||  obj.to != obj.from ) )
		   dialog = '<a href="###" task_id = "'+ task_id +'"  findex="' + obj.findex + '"  mode="'+ mode +'" class="sub_dialog">查看对话</a>'; 

		content = obj.content.replace(':', '  ');		
	   	content = loadContent.format_message_content(content, 'linkuser');
	    html = ['<dl>',
				'<dt class="sub_dt"><img src="'+ photo +'" width="28" height="28"/></dt>',		
			    '<dd class="sub_dd"><span employer_uuid="'+ obj.from +'" class="lanucher '+ delete_css +' '+ delete_uuid +'">' + name + '</span>： ' + content + '<span class="gray"> ( ' + obj.timestamp + ' )</span></dd>',
				'<dd class="sub_comt">'+ dialog +'<a href="###" task_id = "'+ task_id +'"  to = "'+ obj.to +'" tindex="' + obj.tindex + '"  findex="' + obj.findex + '"  name = "'+ name_employid +'" class="sub_comment">回复 </a></dd>',
			    '</dl>'
			    ].join("");
        return html;
   },
	subcomt_handle: function(){
		var _this = $(this);
		var name = _this.attr('name');
	    var task_id = _this.attr('task_id');
		comt_index = _this.attr('findex');
		loadContent.target.find('.' + task_id).find('.comtInput').focus().val('回复@'+name+':');		
	},
    setFocus: function(){
        var _this = $(this);
        var type = _this.attr('type');
        var msgid = _this.attr('msgid');
        api.focus.setFocus(uuid, [{"type":type, "entity_id":msgid, "tags":[]}], function(){
            loadContent.myFocus.setFocus(type, msgid, []);
            _this.removeClass('setFocus').addClass('cancelFocus');
            _this.attr('titile', '取消关注');
            _this.text('取消关注');
            loadContent.bind('cancelFocus', loadContent.cancelFocus, 'class');
            var hide = function () {              
                $('#floattips').html('').remove();
                return false;
            }
            var html = '<div class="new_tag_tip">';
            html += '<div class="set_focus_success_msg">添加关注成功！</div>';
            html += '<div>' + loadContent.createTagInputer() + '</div>';
            html += '<div class="tag_edit_tip">标签1~12个字，不能有空格，可以已有标签中选择：</div><ul class="candidate_tags">';
            var tagCandidates = loadContent.myFocus.getExistingTagList();
            for (var i in tagCandidates){
                html += '<li class="candidate_tag"> <a class="candidate_tag_btn" href="###">' + tagCandidates[i] + '</a></li>';
            }
            html += '</ul></div>';
            totips.showtip(_this, html, 25 ,90);
            $('.new_tag_tip').find('.tag_inputer').css('display', 'inline');
            $('.new_tag_tip').find('.input_tag_txt').focus();
            ifNotInnerClick(['new_tag_tip', 'input_tag_txt', 'input_tag_yes', 'input_tag_no','set_focus_success_msg',
                            'tag_edit_tip', 'candidate_tags', 'candidate_tag', 'candidate_tag_btn'], function(releaseFunc){hide();if (releaseFunc){releaseFunc();}});
            $('.new_tag_tip').find('.input_tag_no').unbind('click').bind('click', hide);
            $('.new_tag_tip').find('.candidate_tag').unbind('click').bind('click', function(){
                $('.new_tag_tip').find('.input_tag_txt').val($(this).find('a').text()).focus();
            });
            $('.new_tag_tip').find('.input_tag_yes').unbind('click').bind('click', function(){
                var curTag = $('.new_tag_tip').find('.input_tag_txt').val();
                if ("" != curTag){
                    api.focus.setFocus(uuid, [{"type":type, "entity_id":msgid, "tags":[curTag]}], function(){
                        //LWORK.msgbox.show("打标签成功！", 4, 1000);
                        loadContent.myFocus.setFocus(type, msgid, [curTag]);
                    });
                    hide();
                }else{
                    LWORK.msgbox.show("标签不能为空！", 5, 1000);
                }
            });
            $('.new_tag_tip').find('.input_tag_txt').unbind('keyup').bind('keyup', function(){loadContent.checkTagInput($(this)); return false;});
        });
        return false;
    },
    cancelFocus: function(){
        var _this = $(this);
        var type = _this.attr('type');
        var msgid = _this.attr('msgid');
        loadContent.createGeneralConfirm(_this, '你确定要取消关注吗？', '取消关注不会删除该消息。', function(){        
            api.focus.cancelFocus(uuid.toString(), type, msgid, function(){
                loadContent.myFocus.cancelFocus(type, msgid);
                if (loadContent.target.attr('id') === 'focus'){
                    _this.parent().parent().remove();
                    loadContent.createTagsMgtDom();
                    var tagsStatistics = loadContent.myFocus.getTagsStatistics();
                    if (tagsStatistics['allFocuses'] === 0){
                        $('#focus_msg').html('<div class="nocontent">你还没有关注任何微博和任务呢！ 对于重要的微博或者任务，赶紧关注一下哦！</div>');
                    }else{
                        loadContent.curTag = (tagsStatistics[loadContent.curTag] > 0) ? loadContent.curTag : "allFocuses";
                        $('.tag_mgt').find('#' + loadContent.curTag).click();
                    }
                }

                $('#article').find('.cancelFocus').each(function(){
                    //console.log('walk a msg:{' + $(this).attr('type') + ', ' + $(this).attr('msgid') + '}...');
                    if (($(this).attr('type') === type) && ($(this).attr('msgid') === msgid)){
                        $(this).removeClass('cancelFocus').addClass('setFocus');
                        $(this).attr('titile', '关注');
                        $(this).text('关注');
                        loadContent.bind('setFocus', loadContent.setFocus, 'class');
                    }
                });

                totips.hidetips(); 
                $(document).unbind('click');
            });
        });
        return false;
    },
    loadtrace: function () {
        var _this = $(this);
        var task_id = _this.attr('taskid');
        linkhref = task_id + _this.attr('link');
        obj = $('#' + linkhref);
        var mode = _this.attr('mode');
        if (obj.find('.tracewrap').css('display') === 'none') {
            $('.comtWrap , .invite ,.tracewrap').slideUp();
            $('.trace_content').html('').parent().hide();
            api.content.tasktrace(mode, task_id, uuid, function (data) {
                var traces = data['traces'];
                var html = "",
                    content,
                    str, temp_employer, photo,  owner, name_employid ,delete_css = '',  delete_uuid ='';
                obj.find('.unreadtrace').text(traces.length);
                if (traces.length > 0) {
                    for (var i = 0; i < traces.length; i++) {
                        var temp = traces[i].event;
						if(typeof(loadContent.employstatus_sub(traces[i].from)) !== 'undefined'){
							temp_employer = employer_status[loadContent.employstatus_sub(traces[i].from)];		
							photo = temp_employer['photo'];	
							owner = temp_employer['name'];
							delete_css = '';
						    delete_uuid ='';
						}else{
							owner = '未知';
							photo = '/images/photo/defalt_photo.gif';
							delete_css = 'delete_uuid';	
							delete_uuid = 'delete_' + traces[i].from ;			
						}	
                        if (temp.indexOf('invite') < 0) {							
                            temp === 'read' ? content = '阅读了该任务' : ( temp == 'voted' ?  content = '参与了投票' :  content = '将该任务状态设置为完成' );							
                        } else {
                            content = '邀请了 ';
                            str = temp.split(',');
                            for (var m = 1; m < str.length; m++) {
                                var a = str[m];
								var yaoqing_name = '未知' ;
								var delete_css_2 = 'delete_uuid';
						
								if(typeof(loadContent.employstatus_sub(a)) !== 'undefined')	{							
								  yaoqing_name = employer_status[loadContent.employstatus_sub(a)].name ;
							      delete_css_2 = '';
								}
                                content += '<span employer_uuid="'+ a +'" class="comtuser '+ delete_css_2 +'  delete_'+ a +'">' + yaoqing_name + '</span>' + ' ';								
                            }
                            content += " 加入";
                        }
                        html += ['<dl>',
							 '<dt class="sub_dt"><img src="' + photo + '" width="28" height="28"/></dt>',
							 '<dd class="sub_dd"><span employer_uuid="'+ traces[i].from +'" class="comtuser '+delete_css+' '+ delete_uuid +'">' + owner + '：</span>' + content + '  <span class="gray"> ( ' + traces[i].timestamp + ' ) </span></dd>',
							 '</dl>'
						].join("");
                    }
                    obj.find('.trace_content').html(html).parent().slideDown(500);
					loadContent.getdelete_name(obj.find('.trace_content'));
                } else {
                    LWORK.msgbox.show("当前没有任何动态！", 4, 1000);
                }
            });
        } else {
            obj.find('.tracewrap').slideUp(500, function () { obj.find('.trace_content').html(''); });
        }
    },
    invitecolleagues: function () {
        var _this = $(this);
        var taskid = _this.attr('sendid');
        linkhref = taskid + _this.attr('link');
        obj = $('#' + linkhref);
        obj.find('.comtWrap ,.tracewrap').hide();
        var mode = $(this).attr('mode');
        if (obj.find('.invite').length <= 0) {
            loadContent.createcomtinput(obj, taskid, 'invite', mode, linkhref);
            loadContent.bind(linkhref + '_invitebtn', loadContent.Invitehandle, 'id');
            $('#' + linkhref + '_invite').membersearch({
                target: $('#' + linkhref),
                isgroup: 'no',
                appendcontainer: $('#' + linkhref).find('.invitecontent'),
                symbol: ';'
            });
        } else {
            obj.find('.invite').css('display') == 'block' ? obj.find('.invite').slideUp() : obj.find('.invite').slideDown();
        }
    },
    Invitehandle: function () {
        var _this = $(this);
        var task_id = _this.attr('sendid');
        var new_members = new Array();
        var obj = _this.parent().parent();
        var txt = obj.find('.unreadtrace').text();
        var mode = _this.attr('mode');
        var temp_item;
		var reply_content = '邀请了 ';
        _this.parent().find('.invitecontent').find('li').each(function () {
            temp_item = ($(this).attr('uuid').toString());
		    reply_content += employer_status[loadContent.employstatus_sub(temp_item)].name_employid + ' ';
            new_members.push(temp_item);
        });
		reply_content += " 加入该微博"; 
				
       if(new_members.length >0){
			api.content.msginvite(mode, task_id.toString(), uuid, new_members, function (data) {
				obj.find('.unreadtrace').text(parseInt(txt) + 1);
				obj.find('.invite').hide();
				obj.find('.inputTxt').val('').focus();
				_this.parent().find('.invitecontent').html('');
				_this.parent().parent().slideUp();
				LWORK.msgbox.show("已发送您的邀请！", 4, 1000);
				if(mode === 'topics'){
				   var comt_num = _this.parents().find('.' + task_id).eq(0).find('.unreadcomt').text();				
				   api.content.sendreplies(mode, task_id, uuid, reply_content, '-1', '-1', function (data) {								   
					   var html2 = loadContent.createcomtdom({'from':uuid, 'timestamp': data.timestamp, 'content':reply_content ,'findex':data.index ,to:'-1' } , task_id , mode );				
						$('.' + task_id).find('.comtcontent').prepend(html2);
						loadContent.bind('sub_dialog', loadContent.load_dialog, 'class');
						loadContent.bind('sub_comment', loadContent.subcomt_handle, 'class');				   
						$('.' + task_id).find('.unreadcomt').text(parseInt(comt_num, 10) + 1);
						return false;
				  });
				}						
			});
	   }else{
			    LWORK.msgbox.show("请选择邀请人！", 4, 1000);
				obj.find('.inputTxt').val('').focus();
	   }
    },
    createcomtinput: function (obj, taskid, type, mode, linkhref) {
        var txt;
		var inputcss = ""; 		
        $('.comtWrap , .invite , .tracewrap').slideUp();		
		type === "invite" ? inputcss = 'comtbtn' : inputcss = 'comtbtn disabledBtn';
		type === 'comtWrap' || type === 'newcomtWrap'? (mode === 'questions' ? txt = "回答" : txt = "回复", css = 'comtInput') : (mode === 'documents' ? txt = "分享" : txt = "邀请", css = 'inputTxt');
        html = ['<div class="' + type + '" style="display:none;">',
				'<div class="float_corner float_corner_top" style=""><span class="corner corner_1">◆</span> <span class="corner corner_2">◆</span></div><div class="' + type + '_content">',
				'<textarea id="' + linkhref + '_' + type + '" sendid="" class="' + css + '" style="overflow-y: hidden; height: 37px;"/>',
				'<a class="'+ inputcss +'" mode="' + mode + '" id="' + linkhref + '_' + type + 'btn"  type="'+ type +'" sendid="' + taskid + '" href="###">' + txt + '</a>'
			   ].join("");
        type === 'invite' ? html += ['<div class="seatips"></div><div class="clear"></div> <ul class="invitecontent"></ul>  </div>'].join("") : html += ['<span class="comt_tips"><span id="' + linkhref + type + '_oMaxNum">0</span>/140</span><div class="comtcontent"></div></div></div>'].join("");
        obj.append(html);
        obj.find('.' + type).slideDown(500);
        $('#' + taskid + '_' + type).focus();
        obj.find('.comtInput').keyup(function () {			
            confine({ 'oConBox': $(this), 'oSendBtn':$(this).next(), 'oMaxNum': $(this).next().next().find('span').eq(0) }, 1);
        })
    },
    load_interval: function () {		
        var num_cur = 0, num_his = 0, num_send = 0;
        api.content.interval(uuid.toString(), function (data) {
            var interval_online = data.onlines;
            var interval_offline = data.offlines;			
            employer_status = array.updataArray(interval_online, interval_offline, employer_status);			
            loadContent.dynamic_msgnum('polls', data['polls']);
            loadContent.dynamic_msgnum('tasks', data['tasks']);
            loadContent.dynamic_msgnum('documents', data['documents']);
            loadContent.vedio_Notice('video', data['video']);
            loadContent.datameeting_Notice(data['datameeting']);
            loadContent.dynamic_msgnum('topics', data['topics']);
            loadContent.interval_taskfinish(data['tasks_finished']);
        } ,function(){
			clearInterval(time);
			$('.Interrupt').show();						
		});
        return false;
    },
	blinkNewMsg: function(num){
		setInterval(function(){		
		  var num = 0;
		  $('.dynamic').find('a').each(function(){
			  var txt = parseInt($(this).text());
			  num = num + txt;
			})
		  if(num >0 ){
			 document.title = loadContent.g_blinkswitch % 2 == 0 ? 'LWORK工作平台': "【 您有" + num + "条新消息 】 - " + 'LWORK工作平台';	
		  }else{
			 document.title = 'Lwork工作平台';
		  }
		}, 500);
	},
	stopBlinkNewMsg: function() {
			if (g_blinkid) {
				clearInterval(g_blinkid);
				g_blinkid = 0;
				document.title = 'Lwork工作平台';
			}
	 },
    dynamic_msgnum: function (type, num) {
        var obj = $('.dynamic').find('.' + type);
		var link_href = obj.find('.new_msg').attr('link');
        if ($.isArray(num)) {
            var a = parseInt(num[0], 10);
            var b = parseInt(num[1], 10);
			var al = a + b;
            obj.find('a').text(al);
            a + b > 0 ? (obj.show() , showNotification('消息提醒', '您在Lwork工作平台有新消息！')) :obj.hide();			
            if (a > 0) {
				obj.find('.new_msg_num').text(a).parent().show();
                $('#' + type).find('.unreadmsg_num').text(a);
                $('#' + type).find('.nuread_msg').css('display', 'inline-block');
			 }
            if (b > 0) {
				obj.find('.new_msg_comt').text(b).parent().show();
                $('#' + type).find('.unreadcomt_num').text(b).parent().show();		
                $('#' + type).find('.nuread_comt').css('display', 'inline-block');
            }
			
        } else {
            if (parseInt(num, 10) > 0) {
                obj.show();
                obj.find('a').text(num);
                obj.find('.new_msg_num').text(num).parent().show();
                $('#' + type).find('.unreadmsg_num').text(num);
                $('#' + type).find('.nuread_msg').css('display', 'inline-block');			
				showNotification('消息提醒', '您在Lwork工作平台有新消息！');
            } else {
                obj.hide();
            }
        }
        return false;
    },
    vedio_Notice: function (type, data) {
        var obj = $('.dynamic').find('.' + type);
        if (data.length > 0) {
            obj.find('.new_num').text(data.length);
            var from = data[0];
            var i = subscriptArray[from.toString()];
            var name = employer_status[i].name;
			ManageSoundControl('play' , '/images/aud.wav', 3)
            obj.find('.vedio_notice').attr('from', from).text(name + '向您发起了视频邀请');
			showNotification('消息提醒', '在Lwork工作平台，' + name + '向您发起了视频邀请！');
            obj.show();	
        }
    },
    vedio_noticehandle: function () {
        var obj = $('.dynamic').find('.video');
		var from = $(this).attr('from');
            var opt = { from: uuid, to: from.toString(), sdp: '1' }
            $('.tab_item').find('.video').find('a').click();
			$('#video').find('.endVedio').attr('to',from);
            ws.connect(opt);			
            $('#video').find('.video_input').attr('disabled', true);
            $('#video').find('.startVedio').hide().next().show();
            obj.hide();
		    obj.find('a').text(0);
        return false;
    },
    datameeting_Notice: function (data) {
        var obj = $('.dynamic').find('.datameeting');
        var datameeting_poll_func = {
            "invite" : function() {
                        if (loadContent.meetingJoined) return;
                        loadContent.meetingJoined = true;
                        obj.find('.new_num').text(1);
                        var subject = data[1];
                        var url = data[2];
                        var from = data[3];
                        var meetingId = data[4];
                        var i = subscriptArray[from.toString()];
                        var name = employer_status[i].name;
                        ManageSoundControl('play' , '/images/aud.wav', 3);
                        obj.find('.datameeting_notice').attr('from', from).attr('url',url).attr('meetingId', meetingId).text(name + '向您发起了数据会议邀请');
                        showNotification('消息提醒', '在Lwork工作平台，' + name + '向您发起了数据会议邀请！');
                        obj.show();	
                      },
            "cancel" : function() {
                        if (!loadContent.meetingJoined) return;
                        ManageSoundControl('stop' , '/images/aud.wav', 3);
                        loadContent.meetingJoined = false;
                        obj.find('.new_num').text("");
                        obj.hide();	
                        var from = data[1];
                        var meetingId = data[2];
                        var i = subscriptArray[from.toString()];
                        var name = employer_status[i].name;
                        if (loadContent.datameetingWindow) {
                            loadContent.datameetingWindow.close();
                        }
                        showNotification('消息提醒', '在Lwork工作平台，' + name + '终止了数据会议！');
                     }
        }
        if (data.length > 0) {
            var func = datameeting_poll_func[data[0]];
            if (func) func();
        }/*else{
			ManageSoundControl('stop','');
		    obj.hide();
			obj.find('.new_num').text(0);
		}*/
    },
    datameeting_noticehandle: function () {
        ManageSoundControl('stop' , '/images/aud.wav', 3);
        var obj = $('.dynamic').find('.datameeting');
		var from = $(this).attr('from');
        var url =  $(this).attr('url');
        (function() {
            newwin =window.open("");
            newwin.location = url;
            loadContent.datameetingWindow = newwin;
            newwin.focus();
        })();
        obj.hide();
        obj.find('a').text(0);
        return false;
    },
    dynamic_itemdisplay: function (mode) {
        var obj = $('.dynamic').find('.' + mode);
        var a = parseInt(obj.find('.new_msg_num').text(), 10);
        var b = parseInt(obj.find('.new_msg_comt').text(), 10);
        obj.find('.new_num').text(a + b);
        a + b > 0 ? obj.show() : obj.hide();
        return false;
    },
    loadunreadmsg: function () {
        var mode = $(this).attr('mode');
        var linkhref = $(this).attr('link');	
        var containdom = $('#' + linkhref).attr('containdom');
		function loadunread_appnedmsg(){ loadContent.loadmsg(mode, 'none', 'unread', linkhref, '-1', 1); }
		if( containdom !== 'yes' ){
		   loadContent.loadmsg_handle(link_href, page_index, 1, '', loadunread_appnedmsg);
		}else{
		   loadunread_appnedmsg();
		}
        return false;
    },
    loadunreadcomt: function () {
        var mode = $(this).attr('mode');
        var linkhref = $(this).attr('link');
        loadContent.loadnewcomt(mode, linkhref);
        $('.dynamic').find('.new_msg_comt').text(0).parent().hide();
        //$('.dynamic').find('.new_num').text(0);	
        return false;
    },
    replacecontent: function (msg_content) {
        var reg = /(@[^\s]+)\s*/g;
        var m = "", temp = "", group, group_str, group_arr, member_id;
        var temp_name = "";
        var to = {};
		var groupmembers_len;
        while (m = reg.exec(msg_content)) {			
            temp = (m[0].substr(1)).replace(/(^\s*)|(\s*$)/g, "");	
            if (typeof (name2user[temp]) === 'object') {		
                if (name2user[temp].group_id) {
				  var group_id = name2user[temp].group_id;
				  for(var key in groupsArray[group_id]['members']){
					  var temp_uuid =groupsArray[group_id]['members'][key];					  					  
					  temp_name += ' @' + employer_status[loadContent.employstatus_sub(temp_uuid)]['name_employid'];				
					  to[temp_uuid] = temp_uuid;
				  }	
				   msg_content = msg_content.replace('@' + temp, temp_name);				    
                   if ('' == msg_content) { LWORK.msgbox.show("您所选择的组没有成员，请添加成员或输入内容！", 2, 1000); return false; }				   	
                }else if(name2user[temp].department_id){
					group = (name2user[temp].department_id).toString();
                    to[group] = group;
				} else {
                    group = (name2user[temp].uuid).toString();
                    to[group] = group;
                }
            }else{			     		
			   if (temp == 'all') { to['all'] = (groupsArray['all']['employer_uuid']).toString(); }	
			}
        }
        return { 'msg_content': msg_content, 'to': to };
    },
    goback: function () {
        api.request.del('/lwork/auth/logout', { 'uuid': uuid }, function (data) {
            clearInterval(time);
            $.cookie('password', '');
            window.location = "index.html";
        })
        return false;
    },
    setpersonal: function () {
        var setlisthide = function () { $(this).find('.set_perinformation').removeClass('setcurrent').next().hide(); }
        var setlistshow = function () { $(this).find('.set_perinformation').addClass('setcurrent').next().show(); }		
        $('.login_suc').bind('mouseover', setlistshow);
        $('.login_suc').bind('mouseleave', setlisthide);		
        $('.set_list').find('.personal').click(function () {
            setlisthide();
            var mode = $(this).attr('mode');
            var contentId = document.getElementById(mode);
			var fun;
            var title;
            mode === 'modifyperinof' ? (  fun = loadContent.setpersonalinfo , title = "个人信息设置") : (  fun = loadContent.modifypassword , title = "修改密码");
            var dialog = art.dialog({
                title: title,
                content: contentId,
                id: mode + '_dialog',
                lock: true,
                fixed: true,
                width: 450,
                height: 200,
			    cancel: true,
			    button: [{
				 name: '确定',
				 focus: true,
				 callback:  fun
				}]
            });
        })
    },
	modify_images: function(){	
		var obj = $('#modify_images');			
		var contentId = document.getElementById('modify_images');		
	    loadContent.updateimg.src(obj);	
		$('.modify_img').unbind('click').click(function(){
            var dialog = art.dialog({
                title: '更改图像',
                content: contentId,
                id:'upload_images',
                fixed: true,
                width: 450,
                height: 200,
			    cancel: true,
			    button: [{
				  name: '确定',
				  focus: true,
				  callback: loadContent.updateimg.update_images
			    }]
            });
		    return false;	 
	     })	
	},
	updateimg:{
	   src:function(obj){	
	   		var obj = $('#modify_images');	
	        var img =obj.find('.preview_img img');				   
			obj.find('.recommend_images img').click(function(){
			  var url = $(this).attr('src');
			  img.attr({'src': url, 'upload':'no'});
			})
			var o = document.getElementById('upld2');
			o.onchange = function(){
				getFilePath(this, function(file_path){
					img.attr({'src': file_path, 'upload':'yes'});				
				});
			}
			function getFilePath(o, callback){
				var url = '';
				if(document.all){ // MSIE
					url = o.value;
					if(url != '')callback(url);
				}else{		
					oFReader = new FileReader(), rFilter = /^(image\/bmp|image\/cis-cod|image\/gif|image\/ief|image\/jpeg|image\/jpeg|image\/jpeg|image\/pipeg|image\/png|image\/svg\+xml|image\/tiff|image\/x-cmu-raster|image\/x-cmx|image\/x-icon|image\/x-portable-anymap|image\/x-portable-bitmap|image\/x-portable-graymap|image\/x-portable-pixmap|image\/x-rgb|image\/x-xbitmap|image\/x-xpixmap|image\/x-xwindowdump)$/i;  
					 oFReader.onload = function (oFREvent) { 
						url = oFREvent.target.result;  
						if(url != '')callback(url);
					}; 
					  if (o.files.length === 0) { return; }  
					  var oFile = o.files[0];  
					  if (!rFilter.test(oFile.type)) { LWORK.msgbox.show("请上传图片文件！", 1, 2000);   return; } 
						oFReader.readAsDataURL(oFile);
					  } 
			}
	    },		
	   update_images: function(){           
	       var obj = $('#modify_images');			
		   var img =obj.find('.preview_img img');
		   var photo = "";
		   if(img.attr('upload')==='yes'){    
             obj.find('.upload_imag_loading').show();        
		     obj.find('.submit_imgaes').click();
             return false;
		   }else{				
			 photo = img.attr('src');				
			 return loadContent.updateimg.updateimages(photo ,1);			 
		  }
	  },
	  updateimages: function(photo, flag){
        $('#modify_images').find('.upload_imag_loading').hide();
		     if(!flag) photo = loadContent.getpicphoto(photo, 'S');
    		 api.content.updatephoto(uuid, photo, function (data) {
				var i = subscriptArray[uuid];
				employer_status[i].photo = photo;			
				$('#modifyperinof').find('img').attr('src',photo)
				$('.' +  employer_status[i].phone).find('img').attr('src',photo);
                $.dialog({ id: "upload_images" }).close();     
				return true; 
            });		
	  }
    },
	getpicphoto: function(filename, type){
		var str = filename.split('.');
		var len = str.length;
		var newfilename = '';
		var filetype = (str[str.length-1]).toLowerCase();
			//console.log(filetype)
		str[len-2] =  str[len-2] + type + '.';
		if(filetype.indexOf('yaws') < 0){
			
		for(var i = 0 ; i<len; i++){
			newfilename += str[i];
		}
		  return newfilename ;
		}else{

			return filename 
	   }
		
	},
    setpersonalinfo: function () {
        var obj = $('#modifyperinof');
        var department = obj.find('.department').val();
        var phone = obj.find('.telephone').val();
        var mail = obj.find('.email').val();
        var reg = /^([.a-zA-Z0-9_-])+@([a-zA-Z0-9_-])+((\.[a-zA-Z0-9_-]{2,3}){1,2})$/;
        obj.find('input').keyup(function () { obj.find('.modify_tips').hide(); })
		if('' !== phone){
			if (!mobile_test(phone)) {
				obj.find('.modify_tips').text('请输入正确的手机号，须包含国家码,如中国 0086！').show();
				obj.find('.telephone').focus();
				return false;
			}
		}
		if('' !== mail){			
			if (!reg.test(mail)) {
				obj.find('.modify_tips').text('请输入正确的邮箱！').show();
				obj.find('.email').focus();
				return false;
			}
		}
		
        api.content.setpersonalinfo(uuid, department, mail, phone, function (data) {
            var i = subscriptArray[uuid];
            employer_status[i].phone = phone;
            employer_status[i].mail = mail;
			
            LWORK.msgbox.show("更改成功！", 4, 1000);
        });
    },
    modifypassword: function () {	
        var obj = $('#modifypassword');
        var old_pass = obj.find('.oldpsw').val();
        var account = $.cookie('account');
        var new_pass1 = obj.find('.newpsw1').val();
        var new_pass2 = obj.find('.newpsw2').val();
        obj.find('input').keyup(function () { obj.find('.modify_tips').hide(); })
        if ('' === old_pass) {
            obj.find('.modify_tips').text('原密码不能为空').show();
            obj.find('.oldpsw').focus();
            return false;
        } else {
            if ('' === new_pass1) {
                obj.find('.modify_tips').text('新密码不能为空').show();
                obj.find('.newpsw1').focus();
                return false;
            } else if (new_pass1.length < 6) {
                obj.find('.modify_tips').text('密码长度不能小于6位').show();
                return false;
            } else {
                if (new_pass1 !== new_pass2) {
                    obj.find('.modify_tips').text('重复密码不一致').show();
                    obj.find('.newpsw2').focus();
                    return false;
                }
            }
        }
        api.content.modifypassword(uuid, $.cookie('company'), account, md5(old_pass), md5(new_pass1), function (data) {
            if (data.status === 'ok') {
                $.cookie('password', md5(new_pass1), {expires: 30});  
                LWORK.msgbox.show("更改成功！", 4, 1000);
            } else {
                obj.find('.modify_tips').text('原始密码输入错误').show();
                obj.find('.oldpsw').focus();
                return false;
            }
        });
    },
    taskstatus: function () {
        var obj = $(this).parent().parent();
        var task_id = obj.attr('task_id');
        loadContent.createGeneralConfirm($(this), '你确认要将这条任务设置为完成吗？', '设置为完成将通知所有任务成员。', function(){
            api.content.setstatus(task_id, uuid, 'finished', function (data) {
    			var arr =new Array();
    			arr.push({'entity_id':task_id, 'finished_time':  data['finished_time'] })
    			loadContent.taskfinish_handle(arr ,'mysend_msg');
                LWORK.msgbox.show("该任务状态已设置为完成！", 4, 1000);					
            });
        });
        return false;
    },
    interval_taskfinish: function (arr) {
        var obj = $('.dynamic').find('.notice');
        var num = parseInt(obj.find('a').text(), 10) + 1;
	    if (arr.length > 0) {
            obj.show().find('.new_msg_num').text(arr.length).parent().show();
			obj.find('.new_num').text(1).parent().show();	
			loadContent.taskfinish_handle(arr ,'current_task');
		}
        return false;
    },	
	taskfinish_handle: function(arr, contianer){	
	    var html , temp  ,recycleHtml;	
		for (var i = 0; i < arr.length; i++) {	
			temp = $('#' + arr[i]['entity_id'] + contianer);
			html = temp.clone(true);
			temp.html('').remove();
			html.prependTo('#finish_msg');			
			$('#' + arr[i]['entity_id'] + contianer).attr('id', arr[i]['entity_id'] + 'finish_msg');			
			temp = $('#' + arr[i]['entity_id'] + 'finish_msg');				
			temp.find('a').attr('link', 'finish_msg');
			temp.find('.invitecolleagues ,.taskstatus').remove();              
			temp.find('.msg_time').append('<span class="fininshtime">完成:&nbsp;' + arr[i]['finished_time'] + ' </span>');
			recycleHtml = '<div class="recycle_item"><a href="###" class="recycle_msg_btn" style="display:none" title="删除此消息"></a></div>'
			temp.prepend(recycleHtml);
			loadContent.bindMsgRecycler('finish_msg');
			loadContent.bindMsgHandlers();
		}		
	},	
    pollstatus: function () {
        var _this = $(this);
        var input = _this.parent().prev().find('input[type=radio]');
        var msg_id = _this.attr('msg_id');
        var choice = _this.parent().prev().find('input:radio:checked').attr('label');
        if (!choice) { LWORK.msgbox.show("请选择投票项！", 2, 1000); return false; }
        api.content.votestatus(msg_id, uuid, choice, function (data) {
            _this.removeClass('pollsBtn').addClass('disabledBtn').text('已投票');
            _this.next().show().click();
            input.attr('checked', false);
            //  LWORK.msgbox.show("投票成功，可点击查看投票结果！", 4, 1000);			    
        });
    },
    pollsresult: function () {
        var entity_id = $(this).attr('msg_id');
        var obj = $(this).parent().parent();
		$(this).text('刷新投票结果');
      //  console.log('view vote result...');
        api.content.voteresult(entity_id, uuid, function (data) {
            var current = data['results'];
            var count = 0;
            var temp_arr = {};
            for (var i = 0; i < current.length; i++) {
                temp_arr[current[i]['label']] = current[i]['votes'];
                count += current[i]['votes'];
            }
            obj.find('input').each(function () {
                var voteitem = $(this).attr('label');
                var votenum = temp_arr[voteitem];
                var voteprop;
                count === 0 ? voteprop = 0 + "%" : (voteprop = (((votenum / count) * 100).toFixed(2)) + "%");
                obj.find('.' + voteitem).show();
                obj.find('.' + voteitem).find('.number').text(votenum + '票(' + voteprop + ')');
                obj.find('.' + voteitem).find('.bar_inner').animate({
                    width: voteprop
                }, 2000);
            });
        });
    },
    sendcomt: function () {
	    var _this = $(this);
		if (!_this.hasClass('disabledBtn')) {
			_this.addClass('disabledBtn')
            var mode = _this.attr('mode');
            var html = '',
                task_id = _this.attr('sendid'), 		
                reply = _this.prev().val();
            var content = reply.replace(/(^\s*)|(\s*$)/g, "");			
            var comt_num = _this.parents().find('.' + task_id).eq(0).find('.unreadcomt').text();
			var to = "-1";
			var type = _this.attr('type');
			if(content.indexOf('回复') === 0){
				var index_start = content.indexOf('@');	
				var index_of = content.indexOf(':');		
				var name = content.slice(index_start + 1,index_of);	
				if(name2user[name]) to = (name2user[name]['uuid']).toString();
			}
		//	console.log(to);
			if(to === '-1'){ comt_index = '-1';to = '-1';}						
            api.content.sendreplies(mode, task_id, uuid, content, to, comt_index, function (data) {		
								
                html = loadContent.createcomtdom({'from':uuid, 'timestamp': data.timestamp, 'content':reply ,'findex':data.index ,to:to } , task_id , mode );				
                $('.' + task_id).find('.comtcontent').prepend(html);
				loadContent.bind('sub_dialog', loadContent.load_dialog, 'class');
				loadContent.bind('sub_comment', loadContent.subcomt_handle, 'class');
                $('.' + task_id).find('.unreadcomt').text(parseInt(comt_num, 10) + 1);				
                _this.prev().val('').focus();				
				if(type === "newcomtWrap")_this.parent().parent().slideUp();				
				_this.next().find('span').eq(0).text(0);				
                LWORK.msgbox.show("回复成功！", 4, 1000);				
                return false;
            });
			
        }
    },
    focusHandle: function () {
        var _this = $(this);
        var obj = _this.parent().parent();
        var index = parseInt(obj.find('input[type=text]').index(_this), 10);
        var len = obj.find('input[type=text]').length;
        var flag = true;		
        obj.find('input[type=text]').each(function (i) {
            if (i < index) {
                var txt = $(this).val();
                if (txt.indexOf('选项') >= 0 || '' === txt) {
                    flag = false;
                    return false;
                }
            } else {
                   return false;
            }
        })
        if (index == len - 1 && len < 5 && flag) {
            _this.parent().clone(true).appendTo(obj);
			_this.parent().next().find('img').attr({'src' : '/images/update_pic.png' , 'source':''});		
			
				
        }
    },
    polls_item: function () {
        var option = new Array();
        var temp_obj = {};
        $('#polls_option').find('input[type=text]').each(function (i) {
	        var txt = $(this).val();
			var images = $(this).prev().find('img').attr('source');		
            if ('' !== txt && txt.indexOf('选项') < 0) {
                temp_obj = { label: String.fromCharCode(65 + i), content: txt, image: images};  
				option.push(temp_obj);
            } else {
				if(''!== images ){
				  temp_obj = { label: String.fromCharCode(65 + i), content: '', image: images};  
				  option.push(temp_obj);
				}
            }
        });
        return option;
    },
    getselectionpos: function (textBox) {
        var start = 0, rng, srng;
        if (typeof (textBox.selectionStart) == "number") {
            start = textBox.selectionStart;
        } else if (document.selection) {
            rng = document.body.createTextRange();
            rng.moveToElementText(textBox);
            srng = document.selection.createRange();
            srng.setEndPoint("StartToStart", rng);
            start = srng.text.length;
        }
        return start;
    },
    searchIt: function(){
        $('#search_box').find('.current').eq(0).click();
    },
    searchContent: function(type, keyword){
        $('#loading').show();
        api.content.search(uuid, type, keyword, function(data){
            var msg = data[type];
            var count = data["count"];
			var msgtype2name = {'tasks':'工作协同', 'topics':'微博', 'documents':'文件', 'meeting':'电话会议', 'questions':'知识问答',  'polls':'集体决策','vedio':'视频通话'}
            //var msg = get_test_search_result()[type];
            //var count = get_test_search_result()["count"];
            var preMode = loadContent.target.attr('id');
            $('#nav').find('.' + preMode).removeClass('li_current').find('a').removeClass('curent');        
            loadContent.target.hide();
            $('#search_result').fadeIn();
            $('#search_result').find('.search_keyword').eq(0).text(keyword);
            $('#search_result').find('.search_type').eq(0).text(msgtype2name[type]);
            $('#search_result').find('.search_result_num').eq(0).text(count.toString());
            loadContent.bind('abandon_search_result', loadContent.abandonSearchResult, 'id');
            var owner, content, continer='search_result_msg';
            var html = "";
            if (msg && msg.length > 0) {
                $('#' + continer).find('.nocontent').hide();
			  if(type !== 'documents'){         
                for (var i = 0; i < msg.length; i++) { 		   
				    html += loadContent.createContent(msg[i], type, 'none' , (msg[i].status ? msg[i].status : 'all') , continer, 'block');				
                }
			  }else{
				html = [  '<ul><li class="hover_top">',       
							'<em class="uname" style="width:382px;">文件名</em>',
							'<span class="fsize file_gray" style="width:66px;text-align: left;">大小</span>',
							'<span class="fdate file_gray">更新时间</span></li>',
						  '</ul>'].join("");
				  for (var i = 0; i < msg.length; i++) { 		 
					html += loadContent.create_sharefile(msg[i]);		
				}
			  }
                $('#loading').hide();
                $('#' + continer).html(html);
				loadContent.fileshow_handle();
                loadContent.bindMsgHandlers();
				loadContent.bindloadImage();
            } else {
                $('#loading').hide();
                $('#' + continer).html('<div class="nocontent">没有搜索到任何消息</div>');
            }
        }, function () { LWORK.msgbox.show("服务器繁忙，请稍后再试！", 1, 2000); $('#loading').hide(); });
    },
    abandonSearchResult: function(){
        var msg = get_test_search_result();
        var preMode = loadContent.target.attr('id');
        $('#nav').find('.' + preMode).eq(0).click();
    }
}
// file upload plugin
var SITE = SITE || {};
SITE.fileInputs = function () {
    var $this = $(this),
      $val = $this.val(),
      valArray = $val.split('\\'),
      newVal = valArray[valArray.length - 1],
      $button = $this.siblings('.button'),
      $fakeFile = $this.siblings('.file-holder');
    if (newVal !== '') {
        $button.text('当前文件');
        if ($fakeFile.length === 0) {
            $button.after('<span class="file-holder">' + newVal + '</span>');
        } else {
            $fakeFile.text(newVal);
        }
    }
};
$(document).ready(function () {
    $('.file-wrapper input[type=file]').bind('change focus click', SITE.fileInputs);

});
// meeting controller
// responsibility: interact with server and dynamic update the meeting part of web page

var MeetingController = {
    createNew: function () {
        var memberID2Li = {};
        var phoneDict = {};
        var activeMeetingID = null;
        var c = {};
        var update_member_item = function (li, status, member_id) {
            var statusDiv = li.children('.member_status');
            var buttonDiv = li.children('.member_button');
            switch (status) {
                case 'pending':
                    statusDiv.hide();
                    buttonDiv.show().append($('<a href="###">删除</a>').click(function () {
                        li.hide('slow', function () {
                            var phone = li.find('.meeting_member_phone').text();
                            delete phoneDict[phone];
                            li.remove();
                            if ($('#meeting_current_list').find('.meeting_source').length <= 0) {
                                $('#meeting_current_list').find('li').eq(0).addClass('meeting_source').find('.meetingHost').text('主持人');
                            }
                        });
                    })).append($('<a class="meetingHost" href="###">设为主持人</a>').click(function () {
                        li.siblings().removeClass('meeting_source').find('.meetingHost').text('设为主持人');
                        li.addClass('meeting_source').find('.meetingHost').text('主持人');
                    }));
                    break;
                case 'connecting':
                    statusDiv.show().text('正在连接...');
                    buttonDiv.hide();
                    setOfflineTimeout(li, member_id);
                    break;
                case 'online':
                    statusDiv.show().text('在线');					
	                buttonDiv.show().html('<a href="###">挂断</a>').unbind('click').bind('click',function () {												
				       loadContent.createGeneralConfirm($(this), '您确认要挂断吗？', '挂断后系统将终止与其进行通话。', function(){
						    $('.float_corner3').css('right','50px');
                            api.meeting.hangup(uuid, activeMeetingID, member_id, function () {
                            update_member_item(li, 'offline', member_id);
                          });
				       });
				       return false;	
                    });				
                    break;
                case 'offline':
                   // if (li.hasClass('connecting')) return;
                    statusDiv.show().text('离线');
                    buttonDiv.show().html('<a href="###">重拨</a>').unbind('click').bind('click',function () {
                        var service_id = "123";
                        var seq_no = 1;
                        var auth_code = "auth";
                        var session_id = activeMeetingID;
                        var url = "/xengine/meetings/members?service_id="+service_id+"&seq_no="+seq_no+"&uuid="+uuid+"&auth_code="+auth_code+"&session_id="+session_id;
                        var data = {member_id:member_id, status:"online"};
                        MeetingChannel.put(url, data,function () {
                            update_member_item(li, 'connecting', member_id);
                        });
					    return false;
                    });
                    break;
                default:
                    //  console.log('not match member status');
            }
            li.removeClass('pending connecting online offline');
            li.addClass(status);
        };

        var setOfflineTimeout = function (li, member_id) {
            setTimeout(function () {
                if (li.hasClass('connecting')) {
                    update_member_item(li, 'offline', member_id);
                }
            }, 45000);
        };
        var build_member_item = function (name, phone, status, member_id, cb) {
            name = name || '会议成员';
            var nameElement = $('<span class="meeting_member_name">' + name + '</span>');
            var phoneElement = $('<span class="meeting_member_phone">' + phone + '</span>');
            var statusDiv = $('<span class="member_status">' + status + '</span>');
            var buttonDiv = $('<span class="member_button" />');
            var li = $('<li>').append(nameElement).append(phoneElement).append(statusDiv).append(buttonDiv);
            update_member_item(li, status, member_id);
            if (cb) cb(li);
        };

        var parsePendingList = function (pendingList, cbForEach) {
            var members = pendingList.val().split(' ');
            for (var i = 0; i < members.length; i++) {
                var name = '', phone = '';
                if (members[i][0] == '@') {
                    var user = name2user[members[i].substr(1)];
                    if (user) {
                        name = user['name'];
                        phone = user['phone'];
                    }
                } else {
                    phone = members[i];
                }
                if (phone) {
                    cbForEach(name, phone);
                }
            }
        }
        
        var pending_add_clicked = function (e) {
            if ('' !== c.pending_list.val() && c.pending_list.val() != '输入电话号码/拼音或汉字') {
                e = e || window.event;
                e.preventDefault();
                e.stopPropagation();
                parsePendingList(c.pending_list, function (name, phone) {
                    c.addto_current_list(name, phone);
                });
                c.pending_list.val('');
            }
        };
        
        var start_meeting_clicked = function () { 
            var meeting_source = c.current_list.find('.meeting_source');
            var current_members = new Array;
            c.current_list.children().each(function () {
                var name = $(this).find('.meeting_member_name').text();
                var phone = $(this).find('.meeting_member_phone').text();
                if ($(this).hasClass('meeting_source')) {
                    current_members.splice(0, 0, {name:name, phone:phone});
                } else {
                    current_members.push({name:name, phone:phone});
                }
            });					
            if(current_members.length<2){
               LWORK.msgbox.show("会议成员不能少于两位！", 1, 2000);
            }else{
                var subject = $('.meetingTheme').val();
                var service_id = "123";
                var seq_no = 1;
                var url = "/xengine/meetings?service_id="+service_id+"&seq_no="+seq_no+"&uuid="+uuid;
                var auditInfo = {uuid:uuid.toString(), company:"livecom",name:"yxw",account:"51"};
                var hostPhone = current_members[0];
                var MemebersPhone = current_members.slice(1);
                
                var data = {audit_info:auditInfo, host:hostPhone, members:MemebersPhone};
                MeetingChannel.post(url, data, function (data) {						
                    activeMeetingID = data['session_id'];
                    c.reloadlist(data['member_info']);
                });
            }
            return false;
        };
        var stopMeeting_clicked = function (e) {
            e = e || window.event;
            e.preventDefault();
            e.stopPropagation();			
            var service_id = "123";
            var seq_no = 1;
            var session_id = activeMeetingID;
            var url = "/xengine/meetings?service_id="+service_id+"&seq_no="+seq_no+"&uuid="+uuid+"&session_id="+session_id;
            MeetingChannel.delete(url, {}, function (data) {
//                clearInterval(intervalID);
                activeMeetingID = null;
                c.reloadlist([]);
                c.startAction.show();
                meetingController.load_history();	
            });
            return false;
        };
        c.init = function (meeting_container) {
            c.pending_list = meeting_container.find('.meeting_box .inputText');
            c.pending_add = meeting_container.find('.meeting_pending_add');
            c.pending_add.click(pending_add_clicked);
            c.current_list = meeting_container.find('.meeting_current_list');
            c.stopAction = meeting_container.find('#meeting_stop_action');
            c.stopAction.unbind('click').bind('click',stopMeeting_clicked);				
            c.startAction = meeting_container.find('#meeting_start_action');
            c.startAction.unbind('click').bind('click',start_meeting_clicked);				
            c.history_list = meeting_container.find('.meeting_history_list');
        };

        c.checkActive = function () {
            var service_id = "123";
            var seq_no = 1;
//            var session_id = activeMeetingID;
            var url = "/xengine/meetings?service_id="+service_id+"&seq_no="+seq_no+"&uuid="+uuid;
            MeetingChannel.get(url, {}, function (data) {
                activeMeetingID = data['meetings']["session_id"];
                c.reloadlist(data['meetings']['member_info']);
            });
        };

        c.load_history = function () {
            var d = new Date();
            var y = d.getFullYear();
            var m = d.getMonth() + 1;
            api.meeting.history(uuid, y, m, function (data) {
                c.history_list.children().remove();
                var history = data['details'];
                for (var j = 0; j < history.length; j++) {
                    var members = history[j]['members'];
                    var subject = history[j]['subject'];
                    subject === '' || subject === "会议主题:新会议" ? subject = "新会议" : subject = subject;
                    var h = sprintf('<span class="gray">会议主题：</span> %s %s',  subject, '<span class="gray">' + history[j]['timestamp'] +'</span>');
                    var content = '';
                    for (var i = 0; i < members.length; i++) {
                        var value;
                        if (members[i]['name']) {
                            value = members[i]['name'] + ' ' + members[i]['phone'];
                        } else {
                            value = members[i]['phone'];
                        }
                        content += sprintf('@%s\n', value);
                    }
                    //var f = sprintf('会议时长：%s', members[0]['duration']+'s' );
					var f='';			
                    var ret = loadContent.format_message(h, content, f, { '重新发起': (function (members) {
                        return function () { c.reloadlist(members);   $("html, body").animate({ scrollTop: 0 }, 120);}
                    })(members)
                    });
                    c.history_list.append(ret);
                }
                $('#loading').hide();
            });
        };
        c.addto_current_list = function (name, phone) {
            phone = correctPhoneNumber(phone);
			if (!mobile_test(phone)) return false;			
            if (phoneDict[phone]) return false;
            phoneDict[phone] = 1;
            if (activeMeetingID) {
                var service_id = "123";
                var seq_no = 1;
                var auth_code = "auth";
                var session_id = activeMeetingID;
                var url = "/xengine/meetings/members?service_id="+service_id+"&seq_no="+seq_no+"&uuid="+uuid+"&auth_code="+auth_code+"&session_id="+session_id;
                var data = {name:name, phone:phone};
                MeetingChannel.post(url, data, function (data) {						
                    var member_id = data['member_info']['member_id'];
                    build_member_item(name, phone, 'connecting', member_id, function (li) {
                        memberID2Li[member_id] = li;
                        c.current_list.append(li);
                })});
            } else {
                build_member_item(name, phone, 'pending', '', function (li) {
                    if (c.current_list.children().length <= 0) {
                        li.addClass('meeting_source').find('.meetingHost').text('主持人');
                    }
                    c.current_list.append(li);
                });
            }
            return true;
        };
        c.reloadlist = function (initialMembers) {
            memberID2Li = {};
            phoneDict = {};
            c.current_list.children().remove();
            for (var i = 0; i < initialMembers.length; i++) {
                var phone = initialMembers[i]['phone'];
                phoneDict[phone] = 1;
                var name = initialMembers[i]['name'];
                var status = activeMeetingID ? 'connecting' : 'pending';
                var member_id = initialMembers[i]['member_id'] || '';
                phoneDict[phone] = true;
                build_member_item(name, phone, status, member_id, function (li) {
                    if (member_id) {
                        memberID2Li[member_id] = li;
                    } else if (i == 0) {
                        li.addClass('meeting_source').find('.meetingHost').text('主持人');
                    }
                    c.current_list.append(li);
                });
            }
            c.pending_add.click(function (e) {
                if ('' !== c.pending_list.val() && c.pending_list.val() != '输入电话号码/拼音或汉字') {
                    e = e || window.event;
                    e.preventDefault();
                    e.stopPropagation();
                    parsePendingList(c.pending_list, function (name, phone) {
                        c.addto_current_list(name, phone);
                    });
                    c.pending_list.val('');
                }
            });
            if (activeMeetingID) {
                c.startAction.hide();
				var interval = function(){	
				  api.meeting.get_status(uuid, activeMeetingID, function (data) {
                        changedMembers = data['members'];
                        if (!changedMembers || changedMembers.length == 0) {
                            api.meeting.stopmeeting(uuid, activeMeetingID, function (data) {
                                clearInterval(intervalID);
                                activeMeetingID = null;
                                c.reloadlist([]);
								c.startAction.show();
								meetingController.load_history();									
                            });
                        }
                        for (var i = 0; i < changedMembers.length; i++) {
                            var mid = changedMembers[i]['member_id'];
                            var status = changedMembers[i]['status'];
                            update_member_item(memberID2Li[mid], status, mid);
                        }
                    });	
				}
                var intervalID = setInterval(interval , 8000);
                c.stopAction.show();
            } else {
                c.stopAction.hide();
            }
        };
        return c;
    }
};

function Focus(){
    this.tag2Msgs = {"allFocuses":[], "untagedFocuses":[]};
    this.msg2Tags = {};
}
Focus.prototype = {
    init: function(data){
        this.tag2Msgs = {"allFocuses":[], "untagedFocuses":[]};
        this.msg2Tags = {};
        for (var i = 0; i < data.length; i++){
            this.setFocus(data[i]["type"], data[i]["content"]["entity_id"], data[i]["tags"]);
        }
        return true;
    },
    setFocus: function(type, msgid, tags){
        var oldTags = this.getTags(type, msgid);
        this.addMsgWithTag(type, msgid, "allFocuses");
        this.modifyTags(type, msgid, oldTags, tags);
    },
    cancelFocus: function(type, msgid){
        var oldTags = this.getTags(type, msgid);
        this.removeMsgWithTag(type, msgid, "allFocuses");
        if (oldTags.length === 0){
            this.removeMsgWithTag(type, msgid, "untagedFocuses");
        }else{
            for (var i = 0; i < oldTags.length; i++){
                this.removeMsgWithTag(type, msgid, oldTags[i]);
            }
        }

        if ((this.msg2Tags[type]) && (this.msg2Tags[type][msgid])){
            delete this.msg2Tags[type][msgid];
        }
    },
    isMsgIn: function(type, msgid){
        if ((this.msg2Tags[type]) && (this.msg2Tags[type][msgid])){
            return true;
        }else{
            return false;
        }
    },
    getExistingTagList: function(){
        var rslt = new Array();
        for (tag in this.tag2Msgs){
            if ((tag != "allFocuses") && (tag != "untagedFocuses")){
                rslt.push(tag);
            }
        }
        return rslt;
    },
    getTagsStatistics: function(){
        var rslt = {"allFocuses" : 0, "untagedFocuses" : 0};
        for (tag in this.tag2Msgs){
            rslt[tag] = this.tag2Msgs[tag].length;
        }
        return rslt;
    },
    getMsgsWithTag: function(Tag){
        if (this.tag2Msgs[Tag]){
            return this.tag2Msgs[Tag];
        }else{
            return [];
        }
    },
    getTags: function(type, msgid){
        if (this.msg2Tags[type] && this.msg2Tags[type][msgid]){
            return this.msg2Tags[type][msgid];
        }else{
            return [];
        }
    },
    resetMsg2Tags: function(type, msgid, tags){
        if (!this.msg2Tags[type]){
            this.msg2Tags[type] = {};
        }
        this.msg2Tags[type][msgid] = tags;
    },
    removeMsgWithTag: function(type, msgid, tag){
        var j = 0;
        while ((this.tag2Msgs[tag]) && (j < this.tag2Msgs[tag].length)){
            if ((this.tag2Msgs[tag][j]["type"] === type) && (this.tag2Msgs[tag][j]["msgid"] === msgid)){
                this.tag2Msgs[tag].splice(j, 1);
            }
            j++;
        }
        if ((tag != "allFocused") && (tag != "untagedFocuses") && this.tag2Msgs[tag] && (this.tag2Msgs[tag].length === 0)){
            delete this.tag2Msgs[tag];
        }
    },
    addMsgWithTag: function(type, msgid, tag){
        if(this.tag2Msgs[tag]){
            if (!this.containMsg(this.tag2Msgs[tag], type, msgid)){
                this.tag2Msgs[tag].push({"type":type, "msgid":msgid.toString()});
            }
        }else{
            this.tag2Msgs[tag] = [{"type":type, "msgid":msgid.toString()}];
        }
    },
    modifyTags: function(type, msgid, oldTags, newTags){
        if (oldTags.length == 0){
            this.removeMsgWithTag(type, msgid, "untagedFocuses");
        }else{
            for (var i = 0; i < oldTags.length; i++){
                this.removeMsgWithTag(type, msgid, oldTags[i]);
            }
        }
        if (newTags.length == 0){
            this.addMsgWithTag(type, msgid, "untagedFocuses");
        }else{
            for (var i = 0; i < newTags.length; i++){
                this.addMsgWithTag(type, msgid, newTags[i]);
            }
        }

        this.resetMsg2Tags(type, msgid, newTags);
        return true;
    },
    batchModifyTag: function(oldTag, newTag){
        //console.log('batch modify, oldTag:' + oldTag + '; newTag:' + newTag);
        var msgs = this.tag2Msgs[oldTag];
        delete this.tag2Msgs[oldTag];
        if (newTag === ""){
            for (var i = 0; i < msgs.length; i++){
                this.tag2Msgs["untagedFocuses"].push(msgs[i]);
            }
        }else{
            this.tag2Msgs[newTag] = msgs;
        }
        for (type in this.msg2Tags){
            for (msgid in this.msg2Tags[type]){
                var index = this.msg2Tags[type][msgid].indexOf(oldTag);
                if (index != -1){
                    if (newTag === ""){
                    this.msg2Tags[type][msgid].splice(index, 1);
                    }else{
                        this.msg2Tags[type][msgid][index] = newTag;
                    } 
                }
            }
        }
        return true;
    },
    containMsg: function(msgs, type, msgid){
        for (var i = 0; i < msgs.length; i++){
            if ((msgs[i]["type"] === type) && (msgs[i]["msgid"] === msgid)){
                return true;
            }
        }
        return false;
    }
};







function get_test_recycle_data(obj)
{
    var realData = {"status":"ok","recycle":[{"type":"topics","timestamp":"2012-9-08 23:4:5","content":{"entity_id":143,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 玛丽有一只小羊aaa"}},
                                           {"type":"tasks","timestamp":"2012-9-05 23:4:6","content":{"entity_id":151,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪aaa"}},
                                           {"type":"polls","timestamp":"2012-9-08 23:4:5","content":{"entity_id":144,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 玛丽有一只小羊bbb"}},
                                           {"type":"documents","timestamp":"2012-9-05 23:4:6","content":{"entity_id":154,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb","file_id":88, "file_length":76637, "name":"一个文件.docx"}},
                                           {"type":"topics","timestamp":"2012-9-08 23:4:5","content":{"entity_id":145,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 玛丽有一只小羊ccc"}},
                                           {"type":"tasks","timestamp":"2012-9-05 23:4:6","content":{"entity_id":153,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb"}}]};
    return realData["recycle"];
};

function get_test_search_result(obj)
{
    var realData = {"status":"ok","count":2, "tasks":[{"entity_id":151,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪aaa"},
                                            {"entity_id":153,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb"}],
                                  "topics":[{"entity_id":151,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪aaa"},
                                            {"entity_id":153,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb"}],
                                  "documents":[{"entity_id":154,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb","file_id":88, "file_length":76637, "name":"一个文件.docx"},
                                            {"entity_id":154,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb","file_id":88, "file_length":76637, "name":"一个文件.pdf"}],
                                  "questions":[{"entity_id":151,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪aaa"},
                                            {"entity_id":153,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb"}],
                                  "news":[{"entity_id":151,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪aaa"},
                                            {"entity_id":153,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb"}],
                                  "polls":[{"entity_id":151,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪aaa"},
                                                {"entity_id":153,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb"}]};
    return realData;
};

function get_test_sms_history(){
    var data = {"status":"ok", "history":[{"timestamp":"2012-7-8 23:4:5", "members":[{"name":"阿大", "phone":"008613654128952"},{"name":"阿傻", "phone":"008613654128454"},{"name":"阿强", "phone":"00861365411111"},{"name":"山鸡", "phone":"008613654128952"},{"name":"", "phone":"008613654128454"},{"name":"阿贵", "phone":"00861365411111"}], "content":"好饿啊，饭熟了没有啊，快上啊。。"},
                                                    {"timestamp":"2012-7-8 23:4:8", "members":[{"name":"阿大", "phone":"008613654128952"},{"name":"阿傻", "phone":"008613654128454"},{"name":"阿强", "phone":"00861365411111"}], "content":"神仙？妖怪？谢谢。。"}]};

    return data;
}

