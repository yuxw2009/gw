var defaultVideoMediaParas = {"mandatory": {
                                              "minWidth": "320",
                                              "maxWidth": "320",
                                              "minHeight": "240",
                                              "maxHeight": "240",
                                              "minFrameRate": "10"},
                                              "optional": []};

function isUserOnline(aUUID){
    return subscriptArray[aUUID]>=0 && employer_status[subscriptArray[aUUID]] && (employer_status[subscriptArray[aUUID]].status == 'online');
}

function mpVideo(){
    this.wrtcClient = new webrtcClient(this);
    this.asChairman = true;
    this.myRoomNo = null;
    this.mySeatNo = 0;
    this.intervalID = null;
}
mpVideo.prototype = {
    bindHandlers: function(){
    	var curObj = this;
    	$('.mp_btns .startVedio').unbind('click').bind('click', function(){curObj.start();});
    	$('.mp_btns .endVedio').unbind('click').bind('click', function(){curObj.end();});
        $('.mp_btns .leaveVedio').unbind('click').bind('click', function(){curObj.leave();});
        $('.del_vmember').unbind('click').bind('click', function(){
            curObj.resetSeat($(this).parent().parent());
        });
    },
    ready: function(){
        var curObj = this;
        curObj.mVideoStopped();
        curObj.queryOngoingVideo();
    },
    queryOngoingVideo: function(){
        var curObj = this;
        function confirmIfReenter(chairman, room, position){
            function reenterVideo(){
                $('.tab_item').find('.video').find('a').click();
                $('.video_mode_selections').find('.mp_video').click();
                api.video.leaveMP(uuid, room, function(){
                    curObj.joinConf(chairman, room, position);
                });
            }
            var invatorName = employer_status[subscriptArray[chairman.toString()]].name;
            artDiaglogConfirm(lw_lang.ID_VIDEO_TIP + invatorName,
                    lw_lang.ID_VIDEO_CONNECTIP,
                    "received_video_invitation", 
                    {'name':lw_lang.ID_VIDEO_RECONNECT, 'cb':function(){reenterVideo();}}, 
                    {'name':lw_lang.ID_CANCEL, 'cb':function(){}}
                );   
        }
        
        api.video.get_my_ongoing(uuid, function(data){
            if (data['room'] && data['room'].length > 0){
                confirmIfReenter(data['chairman'], data['room'], data['position']);
            }
        });
    },
    addPeer: function(aUUID){
        var curObj = this;
        if (curObj.asChairman){
            if (curObj.isUserInPresence(aUUID)){
                LWORK.msgbox.show(lw_lang.ID_VIDEO_USER , 1, 2000);
                return false;
            }
            if (!isUserOnline(aUUID)){
                LWORK.msgbox.show(lw_lang.ID_VIDEO_OFFLINE , 1, 2000);
                return false;
            }
            var seatNo = curObj.assignSeat(aUUID);
            if (seatNo < 0){
                LWORK.msgbox.show(lw_lang.ID_VIDEO_ROOM, 1, 2000);
                return false;
            }
            if (curObj.myRoomNo){
                curObj.add2OngoingMVideo(aUUID, seatNo);
            }
        }else{
            LWORK.msgbox.show(lw_lang.ID_VIDEO_Moder, 1, 2000);
        }
        return true;
    },
    handleInvitation: function(dataDom){
        var curObj = this;
        var from = dataDom.attr('from'), room = dataDom.attr('room'), position = dataDom.attr('position');
        var obj = $('.dynamic').find('.video');
        var invatorName = employer_status[subscriptArray[from.toString()]].name;

        function acceptedVideo(){
            $('.tab_item').find('.video').find('a').click();
            $('.video_mode_selections').find('.mp_video').click();
            curObj.joinConf(from, room, position);
        }

        if (!mpVideo.myRoomNo){
            acceptedVideo();
        }else{
            artDiaglogConfirm(lw_lang.ID_VIDEO_INVITED1 + invatorName + lw_lang.ID_VIDEO_INVITED4, 
                mpVideo.asChairman ? lw_lang.ID_VIDEO_INVITED2 : lw_lang.ID_VIDEO_INVITED3,
                "received_video_invitation", 
                {'name':lw_lang.ID_VIDEO_ALLOW, 'cb':function(){acceptedVideo();}}, 
                {'name':lw_lang.ID_VIDEO_DENY, 'cb':function(){}}
            );
        }
    },
    joinConf: function(chairman, roomNo, seatNo){
        var curObj = this;
        if (curObj.myRoomNo){
            if (curObj.asChairman){
                api.video.endMP(uuid, curObj.myRoomNo, function(){
                    curObj.stopInterval();
                });  
            }else{
                api.video.leaveMP(uuid, curObj.myRoomNo, function(){
                    curObj.stopInterval();
                });
            }
        }
        curObj.asChairman = (uuid == chairman) ? true : false;
        curObj.myRoomNo = roomNo;
        curObj.mySeatNo = seatNo;
        $('.chairman_opt').hide();
        $('.add_mvideo_member').hide();
        curObj.wrtcClient.prepareCall('video', defaultVideoMediaParas);
    },
    start: function(){
        ajaxErrorTips('video' , lw_lang.ID_WRONG_VOIP , 'weibv');
        this.wrtcClient.prepareCall('video', defaultVideoMediaParas);
    },
    end: function(){
        var curObj = this;
        var oldRoomNo = curObj.myRoomNo;
        curObj.mVideoStopped();
        api.video.endMP(uuid, oldRoomNo, function(){
            LWORK.msgbox.show(lw_lang.ID_VIDEO_END , 4, 1000);
        });  
    },
    leave: function(){
        var curObj = this;
        var oldRoomNo = curObj.myRoomNo;
        curObj.mVideoStopped();
        api.video.leaveMP(uuid, oldRoomNo, function(){
            LWORK.msgbox.show(lw_lang.ID_VIDEO_EXIT , 4, 1000);
        }); 
    },
    add2OngoingMVideo: function(aUUID, seatNo){
        var curObj = this;
        var user = employer_status[subscriptArray[aUUID]];

        function sendInvitation(){
            api.video.invite(uuid, aUUID, seatNo, curObj.myRoomNo, function(){
                LWORK.msgbox.show(lw_lang.ID_INVITATION, 4, 1000);
            });
        }
        artDiaglogConfirm(lw_lang.ID_VIDEO_CONFIRM, 
            lw_lang.ID_VIDEO_ALLOWINVITE + user.name+ lw_lang.ID_VIDEO_JOIN, 
            "to_confirm_invite_video_member", 
            {'name':lw_lang.ID_OK, 'cb':function(){sendInvitation();}}, 
            {'name':lw_lang.ID_CANCEL, 'cb':function(){curObj.resetSeat($('#seat'+seatNo));}});
    },
    isUserInPresence: function(aUUID){
        var rslt = false
        var allSeats = $('#video_grade').find('.seat').each(function(){
            if ($(this).attr('mUUID') == aUUID){
                rslt = true;
            }
        });
        return rslt;
    },
    assignSeat: function(aUUID){
        var curObj = this;
        var allSeats = $('#video_grade').find('.seat');
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
        var seatDom = $('#seat' + seatNo);
        var stObj = seatDom.find('.vmember_status');
        var optObj = seatDom.find('.chairman_opt');
        var user = employer_status[subscriptArray[aUUID]];        
        seatDom.attr('mUUID', aUUID);
        seatDom.find('.vmember_name').text(user.name_employid);
        switch (status){
            case 'invited':
                if (aUUID == uuid){
                    stObj.text('');
                    optObj.children().hide();
                }else{
                    stObj.text(lw_lang.ID_VIDEO_WAIT);
                    optObj.find('.del_vmember').show().siblings().hide(); 
                }
                seatDom.removeClass("free invited occupy busy").addClass("invited");                
                break;
            case 'occupy':
                stObj.text(lw_lang.ID_VIDEO_WAIT);
                optObj.children().hide(); 
                seatDom.removeClass("free invited occupy busy").addClass("occupy"); 
                break;
            case 'busy':
                stObj.text('');
                if (curObj.asChairman && (seatDom.attr('mUUID') != uuid)){
                    //optObj.find('.hkon_vmember').show().siblings().hide();
                    optObj.children().hide();
                }else{
                    optObj.children().hide();
                }
                seatDom.removeClass("free invited occupy busy").addClass("busy"); 
                break;
        }
    },
    resetSeat: function(seatObj){
        seatObj.attr('mUUID', 'none');
        seatObj.find('.vmember_name').text(lw_lang.ID_VIDEO_FREE);
        seatObj.find('.vmember_status').text('');
        seatObj.find('.chairman_opt').show();
        seatObj.find('.chairman_opt').children().hide();
        seatObj.removeClass("free invited occupy busy").addClass("free");
    },
    collectMembers: function(){
        var curObj = this;
        var allSeats = $('#video_grade').find('.seat');
        var rslt = new Array();
        for (var i = 0; i < allSeats.length; i++){
            if (allSeats.eq(i).attr('mUUID') != 'none'){
                rslt.push({'uuid':allSeats.eq(i).attr('mUUID'), 'position':i.toString()});
            }
        }
        return rslt;
    },
    videoStatusTip:function(type, text){
        $('.videoTips').addClass(type).show().text(text);
    },
    doStart: function(sdp){
        var curObj = this;
        var members = curObj.collectMembers();
        api.video.startMP(uuid, sdp, members, function(data){
                curObj.myRoomNo = data['room'];
                curObj.wrtcClient.setRemoteSDP(data['sdp']);
                curObj.mVideoStarted();
            }, function(fdata){
                  ajaxErrorTips('video' , fdata , 'error');
                  setTimeout(function(){
                    curObj.mVideoStopped();
                    curObj.wrtcClient.terminateCall();
                 }, 3000)
            });
    },
    mVideoStarted: function(){
        var curObj = this;
        if (curObj.asChairman){
            $('.mp_btns .endVedio').show().siblings().hide();
        }else{
            $('.mp_btns .leaveVedio').show().siblings().hide();
        }
        HideajaxErrorTips('video');
        curObj.startInterval();
    },
    mVideoStopped: function(){
        var curObj = this;
        curObj.asChairman = true;
        curObj.myRoomNo = null;
        curObj.stopInterval();
        $('#video_grade').find('.seat').each(function(){
            curObj.resetSeat($(this));
        });
        curObj.mySeatNo = curObj.assignSeat(uuid);
        $('.mp_btns .startVedio').show().siblings().hide();
        $('.chairman_opt').show();
        $('.add_mvideo_member').show();
		$('#video_screem_html5_api').attr('src', '');
		$('.vjs-current-time-display').text('0:00');
        $('.videoTips').hide();
        curObj.wrtcClient.terminateCall();
    },
    enterConf: function(sdp){
        var curObj = this;
        var members = curObj.collectMembers();
        api.video.enterMP(uuid, sdp, curObj.myRoomNo, curObj.mySeatNo.toString(), function(data){
            curObj.wrtcClient.setRemoteSDP(data['sdp']);
            curObj.mVideoStarted();
        }, function(fdata){
            LWORK.msgbox.show(lw_lang.ID_ENTER_FAILED, 5, 2000);
            curObj.mVideoStopped();
            curObj.wrtcClient.terminateCall();
        });
    },
    startInterval: function(){
        var curObj = this;
        var interval = function(){  
            api.video.get_roomInfo(uuid, curObj.myRoomNo, function (data) {
                var roomInfo = data['room_info'];
                if (!roomInfo || roomInfo.length == 0 || !curObj.myRoomNo){
                    LWORK.msgbox.show(lw_lang.ID_VIDEO_END, 4, 2000);
                    curObj.mVideoStopped();
                    return;
                }
                var emptySeats = [0, 1, 2, 3];
                for (var i = 0; i < roomInfo.length; i++) {
                    var uuid = roomInfo[i]['uuid'];
                    var status = roomInfo[i]['status'];
                    delete emptySeats[parseInt(roomInfo[i]['position'])];
                    curObj.updateMemberStatus(roomInfo[i]['position'], roomInfo[i]['uuid'], roomInfo[i]['status']);
                }
                for (j in emptySeats){
                    curObj.resetSeat($('#seat'+emptySeats[j].toString()));
                }
            }, function(){
                LWORK.msgbox.show(lw_lang.ID_SERVICE_UNAVAILABLE, 5, 2000);
                curObj.mVideoStopped();
            }); 
        }
        interval();
        curObj.intervalID = setInterval(interval , 8000);
    },
    stopInterval: function(){
        var curObj = this;
        if (curObj.intervalID){
            clearInterval(curObj.intervalID);
            curObj.intervalID = null;
        }
    },
    // the following three functions are webrtcClient callbacks..
    onLocalSDP: function(localSDP){
        var curObj = this;
        if (curObj.asChairman && !curObj.myRoomNo){
            curObj.doStart(localSDP);
        }else{
            curObj.enterConf(localSDP);
        }
        ajaxErrorTips('video' , lw_lang.ID_CONNECTING , 'weibv');
    },
    onLocalStream: function(localURI){
          ajaxErrorTips('video' , lw_lang.ID_PREPAR_CALL , 'weibv');
    },
    onRemoteStream: function(remoteURI){
        $('#video_screem_html5_api').attr('src', remoteURI);
    },
    onWrtcError: function(error){
        LWORK.msgbox.show(error, 5, 2000);
    }
}

