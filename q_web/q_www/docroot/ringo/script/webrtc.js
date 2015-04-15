;(function () {
// normalize environment
var RTCPeerConnection = null,
    getUserMedia = null,
    attachMediaStream = null,
    reattachMediaStream = null,
    browser = null,
    webRTCSupport = true;

if (navigator.mozGetUserMedia) {
    browser = "firefox";

    // The RTCPeerConnection object.
    RTCPeerConnection = mozRTCPeerConnection;

    // The RTCSessionDescription object.
    RTCSessionDescription = mozRTCSessionDescription;

    // The RTCIceCandidate object.
    RTCIceCandidate = mozRTCIceCandidate;

    // Get UserMedia (only difference is the prefix).
    // Code from Adam Barth.
    getUserMedia = navigator.mozGetUserMedia.bind(navigator);

    // Attach a media stream to an element.
    attachMediaStream = function(element, stream) {
        element.mozSrcObject = stream;
        element.play();
    };
    dettachMediaStream = function(element){
    	element.mozSrcObject = null;
    }

    // Fake get{Video,Audio}Tracks
    MediaStream.prototype.getVideoTracks = function() {
        return [];
    };

    MediaStream.prototype.getAudioTracks = function() {
        return [];
    };
} else if (navigator.webkitGetUserMedia) {
    browser = "chrome";

    // The RTCPeerConnection object.
    RTCPeerConnection = webkitRTCPeerConnection;

    // Get UserMedia (only difference is the prefix).
    // Code from Adam Barth.
    getUserMedia = navigator.webkitGetUserMedia.bind(navigator);

    // Attach a media stream to an element.
    attachMediaStream = function(element, stream) {
        element.autoplay = true;
        element.src = webkitURL.createObjectURL(stream);
    };
    dettachMediaStream = function(element){
    	element.src = "";
    }

    // The representation of tracks in a stream is changed in M26.
    // Unify them for earlier Chrome versions in the coexisting period.
    if (!webkitMediaStream.prototype.getVideoTracks) {
        webkitMediaStream.prototype.getVideoTracks = function() {
            return this.videoTracks;
        };
        webkitMediaStream.prototype.getAudioTracks = function() {
            return this.audioTracks;
        };
    }

    // New syntax of getXXXStreams method in M26.
    if (!webkitRTCPeerConnection.prototype.getLocalStreams) {
        webkitRTCPeerConnection.prototype.getLocalStreams = function() {
            return this.localStreams;
        };
        webkitRTCPeerConnection.prototype.getRemoteStreams = function() {
            return this.remoteStreams;
        };
    }
} else {
    webRTCSupport = false;
    throw new Error("Browser does not appear to be WebRTC-capable");
}

var localMedia = null;

function obtainLocalMedia(av, videoPara, onLocalStream, onError){
	if (localMedia){
		localMedia.referenceCount += 1;
		onLocalStream(localMedia.stream);
	}else{
	    var mediaAttr = {'audio':true, 'video': videoPara};
	    getUserMedia(mediaAttr,
			function(stream){
				localMedia = {stream:stream, referenceCount:1};
				onLocalStream(stream);
			}, 
		    function(){if (onError){onError("获取本地媒体失败");}});
	}
}

function releaseLocalMedia(av){
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
function webrtcClient(owner, remoteEle, localEle){
	this.service = 'video';
	this.mediaParas = null;
	this.owner = owner;
	this.remotePlayer = remoteEle;
	this.localPlayer = localEle;
	this.localStream = null;
	this.pc = null;
	this.asCaller = true;
	this.peerSDP = '';
	this.isICEing = false;

	this.prepareCall = function(service, mediaParas, peerSDP){
		var self = this;
		self.service = service;
		self.mediaParas = mediaParas;
		if (peerSDP){
			self.asCaller = false;
			self.peerSDP = peerSDP;
		}else{
			self.asCaller = true;
			self.peerSDP = '';
		}
		//self.obtainLocalStream();
		obtainLocalMedia(service, mediaParas, self.onGotLocalStream(), function(Er){self.owner.onWrtcError(Er);})
	};

	this.terminateCall = function(){
		if (this.pc) this.pc.close();
		this.pc = null;
		//if(this.localStream) this.localStream.stop();
		if(this.localStream){releaseLocalMedia(this.service);}
		this.localStream = null;
		if (this.localPlayer){dettachMediaStream(this.localPlayer);}
		this.asCaller = true;
	    this.peerSDP = '';
	    this.isICEing = false;
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
			//var MediaURL = webkitURL.createObjectURL(stream);
			//curObj.owner.onLocalStream(MediaURL);
			curObj.owner.onLocalStream();
			if (curObj.localPlayer){attachMediaStream(curObj.localPlayer, stream);}
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
    		//var remoteStreamURI = webkitURL.createObjectURL(e.stream);
    		//curObj.owner.onRemoteStream(remoteStreamURI);
    		window.remotestream1 ?  window.remotestream2 = e.stream : window.remotestream1 = e.stream;
    		if (curObj.remotePlayer){attachMediaStream(curObj.remotePlayer, e.stream);}
    	};
    };

    this.pc_onGotLocalDescription = function(){
    	var curObj = this;
    	return function(desc){
    		if (browser == "chrome"){
	    		if (curObj.getOriginalVersionNo(desc.sdp) == '2'){
	    			curObj.pc.setLocalDescription(desc);
	    		}else if (curObj.getOriginalVersionNo(desc.sdp) == '3'){
	    			if (curObj.isICEing){
		                curObj.owner.onLocalSDP(desc.sdp);
		                curObj.isICEing = false;
		            }
	    		}
	    	}else{
	    		if (curObj.isICEing){
	                curObj.pc.setLocalDescription(desc);
	    		    curObj.owner.onLocalSDP(desc.sdp);
	                curObj.isICEing = false;
	            }
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
		    getUserMedia(mediaAttr,
				curObj.onGotLocalStream(), 
			    function(){
			    	curObj.owner.onWrtcError(mediaErrorTip);
			    });
	    }
	};

	this.initiatePeerConnection = function(){
		var curObj = this;
		var servers = null;
		//var servers = {"iceServers": [{"url": "stun:202.122.107.66:19303"}]};
		//var servers = {"iceServers": [{"url": "stun:10.61.34.53:19303"}]};
		var contraints = {optional: [{"DtlsSrtpKeyAgreement": true}]};
		if (curObj.pc){
			curObj.pc.close();
			curObj.pc = null;
		}
		curObj.pc = new RTCPeerConnection(servers, contraints);
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
	    curObj.isICEing = true;
	};

    this.getOriginalVersionNo = function(sdpTxt){
    	return sdpTxt.substring(sdpTxt.indexOf("o=")).split(' ')[2];
    }
}

window.webrtcClient = webrtcClient;

}());