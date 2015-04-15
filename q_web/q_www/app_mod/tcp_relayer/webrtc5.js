var VOIPSession = null;
var VOIPTimer = null;
var VOIPPC = null;
var VOIPLocalStream = null;

var WAITTimer = null;
var WEBPC =null;
var WEBRemoteStream = null;

var VOIPPhNo = null;
var VOIPOSVer = 0;	// session orignate session-versin

var VOIPCallSucc = null;
var VOIPCallHookOn = null;

// *********************************
//
//	log and ajax common functions
//
// *********************************

function trace(text) {
  if (text[text.length - 1] == '\n') {
    text = text.substring(0, text.length - 1);
  }
  console.log(text);
}

function ajax_send_json(msg,callback) {
  $.post("lrswap.yaws?t=" + Math.random(), msg,callback,'json');
}

function uas_er_startvoip(SDP,PhNo) {
  var message = {type:'offer', sdp:SDP, uid:PhNo};
  ajax_send_json(message,voip_er_get_answer);
}

function uas_er_pollvoip() {
  var message = {type:'poll_call', session:VOIPSession};
  ajax_send_json(message,pollack);
}

function uas_er_stopvoip() {
  var message = {type:'release',  session:VOIPSession};
  ajax_send_json(message,function(){});
  voip_er_clearenv();
}

// ---------------------------------

function uas_ee_waitcall(MyNo) {
  var message = {type:'wait_call', uid:MyNo};
  ajax_send_json(message,ee_waitcallack);
}

function uas_ee_answervoip(SDP,MyNo) {
  var message = {type:'answer', sdp:SDP, uid:MyNo};
  ajax_send_json(message,ee_answerack);
}

// *********************************
//
//	getUserMedia
//
// *********************************
function voip_gotStream(stream){
  trace("Received local stream");
//  $("#vid1")[0].src = webkitURL.createObjectURL(stream);
  VOIPLocalStream = stream;
}

function getaudio() {
  trace("Requesting local stream");
  navigator.webkitGetUserMedia({audio:true, /* video:false */
								video: {mandatory: { minAspectRatio: 1.333, maxAspectRatio: 1.334 },
        								optional: [{ maxFrameRate: 3 },
          										   { maxWidth: 320 },
          										   { maxHeigth: 240 }]}
  										  },
                                voip_gotStream, function() {alert("error.");});
}

function releaseaudio() {
  trace("release media");
  VOIPLocalStream.stop();
  VOIPLocalStream = null;
}

// *********************************
//
//	caller wait answer sdp
//
// *********************************

function voip_er_clearenv() {
  window.clearInterval(VOIPTimer);
  VOIPTimer = null;
  VOIPSession = null;
}

function pollack(msg) {
  if(msg.type == 'successful'){
    window.clearInterval(VOIPTimer);
    trace("successful answer.\n"+msg.sdp);
    VOIPPC.setRemoteDescription(new RTCSessionDescription({type:'answer',sdp:msg.sdp}));
  }
  else {
    trace("failure answer: " + msg.reason);
  }
}

function voip_er_get_answer(msg) {
  if (msg.type === 'successful') {
    VOIPSession = msg.session;
  	trace("voip session " + VOIPSession);

	VOIPTimer = setInterval(uas_er_pollvoip, 500);
	VOIPCallSucc();
  }
  else {
  	trace("start failure: "+msg.reason);
  }
}

// *********************************
//
//	peerConnection Caller
//
// *********************************
  
function voip_er_gotRemoteStream(e){
  trace("er get remote stream");
  $("#vid2")[0].src = webkitURL.createObjectURL(e.stream);
}

function voip_webcall(phoneNo,peer_ring,peer_hookon) {
  VOIPPhNo = phoneNo;
  VOIPCallSucc = peer_ring;
  VOIPCallHookOn = peer_hookon;
  if (VOIPLocalStream == null) {
    alert("getMedia first!");
  	return false;
  }
  else
  	er_startwrtc();
}


function er_startwrtc() {
  trace("er Starting call");
  VOIPPC = new webkitRTCPeerConnection(null);
  // peerConnect callbacks
  VOIPPC.onicecandidate = voip_er_iceCallback;
  VOIPPC.onconnecting = function(event) {trace("er Session connecting.");};
  VOIPPC.onopen = function(event) {trace("er Session openned.");};
  VOIPPC.onaddstream = voip_er_gotRemoteStream;
  VOIPPC.onremovestream = function(event) {trace("er Remote stream removed.");};
  VOIPPC.onnegotiationneeded = function(event) {trace("er negotiation.");};
  // local media setting
  VOIPPC.addStream(VOIPLocalStream);
  VOIPPC.createOffer(voip_er_gotDescription);
}

