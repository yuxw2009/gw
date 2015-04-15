var defaultVideoMediaParas = {"mandatory": {
                                              "minWidth": "320",
                                              "maxWidth": "320",
                                              "minHeight": "240",
                                              "maxHeight": "240",
                                              "minFrameRate": "10"},
                                              "optional": []};

function p2pAudio(sid){
    this.sid = sid;
    this.winDom = $('#window_'+sid+'_warp');
    this.wrtcClient = new webrtcClient(this, this.winDom.find('.big_audio_Screen')[0], null);
    this.asCaller = true;
    this.peerUUID = null;
};
p2pAudio.prototype = {
    bindHandlers: function(){
        var curObj = this;

        curObj.winDom.find('.S_audio').unbind('click').bind('click', function(){
            var session_members = sc.sessions[curObj.sid].members;
            var peerUUID = session_members[0] == myID() ? session_members[1] : session_members[0];
            var peerUser = mainmark.getContactAttr(peerUUID.toString());
            
            if (peerUser.status == 'offline'){
                LWORK.msgbox.show('Sorry, peer is offline' , 3, 1000);
            }else{
                curObj.start(peerUUID);
            }
            return false;
        });
        curObj.winDom.find('.ahangUp').unbind('click').bind('click', function(){
            curObj.end();
            return false;
        });

        return this;
    },
    onNewTip: function(){
        var curObj = this;
        curObj.winDom.find('.audio_invitation .accept').unbind('click').bind('click', function(){
            curObj.acceptInvitation($(this));
            $(this).parent().parent().hide();
            ManageSoundControl('stop');
            return false;
        });
    },
    ready: function(){
        this.p2pAudioStopped();
        return this;
    },
    start: function(peerUUID){
        this.asCaller = true;
        this.peerUUID = peerUUID;
        pageTips(this.winDom.find('.S_audio').parent(), 'Click the above "Allow" button, please', 'info');
        this.wrtcClient.prepareCall('audio', defaultVideoMediaParas); 
    },
    end: function(){
        this.endP2P();
        LWORK.msgbox.show('Call is over', 4, 1000);
        this.p2pAudioStopped();
    },
    acceptInvitation: function(dataDom){
        var from = dataDom.attr('from'), sdp = dataDom.attr('sdp');
        this.joinVideo(from, sdp);
    },
    joinVideo: function(peerUUID, peerSDP){
        var curObj = this;
        curObj.asCaller = false;
        curObj.peerUUID = peerUUID;
        pageTips(this.winDom.find('.S_audio').parent(), 'Click the above "Allow" button, please', 'info');
        curObj.wrtcClient.prepareCall('audio', defaultVideoMediaParas, peerSDP);
    },
    doStart: function(localSDP){
        this.startP2P(localSDP);
        this.p2pAudioStarted();
        this.winDom.find('.p2pAudioTip').text('Waiting for reply ...');
    },
    doAnswer: function(localSDP){
        this.acceptP2P(localSDP);
        this.p2pAudioStarted();
        this.winDom.find('.p2pAudioTip').text('Talking ...');
    },
    p2pAudioStopped: function(){
        this.asCaller = true;
        this.peerUUID = null;
        this.receivedPid = '';
        this.wrtcClient.terminateCall();
        this.winDom.find('.big_audio_Screen').attr('src', '');
        Core.changeDisplayMode(this.sid, 'p2p', 'chat');
        removePageTips(this.winDom.find('.S_audio').parent());
    },
    p2pAudioStarted: function(){
        Core.changeDisplayMode(this.sid, 'p2p', 'audio');
        removePageTips(this.winDom.find('.S_audio').parent());
    },
    isOngoing: function(){
        return true && this.peerUUID;
    },

    //// callbacks for webrtcClient..
    onLocalSDP: function(localSDP){
        var curObj = this;
        if (curObj.asCaller){
            curObj.doStart(localSDP);
        }else{
            curObj.doAnswer(localSDP);
        }    
    },
    onLocalStream: function(){
        var curObj = this;
        pageTips(curObj.winDom.find('.S_audio').parent(), 'Session is establishing ...', 'info');   
    },
    onWrtcError: function(error){
        this.p2pAudioStopped();
        LWORK.msgbox.show(error, 5, 2000);
    },

    //send to Hotport
    startP2P: function(localSDP){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'audio_p2p', 
            action:'invite', sdp:localSDP, peer_id:this.peerUUID.toString()}};
        hp.sendData(data);
    },
    acceptP2P: function(localSDP){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'audio_p2p', 
            action:'accept', sdp:localSDP, peer_id:this.peerUUID.toString()}};
        hp.sendData(data);
    },
    endP2P: function(){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'audio_p2p', 
            action:'stop', peer_id:this.peerUUID.toString()}};
        hp.sendData(data);
    },


    //received from hotport
    processVideoMsg: function(payload){
        var curObj = this;
        //console.log(payload);
        switch (payload.action){
            case 'peer_accept':
                curObj.onPeerAccept(payload.sdp);
                break;
            case 'peer_stop':
                curObj.onPeerStop();
                break;
            default:
                break;
        }
    },
    onPeerAccept: function(peerSDP){
        if (this.isOngoing()){
            this.wrtcClient.setRemoteSDP(peerSDP);
            this.winDom.find('.p2pAudioTip').text('Talking ...');
        }
    },
    onAcceptFailure: function(reason){
        LWORK.msgbox.show('Expired audio session', 5, 2000);
        this.p2pAudioStopped();
    },
    onPeerStop: function(){
        LWORK.msgbox.show('Peer has hung up.', 4, 1000);
        this.p2pAudioStopped();
    },


    //on chatwin message.
    onWindowClosed: function(){
        if (this.peerUUID){
            this.end();
        }
    }
}
