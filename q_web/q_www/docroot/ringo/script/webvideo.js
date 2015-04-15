
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

function mpVideo(sid){
    this.sid = sid;
    this.winDom = $('#window_'+sid+'_warp');
    this.wrtcClient = new webrtcClient(this, document.getElementById('mpvideo_'+ sid +'_box'), null);
    this.asChairman = true;
    this.myRoomNo = null;
    this.mySeatNo = 0;
}
mpVideo.prototype = {
    bindHandlers: function(){
    	var curObj = this;
        var video = document.getElementById('mpvideo_'+ curObj.sid +'_box');

        curObj.winDom.find('.S_video').unbind('click').bind('click', function(){
            var curCandidates = sc.sessions[curObj.sid].members.filter(function(item){var userInfo = mainmark.getContactAttr(item); return userInfo && userInfo.status == 'online';});
            if (curCandidates.length > 3){
                curObj.start([myID()]);
            }else{
                curObj.start(curCandidates);
            }
            return false;
        });
        curObj.winDom.find('.vhangUp').unbind('click').bind('click', function(){
            if (curObj.asChairman){
                curObj.end();
            }else{
                curObj.leave();
            }
            return false;
        });
        curObj.winDom.find('input.inputToInvite').unbind('focus').bind('focus', function(){
            var inputDom = $(this);
            var curCandidates = sc.sessions[curObj.sid].members.filter(function(item){var userInfo = mainmark.getContactAttr(item); return userInfo && userInfo.status == 'online';});
            var curInRoom = [];
            curObj.winDom.find('.invited, .occupy, .busy').each(function(){curInRoom.push(parseInt($(this).attr('mUUID')));});
            //console.log(curCandidates);console.log(curInRoom);
            curCandidates = curCandidates.filter(function(item){return curInRoom.indexOf(item) == -1;});
            var html = curCandidates.map(function(u){return FormatModel(friendItemTemplate2, mainmark.getContactAttr(u));}).join('');
            var toInviteList = $(this).parent().find('.inviteList');
            toInviteList.html(html).show();
            toInviteList.find('.frienditem').unbind('click').bind('click', function(){
                inputDom.val($(this).find('.friendname').html());
                inputDom.attr('toInviteID', $(this).attr('uuid'));
                toInviteList.hide();
			    inputDom.parent().parent().parent().mouseenter();
				
                return false;
            });
            return false;
        });
        curObj.winDom.find('input.inputToInvite').unbind('blur').bind('blur', function(){
            $(this).val('');
            $(this).attr('toInviteID', '');
            return false;
        });
        curObj.winDom.find('.inviteInVideo').unbind('click').bind('click', function(){
            var toInviteInput = $(this).parent().find('input.inputToInvite');
            var toInviteID = toInviteInput.attr('toInviteID');
            var curSeat = $(this).parent().parent().parent();

            if (toInviteInput.val().length == 0 || toInviteID == ''){
                LWORK.msgbox.show("Please select a friend!", 3, 1000);
                return false;
            }

            curSeat.find('.videObjInfo').html(toInviteInput.val());
            curSeat.find('.videoObjName').html(toInviteInput.val());
            curObj.updateMemberStatus(curSeat.attr('seat'), toInviteID, 'invited');

            curSeat.addClass('pending');
            setTimeout(function(){
                if (curSeat.hasClass('pending')){
                    LWORK.msgbox.show("Invitation is not responsed by server", 5, 1000);
                }
                curSeat.removeClass('pending');
            }, 8000);
            curObj.add2OngoingMVideo(toInviteID, curSeat.attr('seat'));

            curObj.winDom.find('input.inputToInvite').each(function(){
                if ($(this).attr('toInviteID') == toInviteID){
                    $(this).val('');
                    $(this).attr('toInviteID', '');
                }
            });

            return false;
        });
        curObj.winDom.find('.ribbonMenu').find('a').bind('click', tabSwitch);
        curObj.winDom.find('dd').unbind('mouseenter').bind('mouseenter', function(){
            if($(this).hasClass('free') && curObj.asChairman){
                $(this).find('.videoObjOpt').show();
            }  
        }).unbind('mouseleave').bind('mouseleave', function(){
			if( $(this).find('.inputToInvite').val() == '')
             $(this).find('.videoObjOpt').hide();
			
        });
        curObj.winDom.find('.fullscreen').click(function(){ 
          video.webkitRequestFullScreen(); // webkit类型的浏览器
       //   video.mozRequestFullScreen();  // FireFox浏览器
        });
        video.addEventListener('timeupdate', function() {
           var curTime = Math.floor(video.currentTime);
           var hour = parseInt(curTime / 3600);// 分钟数      
           var min = parseInt(curTime / 60);// 分钟数
           var sec = parseInt(curTime % 60);
           var txt = (parseInt(hour, 10) < 10 ? '0' + hour : hour)  + ":" + (parseInt(min, 10) < 10 ? '0' + min : min)  + ":" + (parseInt(sec, 10) < 10 ? '0' + sec : sec); 
           curObj.winDom.find('.videoCurrentTime').text(txt);
        }, true);
        
        return this;
    },
    onNewTip: function(){
        var curObj = this;
        curObj.winDom.find('.video_invitation .accept').unbind('click').bind('click', function(){
            curObj.acceptInvitation($(this));
            $(this).parent().parent().hide();
            ManageSoundControl('stop');
            return false;
        });
        curObj.winDom.find('.video_ongoing .accept').unbind('click').bind('click', function(){
            var host_id = myID(), room_no = $(this).attr('room_no'), seat_no = $(this).attr('seat_no');
            curObj.joinConf(host_id, room_no, seat_no);
            $(this).parent().parent().hide();
            ManageSoundControl('stop');
            return false;
        });
        curObj.winDom.find('.video_ongoing .endIt').unbind('click').bind('click', function(){
            curObj.myRoomNo = $(this).attr('room_no');
            curObj.end();
            $(this).parent().parent().hide();
            ManageSoundControl('stop');
            return false;
        });
    },
    ready: function(){
        this.mVideoStopped();
        return this;
    },
    isOngoing: function(){
        return true && this.myRoomNo;
    },
    acceptInvitation: function(dataDom){
        var from = dataDom.attr('host_id'), room = dataDom.attr('room_no'), position = dataDom.attr('seat_no');
        this.joinConf(from, room, position);
    },
    joinConf: function(chairman, roomNo, seatNo){
        var curObj = this;
        if (curObj.myRoomNo){
            if (curObj.asChairman){
                curObj.endMPV();
            }else{
                curObj.leaveMPV();
            }
        }
        curObj.asChairman = (myID() == chairman) ? true : false;
        curObj.myRoomNo = roomNo;
        curObj.mySeatNo = seatNo;
        pageTips(this.winDom.find('.S_video').parent(), 'Click the above "Allow" button, please', 'info');
        curObj.wrtcClient.prepareCall('video', defaultVideoMediaParas);   
    },
    start: function(members){
        for (var i = 0; i < members.length; i++){
            this.assignSeat(members[i]);
        }
        this.asChairman = true;
        pageTips(this.winDom.find('.S_video').parent(), 'Click the above "Allow" button, please', 'info');
        this.wrtcClient.prepareCall('video', defaultVideoMediaParas);
    },
    end: function(){
        this.endMPV();
    },
    leave: function(){
        this.leaveMPV();
    },
    add2OngoingMVideo: function(aUUID, seatNo){
        this.inviteMPV(seatNo, aUUID);
    },
    assignSeat: function(aUUID){
        var curObj = this;
        var allSeats = curObj.winDom.find('.seat');
        for (var i = 0; i < allSeats.length; i++){
            if (allSeats.eq(i).attr('mUUID') == 'none'){
                allSeats.eq(i).attr('mUUID', aUUID.toString());
                curObj.updateMemberStatus(i.toString(), aUUID, 'invited');
                return i;
            }
        }
        return -1;
    },
    updateMemberStatus: function(seatNo, aUUID, status){
        var curObj = this;
        var seatDom = curObj.winDom.find('.seat' + seatNo);
        var user = mainmark.getContactAttr(aUUID);        
        seatDom.attr('mUUID', aUUID);
        seatDom.find('.videoObjName, .videObjInfo').text(user.name);
        seatDom.removeClass('free invited occupy busy').addClass(status);
    },
    resetSeat: function(seatObj){
        seatObj.attr('mUUID', 'none');
        seatObj.find('.videoObjName, .videObjInfo').text('');
        seatObj.removeClass('free invited occupy busy').addClass('free');
    },
    collectMembers: function(){
        var curObj = this;
        var allSeats = curObj.winDom.find('.seat');
        var rslt = new Array();
        for (var i = 0; i < allSeats.length; i++){
            if (allSeats.eq(i).attr('mUUID') != 'none'){
                rslt.push({'uuid':allSeats.eq(i).attr('mUUID'), 'position':i.toString()});
            }
        }
        return rslt;
    },
    doStart: function(selfSDP){
        var curObj = this;
        var members = curObj.collectMembers();
        pageTips(this.winDom.find('.S_video').parent(), 'Waiting for the conference being established ...', 'info');
        curObj.startMPV(selfSDP, members);
    },
    mVideoStarted: function(){
        var curObj = this;
        if (curObj.asChairman){
            curObj.winDom.find('.hangUp').text('End');
        }else{
            curObj.winDom.find('.hangUp').text('Hangup');
        }
        Core.changeDisplayMode(this.sid, 'mp', 'video');
        removePageTips(this.winDom.find('.S_video').parent());
    },
    mVideoStopped: function(){
        var curObj = this;
        curObj.asChairman = true;
        curObj.myRoomNo = null;
        curObj.winDom.find('.seat').each(function(){
            curObj.resetSeat($(this));
        });
		curObj.winDom.find('.video_screen').attr('src', '');
        curObj.wrtcClient.terminateCall();
        Core.changeDisplayMode(curObj.sid, 'mp', 'chat');
        removePageTips(this.winDom.find('.S_video').parent());
    },
    enterConf: function(selfSDP){
        this.enterMPV(selfSDP);
    },
    
    // the following three functions are webrtcClient callbacks..
    onLocalSDP: function(localSDP){
        var curObj = this;
        if (curObj.asChairman && !curObj.myRoomNo){
            curObj.doStart(localSDP);
        }else{
            curObj.enterConf(localSDP);
        }
    },
    onLocalStream: function(){
        pageTips(this.winDom.find('.S_video').parent(), 'Session is establishing ...', 'info');
    },
    onWrtcError: function(error){
        this.mVideoStopped();
        LWORK.msgbox.show(error, 5, 2000);
    },

    //notify to hotPort
    startMPV: function(selfSDP, members){
        var dt = formatDateTimeString(new Date());
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'video_conf', 
            action:'create', host_sdp:selfSDP, members:members}};
        hp.sendData(data);
        //console.log(data);
    },
    endMPV: function(){
        var dt = formatDateTimeString(new Date());
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'video_conf', 
            action:'stop', conf_no:this.myRoomNo}}
        hp.sendData(data);
        //console.log(data);
    },
    enterMPV: function(selfSDP){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'video_conf', 
            action:'enter', conf_no:this.myRoomNo, position:this.mySeatNo, sdp:selfSDP}}
        hp.sendData(data);
        //console.log(data);
    },
    leaveMPV: function(){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'video_conf', 
            action:'leave', conf_no:this.myRoomNo}};
        hp.sendData(data);
        //console.log(data);
    },
    inviteMPV: function(seatNo, Invitee){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'video_conf', 
            action:'invite', conf_no:this.myRoomNo, position:seatNo, invitee:Invitee}};
        hp.sendData(data);
    },

    //received data from hotPort
    processVideoMsg: function(payload){
        var curObj = this;
        //console.log(payload);
        switch (payload.action){
            case 'create_ok':
                curObj.onStartMPVOK(payload.conf_no, payload.conf_sdp);
                break;
            case 'create_failed':
                curObj.onStartMPVFailure(payload.reason);
                break;
            case 'invite':
                var chatTip = curObj.winDom.find('.chatWin_tip');
                chatTip.find('.invitor_name').text(payload.host_name);
                chatTip.find('.accept').attr({host_id:payload.host_id, room_no:payload.conf_no, seat_no:payload.position});
                chatTip.show();
                break;
            case 'enter_ok':
                curObj.onEnterMPVOK(payload.conf_no, payload.conf_sdp);
                break;
            case 'enter_failed':
                curObj.onEnterMPVFailure(payload.reason);
                break;
            case 'stop_ok':
                curObj.onEndMPVOK();
                break;
            case 'leave_ok':
                curObj.onLeaveMPVOK();
                break;
            case 'conf_status':
                curObj.onMPVInfo(payload.conf_status);
                break;
            case 'over':
                curObj.onMPVOver();
                break;
            default:
                break;
        }
    },
    onStartMPVOK: function(roomNo, roomSDP){
        this.myRoomNo = roomNo;
        this.wrtcClient.setRemoteSDP(roomSDP);
        this.mVideoStarted();
    },
    onStartMPVFailure: function(reason){
        if (reason == 'conf_already_exist'){
            LWORK.msgbox.show('Videoconference has already been started', 5, 2000);
        }else if(reason == 'no_free_room'){
            LWORK.msgbox.show('No conference resource available', 5, 2000);
        }else{
            LWORK.msgbox.show('Start videoconference unsuccessfully', 5, 2000);
        }
        this.mVideoStopped();
    },
    onEnterMPVOK: function(roomNo, roomSDP){
        this.wrtcClient.setRemoteSDP(roomSDP);
        this.mVideoStarted();
        Core.changeDisplayMode(this.sid, 'mp', 'video');
    },
    onEnterMPVFailure: function(reason){
        if (reason == 'conf_invalid'){
            LWORK.msgbox.show('Expired videoconference', 5, 2000);
        }else{
            LWORK.msgbox.show('Join videoconference unsuccessfully', 5, 2000);
        }
        this.mVideoStopped();
    },
    onInviteFailure: function(reason){

    },
    onEndMPVOK: function(){
        this.mVideoStopped();
        LWORK.msgbox.show('Videoconference has been ended', 4, 1000);
    },
    onLeaveMPVOK: function(){
        this.mVideoStopped();
        LWORK.msgbox.show('Leave the videoconference successfully', 4, 1000);
    },
    onMPVInfo: function(roomInfo){
        var curObj = this;
        if (!roomInfo || roomInfo.length == 0 || !curObj.myRoomNo){
            LWORK.msgbox.show('Videoconference has been ended', 4, 2000);
            curObj.mVideoStopped();
            return;
        }
        var emptySeats = [0, 1, 2, 3];
        for (var i = 0; i < roomInfo.length; i++) {
            var uuid = roomInfo[i]['uuid'];
            var status = roomInfo[i]['status'];
            delete emptySeats[parseInt(roomInfo[i]['position'])];
            //console.log(roomInfo[i]);
            curObj.winDom.find('.seat'+roomInfo[i]['position']).removeClass('pending');
            curObj.updateMemberStatus(roomInfo[i]['position'], roomInfo[i]['uuid'], roomInfo[i]['status']);
        }
        for (j in emptySeats){
            if (!curObj.winDom.find('.seat'+emptySeats[j].toString()).hasClass('pending')){
                curObj.resetSeat(curObj.winDom.find('.seat'+emptySeats[j].toString()));
            }
        }
    },
    onMPVOver: function(){
        LWORK.msgbox.show('Videoconference has been ended', 4, 1000);
        this.mVideoStopped();
    },
    onWindowClosed: function(){
        /*
        if (this.isOngoing()){
            if (this.asChairman){
                this.endMPV();
            }else{
                this.leaveMPV();
            }
            this.mVideoStopped();
        }
        */
    }
}

