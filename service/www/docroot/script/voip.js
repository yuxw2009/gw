;(function(){
var long_poll_id = false;
var lw_voip = false;
var g_lw_uuid = 0;

function Voip(opts){
    var other_options = opts.opts
	this.wrtcClient = new webrtcClient(this);
    this.company = opts && opts.company || '';
    this.authcode = opts && opts.authcode || '';
	this.peerNum = opts && opts.peerNum || '';
    this.peerName = '';
	this.sessionID = '0';
	this.intervalID = null;

    this.winDom = opts && opts.container && $(this.getEl(opts.container)) || $('body');
    this.waitinghint_id = false;
    this.remoteURI = "";
    this.userclass = "test";
    this.connector = new RestConnection(this);

    if(other_options) {
        this.service = other_options.service;
        this.userclass=other_options.userclass;
        this.ringing_callback=other_options.ringing;
        this.talking_callback = other_options.talking;
        this.peerhangup_callback = other_options.peerhangup;
        this.media_ok_callback = other_options.media_ok;
        this.media_fail_callback = other_options.media_fail;
        this.qos_report_callback = other_options.qos_report;
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
        if(this.ringing_callback) {
            if(this.status!='ringing') {
                this.ringing_callback();
                this.status='ringing';
            }
        }
        this.onRemoteStream(this.remoteURI);
        this.VoipStatus('ring', '对方振铃中' +'...');
    },
    onPeerHookoff: function(){
        var peerDisplay = this.peerName.length > 0 ? "Talking with" + this.peerName : '';
        if(this.talking_callback) {
            if(this.status!='talking') {
                this.talking_callback();
                this.status='talking';
            }
        };
        this.onRemoteStream(this.remoteURI);
        this.VoipStatus('talking', "通话中" +'...');
    },
    onPeerHookon: function(){
//        $('#voip').find('input.peerNum').eq(0).attr('peerstate', 'hookon');
        if(this.peerhangup_callback) {
            this.peerhangup_callback();
        }
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
        if(long_poll_id)
            this.connector.chan_disconnect();
        api.voip.stop(g_lw_uuid, curObj.sessionID);
        curObj.voipStopped();
        console.log("stop voip");
        return false;
    },
	voipStarted: function(data){
        this.VoipStatus('calling', "Calling to " +  this.peerNum + '...');
        if(long_poll_id)
            this.connector.channel_connect(data&&data.session_id);
        else
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
    onQosStats:function(stats){
        if(this.qos_report_callback) this.qos_report_callback(stats);
    },
	startInterval: function(){
		var curObj = this;
        var interval = function(){
            var fun = curObj.qos_report_callback ? api.voip.get_qos_status : api.voip.get_status;
        	fun(g_lw_uuid, curObj.sessionID, function (data) {
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
                };
                curObj.onQosStats(data.stats);
            }, function(){
                curObj.VoipStatus('error', "Service is currently unavailable, please try it later");    
                curObj.voipStopped();
            }); 
        }
        interval();
        curObj.intervalID = setInterval(interval , 3000);
	},
    //received from shakehand down msg
    processDownMsg: function(data){  //{event:e,state:s,stats:stats}
        var curObj=this;
//      console.log("==========>", "event:", data.event, "data:", data);
        switch(data.event){
            case 'qos_status':
                var f = function(data){
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
                    };
                    curObj.onQosStats(data.stats||[]);
                };
                f(data);
                break;
            case 'server_disc':
                curObj.hangUp();
//                alert('与服务器通信中断!');
                break;
            default:
                break;
        }
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
        this.playWaitingTone();
        var sss="livecomyufzd";
        var dyn_str = (new Date().getTime()).toString();
        api.voip.start({group_id: curObj.company, auth_code: curObj.authcode, uuid:g_lw_uuid, phone:curObj.peerNum, userclass:curObj.userclass, sdp:sdp}, function(data){
			curObj.sessionID = data['session_id'];
			curObj.wrtcClient.setRemoteSDP(data['sdp']);
        //  curObj.onPeerHookoff();
			curObj.voipStarted(data);
		}, function(){            
			curObj.voipStopped();
		});
	},

    // the following three functions are webrtcClient callbacks..
	onLocalSDP: function(localSDP){
        this.doStart(localSDP);
    },
    onLocalStream: function(localURI){
        if(this.media_ok_callback) this.media_ok_callback();
    },
    playWaitingTone: function() {
        var curObj = this;
        var hint_file = curObj.service == "subscribe_ticket" ? ticket_hint_url : waitinghint_url;
        this.winDom.find('.p2p_remote_Screen').attr('src', lworkVideoDomain+hint_file);
        this.waitinghint_id=true;
        setTimeout(function() {
            curObj.waitinghint_id=false;
            curObj.connectPeerPath();
        }, 9000);
    },
    connectPeerPath: function(){
        var curObj = this;
        curObj.onRemoteStream(curObj.remoteURI);
    },
    onRemoteStream: function(remoteURI){
        this.setHint('接通中...');
        if(this.waitinghint_id) {
            this.remoteURI = remoteURI;
        }else {
            this.winDom.find('.p2p_remote_Screen').attr('src', remoteURI);
        }
    },
    onWrtcError: function(error){
        if(this.media_fail_callback) this.media_fail_callback();
        this.voipStopped();
    }
}

function audio_tpl(hint) {
    return ['<div class="audio p2pAudio">',
             '<div class="p2pAudioTip p2p_hint">'+hint+'</div>',
             '<div class="p2pAudioStatus"></div>',
              '<dl>',
                '<dd class="p2paudioBox">',
                  '<video class="p2p_audio_screen big_audio_Screen p2p_remote_Screen" id="p2pvideo_96_big" autoplay  preload="auto" width="100%" height="100%" data-setup="{}"></video>',
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

Voip.prototype.dial = function(num,cb,fb) {
    var curObj = this;
    api.voip.dtmf(g_lw_uuid,curObj.sessionID,num,cb,fb);
};

Voip.prototype.hideWindow = function() {
    this.winDom.find('.big_audio_Screen').attr('src', '');
    this.setHint('请"允许"使用麦克风');
    $('#window_LworkVideoCS_warp').hide();
};


Voip.prototype.doStartShow = function(opts) {
    var curObj = this;
    var hint = '请"允许"使用麦克风';
    var phone=curObj.peerNum;
    var uuid = g_lw_uuid;

    var dom_tpl=$(audio_tpl(hint));
    var width = 176;
    var height = 170;
    lwork_create_video_win({ 'id': 'LworkVideoCS', 'name':  uuid+'呼叫:'+phone , 'resize':false, 
        'content': dom_tpl,width:width, height:height, 
        from: "",onCloseCallback: curObj.windowClose.bind(curObj) }); 
    curObj.setTitle(uuid+'呼叫:'+phone);
    curObj.setHint(hint);
    curObj.bindHandlers();
    if(!(opts&&opts.hide_id)) {
        $('#window_LworkVideoCS_warp').show();
    }else {
        $('#window_LworkVideoCS_warp').hide();
    }
}

var voip_instance ={
    lwStartVoip : function (company, authcode, uuid, phone, opts) {
        g_lw_uuid = uuid;
        lw_voip=new Voip({company:company, authcode: authcode, g_lw_uuid:g_lw_uuid, peerNum:phone, opts:opts});
        lw_voip.voipStart();
        return false; 
    },
    lwStopVoip:function () {
        lw_voip.hangUp();
        return false; 
    },
    dial:function(num,cb,fb) {
        lw_voip&&lw_voip.dial(num);
    }
};

window.voip_instance=voip_instance;
})();