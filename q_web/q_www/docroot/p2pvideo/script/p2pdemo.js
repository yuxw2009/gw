var LWORK_SHAKEHAND_TIMER = 30*1000;
var SHAKE_TIMES = 6;
var formatDateTimeString = function(d){
      var s;
      s = d.getFullYear() + "-";             //取年份
      s = s + (d.getMonth() < 9 ? '0' : '') + (d.getMonth() + 1) + "-";//取月份
      s += d.getDate() + " ";         //取日期
      s += d.getHours() + ":";       //取小时
      s += d.getMinutes() + ":";    //取分
      s += d.getSeconds();         //取秒   
      return(s); 
}


var video_tpl = function(hint) {
    return ['<div class="ribbonBox" style="width: 405px; height:340px;"> ',
                '<div class="video p2pVideo" style="display:block">',
                    '<dl>',
                        '<dd class="p2pvideoBox">',
                        '<div class="p2pVideoTip p2p_hint">'+hint+'</div>',
                        '<video class="p2p_video_screen big_video_Screen p2p_remote_Screen" id="p2pvideo_96_big" autoplay="" preload="auto" width="100%" height="100%" data-setup="{}" src=""></video>',
                        '<video class="p2p_video_screen small_video_Screen" autoplay="" preload="auto" width="100%" height="100%" data-setup="{}" src=""></video>',
                        '</dd>',
                    '</dl>',
                    '<div class="videoOpt">',
                        '<div class="videOpt_c"> <span class="videoTime">通话时长： <span class="videoCurrentTime"> 00:00:00 </span> </span> ',
                            '<a href="###" class="fullscreen">全 屏</a> <a href="###" class="hangUp">挂 断</a> ',
                        '</div>',
                    '</div>',
                '</div>',
            '</div> '].join('');
}

