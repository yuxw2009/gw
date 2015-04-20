
var UUID='0';
var FZD_SHAKEHAND_TIMER = 30*1000;
var SHAKE_TIMES = 6;
var p2pclient = false;
var scrclient = false;
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
var defaultVideoMediaParas = {"mandatory": {
                            maxFrameRate: "5",
                              "minWidth": "1280",
                              "maxWidth": "1280",
                              "minHeight": "720",
                              "maxHeight": "720",
							  "minFrameRate": "5"},
							  "optional": []};
					  
var defaultScreenMediaParas = {"mandatory": {
                            maxFrameRate: "2",
                              "chromeMediaSource": "screen",
                              "minWidth": "1600",
                              "maxWidth": "1600",
                              "minHeight": "900",
                              "maxHeight": "900",
                              "minFrameRate": "1"},
                              "optional": []};

function p2pVideo(opts){
    this.uuid = opts.uuid||UUID;
    this.media_type = (opts && opts.media_type) || false;
    this.room = opts&&opts.room || "";
    this.is_creator = opts&&opts.is_creator || false;
    this.ptId = opts&&opts.ptId;
    this.chanId = opts&&opts.chanId;
    this.asClient = opts&&opts.asClient;
    this.lost_times=0;
    this.winDom = opts && opts.winDom||$('#'+dom_id);
    this.connector = new RestConnection(this, opts.p2p_audio_url);
    this.incoming = opts&&opts.cbs&&opts.cbs.incoming || function(data){console.log("incoming:",data);};
    this.media_ok_cb = opts&&opts.cbs&&opts.cbs.media_ok || function(data){console.log("media_ok_cb:",data);};
    this.media_fail_cb = opts&&opts.cbs&&opts.cbs.media_fail || function(data){console.log("media_fail:",data);};
    this.peerleave_cb = opts&&opts.cbs&&opts.cbs.peerleave || function(peerUUID){console.log("peerleave_cb:",peerUUID);};
    this.release_cb = opts&&opts.cbs&&opts.cbs.release || function(){};
    this.waiting = opts&&opts.cbs&&opts.cbs.waiting || function(){};
    this.request_talking = opts&&opts.cbs&&opts.cbs.request_talking || function(){};
    this.server_disc_cb = opts&&opts.cbs&&opts.cbs.server_disc || function(reason){console.log('server_disc! reason: '+reason);};
    this.peerConns = {};
    this.network=(opts && opts.network) || 'telecom';
    this.ring_tone=lwork_room_host+"/test/tone/opr_ring.mp3";
    this.ringback_tone=lwork_room_host+"/test/tone/ringback.mp3";
    this.first_wait_tone=lwork_room_host+"/test/tone/first_waiting.mp3";
    this.along_wait_tone=lwork_room_host+"/test/tone/waiting.mp3";
    this.isTalking = false;
};

