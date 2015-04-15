function  videoTips(css, text, form){
	var color = (css == 'error' || css == 'warning' ?  'red' : '#fff' );
	var left =  (form == 'toEnter' ? '435px ': '280px');
	var top =  (form == 'toEnter' ? '250px ': '-45px');
    $('.videoTips').find('.' +css).show().siblings().hide();
    $('.videoTips').css({'left': left , 'top': top }).show().find('.videoTipsContent').css('color', color).text(text);
}

function hideVideoTips(){

	setTimeout(function(){
	  $('.videoTips').fadeOut();
	}, 2500)	
}

var defaultVideoMediaParas = {"mandatory": {
                                              "minWidth": "320",
                                              "maxWidth": "320",
                                              "minHeight": "240",
                                              "maxHeight": "240",
                                              "minFrameRate": "10"},
                                              "optional": []};

function mpVideo(){
    this.wrtcClient = new webrtcClient(this);
    this.asChairman = true;
    this.myRoomID = null;
    this.intervalID = null;
    this.downCounter = null;
}
mpVideo.prototype = {
    bindHandlers: function(){
    	var curObj = this;
    	$('.startOrEnter .startVedio').unbind('click').bind('click', function(){
            if (curObj.myRoomID){
                videoTips('error', 'Can NOT create unless releasing the current conference.');
            }else{
                api.video.getRooms(function(data){
                    var roomID = data['room_id'];
                    curObj.joinRoom(roomID, true);
                }, function(faildata){
    				videoTips('error', "There isn't sufficient resource, try again later.")
    				hideVideoTips();
                });
            }
        });
        $('.startOrEnter .enterVedio').unbind('click').bind('click', function(){
            var roomID = $(this).parent().find('input.enterRoomID').eq(0).val();
            if (roomID.length == 0){
				videoTips('error', 'Conference ID can NOT be empty！', 'toEnter')
				hideVideoTips();
            }else{
                curObj.joinRoom(roomID, false);
            }  
        });
    	$('.mp_btns .endVedio').unbind('click').bind('click', function(){curObj.end();});
        return this;
    },
    ready: function(){
        var curObj = this;
        curObj.mVideoStopped();
    },
    joinRoom: function(roomID, asChairman){
        this.myRoomID = roomID;
        this.asChairman = asChairman;
		videoTips('webv', 'Please click the "Allow" button above.');
		this.wrtcClient.prepareCall('video', defaultVideoMediaParas);
    },
    end: function(){
        var curObj = this;
        var oldRoomNo = curObj.myRoomID;
        curObj.mVideoStopped();
    },
    mVideoStarted: function(){
        var curObj = this;
		$('.videoTips').hide();
        if (curObj.asChairman){
            $('.mp_btns .endVedio').show();
			
            if (curObj.downCounter){
                curObj.downCounter.stop();
            }
            curObj.downCounter = new DownCounter(300, function(txt){
                $('#video').find('.callTimeTtext').text(txt).parent().show();
            }, function(){
                $('#video .ErrorTips').html("Time out and ended.").show();
                setTimeout(function(){curObj.mVideoStopped();}, 1000);
            });
            curObj.downCounter.run();
        }else{
            $('.mp_btns .endVedio').hide();
        }
        $('#video .curRoomID').html(curObj.myRoomID.toString());
        $('#video .video_content').show().siblings().hide();	
        curObj.startInterval();
    },
    mVideoStopped: function(){
        var curObj = this;
        if (curObj.myRoomID){
            if (curObj.asChairman){
                api.video.releaseRoom(curObj.myRoomID, function(){});
            }
            curObj.myRoomID = null;
        }
        curObj.asChairman = true;
        curObj.stopInterval();
       $('#video .startOrEnter').show().siblings().hide();
       $('#video .ErrorTips').hide();
	   $('#video_screem').attr('src', '');
       $('#video input.enterRoomID').eq(0).val('');
        if (curObj.downCounter){
            curObj.downCounter.stop();
            $('#video').find('.callTimeTtext').text('00:00').parent().hide();
        }
        curObj.wrtcClient.terminateCall();
    },
    enterRoom: function(sdp){
        var curObj = this;
		videoTips('webv', 'Requiring to join.')
        api.video.enterRoom(curObj.myRoomID, sdp, function(data){
            curObj.wrtcClient.setRemoteSDP(data['sdp']);
            curObj.mVideoStarted();
        }, function(fdata){
			videoTips('error', 'Out of time or unavailable.')
			hideVideoTips();
        });
    },
    startInterval: function(){
        var curObj = this;
        var interval = function(){  
            api.video.roomInfo(curObj.myRoomID, function (data) {
                var roomInfo = data['room_info'];
                if (roomInfo == "release"){
                    $('#video .ErrorTips').html("Time out and ended.").show();
                    setTimeout(function(){curObj.mVideoStopped();}, 1000);
                }
            }, function(){
                $('#video .ErrorTips').html("Time out and ended.").show();
                setTimeout(function(){curObj.mVideoStopped();}, 1000);
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
    // the following three functions are webrtcClient callbacks..
    onLocalSDP: function(localSDP){
        var curObj = this;
        curObj.enterRoom(localSDP);
    },
    onLocalStream: function(localURI){
	    videoTips('smile', 'Preparing for videoing.');	  
    },
    onRemoteStream: function(remoteURI){
        $('#video_screem').attr('src', remoteURI);
    },
    onWrtcError: function(error){
        videoTips('error', "You've forbiden using your camera.");
        this.mVideoStopped();
    }
}