function p2pVideo(){
    this.wrtcClient = new webrtcClient(this);
    this.asCaller = true;
    this.peerUUID = null;
    this.receivedPid = '';
};
p2pVideo.prototype = {
    bindHandlers: function(){
        var curObj = this;
        $('.p2p_btns .startVedio').unbind('click').bind('click', function(){curObj.start();});
        $('.p2p_btns .endVedio').unbind('click').bind('click', function(){curObj.end();});
    },
    ready: function(){
        this.p2pVideoStopped();
    },
    peerHookon: function(){
        if (!$('#p2p_main_screen').hasClass('free')){
            LWORK.msgbox.show(lw_lang.ID_P2PVIDEO_PEER_HOOKON, 4, 1000);
            this.p2pVideoStopped();
        } 
    },
    start: function(){
        if (this.peerUUID){
            this.asCaller = true;
            $('.p2p_btns .video_time').children().hide();
            this.updateStatus($('#p2p_slave_screen'), 'connecting');
            this.wrtcClient.prepareCall('video', defaultVideoMediaParas);
        }else{
            LWORK.msgbox.show(lw_lang.ID_P2PVIDEO_ADD_PEER_FIRST, 3, 2000);
        }
    },
    end: function(){
        var curObj = this;
        api.video.endP2P(uuid, curObj.peerUUID, function(data){
                LWORK.msgbox.show(lw_lang.ID_P2PVIDEO_OVER, 4, 1000);
                curObj.p2pVideoStopped();
            });
    },
    handleInvitation: function(dataDom){
        var curObj = this;
        var from = dataDom.attr('from'), sdp = dataDom.attr('sdp'), rpid = dataDom.attr('rpid');
        var obj = $('.dynamic').find('.video');
        var invatorName = employer_status[subscriptArray[from.toString()]].name;

        function acceptedVideo(){
            $('.tab_item').find('.video').find('a').click();
            $('.video_mode_selections').find('.p2p_video').click();
            curObj.accepetInvitation(from, sdp, rpid);
        }

        if ($('#p2p_main_screen').hasClass('free')){
            acceptedVideo();
        }else{
            artDiaglogConfirm(lw_lang.ID_VIDEO_INVITED5 + invatorName + lw_lang.ID_VIDEO_INVITED6, 
                lw_lang.ID_VIDEO_INVITED7,
                "received_video_invitation", 
                {'name':lw_lang.ID_VIDEO_ALLOW, 'cb':function(){acceptedVideo();}}, 
                {'name':lw_lang.ID_VIDEO_DENY, 'cb':function(){}}
            );
        }
    },
    accepetInvitation: function(peerUUID, peerSDP, receivedPid){
        var curObj = this;
        if (!$('#p2p_main_screen').hasClass('free')){
            api.video.endP2P(uuid, curObj.peerUUID, function(){});
            curObj.p2pVideoStopped();
        }
        curObj.asCaller = false;
        curObj.peerUUID = peerUUID;
        curObj.receivedPid = receivedPid;
        var user = employer_status[subscriptArray[peerUUID]];
        $('.peer_info').text(user.name_employid);
        $('.p2p_btns .video_time').children().hide();
        curObj.updateStatus($('#p2p_slave_screen'), 'connecting');
        curObj.wrtcClient.prepareCall('video', defaultVideoMediaParas, peerSDP);
    },
    addPeer: function(peerUUID){
        if (!$('#p2p_main_screen').hasClass('free')){
            LWORK.msgbox.show(lw_lang.ID_P2PVIDEO_TOO_MANY_PEERS, 1, 2000);
        }else if (!isUserOnline(peerUUID)){
            LWORK.msgbox.show(lw_lang.ID_VIDEO_OFFLINE , 1, 2000);
        }else{
            var user = employer_status[subscriptArray[peerUUID]];
            $('.peer_info').text(user.name_employid);
            this.peerUUID = peerUUID;
        }
    },
    doStart: function(localSDP){
        var curObj = this;
        curObj.updateStatus($('#p2p_main_screen'), 'connecting');
        var timerID = setTimeout(curObj.onPeerNoAnswer(), 60000);

        api.video.startP2P(uuid, localSDP, curObj.peerUUID, function(data){
            clearTimeout(timerID);
            curObj.wrtcClient.setRemoteSDP(data["peer_sdp"]);
            curObj.p2pVideoStarted();
        }, function(faildata){
            clearTimeout(timerID);
            LWORK.msgbox.show(lw_lang.ID_P2PVIDEO_FAILED, 5, 2000);
            curObj.p2pVideoStopped();
        });
    },
    doAnswer: function(localSDP){
        var curObj = this;
        curObj.updateStatus($('#p2p_main_screen'), 'connecting');

        api.video.acceptP2P(uuid, localSDP, curObj.peerUUID, curObj.receivedPid, function(data){
            curObj.p2pVideoStarted();
        }, function(faildata){
            LWORK.msgbox.show(lw_lang.ID_P2PVIDEO_ANSWER_FAILED, 5, 2000);
            curObj.p2pVideoStopped();
        });
    },
    onPeerNoAnswer: function(){
        var curObj = this;
        return function(){
            LWORK.msgbox.show(lw_lang.ID_P2PVIDEO_PEER_REJECTED, 5, 2000);
            curObj.p2pVideoStopped();
        };
    },
    p2pVideoStopped: function(){
        this.asCaller = true;
        this.peerUUID = null;
        this.receivedPid = '';
        this.wrtcClient.terminateCall();
        $('.p2p_btns .startVedio').show().siblings().hide();
        this.updateStatus($('#p2p_main_screen'), 'free');
        this.updateStatus($('#p2p_slave_screen'), 'free');
        $('#p2p_main_screen').attr('src', '');
        $('#p2p_slave_screen').attr('src', '');
        $('.peer_info').text('');
    },
    p2pVideoStarted: function(){
        this.updateStatus($('#p2p_main_screen'), 'busy');
        $('.p2p_btns .endVedio').show().siblings().hide();
    },
    updateStatus: function(Obj, status){
        Obj.removeClass('free connecting busy').addClass(status);
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
    onLocalStream: function(localURI){
        var curObj = this;
        curObj.updateStatus($('#p2p_slave_screen'), 'busy');
        $('#p2p_slave_screen').attr('src', localURI);
    },
    onRemoteStream: function(remoteURI){
        this.updateStatus($('#p2p_main_screen'), 'busy');
        $('#p2p_main_screen').attr('src', remoteURI);
    },
    onWrtcError: function(error){
        LWORK.msgbox.show(error, 5, 2000);
        this.p2pVideoStopped();
    }
}

function webVideo(){
    this.curMode = 'p2p';
    this.videoHandlers = {'p2p': new p2pVideo(), 'mp': new mpVideo()}
}
webVideo.prototype = {
    bindHandlers: function(){
        var curObj = this;
        $('.video_mode').unbind('click').bind('click', function(){
            if (!$(this).hasClass('curent')){
                //only for inner network
                //if (window.location.href.indexOf('http://10.') != -1){
                    $('.video_mode_selections').find('.curent').removeClass('curent');
                    $(this).addClass('curent');
                    var vMode = $(this).attr('v_mode');
                    $('.video_bar').find('.'+vMode + '_btns').show().siblings().hide();
                    $('.video_box').find('.'+vMode + '_icon').show().siblings().hide();
                    curObj.curMode = vMode;
                //}else{
                //    alert("目前由于服务器部署的原因，多方视频暂不对公网用户提供！");
                //}
            }
            return false;
        });
        curObj.videoHandlers['p2p'].bindHandlers();
        curObj.videoHandlers['mp'].bindHandlers();
    },
    ready: function(){
        this.videoHandlers['p2p'].ready();
        this.videoHandlers['mp'].ready();
    },
    addPeer: function(peerUUID){
        this.videoHandlers[this.curMode].addPeer(peerUUID);
    },
    onVideoNotice: function(data){
        var obj = $('.dynamic').find('.video');
        var oldnum = parseInt(obj.find('.new_num').text());
        switch (data[0]){
            case 'mp':
                obj.find('.new_num').text(oldnum + 1);
                var from = data[1], room = data[2], position=data[3];
                var i = subscriptArray[from.toString()];
                var name = employer_status[i].name;
                ManageSoundControl('play', 3);
                obj.find('.mp_vedio_notice').attr('from', from).attr('room', room).attr('position', position).text(name + lw_lang.ID_VIDEO_INVITE);
                obj.find('.mp_vedio_notice').show();
                showNotification("/images/note.png", lw_lang.ID_MESS_ATT, lw_lang.ID_ON_LWORK + name + lw_lang.ID_VIDEO_INVITE);
                obj.show(); 
                break;
            case 'p2p':
                obj.find('.new_num').text(oldnum + 1);
                var from = data[1], sdp = data[2], rpid=data[3];
                var i = subscriptArray[from.toString()];
                var name = employer_status[i].name;
                ManageSoundControl('play', 3);
                obj.find('.p2p_vedio_notice').attr('from', from).attr('sdp', sdp).attr('rpid', rpid).text(name + lw_lang.ID_VIDEO_P2PINVITE);
                obj.find('.p2p_vedio_notice').show();
                showNotification("/images/note.png", lw_lang.ID_MESS_ATT, lw_lang.ID_ON_LWORK + name + lw_lang.ID_VIDEO_P2PINVITE);
                obj.show(); 
                break;
            case 'p2p_stop':
                var newnum = (oldnum > 1 ? oldnum - 1 : 0);
                obj.find('.new_num').text(newnum);
                ManageSoundControl('stop');
                obj.find('.p2p_vedio_notice').attr('from', '').attr('sdp', '').attr('rpid', '').text('');
                obj.find('.p2p_vedio_notice').hide();
                if (newnum == 0){obj.hide();}
                this.videoHandlers['p2p'].peerHookon();
                break;  
        }
        
    },
    handleVideoInvitation: function(dataDom){
        var vmode=dataDom.attr('vmode');
        var obj = $('.dynamic').find('.video');
        var msgnum = parseInt($('.dynamic').find('.video').find('a').text());
        this.videoHandlers[vmode].handleInvitation(dataDom);
        msgnum = msgnum > 1 ? msgnum - 1 : 0;
        obj.find('a').text(msgnum);
        obj.find('.'+ vmode +'_vedio_notice').hide();
        if (msgnum == 0){obj.hide();}
    }
}