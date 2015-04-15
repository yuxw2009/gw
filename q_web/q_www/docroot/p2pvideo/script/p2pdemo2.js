var LWORK_SHAKEHAND_TIMER = 30*1000;
var SHAKE_TIMES = 6;
var formatDateTimeString = function(d){
    var s;
    s = d.getFullYear() + "-";       //取年份
    s = s + (d.getMonth() < 9 ? '0' : '') + (d.getMonth() + 1) + "-";//取月份
    s += d.getDate() + " ";         //取日期
    s += d.getHours() + ":";       //取小时
    s += d.getMinutes() + ":";    //取分
    s += d.getSeconds();         //取秒   
    return(s);
}
var login_dom_tpl = ['<div id="LworkVideo_login">',
                  '<div class="login_box">',
                    '<ul>',
                      '<li class="item">',
                        '<label>输入座席号:</label>',
                        '<input type="text" class="callseat" value=""/>',
                      '</li>',
                    '</ul>',
                  '</div>',
                '</div>'].join('');

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
        curObj.winDom.find('.vd_hangup').unbind('click').bind('click', function(){
          curObj.hangup();
          return false;
        });
        return this;
    },
    hangup: function() {this.end();},	
    start: function(peerUUID){
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
           var hint = '请求麦克风<br/>请点击浏览器上方"允许"按钮';
           var dom_tpl,width,height;
           curObj.room = Room = data.room;
           curObj.start(Room);
           curObj.connector.room_connect(Room+"_clt");						
           //  if(curObj.media_type=='video'){
           //    dom_tpl=$(video_tpl(hint));
           //    width = 410;
           //    height = 345;
           //  }else{
           //    dom_tpl=$(audio_tpl(hint));
           //    width = 176;
           //    height = 170;
           // }
           // lwork_create_video_win({ 'id': 'LworkVideoCS', 'name':  '呼叫坐席:'+ Room , 'resize':false,
		       // 'content': dom_tpl, width:width, height:height, from: "", onCloseCallback: curObj.windowClose.bind(curObj)});
           curObj.setHint(hint);
           curObj.bindHandlers();
       },function(err){
           winTips('提示信息：', '坐席忙，请稍后再试!'); 
       });
    },
    end: function(){
        this.endP2P();
        this.p2pVideoStopped();
        winTips('提示信息：', '通话已结束!');
    },
    onInvite: function(peerUUID, peerSDP){
        this.setHint("等待<br/>正在接通...");
        var curObj = this;
        curObj.asClient = false;
        curObj.peerUUID = peerUUID;
        curObj.wrtcClient.prepareCall(curObj.media_type, defaultVideoMediaParas, peerSDP);
        curObj.incoming();
        //ManageSoundControl('play',2);
    },
    doStart: function(localSDP){
        this.startP2P(localSDP);
        this.p2pVideoStarted();
        this.setHint('等待<br/>正在联系座席...');
    },
    doJoin: function(localSDP){
        this.joinP2P(localSDP);
        this.p2pVideoStarted();
    },
    p2pVideoStopped: function(){
        this.peerUUID = null;
        this.receivedPid = '';
        this.wrtcClient.terminateCall();
        this.setHint('空闲<br/>等待接入');
        if(this.asClient) {
            this.winDom.find('.bgvideo').attr('src', '');
            this.winDom.find('.smvideo').attr('src', '');
            this.winDom.find('.bgvideoTip').show();
            this.winDom.find('.smvideoTip').show();  
            this.connector.room_disconnect();
            p2pclient = false;
        }else{
            this.winDom.find('.bgvideo').attr('src', '');
        }
    },
    p2pVideoStarted: function(){ 

    },
    // callbacks for webrtcClient..
    onLocalSDP: function(localSDP){
        var curObj = this;
        this.localSDP = localSDP;
        if (curObj.asClient){
          curObj.doStart(localSDP);
        }else{
          console.log(localSDP)
          curObj.doJoin(localSDP);
        }    
    },
    onLocalStream: function(localURI){
        var curObj = this;
        if(curObj.asClient) {
          curObj.setHint("繁忙<br/>正在联系坐席...");
        }else{
          curObj.setHint("空闲<br/>等待客户接入...");
        }
        curObj.winDom.find('.smvideo').attr('src', localURI);
        curObj.winDom.find('.smvideoTip').hide();
        $('.vd_start').hide().next().css('display','inline-block');
    },
    onRemoteStream: function(remoteURI){
        if(this.media_type=='audio') {

          //this.setHint('通话中...');   
        }else{
          this.openVideo();
        }
        this.calling();
        console.log(remoteURI)
        this.winDom.find('.bgvideo').attr('src', remoteURI);
        this.setHint("空闲<br/>等待邀请");
        this.winDom.find('.bgvideoTip').hide();
    },
    onWrtcError: function(error){
      //LWORK.msgbox.show(error, 5, 2000);
        this.hangup();
    },
    startP2P: function(localSDP){
        var curObj = this;
        var dt = formatDateTimeString(new Date()); 
        var data = {event:"invite", params:{room:this.room, sdp:localSDP}};
        hp.sendData(data, function(data){

        }, function(err){
          curObj.onWrtcError(err.reason, 5, 2000);		  
        });
    },
    joinP2P: function(localSDP){
        var curObj = this;
        var dt = formatDateTimeString(new Date()); 
        var data = {event:'join', params:{sdp:localSDP, room:curObj.room}};
        hp.sendData(data);
    },
    onIceCandidate: function(candidate){
        var data = {event:'peer_candidate', params:{
            room:this.room,
            asClient:this.asClient,
            label: candidate.sdpMLineIndex,
            id: candidate.sdpMid,
            candidate: candidate.candidate
        }};         
        hp.sendData(data);
    },
    onPeerCandidate: function(data){
        this.wrtcClient.onPeerCandidate(data);
    },
    endP2P: function(){
        var dt = formatDateTimeString(new Date()),
        evt = this.asClient ? 'clt_leave': 'opr_leave',
        data = {event:evt, params:{ room:this.room, timestamp:dt, media_type:'video_p2p', action:'stop'}};
        hp.sendData(data);
    },
    shakeHand: function(){
        if(this.asClient) return;
        var curObj = this;
        var evt= 'shakehand_opr';
        var data = {event:evt, params:{ room:this.room, oprid:this.asClient,  media_type:curObj.media_type}};
        hp.sendData(data,function(data){
          var event = data.event;
          curObj.lost_times = 0;
        }, function(err){

        });
        curObj.lost_times += 1;
        if(curObj.lost_times>SHAKE_TIMES) {
          lw_log("shake timeout exceed "+SHAKE_TIMES+" times!");
          curObj.setTitle('空闲<br>连接中断，请重新登录！');
        }else{
          curObj.shakeTimer = setTimeout(function() {
            curObj.shakeHand();
          }, LWORK_SHAKEHAND_TIMER);
        }
    },
    //received from shakehand down msg
    processDownMsg: function(data){
        var curObj=this;
        switch(data.event){
            case 'invite':
                curObj.onInvite(data.room, data.peer_sdp);
            break;
            case 'join':
                curObj.onJoin(data.peer_sdp);
                break;
            case 'leave':
                curObj.onPeerStop();
                break;
            case "peer_candidate":
                curObj.onPeerCandidate(data);
                break;
            default:
                break;
        }
    },
    onJoin: function(peerSDP){
      this.setHint("等待<br/>正在接通...");
      this.wrtcClient.setRemoteSDP(peerSDP);
    },
    onPeerStop: function(){
      winTips('提示信息：', '对端已挂机');
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
    }else{
      this.hangup();
      this.logout();
    }
};
p2pVideo.prototype.setTitle = function(title) {
  this.winDom.find('.peerNumber').text(title).parent().show();
};
p2pVideo.prototype.setHint = function(hint) {
   this.winDom.find('.bgvideoTip').show().html(hint);
};
p2pVideo.prototype.openVideo = function(hint) {
   if(this.media_type == 'video')  this.winDom.find('.bgvideoTip').hide().html(hint);
};
function lwork_create_video_win(opts){
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
       	   winTips('错误提示：', '获取媒体流失败！');
  	   });
	   },	
	 PrepareServerCall: function(Room, opts){
		var curObj = this;
		var flag;
			var data = {event:"login", params:{room:Room, media_type:curObj.type}};
			hp.sendData(data, function(data){
				var hint= p2pserver ? "空闲<br/>等待客户接入！" : '等待<br/>请"允许"使用麦克风！';
        var dom_tpl,width,height;
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
					p2pserver.setTitle(Room);
					p2pserver.setHint(hint);
					p2pserver.bindHandlers();
					p2pserver.connector.room_connect(Room+"_opr");
					curObj.obtainLocalMediaCallback(p2pserver);
			    p2pserver.logined();
					p2pserver.shakeHand();
			 		$('.avgrund-popin').find('.avgrund-close').click();
			  	return false;
			  }, function(err){
			    $('#LworkVideo_login').length >0 ? pageTips($('#LworkVideo_login').find('.callseat').parent(), '该坐席号被占用！') : winTips('错误提示：', '该坐席号被占用！');      
			    return false;
		  });
	  },
     PrepareclientCall: function(Room, opts){
        var curObj = this;
        if(!p2pclient) {
           p2pclient=new p2pVideo({ 
             room:Room, 
             asClient:true, 
             media_type:curObj.type, 
             incoming: opts&&opts.incoming ? opts.incoming: function(){ },
             calling: opts&&opts.calling ? opts.calling: function(){ },
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
       winTips('错误提示：', '不能本地运行请访问服务器,谢谢!');
       return false;
    }
    if(winBox.length==0 ||winBox.css('display')=='none'){
       var lwork_call = new lworkpreCall(type);
       return lwork_call.PrepareServerCall(Room, opts);
    }
}

function winTips(title, text){
    $.gritter.add({
         title: title,
          text: text,
        sticky: true
    });
}

function LworkCallQuit(){
    if(p2pserver)
     p2pserver.windowClose();
    if(p2pclient) 
     p2pclient.windowClose();
}

function LworkClintCall(type, Room, opts) {
    var dom=$('#window_LworkVideoCS_warp');
    if(location.protocol !='http:' && location.protocol !='https:'){
       winTips('错误提示：', '请访问web服务器,谢谢!');
       return false;
    }
    if(dom.length==0 ||dom.css('display')=='none'){
        var lwork_call = new lworkpreCall(type);
        lwork_call.PrepareclientCall(Room, opts);
    }
	  return false; 
}

function appendLoginDom(type){
  var loginBox = $("#LworkVideo_login");
  var room =  loginBox.find('.callseat').val();
  loginBox.find('.callseat').keyup(function(){  
      removePageTips(loginBox.find('.callseat').parent()); 
  });  
  if('' == room) {
     pageTips(loginBox.find('.callseat').parent(),'坐席号不能为空');
     return false;
  }; 
     return LworkServerCall(type, room);
}

function artdialog(target, type){
  var title = (type == 'video'? '视频': '语音');
  target.lwDialog({
      title:'登录'+ title +'座席',
      template: login_dom_tpl,
      onPrepare:function(){
        if(target.attr('disabled') == "true"){ 
           target.attr('disabled', "false");  
           return false;
        }      
        return true;
      },
      onOk:function(){
        return appendLoginDom(type);
      }
  });
}

var lw_debug_id=false;
function lw_log(){
  if(lw_debug_id) console.log(arguments);
}

function ManageSoundControl(action, num){	
  var sc = document.getElementById("soundControl");  
  if(action == "play") {
      sc.playcount = (num ? num.toString() : "1");
      sc.play();
  }else if(action == "stop") {
      sc.playcount = "1";
      sc.pause();
  }
}

$(document).ready(function(){
  $('#LworkVideoCs').click(function () {
     LworkClintCall('video', '');
     return false;          
  });
  $('#LworkAudioCs').click(function () {
     LworkClintCall('audio', '');
     return false;          
  });  
  artdialog($('#LworkVideoZx'), 'video');
  artdialog($('#LworkAudioZx'), 'audio');
});