
var localMedia = null;

function obtainLocalMedia(videoPara, onLocalStream, onError){
	if (localMedia){
		localMedia.referenceCount += 1;
		onLocalStream(localMedia.stream);
	}else{
	    var mediaAttr = {'audio':true, 'video': videoPara};
	    navigator.webkitGetUserMedia(mediaAttr,
			function(stream){
				localMedia = {stream:stream, referenceCount:1};
				onLocalStream(stream);
			}, 
		    function(){if (onError){onError("获取本地媒体失败");}});
	}
}

function releaseLocalMedia(){
	if (localMedia){
		if (localMedia.referenceCount == 1){
			localMedia.stream.stop();
			localMedia = null;
		}else{
			localMedia.referenceCount -= 1;
		}
	}
}

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
		var self = this;
		self.service = service;
		self.mediaParas = (service == "video" ? mediaParas : false);
		if (peerSDP){
			self.asCaller = false;
			self.peerSDP = peerSDP;
		}else{
			self.asCaller = true;
			self.peerSDP = '';
		}
		//self.obtainLocalStream();
		obtainLocalMedia(self.mediaParas, self.onGotLocalStream(), function(Er){self.owner.onWrtcError(Er);})
	};

	this.terminateCall = function(){
		if (this.pc) this.pc.close();
		this.pc = null;
		//if(this.localStream) this.localStream.stop();
		if(this.localStream) releaseLocalMedia();
		this.localStream = null;
//		this.asCaller = true;
	    this.peerSDP = '';
	};

	this.setRemoteSDP = function(sdp){
		if (this.asCaller){
		    this.pc.setRemoteDescription(new RTCSessionDescription({type:'answer',sdp:sdp}));
		}
	};

	this.onPeerCandidate = function(data) {
		if(this.pc) {
	        var candidate = new RTCIceCandidate({
	            sdpMLineIndex: data.label,
	            candidate: data.candidate
	        });
	        this.pc.addIceCandidate(candidate);
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
//		        curObj.owner.onIceCandidate(event.candidate);

		    }else {
/*		    	var sdpConstraints = (curObj.service == 'video') ? {'mandatory': {
                          'OfferToReceiveAudio':true, 
                          'OfferToReceiveVideo':true }} : null;
				if (curObj.asCaller){
				    curObj.pc.createOffer(curObj.pc_onGotLocalDescription(), null, sdpConstraints);
			    }else{
			    	curObj.pc.createAnswer(curObj.pc_onGotLocalDescription(), null, sdpConstraints);
			    }*/
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
//    		if (curObj.getOriginalVersionNo(desc.sdp) == '2'){
    			curObj.pc.setLocalDescription(desc);
//    		}else if (curObj.getOriginalVersionNo(desc.sdp) == '3'){
                curObj.owner.onLocalSDP(desc.sdp);
//    		}
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
	    	    mediaErrorTip = '获取媒体失败';
	    	    break;
	    	case 'audio':
	    	    mediaAttr = {'audio':true, 'video':false};
	    	    mediaErrorTip = '获取媒体失败' ;
	    	    break;
	    	default:
	    	    break;
	    }
        if (mediaAttr){
		    navigator.webkitGetUserMedia(mediaAttr,
				curObj.onGotLocalStream(), 
			    function(){
			    	curObj.owner.onWrtcError(mediaErrorTip);
			    });
	    }
	};

	this.initiatePeerConnection = function(){
		var curObj = this;
		var servers = null;
		//var servers = {"iceServers": [{"url": "stun:stun.l.google.com:19302"}]};
		//var servers = {"iceServers": [{"url": "stun:10.32.3.52:19303"}, {"url": "stun:202.122.107.66:19303"}]};
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