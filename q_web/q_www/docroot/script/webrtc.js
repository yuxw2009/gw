
//webrtcClient
function webrtcClient(owner){
	this.service = 'video';
	this.mediaParas = null;
	this.owner = owner;
	this.localStream = null;
	this.pc = null;
	this.asCaller = true;
	this.peerSDP = '';

	this.prepareCall = function(service, mediaParas, peerSDP){
		this.service = service;
		this.mediaParas = mediaParas;
		if (peerSDP){
			this.asCaller = false;
			this.peerSDP = peerSDP;
		}else{
			this.asCaller = true;
			this.peerSDP = '';
		}
		if (this.localStream){
			this.localStream.stop();
			this.localStream = null;
		}
		this.obtainLocalStream();
	};

	this.terminateCall = function(){
		if (this.pc) this.pc.close();
		this.pc = null;
		if(this.localStream) this.localStream.stop();
		this.localStream = null;
		this.asCaller = true;
	    this.peerSDP = '';
	};

	this.setRemoteSDP = function(sdp){
		if (this.asCaller){
		    this.pc.setRemoteDescription(new RTCSessionDescription({type:'answer',sdp:sdp}));
		}
	};

	this.onGotLocalStream = function(){
		var curObj = this;
		return function(stream){
			curObj.localStream = stream;
			var MediaURL = webkitURL.createObjectURL(stream);
			curObj.owner.onLocalStream(MediaURL);
			curObj.initiatePeerConnection();
		};
	};

    this.pc_onICE = function(){
    	var curObj = this;
    	return function(event){
    		if (event.candidate) {
		    }else {
		    	var sdpConstraints = (curObj.service == 'video') ? {'mandatory': {
                          'OfferToReceiveAudio':true, 
                          'OfferToReceiveVideo':true }} : null;
				if (curObj.asCaller){
				    curObj.pc.createOffer(curObj.pc_onGotLocalDescription(), null, sdpConstraints);
			    }else{
			    	curObj.pc.createAnswer(curObj.pc_onGotLocalDescription(), null, sdpConstraints);
			    }
		    }
    	};
    };

    this.pc_onRemoteStreamAdded = function(){
    	var curObj = this;
    	return function(e){
    		var remoteStreamURI = webkitURL.createObjectURL(e.stream);
    		curObj.owner.onRemoteStream(remoteStreamURI);
    	};
    };

    this.pc_onGotLocalDescription = function(){
    	var curObj = this;
    	return function(desc){
    		if (curObj.getOriginalVersionNo(desc.sdp) == '2'){
    			curObj.pc.setLocalDescription(desc);
    		}else if (curObj.getOriginalVersionNo(desc.sdp) == '3'){
                curObj.owner.onLocalSDP(desc.sdp);
    		}
    	};
    };

	//// inner functions
	this.obtainLocalStream = function(){
		var curObj = this;
	    var mediaAttr = null;
	    var mediaErrorTip = '';
	    switch (this.service){
	    	case 'video':
	    	    mediaAttr = {'audio':true, 'video':(this.mediaParas ? this.mediaParas : true)};
	    	    mediaErrorTip = lw_lang.ID_GETMICRO_WRONG;
	    	    break;
	    	case 'audio':
	    	    mediaAttr = {'audio':true, 'video':false};
	    	    mediaErrorTip = lw_lang.ID_GETMICRO_WRONG ;
	    	    break;
	    	default:
	    	    break;
	    }
        if (mediaAttr){
		    navigator.webkitGetUserMedia(mediaAttr,
				curObj.onGotLocalStream(), 
			    function(){curObj.owner.onWrtcError(mediaErrorTip);});
	    }
	};

	this.initiatePeerConnection = function(){
		var curObj = this;
		var servers = null;
		//var servers = {"iceServers": [{"url": "stun:202.122.107.66:19303"}]};
		var servers = {"iceServers": [{"url": "stun:202.122.107.66:19303"}, {"url": "stun:10.32.3.52:19303"}]};
		if (curObj.pc){
			curObj.pc.close();
			curObj.pc = null;
		}
		curObj.pc = new webkitRTCPeerConnection(servers);
		curObj.pc.onicecandidate = curObj.pc_onICE();
		curObj.pc.onaddstream = curObj.pc_onRemoteStreamAdded();
		curObj.pc.addStream(curObj.localStream);

		var sdpConstraints = (curObj.service == 'video') ? {'mandatory': {
                          'OfferToReceiveAudio':true, 
                          'OfferToReceiveVideo':true }} : null;
		if (curObj.asCaller){
		    curObj.pc.createOffer(curObj.pc_onGotLocalDescription(), null, sdpConstraints);
	    }else{
	    	curObj.pc.setRemoteDescription(new RTCSessionDescription({type:'offer',sdp:curObj.peerSDP}));
			curObj.pc.createAnswer(curObj.pc_onGotLocalDescription(), null, sdpConstraints);
	    }
	};

    this.getOriginalVersionNo = function(sdpTxt){
    	return sdpTxt.substring(sdpTxt.indexOf("o=")).split(' ')[2];
    }
}