p2pVideo.prototype = {
    enter_room:function(Room, sucesscb ,failedcb) {
        this.asClient = true;
        var curObj = this;
        var opt ={media_type:curObj.media_type,room: Room,network:this.network,is_creator:this.is_creator, uuid:this.uuid};
        var data = {"event":"enter_room", params:opt};       
        lhp.sendData(data, function(data){
            curObj.room = Room = data.room;
            curObj.ptId = data.ptId;
            curObj.chanId = data.chanId;
            curObj.connector.channel_connect(data.chanId);
            if(data.waiting) {
                curObj.isWaiting = true;
                curObj.waiting();
                curObj.play_tone(curObj.first_wait_tone);
                curObj.waiting_tone_tid = setTimeout(function(){curObj.play_tone(curObj.along_wait_tone);}, 8000)
            }
            if(sucesscb) sucesscb(data);
       },function(err){
            curObj.p2pVideoStopped();
           if(failedcb) failedcb(err)

       });
    },
    hangup: function(){
        //  for(pcId in this.peerConns) {
        //    this.leaveRoom(pcId);
        //    this.peerConns[pcId].p2pVideoStopped();
        //  }
        this.leaveRoom();
        this.p2pVideoStopped();
    },
    p2pVideoStopped: function(){
        for(pcId in this.peerConns) {
            this.peerConns[pcId].p2pVideoStopped();
            delete this.peerConns[pcId];
        }
        this.connector.chan_disconnect();
        releaseLocalMedia();
        this.release_cb();
        this.isTalking = false;
        this.play_tone("");
        clearTimeout(this.waiting_tone_tid);
    },
    p2pVideoStarted: function(){ },
    //// callbacks for webrtcClient..
    onLocalStream: function(localURI){
        this.media_ok_cb({uri:localURI, is_creator:this.is_creator,media_type:this.media_type});
    },
    onWrtcError: function(error){
        this.hangup();
        if(this.media_fail_cb) this.media_fail_cb();
    },
    reportOffer: function(room,ptId,pcId,localSDP){
        var curObj = this;
        // var dt = formatDateTimeString(new Date()); 
        var data = {event:"report", params:{room:room, ptId:ptId,pcId:pcId,type:"offer", data:localSDP}};  //********
        lhp.sendData(data, function(data){}, function(err){
            curObj.onWrtcError(err.reason, 5, 2000);
        });
    },
    reportAnswer: function(room,ptId,pcId,localSDP){
        var curObj = this;
        var dt = formatDateTimeString(new Date()); 
//      var data = {event:'join', params:{room:curObj.room,ptId:curObj.ptId,pcId:curObj.pcId,sdp:localSDP}};  //**********
        var data = {event:"report", params:{room:room, ptId:ptId,pcId:pcId,type:"answer", data:localSDP}};  //********
        lhp.sendData(data);
    },
    kickout:function(data){
        if(this.is_creator){
            this.reportState(data.room, this.ptId, data.pcId, "kickout");
            this.play_tone("");
        }
        else
            this.hangup();
    },
    reportState: function(room,ptId,pcId,State){
        var curObj = this;
        var dt = formatDateTimeString(new Date()); 
        var data = {event:"report", params:{room:room, ptId:ptId,pcId:pcId,type:"state", data:State}};
        lhp.sendData(data);
    },
    onIceCandidate: function(candidate){
        var curObj = this;
        var data = {event:'peer_candidate', params:{
            room:this.room,
            ptId:curObj.ptId, pcId:curObj.pcId,
            asClient:this.asClient,
            label: candidate.sdpMLineIndex,
            id: candidate.sdpMid,
            candidate: candidate.candidate
        }};  //**********
//      console.log("<========peer_candidate:", candidate.candidate);
        lhp.sendData(data);
    },
    leaveRoom: function(){
        var dt = formatDateTimeString(new Date()); 
        var evt="leave_room";
        var data = {event:evt, params:{room:this.room, timestamp:dt, ptId:this.ptId||'',uuid:this.uuid}};
        lhp.sendData(data);
    },
    shakeHand: function(){
        if(this.asClient) return;
        var curObj = this;
        var evt= 'shakehand_opr';
        var data = {event:evt, params:{ room:this.room, oprid:this.asClient,  media_type:curObj.media_type}};
        lhp.sendData(data,function(data){
            var event=data.event;
            curObj.lost_times = 0;
        }, function(err){

        });
        curObj.lost_times += 1;
        if(curObj.lost_times>SHAKE_TIMES) {
            lw_log("shake timeout exceed "+SHAKE_TIMES+" times!");
           // curObj.setTitle('和服务器连接中断，请重新进入'+curObj.room+'房间！');
        }else{
            curObj.shakeTimer = setTimeout(function() {curObj.shakeHand();}, FZD_SHAKEHAND_TIMER);
        }
    },
    //received from shakehand down msg
    processDownMsg: function(data){
        var curObj=this;
//      console.log("==========>", "event:", data.event, "data:", data);
        switch(data.event){
            case 'require_offer':
                curObj.on_require_offer(data);
                break;
            case 'require_answer':
                curObj.on_require_answer(data);
                break;
            case 'notify_candidate':
                curObj.on_notify_candidate(data);
                break;
            case 'notify_state':
                curObj.on_notify_state(data);
                break;
            case 'notify_answer':
                curObj.on_notify_answer(data);
                break;
            case 'require_close':
                curObj.onPeerLeave(data);
                break;
            case 'require_close_all':
                curObj.onRequireCloseAll(data);
                break;
            case 'server_disc':
                curObj.server_disc(data);
//                alert('与服务器通信中断!');
                break;
            default:
                break;
        }
    }
}


