var time;
var uuid;
var company;
var name2user = {};
var departmentArray = {};
var employer_status = new Array();
var subscriptArray = {};
var groupsArray = {}
var g_blinkid = 0;
var comt_index = "-1";
var current_page_index = { 'file_share_container':'1', 'mysend_msg':'1', 'current_task':'1', 'finish_msg':'1','topic_msg':'1', 'polls_msg':'1', 'questions_msg':'1' }
var allow_loading = 0;
var window_focus = true;
var reloginTime = 0;
var salaryHandle = new salaryHandle();
function testPhoneJson()
{
    return JSON.stringify({"mobile":"008618652938287","pstn":"02158895100","extension":"803","other":["04594490502","04594490502","04594490502","04594490502"]});
}
var userPhoneManage = {
    initEmployeeTels:function(phoneJson)
    {
        var phone = JSON.parse(phoneJson);
        return phone;
    },
    initSelfPhones:function()
    {
        var obj = $('#modifyperinof');
        obj.find('.mobile').eq(0).val(userPhoneManage.getEmployeeTel(parseInt(uuid),"mobile"));
        obj.find('.pstn').eq(0).val(userPhoneManage.getEmployeeTel(parseInt(uuid),"pstn"));
        obj.find('.extension').eq(0).val(userPhoneManage.getEmployeeTel(parseInt(uuid),"extension"));
        var array = new Array();
        var otherPhone = userPhoneManage.getEmployeeTel(parseInt(uuid),'other');
        for (var j = 0; j <= otherPhone.length - 1; j++) 
        {
            array.push('<tr><td><span class="tdTitle">' + lw_lang.ID_PHONE_OTHER + '</span><input type="text"  value="' + otherPhone[j] + '"  name="telephone" class="other" /></td>');
        };
        obj.find('.extension').parent().parent().after(array.join(""));
    },
    isEleInArray:function(ele,array)
    {
        if (array.length == 0)
        {
            return false;
        }
        else
        {
            if (ele == array[0])
            {
                return true;
            }
            else
            {
                return userPhoneManage.isEleInArray(ele,array.slice(1));
            }
        }
    },
    getAllEmployeeTel:function(uuid,except)
    {
        var i     = loadContent.employstatus_sub(uuid);
        var dom   = employer_status[i]['phone'];
        var array = new Array();
        for (key in dom)
        {
            var addTag = function(tele)
            {
                var obj = {};
                obj['num'] = tele;
                switch(key)
                {
                    case 'mobile':
                        obj['type'] = lw_lang.ID_PHONE_MOBILE;
                        break;
                    case 'pstn':
                        obj['type'] = lw_lang.ID_PHONE_PSTN;
                        break;
                    case 'extension':
                        obj['type'] = lw_lang.ID_PHONE_EXTENSION;
                        break;
                    case 'other':
                        obj['type'] = lw_lang.ID_PHONE_OTHER;
                        break;
                    default:
                        break;
                } 
                return obj;
            };
            var value = dom[key];
            if (!userPhoneManage.isEleInArray(key,except))
            {
                if (key == 'other')
                {
                    if (value.length != 0)
                    {
                        array = array.concat(value.map(addTag));
                    }
                }
                else
                {
                    if ((value != "") && (value != undefined))
                    {
                        array.push(addTag(value));
                    }
                }
            }
            else
            {
                continue;
            }
        }
        return array;
    },
    getEmployeeTel:function(uuid,which)
    {
        var i   = loadContent.employstatus_sub(uuid);
        var tel = "";
        switch(which)
        {
            case undefined:
                tel = employer_status[i]['phone']["mobile"];
                break;
            default:
                tel = employer_status[i]['phone'][which];
                break;
        }
        return (tel == undefined ? "" : tel);
    },
    userSelectPhone:function (who,except,ok,fail)
    {
        var allTeleNums = userPhoneManage.getAllEmployeeTel(who,except);
        if (allTeleNums.length == 0)
        {
            fail();
        }
        else if ((allTeleNums.length == 1) && isPhoneNum(allTeleNums[0]['num']))
        {
            ok(allTeleNums[0]['num']);
        }
        else if ((allTeleNums.length == 1) && !isPhoneNum(allTeleNums[0]['num']))
        {
            fail();
        }
        else if (allTeleNums.length > 1)
        {
            var setContent = function(){
                var html = '<div id="choice_phone"><ul>';
                    html += '<li><input type="radio" name="phone" checked="checked" value="' + allTeleNums[0]['num'] + '">' + allTeleNums[0]['type'] + allTeleNums[0]['num'] + "</li>"
                for (var i = 1; i <= allTeleNums.length - 1; i++){
                    html += '<li class=""><input type="radio" name="phone" value="' + allTeleNums[i]['num'] + '">' + allTeleNums[i]['type'] + allTeleNums[i]['num']+"</li>";
                }
                html += '</ul></div>';
                return html;
            };
            var ItemHandle = function(){
                $('#choice_phone').find('li').live('click', function(){
                    $(this).find('input:radio').attr('checked', true);
                })
            }

            var callBack = function()
            {

                var phone = $('#choice_phone').find('input[name="phone"]:checked').val();

                if (isPhoneNum(phone))
                {
                    ok(phone);
                }
                else
                {
                  fail();
                }
            };
            art.dialog({title:lw_lang.ID_PHONE_CHOICE,
                    content: setContent(),
                    lock: true,
                    fixed: true,
                    width: 480,
                    height: 60,
                    init:ItemHandle,                    
                    button: [{name:lw_lang.ID_OK,focus:true,callback:callBack},
                             {name: lw_lang.ID_CANCEL}]});
        }
    },
    init:function()
    {
        var clickEvent = function(e)
        {
            var last = $('#modifyperinof').find('.other').last();
            if ("" != last.val())
            {
                $('#modifyperinof').find('.other').each(
                function()
                {
                    if ("" == $(this).val())
                    {
                        $(this).parent().parent().remove();
                    }
                });
                $('.add_other_phone').remove();
                last.parent().parent().after('<tr><td><span class="tdTitle">' + lw_lang.ID_PHONE_OTHER + '</span><input type="text"  value=""  name="telephone" class="other" /><a href="###" class="add_other_phone"></a></td></tr>');
                $('.add_other_phone').unbind('click').bind('click',clickEvent);
            }
            return false;
        }
        $('.add_other_phone').unbind('click').bind('click',clickEvent);
    },
    getUserSetPhone:function()
    {
        var result = true; 
        var phone = {"mobile":"","pstn":"","extension":"","other":[]};
        var dom   = $('#modifyperinof').find('input:[name="telephone"]');
        var checkFun = {"mobile":function(num){return true/*(isPhoneNum(num) || num == "")*/},
                        "pstn":function(num){return true/*(isPhoneNum(num) || num == "")*/},
                        "extension":function(num){return true/*(num == num.match(/\d{1,}/) || num == "")*/},
                        "other":function(num){return true/*(isPhoneNum(num) || num == "")*/}};
        var okFun = {"mobile":function(num){phone["mobile"] = num},
                     "pstn":function(num){phone["pstn"] = num},
                     "extension":function(num){phone["extension"] = num},
                     "other":function(num){if (num != "") {phone["other"].push(num)}}};
        dom.each(function()
        {
            var className = $(this).attr('class');
            var num = $(this).val();
            if (checkFun[className](num))
            {
                okFun[className](num);
            }
            else
            {
                result = false;
                return false;
            }
        });
        if (result)
        {
            return phone;
        }
        else
        {
            return false;
        }
    }
};