function p2pVideo(sid){
    this.sid = sid;
    this.winDom = $('#window_'+sid+'_warp');
    this.wrtcClient = new webrtcClient(this, this.winDom.find('video.big_video_Screen')[0], this.winDom.find('video.small_video_Screen')[0]);
    this.asCaller = true;
    this.peerUUID = null;
};
p2pVideo.prototype = {
    bindHandlers: function(){
        var curObj = this;
        var video = document.getElementById('p2pvideo_'+ curObj.sid +'_big');

        curObj.winDom.find('.S_video').unbind('click').bind('click', function(){
            var session_members = sc.sessions[curObj.sid].members;
            var peerUUID = session_members[0] == myID() ? session_members[1] : session_members[0];
            var peerUser = mainmark.getContactAttr(peerUUID.toString());
            
            if (peerUser.status == 'offline'){
                LWORK.msgbox.show('Sorry, Peer is offline.' , 3, 1000);
            }else{
                curObj.start(peerUUID);
            }
            return false;
        });
        curObj.winDom.find('.vhangUp').unbind('click').bind('click', function(){
            curObj.end();
            return false;
        });
        curObj.winDom.find('.fullscreen').click(function(){ 
          video.webkitRequestFullScreen(); // webkit类型的浏览器
       //   video.mozRequestFullScreen();  // FireFox浏览器
        });
        video.addEventListener('timeupdate', function() {
           var curTime = Math.floor(video.currentTime);
           var hour = parseInt(curTime / 3600);// 分钟数      
           var min = parseInt(curTime / 60);// 分钟数
           var sec = parseInt(curTime % 60);
           var txt = (parseInt(hour, 10) < 10 ? '0' + hour : hour)  + ":" + (parseInt(min, 10) < 10 ? '0' + min : min)  + ":" + (parseInt(sec, 10) < 10 ? '0' + sec : sec); 
           curObj.winDom.find('.videoCurrentTime').text(txt);
        }, true);
        return this;
    },
    onNewTip: function(){
        var curObj = this;
        curObj.winDom.find('.video_invitation .accept').unbind('click').bind('click', function(){
            curObj.acceptInvitation($(this));
            $(this).parent().parent().hide();
            ManageSoundControl('stop');
            return false;
        });
    },
    ready: function(){
        this.p2pVideoStopped();
        return this;
    },
    start: function(peerUUID){
        this.asCaller = true;
        this.peerUUID = peerUUID;
        pageTips(this.winDom.find('.S_video').parent(), 'Click the above "Allow" button, please', 'info');
        this.wrtcClient.prepareCall('video', defaultVideoMediaParas); 
    },
    end: function(){
        this.endP2P();
        LWORK.msgbox.show('The video session is over', 4, 1000);
        this.p2pVideoStopped();
    },
    acceptInvitation: function(dataDom){
        var from = dataDom.attr('from'), sdp = dataDom.attr('sdp');
        this.joinVideo(from, sdp);
    },
    joinVideo: function(peerUUID, peerSDP){
        var curObj = this;
        curObj.asCaller = false;
        curObj.peerUUID = peerUUID;
        pageTips(this.winDom.find('.S_video').parent(), 'Click the above "Allow" button, please', 'info');
        curObj.wrtcClient.prepareCall('video', defaultVideoMediaParas, peerSDP);
    },
    doStart: function(localSDP){
        this.startP2P(localSDP);
        this.p2pVideoStarted();
        this.winDom.find('.p2pVideoTip').show().text('Waiting for reply...');
    },
    doAnswer: function(localSDP){
        this.acceptP2P(localSDP);
        this.p2pVideoStarted();
        this.winDom.find('.p2pVideoTip').hide().text('');
    },
    p2pVideoStopped: function(){
        this.asCaller = true;
        this.peerUUID = null;
        this.receivedPid = '';
        this.wrtcClient.terminateCall();
        this.winDom.find('.big_video_Screen').attr('src', '');
        this.winDom.find('.small_video_Screen').attr('src', '');
        Core.changeDisplayMode(this.sid, 'p2p', 'chat');
        removePageTips(this.winDom.find('.S_video').parent());
    },
    p2pVideoStarted: function(){
        Core.changeDisplayMode(this.sid, 'p2p', 'video');
        removePageTips(this.winDom.find('.S_video').parent());
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
        pageTips(curObj.winDom.find('.S_video').parent(), 'Session is establishing ...', 'info');   
    },
    onWrtcError: function(error){
        console.log(this);
        this.p2pVideoStopped();
        LWORK.msgbox.show(error, 5, 2000);
    },

    //send to Hotport
    startP2P: function(localSDP){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'video_p2p', 
            action:'invite', sdp:localSDP, peer_id:this.peerUUID.toString()}};
        hp.sendData(data);
    },
    acceptP2P: function(localSDP){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'video_p2p', 
            action:'accept', sdp:localSDP, peer_id:this.peerUUID.toString()}};
        hp.sendData(data);
    },
    endP2P: function(){
        var dt = formatDateTimeString(new Date()); 
        var data = {type:'session_message', session_id:this.sid, payload:{uuid:myID(), name:myName(), timestamp:dt, media_type:'video_p2p', 
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
            this.winDom.find('.p2pVideoTip').hide().text('');
        }
    },
    onAcceptFailure: function(reason){
        LWORK.msgbox.show('Expired video session', 5, 2000);
        this.p2pVideoStopped();
    },
    onPeerStop: function(){
        LWORK.msgbox.show('Peer has hung up', 4, 1000);
        this.p2pVideoStopped();
    },


    //on chatwin message.
    onWindowClosed: function(){
        if (this.peerUUID){
            this.end();
        }
    }
}
