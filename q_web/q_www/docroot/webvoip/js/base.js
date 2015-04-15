// JavaScript Document

	$.fn.InputFocus = function(){
	   var _this = $(this);
	   _this.focus(function() {
		var obj = $(this);
		if(obj.val() != ''){
		   obj.next().hide();
		 }
	   }).blur(function() {
		 var obj = $(this);
		 if(obj.val() === ''){
		   obj.next().show();
		 }
	   }).next().click(function(){
		   $(this).hide().prev().focus();
	   })
	}
	

	var isPhoneNum = function(str){
		var reg = /^(([+]{1}|(0){2})(\d){1,3})?((\d){10,15})+$/;
		return reg.test(str.replace(/[\(\)\- ]/ig, ''));
	};


	
	var voip = new Voip();
	voip.bindHandlers();
	var video = new mpVideo();
	video.bindHandlers().ready();
	
    var clientwidth ;

	function setDomWidth(){
	   clientwidth = document.body.clientWidth;
	   var linkhref = $('#menu').find('.current').attr('link');
	   var siblink = (linkhref  == 'voip' ? 'video' : 'voip');
	   $('#loading').hide();
	   $('#voip').show().next().fadeIn();
	   $('.box').width(clientwidth);
	  //$('#video').css('left', clientwidth+'px').show();
	   $('#menu').css('left', (clientwidth-365)/2).show();	
	   $('#' + linkhref).css('left', 0)
	   $('#' + siblink).css('left', clientwidth+'px');		

	}
     setDomWidth();
	 window.onresize = 	setDomWidth;

	
	function DownCounter(maxSecond, onSecond, onExpired){
		var curS = maxSecond;
		var timer = null;
		this.run = function (){
			timer = setInterval(function(){
				curS -= 1;
				var min = parseInt(curS / 60);// 分钟数
			    var sec = parseInt(curS % 60);
			    var txt = (parseInt(min, 10) < 10 ? '0' + min : min)  + ":" + (parseInt(sec, 10) < 10 ? '0' + sec : sec);
				
				if(min <= 0 && sec <= 0 && onExpired){
					clearInterval(timer);
			        timer = null;
			        onExpired();
				}else{
				 	if (onSecond){
				 		onSecond(txt);
				 	}
				}

			}, 1000);
        };
		this.stop = function(){
			if (timer){
				clearInterval(timer);
				timer = null;
			}
		};
	}

	
	
	var oScrollbar = $('#countryTips');
    oScrollbar.tinyscrollbar();

(function() {
	$('input.peerNum').InputFocus()
	$('textarea.sugT').InputFocus()
	$('input.peerNum').Lworkkeywork();
	$('.cuntryNum').click(function(){
	 var peer_state = $('#voip').find('input.peerNum').attr('peerstate');
			if(peer_state && peer_state == 'idle'){
			  $('#dialpanel').height(0);
			  if($('.countryTipsBox').height() == 0){
				$('#voip').find('.call_status').hide();
				$('.countryTipsBox').animate({
					height: 230
				 }, 500);
			  }else{
				$('.countryTipsBox').animate({
					height: 0
				 }, 500);		
			 }
		  }	
	})
	var isChrome = window.navigator.userAgent.indexOf("Chrome") !== -1;
	if(!isChrome){
		$('.peer_inputer').width(505).html('<span class="browserCheck"><img src="images/error.png" class="error" width="25" height="25" /> Service for Chrome only.<a href="http://www.google.cn/chrome/intl/zh-CN/landing_chrome.html?hl=zh_cn&brand=CHMA&utm_campaign=zh_cn&utm_source=zh_cn-ha-apac-zh_cn-bk&utm_medium=ha" target="_blank">Install Chrome online</a> <a href="http://pan.baidu.com/share/link?shareid=500175&uk=772255636" target="_blank">Download</a></span>');
		//$('.voip_operations').html('<a href="http://www.google.cn/chrome/intl/zh-CN/landing_chrome.html?hl=zh_cn&brand=CHMA&utm_campaign=zh_cn&utm_source=zh_cn-ha-apac-zh_cn-bk&utm_medium=ha" target="_blank" class="chromeLogo"><img src="images/chromeLogo.png" class="error" width="60" height="60" /></a>')
		$('.voip_operations').hide();
	}
	
		$('.countryTips').find('li').click(function(){
			var _this = $(this);
			$('.countryTipsBox').animate({
				height: 0
			 }, 500, function(){
				 $('.cuntryNum').text(_this.find('.cn').text());
			 });
		
		})
		 $('#suggestion').find('.sendBtn').click(function(){
			 var comments = $('.sugT').val();
			 api.voip.sendsuggestion('90',comments, function (data) {
				$('.sugT').focus().val('');
				$('#sendResult').find('.ok').show().siblings().hide();
				//$('#AboutUsBox').find('.close').click();
			 }, function(){
			  $('.sugT').focus();
			  $('#sendResult').find('.failed').show().siblings().hide(); 
		  });
		 })	 
		 $('.sugT').keyup(function(){
			 $(this).next().hide();
		 })
		 $('#AboutUsBox').find('.close').click(function(){
			 $('#AboutUsBox').animate({
				left: -300,
				top: -100
			 }, 300, function(){
				 $('#voip').show().next().show();
				$('#AboutUsBox').hide(); 
				$('.send_status').hide();
				$('.sugT').val('');
			 });  
		 })	 
			
		$('#menu').find('li').click(function(){
			if(!isChrome){ return false;}
			if(!$(this).hasClass('current')){
				var linkhref =$(this).attr('link');
				var siblink = (linkhref  == 'voip' ? 'video' : 'voip');
				var left = -clientwidth
				$('#menu').removeClass(siblink + '_act').addClass(linkhref + '_act');
				$(this).addClass('current').siblings().removeClass('current');
				$('#' + linkhref).show().animate({
					left: 0
				}, 300)
				$('#' + siblink).show().animate({
					left:left
				}, 300, function(){
					$('#' + siblink).hide().css('left', clientwidth + 'px');
				});
			}
		})
		$('#footer').find('a').click(function(){
			$('#voip').hide().next().hide();
			var winbox = $('#AboutUsBox').show().css({'left':' -300px' ,'top':'-100px'});
			$('#' + $(this).attr('link')).show().siblings().hide();	
			winbox.animate({
				left: (clientwidth-610)/2 ,
				top: 100
			}, 300);
		})
		
} ());	