var audio_tpl = function(hint) {
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



var login_dom_tpl = ['<div id="LworkVideo_login" style="display:none">',
        '<div class="loginBox">',
         '<div class="loginCon">',
              '<div class="logo">    </div>',
              '<div class="login_box">',
                '<ul>',
                  '<li class="item">',
                    '<label>呼叫坐席:</label>',
                    '<input type="text" class="callseat" value="" />',
                  '</li>',
                  '<li style="margin-left:30px;"><a href="###" class="btn loginbtn">登 录</a><a href="###" class="btn cancel">关 闭</a></li>',
                '</ul>',
              '</div>',
          '</div>',
         '</div> ',
        '</div>'
    ].join('');




var p2pclient = false;
var p2pserver = false;
var defaultVideoMediaParas = {"mandatory": {
							  "minWidth": "320",
							  "maxWidth": "320",
							  "minHeight": "240",
							  "maxHeight": "240",
							  "minFrameRate": "10"},
							  "optional": []};
					  

function isUserOnline(aUUID){
    return true;
}
function p2pVideo(opts){
    this.media_type = (opts && opts.media_type) || false;
    this.room = opts&&opts.room || "";
    this.winDom = opts&& opts.container && $(this.getEl(opts.container)) || $('body');//$('#window_'+room+'_warp');
    this.wrtcClient = new webrtcClient(this);
    this.asClient = opts&&opts.asClient;
    this.peerUUID = this.room;
    this.lost_times=0;
    this.connector = new RestConnection(this);
    this.logined = opts&&opts.logined;
    this.incoming = opts&&opts.incoming;
    this.calling = opts&&opts.calling;
    this.peerhangup = opts&&opts.peerhangup;
};
p2pVideo.prototype = {
    bindHandlers: function(){
        var curObj = this;
        var video = document.getElementById('p2pvideo_'+ curObj.room +'_big');
        curObj.winDom.find('.hangUp').unbind('click').bind('click', function(){
            curObj.hangup();
            return false;
        });
        curObj.winDom.find('.fullscreen').click(function(){ 
          video.webkitRequestFullScreen(); // webkit类型的浏览器
        });
        return this;
    },
    hangup: function() {this.end();},
    start: function(peerUUID){    //yxw  it's room actually
        this.asClient = true;
        this.peerUUID = peerUUID;
        this.wrtcClient.prepareCall(this.media_type, defaultVideoMediaParas);
    },
    get_opr:function(Room) {
        this.asClient = true;
        var curObj = this;
        var dt = formatDateTimeString(new Date()); 
        var opt = Room &&''!= Room ? {media_type:curObj.media_type,room: Room } : {media_type:curObj.media_type};
        var data = {"event":"get_opr", params:opt};
        hp.sendData(data, function(data){
            var hint = '请"允许"使用麦克风...';
            var dom_tpl,width,height;
            curObj.room = Room = data.room;
            curObj.start(Room);
            curObj.connector.room_connect(Room+"_clt");
            if(curObj.media_type=='video'){
                dom_tpl=$(video_tpl(hint));
                width = 410;
                height = 345;
            }else{
                dom_tpl=$(audio_tpl(hint));
                width = 176;
                height = 170;
            }
            lwork_create_video_win({ 'id': 'LworkVideoCS', 'name':  '呼叫坐席:'+ Room , 'resize':false, 
                'content': dom_tpl,width:width, height:height,from: "",onCloseCallback: curObj.windowClose.bind(curObj) }); 
            curObj.setTitle('坐席'+ Room + '为您服务');
            curObj.setHint(hint);
            curObj.bindHandlers();
       },function(err){
           LWORK.msgbox.show('坐席忙，请稍后再试',5, 2000);
       });
    },
    end: function(){
        this.endP2P();
        LWORK.msgbox.show('通话已结束', 4, 2000);
        this.p2pVideoStopped();
    },
    onInvite: function(peerUUID, peerSDP){
        this.setHint("正在接通...");
        var curObj = this;
        curObj.asClient = false;
        curObj.peerUUID = peerUUID;
        curObj.wrtcClient.prepareCall(curObj.media_type, defaultVideoMediaParas, peerSDP);
        curObj.incoming();
        ManageSoundControl('play',2);
    },
    doStart: function(localSDP){
        this.startP2P(localSDP);
        this.p2pVideoStarted();
        this.setHint('正在联系坐席...');
    },
    doJoin: function(localSDP){
        this.joinP2P(localSDP);
        this.p2pVideoStarted();
    },
    p2pVideoStopped: function(){
        this.peerUUID = null;
        this.receivedPid = '';
        this.wrtcClient.terminateCall();
        if(this.asClient) {
            this.winDom.find('.big_video_Screen').attr('src', '');
            this.winDom.find('.small_video_Screen').attr('src', '');
            this.setHint('请"允许"使用麦克风...');
            $('#window_LworkVideoCS_warp').hide();
            this.connector.room_disconnect();
            p2pclient=false;
        }
        else{
            this.setHint('等待客户接入...');
            this.winDom.find('.big_video_Screen').attr('src', '');
        }
    },
    p2pVideoStarted: function(){ },
    //// callbacks for webrtcClient..
    onLocalSDP: function(localSDP){
        var curObj = this;
        this.localSDP = localSDP;  //yxw
        if (curObj.asClient){
            curObj.doStart(localSDP);
        }else{
            curObj.doJoin(localSDP);
        }    
    },
    onLocalStream: function(localURI){
        var curObj = this;
        if(curObj.asClient) {
            curObj.setHint("正在联系坐席...");
        }else {
            curObj.setHint("等待客户接入...");
        }
        curObj.winDom.find('.small_video_Screen').attr('src', localURI);
    },
    onRemoteStream: function(remoteURI){
        if(this.media_type=='audio') {
            this.setHint('通话中...');   
        }else{
            this.openVideo();
        }
        this.calling();
        this.winDom.find('.p2p_remote_Screen').attr('src', remoteURI);
    },
    onWrtcError: function(error){
		//console.log(error)
        LWORK.msgbox.show(error, 5, 2000);
        this.hangup();
    },
    startP2P: function(localSDP){
        var curObj = this;
        var dt = formatDateTimeString(new Date()); 
        var data = {event:"invite", params:{room:this.room, sdp:localSDP}};  //********
        hp.sendData(data, function(data){}, function(err){
            curObj.onWrtcError(err.reason, 5, 2000);
        });
    },
    joinP2P: function(localSDP){
        var curObj = this;
        var dt = formatDateTimeString(new Date()); 
        var data = {event:'join', params:{sdp:localSDP, room:curObj.room}};  //**********
        hp.sendData(data/*, function(data){
            curObj.room=data.room;
            curObj.peerUUID = data.room;
            curObj.onPeerAccept(data.oprsdp);
        }*/
        );
    },
    onIceCandidate: function(candidate){
        var data = {event:'peer_candidate', params:{
            room:this.room,
            asClient:this.asClient,
            label: candidate.sdpMLineIndex,
            id: candidate.sdpMid,
            candidate: candidate.candidate
        }};  //**********
//        console.log("<========peer_candidate:", candidate.candidate);
        hp.sendData(data);
    },
    onPeerCandidate: function(data){
        this.wrtcClient.onPeerCandidate(data);
    },
    endP2P: function(){
        var dt = formatDateTimeString(new Date()); 
        var evt;
        if(this.asClient) {
            evt='clt_leave';
        }
        else {
            evt= 'opr_leave';
        }
        var data = {event:evt, params:{room:this.room, timestamp:dt, media_type:'video_p2p', 
                    action:'stop'}};
        hp.sendData(data);
    },
    shakeHand: function(){
        if(this.asClient) return;
        var curObj = this;
        var evt= 'shakehand_opr';
        var data = {event:evt, params:{ room:this.room, oprid:this.asClient,  media_type:curObj.media_type}};
        hp.sendData(data,function(data){
            var event=data.event;
            curObj.lost_times = 0;
        }, function(err){

        });
        curObj.lost_times += 1;
        if(curObj.lost_times>SHAKE_TIMES) {

            lw_log("shake timeout exceed "+SHAKE_TIMES+" times!");
            curObj.setTitle('坐席'+curObj.room+'和服务器连接中断，请重新登录！');
        }else{
            curObj.shakeTimer = setTimeout(function() {curObj.shakeHand();}, LWORK_SHAKEHAND_TIMER);
        }
    },
    //received from shakehand down msg
    processDownMsg: function(data){
        var curObj=this;
//        console.log("==========>", "event:", data.event, "data:", data);
        switch(data.event){
            case 'invite':
                curObj.onInvite(data.room, data.peer_sdp);  //*********
            break;
            case 'join':
                curObj.onJoin(data.peer_sdp);
                break;
            case 'leave':
                curObj.onPeerStop();
                break;
            case "peer_candidate":
//                console.log("========>peer_candidate:", data.candidate);
                curObj.onPeerCandidate(data);
                break;
            default:
                break;
        }
    },
    onJoin: function(peerSDP){
        this.setHint("正在接通...");
        this.wrtcClient.setRemoteSDP(peerSDP);
    },
    onPeerStop: function(){
        LWORK.msgbox.show('对端已挂机', 4, 1000);
        this.peerhangup();
        this.p2pVideoStopped();
    }
}

p2pVideo.prototype.getEl = function (idOrEl) {
    if (typeof idOrEl == 'string') {
        return document.getElementById(idOrEl);
    } else {
        return idOrEl;
    }
};

p2pVideo.prototype.logout = function(onCallback) {
    var curObj = this;
    var data = {event:"logout", params:{room:curObj.room}}; 
    hp.sendData(data, function(data){
        $('#window_LworkVideoCS_warp').hide();
        curObj.connector.room_disconnect();
        clearTimeout(curObj.shakeTimer);
        p2pserver=false;
    }, function(err){
        curObj.onWrtcError(err.reason, 5, 2000);
    });

};

p2pVideo.prototype.windowClose = function() {
    if(this.asClient) {
       this.hangup();
    }
    else{
      this.hangup();
      this.logout();
    }
};

p2pVideo.prototype.setTitle = function(title) {
    this.winDom.find('.cm_title').text(title);
};

p2pVideo.prototype.setHint = function(hint) {
    this.winDom.find('.p2p_hint').show().text(hint);
};

p2pVideo.prototype.openVideo = function(hint) {
    if(this.media_type == 'video')  this.winDom.find('.p2p_hint').hide().text();
};

function lwork_create_video_win(opts){
    if($('#window_LworkVideoCS_warp').length>0){
       $('#window_LworkVideoCS_warp').html('').remove();
    }
    Core.create(opts);
}

function lworkpreCall(type){
  this.type = type;	
}

lworkpreCall.prototype = {	
     obtainLocalMediaCallback: function(owner) {
       var para= this.type == "video" ? defaultVideoMediaParas : false;
       obtainLocalMedia(para, function(stream) {
		   var MediaURL = webkitURL.createObjectURL(stream);
		   owner.onLocalStream(MediaURL);
		}, function(){
			LWORK.msgbox.show('获取媒体流失败', 5, 5000);
		});
	 },	
	 PrepareServerCall: function(Room, opts){
        var curObj = this;
		var data = {event:"login", params:{room:Room, media_type:curObj.type}};
			hp.sendData(data, function(data){
				var hint= p2pserver ? "等待客户接入..." : '请"允许"使用麦克风...';
				if(!p2pserver) {
					p2pserver= new p2pVideo({
                        room:Room, 
                        asClient:false, 
                        media_type: curObj.type,
                        'logined':opts&&opts.logined ? opts.logined: function(){ } ,
                        'incoming':opts&&opts.incoming ? opts.incoming: function(){ } ,
                        'calling':  opts&&opts.calling ? opts.calling: function(){ } ,
                        'peerhangup': opts&&opts.peerhangup ? opts.peerhangup: function(){ }
                    });
				}else{
					p2pserver.room = Room;
					p2pserver.lost_times=0;
					p2pserver.media_type = curObj.type;
				}
				var dom_tpl,width,height;
				if(p2pserver.media_type=='video'){
					dom_tpl=$(video_tpl(hint));
					width = 410;
					height = 345;
				}else{
					dom_tpl=$(audio_tpl(hint));
					width = 176;
					height = 170;
				}

				lwork_create_video_win({ 'id': 'LworkVideoCS', 'name':  '坐席号:'+Room ,
								'resize':false, 'content': dom_tpl,width:width, height:height, from:Room,
								onCloseCallback: p2pserver.windowClose.bind(p2pserver)}); 
                p2pserver.setTitle('坐席号:'+Room);
				p2pserver.setHint(hint);
				p2pserver.bindHandlers();
				p2pserver.connector.room_connect(Room+"_opr");
				curObj.obtainLocalMediaCallback(p2pserver);
                p2pserver.logined();
				p2pserver.shakeHand();
                if($('#LworkVideo_login').length >0)$('#LworkVideo_login').fadeOut();
			}, function(err){
                if($('#LworkVideo_login').length >0){
                  pageTips($('#LworkVideo_login').find('.callseat').parent(),'该坐席号被占用！');
                } else{
                  LWORK.msgbox.show("该坐席号被占用！", 5, 1500);
                }
            });
	},
    PrepareclientCall: function(Room, opts){
        var curObj = this;
        if(!p2pclient) {
           p2pclient=new p2pVideo({ 
              room:Room, 
              asClient:true, 
              media_type:curObj.type, 
              incoming: opts&&opts.incoming ? opts.incoming: function(){ } ,
              calling: opts&&opts.calling ? opts.calling: function(){ } ,
              peerhangup: opts&&opts.peerhangup ? opts.peerhangup: function(){ } 
          });
        }else{
           p2pclient.media_type = curObj.type;
        }
        p2pclient.get_opr(Room);

    }
}

function LworkServerCall(type, Room, opts){
    var winBox=$('#window_LworkVideoCS_warp');
    if(location.protocol !='http:' && location.protocol !='https:'){
        LWORK.msgbox.show("不能本地运行请访问服务器,谢谢!", 5, 2000);
        return false;
    }
    if(winBox.length==0 ||winBox.css('display')=='none'){
        var lwork_call = new lworkpreCall(type);
        lwork_call.PrepareServerCall(Room, opts);
        return false;
    }
}

function LworkCallQuit(){
    if(p2pserver) {
        p2pserver.windowClose();
    }
    if(p2pclient) {
        p2pclient.windowClose();
    }
}

function LworkClintCall(type, Room, opts) {
    var dom=$('#window_LworkVideoCS_warp');
    if(location.protocol !='http:' && location.protocol !='https:')
    {
        LWORK.msgbox.show("请访问web服务器,谢谢!", 5, 2000);
        return;
    }
    if(dom.length==0 ||dom.css('display')=='none'){
        var lwork_call = new lworkpreCall(type);
        lwork_call.PrepareclientCall(Room, opts);
    }
	return false; 
}


$(document).ready(function(){
  function appendLoginDom(type){
    $(login_dom_tpl).appendTo('body');
    var loginBox = $('#LworkVideo_login');
    loginBox.find('.loginCon').addClass('stack');
    loginBox.attr('class','').addClass(type + '_login_box').show();
    loginBox.find('.loginbtn').unbind('click').click(function(){
        var room =  $('#LworkVideo_login').find('.callseat').val();
        if('' == room) {
            pageTips($('#LworkVideo_login').find('.callseat').parent(),'坐席号不能为空');
            return false;
        };
        LworkServerCall(type, room);
        return false;        
    });
    loginBox.find('.cancel').unbind('click').click(function(){
        $('#LworkVideo_login').fadeOut();
        return false;        
    });
    loginBox.find('.callseat').keyup(function(){  
        removePageTips($('#LworkVideo_login').find('.callseat').parent()); 
    });
  }
  $('#LworkVideoCs').click(function () {
     LworkClintCall('video', '');
     return false;          
  });
  
  $('#LworkAudioCs').click(function () {
     LworkClintCall('audio', '');
     return false;          
  });
  
  $('#LworkVideoZx').click(function () {
     appendLoginDom('video');
     return false;
  });
  
  $('#LworkAudioZx').click(function () {
     appendLoginDom('audio');
     return false;
  });
  
}); 


var lw_debug_id=false;
function lw_log(){
    if(lw_debug_id) console.log(arguments);
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