function voip_er_gotDescription(desc){
  VOIPPC.setLocalDescription(desc);
  trace("er set local description");
  VOIPOSVer = 2;
}

function voip_ergot_desc_again(desc){
  VOIPOSVer = VOIPOSVer + 1;
  if (VOIPOSVer == 3) {
    trace("call phone :"+VOIPPhNo);
    trace("("+ VOIPOSVer + ") Offer again: \n" + desc.sdp);
    uas_er_startvoip(desc.sdp,VOIPPhNo);
  }
  else {
    trace("("+ VOIPOSVer + ") Offer again: \n" + desc.sdp);
  }
}

function voip_er_iceCallback(event){
  if (event.candidate) {
  	trace("er gathering candidate for: "+event.candidate.sdpMLineIndex);
    }
  else {
  	trace("er gather candidates end.");
    VOIPPC.createOffer(voip_ergot_desc_again);
    }
}

function voip_hangup() {
  trace("remove stream.\n");
  VOIPPC.removeStream(VOIPLocalStream);
  releaseaudio();
  trace("Ending call.\n");
  VOIPPC.close(); 
  VOIPPC = null;
  uas_er_stopvoip();
}

// *********************************
//
//	peerConnection Callee
//
// *********************************

function ee_gotRemoteStream(e){
  trace("ee get remote stream");
  $("#vid2")[0].src = webkitURL.createObjectURL(e.stream);
  WEBRemoteStream = e.stream;
}

function voip_eegot_desc_again(desc){
  VOIPOSVer = VOIPOSVer + 1;
  if (VOIPOSVer == 3) {
    trace("call phone :"+VOIPPhNo);
    uas_ee_answervoip(desc.sdp,VOIPPhNo);
  }
}

function voip_ee_iceCallback(event){
  if (event.candidate) {
    trace("ee gatering candidate for : "+event.candidate.sdpMLineIndex);
    }
  else {
    trace("ee ice callback,null candidate");
    VOIPPC.createanswer(voip_eegot_desc_agaion);
    }
}

function ee_waitcallack(msg) {
  if (msg.type == 'successful') {
  	trace("callee session." + msg.session);
    trace("callee starting.\n" + msg.sdp);
    window.clearInterval(WAITTimer);
    calleeStart();
    WEBPC.setRemoteDescription(new RTCSessionDescription({type:'offer',sdp:msg.sdp}));
    WEBPC.createAnswer(ee_gotDescription);
  } else if (msg.reason == 'hangup') {
    trace("hang up.");
  } else {
  };
}

function web_ee_waitcall() {
  var MyNo = document.getElementById('phno').value;
  
  VOIPPhNo = MyNo;
  uas_ee_waitcall(MyNo);
}

function calleeStart() {
  WEBPC = new webkitRTCPeerConnection(null);
  WEBPC.onicecandidate = ee_iceCallback;
  WEBPC.onconnecting = function(event) {trace("ee Session connecting.");};
  WEBPC.onopen = function(event) {trace("ee Session openned.");};
  WEBPC.onaddstream = ee_gotRemoteStream;
  WEBPC.onremovestream = ee_removeRStream;
  WEBPC.onnegotiationneeded = function(event) {trace("ee negotiation.");};
}

function ee_removeRStream(event) {
  trace("ee Remote stream removed.");
}

function ee_answerack(msg) {
  if (msg.type === 'successful') {
  	window.clearInterval(WAITTimer);
  	WAITTimer = null;
  	trace("response ok");
  }
  else {
  	trace("response failure: "+msg.reason);
  }
}

function eegot_desc_again(desc){
  VOIPOSVer = VOIPOSVer + 1;
  if (VOIPOSVer == 3) {
    trace("("+ VOIPOSVer + ") answer again: \n" + desc.sdp);
    uas_ee_answervoip(desc.sdp,VOIPPhNo);
  }
  else {
    trace("("+ VOIPOSVer + ") answer again: \n" + desc.sdp);
  }
}

function ee_gotDescription(desc) {
  trace("answer sdp:\n" + desc.sdp);
  WEBPC.setLocalDescription(desc);
  VOIPOSVer = 2;
}

function ee_iceCallback(event){
  if (event.candidate) {
  	trace("ee gathering candidate for: "+event.candidate.sdpMLineIndex);
    }
  else {
  	trace("ee gather candidates end.");
    WEBPC.createAnswer(eegot_desc_again);
    }
}
