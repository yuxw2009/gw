function Voip(opts){
	this.wrtcClient = new webrtcClient(this);
	this.peerNum = opts&&opts.peerNum || '';
    this.peerName = '';
	this.sessionID = '0';
	this.intervalID = null;
    this.winDom = opts&& opts.container && $(this.getEl(opts.container)) || $('body');//$('#window_'+room+'_warp');
    var other_options = opts.opts;
    if(other_options) {
        this.userclass=other_options.userclass;
        this.ringing_callback=other_options.ringing;
        this.talking_callback = other_options.talking;
        this.peerhangup_callback = other_options.peerhangup;
    }
}
Voip.prototype = {
	bindHandlers: function(){
		var curObj = this;
        curObj.winDom.find('.hangUp').unbind('click').bind('click', function(){
            curObj.voipStop();
            return false;
        });
	},
    VoipStatus:function(status, txt){
        this.setHint(txt);
    },
	prepareToCall: function(){
		this.voipStopped();
	},
    onPeerRing: function(){
//        var peerDisplay = this.peerName.length > 0 ? this.peerName : '';
//        $('#voip').find('input.peerNum').eq(0).attr('peerstate', 'ring').attr('disabled', 'disabled');
        //$('#voip').find('.voip_call_status').eq(0).empty().append('<span class="peerNumStr">'+peerDisplay+'</span>'+ lw_lang.ID_PEER_RINGING +'...');
        // $('#voip').find('.voip_call_status').eq(0).empty().append()
        //$('#voip').find('.peer_status').css('background-position', 'left -2370px');
        if(this.ringing_callback) {
            if(this.status!='ringing') {
                this.ringing_callback();
                this.status='ringing';
            }
        }
        this.VoipStatus('ring', lw_lang.ID_PEER_RINGING +'...');
    },
    onPeerHookoff: function(){
        var peerDisplay = this.peerName.length > 0 ? lw_lang.ID_TALKING_H + this.peerName : '';
//        $('#voip').find('input.peerNum').eq(0).attr('peerstate', 'hookoff').attr('disabled', false);
        //$('#voip').find('.voip_call_status').eq(0).empty().append(peerDisplay + );
        //$('#voip').find('.voip_call_status').eq(0).empty().append(lw_lang.ID_TALKING_H +'<span class="peerNumStr">'+peerDisplay+'</span>'+ lw_lang.ID_TALKING_F +'...');
        //$('#voip').find('.peer_status').css('background-position', 'left -2370px');
        if(this.talking_callback) {
            if(this.status!='talking') {
                this.talking_callback();
                this.status='talking';
            }
        }
        this.VoipStatus('talking', lw_lang.ID_TALKING_F +'...');
    },
    onPeerHookon: function(){
//        $('#voip').find('input.peerNum').eq(0).attr('peerstate', 'hookon');
        if(this.peerhangup_callback) {
            this.peerhangup_callback();
        }
        LWORK.msgbox.show(lw_lang.ID_CALL_END, 4, 2000);
        this.voipStopped();
    },
    voipStart: function(){
    	var curObj = this;
        curObj.voipShow();
        curObj.wrtcClient.prepareCall('audio', null);
        console.log("start voip");
        return false;
    },
    voipStop: function(){
        var curObj = this;
        api.voip.stop(g_lw_uuid, curObj.sessionID, function(){
            curObj.voipStopped();
        }, curObj.voipStopped.bind(curObj));
        console.log("stop voip");
        return false;
    },
	voipStarted: function(){
        this.VoipStatus('calling', lw_lang.ID_CALLING_TO +  this.peerNum + '...');
		this.startInterval();
	},
    voipShow: function(){
        if(this.ringing_callback) {
            this.doStartShow({hide_id:true});
        }else{
            this.doStartShow();
        }
    },
	voipStopped: function(){
		this.stopInterval();
		this.wrtcClient.terminateCall();
	    this.peerNum = '';
        this.peerName = '';
	    this.sessionID = null;
	    this.intervalID = null;
        this.hideWindow();
	},
	startInterval: function(){
		var curObj = this;
        var interval = function(){  
        	api.voip.get_status(g_lw_uuid, curObj.sessionID, function (data) {
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
              //  LWORK.msgbox.show( , 5, 2000);
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
       //  $('#voip').find('.call_status').show();
       //$('#voip').find('.voip_call_status').eq(0).empty().append( lw_lang.ID_CALLING_TO + '<span class="peerNumStr">'+peerDisplay+'</span>'+'...');
		curObj.VoipStatus('calling', lw_lang.ID_CALLING_TO + peerDisplay +'...' );
        api.voip.start(g_lw_uuid, sdp, curObj.peerNum, function(data){
			curObj.sessionID = data['session_id'];
			curObj.wrtcClient.setRemoteSDP(data['sdp']);
//            curObj.onPeerHookoff();
			curObj.voipStarted();
		}, function(){            
			LWORK.msgbox.show(lw_lang.ID_SERVICE_UNAVAILABLE, 5, 2000);
			curObj.voipStopped();
		});
	},

    // the following three functions are webrtcClient callbacks..
	onLocalSDP: function(localSDP){
        this.doStart(localSDP);
    },
    onLocalStream: function(localURI){},
    onRemoteStream: function(remoteURI){
        this.setHint('接通中...');
        this.winDom.find('.p2p_remote_Screen').attr('src', remoteURI);

    },
    onWrtcError: function(error){
        LWORK.msgbox.show(error, 5, 2000);
        this.voipStopped();
    }
}

function audio_tpl(hint) {
    return ['<div class="audio p2pAudio">',
             '<div class="p2pAudioTip p2p_hint">'+hint+'</div>',
             '<div class="p2pAudioStatus"><img src="images/micromark.gif"/></div>',
              '<dl>',
                '<dd class="p2paudioBox">',
                  '<video class="p2p_audio_screen big_audio_Screen p2p_remote_Screen"  id="p2pvideo_96_big" autoplay  preload="auto" width="100%" height="100%" data-setup="{}"></video>',
                '</dd>',
              '</dl>',
             '<div class="audioOpt"><a href="###" class="ahangUp hangUp">挂断</a> </div>',
            '</div>'].join('');
}

Voip.prototype.windowClose = function() {
    this.hangUp();

};
Voip.prototype.setTitle = function(title) {
    this.winDom.find('.cm_title').text(title);
};

Voip.prototype.setHint = function(hint) {
    this.winDom.find('.p2p_hint').show().text(hint);
};


Voip.prototype.hangUp = function() {
    this.voipStop();
};

Voip.prototype.hideWindow = function() {
    this.winDom.find('.big_video_Screen').attr('src', '');
    this.winDom.find('.small_video_Screen').attr('src', '');
    this.setHint('请"允许"使用麦克风');
    $('#window_LworkVideoCS_warp').hide();
};


Voip.prototype.doStartShow = function(opts) {
    var curObj = this;
    var hint = '请"允许"使用麦克风';
    var phone=curObj.peerNum;
    var uuid = g_lw_uuid;
    dom_tpl=$(audio_tpl(hint));
    width = 176;
    height = 170;
    lwork_create_video_win({ 'id': 'LworkVideoCS', 'name':  uuid+'呼叫:'+phone , 'resize':false, 
        'content': dom_tpl,width:width, height:height, 
        from: "",onCloseCallback: curObj.windowClose.bind(curObj) }); 
    curObj.setTitle(uuid+'呼叫:'+phone);
    curObj.setHint(hint);
    curObj.bindHandlers();
    if(!(opts&&opts.hide_id)) {
//        $('#window_LworkVideoCS_warp').show();
    }
}

var lw_voip = false;
var g_lw_uuid = 0;
function lwStartVoip(uuid, phone, opts) {
    g_lw_uuid = uuid;
    lw_voip=new Voip({g_lw_uuid:g_lw_uuid, peerNum:phone, opts:opts});
    lw_voip.voipStart();
    return false; 
}

function lwStopVoip() {
    lw_voip.hangUp();
    return false; 
}

function correctPhoneNumber(phone) {
    phone = phone.replace(/-/g, "");
    phone = phone.replace(/ /g, "");
    phone = phone.replace(/\(/g, "");
    phone = phone.replace(/\)/g, "");
    phone = phone.replace("+", "00");
    return phone;
}