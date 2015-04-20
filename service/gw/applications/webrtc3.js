var VOIPSession = null;
var VOIPTimer = null;
var VOIPPC = null;
var VOIPLocalStream = null;
var VOIPAutoStart = false;
var VOIPPhNo = null;
var VOIPOSVer = 0;	// session orignate session-versin

var VOIPCallSucc = null;
var VOIPCallHookOn = null;

function trace(text) {
  // This function is used for logging.
  if (text[text.length - 1] == '\n') {
    text = text.substring(0, text.length - 1);
  }
//  console.log((performance.webkitNow() / 1000).toFixed(3) + ": " + text);
//  console.log((performance.now() / 1000).toFixed(3) + ": " + text);
    console.log(text);
}

function ajax_send_json(msg,callback) {
  $.post("voip.yaws?t=" + Math.random(), msg,callback,'json');
}

function voipanswer(msg) {
  if (msg.type === 'successful') {
    VOIPSession = msg.session;
  	trace("voip session " + VOIPSession);
    trace("successful answer.\n"+msg.sdp);
    VOIPPC.setRemoteDescription(new RTCSessionDescription({type:'answer',sdp:msg.sdp}));

	VOIPTimer = setInterval(uas_pollvoip, 3000);
	VOIPCallSucc();
  }
  else {
  	trace("start failure: "+msg.reason);
  	VOIPCallHookOn();
  }
}

function uas_startvoip(SDP,PhNo) {
  var message = {type:'start_voip_call', duration:30,sdp:SDP, phone:PhNo};
  ajax_send_json(message,voipanswer);
}

function uas_stopvoip() {
  var message = {type:'stop_voip_call', session:VOIPSession};
  ajax_send_json(message,function(){});
  voip_clearenv();
}

function voip_event(Nu) {
  var message = {type:'event_voip_call', 'session':VOIPSession,'dail':Nu};

  ajax_send_json(message,null);
}

function pollack(msg) {
  $("#status").html(msg.ack);
  if(msg.ack == 'hook_on' || msg.ack == 'released'){
    trace("bye received.");
    voip_onRemoteHangup();
    VOIPCallHookOn();
    voip_clearenv();
  }
}

function uas_pollvoip() {
  var message = {type:'get_voip_status', session:VOIPSession};
  ajax_send_json(message,pollack);
}

function voip_clearenv() {
  window.clearInterval(VOIPTimer);
  VOIPTimer = null;
  VOIPSession = null;
}

// *********************************
function voip_gotStream(stream){
  trace("Received local stream");
//  $("#vid1")[0].src = webkitURL.createObjectURL(stream);
  VOIPLocalStream = stream;
  if (VOIPAutoStart == true) {
  	VOIPAutoStart = false;
  	startcall();
  }
}

function getaudio() {
  trace("Requesting local stream");
  navigator.webkitGetUserMedia({audio:true, video:false},
                               voip_gotStream, function() {});
}

function releaseaudio() {
  trace("release media");
  VOIPLocalStream.stop();
  VOIPLocalStream = null;
}
  
function voip_gotRemoteStream(e){
  trace("er get remote stream");
  $("#vid2")[0].src = webkitURL.createObjectURL(e.stream);
}

function voip_webcall(phoneNo,peer_ring,peer_hookon) {
  VOIPPhNo = phoneNo;
  VOIPCallSucc = peer_ring;
  VOIPCallHookOn = peer_hookon;
  if (VOIPLocalStream == null) {
  	VOIPAutoStart = true;
  	getaudio();
  	return false;
  }
  else
  	startcall();
}

function startcall() {
  trace("Starting call");
  var Ice = {"iceServers": [{"url": "stun:74.125.132.127:19302"}]};
//  var Ice = {"iceServers": [{"url": "stun:202.122.107.66:19303"}]};
//    var Ice = {"iceServers": [{"url": "stun:23.21.150.121"}]};
//  var Ice=null;

  VOIPPC = new webkitRTCPeerConnection(Ice);
  // callbacks
  VOIPPC.onicecandidate = voip_er_iceCallback;
  VOIPPC.onconnecting = function(event) {trace("er Session connecting.");};
  VOIPPC.onopen = function(event) {trace("er Session openned.");};
  VOIPPC.onaddstream = voip_gotRemoteStream;
  VOIPPC.onremovestream = function(event) {trace("er Remote stream removed.");};
  // local setting
  VOIPPC.addStream(VOIPLocalStream);

  VOIPPC.createOffer(voip_gotDescription);
}

function voip_gotDescription(desc){
  VOIPPC.setLocalDescription(desc);
  trace("er set local description");
  VOIPOSVer = 2;
}

function voip_got_desc_again(desc){
  VOIPOSVer = VOIPOSVer + 1;
  if (VOIPOSVer == 3) {
    trace("call phone :"+VOIPPhNo);
    trace("("+ VOIPOSVer + ") Offer again: \n" + desc.sdp);
    uas_startvoip(desc.sdp, VOIPPhNo);
  }
}

function voip_hangup() {
  trace("Ending call");
  VOIPPC.close(); 
  VOIPPC = null;
  uas_stopvoip();
}

function voip_er_iceCallback(event){
  if (event.candidate) {
  	trace("er gathering candidate for: "+event.candidate.sdpMLineIndex);
    }
  else {
  	trace("er gather candidates end.");
    VOIPPC.createOffer(voip_got_desc_again);
    }
}

function voip_onRemoteHangup() {
  VOIPPC.close();
  VOIPPC = null;
}
