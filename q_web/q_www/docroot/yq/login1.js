var login_lang_en ={
	ID_TIP_COM:'Communication Easier',
	ID_TIP_MOBILE:'Anywhere Working',
	ID_TIP_PROJECT:'Task Tracing',		
	ID_TIP_SHARE:'Knowledge Sharing',
	ID_TIP_Cost:'Cost Reducing'	,	
	ID_APP_DOWN:'Mobile Apps',		
	ID_INPUT_COMPANY:'Company ID',	
	ID_INPUT_ACCOUNT:'Username',		
	ID_INPUT_PSW:'Password',
	ID_COMPANY_TIP:'Enter your company',				
	ID_PSW_TIP:'Enter your password',			
	ID_ACCOUNT_TIP:'Enter your account',	
	ID_BTN_LOGIN:'Sign in',		
	ID_LWORK_TIP:'images/login_log_en.png',	
	ID_lign_box:'images/login_log_en.png',
	ID_WRONG_box:'The account or password you entered is incorrect.'
}

var login_lang_ch ={ 
	ID_TIP_COM:'便捷通讯',
	ID_TIP_MOBILE:'移动融合',	
	ID_TIP_PROJECT:'项目追踪',		
	ID_TIP_SHARE:'知识共享',
	ID_TIP_Cost:'降低成本',	
	ID_APP_DOWN:'手机客户端下载',		
	ID_INPUT_COMPANY:'企业标识',		
	ID_INPUT_ACCOUNT:'账号',		
	ID_INPUT_PSW:'密码',	
	ID_PSW_TIP:'企业标识不能为空！',				
	ID_PSW_TIP:'密码不能为空！',			
	ID_ACCOUNT_TIP:'账号不能为空！',	
	ID_BTN_LOGIN:'登 录',
	ID_LWORK_TIP:'images/login_log.png',
	ID_WRONG_box:'账号或者密码有误！'
}

var login_lang = login_lang_ch;

function QueryString(uriStr){
  var sea =  (window.location.search).slice(1);
  var str = sea.split('&');
  var query;  
  for(var i =0 ; i < str.length; i++){
    query = str[i].split('=');
	if( query[0] == uriStr ) return query[1] ;
  }
  return ''	
}
// 文本框插件			   
$.fn.searchInput = function (options) {
	var _this = $(this);
	_this.focus(function(){
		_this.next().hide();
	}).blur(function(){
	   if($(this).val() === '')	 _this.next().show();
	})
	_this.next().click(function(){
		 _this.focus();		 
	})
}

var setHeight=function(){
	var clientHeight = document.documentElement.clientHeight > document.body.clientHeight ? document.documentElement.clientHeight :document.body.clientHeight;
	if(clientHeight < 725) clientHeight = 725 ;                  
	$('.bottom').css('top',clientHeight - 200  + 'px')
	$('.copyright').css('top',clientHeight - 50  + 'px')
	$('#current_box').css('top', clientHeight - 565  + 'px')
}
window.onresize = function(){ setHeight();}
$('#company').searchInput();
$('#usename').searchInput();
$('#password').searchInput();
var autoFillInput=function(){
	var company = $.cookie('company'),
	    account = $.cookie('account');
	$('#login').find('input.company').focus();
	if (company){
	    $('#login').find('input.company').val(company.toString());
    	$('#login').find('input.usename').focus();
}
if (account){
 	$('#login').find('input.usename').val(account.toString());
 	$('#login').find('input.password').focus();
}
}
setHeight();
autoFillInput();	
var save2Cookie = function(company, account, password, uuid){	
$.cookie('company',company, {expires: 30});
$.cookie('account',account, {expires: 30});
$.cookie('password', password, {expires: 30});		
$.cookie('uuid',uuid);
}
var doLogin = function(company, account, passwordMD5, deviceToken,  failCallback){
	var url = '/lwork/auth/login';
	var language =  $.cookie('language')?  $.cookie('language'):$('.current_lan').attr('lang');
	var data = {'company':company, 'account': account,'password': passwordMD5,'deviceToken': deviceToken,'t': new Date().getTime()};
	$.post(url,JSON.stringify(data),function(data){
			if(data.status === 'ok'){	
			   save2Cookie(company, account, passwordMD5, data['uuid']);
			   language == 'en' ?  window.location = "lw_yq.yaws?language=en&uuid=" + data['uuid'] :  window.location = "lw_yq.yaws?uuid=" + data['uuid'];
			   //window.location = "lwork.html";
			}else{
				if (failCallback){
					failCallback(data.reason);
				}
			}
	})
}

