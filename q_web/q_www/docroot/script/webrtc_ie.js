;(function () {
// normalize environment
WebRtc4all_Init();
var RTCPeerConnection = null,
    getUserMedia = null,
//    attachMediaStream = null,
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
//    webRTCSupport = false;
//    throw new Error("Browser does not appear to be WebRTC-capable");
}

function getMedia(mediaParas) {
	if(!mediaParas||!mediaParas.video){
		return localAudioMedia;
	}else if(mediaParas.video.mandatory.chromeMediaSource=="screen") {
		return localScrMedia;
	}else{
		return localVideoMedia;
	}
}

function obtainLocalMedia(mediaParas, onLocalStream, onError){
	var localMedia = getMedia(mediaParas);
	localMedia.obtain(mediaParas,onLocalStream,onError);
}

function releaseLocalMedia(mediaParas){
	var localMedia = getMedia(mediaParas);
	localMedia.release();
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
	var oSdpLocal=0, oSdpRemote=0;

	this.prepareCall = function(service, mediaParas, peerSDP){
//		lw_log("webrtcClient.prepareCall",service,mediaParas,peerSDP);
		var self = this;
		self.service = service;
		self.mediaParas = mediaParas||{audio:true,video:null};
        this.oPeerConnection = new w4aPeerConnection("",
		        function (o_candidate, b_moreToFollow) {
		            if (o_candidate) {
		                console.log();
		                oSdpLocal.addCandidate(o_candidate);
		            }
		            if (!b_moreToFollow) {
		                // No more ICE candidates: 
		                //Send the SDP message to the remote peer (e.g. as content of SIP INVITE request)
		                console.log(oSdpLocal.toSdp());
				        self.owner.onLocalSDP(oSdpLocal.toString());
		            }
		        }
        );
		if (peerSDP){
			 oSdpRemote = new w4aSessionDescription(peerSDP); // converts DOMString to "SessionDescription" object
			                                                     // set remote SDP and start media streaming
			 this.oPeerConnection.setRemoteDescription(w4aPeerConnection.SDP_ANSWER, oSdpRemote);
		}else{
	        oSdpLocal = this.oPeerConnection.createOffer({ has_audio: true, has_video: true });
	        this.oPeerConnection.setLocalDescription(w4aPeerConnection.SDP_OFFER, oSdpLocal);
	        this.oPeerConnection.startIce({ use_candidates: "all" });
		}
//		self.obtainLocalStream();

//        obtainLocalMedia(self.mediaParas, self.onGotLocalStream(), function(Er){self.owner.onWrtcError(Er);})
	};

	this.terminateCall = function(){
		this.oPeerConnection&&this.oPeerConnection.close();
	};

	this.setRemoteSDP = function(sdp){
		lw_log("webrtcClient.setRemoteSDP",sdp);
		if (this.asCaller){
			oSdpRemote = new w4aSessionDescription(sdp);
		    this.oPeerConnection.setRemoteDescription(w4aPeerConnection.SDP_ANSWER, oSdpRemote);
				        this.oPeerConnection.startMedia();
		}
	};

	this.onPeerCandidate = function(data) {
		lw_log("webrtcClient.onPeerCandidate",data.label, data.candidate);
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
			lw_log("webrtcClient.onGotLocalStream");
			curObj.localStream = stream;
			var MediaURL = webkitURL.createObjectURL(stream);
			curObj.owner.onLocalStream(MediaURL);
			curObj.initiatePeerConnection();
		};
	};

    this.pc_onICE = function(){
    	var curObj = this;
    	return function(event){
			lw_log("webrtcClient.pc_onICE");
    		if (event.candidate) {
//    			console.log("onICE: type:",curObj.service, "candidate:", event.candidate);
		        curObj.owner.onIceCandidate(event.candidate);
		    }else {
/*	this section can't open	    	var sdpConstraints = (curObj.service == 'video') ? {'mandatory': {
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
			lw_log("webrtcClient.pc_onRemoteStreamAdded");
    		var remoteStreamURI = webkitURL.createObjectURL(e.stream);
    		curObj.owner.onRemoteStream(remoteStreamURI);
    	};
    };

    this.pc_onGotLocalDescription = function(){
    	var curObj = this;
    	return function(desc){
//    		if (curObj.getOriginalVersionNo(desc.sdp) == '2'){
				lw_log("webrtcClient.pc_onGotLocalDescription,sdp: ",desc.sdp);
    			curObj.pc.setLocalDescription(desc);
//    		}else if (curObj.getOriginalVersionNo(desc.sdp) == '3'){
                curObj.owner.onLocalSDP(desc.sdp);
//    		}
    	};
    };

	//// inner functions
	this.obtainLocalStream = function(){
		lw_log("webrtcClient.obtainLocalStream");
		var curObj = this;
	    var mediaParas = {'audio':this.service=='screen'? false:true, 'video':this.mediaParas};
	    var mediaErrorTip = '获取媒体失败';
	    getUserMedia(mediaParas,
			curObj.onGotLocalStream(), 
		    function(){
		    	curObj.owner.onWrtcError(mediaErrorTip);
		    });
	};

	this.initiatePeerConnection = function(){
		var curObj = this;
		var servers = null;
		//var servers = {"iceServers": [{"url": "stun:202.122.107.66:19303"}]};
		//var servers = {"iceServers": [{"url": "stun:10.61.34.53:19303"}]};
		var contraints = {optional: [{"DtlsSrtpKeyAgreement": false}]};
		if (curObj.pc){
			curObj.pc.close();
			curObj.pc = null;
		}
		curObj.pc = new RTCPeerConnection(servers, contraints);
		curObj.pc.onicecandidate = curObj.pc_onICE();
		curObj.pc.onaddstream = curObj.pc_onRemoteStreamAdded();
		curObj.pc.addStream(curObj.localStream);

		var sdpConstraints = (curObj.service == 'p2pav'||curObj.service == 'video') ? {'mandatory': {
                          'OfferToReceiveAudio':true, 
                          'OfferToReceiveVideo':true }} : null;
		lw_log("webrtcClient.initiatePeerConnection",sdpConstraints);
		if (curObj.asCaller){
		    curObj.pc.createOffer(curObj.pc_onGotLocalDescription(), null, sdpConstraints);
	    }else{
	    	curObj.pc.setRemoteDescription(new RTCSessionDescription({type:'offer',sdp:curObj.peerSDP}));
			curObj.pc.createAnswer(curObj.pc_onGotLocalDescription(), null, sdpConstraints);
	    }
	};
    this.getOriginalVersionNo = function(sdpTxt){
		lw_log("webrtcClient.getOriginalVersionNo");
    	return sdpTxt.substring(sdpTxt.indexOf("o=")).split(' ')[2];
    }
}

function mediaClass(type){
	this.stream = null;
	this.referenceCount = 0;
	this.owners = [];
	this.type = type;
};
mediaClass.prototype.stopped = function(){
    if(this.type == "screen" && scrclient)  scrclient.hangup();
};
mediaClass.prototype.obtain = function(mediaParas, onLocalStream, onError){
	var curObj = this;
	var streamHandler = function(stream) {
		onLocalStream && onLocalStream(stream);
		stream.onended = function(e) {curObj.stopped();};
	};
	if (curObj.stream){
		curObj.referenceCount += 1;
		streamHandler(curObj.stream);
	}else{
	    getUserMedia(mediaParas,
			function(stream){
				curObj.stream=stream;
				curObj.referenceCount=1;
				streamHandler(stream);
			}, 
		    function(e){console.log(e);if (onError){onError("获取本地媒体失败");}});
	}
};
mediaClass.prototype.release = function(){
	var curObj = this;
	if (curObj.stream){
		if (curObj.referenceCount == 1){
			curObj.stream.stop();
			curObj.stream=null;
			curObj.referenceCount = 0;
		}else{
			curObj.referenceCount -= 1;
		}
	}
};

window.webrtcClient = webrtcClient;
window.obtainLocalMedia=obtainLocalMedia;
window.releaseLocalMedia=releaseLocalMedia;
window.mediaClass = mediaClass;
}());

var localVideoMedia=new mediaClass("video");
var localScrMedia=new mediaClass("screen");
var localAudioMedia=new mediaClass("audio");

lw_debug_id=false;
function lw_log() {
    if(lw_debug_id) {
        console.log(arguments[0],arguments[1],arguments[2],arguments[3]);
    }
}