p2pVideo.prototype.server_disc = function(data) {
//    this.server_disc_cb(data.reason);
    if(data.reason != 'server_no_session') this.hangup();
};

p2pVideo.prototype.deleteRoom = function(onCallback) {
    var curObj = this;
    var data = {event:"delete_room", params:{room:curObj.room,ptId:curObj.ptId,uuid:curObj.uuid}}; 
    lhp.sendData(data, function(data){
        clearTimeout(curObj.shakeTimer);
        p2pclient=false;
    }, function(err){
        curObj.onWrtcError(err.reason, 5, 2000);
    });
};

p2pVideo.prototype.windowClose = function(cb) {
    this.hangup();
    if(cb) cb();

};

function obtainLocalMediaCallback(type,owner,callback,fb) {
    function getMediaParas(type) {
        switch(type) {
            case 'p2pav':
                return {audio:true, video:defaultVideoMediaParas};
            case 'screen':
                return  {audio:false, video:defaultScreenMediaParas};
            default:
                return {audio:true};
        }
    }
    var mediaParas= getMediaParas(type);
    obtainLocalMedia(mediaParas, function(stream) {
       var MediaURL = webkitURL.createObjectURL(stream);
       owner.onLocalStream(MediaURL);
       owner.mediaParas = mediaParas;
       if(callback) callback();
    }, function(){
        owner&&owner.media_fail_cb&&owner.media_fail_cb();
       if(fb) fb();
    });
};

function RoomHandler(type){
  this.type = type;	
}

RoomHandler.prototype = {	
   CreateAndEnterRoom: function(type, attrs, facade_cbs, sucesscb, failedcb) {
        var curObj = this;  
        var data = {event:"create_room", params:{type:type, attr:attrs, uuid:UUID}};
          lhp.sendData(data, function(data){
           // console.log('createrrom:' + data);
            var paras = facade_cbs;
            paras.room = data.room;
            paras.media_type = type;
            paras.is_creator = true;
            var p2p = new p2pVideo(paras);
            obtainLocalMediaCallback(curObj.type,p2p,function() {
                p2pclient = p2p;
                p2pclient.enter_room(paras.room);
            });
            sucesscb(data);
          }, function(err){
             failedcb(err);
          });
    },
    enterRoom: function(Room, facade_cbs, sucesscb, failedcb){
        var curObj = this;
        var paras = facade_cbs||{};
        paras.room = Room;
        paras.media_type = curObj.type;
        var p2p=new p2pVideo(paras);
        var enterf = function() {
            p2p.enter_room(Room, sucesscb, failedcb);
        };
        if(curObj.type=="screen") {
            scrclient = p2p;
        }else {
            p2pclient = p2p;
        }
        obtainLocalMediaCallback(curObj.type,p2p,enterf);
    }

}


var lw_debug_id=false;
function lw_log(){
    if(lw_debug_id) console.log(arguments);
}

function ManageSoundControl(action, num) {
   return;
  var sc = document.getElementById("soundControl");  
  if(action == "play") {
      sc.playcount = (num ? num.toString() : "1");
      sc.play();	  
  }else if(action == "stop") {	  
      sc.pause();
      sc.playcount = "1";	  
  }  
}