$(window).bind("scroll", function (event){
    var top = document.documentElement.scrollTop + document.body.scrollTop;	
    var textheight = $(document).height();	
    if(textheight - top - $(window).height() <= 100) { if (allow_loading >= 1) { return; }
      allow_loading++;
   	  loadContent.loadmore_msg();
    }
});
$(window).bind( 'blur', function(){ window_focus = false; }).bind( 'focus', function(){ window_focus = true; });  
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
    else if(phone[0]=="*"){
        return phone;
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
            class_name = isUserExternalEmployee(temp_id) ? get_eid_class_name_by_uuid(temp_id) : employid;
			if(arr1[subtag].status  === offline){
			   arr1[subtag].status = online;			   
		       if(link_href === 'recontact'){
			     $('#recontact').addClass('isupdate')				 
			   }else{
				 var obj = $('.' + class_name).parent().parent().find('.structre');		
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
function getAreaVal(obj, contentEdit){
   if(contentEdit&& contentEdit === true){
        var div = document.createElement("div");
        $(div).html(obj.html())
        $(div).find('.tag').remove();
        val =  $(div).text();
    }else{
        val = obj.val();
    }
     return jQuery.trim(val);
}

//输入字符限制
function confine(maxNum, opt, flag ) {
    var oConBox = opt.oConBox, 
        oSendBtn = opt.oSendBtn, 
        oMaxNum = opt.oMaxNum, 
        oCountTxt = opt.oCountTxt, 
        iLen = 0,
        val = getAreaVal(oConBox, opt.editdiv), 
        num, oMaxNumText;
        for (var i = 0; i < val.length; i++) {
            iLen +=  1 ; 
        }
        num = (flag !== 1 ? maxNum - Math.floor(iLen) :  Math.floor(iLen));
        oMaxNum.text(maxNum - Math.floor(iLen));
        ((num > 0) && (num <= maxNum)) ? (oMaxNum.css('color', "#828282"), oSendBtn.removeClass('disabledBtn'), loadContent.bSend = true) : (oMaxNum.css('color', "red"), oSendBtn.addClass('disabledBtn'), loadContent.bSend = false);
}

function contact_scroll(){
	oScrollbar.tinyscrollbar_update("relative");
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

function ManageSoundControl(action, num) {
    var sc = document.getElementById("soundControl");
    if(action == "play") {
        sc.playcount = (num ? num.toString() : "1");
        sc.play();
    }else if(action == "stop") {
        sc.pause();
        sc.playcount = "1";
    }
}

function IMWSClientInit(){
    var imws = new wsClient(getIMWebSocketURL(), function(data){
            imClient.onReceivedMsg(data);
        },
        function(){
            //console.log('im websocket established ok.');
        }, 
        function(){
            //console.log('im websocket broken.');
        }
    );
    if (imws.connect){
        imws.connect();
    }    
}

function setconner_position(obj, conner_parent){
   var left = obj.position().left,
       top = obj.position().top;
       conner_parent.find('.float_corner').css({'left':left + 10, 'top':top + 32, 'display':'block'});
}
function floatConnerHandle(obj, css){
    var connerParent = obj.find('.' + css  );
      connerParent  .css('display') == 'block' ? (
      obj.find('.float_corner').hide(),
      connerParent.slideUp()) : 
      connerParent.slideDown(500, function(){ 
      obj.find('.float_corner').show() 
    });

}
var imClient = new imClient();
var wVideo = new webVideo();
var voip = new Voip();
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
       if($.cookie('company') != 'livecom'){
          $('#nav').find('.salary , .email, .forum').hide();
       }
        loadContent.initrequest();
        loadContent.bind('goback', loadContent.goback, 'id');
        loadContent.bind('tab_item li', loadContent.modeswitch, 'class');
		loadContent.bind('contact_tab a', loadContent.loadaddressbook, 'class');
        loadContent.bind('editg_btn', loadContent.modifygroup, 'class');
        loadContent.bind('nuread_comt', loadContent.loadunreadcomt, 'class');
        loadContent.bind('nuread_msg', loadContent.loadunreadmsg, 'class');
        loadContent.bind('vedio_notice', loadContent.vedio_noticehandle, 'class');
        loadContent.dynamichandle();
		loadContent.modify_images();
		//loadContent.upload_file();
        wVideo.bindHandlers();
        voip.bindHandlers();
        userPhoneManage.init();
	    $('input[type=text]').each(function () {
            var txt = $(this).val();
            $(this).searchInput({
                defalutText: txt
            });
        })
	   var val =  $('#questions').find('.lwork_mes').val();
	   $('#questions').find('.description_input').searchInput({
			defalutText: lw_lang.ID_DESCRIBTION
		});
	   $('#questions').find('.lwork_mes').searchInput({
			defalutText: val
		});
	   $('.Interrupt').click(function(){ 	 
          if(!$.cookie('nologin')){
    	    loadContent.reLogin();
          }else{
              var data = {'uuid':uuid, 't': new Date().getTime()};
              $.post('/lwork/auth/enter', JSON.stringify(data) ,function(data){
                  if(data.status === 'ok'){
                     window.location = "default.yaws?uuid=" + data['uuid']; 
                  }else{
                     alert(lw_lang.ID_INNITIALIZING_FAILED);
                  }
                 })
              }
		 })
         $('#shortmsg').find('.shortmsg_content').searchInput({
			 defalutText: lw_lang.ID_SMS_CONTENT
	      });
	     $('#alert').find('.close , .concel').click(function(){  $('#alert').slideUp();})
    },
    reLogin:function(){    
      if($.cookie('company') &&  $.cookie('account') &&  $.cookie('password') ){
         var data = {'company': $.cookie('company'), 'account': $.cookie('account'),'password':  $.cookie('password'), 'deviceToken': '', 't': new Date().getTime()};
        $.ajax({
          type: 'POST',
          url: '/lwork/auth/login',
          data: JSON.stringify(data),
          dataType: 'JSON',
          success: function(data){            
                  if(data.status === 'ok'){
                    $('.Interrupt').hide();
                    if(reloginTime > 5){
                      employer_status = [];
                      loadContent.loadallgroupmember(groupsArray['all']['employer_uuid']);  
                    }
                    clearInterval(time);
                    time = setInterval(loadContent.load_interval, 12000);
                  }else{
                     if($.cookie('company') === 'wuhansourcing') { window.location = "whs_index.html";  return false;}
                     window.location = "index.html";     
                  }
              },
          error:function(){
            reloginTime++;
           }
        });
      }
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
                case 'email':
                    $('#nav .email a').click();
                    $('.dynamic').find('.email').hide();
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
        if(linkhref === 'email'){
          $('#email').show().prev().hide().prev().hide();
        }else{
          $('#email').hide().prev().show().prev().show();
          obj_link.siblings().hide();    
          linkhref === 'org_structure' || linkhref === 'group_list' || linkhref === 'recontact' ? ( $('.jscroll-c').css('top',0) , obj_link.fadeIn(400,contact_scroll)) : obj_link.fadeIn();
        }
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
		var _this = $(this).find('a'),        
            linkhref = _this.attr('link'),
            obj_link = $('#' + linkhref),
		    temp_obj = $('.tab_item');
            loadContent.tabswithch(_this);
        if(linkhref == 'salary'){
		  $('#salary_msg').html('可点击查询按钮查询你的工资单情况！')
          salaryHandle.init();
          return false;
        }
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
            target: $('#' + linkhref),
			symbol:'@',
			bind_confine:'yes',
			from:'weibo'
        });
        $.cookie('current_tab', linkhref);
		loadContent.loadmsg_handle(linkhref, "1");
    },
	loadmore_msg: function(){
		var link_href, comtlink, page_index ;	
		    link_href = $('.tab_item').find('.curent').attr('link');
			if(link_href === 'questions' || link_href === 'news' || link_href === 'forum') return ;
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
        $('.forum_box').hide().prev().show();
		$('#alert').fadeOut();
        switch (linkhref) {
            case 'documents':
                if ('no' === $('#file_share_container').attr('containdom')|| '' !== loadmore) {
                    loadContent.loadmsg('documents', 'none', 'read', 'file_share_container', page_index, 2 , callback);
                    $('#file_share_container').attr('containdom', 'yes');
                }
                break;				
            case 'tasks':
                obj_link.find('.task_menu li').unbind('click').bind('click', loadContent.subMenuHandle);
                if ('no' === $('#current_task').attr('containdom')|| '' !== loadmore) {
                    loadContent.loadmsg('tasks', 'assigned', 'unfinished', 'current_task',  page_index, 2,  callback);
                    $('#current_task').attr('containdom', 'yes');
                }
                break;
            case 'topics':		
                obj_link.find('.menu li').unbind('click').bind('click', loadContent.subMenuHandle);		
                if ('no' === $('#topic_msg').attr('containdom') || '' !== loadmore) {					
                    loadContent.loadmsg('topics', 'none', 'all', 'topic_msg', page_index, 2, callback);
                    $('#topic_msg').attr('containdom', 'yes');
                }
                break;
            case 'video':
			    loadContent.navigator_check();		
				break;		
            case 'forum':
              //  obj_link.find('.upload_image').upload_file({ contian_attachment : 'yes'});
               // obj_link.find('.upload_attachment').upload_file({'start': 'attachment', contian_attachment : 'yes'});
                $('.forum_box').show().prev().hide();
                load_forum_categories();
                break;      
            case 'mail':
                load_mail_menu();
                break;      
            case 'polls':
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
					 meetingController.load_history();
					obj_link.find('.inputText').membersearch({
						target: $('#' + linkhref),						
                        isgroup: 'no',
						showNumberTip:'yes',
						from:'meeting'
					})
				   obj_link.attr('containdom', 'yes');
			    }
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
			    loadContent.navigator_check();		
			    obj_link.find('.peerNum').membersearch({
                    target: $('#' + linkhref),
					isgroup: 'no',
					showNumberTip:'yes',
					from:'voip'
                });
				break;
            case 'shortmsg':
                $('#loading').hide();
                obj_link.find('#sendShortMsg').unbind('click').bind('click', loadContent.sendShortMsg);
                obj_link.find('#view_shortmsg_history').unbind('click').bind('click', loadContent.viewHistoricalShortMsg);
                obj_link.find('.shortmsg_content').eq(0).unbind('keyup').bind('keyup', loadContent.checkShortMsgInput);
                $('#sendsms_input_tag').membersearch({
					from: 'shortmsg',
					target: $('#' + linkhref),
					isgroup: 'no',
					showNumberTip:'yes',
                    bindTagInput:'yes',
					symbol: ';'	
                });	
                break;
            default:			
                break; 
        }
	},
    subMenuHandle: function () {
        var obj = $(this);
        var linkhref = loadContent.tabswithch(obj),
		    status = obj.attr('status'),
            mode = obj.attr('mode'),
		    type = obj.attr('type');
        if('topic_content' == linkhref) linkhref = 'topic_msg';   
        if (status != 'reply') {
           if ('no' === $('#' + linkhref).attr('containdom')) {
                loadContent.loadmsg(mode, type, status, linkhref ,'1');
                $('#' + linkhref).attr('containdom', 'yes');
           }
        } else {
            if ('no' === $('#' + linkhref).find('.newcomt_wrap').attr('containdom')) {
                loadContent.loadnewcomt(mode, linkhref);
                $('#' + linkhref).find('.newcomt_wrap').attr('containdom', 'yes');
            }
        }
    },//初始化获取群组
    navigator_check: function () {
      var isChrome = window.navigator.userAgent.indexOf("Chrome") !== -1;		 
      if (!isChrome) {
        var left = parseInt(document.body.clientWidth)/2 - 330 + 'px';
        $('#alert').css('left', left) .fadeIn();
      }
    },
    initrequest: function () {
        if ($.cookie('uuid')) {
			uuid = $.cookie('uuid').toString();	
            $('#loading').show();
            IMWSClientInit();
            api.request.get('/lwork/auth/profile', { 'uuid':uuid , 't':new Date().getTime() }, function (data) {
               var html = '';
               var groups = data.groups;
               var convertname;
               var all_group_id;
               company = data['hierarchy']['short_name'];
			   $.cookie('company', company, {expires: 30});
               $('#username').text(data.profile.name).parent().show();				
               for (var i = 0; i < groups.length; i++) {							
                    var group = groups[i];
					var group_members = {};
                    if (group['name'] === 'all') {
                       all_group_id = group['group_id'];					
                       groupsArray['all'] = { 'name': 'all', 'employer_uuid': all_group_id , 'convertname': 'ALL' };									
                    } else if(group['name'] === 'recent') {				
					   groupsArray['recontact'] = { 'name': 'recontact', 'employer_uuid': group['group_id'], 'members': group['members'],  'convertname': ''};					
                    } else {							
                       html += ['<li class="department  department_'+ group['group_id'] +'"> <a href="###" department_id="' + group['group_id'] + '" class="group structre"><span class="members_name" title = "' + group['name'] + '">' + group['name'] + '</span><span class="members_tongji"></span></a> <span class="send_department"  titile="lw.lang.ID_AT_DEPARTMENT"></span></li>'
						   ].join("");
                       convertname = ConvertPinyin(group['name']);
					   name2user[group['name']] = {'group_id':group['group_id']};					   
					   if(group['members'].length > 0)	{
						   groupsArray[group['group_id']] = {'name': group['name'], 'members': group['members'] , 'convertname': convertname.toUpperCase()};						   
					    }else{
						   groupsArray[group['group_id']] = {'name': group['name'], 'members': { }, 'convertname': convertname.toUpperCase()};
						}
                    }
                }
				html += ['</ul>'].join("");	
				loadContent.create_structure(data['hierarchy']['departments']);
                $('#group_list').append(html);							
                //loadContent.loaddepartment(data['profile']);				
                if ($('#customgroup').find('li').length <= 0) $('.mygroup').hide();		
                loadContent.loadallgroupmember(all_group_id,function(){loadContent.loaddepartment(data['profile']);});							
                BindExternalEnterpris(data.external);  //      
			    loadContent.bind('structre', loadContent.org_structure_itemclick, 'class');				
				loadContent.bind('creategroup', loadContent.creategroup, 'id');	
                loadContent.personalgroup_handle();
                loadContent.setpersonal();
                loadContent.fetchFocusData();
                $('#search_input').searchSuggest();				
                loadContent.bind('searchbutton', loadContent.searchIt, 'class');
				   $('#loading').hide();
            }, function () {
                LWORK.msgbox.show(lw_lang.ID_BUSY_LOGIN, 1, 2000);
				$('#loading').hide();
             //   window.location = "index.html";
            })
        } else {
            LWORK.msgbox.show(lw_lang.ID_LOGIN_FIRST, 1, 1000);
			if($.cookie('company') === 'wuhansourcing') { window.location = "whs_index.html";  return false;}
            QueryString('language') == 'en' ?  window.location = "index.html?language=en" :  window.location = "index.html" ;          
        }
    },
	create_structure: function(departments){
	  var department_id; 	  
	  function createDom(opt){
		  var dom ="<ul>";
		  for(var j = 0 ; j< opt.length ; j++){
		    dom += ['<li class="department  department_'+ opt[j]['department_id'] +'"> <a class="structre"  department_id = "'+ opt[j]['department_id'] +'" href="###"><span class="members_name"  title = "' + opt[j]['department_name'] + '">'+ opt[j]['department_name'] +'</span><span class="members_tongji"></span></a><span class="send_department"  titile="'+lw_lang.ID_AT_DEPARTMENT+'"></span></li>'].join("");
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
       //obj.find('.telephone').val(data['phone']);
       obj.find('.email').val(data['mail']);
       userPhoneManage.initSelfPhones();
    },
    loadallgroupmember: function (group_id,callback) {
        api.group.get_members(uuid, group_id, function (data) {
            if (data.status === 'ok') {
                var value, len, str;
                var temp = {}, temp1 = {}, convertname;
                var getmembers = new Array;
				len = data.members.length;
                for (var i = 0; i < len; i++) {
                    value = data.members[i];
                    convertname = ConvertPinyin(value.name);
                    temp = { 'uuid': value.member_id, 'name': value.name, 'employid': value.empolyee_id, 'phone': userPhoneManage.initEmployeeTels(value.phone) /*value.phone*/, 'department': value.department, 'mail': value.mail,'photo': value.photo, 'convertname': convertname.toUpperCase(), 'name_employid': value.name + value.empolyee_id, 'status': value.status , 'department_id': value.department_id };
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
              // loadContent.fill_members_tonji(departmentArray);
			  // loadContent.fill_members_tonji(groupsArray);			   
                if ($.cookie('current_tab')) {
                    var current_tab = $.cookie("current_tab");
                    $('.' + current_tab).find('a').click();
                } else {
					$('.focus').find('a').click();
                }
				meetingController.checkActive();
                loadContent.load_interval();
				$('.sea_member_input').filter_addressbook();
                time = setInterval(loadContent.load_interval, 12000);
				loadContent.blinkNewMsg();
                if(callback)callback();
                add_external_employees(external_members);    
                loadContent.fill_members_tonji(departmentArray);
                wVideo.ready();
                voip.prepareToCall();
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
    showemployer: function (arr,container,append_flag) {
        var html = '', html2 = '';
		var temp_id , subtag;
        var newarr = new Array(); 
        //console.log(arr,container, append_flag)
	    for (var key in arr){			
			subtag = subscriptArray[arr[key]];
		    newarr.push(employer_status[subtag]);
	    }
		newarr = newarr.sort(array.sort_Aarray);
        for (var i=0 ; i < newarr.length; i++) {
		  if(newarr[i]){	
              var markname = newarr[i].markname;
              var marksuffix = markname ? "@"+markname : "";
              var phone = userPhoneManage.getEmployeeTel(parseInt(newarr[i]["uuid"]));
             if (newarr[i].status === 'online') {
                html += ['<li class="online employer_list ' + eid_class_name(newarr[i].employid,markname) + '">',
                        '<img src="' + newarr[i].photo + '" width="38" height="38"/>',
                        '<a href="###" name="' + newarr[i].name + '" phone="' + phone/*newarr[i].phone*/ + '" mail="' + newarr[i].mail + '" class="sendmsn" uuid="' + newarr[i].uuid + '">',
                        '<span class="employ_name">' + newarr[i].name + '</span>',
                        '<span class="employ_id">' + newarr[i].employid+marksuffix + '</span></a>',
                        (newarr[i].uuid == uuid) ? '':'<a href="###" title="'+lw_lang.ID_IM_START_IM+'"  uuid="' + newarr[i].uuid + '" class="buddyChat"></a>',
                        '</li>'
					 ].join("");

             } else {                
                html2 += ['<li class="offline employer_list ' + eid_class_name(newarr[i].employid,markname) + '">',
                            '<img src="' + newarr[i].photo + '" width="38" height="38"/>',
                            '<a href="###" name="' + newarr[i].name + '" phone="' + phone/*newarr[i].phone*/ + '" mail="' + newarr[i].mail + '" class="sendmsn" uuid="' + newarr[i].uuid + '">',
                            '<span class="employ_name">' + newarr[i].name + '</span>',
                            '<span class="employ_id">' + newarr[i].employid+marksuffix + '</span></a>',
                            '</li>'
					 ].join("");
             }
		  }

        }
        html += ['' + html2 + ''].join("");
		if(container.attr('id') !== 'search_employer'){			
	        if(container.find('ul').length > 0)  {
                append_flag ? container.find('ul').append(html):container.find('ul').html(html)
            } else {
                container.append('<ul>' + html + '</ul>');
            }
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
        imClient.bindHandlers();		
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
         var external_flag =isUserExternalEmployee($(this).find('a').attr('uuid'));
         $(this).find('.buddyChat').show();
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
			(current_mode === 'org_structure' && !external_flag) ? html += '</div>' : html += '<div id="delgroupmember" class="delgroupmember" title = "'+lw_lang.ID_DELETE_MEMBER+'"></div></div>';
            timeout = setTimeout( function () {
			   totips.showtip(obj, html,-55, 10, 'down');
			   $('#delgroupmember').die('click').live('click', function () {
                    if (!external_flag) {
    					api.group.delete_members(uuid, group_id.toString(), employer_uuid, function (data) {			
    						groupsArray[group_id] ? delete groupsArray[group_id]['members'][employer_uuid]: delete groupsArray['recontact']['members'][employer_uuid];					
    						hide();
    						obj.parent().remove();
    						LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 4, 1000);					
    					}, function () { LWORK.msgbox.show(lw_lang.ID_SERVER_BUSY, 1, 2000); $('#loading').hide(); });
                    }else {
                        var ok_fun =function() {
                            groupsArray[group_id] ? delete groupsArray[group_id]['members'][employer_uuid]: delete groupsArray['recontact']['members'][employer_uuid];                  
                            hide();
                            obj.parent().remove();
                            deleteMemberInExternalDep(employer_uuid);
                            LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 4, 1000);
                        }
                        restDeleteExternalEmployee(uuid, employer_uuid, ok_fun);
                    }
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
        }).bind('mouseout', function () { 
            $(this).find('.buddyChat').hide();
            clearTimeout(timeout); 
        });
    }, //自定义组添加右键菜单
	createtipsDom: function(i ,css){
        var fun = function()
        {
           var array = new Array(),
                mobile =  userPhoneManage.getEmployeeTel(parseInt(employer_status[i]["uuid"]),'mobile'),
                pstn = userPhoneManage.getEmployeeTel(parseInt(employer_status[i]["uuid"]),'pstn') ,
                extension = userPhoneManage.getEmployeeTel(parseInt(employer_status[i]["uuid"]),'extension');
          if('' !== mobile) array.push('<li><span class="check_bt">'+lw_lang.ID_PHONE_MOBILE+'</span>' + mobile + '</li>');
          if('' !== pstn) array.push('<li><span class="check_bt">'+lw_lang.ID_PHONE_PSTN+'</span>' + pstn + '</li>');
          if('' !== extension) array.push('<li><span class="check_bt">'+lw_lang.ID_PHONE_EXTENSION+'</span>' + extension + '</li>');
            var otherPhone = userPhoneManage.getEmployeeTel(parseInt(employer_status[i]["uuid"]),'other');
            for (var j = 0; j <= otherPhone.length - 1; j++) 
            {
                array.push('<li><span class="check_bt">'+lw_lang.ID_PHONE_OTHER+'</span>' + otherPhone[j] + '</li>');
            };
            return array;
        }
        var myhtml = 
               ['<div class="'+ css +'">',
                '<img src="' + employer_status[i].photo + '" width="48" height="48">',
                '<ul class="tipsdetail"><li><span class="check_bt">'+lw_lang.ID_NAME+'</span>' + employer_status[i].name + '</li>',
                '<li><span class="check_bt">'+lw_lang.ID_EMPLOYEE_NO+'</span>' +  employer_status[i].employid + '</li>',
                '<li><span class="check_bt">'+lw_lang.ID_DEPT+'</span>' + employer_status[i].department + '</li>',
                '<li><span class="check_bt">'+lw_lang.ID_EMAIL2+'</span>' + employer_status[i].mail + '</li>'].concat( 
                fun(),['</ul>'],
               ['<div class="tips_buttom"><ul>',
                '<li class="tasks" title="'+lw_lang.ID_TAKE_WORK+'"><a href="###"></a></li>',                   
                '<li class="topics" title="'+lw_lang.ID_TAKE_WEIBO+'"><a href="###"></a></li>',
                '<li class="meeting" title="'+lw_lang.ID_CONFERENCE_CALL+'"><a href="###"></a></li>',
                '<li class="shortmsg" title="'+lw_lang.ID_TEXTING+'"><a href="###"></a></li>',                  
                '<li class="voip" title="'+lw_lang.ID_VOIP+'"><a href="###"></a></li>',
                '<li class="video" title="'+lw_lang.ID_MAKE_CONF+'"><a href="###"></a></li>',                   
                '</ul></div>']);
        return html = myhtml.join("");
	},
	contentmemberdetail: function(){
	  var timeout;
	  $('.lanucher').unbind('mouseover').bind('mouseover', function () {
		  var _this = $(this);
		  var employ_uuid = _this.attr('employer_uuid');		  
	      var i = subscriptArray[employ_uuid];	  
		  if(!employer_status[i]) {
              return;
          }
		  var html =  loadContent.createtipsDom(i, 'tipcontent2');		
	      var hide = function(){ if($('#floattips').find('.tipcontent2').length > 0) totips.hidetips(); }		
          needAdd2ExternalDep(employ_uuid) ? html += '<div id="addExternalEmployee" class="addgroupmember" title = "'+lw_lang.ID_ADD_ECTERNAL+'"></div></div>' : html += '</div>';
            $('#addExternalEmployee').die('click').live('click', function () {
                restAddExternalPartner([{account:employer_status[i].employid,
                    markname:getMarkname(employ_uuid), mail:'', phone:''}]);
            }); 
		 timeout = setTimeout(function () { totips.showtip( _this, html , -198 ,207,'top');		
				$('#floattips ').mouseleave(hide);
				$('#nav').mouseenter(hide);
				$('.slide_box').mouseenter(hide);
				_this.parent().parent().siblings().mouseenter(hide);
                _this.parent().next().mouseenter(hide);
				_this.parent().parent().find('.pagefoot').mouseenter(hide);
				$('.tips_buttom').find('a').die('click').live('click', function () {
					var link_obj = $(this).parent().attr('class');
					$('.tab_item').find('.' + link_obj).click();	
					loadContent.fill_text(employ_uuid);
					hide();					
				});
		 }, 1000);		    
	  })
	   $('.personal_icon').unbind('mouseover').bind('mouseover', function () {	
		 $(this).next().find('.lanucher').mouseover();	   
	   })
	   $('.lanucher , .personal_icon').unbind('mouseout').bind('mouseout', function () { clearTimeout(timeout); });	  
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
                   var tempid = 'select' + parseInt(Math.random()*10E20);
                   var btn;
				    if(current_id === "documents"){
                       target = $('#floattipsshare'); 
                       mesText = target.find('.lwork_mes').val();
                       target.find('.lwork_mes').focus().val(mesText + ' @' + txt + ' ');
                    }else{
    				  if(current_id !== "questions"){
                          loadContent.AddEmployDom(target, txt);
                          if (current_id === 'shortmsg'){
                            loadContent.addGroup2ShortMsgReceivers(txt);
                          }	
    				  }
                   }
				   return false;				   
				})		
        var imageMenu1Data = [
                [{ text: lw_lang.ID_ADD_MEMBER,
                    func: function () {
						var _this = $(this);
						var group_id = _this.attr('department_id');
						var group_name = _this.text();
                        loadContent.modifygroup(group_id , group_name , _this);
                    }
                }],
                [{ text: lw_lang.ID_CHANGE_GROUPNAME,
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
								    LWORK.msgbox.show(lw_lang.ID_GROUP_INCLUDED, 2, 1000);
									$('.modifygroupname').find('input').focus();
									return false;
								}
							}
						  if ('' !== new_name && lw_lang.ID_INPUT_GROUPNAME !== new_name && new_name.indexOf(' ') < 0) {
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
                                    LWORK.msgbox.show(lw_lang.ID_CHANGE_SUCCESS, 4, 1000);
                                }
                            });
						  }else{
							  LWORK.msgbox.show(lw_lang.ID_GROUPNAME_EMPTY, 2, 1000);
							  $('.modifygroupname').find('input').focus();
						  }
                        });
                    }
                }],
                [{
                    text: lw_lang.ID_DELETE_GROUP,
                    func: function () {
                        var obj = $(this);
						var group_id = obj.attr('department_id');				
                        loadContent.createGeneralConfirm(obj, lw_lang.ID_SURE_DELETEGROUP, '', function() {
                            api.group.delete_group(uuid, group_id.toString(), function (data) {
                                if (data.status === 'ok') {
                                    obj.parent().remove();
                                    if ($('#group_list').find('li').length <= 0) $('.mygroup').hide();
                                    LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 4, 1000);
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
    creategroup: function () {
        var creatgroupbox = document.getElementById('creatgroupbox');
        var obj = $('#creatgroupbox');		
		var fun = function () {
            var groupname = obj.find('input').val();
            for (var key in groupsArray) {
                if (groupname == groupsArray[key]['name'] || groupname.toUpperCase() === 'RECENT') {
                    obj.find('.modify_tips').text(lw_lang.ID_GROUP_INCLUDED).show();
                    $('#creatgroupbox').find('input').focus();
                    return false;
                }
            }
            if ('' !== groupname && lw_lang.ID_INPUT_GROUPNAME !== groupname && groupname.indexOf(' ') < 0) {
                api.group.create_group(uuid, groupname, 'ww', function (data) {					
                    var a = $('<li class="department  department_'+ data['group_id'] +'"> <a href="###" department_id="' + data['group_id'] + '" class="group structre"><span class="members_name" title = "' + groupname + '">' + groupname + '</span><span class="members_tongji"></span></a> <span class="send_department"  titile="lw.lang.ID_AT_DEPARTMENT"></span></li>');
 				    $('#group_list').append(a).parent().show();
				    loadContent.bind('structre', loadContent.org_structure_itemclick, 'class');
                    obj.find('input').val('');
                    LWORK.msgbox.show(lw_lang.ID_ADDGROUP_SUCCESS, 4, 1000);					
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
                $('#creatgroupbox').find('.modify_tips').text(lw_lang.ID_CREATE_GRUOP).show();
                $('#creatgroupbox').find('input').focus();
				return false;
            }
        }
	   var dialog = art.dialog({
            title: lw_lang.ID_NEWGROUP,
            content: creatgroupbox,
            id: 'creategroup_dialog',
            lock: true,
            fixed: true,
            width: 300,
            height: 120,
			button: [{
			  name: lw_lang.ID_OK,
			  focus: true,
			  callback:  fun
			},{
				 name: lw_lang.ID_CANCEL
			}]			
        });		
        obj.find('input').keyup(function () { obj.find('.modify_tips').hide(); })
        obj.find('input').searchInput({
            defalutText: lw_lang.ID_INPUT_GROUPNAME
        });
        obj.find('input').keyup(function () { $('#creatgroupbox').find('.tips').hide(); }) 
    },
    modifygroup: function (group_id, group_name, _this) {
        var modifygroupbox = document.getElementById('modifygroupbox');
		var fun = function () {
            var temp = [];
            var temp_item, temp_str = '';
	        var newstr = $('#add_member').attr('data');
	     	newstr.indexOf(';') > 0 ? temp = newstr.split(';') : temp[0]  = newstr ;
			for(var i = 0; i < temp.length; i++ ){
		      groupsArray[group_id.toString()]['members'][temp[i]] = temp[i] ;
			}
            api.group.add_members(uuid, group_id.toString(), temp, function (data) {
                $('#add_member').attr('data', '').val('');
                $('#add_member_tagsinput').find('.tag').remove();
                $('#addmemberlist').html('');
				loadContent.showemployer(groupsArray[group_id.toString()]['members'], _this.parent());
            });
        };
        var dialog = art.dialog({
            title: lw_lang.ID_ADD_GROUPMEMBER,
            content: modifygroupbox,
            id: 'addgroupmembers',
            lock: true,	
            fixed: true,
            width: 410,
            height: 200,
			button: [{
			  name: lw_lang.ID_OK,
			  focus: true,
			  callback:  fun
			},{
				 name: lw_lang.ID_CANCEL
			}]	
        });				
        $('#add_member_tag').membersearch({
            target: $('#modifygroupbox'),
            isgroup: 'no',
			from:'addmembertogroup',
            symbol: ';'
        });
    },
    format_message_content: function (content, the_class) {		
		String.prototype.replaceAll = function(s1,s2){  
             return this.replace(new RegExp(s1,"gm"),s2);    
        }
        var regexp = /((ftp|http|https):\/\/(\w+:{0,1}\w*@)?([A-Za-z0-9][\w#!:.?+=&%@!\-\/]+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?)/gi;
        var str = content.split('@');
        var temp ;
        content = content.replace(/</g, '<span> <</span>');
        for(var i = 0; i < str.length; i++){
            temp = jQuery.trim(str[i]);			
            if(name2user[temp] || temp === 'all'){
               content = content.replaceAll('@' + temp, '<span class="' + the_class + '">@'+ temp +'</span>');
            }else{
               text_num =  temp.length < 50 ? temp.length : 50 ;
               for(var j = 1 ; j < text_num; j++ ){
                  sp_temp = temp.slice(0, j)
                  if(sp_temp == 'all'){
                     content = content.replaceAll('@' + sp_temp, '<span class="' + the_class + '">@'+ sp_temp +'</span>');
                     break;
                  }
                  if(name2user[sp_temp]){
                    content = content.replaceAll('@' + sp_temp, '<span class="' + the_class + '">@'+ sp_temp +'</span>');
                    break;
                  }
              } 
            }
        }
        for(var key in externalEmployees) {
          var temp = '@' + externalEmployees[key]['name'] + externalEmployees[key]['eid'] + '/' + externalEmployees[key]['markname']
          if(content.indexOf(temp)>=0){
            content = content.replaceAll(temp, '<span class="' + the_class + '">'+ temp +'</span>');     
          } 
        }
	    content = content.replaceAll('<span class="linkuser"><span class="linkuser">', '<span class="linkuser">');	
	    content = content.replaceAll('</span></span>', '</span>');	
		content = content.replace(/(^\s*)|(\s*$)/g, "");	
        content = content.replace(regexp, '<a class="' + the_class + '" target="_blank" href="$1">$1</a>');
		return	content.replace(/\n/g, '<br\>');
    },
    format_message: function (header, content, footer, links, cb) {	
        var container = $('<dl class="message_container"/>');
        content = content.replace(/(@[^\s]+)\s*/g, '<span class="linkuser">$1</span>');
        content = content.replace(/\n/g, '<br\>');     ;  
        var header_div = $('<dt class="message_header">' + header + '</dt>');
        var content_div = $('<dd class="message_content">' + content + '</dd>');
        var footer_div = $('<dd class="message_footer">' + footer + '</dd>');
        var link_container = $('<dd class="pagefoot"/>');
        $.each(links, function (key, value) {
            if ($.isFunction(value)) {
                var a = $(sprintf('<a href="###">%s</a>', lw_lang.ID_RESTART)).click(function (e) {
                    e.preventDefault();
                    value();
                });
                link_container.append(a);
            } else if (typeof (value) == 'string') {
                link_container.append(sprintf('<a href="%s">%s</a>', value, lw_lang.ID_RESTART));
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
		//var phone =  employer_status[i]['phone'];
        var phone = userPhoneManage.getEmployeeTel(emmployer_uuid);
        var name =  employer_status[i]['name'];				
        switch (id) {
            case 'meeting':
                var ok   = function(phone){meetingController.addto_current_list(name, phone);};
                var fail = function(){LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_INVALID+"!", 5, 2000);};
                userPhoneManage.userSelectPhone(emmployer_uuid,["extension"],ok,fail);
                /*if (isPhoneNum(phone)){
			      meetingController.addto_current_list(name, phone);
                }else{
                  LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_EMPTY+"!", 5, 2000);
                }*/
                break;
			case 'documents':
			    var new_target = $('#floattipsshare')
		        new_target.find('.lwork_mes').focus();
                mesText = new_target.find('.lwork_mes').val();
                new_target.find('.lwork_mes').val(mesText + ' @' + txt + ' ');
                confine(300, { 'oConBox': new_target.find('.lwork_mes'), 'oSendBtn': new_target.find('.sendBtn'), 'oMaxNum': new_target.find('.maxNum:first'), 'oCountTxt': new_target.find('.countTxt:first') });
			    break;	
            case 'questions':
            case 'focus':
            case 'forum':
            case 'mail':
            case 'recycle':
                break;
            case 'video':
                wVideo.addPeer(emmployer_uuid);
                break;
            case 'voip':
                var ok   = function(phone){target.find('.peerNum').val(phone).attr({'phone': phone,'name': name});};
                var fail = function(){LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_INVALID+"!", 5, 2000);};
                userPhoneManage.userSelectPhone(emmployer_uuid,["extension"],ok,fail);
                /*if (isPhoneNum(phone)){
			        target.find('.peerNum').val(txt).attr('phone', phone);
                }else{
                    LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_EMPTY+"!", 5, 2000);
                }*/
                break;
            case 'shortmsg':
                var ok   = function(phone)
                {
                    var newPhone = phone + '[' + name + ']';
                    $('#sendsms_input_tag').val(newPhone).blur();
                };
                var fail = function(){LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_INVALID+"!", 5, 2000);};
                userPhoneManage.userSelectPhone(emmployer_uuid,['pstn','extension'],ok,fail);
                /*if (isPhoneNum(phone)){
                    var newPhone = phone + '[' + name + ']';
                    $('#sendsms_input_tag').val(newPhone).blur();
                }else{
                    LWORK.msgbox.show(name + " " + lw_lang.ID_NUMBER_EMPTY+"!", 5, 2000);
                }*/
                break;				
            default:              
                loadContent.AddEmployDom(target, txt);
                break;
        }
	},
    AddEmployDom:function(target, txt){
        var temp_obj = target.find('.lwork_mes');  
        var range;
        var tempid = 'select' + parseInt(Math.random()*10E20);
        var maxnum = ( target.attr('id') === 'tasks' ? 1000 :  300)
        temp_obj.focus();
        temp_obj.append('<button class="tag" contenteditable="false" id="'+ tempid +'" onclick="return false;">@'+ txt.replace('@','/') +'</button>&nbsp;');           
        confine(maxnum,{
            'oConBox':temp_obj,
            'oSendBtn': target.find('.sendBtn').eq(0),
            'oMaxNum': target.find('.maxNum').eq(0),
            'oCountTxt': target.find('.countTxt').eq(0),
            'editdiv':true
         }); 
              
        if (window.getSelection) {
           sel = window.getSelection();
           if (sel.getRangeAt && sel.rangeCount) {
              range = sel.getRangeAt(0);
           } 
           temp_obj.blur();     
           range.setStartAfter(document.getElementById(tempid));
           range.setEndAfter(document.getElementById(tempid));
           getSelection().addRange(range);
        }
        temp_obj.focus(); 
    },
    addGroup2ShortMsgReceivers: function(groupname){
        var target = loadContent.target;
        $('#sendsms_input_tag').val('@'+groupname+'[00000]');
        $('#sendsms_input_tag').blur();
    },
    sendShortMsg: function(){
        var target = loadContent.target;
        var receiversStr = $('#sendsms_input').attr('data');
        var msgContent = target.find('textarea.shortmsg_content').eq(0).focus().val();
        if (msgContent.length < 1){
            LWORK.msgbox.show(lw+lang.ID_SMS_MISSED, 5, 1000);
            return false;
        }
        if (receiversStr.length < 1){
            LWORK.msgbox.show(lw_lang.ID_RECNUM_MISSED, 5, 1000);
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
                            var phone = userPhoneManage.getEmployeeTel(temp_uuid);
                            var person = employer_status[loadContent.employstatus_sub(temp_uuid)];
                            if (phone.length < 1){
                                noNums.push(groupName+'/'+person.name);
                            }else{
                                rcvrs.push(phone + '[' + person.name + ']');
                            }
                            /*if (person.phone.length < 1){
                                noNums.push(groupName+'/'+person.name);
                            }else{
                                rcvrs.push(person.phone + '[' + person.name + ']');
                            }*/
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
            LWORK.msgbox.show(lw_lang.ID_WRONGNUM, 5, 1000); 
            return false;
        }
        var html = "";
        if (expanded['invalidGroups'].length > 0){
            html += '<div class="confirm_dialog_item">'+lw_lang.ID_WRONG_GROUPNAME+'</div>';
            html += '<div class="confirm_dialog_txt">' + expanded['invalidGroups'].join(";") + '</div>';
        }
        if (expanded['noNums'].length > 0){
            html += '<div class="confirm_dialog_item">'+lw_lang.ID_NUM_MISSED+'</div>';
            html += '<div class="confirm_dialog_txt">' + expanded['noNums'].join(";") + '</div>';
        }
        if (filtered['invalidNums'].length > 0){
            html += '<div class="confirm_dialog_item">'+lw_lang.ID_NUM_WRONG+'</div>';
            html += '<div class="confirm_dialog_txt">' + filtered['invalidNums'].join(";") + '</div>';
        }
        if (html.length > 0){
            artDiaglogConfirm(lw_lang.ID_CONFIRM, 
                html + '<h4>' +  lw_lang.ID_CONFIRM_SEND + '</h4>', 
                'smsReceivers',
                {'name':lw_lang.ID_IGNORE, 'cb':function(){loadContent.doSendShortMsg(receiverList, msgContent);}}, 
                {'name':lw_lang.ID_CHANGE_AGAIN, 'cb':function(){}});
        }else {
            loadContent.doSendShortMsg(receiverList, msgContent);
        }
        return false;
    },
    doSendShortMsg: function(receivers, msg){
        var target = loadContent.target;
        var me = employer_status[loadContent.employstatus_sub(uuid)];
        //var sig = lw_lang.ID_FROM + me.name + me.employid + '-' + company;
        var sig = lw_lang.ID_FROM + me.name + me.employid + '-' + $('#header .logo').html();
        api.sms.send(uuid, receivers, msg, sig, function(data){
           data['fails'].length > 0 ? alert( "向" + data['fails'].join("、") + lw_lang.ID_SEND_FAILED ) : LWORK.msgbox.show(lw_lang.ID_SEND_SUCCESS, 4, 1000);
           $('#sendsms_input_tagsinput').find('.tag').remove();		   
           $('#sendsms_input').attr('data', '').val('');
           target.find('textarea.shortmsg_content').val('').focus().blur();       
        }, function(fdata){
            ajaxErrorTips('sms' ,fdata, 'error');
            HideajaxErrorTips('sms');
        });
    },
    createSmsHistoryItemDom: function(item){
        var receiversDisplay = item.members.map(function(receiver){return '<span class="linkuser">' + receiver.name + '</span>' +  receiver.phone;}).join("、");
        var receiversDataRecord = item.members.map(function(receiver){return receiver.phone + (receiver.name.length > 0 ? '[' + receiver.name + ']' : '');}).join(";")
        var html = ['<dl class="msg_item_1" style="display:block">',
		            '<dd><span class="shortmsg_content_1">'+lw_lang.ID_SMSCONTENT+'</span><span>' + item.content  + '</span></dd>',	
                    '<dd class =""><span class="shortmsg_object_1">'+lw_lang.ID_RECEIVER+'</span><span>' + receiversDisplay + '</span></dd>', 
					'<dd><span class="shortmsg_time_1">'+lw_lang.ID_SEND_TIME+'：</span>' + item.timestamp + '</dd>',		
                    '<dd class="pagefoot" style="clear:both">',
                    '<a href="###" class="reSendSMS" receivers="' + receiversDataRecord + '">'+lw_lang.ID_RESEND+'</a>',
                    '</dd></dl>'].join("");
        return html;
    },
    viewHistoricalShortMsg: function(){
        api.sms.history(uuid, function(data){
            //var data = get_test_sms_history();
            var history = data["history"];
            if (history.length === 0){
                LWORK.msgbox.show(lw_lang.ID_SMS_RECORD, 3, 1000);
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
        $('#sendsms_input_tag').val(receivers).blur();
        $('#shortmsg').find('.shortmsg_content').focus().val(content);
        return false;
    },
    checkInputLimit: function(target, container, max_num, sendButton){
        var i = 0, iLen = 0, txt = target.val();
        for (i = 0; i < txt.length; i++){
            //iLen += txt.charAt(i).charCodeAt() > 255 ? 1 : 0.5;
            iLen += 1;
        }
        var maxNum = max_num - Math.floor(iLen);
        if (maxNum < 0){
            $(this).val(txt.substring(0, txt.length - 1));
            maxNum = 0;
        }
        if (sendButton) {
            max_num > maxNum ? sendButton.removeClass('disabledBtn') : sendButton.addClass('disabledBtn');
        }
        container.find('.maxNum').eq(0).text(maxNum);
        return false;
    },
    checkShortMsgInput: function(){
        return loadContent.checkInputLimit($(this), $('#shortmsg'),120);
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
	    var msg_content = target.find('.lwork_mes').html();
        var opt = {};
        var SendFileObj = $(this).parent();
		var upload_images = loadContent.getAttachmentObj(SendFileObj);


        if (!target.find('.sendBtn').hasClass('disabledBtn')) {			
			var images ,filename;
            msg_content = loadContent.replacecontent(msg_content)['msg_content'];
            var members =  loadContent.getmembers(msg_content);
            switch (targetid) {
                case 'tasks':
                    opt = { uuid: uuid, content: msg_content, members: members, image:upload_images,  't': new Date().getTime() };
                    loadContent.publish('tasks', opt, $('#mysend_msg'), SendFileObj);
                    break;
                case 'topics':	
                    opt = { uuid: uuid, content: msg_content, members: members, image:upload_images, 't': new Date().getTime() };
                    loadContent.publish('topics', opt, $('#topic_msg'), SendFileObj);
                    break;
                case 'polls':
                    var option = loadContent.polls_item();
                    if (option.length < 2) { LWORK.msgbox.show(lw_lang.ID_TWO_OPTIONS, 1, 2000); return false; }					
                    opt = { uuid: uuid, type: 'single', content: msg_content, members: members, image:upload_images,  options: option, 't': new Date().getTime() };
                    loadContent.publish('polls', opt, $('#polls_msg'), SendFileObj);
                    break;
			//	case 'news':				
            //        opt = { uuid: uuid, content: msg_content, image:upload_images, 't': new Date().getTime()};					
            //        loadContent.publish('news', opt, $('#news_msg'));					
            //       break;	
                case 'questions':
                    var description = target.find('.description_input').val();
                    var tags = target.find('.ask_tag').val();
                    if ('' === msg_content || msg_content == lw_lang.ID_QUESTION) return false;
                    if (description === lw_lang.ID_DESCRIBTION) { description = ''; }
                    if (lw_lang.ID_TAGS == tags) tags = '';
                    opt = { uuid: uuid, title: msg_content, tags: tags, content: description, 't': new Date().getTime() };
                    loadContent.publish('questions', opt, $('#questions_msg'));
                    target.find('.ask_tag').val(lw_lang.ID_TAG_SEPERATED);
                    target.find('.description_input').val(lw_lang.ID_DESCRIBTION);
                    target.find('.description_input').searchInput({
                        defalutText: lw_lang.ID_DESCRIBTION
                    });
                    target.find('.ask_tag').searchInput({
                        defalutText: lw_lang.ID_TAGS
                    });
                    break;
            }
        }
        return false;
    },
    removeUpFiles : function(SendFileObj){
        SendFileObj.find('.fileList').slideUp(400, function(){
            $(this).html('');
        })
        SendFileObj.find('form').each(function(){
           if($(this).attr('filepath')||$(this).attr('filepath')===''){
             $(this).remove();
           }
        })
        removePageTips(SendFileObj);
    },
    publish: function (type, opt, container, SendFileObj) {
        var target = loadContent.target;
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
		target.find('.lwork_mes').find('.tag').remove()
        var shortsmsContent = target.find('.lwork_mes').text();
            target.find('.lwork_mes').focus().html('');
            target.find('.sendBtn').eq(0).addClass('disabledBtn');
            if(SendFileObj) loadContent.removeUpFiles(SendFileObj);
        var fun = function(){
            container.find('dl').eq(0).slideDown('slow', function () {            
                  if(type == 'tasks') loadContent.sendMessage_task(opt['members'], shortsmsContent,  opt['image']);            
                  LWORK.msgbox.show(lw_lang.ID_SEND_SUCCESSFUL, 4, 1000);         
                  container.find('.nocontent').hide();
                  if ($('#polls_option').length > 0) {
                      $('#polls_option').find('img').attr({'src' : '/images/update_pic.png' , 'source':''});
                      $('#polls_option').find('input[type=file]').val('');
                      $('#polls_option').find('input[type=text]').each(function (i) {
                      if (i >= 3) {
                        $(this).parent().html('').remove();
                      } else {
                            var text = lw_lang.ID_OPTION + String.fromCharCode(65 + i);         
                            $(this).val(text);
                            $(this).searchInput({
                                defalutText: text
                            });
                    }
                });
              }
            });
        } 
            if(type == 'tasks' && $('#mysend_msg').attr('containdom') === 'no'){
                 loadContent.loadmsg('tasks', 'owned', 'unfinished', 'mysend_msg',  '1',  '', function(){			
				 fun();
                 $('#tasks').find('.menu').find('li').eq(1).click();
			   });
			}else{
			     container.prepend(html);	
                 fun();
			}
            loadContent.bindMsgRecycler(container.attr('id'));
			loadContent.bindloadImage();
            loadContent.bindMsgHandlers();
			loadContent.fileshow_handle();
        });
    },
	sendMessage_task: function(members, content, attachment){
		var me = '';
		var offline_content = '';
		var sendphone = new Array();
		var offline_members = '';
		var name_num = 0;
        var containcontent = '';
        content = jQuery.trim(content); 
        if(attachment['multi_images'].length>0)
          containcontent === '' ? containcontent = lw_lang.ID_TASKS_SHORTMSG + lw_lang.ID_TASKS_CONTAINERIMG :  containcontent += ( '、' + lw_lang.ID_TASKS_CONTAINERIMG);
        if(attachment['multi_attachment'].length>0)
          containcontent === '' ? containcontent = lw_lang.ID_TASKS_SHORTMSG + lw_lang.ID_TASKS_CONTAINERATTACHE  :  containcontent += ( '、' + lw_lang.ID_TASKS_CONTAINERATTACHE);
          containcontent === '' ? containcontent = '' :  containcontent += lw_lang.ID_TASKS_LOGIN;
        for(var i=0; i < members.length; i++){
          var phone = userPhoneManage.getEmployeeTel(members[i]);
		  me = employer_status[loadContent.employstatus_sub(members[i])];
          if(me){
		   if(me['status'] === 'offline'){	
			 if('' != phone/*me['phone']*/){
		        sendphone.push({'phone':correctPhoneNumber(phone)/*me['phone']*/, 'name':me['name']});
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
						 if('' != phone/*me['phone']*/){			
						    sendphone.push({'phone':correctPhoneNumber(phone)/*me['phone']*/, 'name':me['name']});
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
		if('' !== offline_members) offline_members = offline_members + ' ' + lw_lang.ID_CANNOT_SEND;
		if(sendphone.length > 0){
			var dialog = art.dialog({
				title: lw_lang.ID_SMS_NOTICE,
				content: '<span style="line-height:20px; font-size: 13px;">' + lw_lang.ID_SMS_REMIND + '<br/>' +offline_members  + '</span>' ,
				width: '400px',
				button: [{
				  name: lw_lang.ID_REMIND,
				  callback: function () {          
					loadContent.doSendShortMsg(sendphone ,lw_lang.ID_CO_WORK + ':'+ content + ' ' + containcontent);
				  },
				  focus: true
				},{
				  name: lw_lang.ID_CANCEL
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
        loadContent.bind('attachment_header', loadContent.bindAttachHandle, 'class');    	
		loadContent.contentmemberdetail();
		loadContent.bind_images_scaling();

    },
    bindAttachHandle: function(){
        $(this).find('.attach_opt').toggleClass('attach_optCur');
        $(this).next().slideToggle();
    },
	bindloadImage: function(){
		$('.pagecontent_img img').LoadImage(true, 100,100,'/images/loading.gif');		
	    $('.poll_img img').LoadImage(true, 60,60,'/images/loading.gif');	
	},
	bind_images_scaling: function(){
		$('.pagecontent_img img , .poll_img img').bind('click',function(){
			var _this = $(this);			
			var url = _this.attr('source'),
			    url2 = loadContent.getpicphoto(url, 'B');
		    _this.parent().parent().hide().prev().show().find('img').attr('src' ,url2);
			_this.parent().parent().prev().find('.lwork_bingmap').attr('href', url);			
			_this.parent().parent().prev().show().find('img').LoadImage(true, 480,500,'/images/loading.gif');
		   return false;
		 })
		$('.bigimag_content').bind('click',function(){
			var _this = $(this);
		    _this.parent().hide().next().show();
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
        html += '<div class="gen_confirm_btns"><a href="###" class="gen_confirm_yes">'+lw_lang.ID_OK+'</a><a href="###" class="gen_confirm_no">'+lw_lang.ID_CANCEL+'</a></div>';
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
        var no_tag_tip = '<div class="no_tag_tip">'+lw_lang.ID_ADD_TAG+'</div>';
        var tagsStatistics = loadContent.myFocus.getTagsStatistics();
        $('.focus_num').text(tagsStatistics["allFocuses"]);
        if(tagsStatistics["allFocuses"] === 0){
            $('.tag_mgt').hide();
            return false;
        }
        $('.tag_mgt').show();
        if (tagsStatistics["allFocuses"] === tagsStatistics["untagedFocuses"]){
            $('.tag_mgt').html('<div class="no_tag_tip">'+lw_lang.ID_ADD_TAG+'</div>');
            loadContent.displaySelectedFocuses("allFocuses");
            loadContent.curTag = "allFocues";
        }else{
            $('.tag_mgt').html('<ul class="menu tags_list"></ul><div class="tag_mgt_btn_ragion"><a id="tag_mgt_btn" curMode="view" href="###" class="viewing">'+lw_lang.ID_TAG_MANAGEMENT+'</a> </div>');
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
        return '<span class="tag_inputer" style="display:none;"><input class="input_tag_txt"></input><a href="###" class="input_tag_yes">'+ lw_lang.ID_OK +'</a><a href="###" class="input_tag_no">'+lw_lang.ID_CANCEL+'</a></span>';
    },
    createFocusBtn: function(type, msgid){
        if ( type === 'tasks' || type === 'topics'){
            if (loadContent.myFocus.isMsgIn(type, msgid)){
                return '<a href="###" type="' + type + '"  msgid="' + msgid + '"  titile="'+lw_lang.ID_FAVORITE_REMOVE+'" class="cancelFocus">'+lw_lang.ID_FAVORITE_REMOVE+'</a>';
            }else{
                return '<a href="###" type="' + type + '"  msgid="' + msgid + '"  titile="'+lw_lang.ID_ADD_FAVORITE+'" class="setFocus">'+ lw_lang.ID_ADD_FAVORITE +'</a>';
            }
        }else{
            return "";
        }
    },
    createTagTab: function(tag, count){
        var tagTxt, tagType, tagEditable;
        var html = "";
        tag === "allFocuses" ? (tagTxt = lw_lang.ID_FAVORITE_ALL, tagType = "reservedTag", tagEditable = "") : (tag === "untagedFocuses" ? (tagTxt = lw_lang.ID_UNTAGGED, tagType = "reservedTag", tagEditable = "") : (tagTxt = tag, tagType = "specifiedTag", tagEditable = " tagEditable"));
        var tagView = '<span class="tag_view" style="display:inline;"><span class="tag_name">' + tagTxt + '</span><span class="tag_count">(' + count + ')</span></span>';
        var tagEditor = '<span class="tag_editor" style="display:none;"><a class="tag_batch_edit" href="###"><span class="tag_name">' + tagTxt + '</span><span class="tag_count">(' + count + ')</span></a><a class="tag_batch_delete"></a></span>';
        return '<li class="tag_tab ' + tagEditable + '"' +' id="' + tag + '" tagType="' + tagType + '" href="###">' + tagView + tagEditor + loadContent.createTagInputer() + '</li>';   
    },
    insertFocusTagRegion: function(itemHtml, focusTime, msg_type, msg_id, tags){
        var tag = (tags.length > 0) ? tags[0] : "";
        var tag_html = '<span class="focus_tag_panel" curTag="' + tag + '"><a href="###" class="tag_btn ' + (tag === "" ? "add_new_tag" : "filter_tag") + '">' + (tag === "" ? "+"+lw_lang.ID_TAG : tag) + '</a>' + '<a href="###" class="edit_focus_tag" style="display:' + (tag === "" ? "none;":"inline;") + '"></a></span>';
        var txt = '<dd class="focus_tag_region" msgtype="' + msg_type + '" msgid="' + msg_id + '" tag="' + tag + '">' + lw_lang.ID_TAG_BT + loadContent.createTagInputer() + tag_html + '<span class="focus_time_txt">' + lw_lang.ID_FAVORITE_TIME + focusTime + '</span></dd>';
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
                        tagBtn.addClass('add_new_tag').removeClass('filter_tag').text('+'+lw_lang.ID_TAG);
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
        loadContent.createGeneralConfirm(tagTab, lw_lang.ID_IF_REMOVETAG, lw_lang.ID_DELETETAG_NOTE, function(){
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
                        tagBtn.addClass('add_new_tag').removeClass('filter_tag').text('+'+lw_lang.ID_TAG);
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
                    LWORK.msgbox.show(lw_lang.ID_TAG_EMPTY, 5, 1000);
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
                Obj.attr('curMode', "maintain").text(lw_lang.ID_EXIT);
                break;
            case "maintain":
                loadContent.toViewTags();
                Obj.removeClass("maintaining").addClass("viewing");
                Obj.attr('curMode', "view").text(lw_lang.ID_TAG_MANAGEMENT);
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
            LWORK.msgbox.show(lw_lang.ID_REMOVE_FAVORITE, 1, 1000);
        }else{
            api.content.del(uuid, [{"type":type, "ownership":ownership, "entity_id":msgid}], function(){
                LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 4, 1000);
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
            LWORK.msgbox.show(lw_lang.ID_RESTORED, 4, 1000);
			type === 'documents' ? msg_item.parent().remove() : msg_item.html('').remove();					
            if ($('#recycled_msg').find('.msg_item').length === 0 && $('#recycled_msg').find('.hover').length === 0  ){
                $('#recycled_msg').html('<div class="nocontent">'+ lw_lang.ID_RECYCLE_EMPTY +'</div>');
            }			
        });
        return false;
    },
    removeMsg: function(){
        var msg_item = $(this).parent().parent();
        loadContent.createGeneralConfirm($(this), lw_lang.ID_DELETE_NOTE1, lw_lang.ID_DELETE_NOTE2, function(){
            var type = msg_item.attr("msg_type");
            var msgid = msg_item.attr("task_id");
            var ownership = msg_item.attr("ownership");
            api.content.remove(uuid, [{"type":type, "ownership":ownership, "entity_id":msgid}], function(){
                LWORK.msgbox.show(lw_lang.ID_PERMANENTLY_DELETE, 4, 1000);
				type === 'documents' ? msg_item.parent().html('').remove() : msg_item.html('').remove();				  				
                if ($('#recycled_msg').find('.msg_item').length === 0 && $('#recycled_msg').find('.hover').length === 0 ){
                    $('#recycled_msg').html('<div class="nocontent">'+lw_lang.ID_RECYCLE_EMPTY+'</div>');
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
            loadContent.createGeneralConfirm($(this), lw_lang.ID_RECYCLE_NOTE2, lw_lang.ID_RECYCLE_NOTE3, function(){
				
                api.content.remove(uuid, items, function(){
                    LWORK.msgbox.show(lw_lang.ID_RECYCLE_NOTE4, 4, 1000);
                    $('#recycled_msg').html('<div class="nocontent">'+lw_lang.ID_RECYCLE_EMPTY+'</div>');
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
                    $(this).append('<a href="###" class="recoverMsg">'+lw_lang.ID_RECYCLE_NOTE5+'</a><a href="###" class="removeMsg">'+ lw_lang.ID_RECYCLE_NOTE1 +'</a>');
                });
                $('#' + continer).find('.opts').each(function(){
                    $(this).find('a').remove();
                    $(this).append('<a href="###" class="recoverMsg">'+lw_lang.ID_RECYCLE_NOTE5+'</a><a href="###" class="removeMsg">'+ lw_lang.ID_RECYCLE_NOTE1 +'</a>');
                });
                loadContent.bind('recoverMsg', loadContent.recoverMsg, 'class');
                loadContent.bind('removeMsg', loadContent.removeMsg, 'class');
                loadContent.bindMsgHandlers();
				loadContent.bindloadImage();
			    loadContent.bind('delete_all', loadContent.removeAllMsgs, 'id');		
            } else {
                $('#loading').hide();
                $('#' + continer).html('<div class="nocontent">'+lw_lang.ID_RECYCLE_EMPTY+'</div>');
            }
     
        }, function () { LWORK.msgbox.show(lw_lang.ID_SERVER_BUSY, 1, 2000); $('#loading').hide(); });
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
                $('#' + continer).html('<div class="nocontent">'+lw_lang.ID_FAVORITE_NOTE+'</div>');
            }
            loadContent.createTagsMgtDom();
            $('.tag_mgt').find('#allFocuses').click();
            $('#loading').hide();
            return false;
        }); 
    },
   getdelete_name: function(obj){
	   var employ_uuids = '';
       var subobj;
	     obj.find('.delete_uuid').each(function(){
            subobj = $(this)
            var employer = $(this).attr('employer_uuid');
		    '' === employ_uuids ?   employ_uuids = employer :  employ_uuids += ',' + employer;		  	
		})
        if(employ_uuids=='') return;
		$.getJSON('/lwork/auth/names?uuids=' + employ_uuids, function(data) {
			var con = data['results'];
			var len = con ? con.length : 0;

			for(var i = 0; i< len; i++){
                var markname = (con[i].markname && con[i].markname != company) ? con[i].markname : false;
                var suffix = markname ? '@'+markname : '';
                $('.delete_' + con[i].uuid).text(con[i].name+suffix);
                $('.comt_name_' + con[i].uuid).attr('name', con[i].name + con[i].eid+suffix);
                if(markname) {
                    subobj.attr('title','')
                    addExternalEmployee2GlobalDb(con[i]);
                }
			}
		});		
   },	
    loadmsg: function (mode, type, status, continer, page_index , flag , callback) {
	   if($('#' + continer).find('.loadmore_msg').length <= 0){
	       $('<div class="loadmore_msg" style="text-align:center; padding:10px ;"><img src = "/images/uploading.gif" style="vertical-align:bottom;"/><span>正在加载...</span></div>').appendTo($('#' + continer));	
	   }
	   api.content.load_msg(mode, uuid, type, status, page_index, '20' , function (data) {
            var msg = data[mode];
            var owner, content;
            var html = "";
			var unread = '<div class="readed_hr"><span class="readed_line"></span><span class="readed_content"> '+lw_lang.ID_PREVIOUS_READ+' </span><span class="readed_line"></span></div>';
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
                        var div = document.createElement("div");
                        div.innerHTML = html;
                        $('#' + continer)[0].appendChild(div);
						current_page_index[continer] = page_index ;
					   }
					  }else{
						 $('#' + continer).html(html); 
					  }	
                      loadContent.getdelete_name($('#' + continer));   

				 }else{	
					html = '<ul>' 
					for (var i = 0; i < msg.length; i++) {
						 html += loadContent.create_sharefile(msg[i]);
					}
					html += '</ul>';
				   if(flag && '' !== flag){
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
                 $('#' + continer).html('<div class="nocontent">'+lw_lang.ID_NO_CONTENT+'</div>');
				 if(callback) callback();
			  }	
              if(status === 'unread'){
                var triggerLi;
                current_page_index[continer] = '1' ;
                $('#' + continer).attr('containdom', 'no').html('');

                $('#' + mode).find('.menu').find('li').each(function(){
                  triggerLi = $(this).attr('link');
                  if(triggerLi === 'topic_content')  triggerLi ='topic_msg';
                  if(continer === triggerLi) $(this).click();
                  return;
                })
                $('#' + mode).find('.nuread_msg').fadeOut();

              }
            }
        }, function () { LWORK.msgbox.show(lw_lang.ID_SERVER_BUSY, 1, 2000); $('#loading').hide(); });
        return false;
    },
    loadnewcomt: function (mode, continer) {
       if($('#' + continer).find('.loadmore_msg').length <= 0){
           $('<div class="loadmore_msg" style="text-align:center; padding:10px ;"><img src = "/images/uploading.gif" style="vertical-align:bottom;"/><span>正在加载...</span></div>').appendTo($('#' + continer));  
       }
       api.content.loadnewcomt(mode, uuid.toString(), function (data) {			
            var msg = data['replies'], owner, html = "", content, delete_css = "" ,comt_name_uuid = '';				
            if (msg.length > 0) {
                for(var i = 0; i < msg.length; i++) {
                    var reply = msg[i]['reply'] , topic = msg[i]['topic'] , dialog="";
					var reply_content  , delete_css = '';
					var employer, delete_uuid = ''; 
					var attachmentDOM = '';
					if(typeof(loadContent.employstatus_sub(reply.from)) !== 'undefined'){
					   employer =employer_status[loadContent.employstatus_sub(reply.from)];
                       owner = getEmployeeDisplayname(reply.from);
					   photo = employer['photo'];
					   name_employid = employer['name_employid'];
					}else{
					  owner = lw_lang.ID_UNKNOWN;
					  delete_css = 'delete_uuid';		  
					  photo = '/images/photo/defalt_photo.gif';
					  delete_uuid = 'delete_' + reply.from;
					  name_employid = lw_lang.ID_UNKNOWN
					  comt_name_uuid = 'comt_name_' + reply.from;
					}
					if(reply.to && '-1' !== (reply.to).toString() && uuid !== (reply.to).toString()){
			    	  dialog = '<a href="###" task_id = "'+ topic['entity_id'] +'"  findex="' + reply.findex + '"  mode="'+ mode +'" class="sub_dialog" style="float:right;padding-right:10px;">'+lw_lang.ID_CHECK_DIALOGUE+'</a>';
					}
					if(typeof(reply.content) === 'object'){
					   reply_content = reply.content.content;
					   attachmentDOM = loadContent.getImgAttacheDom(reply.content.upload_images);
					}else{
					   reply_content = reply.content;
					}								
					//reply_content = reply_content.replace(':', ' ');					
					reply_content = loadContent.format_message_content(reply_content, 'linkuser');
					html += ['<dl id="'+ topic['entity_id'] +' + newcomt_content'+ i +'sub">',
					      '<dt class="sub_dt"><img src="'+ photo +'" width="48" height="48"/></dt>',
				 		  '<dd class="sub_dd"><span employer_uuid="'+ reply.from +'" class="lanucher '+ delete_css +' '+ delete_uuid +'">' + owner + '</span>：' + reply_content,
						  '</dd>',
                          '<dd class="sub_dd">'+ attachmentDOM +'</dd>',
                          '<dd class="newcomt_msg"><div class="float_corner float_corner_top"> <span class="corner corner_1" style="color:#FBFBFB">◆</span> <span class="corner corner_2" style="color:#E1E4E5">◆</span> </div>',     
        				  loadContent.createContent(topic, mode, 'owned' , status, continer + i, 'block'),
                          '</dd><dd class="sub_newcomt"><span class="gray">' + reply.timestamp + '</span><a href="###" findex = "'+ reply.findex +'" name="'+ name_employid +'" mode="'+mode+'" sendid="' +topic['entity_id'] +'" name="" class="sub_newcomment '+ comt_name_uuid +'">'+lw_lang.ID_REPLY+' </a>'+ dialog +'</dd>',
        				  '</dl>' ].join("");
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
                $('#' + continer).find('.newcomt_wrap').html('<div class="nocontent">'+lw_lang.ID_NO_NEWREPLY+'</div>');
                $('#' + mode).find('.nuread_comt').fadeOut();
            }
            $('#' + continer).find('.loadmore_msg').remove();    
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
	       owner = getEmployeeDisplayname(msg['from']);
		   photo = employer['photo'];
		}else{
		  owner = lw_lang.ID_UNKNOWN;
		  delete_css = 'delete_uuid';		  
		  photo = '/images/photo/defalt_photo.gif';
		  delete_uuid = 'delete_' + msg['from'];
		  title = lw_lang.ID_USER_REMOVED;
		}		
        mode === 'documents' ? txt = lw_lang.ID_SHARE  : txt = lw_lang.ID_INVITE1;
        mode === 'questions' ? txt2 = lw_lang.ID_ANSWER : txt2 = lw_lang.ID_REPLY;		
        var e = '<a class="trace"  mode="' + mode + '"  taskid ="' + msg['entity_id'] + '" link ="' + linkhref + '" href="###">'+ lw_lang.ID_TRACE +'(<span class = "unreadtrace">' + msg['traces']+ '</span>)</a>',
		    a = '<a href="###" mode="' + mode + '" link ="' + linkhref + '"  sendid ="' +  msg['entity_id'] + '" class="comment">' + txt2 + ' (<span class = "unreadcomt">' + msg['replies'] + '</span>)</a>',
		    b = '<a href="###" mode="' + mode + '"  link ="' + linkhref + '"  sendid ="' +  msg['entity_id'] + '"  titile="' + txt + '" class="invitecolleagues">' + txt + '</a>',			  
			g = '<a href="/lw_download.yaws?fid=' + msg['file_id'] + '" titile="'+lw_lang.ID_DOWNLOAD_FILE+'" target="_blank" class="downloadfile">'+lw_lang.ID_DOWNLOAD+'</a>',			  
		    c = '<a href="###" titile="'+lw_lang.ID_REMARK_COMPLETED+'" class="taskstatus">'+lw_lang.ID_DONE+'</a>',
            r = '<div class="recycle_item"><a href="###" class="recycle_msg_btn" style="display:none" title="'+lw_lang.ID_DELETE_MESSAGE+'"></a></div>';
            focusBtn = loadContent.createFocusBtn(mode, msg['entity_id']);
        switch (mode) {
            case 'tasks':
                status === 'finished' ? (( employer_uuid === uuid) ? f = e + a : f = focusBtn + e + a)  : ( employer_uuid === uuid ? f = e + a + b + c : f = focusBtn + e + a + b );
                status === 'finished' ? r : r = '';
                bt = lw_lang.ID_CO_WORK ;
                if (flag && flag === 1) f = e + a;
                break;
            case 'polls':
                bt = lw_lang.ID_VOTE;
                f = e + b;
                break;
            case 'questions':
                bt = lw_lang.ID_QA;
                f = a;
                r = '';
                break;
	        case 'news':
                bt = lw_lang.ID_MESS;
                f = a;
                r = '';
                break;			
            default:
                bt = lw_lang.ID_WEIBO;
                f = focusBtn + a + b;
                break;
        }
        msg['finished_time'] ? m = '<span class="gray">' + msg['timestamp'] + '</span>&nbsp;&nbsp;&nbsp;&nbsp;'+lw_lang.ID_DONE+'：<span class="fininshtime">' + msg['finished_time'] + ' </span>' : m = '<span class="gray">' + msg['timestamp'] + '</span>';
        msg['delete_time'] ? m += '&nbsp;&nbsp;&nbsp;&nbsp;'+lw_lang.ID_DELETE+'：<span class="fininshtime">' + msg['delete_time'] + ' </span>' : m += '';
        html = ['<dl class="msg_item ' +  msg['entity_id'] + '" style="display:' + display + '" id="' +  msg['entity_id'] + linkhref + '" task_id="' +  msg['entity_id'] + '" msg_type="' + mode + '" ownership="' + (employer_uuid === uuid ? 'assign' : 'relate')+'">',
                '' + r + '',
				'<dd class="personal_icon"><img src ="' + photo + '" width="48" height="48"/></dd>', 
		        '' + loadContent.msgcontent(msg, owner, employer_uuid , delete_css, delete_uuid, title) + '',
		        '<dd class="pagefoot"><span class="msg_time">'+ bt +'：' + m + ' </span>' + f + '</dd><div class="tracewrap" style="display:none;">',
				'<div class="float_corner float_corner_input" style=""><span class="corner corner_1">◆</span> <span class="corner corner_2">◆</span></div>',
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
		 LWORK.msgbox.show(lw_lang.ID_CLOUD_SAVE, 4, 1000);		
		 _this.hide();
	},
    getImgAttacheDom: function(opt, size_style){
        var size_style = size_style ? size_style : 'S';
        var filetype ,  show_len = '', str, size = '', html = '' , images;
        var msg_img = new Array();
        var msg_attachement = new Array();        
        var img_dom = ['<div class="bigimages">',
                '<div class="select_map_btn"><a href="###" class="lwork_slideup">'+lw_lang.ID_PACKUP+'</a><a href="###" target="_blank" class="lwork_bingmap">'+lw_lang.ID_ORIGINAL_PIC+'</a></div>',
                '<div class="bigimag_content"><img src =""/></div></div><div class="imagesList">'].join('');    
         if(typeof(opt) === 'object'){
            if(opt['upload_images_url'] && opt['upload_images_url'] !== '') 
              msg_img.push(opt['upload_images_url']);
            if(opt['attachment_name'] && opt['attachment_name'] !== '') 
              msg_attachement.push({ 'attachment_name' : opt['attachment_name'] , 'filesize' : opt['filesize'] ? opt['filesize'] : '', 'attachment_url' : opt['attachment_url']} );
            if(opt['multi_images']) 
              msg_img = opt['multi_images'];      
            if(opt['multi_attachment']) 
              msg_attachement = opt['multi_attachment']; 
        }else{
            opt.indexOf('share;')>=0  ? ( str = opt.split(';'), msg_attachement.push({ 'attachment_name' : str[1] , 'filesize' : '', 'attachment_url' : str[2]}) ) : msg_img.push(opt);
        }
        if(msg_img.length > 0){
            html += img_dom;
            for(var i = 0 ; i < msg_img.length; i++ ){  
              Simg = loadContent.getpicphoto(msg_img[i], size_style);
              html += ['<li class="pagecontent_img"><img src ="'+ Simg +'" source="'+ msg_img[i] +'"/></li>'];
            }
              html += '</div>';
        }
        if(msg_attachement.length > 0){
            html += '</div><div class="pagecontent_attachment"><div class="attachment_header">'+lw_lang.ID_ATTACHED+'('+ msg_attachement.length +')<span class="attach_opt"></span></div><ul>';        
            for(var j = 0 ; j < msg_attachement.length; j++ ){
              filetype = getFileType(msg_attachement[j]['attachment_name']);
              if(msg_attachement[j]['filesize']){ 
                size = msg_attachement[j]['filesize'];
                show_len =  '<span style="padding-left:10px;">('+ getfilesize(size) +')</span>';    
              } 
              html += ['<li class="attachment_content"><div class="attachment '+ filetype +'">',
                        '<span>'+ msg_attachement[j]['attachment_name'] +'</span>'+ show_len  +'</div>',
                        '<div class="download_attachment">',
                        '<a class=""  target="_blank"  href="'+  msg_attachement[j]['attachment_url'] +'" >'+lw_lang.ID_DOWNLOAD+'</a>',
                        '<a class="gotonetwork" filesize = "'+ size +'"  href="###" >'+lw_lang.ID_MOVETOCLOUD+'</a>',
                       '</li>'].join('');                      
            }
              html += '</ul></div>';
        }
        return html;        
    },
    msgcontent: function (msg, owner, employer_uuid, delete_css ,delete_uuid, title) {
        var html = "", imgAttacheDom = '', a, display, css, txt, opt_img, 
            content = (msg.content.indexOf('contentEditable') >= 0  || msg.content.indexOf('</') >= 0 || msg.content.indexOf('contenteditable') >= 0) ?  msg.content : loadContent.format_message_content(msg.content, 'linkuser');
        if(msg['image']){ 
           imgAttacheDom = loadContent.getImgAttacheDom(msg['image']) 
        }
        if (msg['title']) {
            html = '<dd class="pagecontent"><span employer_uuid="' +employer_uuid +'" title="'+ title +'"  class="lanucher '+ delete_css +'  '+ delete_uuid +'">' + owner + '</span>：' + msg['title'] + '';
            if ('' !== content)  html += '<div class="ask_description">' + content + '</div>' + imgAttacheDom ; 
        } else {
            html = '<dd class="pagecontent"><span employer_uuid="'+employer_uuid+'" title="'+ title +'" class="lanucher '+ delete_css +' '+ delete_uuid +'">' + owner + '</span>：<pre> ' + content + '</pre>' + imgAttacheDom;
        }           
        if (msg['options']) {
            var obj = msg['options'];
            for (var i = 0; i < obj.length; i++) {
                msg.status.value === obj[i].label ? a = '<input label ="' + obj[i].label + '" name="' + msg['entity_id'] + 'polls" class="polls_radio" type="radio" checked value="" />' : a = '<input class="polls_radio" label ="' + obj[i].label + '" name="' +  msg['entity_id'] + 'polls" type="radio" value="" />';
                msg.status.status === 'voted' ? (css = 'disabledBtn', txt = lw_lang.ID_VOTED ) : (css = 'pollsBtn', txt = lw_lang.ID_VOTE);
                employer_uuid == uuid ? display = 'inline' : (msg.status.status === 'voted' ? display = 'inline' : display = 'none');
                opt_img = loadContent.getpicphoto(obj[i]['image'], 'S');
                html += [
                  '<li>' + a + '<span class="pollsitem">' + obj[i].content + '</span>',
                  '<div class="bigimages">',
                   '<div class="select_map_btn"><a href="###" class="lwork_slideup">'+lw_lang.ID_PACKUP+'</a><a href="###" target="_blank" class="lwork_bingmap">'+ lw_lang.ID_ORIGINAL_PIC +'</a></div>',
                   '<div class="bigimag_content"><img src =""/></div>',
                  '</div>',
                  '<ul><li class="poll_img"><img src="'+ opt_img +'" source = "'+ obj[i]['image'] +'"/></li></ul>',
                  '<div class="vote_count ' + obj[i].label + '"><div class="bar bg"><div class="bar_inner bg2"></div></div><div class="number c_tx3"></div></div></li>'
                ].join("");
            }
            html += ['</dd><dd class="vote_dd"><a class="' + css + '"  msg_id="' + msg['entity_id'] + '"  href="###">' + txt + '</a>',
                      '<a msg_id="' + msg['entity_id'] + '" class="results" style="display:' + display + ';" href="###">'+lw_lang.ID_VIEW_RESULT+'</a>'
                    ].join("");
        } else {
            html += '</dd>';
        }
        return html;
    },
	create_sharefile: function(msg){
		var show_len = getfilesize(msg['file_length']);
			sharer = employer_status[loadContent.employstatus_sub(msg['from'])].name;
		var openfile  = '';
		var filetype = getFileType(msg['name']);
		var css = '';
		var ownership = (msg['from']).toString() === uuid ? 'assign' : 'relate';
		if(filetype == 'rar' || filetype == 'zip' || filetype == '7z' ){
			css = 'rar_files'
		}else if(filetype == 'jpg' || filetype == 'jpeg' || filetype == 'png' || filetype == 'bmp'|| filetype == 'ico' || filetype == 'gif'){
			css = 'pic_files'
		}else if(filetype == 'doc' || filetype == 'docx' || filetype == 'xls' || filetype == 'xlsx'|| filetype == 'ppt' || filetype == 'pptx'|| filetype == 'txt'|| filetype == 'pdf'){
			css = 'doc_files'
		}else{
			css = 'other_files'
		}		
	    html = ['<li class="hover '+ css +'" >',
		 //    '<i class="file_icon '+ filetype +'"></i>',
			 '<span class="fsize file_gray"  task_id = "'+msg['entity_id']+'"  msg_type="documents" ownership="'+ ownership +
                 '" ><a href="/lw_download.yaws?type=raw&fid=' + msg.file_id+'&uuid='+uuid+'" class="sharefilename1">' + msg['name'] + '</a>',	
			 '<span class="my_opts">'+ openfile +
              '<a href="/lw_download.yaws?fid=' + msg.file_id+'&uuid='+uuid + '" target="_blank" class="downloadFile">'+"导出"+'</a>',
//              '<a href="/q_cmd.yaws?fid=' + msg.file_id+'&uuid='+uuid+'&cmd='+'zj' + '" target="_blank" class="downloadFile">'+"再解"+'</a>',
//              '<a href="/q_cmd.yaws?fid=' + msg.file_id+'&uuid='+uuid+'&cmd='+'stop'+ '" target="_blank" class="downloadFile">'+"停止"+'</a>',
//              '<a href="/q_cmd.yaws?fid=' + msg.file_id+'&uuid='+uuid+'&cmd='+'restart'+ '" target="_blank" class="downloadFile">'+"全部重解"+'</a>',
//              '<a href="/q_cmd.yaws?fid=' + msg.file_id+'&uuid='+uuid+'&cmd='+'refresh'+ '" target="_blank" class="downloadFile">'+"刷新"+'</a>',
             '</span></span>',
             '<span class="fsize file_gray"> ' + msg['oks'] + '</span>',            
             '<span class="fsize file_gray"> ' + msg['kjs'] + '</span>',            
			 '<span class="fsize file_gray"> ' + msg['gms'] + '</span>',			  
             '<span class="fsize file_gray"> ' + msg['lefts'] + '</span>',              
             '<span class="fsize file_gray"> ' + msg['status'] + '</span>',              
			 '<span class="fdate file_gray"> ' + msg.timestamp + '</span></li>'		  
			 ].join("");			 
	    return html;
	},
	del_file: function(){
 		 var _this = $(this);
		 var msgid = _this.parent().parent().attr('task_id');
		 var ownership = _this.parent().parent().attr('ownership');
        loadContent.createGeneralConfirm($(this), lw_lang.ID_DELETE_FILE, lw_lang.ID_DELETE_TIP, function(){
		   api.content.del(uuid, [{"type":'documents', "ownership":ownership, "entity_id":msgid.toString()}], function(){
				LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 4, 1000);
				_this.parent().parent().parent().html('').remove();
			});	     
        });
        return false;		
	},
    restart_qq: function(){
        var _this = $(this);
        var msgid = _this.parent().parent().attr('task_id');
        var ownership = _this.parent().parent().attr('ownership');

        api.content.del(uuid, [{"type":'documents', "ownership":ownership, "entity_id":msgid.toString()}], function(){
            LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 4, 1000);
            _this.parent().parent().parent().html('').remove();
        });      
        return false;       
    },
    pause_qq: function(){
         var _this = $(this);
         var msgid = _this.parent().parent().attr('task_id');
         var ownership = _this.parent().parent().attr('ownership');
        loadContent.createGeneralConfirm($(this), lw_lang.ID_DELETE_FILE, lw_lang.ID_DELETE_TIP, function(){
           api.content.del(uuid, [{"type":'documents', "ownership":ownership, "entity_id":msgid.toString()}], function(){
                LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 4, 1000);
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
		$('.vd_sieve').find('span').click(function(){
			 var filetype = $(this).attr('filetype');
			 $(this).addClass('current').siblings().removeClass('current');
			 if(filetype === 'all_files'){
			   $('#file_share_container').find('li').show()
			   return false;	 
			 }
			 $('#file_share_container').find('li').hide()
			 $('#file_share_container').find('.'+  filetype).show()
		})	
//	    loadContent.bind('sharefiles', loadContent.fileshare_handle, 'class');
	    loadContent.bind('pauseqq', loadContent.pause_qq, 'class');
        loadContent.bind('restartqq', loadContent.restart_qq, 'class');
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
		  '<li class="totaskmenu share_menu_on" mode = "topics">'+lw_lang.ID_SHARE_WEIBO+'</li>',
		  '<li class="totaskmenu"  mode = "tasks">'+lw_lang.ID_SHARE_LWORK+'</li>',
		  '</ul></div>',		  
		  '<div class="share_content"> <span class="remindSpan"><span class="countTxt"> '+lw_lang.ID_WORD_REMAIN+'</span></span>',
          '<textarea name="" cols=""  rows="1" class="lwork_mes" sendid=""></textarea>',
          '<a class="sendBtn" style="width:60px;" href="###">'+ lw_lang.ID_SHARE+'</a>',
          '<div class="seatips"></div>',
          '</div></div>'].join("");
	      totips.showtip(_this, html, 30 ,290, '' , 'share');	
		  var obj_link = $('#floattipsshare');
		  obj_link.find('.close').bind('click', function(){totips.hidetips('share')})
		  obj_link.find('.lwork_mes').focus().val(''+lw_lang.ID_SHARE_CLOUD+' \n'); 
		  obj_link.find('.lwork_mes').membersearch({
			  target: obj_link,
			  from:'weibo'
		  });
		  obj_link.find('.share_menu').find('li').click(function(){
			  $(this).addClass('share_menu_on').siblings().removeClass('share_menu_on');
			  type = $(this).attr('mode');
			  type == 'tasks' ?(contianer = $('#mysend_msg'), obj_link.find('.lwork_mes').focus().val(lw_lang.ID_SHARE_CLOUD +'\n')):(contianer = $('#topic_msg') ,obj_link.find('.lwork_mes').focus().val(lw_lang.ID_SHARE_CLOUD + '\n')); 	
		  })
		  obj_link.find('.sendBtn').unbind('click').bind('click', function(){
			 var msg_content =  obj_link.find('.lwork_mes').val(); 
			 var members =  loadContent.getmembers(msg_content);	 
			 var image ='share;' + file_name + ';' + url ;
			 var opt = { uuid: uuid, content:msg_content , members: members, image: image, 't': new Date().getTime()}; 
             loadContent.publish(type, opt, contianer );
			 totips.hidetips('share');
			 return false;
		  })
         ifNotInnerClick(['totips', 'share_top', 'sendBtn', 'sharefiles','totaskmenu', 'share_menu', 'share_content' ,'remindSpan' ,'lwork_mes', 'seatips' ,'maxNum', 'countTxt', 'group_icon', 'member_icon','floatCorner_top','corner'
		 ], function(releaseFunc){totips.hidetips('share');if (releaseFunc){releaseFunc();}});	
	},
    commentmes: function () {
        var _this = $(this);
        var taskid = _this.attr('sendid');
        linkhref = taskid + _this.attr('link');     			
	    obj =_this.parent().parent();
        $('.invite ,.tracewrap, .newcomtWrap, .float_corner_input').hide();
        mode = _this.attr('mode');		
        if (obj.find('.comtWrap').length <= 0) {
            loadContent.createcomtinput(_this, obj, taskid, 'comtWrap', mode, linkhref);           			
            loadContent.loadcomt(mode, taskid, linkhref);
            loadContent.bind(linkhref + '_comtWrapbtn', loadContent.sendcomt, 'id');			
        } else {
            loadContent.loadcomt(mode, taskid, linkhref);
            floatConnerHandle(obj, 'comtWrap');
        }
    },
    new_commentmes: function () {
        var _this = $(this);
        var taskid = _this.attr('sendid');
        linkhref = taskid + _this.attr('link');	
		var	name = _this.attr('name'), mode = _this.attr('mode'), index = _this.attr('findex');	
	    obj =_this.parent().parent();
        $('.invite ,.tracewrap , .comtWrap, .float_corner_input').hide();
        if (obj.find('.newcomtWrap').length <= 0) {
            loadContent.createcomtinput(_this, obj, taskid, 'newcomtWrap', mode, linkhref);
			_this.parent().parent().find('.comtInput').val(lw_lang.ID_REPLY + '@'+ name +':');
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
             loadContent.bind('attachment_header', loadContent.bindAttachHandle, 'class');      
		    loadContent.bind('sub_comment', loadContent.subcomt_handle, 'class');
			loadContent.bind('sub_dialog', loadContent.load_dialog, 'class');
            loadContent.bind_images_scaling();
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
					title: lw_lang.ID_REPLY_DIALOG ,
					content: html,
					id: mode + '_dialoga',
					lock: true,
					fixed: true,
					width: 500,
					button: [{
					 name: lw_lang.ID_CLOSE
					}]
		   });
        });
    },
    createcomtdom: function (obj, task_id, mode) {
		var content = obj.content;
		var temp , name ,photo , delete_css = '', delete_uuid = '' ;
        var attachmentDOM = '';
		if(typeof(loadContent.employstatus_sub(obj.from)) !== 'undefined'){
		   temp = employer_status[loadContent.employstatus_sub(obj.from)];		
		   	photo = temp['photo'];	
			name = getEmployeeDisplayname(obj.from);
			name_employid = temp['name_employid'];
		}else{
			name = lw_lang.ID_UNKNOWN;
			photo = '/images/photo/defalt_photo.gif';	
			name_employid = lw_lang.ID_UNKNOWN;
			delete_css = 'delete_uuid';	
			delete_uuid = 'delete_' + obj.from ;			
		}
		var dialog ='';	
	    if(obj.to && '-1' !== (obj.to).toString() && ( uuid != (obj.to).toString() ||  obj.to != obj.from ) )
		   dialog = '<a href="###" task_id = "'+ task_id +'"  findex="' + obj.findex + '"  mode="'+ mode +'" class="sub_dialog">'+ lw_lang.ID_REPLY_DIALOG +'</a>'; 
        if(typeof(obj.content) === 'object'){
           content = obj.content.content;
           attachmentDOM = loadContent.getImgAttacheDom(obj.content.upload_images);
        }else{
           content = obj.content;
        }
       // content = content.replace(':', '  ');
          content = loadContent.format_message_content(content, 'linkuser');
	       html = ['<dl>',
				 '<dt class="sub_dt"><img src="'+ photo +'" width="28" height="28"/></dt>',		
			     '<dd class="sub_dd"><span employer_uuid="'+ obj.from +'" class="lanucher '+ delete_css +' '+ delete_uuid +'">' + name + '</span>： ' + content + '<span class="gray"> ( ' + obj.timestamp + ' )</span></dd>',
                 '<dd class="sub_dd">'+ attachmentDOM +'</dd>',				
                 '<dd class="sub_comt">'+ dialog +'<a href="###" task_id = "'+ task_id +'"  to = "'+ obj.to +'" tindex="' + obj.tindex + '"  findex="' + obj.findex + '"  name = "'+ name_employid +'" class="sub_comment">'+lw_lang.ID_REPLY+' </a></dd>',
                 '</dl>'
			    ].join("");
        return html;
   },
	subcomt_handle: function(){
		var _this = $(this);
		var name = _this.attr('name');
	    var task_id = _this.attr('task_id');
		comt_index = _this.attr('findex');
		loadContent.target.find('.' + task_id).find('.comtInput').focus().val(lw_lang.ID_REPLY + '@'+name+':');		
	},
    setFocus: function(){
        var _this = $(this);
        var type = _this.attr('type');
        var msgid = _this.attr('msgid');
        api.focus.setFocus(uuid, [{"type":type, "entity_id":msgid, "tags":[]}], function(){
            loadContent.myFocus.setFocus(type, msgid, []);
            _this.removeClass('setFocus').addClass('cancelFocus');
            _this.attr('titile', lw_lang.ID_FAVORITE_REMOVE);
            _this.text(lw_lang.ID_FAVORITE_REMOVE);
            loadContent.bind('cancelFocus', loadContent.cancelFocus, 'class');
            var hide = function () {              
                $('#floattips').html('').remove();
                return false;
            }
            var html = '<div class="new_tag_tip">';
            html += '<div class="set_focus_success_msg">'+lw_lang.ID_FAVORITE_DONE+'</div>';
            html += '<div>' + loadContent.createTagInputer() + '</div>';
            html += '<div class="tag_edit_tip">'+ lw_lang.ID_TAGNAME_NOTE +'</div><ul class="candidate_tags">';
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
                    LWORK.msgbox.show(lw_lang.ID_TAG_EMPTY, 5, 1000);
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
        loadContent.createGeneralConfirm(_this, lw_lang.ID_FAV_NOTE, lw_lang.ID_FAV_NOTE_TIP,  function(){        
            api.focus.cancelFocus(uuid.toString(), type, msgid, function(){
                loadContent.myFocus.cancelFocus(type, msgid);
                if (loadContent.target.attr('id') === 'focus'){
                    _this.parent().parent().remove();
                    loadContent.createTagsMgtDom();
                    var tagsStatistics = loadContent.myFocus.getTagsStatistics();
                    if (tagsStatistics['allFocuses'] === 0){
                        $('#focus_msg').html('<div class="nocontent">'+ lw_lang.ID_FAVORITE_NOTE +'</div>');
                    }else{
                        loadContent.curTag = (tagsStatistics[loadContent.curTag] > 0) ? loadContent.curTag : "allFocuses";
                        $('.tag_mgt').find('#' + loadContent.curTag).click();
                    }
                }

                $('#article').find('.cancelFocus').each(function(){
                    //console.log('walk a msg:{' + $(this).attr('type') + ', ' + $(this).attr('msgid') + '}...');
                    if (($(this).attr('type') === type) && ($(this).attr('msgid') === msgid)){
                        $(this).removeClass('cancelFocus').addClass('setFocus');
                        $(this).attr('titile', lw_lang.ID_ADD_FAVORITE);

                        $(this).text(lw_lang.ID_ADD_FAVORITE);
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
        obj = _this.parent().parent();
        var mode = _this.attr('mode');
        if (obj.find('.tracewrap').css('display') === 'none') {
            $('.float_corner_input').hide();
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
                            owner = getEmployeeDisplayname(traces[i].from);
							delete_css = '';
						    delete_uuid ='';
						}else{
							owner = lw_lang.ID_UNKNOWN;
							photo = '/images/photo/defalt_photo.gif';
							delete_css = 'delete_uuid';	
							delete_uuid = 'delete_' + traces[i].from ;			
						}	
                        if (temp.indexOf('invite') < 0) {							
                            temp === 'read' ? content = lw_lang.ID_TASK_DONE : ( temp == 'voted' ?  content = lw_lang.ID_ATTEND_VOTE :  content = lw_lang.ID_SET_COMPLETE );							
                        } else {
                            content = lw_lang.ID_INVITE;
                            str = temp.split(',');
                            for (var m = 1; m < str.length; m++) {
                                var a = str[m];
								var yaoqing_name = lw_lang.ID_UNKNOWN ;
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
                    obj.find('.trace_content').html(html).parent().slideDown(500, function(){
                         setconner_position(_this, obj.find('.tracewrap'));
                         obj.find('.float_corner').eq(0).show();
                    });
					loadContent.getdelete_name(obj.find('.trace_content'));
                } else {
                    LWORK.msgbox.show(lw_lang.ID_NO_NEWUPDATE, 4, 1000);
                }
            });
        } else {
            obj.find('.float_corner').hide();
            obj.find('.tracewrap').slideUp(500, function () { 
                obj.find('.trace_content').html(''); 

            });


        }
    },
    invitecolleagues: function () {
        var _this = $(this);
        var taskid = _this.attr('sendid');
        linkhref = taskid + _this.attr('link');
        obj = $('#' + linkhref);
        obj.find('.comtWrap ,.tracewrap, .float_corner_input').hide();
        var mode = $(this).attr('mode');
        if (obj.find('.invite').length <= 0) {
            loadContent.createcomtinput(_this, obj, taskid, 'invite', mode, linkhref);
            loadContent.bind(linkhref + '_invitebtn', loadContent.Invitehandle, 'id');            
			$('#' + linkhref + '_invite').tagsInput({
			   'width':'auto', 
			   'height':'30px' ,
			   'getuuid': 'yes',
			   'delimiter':';',
			   'defaultText':lw_lang.ID_SEARCH_TIP
			});	
	       $('#' + linkhref + '_invite_tag').membersearch({
                target: $('#' + linkhref+'_invite_tagsinput'),
                isgroup: 'no',
				from:'invite',
                symbol: ';'
            });	
        } else {
            floatConnerHandle(obj, 'invite');
        }
    },
    Invitehandle: function () {
        var _this = $(this);
        var task_id = _this.attr('sendid');
        var new_members = [];
        var obj = _this.parent().parent();
        var txt = obj.find('.unreadtrace').text();
        var mode = _this.attr('mode');
        var temp_item;
		var reply_content = lw_lang.ID_INVITE;
        var newstr = _this.parent().find('.inputTxt').attr('data');
		newstr.indexOf(';') > 0 ? new_members = newstr.split(';') : new_members[0]  = newstr ;
        for(var i = 0; i < new_members.length; i++ ){
	       reply_content +=  ' @' + employer_status[loadContent.employstatus_sub(new_members[i])].name_employid;
		}
		reply_content += " "+lw_lang.ID_JOIN_WEIBO; 
       if(new_members.length >0){
			api.content.msginvite(mode, task_id.toString(), uuid, new_members, function (data) {
				obj.find('.unreadtrace').text(parseInt(txt) + 1);
				obj.find('.invite').hide();
				obj.find('.inputTxt').val('').focus();
				_this.parent().find('.invitecontent').html('');
				_this.parent().parent().slideUp();

				LWORK.msgbox.show(lw_lang.ID_INVITATION, 4, 1000);
				_this.parent().find('.inputTxt').attr('data', '').val('');
				_this.parent().find('.tagsinput').find('.tag').remove();
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
			    LWORK.msgbox.show(lw_lang.ID_SELECT_INVITE, 4, 1000);
				obj.find('.inputTxt').val('').focus();
	   }
    },
    createcomtinput: function (btnObj, obj, taskid, type, mode, linkhref) {
        var txt;
		var inputcss = "";
        var upFileDom = ['<div class="stb">',
                            '<a href="###" class="upload_attachment">选择文件</a>',
                              '<div class="sharefile_handle">',
                                '<form enctype="multipart/form-data" action ="/lw_upload.yaws?size_limit=10000000" method="post">',
                                  '<input type="file" class="DiskFile" name="upld"  onchange="sharefiles_handle(this, \'attach\')"/>',
                                  '<input type="submit" value="submit_files" class="submit_sharefile"  style="display:none" />',
                                '</form>',
                              '</div>',
                              '<div class="fileList">',
                              '</div>',
                           '</div>'].join('');
		var addattachment = ( type == 'comtWrap' || type === 'newcomtWrap' ? upFileDom: '');
        $('.comtWrap , .invite , .tracewrap').slideUp();		
		type === "invite" ? inputcss = 'comtbtn' : inputcss = 'comtbtn disabledBtn';
		type === 'comtWrap' || type === 'newcomtWrap'? (mode === 'questions' ? txt = lw_lang.ID_ANSWER : txt = lw_lang.ID_REPLY, css = 'comtInput') : (mode === 'documents' ? txt = lw_lang.ID_SHARE : txt = lw_lang.ID_INVITE1, css = 'inputTxt');
        html = ['<div class="' + type + '" style="display:none;">',
				'<div class="float_corner float_corner_input" style="display:none;"><span class="corner corner_1">◆</span> <span class="corner corner_2">◆</span></div><div class="' + type + '_content">',
				'<textarea id="' + linkhref + '_' + type + '" sendid="" data="" class="' + css + '" style="height: 37px;"/>',
				'<a class="'+ inputcss +'" mode="' + mode + '" id="' + linkhref + '_' + type + 'btn"  type="'+ type +'" sendid="' + taskid + '" href="###">' + txt + '</a>',
			   ].join("");
        type === 'invite' ? html += ['<div class="clear"></div> <ul class="invitecontent"></ul>  </div>'].join("") : html += ['<span class="comt_tips"><span id="' + linkhref + type + '_oMaxNum">0</span>/300</span>'+ addattachment +'<div class="comtcontent"></div></div></div>'].join("");
        obj.append(html);		
        obj.find('.' + type).slideDown(500, function(){
               setconner_position(btnObj, btnObj.parent().parent().find('.' + type));
        });
        $('#' + taskid + '_' + type).focus();
        obj.find('.comtInput').keyup(function () {
           confine(300, { 'oConBox': $(this), 'oSendBtn':$(this).next(), 'oMaxNum': $(this).parent().find('.comt_tips span').eq(0) }, 1);
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
          loadContent.dynamic_msgnum('topics', data['topics']);
          loadContent.interval_taskfinish(data['tasks_finished']);
        } ,function(){
          clearInterval(time);
          loadContent.reLogin();
          $('#Interrupt').show();
          time = setInterval(loadContent.reLogin, 12000);          
		}, function(){
          clearInterval(time);
          $('#Interrupt').show();
          time = setInterval(loadContent.reLogin, 12000);
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
			 document.title = loadContent.g_blinkswitch % 2 == 0 ? lw_lang.ID_LWORK_PLATFORM : ID_NEW_MESSAGE_HEADER + num + ID_NEW_MESSAGE_CON + lw_lang.ID_LWORK_PLATFORM;	
		  }else{
			 document.title = lw_lang.ID_LWORK_PLATFORM;
		  }
		}, 500);
	},
	stopBlinkNewMsg: function() {
			if (g_blinkid) {
				clearInterval(g_blinkid);
				g_blinkid = 0;
				document.title = lw_lang.ID_LWORK_PLATFORM;
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
            a + b > 0 ? (obj.show() , showNotification("/images/note.png", lw_lang.ID_MESSAGE_NOTE, lw_lang.ID_MESSAGE_NOTEMSG)) :obj.hide();			
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
				showNotification("/images/note.png", lw_lang.ID_MESSAGE_NOTE, lw_lang.ID_MESSAGE_NOTEMSG);
            } else {
                obj.hide();
            }
        }
        return false;
    },
    vedio_Notice: function (type, data) {
        if (data.length > 0) {
            wVideo.onVideoNotice(data);
        }
    },
    vedio_noticehandle: function () {
        wVideo.handleVideoInvitation($(this));
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
        return false;
    },
    replacecontent: function (msg_content) {
        var to = {};
        var temp = '', sp_temp = '' , group_id;
        var temp_name = '', temp_uuid, text_num;
        var str = msg_content.split('@');
        var get_uuid = function(name){
            if (typeof (name2user[name]) === 'object') {
               if(name2user[name]['uuid']){
                  to[name2user[name]['uuid']] = name2user[name]['uuid'] ;
               }else if(name2user[name]['group_id']){
                  group_id = name2user[name]['group_id']; 
                  for(var key in groupsArray[group_id]['members']){
                     temp_uuid =groupsArray[group_id]['members'][key];                                        
                     temp_name += ' @' + employer_status[loadContent.employstatus_sub(temp_uuid)]['name_employid'];             
                     to[temp_uuid] = temp_uuid;
               }
                 msg_content = msg_content.replace('@' + name, temp_name);
                 if ('' == msg_content) { 
                    LWORK.msgbox.show(lw_lang.ID_ADD_EMPTYGROUP, 2, 1000); 
                    return false; 
                 } 
               }else if(name2user[name]['department_id']){
                     to[name2user[name]['department_id']] = name2user[name]['department_id'] ;  
               }
            }
        }
        for(var i = 0; i < str.length; i++){
            temp = jQuery.trim(str[i]);
            if(name2user[temp]){
                get_uuid(temp); 
                if(msg_content.indexOf('@' + temp) == -1 ) break;    
            }else{
              text_num = temp.length < 50 ? temp.length : 50 ;
              for(var j = 2 ; j <= text_num; j++ ){
                  sp_temp = temp.slice(0, j)
                  if(msg_content.indexOf('@' + sp_temp) == -1 ) break;
                  if(sp_temp == 'all'){
                     to['all'] = (groupsArray['all']['employer_uuid']).toString(); 
                     break;
                  }
                  if(name2user[sp_temp]){
                    get_uuid(sp_temp);
                    break;
                  }
              }
            }
        }
        for(var key in externalEmployees){
            var temp = '@' + externalEmployees[key]['name'] + externalEmployees[key]['eid'] + '/' + externalEmployees[key]['markname']
            if(msg_content.indexOf(temp)>=0){
              to[key] = key;
            }    
        }
        return { 'msg_content': msg_content, 'to': to };
    },
    goback: function () {
        api.request.del('/lwork/auth/logout', { 'uuid': uuid }, function (data) {
            clearInterval(time);
            $.cookie('password', '');
			if($.cookie('company') === 'wuhansourcing') { window.location = "whs_index.html";  return false;}
            QueryString('language') == 'en' ?  window.location = "index.html?language=en" :  window.location = "index.html" ;         	
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
            mode === 'modifyperinof' ? (  fun = loadContent.setpersonalinfo , title = lw_lang.ID_SETTING) : (  fun = loadContent.modifypassword , title = lw_lang.ID_CHANGE_PASSWORD);
            var dialog = art.dialog({
                title: title,
                content: contentId,
                id: mode + '_dialog',
                lock: true,
                fixed: true,
                width: 450,
                height: 200,
			 // cancel: true,
			    button: [{
				 name: lw_lang.ID_OK,
				 focus: true,
				 callback:  fun
				},
				{
				 name: lw_lang.ID_CANCEL
				}
				]
            });
        })
    },
	modify_images: function(){	
		var obj = $('#modify_images');			
		var contentId = document.getElementById('modify_images');		
	    loadContent.updateimg.src(obj);	
		$('.modify_img').unbind('click').click(function(){
            var dialog = art.dialog({
                title: lw_lang.ID_CHANGE_PIC,
                content: contentId,
                id:'upload_images',
                fixed: true,
                width: 450,
                height: 200,
			    button: [{
				  name: lw_lang.ID_OK,
				  focus: true,
				  callback: loadContent.updateimg.update_images
			    },{
				 name: lw_lang.ID_CANCEL
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
					  if (!rFilter.test(oFile.type)) { LWORK.msgbox.show(lw_lang.ID_UPLOAD_PIC, 1, 2000);   return; } 
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
				$('.' +  employer_status[i].employid).find('img').attr('src',photo);
                $.dialog({ id: "upload_images" }).close();     
				return true; 
            });		
	  }
    },
	getpicphoto: function(filename, type){
		var str = filename.split('.');
		var len = str.length;
		var newfilename = '';
		var filetype = getFileType(filename);
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
        /*var phone = obj.find('.telephone').val();*/
        var phone = userPhoneManage.getUserSetPhone();
        var mail = obj.find('.email').val();
        var reg = /^([.a-zA-Z0-9_-])+@([a-zA-Z0-9_-])+((\.[a-zA-Z0-9_-]{2,3}){1,2})$/;
        obj.find('input').keyup(function () { obj.find('.modify_tips').hide(); })
		/*if('' !== phone){
			if (!isPhoneNum(phone)) {
				obj.find('.modify_tips').text(lw_lang.ID_NUM_INPUT).show();
				obj.find('.telephone').focus();
				return false;
			}
		}*/
        if(false == phone)
        {
            obj.find('.modify_tips').text(lw_lang.ID_NUM_INPUT).show();
            obj.find('.telephone').focus();
            return false;
        }
		if(''!== mail){			
			if (!reg.test(mail)) {
				obj.find('.modify_tips').text(lw_lang.ID_EMAIL).show();
				obj.find('.email').focus();
				return false;
			}
		}
        api.content.setpersonalinfo(uuid, department, mail, phone, function (data) {
            var i = subscriptArray[uuid];
            employer_status[i].phone = phone;
            employer_status[i].mail = mail;			
            LWORK.msgbox.show(lw_lang.ID_SUCCESSFUL, 4, 1000);
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
            obj.find('.modify_tips').text(lw_lang.ID_ORG_PASSWORD).show();
            obj.find('.oldpsw').focus();
            return false;
        } else {
            if ('' === new_pass1) {
                obj.find('.modify_tips').text(lw_lang.ID_NEW_PASSWORD).show();
                obj.find('.newpsw1').focus();
                return false;
            } else if (new_pass1.length < 6) {
                obj.find('.modify_tips').text(lw_lang.ID_PASSWORD_LENGTH).show();
                return false;
            } else {
                if (new_pass1 !== new_pass2) {
                    obj.find('.modify_tips').text(lw_lang.ID_PSWD_MATCH).show();
                    obj.find('.newpsw2').focus();
                    return false;
                }
            }
        }
        api.content.modifypassword(uuid, $.cookie('company'), account, md5(old_pass), md5(new_pass1), function (data) {
            if (data.status === 'ok') {
                $.cookie('password', md5(new_pass1), {expires: 30});  
                LWORK.msgbox.show(lw_lang.ID_SUCCESSFUL, 4, 1000);
                obj.find('input').val('');
            } else {
                obj.find('.modify_tips').text(lw_lang.ID_ORGPSWD_ERR).show();
                obj.find('.oldpsw').focus();
                return false;
            }
        });
    },
    taskstatus: function () {
        var obj = $(this).parent().parent();
        var task_id = obj.attr('task_id');
        loadContent.createGeneralConfirm($(this), lw_lang.ID_CONFIRM_COMPLETE, lw_lang.ID_INFORM_TASK, function(){
            api.content.setstatus(task_id, uuid, 'finished', function (data) {
    			var arr =new Array();
    			arr.push({'entity_id':task_id, 'finished_time':  data['finished_time'] })
    			loadContent.taskfinish_handle(arr ,'mysend_msg');
                LWORK.msgbox.show(lw_lang.ID_DONETASK, 4, 1000);					
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
			temp.find('.msg_time').append('<span class="fininshtime">'+lw_lang.ID_DONE+':&nbsp;' + arr[i]['finished_time'] + ' </span>');
			recycleHtml = '<div class="recycle_item"><a href="###" class="recycle_msg_btn" style="display:none" title="'+lw_lang.ID_DELETE_MESSAGE+'"></a></div>'
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
        if (!choice) { LWORK.msgbox.show(lw_lang.ID_SELETE_OPTION, 2, 1000); return false; }
        api.content.votestatus(msg_id, uuid, choice, function (data) {
            _this.removeClass('pollsBtn').addClass('disabledBtn').text(lw_lang.ID_VOTED);
            _this.next().show().click();
            input.attr('checked', false);
            //LWORK.msgbox.show("投票成功，可点击查看投票结果！", 4, 1000);			    
        });
    },
    pollsresult: function () {
        var entity_id = $(this).attr('msg_id');
        var obj = $(this).parent().parent();
		$(this).text(lw_lang.ID_REFRESH_VOTE);
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
                obj.find('.' + voteitem).find('.number').text(votenum + lw_lang.ID_TICKET + ' (' + voteprop + ')');
                obj.find('.' + voteitem).find('.bar_inner').animate({
                    width: voteprop
                }, 2000);
            });
        });
    },
	getAttachmentObj: function(obj){
	   var upload_images = {'multi_images':[], 'multi_attachment':[]};	
	   var List = obj.find('.success');
	   var str;
       var temp = {};
       if(obj.find('.uping').length >0 ){
          pageTips(obj, '文件正在上传,请稍候...');
          return false;
       }else{
           if(List.length > 0){
             List.each(function(){
                 str = $(this).attr('data');
                if(str.indexOf('&&')<0){
                 upload_images['multi_images'].push(str);            
                }else{
                 str =($(this).attr('data')).split('&&');
                 if(!upload_images['multi_attachment']) upload_images['multi_attachment'] = []; 
                   temp = { 'attachment_url' : str[0] , 'attachment_name' : str[1],  'filesize': str[2] , 'createtime' : str[3] };
                   upload_images['multi_attachment'].push(temp);    
                }
             })
           }
           return upload_images;
       }
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
            var upload_images = loadContent.getAttachmentObj(_this.parent());

            if(upload_images == false){
                return false;
            }
			if(content.indexOf(lw_lang.ID_REPLY) === 0){
				var index_start = content.indexOf('@');	
				var index_of = content.indexOf(':');		
				var name = content.slice(index_start + 1,index_of);	
				if(name2user[name]) to = (name2user[name]['uuid']).toString();
			}
			if(to === '-1'){ comt_index = '-1';to = '-1';}
            api.content.sendreplies(mode, task_id, uuid, { 'content': content, 'upload_images': upload_images}, to, comt_index, function (data) {	
                html = loadContent.createcomtdom({'from':uuid, 'timestamp': data.timestamp, 'content': {'content': content, 'upload_images': upload_images} ,'findex':data.index ,to:to } , task_id , mode );				
                $('.' + task_id).find('.comtcontent').prepend(html);
                loadContent.removeUpFiles(_this.parent());
				loadContent.bind('attachment_header', loadContent.bindAttachHandle, 'class');    
				loadContent.bind('sub_dialog', loadContent.load_dialog, 'class');
				loadContent.bind('sub_comment', loadContent.subcomt_handle, 'class');
                $('.' + task_id).find('.unreadcomt').text(parseInt(comt_num, 10) + 1);				
                _this.prev().val('').focus();
                _this.parent().find('.uploadtip').html('').remove();
			if(type === "newcomtWrap")_this.parent().parent().slideUp();				
				_this.next().find('span').eq(0).text(0);				
                LWORK.msgbox.show(lw_lang.ID_REPLY_SUCCESS, 4, 1000);				
                return false;
            });
        }
    },
    focusHandle: function () {
        var _this = $(this);
        var obj = _this.parent().parent().parent();
        var index = parseInt(obj.find('input[type=text]').index(_this), 10);
        var len = obj.find('input[type=text]').length;
        var flag = true;		
        obj.find('input[type=text]').each(function (i) {
            if (i < index) {
                var txt = $(this).val();
                if (txt.indexOf(lw_lang.ID_OPTION) >= 0 || '' === txt) {
                    flag = false;
                    return false;
                }
            } else {
                   return false;
            }
        })
        if (index == len - 1 && len < 5 && flag) {
            _this.parent().parent().clone(true).appendTo(obj);
			_this.parent().parent().next().find('img').attr({'src' : '/images/update_pic.png' , 'source':''});
        }
    },
    polls_item: function () {
        var option = new Array();
        var temp_obj = {};
        $('#polls_option').find('input[type=text]').each(function (i) {
	        var txt = $(this).val();
			var images = $(this).parent().parent().find('img').attr('source');		
            if ('' !== txt && txt.indexOf(lw_lang.ID_OPTION) < 0) {
                temp_obj = { label: String.fromCharCode(65 + i), content: txt, image: images};  
				option.push(temp_obj);
            } else {
			  if(''!== images ){
				temp_obj = { label: String.fromCharCode(65 + i), content: '', image: images};  
				console.log(temp_obj)
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
        var seaBox = $('#search_result');
        var msgtype2name = {'tasks':lw_lang.ID_CO_WORK, 'topics':lw_lang.ID_WEIBO, 'documents':lw_lang.ID_FILE, 'meeting':lw_lang.ID_CONFERENCE_CALL, 'questions':lw_lang.ID_QA,  'polls':lw_lang.ID_BALLOT,'vedio':lw_lang.ID_VIDEOCALL}       
        $('#loading').show();
        loadContent.target.hide();
        seaBox.fadeIn();
        seaBox.find('.search_keyword').eq(0).text(keyword);
        seaBox.find('.search_type').eq(0).text(msgtype2name[type]);
        loadContent.bind('abandon_search_result', loadContent.abandonSearchResult, 'id');       
        api.content.search(uuid, type, keyword, function(data){
            var msg = data[type];
            var count = data["count"];
            var preMode = loadContent.target.attr('id');
            $('#nav').find('.' + preMode).removeClass('li_current').find('a').removeClass('curent');        
            seaBox.find('.search_type').eq(0).text(msgtype2name[type]);
            seaBox.find('.search_result_num').eq(0).text(count.toString());         
            var owner, content, continer='search_result_msg';
            var html = "";
            if (msg && msg.length > 0) {
                $('#' + continer).find('.nocontent').hide();
			  if(type !== 'documents'){         
                for (var i = 0; i < msg.length; i++) { 		   
				    html += loadContent.createContent(msg[i], type, 'none' , (msg[i].status ? msg[i].status : 'all') , continer, 'block');				
                }
			  }else{
				html = ['<ul><li class="hover_top">',       
						 '<em class="uname" style="width:382px;">'+lw_lang.ID_FILENAME+'</em>',
						 '<span class="fsize file_gray" style="width:66px;text-align: left;">大小</span>',
						 '<span class="fdate file_gray">'+lw_lang.ID_UPDATE_TIME+'</span></li>',
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
                $('#' + continer).html('<div class="nocontent">'+lw_lang.ID_NO_RESULT+'</div>');
            }
        }, function () { $('#loading').hide();LWORK.msgbox.show(lw_lang.ID_SERVER_BUSY, 1, 2000); });
    },
    abandonSearchResult: function(){
        var preMode = loadContent.target.attr('id');
        $('#nav').find('.' + preMode).eq(0).click();
    }
}

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
                    buttonDiv.show().append($('<span class="status_box"><a href="###">'+lw_lang.ID_DELETE+'</a></span>').click(function () {
                        li.hide('slow', function () {
                            var phone = li.find('.meeting_member_phone').text();
                            delete phoneDict[phone];
                            li.remove();
                            if ($('#meeting_current_list').find('.meeting_source').length <= 0) {
                                $('#meeting_current_list').find('li').eq(0).addClass('meeting_source').find('.meetingHost').text(lw_lang.ID_MODERATOR);
                            }
                        });
                    })).append($('<span class="host_box"><a class="meetingHost" href="###">'+lw_lang.ID_SET_MODERATOR+'</a></span>').click(function () {
                        li.siblings().removeClass('meeting_source').find('.meetingHost').text(lw_lang.ID_SET_MODERATOR);
                        li.addClass('meeting_source').find('.meetingHost').text(lw_lang.ID_MODERATOR);
                    }));
                    break;
                case 'connecting':
                    statusDiv.show().text(lw_lang.ID_CONNECTING);
                    buttonDiv.hide();
                    break;
                case 'online':
                    statusDiv.show().text(lw_lang.ID_ONLINE);					
	                buttonDiv.show().html('<a href="###">'+lw_lang.ID_HANG_UP+'</a>').unbind('click').bind('click',function () {												
				       loadContent.createGeneralConfirm($(this), lw_lang.ID_HANGUP_NOTE, '', function(){
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
                    statusDiv.show().text(lw_lang.ID_OFFLINE);
                    buttonDiv.show().html('<a href="###">'+lw_lang.ID_REDAIL+'</a>').unbind('click').bind('click',function () {
                        api.meeting.redial(uuid, activeMeetingID, member_id, function () {
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
            name = name || lw_lang.ID_ATTENDEE;
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

        c.init = function (meeting_container) {
            c.pending_list = $('.meeting_box .inputText');
            c.pending_add = $('.meeting_pending_add');
            c.current_list = $('.meeting_current_list');
            c.stopAction = $('#meeting_stop_action');
            c.startAction = $('#meeting_start_action');
            c.history_list = $('.meeting_history_list');

            c.pending_add.unbind('click').bind('click',function (e) {
                if ('' !== c.pending_list.val() && c.pending_list.val() != lw_lang.ID_ENTER_NUM) {
                    parsePendingList(c.pending_list, function (name, phone) {
                        c.addto_current_list(name, phone);
                    });
                    c.pending_list.val('');
                }
                return false;
            });

        };

        c.checkActive = function () {
            api.meeting.get_info(uuid, function (data) {
                var activeMeetings = data['meetings'];
                if (!activeMeetings || activeMeetings.length == 0) {
                    activeMeetingID = null;
                    c.reloadlist([]);
                } else {
                    var activeMeeting = activeMeetings[0];
                    var activeMembers = activeMeeting['details'];
                    activeMeetingID = activeMeeting['meeting_id'];
                    c.reloadlist(activeMembers);
                }
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
                    subject === '' || subject === lw_lang.ID_MEETING_TOPIC ? subject = lw_lang.ID_NEW_MEETING : subject = subject;
                    var h = sprintf('<span class="gray">'+lw_lang.ID_TOPIC+'</span> %s %s',  subject, '<span class="gray">' + history[j]['timestamp'] +'</span>');
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
					    var f='';
						var g = lw_lang.ID_RESTART;	
                        var ret = loadContent.format_message(h, content, f, { 重新发起 : (function (members) {
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
			if (!isPhoneNum(phone)) {
                LWORK.msgbox.show(lw_lang.ID_VOICE_PHONE, 1, 2000);
                return false;
            }	
            if (phoneDict[phone]) return false;
            phoneDict[phone] = 1;
            if (activeMeetingID) {
                api.meeting.add_member(uuid, activeMeetingID, name, phone, function (data) {
                    var member_id = data['new_member']['member_id'];
                    build_member_item(name, phone, 'connecting', member_id, function (li) {
                        memberID2Li[member_id] = li;
                        c.current_list.append(li);
                    });
                }, function(){ });
            } else {
                build_member_item(name, phone, 'pending', '', function (li) {
                    if (c.current_list.children().length <= 0) {
                        li.addClass('meeting_source').find('.meetingHost').text(lw_lang.ID_MODERATOR);
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
                        li.addClass('meeting_source').find('.meetingHost').text(lw_lang.ID_MODERATOR);
                    }
                    c.current_list.append(li);
                });
            }

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
                c.stopAction.show().click(function (e) {
	                e = e || window.event;
                    e.preventDefault();
                    e.stopPropagation();				
                    api.meeting.stopmeeting(uuid, activeMeetingID, function (data) {
                        clearInterval(intervalID);
                        activeMeetingID = null;
                        c.reloadlist([]);
						c.startAction.show();
						meetingController.load_history();	
                    });
					return false;
                });
            } else {
                c.stopAction.hide();
                c.startAction.unbind('click').bind('click',function () { 
                    var meeting_source = c.current_list.find('.meeting_source');
                    var current_members = new Array;
                    c.current_list.children().each(function () {
                        var name = $(this).find('.meeting_member_name').text();
                        var phone = $(this).find('.meeting_member_phone').text();
                        if ($(this).hasClass('meeting_source')) {
                            current_members.splice(0, 0, { name: name, phone: phone });
                        } else {
                            current_members.push({ name: name, phone: phone });
                        }
                    });					
                    var subject = $('.meetingTheme').val();        
					if(current_members.length<2){
                       ajaxErrorTips('meeting' , lw_lang.ID_CALL_NOTE , 'error');
                       HideajaxErrorTips('meeting');
					}else{
						api.meeting.start(uuid,  $.cookie('company') + '_' + $('#username').text() + '_' + $.cookie('account'), subject, current_members, function (data) {						
							activeMeetingID = data['meeting_id'];
							c.reloadlist(data['details']);
						}, function(fdata){                 
                            ajaxErrorTips('meeting' ,fdata, 'error');
                            HideajaxErrorTips('meeting');
                        });
					}
				    return false;
                });				
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
                                           {"type":"documents","timestamp":"2012-9-05 23:4:6","content":{"entity_id":154,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb","file_id":88, "file_length":76637, "name":lw_lang.ID_A_FILE.docx}},
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
                                  "documents":[{"entity_id":154,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb","file_id":88, "file_length":76637, "name":lw_lang.ID_A_FILE.docx},
                                            {"entity_id":154,"from":92,"timestamp":"2012-7-8 23:4:5","content":"@段先德0131000043 @潘刘兵0131000032 杰克有一只小猪bbb","file_id":88, "file_length":76637, "name":lw_lang.ID_A_FILE.pdf}],
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

function mail() {
    this.late
}
function load_mail_menu() {
    f= function(data) {
        $('#mail_list').append(mail2html(data))
    }
    GetMails(f, function(x) {LWORK.msgbox.show('fail to get mail', 1, 2000);});
}

function load_mail_list() {
    f= function(data) {
        $('#mail_list').append(mail2html(data))
    }
    GetMails(f, function(x) {LWORK.msgbox.show('fail to get mail', 1, 2000);});
}

function GetMails(cb,fb) {
    var url = '/mail';
    RestChannel.get(url, {}, cb, fb);
}

function mail2html(data) {  // [{subject:subject, from:from, payload:payload}]
    function mail_item(item) {
        function from(item) {return '<td>'+item['from']+'</td>'}
        function subject(item) {return '<td>'+item['subject']+'</td>'}
        return ['<tr>',
                    from(item),subject(item),
                '</tr>'
        ].join('')
    }
    function mail_items(data) {
        var html = '';
        for (var i=0;i<data.length;i++) {
            html+=mail_item(data[i]);
        }
        return html;
    }
    html = ['<table cellpadding="0" id="inbox_mail_list">',
            '<tbody>',
            mail_items(data.content),
            '</tbody>',
            '</table>'
    ].join('');
    return html;
}

