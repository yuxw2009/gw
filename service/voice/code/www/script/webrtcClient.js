//websocket agent
function websocketAgent(wsURL){
}

function umProvider(){
    var request = function(mediaAttr, ok_cb, fail_cb){
    	navigator.webkitGetUserMedia(mediaAttr, ok_cb, fail_cb);
    }
}

//webrtcClient
function webrtcClient(wsAgent, userMediaProvider, peerConnectionConstructor){
	this.wsa = wsAgent;
	this.ump = userMediaProvider;
	this.pcc = peerConnectionConstructor;
	this.pc = null;
	this.cur_state = 'idle';
	this.service = null;
	this.from = null;

	this.curState = function(){return this.cur_state;};

	this.makeCall = function(service, from, to){
		this.service = service;
		this.from = from;
		this.wsa.connect(this.onWSOpenOK, this.onWSBroken)
	};

	this.onWSOpenOK = function(){
		this.wsa.send({'command':'connect', 'from':this.from});
	};
	this.onWSBroken = function(){};
	this.onWSReceived = function(msg){
		if (msg === 'connected-ok'){
			this.requestUserMedia();
		}
	};
	this.onGotLocalStream = function(stream){

	};
	this.onUserMdiaFailure = function(){};

	//// inner functions
	this.requestUserMedia = function(){
	    var mediaAttr = null;
	    switch (this.service){
	    	case 'voip':
	    	    mediaAttr = {'audio':true, 'video':false};
	    	    break;
	    	default:
	    	    break;
	    }
        if (mediaAttr){
		    this.ump.request(mediaAttr, this.onGotLocalStream, this.onUserMediaFailure);
	    }
	}
}