p2pVideo.prototype.new_pc=function(pcId,peerUUID){
    if(this.peerConns[pcId]) return this.peerConns[pcId];
    this.peerConns[pcId] = new peerConnection(this, pcId, peerUUID);
    return this.peerConns[pcId];
};
p2pVideo.prototype.waiting2talk =function(){
    if(this.waiting2act) {
        this.waiting2act();
        this.waiting2act = false;
    }
}
p2pVideo.prototype.on_require_offer =function(data){
    var curObj = this;
    var act = function(){
        var pc = curObj.new_pc(data.pcId,data.peerUUID);
        pc && pc.on_require_offer(data);
        curObj.play_tone(curObj.ringback_tone);
    }
    if(this.isWaiting) {
        curObj.waiting2act = act;
        curObj.isWaiting = false;
        curObj.play_tone('');
        curObj.request_talking(data);
    }else{
        curObj.play_tone(curObj.ringback_tone);
        act();
    }
}
p2pVideo.prototype.on_require_answer=function(data){
    var curObj = this;
    var pc = curObj.new_pc(data.pcId,data.peerUUID);
    this.waiting2act = function(){
        pc && pc.on_require_answer(data);
    };
    curObj.play_tone(curObj.ring_tone);
    curObj.request_talking(data);
}

p2pVideo.prototype.play_tone=function(uri){
    if (this.isTalking) return;
    this.winDom.find('.p2p_remote_Screen').attr('src', uri);
}

p2pVideo.prototype.on_notify_candidate=function(data){
    var pc = this.peerConns[data.pcId];
    pc && pc.on_notify_candidate(data);

}
p2pVideo.prototype.on_notify_state=function(data){
    var pc = this.peerConns[data.pcId];
    pc && pc.on_notify_state(data);
}
p2pVideo.prototype.on_notify_answer=function(data){
    var pc = this.peerConns[data.pcId];
    pc && pc.on_notify_answer(data);
}
p2pVideo.prototype.onPeerLeave= function(data){
    var pc = this.peerConns[data.pcId];
    pc && pc.onPeerLeave(data);
    delete this.peerConns[data.pcId];
}
p2pVideo.prototype.onRequireCloseAll= function(){
    this.p2pVideoStopped();
}


function peerConnection(owner,pcId,peerUUID) {
//    this.win = $(class_str);
    this.owner = owner;
    this.pcId = pcId;
    this.room = owner.room;
    this.ptId = owner.ptId;
    this.media_type = owner.media_type;
    this.wrtcClient = new webrtcClient(this);
    this.peerUUID = peerUUID;
}

peerConnection.prototype.onRemoteStream= function(remoteURI){
  //  console.log("dsafsaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
//    this.win.attr('src', remoteURI);
    this.owner.winDom.find('.p2p_remote_Screen').attr('src', remoteURI);
    this.owner.isTalking = true;
    this.owner.incoming({pcId:this.pcId, uri:remoteURI,from_uuid:this.peerUUID, peerIsCreator:this.peerIsCreator});
};


peerConnection.prototype.onLocalSDP= function(localSDP){
    var curObj = this;
    this.localSDP = localSDP;  //yxw
    if (curObj.asClient){
        this.owner.reportOffer(this.room,this.ptId,this.pcId,localSDP);
    }else{
        this.owner.reportAnswer(this.room,this.ptId,this.pcId,localSDP);
    }    
};

peerConnection.prototype.onIceCandidate= function(candidate){
    var curObj = this;
    var data = {event:'peer_candidate', params:{
        room:this.room,
        ptId:curObj.ptId, pcId:curObj.pcId,
        label: candidate.sdpMLineIndex,
        id: candidate.sdpMid,
        candidate: candidate.candidate
    }};  //**********
//  console.log("<========peer_candidate:", candidate.candidate);
    lhp.sendData(data);
},

peerConnection.prototype.onLocalStream= function(uri){
    this.owner.onLocalStream(uri);
},

peerConnection.prototype.on_require_offer=function(data){
    this.peerUUID = data.from_uuid;
    this.peerIsCreator = data.is_creator;
    this.asClient = true;
    var paras = this.owner.media_type == 'screen' ? 
        {audio:false,video:defaultScreenMediaParas}:
        {audio:true, video:defaultVideoMediaParas};
    this.wrtcClient.prepareCall(this.owner.media_type, paras,null);
};

peerConnection.prototype.on_require_answer=function(data){
    this.peerUUID = data.from_uuid;
    this.peerIsCreator = data.is_creator;
    var curObj = this;
    var peerSDP = data.data;
    curObj.asClient = false;
    var paras = this.owner.media_type == 'screen' ? 
        {audio:false,video:defaultScreenMediaParas}:
        {audio:true, video:defaultVideoMediaParas};
    curObj.wrtcClient.prepareCall(curObj.media_type, paras, peerSDP);
    ManageSoundControl('play',2);
};

