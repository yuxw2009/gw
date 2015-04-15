$.fn.Lworkkeywork = function (options) {
    var defaults = {
      keyTarget:$('#dialpanel')
    },
    _this = $(this),
    params = $.extend(defaults, options || {}); 

    function reportDTMF(digitV){
        var sessionid = _this.attr("sessionid");
        api.voip.dtmf(uuid, sessionid, [digitV], function(){});
    }

    $(this).unbind('keydown').bind('keydown', keyDownhandle);

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
            params.keyTarget.find('a').removeClass('keyActive');
            keyhandle(e, function(Digit){
                params.keyTarget.find('.key_'+Digit).addClass('keyActive'); 
                var dial_panel_mode = _this.attr("dial-panel-mode"),
                peer_state = _this.attr('peerstate');
                if (dial_panel_mode == 'perm' && peer_state == 'hookoff'){
                    reportDTMF(params.keyTarget.find('.key_'+Digit).eq(0).text());
                }
            })
    }

    params.keyTarget.find('a').click(function(){ 
        var digitV = $(this).text(); 
        var inputer = $('#voip').find('input.peerNum');
        var dial_panel_mode = _this.attr("dial-panel-mode"),
            peer_state = _this.attr('peerstate');
            
        params.keyTarget.find('a').removeClass('keyActive');
        $(this).addClass('keyActive');
        if (dial_panel_mode == 'perm' && peer_state == 'hookoff'){
            reportDTMF(digitV);
            inputer.focus().val(inputer.val() + digitV);
        }else if (dial_panel_mode == 'temp'){
            inputer.focus().val(inputer.val() + digitV);
        } 
        return false;
    });
}

