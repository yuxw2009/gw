$.fn.Lworkkeywork = function (options) {
    var defaults = {
      keyTarget:$('#dialpanel')
    },
    _this = $(this),
    params = $.extend(defaults, options || {}); 
    function reportDTMF(digitV){
        var sessionid = _this.attr("sessionid");
        api.voip.dtmf('90', sessionid, [digitV], function(){});
    }
    $(this).unbind('keyup').bind('keyup', keyUphandle).unbind('keydown').bind('keydown', keyDownhandle);
    function keyhandle(keyEvent, fun){
        var keycode = keyEvent.keyCode;
        //console.log('keycode=='+keycode);
        switch (keycode) {
            case 48: // M:0
            case 49: // M:1
            case 50: // M:2
            case 52: // M:4
            case 53: // M:5
            case 54: // M:6
            case 55: // M:7
            case 57: // M:9
            case 96: // B:0
            case 97: // B:1
            case 98: // B:2
            case 99: // B:3
            case 100: // B:4
            case 101: // B:5
            case 102: // B:6
            case 103: // B:7
            case 104: // B:8
            case 105: // B:9
               fun(keycode);
               break;
            case 51:  // M:3 or mark
                if (keyEvent.shiftKey){
                    fun('mark');
                }else{
                    fun(keycode);
                }
                break;
            case 56:  // M:8 or star
                if (keyEvent.shiftKey){
                    fun('star');
                }else{
                    fun(keycode);
                }
                break
            case 106: // B:star
               fun('star');
               break;
        }
    }
    function keyDownhandle(e) {
        var  e = e || window.event;
           // params.keyTarget.find('a').removeClass('keyActive');
		     $(this).find('a').addClass('keyActive'); 
            keyhandle(e, function(Digit){
				params.keyTarget.find('.key_'+Digit).addClass('keyActive'); 
                var dial_panel_mode = _this.attr("dial-panel-mode"),
                peer_state = _this.attr('peerstate');
                if (dial_panel_mode == 'perm' && peer_state == 'hookoff'){
                    reportDTMF(params.keyTarget.find('.key_'+Digit).eq(0).text());
                }
            })
    }

    function keyUphandle(e) {
        var  e = e || window.event;
		var val = $(this).val();
		var reg = /[^\d]/g;
        var keycode = e.keyCode;
		var peer_state =  $(this).attr('peerstate');
			params.keyTarget.find('.key_'+keycode).removeClass('keyActive'); 
		   if(val == ''){
			   
			 $('#dialpanel').animate({
					height: 0
			 }, 500); 			   
		   }
		   if(reg.test(val)){
				 $(this).val(val.replace(/[^\d|#|*|-]/g,''));
				 $('.countryTipsBox').height(0)
				 $('#dialpanel').animate({
					height: 230
				 }, 500); 
		   }
		   $(this).next().hide();
		   if(peer_state && peer_state == 'idle'){
			     $('#voip').find('.call_status').hide();
		   }
		   
//            keyhandle(e, function(Digit){
//                params.keyTarget.find('.key_'+Digit).addClass('keyActive'); 
//                var dial_panel_mode = _this.attr("dial-panel-mode"),
//                peer_state = _this.attr('peerstate');
//                if (dial_panel_mode == 'perm' && peer_state == 'hookoff'){
//                    reportDTMF(params.keyTarget.find('.key_'+Digit).eq(0).text());
//                }
//            })
    }
    params.keyTarget.find('a').click(function(){ 
        var digitV = $(this).text(); 
        var inputer = $('#voip').find('input.peerNum');
        var dial_panel_mode = _this.attr("dial-panel-mode"),
            peer_state = _this.attr('peerstate');
			
        params.keyTarget.find('a').removeClass('keyActive');
        $(this).addClass('keyActive');
		     inputer.focus().val(inputer.val() + digitV);
        if (dial_panel_mode == 'perm' && peer_state == 'hookoff'){
			 $('#dialpanel').animate({
				height: 230
			 }, 500); 			
            reportDTMF(digitV);
          //  inputer.focus().val(inputer.val() + digitV);
        }
        return false;
    });
}
var TalkIntervalTime = 0;
function Voip(){
	this.wrtcClient = new webrtcClient(this);
	this.peerNum = '';
    this.peerName = '';
	this.sessionID = null;
	this.intervalID = null;
    this.downCounter = null;
	
}
Voip.prototype = {
	bindHandlers: function(){
		var curObj = this;
		var vbox = $('#voip');
        $('#voip_start').unbind('click').bind('click', function(){curObj.voipStart();});
        $('#voip_stop').unbind('click').bind('click', function(){curObj.voipStop();});
        vbox.find('a.showpanel').unbind('click').bind('click', function(){
            if ($(this).hasClass('toshow')){
                $('#dialpanel').show();
                $(this).removeClass('toshow').addClass('tohide');
            }else{
                $('#dialpanel').hide();
                $(this).removeClass('tohide').addClass('toshow');
            }
        });
	},
	prepareToCall: function(){
		this.voipStopped();
	},
	VoipStatus:function(status, txt){
	    $('#voip').find('.call_status').show().find('.' + status ).show().siblings().hide();	
        $('#voip').find('.voip_call_status').text(txt);
	},

    onPeerRing: function(){
        var peerDisplay = this.peerName.length > 0 ? this.peerName : '';
        $('#voip').find('input.peerNum').attr('peerstate', 'ring').attr('disabled', 'disabled');
		this.VoipStatus('ring', 'Ringing...');
    },


    onPeerHookoff: function(){
        var curObj = this;
		if(TalkIntervalTime == 0){
			//timedCount('voip', 0);
            if (this.downCounter){
                this.downCounter.stop();
            }
            curObj.downCounter = new DownCounter(60, function(txt){
                $('#voip').find('.callTimeTtext').text(txt).parent().show();
            }, function(){
                voip.VoipStatus('warning', 'Time out, thanks for tring');
                voip.voipStop('error');
            });
            curObj.downCounter.run();
			$('#voip').find('input.peerNum').attr('peerstate', 'hookoff').attr('disabled', false);
			curObj.VoipStatus('talking', 'In speaking...');
		}
		TalkIntervalTime++;	
    },
    onPeerHookon: function(){
        $('#voip').find('input.peerNum').eq(0).attr('peerstate', 'hookon');
	    this.VoipStatus('error', 'Peer hung up.');	
        this.voipStopped('error');
    },
    voipStart: function(){
    	var curObj = this,
		 vbox = $('#voip'),
         vobj = vbox.find('input.peerNum'),
		 vobjVal = vobj.val(),
         peerNum  = (vbox.find('.cuntryNum').text()).replace('+', '00')  + (vobjVal.slice(0,1) == '0' ? vobjVal.slice(1) : vobjVal);
        if ( '' == vobj.val()){
	     	curObj.VoipStatus('warning', 'Peer number can NOT be empty.');	
            return false;
        }else if(!isPhoneNum(peerNum)){
			curObj.VoipStatus('warning', 'Make sure the Num is correct.');	
            vbox.find('input.peerNum').focus();
            return false;
        }
        curObj.peerName = '';
		curObj.peerNum = peerNum;		
        $('#voip').find('input.peerNum').eq(0).attr('disabled', 'disabled');
		curObj.VoipStatus('micro', 'Please click the "Allow" button above.');
        curObj.wrtcClient.prepareCall('audio', null);
		$('#dialpanel').animate({ height: 0	 });
		$('.countryTipsBox').animate({ height: 0 });
        return false;
    },
    voipStop: function(ifError){
        var curObj = this;
        api.voip.stop('90', curObj.sessionID, function(){
            curObj.voipStopped(ifError);
        });
        return false;
    },
	voipStarted: function(){
        var peerDisplay = this.peerName.length > 0 ? this.peerName : '';
        $('#voip').find('input.peerNum').attr('dial-panel-mode','perm').attr('sessionid',this.sessionID).attr('peerstate','connecting').attr('disabled', 'disabled');
        $('#voip').find('input.peerNum').val($('#voip').find('input.peerNum').eq(0).val()+'-');
		$('#voip_stop').show();
		$('#voip_start').hide();
		this.VoipStatus('calling', 'Calling...');
		this.startInterval();
	    $('#dialpanel').animate({ height: 0	 });
		$('.countryTipsBox').animate({ height: 0 });
	},
	voipStopped: function(status){
		this.stopInterval();
		this.wrtcClient.terminateCall();
	    this.peerNum = '';
        this.peerName = '';
	    this.sessionID = null;
	    this.intervalID = null;
		$('#voip').find('input.peerNum').eq(0).val('').attr({'dial-panel-mode':'temp', 'phone':'', 'name':'', 'sessionid':'', 'peerstate':'idle', 'disabled':false}).focus().blur();
	    if(!status&&status!='error' ){
		  $('#voip').find('.call_status').hide();
		}else{
		  setTimeout(function(){
			$('#voip').find('.call_status').hide();
		  }, 2000);
		}
		$('#dialpanel').animate({ height: 0	 });
		$('.countryTipsBox').animate({ height: 0 });		
        $('#voip_start').show();
        $('#voip_stop').hide();
		if (this.downCounter){
            this.downCounter.stop();
            $('#voip').find('.callTimeTtext').text('00:00').parent().hide();
        }
		TalkIntervalTime = 0;
	},
	startInterval: function(){
		var curObj = this;
        var interval = function(){  
        	api.voip.get_status('90', curObj.sessionID, function (data) {
                switch (data.state){
                    case 'ring':
                        curObj.onPeerRing();
                        break;
                    case 'hook_off':
                        curObj.onPeerHookoff();
                        break;
                    case 'hook_on':
                    case 'released':
                        curObj.onPeerHookon();
                        break;
                }
            }, function(){
		       // curObj.VoipStatus('error', '对端已挂机！');	
               // curObj.voipStopped('error');
            }); 
        }
        interval();
        curObj.intervalID = setInterval(interval , 3000);
	},
	stopInterval: function(){
		var curObj = this;
        if (curObj.intervalID){
            clearInterval(curObj.intervalID);
            curObj.intervalID = null;
        }
	},
	doStart: function(sdp){
		var curObj = this;
        var peerDisplay = this.peerName.length > 0 ? this.peerName : '';
		curObj.VoipStatus('calling', 'Calling...');
		api.voip.start('90', sdp, curObj.peerNum, function(data){
			curObj.sessionID = data['session_id'];
			curObj.wrtcClient.setRemoteSDP(data['sdp']);
			curObj.voipStarted();
		}, function(){
			curObj.VoipStatus('error', 'Server is busy, please try again later.');	
			curObj.voipStopped('error');
		});
	},
    // the following three functions are webrtcClient callbacks..
	onLocalSDP: function(localSDP){
        this.doStart(localSDP);
    },
    onLocalStream: function(localURI){
		this.VoipStatus('smile', 'Preparing to call...');		
	},
    onRemoteStream: function(remoteURI){
        $("#voip_obj").attr('src', remoteURI);
    },
    onWrtcError: function(error){
		this.VoipStatus('error', "You've forbiden using your microphone.");	
		$('#voip').find('input.peerNum').attr('disabled', false);
	    $('#dialpanel').animate({ height: 0	 });
		$('.countryTipsBox').animate({ height: 0 });		
    }
}