var tryAutoLogin=function(){
var sea =  window.location.search;
if(sea.indexOf('auto_login')>=0)
return false;		
	var company = $.cookie('company'),
	    account = $.cookie('account'),
	    passwordMD5 = $.cookie('password'),
	    deviceToken = '';				
	if (company && account && passwordMD5){
 	doLogin(company, account, passwordMD5, deviceToken, function(){
 		autoFillInput();
 	});
  }
}
tryAutoLogin();
window.onresize =setHeight;
$('input.usename ,input.password').keyup(function(event){	
e = event ? event : (window.event ? window.event : null);
if (e.keyCode != 13) {		 
   $('#tips').hide();
   return false;
 }
})

$('.switch_language').find('a').click(function(){	
  var _this = $(this);
  var lang = _this.parent().attr('lang');
  lang =='en' ? (login_lang = login_lang_en , $('body, input, textarea').css('font-family','Helvetica, Arial, sans-serif')) : (login_lang = login_lang_ch,  $('body, input, textarea').css('font-family','"微软雅黑"')); 
  _this.parent().addClass('current_lan').siblings().removeClass('current_lan');
	  $('#commu').text(login_lang.ID_TIP_COM);
	  $('#mobile').text(login_lang.ID_TIP_MOBILE);
	  $('#proj').text(login_lang.ID_TIP_PROJECT);
	  $('#knowledge').text(login_lang.ID_TIP_SHARE);  
	  $('#cost').text(login_lang.ID_TIP_Cost);
	  $('#company_tip').text(login_lang.ID_INPUT_COMPANY);
	  $('#usename_tip').text(login_lang.ID_INPUT_ACCOUNT);  
	  $('#pssword_tip').text(login_lang.ID_INPUT_PSW);   
	  $('#submit').text(login_lang.ID_BTN_LOGIN);
	  $('#mbt').text(login_lang.ID_APP_DOWN);
	  $('#logo_img').attr('src', login_lang.ID_LWORK_TIP);
	  $('#login_top').text(login_lang.ID_BTN_LOGIN);
	  $.cookie('language',lang, {expires: 30});
})
$('#submit').click(function(){
var company = $('input.company').val(), 
    account = $('input.usename').val(),
    password = $('input.password').val(),
    deviceToken = '';
if (''===company){
//	$('#tips').text(login_lang.ID_COMPANY_TIP).show();
    $('#tips').text(login_lang.ID_ACCOUNT_TIP).show();
    $('input.company').focus();
    return false;
}else{
	company = company.toLowerCase();
}

if(''===account){
  $('#tips').text(login_lang.ID_ACCOUNT_TIP).show();
  $('input.usename').focus();
  return false;
}

if(''===password){
  $('#tips').text(login_lang.ID_PSW_TIP).show();		 
  $('input.password').focus();
    return false;
}
doLogin(company, account, md5(password), deviceToken, function(failReason){
	if(failReason === 'wrong_auth'){		
	     $('#tips').text(login_lang.ID_WRONG_box).show();
	     $('input.usename').focus();
         $('input.password').val('');
	}else{
	     $('#tips').text(login_lang.ID_WRONG_box).show();
         $('input.usename').focus();						  
	}
});
});	

if(QueryString('language') == 'en' || $.cookie('language') === 'en'){
   $('.switch_language').find('.en').click();
}
document.onkeydown = function (event) {
	e = event ? event : (window.event ? window.event : null);
	 if (e.keyCode == 13) {
	    $('#submit').click()
	    return false;
	}
}

$('#kefubox').find('.kefu_tel').click(function(){
	var statusObj = $('#telstatus');
	var teltipbox = $('#telkefubox');
	if(teltipbox.css('display') == 'block'){
	   return false;
	}else{
	   $('#telkefubox').slideDown();
	}
	lwStartVoip(Math.floor(Math.random(11)*10E11), '18616820929', {
	    userclass: 'registered',
		media_ok:function(){
		  statusObj.text('正在初始化媒体...');
		},
		media_fail:function(){
		  statusObj.text('获取媒体失败...');
		  lwhangup();
		},	
		ringing:function(){
		  statusObj.text('正在振铃...');
	    },
	   talking:function(){
		  statusObj.text('正在通话...');		
	   },
	   peerhangup:function(){
		  statusObj.text('对方已挂断！');
		  lwhangup();
	   }
	});
	
})

$('#kefubox').find('.kefu_video').click(function(){
	 LworkClintCall('video');

})


function lwhangup(){
   $('#telkefubox').slideUp();
   lwStopVoip();
   return false;
}
$('#hanguptel').bind('click', lwhangup);
