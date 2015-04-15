
var autoFillInput=function(){
	var account = $.cookie('account');
	if (account){
	 	$('#login').find('input.usename').val(account.toString());
	 	$('#login').find('input.password').focus();
	}else{
		$('#login').find('input.usename').focus();
	}
}

var oScrollbar = null;
var save2Cookie = function(account, password){
	$.cookie('account',account, {expires: 30});
	$.cookie('password', password, {expires: 30});
}
var curAccount = '';
var curPassword = '';
var doLogin = function(account, passwordMD5, sucCallback, failCallback){
	var url = '/login';
	var data = {'account': account,'password': passwordMD5, 't': new Date().getTime()};
	$.post(url,JSON.stringify(data),function(data){	
		if(data.status == 'ok'){
			curAccount = account;
			curPassword = passwordMD5;

			//if (window.location.href != "index.html"){
	            //window.location.href="index.html";
	        //}else{
				sucCallback();
				$('#initBox').hide();
				$('#task-bar').show();
				$('#desk').show();
				$('#contactBox').find('.cb_con').height($(window).height() - 300) 	
				$('#contactBox').show();
				mainmark = mainmark ? mainmark : (new mainMark());
			    mainmark.build(data);
				afterLogin(data.uuid.toString(), data.attributes.nick_name, data.attributes.photo, data.attributes.signature);
			    setTimeout(function(){queryOngoingConf(data['sessions']);}, 1000);
	        //}
		}else{
			if (failCallback){
				failCallback(data.reason);
			}
			$('#initBox').show();
			$('#task-bar').hide();
			$('#desk').hide();
			$('#contactBox').hide();
		}
	})
}

var tryAutoLogin=function(){		
	var account = $.cookie('account'),
	    passwordMD5 = $.cookie('password');				
	if (account && passwordMD5){
 	doLogin(account, passwordMD5, function(){}, function(){
 		autoFillInput();
 	});
  }
}

var queryOngoingConf = function(sessions){
	for(var i=0; i< sessions.length;i++ ){
		if (hp){
			hp.sendData({type:'query_ongoing_conf', session_id:sessions[i].session_id.toString()})
		}
	}
}

$('#login input.usename, #login input.password').keyup(function(event){	
	$(this).parent().removeClass('error');
	e = event ? event : (window.event ? window.event : null);
	if (e.keyCode != 13) {		 
	   removePageTips($(this).parent());
	   return false;
	}
});

$('#login .loginbtn').click(function(){
	var account = $('#login input.usename').val(),
	    password = $('#login input.password').val();
	if(''===account){
	  pageTips($('#login input.usename').parent(), 'Empty username is not allowed', 'error');
	  $('#login input.usename').focus();
	  return false;
	}
	if(''===password){
	 // LWORK.msgbox.show('密码不能为空', 3, 2000);	 
	  //$('#login input.password').focus().parent().addClass('error');
	    pageTips($('#login input.password').parent(), 'Empty password is not allowed', 'error');
		$('#login input.password').focus();
	    return false;
	}
	var passwordMD5 = md5(password);
	doLogin(account, passwordMD5, function(){
		var ifautologin = $('#login .autologin').attr("checked");
		if (ifautologin == 'checked' || ifautologin == true){
	        save2Cookie(account, passwordMD5);
	    }
	},function(failReason){
		if(failReason === 'wrong_auth'){		
		    // LWORK.msgbox.show('用户名或密码错误', 5, 2000);	 
	 	     pageTips($('#login input.password').parent(), 'Wrong username or password', 'error');
		     $('#login input.usename').focus();
	         $('#login input.password').val('');
		}else{
			 pageTips($('#login input.password').parent(), 'Login unsuccessfully', 'error');
			 $('#login input.password').focus();
			//LWORK.msgbox.show('登陆失败', 5, 2000);
		}
	});
});	


$('#login').find('.register').click(function(){
   $('#login').fadeOut(400, function(){

   	$(this).next().fadeIn();
   })

})

document.getElementById('login').onkeydown = function (event) {
	e = event ? event : (window.event ? window.event : null);
	if (e.keyCode == 13) {
	    $('#login .loginbtn').click();
	    return false;
	}
}

/////
// To register
/////

var  checkUserName = function(userName, onUserNameDuplicated){
    var url = '/login/check_user_name';
	var data = {user_name:userName, 't': new Date().getTime()};
	$.post(url,JSON.stringify(data),function(data){
		if(data.status == 'ok'){
		}else{
			if (data.status && data.status == 'failed' && data.reason == 'dup_name' && onUserNameDuplicated){
				onUserNameDuplicated();
			}
		}
	})
}

var registerUser = function(userName, pwdMD5, onRegisterOK, onRegisterFailed){
	var url = '/login/register_user';
	var data = {user_name:userName, password:pwdMD5, 't': new Date().getTime()};
	$.post(url,JSON.stringify(data),function(data){
		if(data.status == 'ok'){
			onRegisterOK(userName, pwdMD5);
		}else{
			if (data.status && data.status == 'failed' && onRegisterFailed){
				onRegisterFailed(data.reason);
			}
		}
	})
}


$('#register input.usename').blur(function(){
	var self = $(this);
	checkUserName(self.val(), function(){
        pageTips($('#register input.usename').focus().parent(), 'This username has been used', 'error');
	});
	return false;
});

$('#register input').keyup(function(){
	removePageTips($(this).parent());
});

$('#register .registerbtn').click(function(){
	var account = $('#register input.usename').val(),
	    password1 = $('#register input.password1').val(),
	    password2 = $('#register input.password2').val();
		
	if(''===account){
	  pageTips($('#register input.usename').focus().parent(), 'Empty username is not allowed', 'error');
	  return false; 
	}
	if(account.indexOf() != -1){
	  pageTips($('#register input.usename').focus().parent(), 'No Blank is allowed to be included', 'error');
	  return false; 
	}

	if(''===password1){
	  pageTips($('#register input.password1').focus().parent(), 'Empty password is not allowed', 'error');
	    return false;
	}
	if(password1!=password2){
	  pageTips($('#register input.password2').focus().parent(), 'The two password do not match', 'error');
	    return false;
	}
	var passwordMD5 = md5(password1);
	registerUser(account, passwordMD5, function(){
		doLogin(account, passwordMD5, function(){
				$('#register').hide();
			}, function(){
		 		autoFillInput();
		 		$('#register').hide();
		 	});
		},function(failReason){
			if(failReason === 'dup_name'){		
			    pageTips($('#register input.usename').focus().parent(), 'This username has been used', 'error');	 
			}else if (failReason === 'user_full'){
				pageTips($('#register .registerbtn').parent(), 'The registeration is closed', 'error');
			}else{
				pageTips($('#register .registerbtn').parent(), 'Register unsuccessfully', 'error');
			}
		}
	);
});	

$('#register .cancel').click(function(){
	$('#register').find('input').val('');
	$('#register').hide().prev().fadeIn();
})

document.getElementById('register').onkeydown = function (event) {
	e = event ? event : (window.event ? window.event : null);
	if (e.keyCode == 13) {
	    $('#register .registerbtn').click();
	    return false;
	}
}