function Voip(){
	this.wrtcClient = new webrtcClient(this);
	this.peerNum = '';
    this.peerName = '';
	this.sessionID = null;
	this.intervalID = null;
}
Voip.prototype = {
	bindHandlers: function(){
		var curObj = this;
        $('#voip').find('input.peerNum').Lworkkeywork();
        $('#voip_start').unbind('click').bind('click', function(){curObj.voipStart();});
        $('#voip_stop').unbind('click').bind('click', function(){curObj.voipStop();});
        $('#voip').find('a.showpanel').unbind('click').bind('click', function(){
            if ($(this).hasClass('toshow')){
                $('#dialpanel').show();
                //$(this).text('拨盘关');
                $(this).removeClass('toshow').addClass('tohide');
            }else{
                $('#dialpanel').hide();
                //$(this).text('拨盘开');
                $(this).removeClass('tohide').addClass('toshow');
            }
        });
	},
    VoipStatus:function(status, txt){
        $('#voip').find('.call_status').show().find('.' + status ).show().siblings().hide(); 
        $('#voip').find('.voip_call_status').attr('class', 'voip_call_status').addClass(status+'tip').text(txt);
    },
	prepareToCall: function(){
		this.voipStopped();
	},
    onPeerRing: function(){
        var peerDisplay = this.peerName.length > 0 ? this.peerName : '';
        $('#voip').find('input.peerNum').eq(0).attr('peerstate', 'ring').attr('disabled', 'disabled');
        //$('#voip').find('.voip_call_status').eq(0).empty().append('<span class="peerNumStr">'+peerDisplay+'</span>'+ lw_lang.ID_PEER_RINGING +'...');
        // $('#voip').find('.voip_call_status').eq(0).empty().append()
        //$('#voip').find('.peer_status').css('background-position', 'left -2370px');
        this.VoipStatus('ring', lw_lang.ID_PEER_RINGING +'...');
    },
    onPeerHookoff: function(){
        var peerDisplay = this.peerName.length > 0 ? lw_lang.ID_TALKING_H + this.peerName : '';
        $('#voip').find('input.peerNum').eq(0).attr('peerstate', 'hookoff').attr('disabled', false);
        //$('#voip').find('.voip_call_status').eq(0).empty().append(peerDisplay + );
        //$('#voip').find('.voip_call_status').eq(0).empty().append(lw_lang.ID_TALKING_H +'<span class="peerNumStr">'+peerDisplay+'</span>'+ lw_lang.ID_TALKING_F +'...');
        //$('#voip').find('.peer_status').css('background-position', 'left -2370px');
        this.VoipStatus('talking', lw_lang.ID_TALKING_F +'...');
    },
    onPeerHookon: function(){
        $('#voip').find('input.peerNum').eq(0).attr('peerstate', 'hookon');
    	LWORK.msgbox.show(lw_lang.ID_CALL_END, 4, 2000);
        this.voipStopped();
    },
    voipStart: function(){
    	var curObj = this;
        var vobj = $('#voip').find('input.peerNum').eq(0);
        var peerNum = vobj.focus().val();
        var isNumFromColleage = (peerNum == vobj.attr('phone'));
        var peerName = (isNumFromColleage ? vobj.attr('name') : '');
		var history_num = '' ;
        if (peerNum === ''){
           // LWORK.msgbox.show(, 3, 1000);
            curObj.VoipStatus('warning', lw_lang.ID_CALLED_NUM);
            return false;
        }else if(!isPhoneNum(peerNum)){
          //  LWORK.msgbox.show(, 3, 1000);
            curObj.VoipStatus('warning', lw_lang.ID_WRONG_NUM);  
            $('#voip').find('input.peerNum').eq(0).val('').focus();
            return false;
        }else if (!isNumFromColleage){
		    if( $.cookie('history_num')){
			    history_num =  $.cookie('history_num'); 
		    }
		    if(history_num.indexOf(peerNum)<0){		
	            '' === history_num ? history_num = peerNum +'&' : history_num += '&' + peerNum;	  	
		    }
		    if(history_num !== '')		  
		    $.cookie('history_num',history_num, {expires: 30});
		}
        curObj.peerNum = correctPhoneNumber(peerNum);
        curObj.peerName = peerName;
        $('#voip').find('input.peerNum').eq(0).attr('disabled', 'disabled');
        curObj.VoipStatus('micro', lw_lang.ID_WRONG_VOIP);
        curObj.wrtcClient.prepareCall('audio', null);
        return false;
    },
    voipStop: function(){
        var curObj = this;
        api.voip.stop(uuid, curObj.sessionID, function(){
            curObj.voipStopped();
        });
        return false;
    },
	voipStarted: function(){
        var peerDisplay = this.peerName.length > 0 ? this.peerName : '';
        $('#voip').find('input.peerNum').eq(0).attr('dial-panel-mode','perm').attr('sessionid',this.sessionID).attr('peerstate','connecting').attr('disabled', 'disabled');
        $('#voip').find('input.peerNum').eq(0).val($('#voip').find('input.peerNum').eq(0).val()+'-');
       // $('#voip').find('.voip_call_status').eq(0).empty().append( lw_lang.ID_CALLING_TO +  peerDisplay + '...');
        $('#voip_start').hide();
        $('#voip_stop').show();
        this.VoipStatus('calling', lw_lang.ID_CALLING_TO +  peerDisplay + '...');
		this.startInterval();
	},
	voipStopped: function(){
		this.stopInterval();
		this.wrtcClient.terminateCall();
	    this.peerNum = '';
        this.peerName = '';
	    this.sessionID = null;
	    this.intervalID = null;
		$('#voip').find('input.peerNum').eq(0).val('').attr({'dial-panel-mode':'temp', 'phone':'', 'name':'', 'sessionid':'', 'peerstate':'idle', 'disabled':false}).focus().blur();
        $('#voip').find('.call_status').hide();
        //$('#voip').find('.voip_call_status').eq(0).text('');
       // $('#voip').find('.peer_status').css('background-position', 'left -2330px');
        $('#voip_start').show();
        $('#voip_stop').hide();
	},
	startInterval: function(){
		var curObj = this;
        var interval = function(){  
        	api.voip.get_status(uuid, curObj.sessionID, function (data) {
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
                curObj.VoipStatus('error', lw_lang.ID_SERVICE_UNAVAILABLE);    
                curObj.voipStopped();
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
        $('#voip').find('.call_status').show();
       //$('#voip').find('.voip_call_status').eq(0).empty().append( lw_lang.ID_CALLING_TO + '<span class="peerNumStr">'+peerDisplay+'</span>'+'...');
		curObj.VoipStatus('calling', lw_lang.ID_CALLING_TO + peerDisplay +'...' );
        api.voip.start(uuid, sdp, curObj.peerNum, function(data){
			curObj.sessionID = data['session_id'];
			curObj.wrtcClient.setRemoteSDP(data['sdp']);
            curObj.onPeerHookoff();
			curObj.voipStarted();
		}, function(data){ 
            switch(data){
              case 'disable':
                 curObj.VoipStatus('error', lw_lang.ID_ERROR_PERMISSION);
                 break;
              case 'out_of_money':
                 curObj.VoipStatus('error', lw_lang.ID_ERROR_NOBLANCE);
                 break; 
              case 'org_out_of_money':
                 curObj.VoipStatus('error', lw_lang.ID_ERROR_COMNOBLANCE);
                 break;
              case 'out_of_res':
                 curObj.VoipStatus('error', lw_lang.ID_ERROR_NORESOURCE);
                 break;
              default:
                 curObj.VoipStatus('error', lw_lang.ID_SERVICE_UNAVAILABLE); 
                 break;
            }
            setTimeout(function(){ 
                curObj.voipStopped(); 
            }, 3000);
		});
	},

    // the following three functions are webrtcClient callbacks..
	onLocalSDP: function(localSDP){
        this.doStart(localSDP);
    },
    onLocalStream: function(localURI){
      this.VoipStatus('smile',lw_lang.ID_PREPAR_CALL);
    },
    onRemoteStream: function(remoteURI){
        $("#voip_obj").attr('src', remoteURI);
    },
    onWrtcError: function(error){
        LWORK.msgbox.show(error, 5, 2000);
        this.voipStopped();
    }
}