peerConnection.prototype.on_notify_candidate=function(data){
    this.wrtcClient.onPeerCandidate(data);
};
peerConnection.prototype.on_notify_answer=function(data){
    this.wrtcClient.setRemoteSDP(data.data);
};
peerConnection.prototype.on_notify_state=function(data){
    var info = data.data;
    if(info=="kickout") {
        this.owner.hangup();
    }
};

peerConnection.prototype.onWrtcError = function(error){
    this.owner.onWrtcError(error);
};

peerConnection.prototype.onPeerLeave = function(){
    this.p2pVideoStopped();
    this.owner.peerleave_cb(this.peerUUID);
};

peerConnection.prototype.p2pVideoStopped=function(){
    this.wrtcClient.terminateCall();
    this.owner.isTalking = false;
    this.owner.play_tone("");
};


var lwork_room_host0 = 'https://www.94360.com';//'http://116.228.53.181/channel/',//'http://192.168.180.29/channel/',
var lwork_room_host = window.location.hostname=="10.32.3.52" ? "" : lwork_room_host0;
//for fzd
var lwforfzdVoices={
    is_creator:false,
    p2p_audio_url : lwork_room_host+'/channel/',
    get_free_room:function (paras, success_cb,fail_cb){
        var curObj = this;
        var data = {event:"create_room", params:{type:'p2pav', attr:{capacity:2},uuid:paras.uuid}};
          lhp.sendData(data, function(data){
           // console.log('createrrom:' + data);
            curObj.room=data.room;
            curObj.is_creator=true;
            success_cb&&success_cb(data);
          }, function(err){
             fail_cb&&fail_cb(err);
          });
    },
    enter_room: function(paras, sucesscb, failedcb){ 
    //paras:{uuid:uuid,room:room,cbs:{incoming:i,media_ok:m,media_fail:m1,peerleave:p,release:r,err:e}}
        var curObj = this;
        paras.media_type = 'audio';
        paras.is_creator = this.is_creator;
        paras.p2p_audio_url = this.p2p_audio_url;
        p2pclient=new p2pVideo(paras);
        obtainLocalMediaCallback(paras.media_type,p2pclient,
            function() {p2pclient.enter_room(paras.room || curObj.room, sucesscb, failedcb);});
    },
    leave_room:function(){
        p2pclient&&p2pclient.windowClose();
    },
    waiting2talk:function(){
        p2pclient&&p2pclient.waiting2talk();
    },
    kickout:function(data) {
        p2pclient&&p2pclient.kickout(data);
    },
    get_room_infos: function (UUIDS,cb,fb){
        var data = {event:"get_opr_rooms", params:{uuids:UUIDS}}; 
        lhp.sendData(data, cb, fb);
    }
};

function test_incoming(data){
    $('#v_videscreen2').attr('src', data.uri);
}

function test_media_ok(data){
    
}

var lhp = new RestConnection(null, lwforfzdVoices.p2p_audio_url);

var win_id = 'LworkVideoCS';
var dom_id = 'window_'+win_id+'_warp';
$((function(){
(function doStartShow(opts) {
    if($('#'+dom_id).length>0) return;
    var uuid = opts && opts.uuid || UUID;
    var peer_uuid = opts && opts.peer_uuid||'';
    var hint = '请"允许"使用麦克风';
    var dom_tpl=$(audio_tpl(hint));
    var width = 176;
    var height = 170;
    lwork_create_video_win({ 'id': win_id, 'name':  '本端:'+uuid+' 对端:'+peer_uuid , 'resize':false, 
        'content': dom_tpl,width:width, height:height, 
        from: peer_uuid }); 
    if(!(opts&&opts.hide_id)) {
        $('#window_LworkVideoCS_warp').show();
    }else{
        $('#window_LworkVideoCS_warp').hide();
    }
})({hide_id:true});
})());