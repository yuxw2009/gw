




var voip_pc;
var voip_localstream;
var _calledphno;
var _onmediaok = null;
var _onanswer = null;
var _onhookon = null;
var voip_trace_flag = false;

function voip_trace(text) {
  // This function is used for logging.
  if (text[text.length - 1] == '\n') {
    text = text.substring(0, text.length - 1);
  }
  if (voip_trace_flag){
    console.log((performance.now() / 1000).toFixed(3) + ": " + text);
  }
}

function voip_gotStream(stream){
  voip_trace("Received local stream");
  voip_localstream = stream;
  _onmediaok();
}

function voip_onGotRemoteStream(desc){
  var rtcwin = $("#voip_obj")[0];
  voip_trace("Got remote stream");
  rtcwin.src = webkitURL.createObjectURL(desc.stream);
}

function voip_startmedia(callback) {
  _onmediaok = callback;
  voip_trace("Requesting local stream");
    try{
	  navigator.webkitGetUserMedia({audio:true, video:false},
								   voip_gotStream, function() {  LWORK.msgbox.show("获取媒体失败，请安装麦克风！", 2, 1000);});
	 }catch(e){ $('#alert').slideDown();}							   
								   
}
  
function voip_webcall(phoneNo,peer_ring,peer_hookon) {
  _calledphno = phoneNo;
  _onanswer = peer_ring;
  _onhookon = peer_hookon;
  voip_trace("Starting call " + phoneNo);
  var servers = null;
  try{
     voip_pc = new webkitRTCPeerConnection(servers);
  }catch(e){ $('#alert').slideDown();}

  // callbacks
  voip_pc.onicecandidate = voip_iceCallback;
  voip_pc.onconnecting = function(event) {voip_trace("er Session connecting.");};
  voip_pc.onopen = function(event) {voip_trace("er Session openned.");};
  voip_pc.onaddstream = voip_onGotRemoteStream;
  voip_pc.onremovestream = function(event) {voip_trace("er Remote stream removed.");};
  // local setting
  voip_pc.addStream(voip_localstream);
  voip_pc.createOffer(voip_gotDescription);
}

function voip_gotDescription(desc){
  voip_pc.setLocalDescription(desc);
  voip_trace("Offer from pc \n" + desc.sdp);
  voip_client.chat({type: 'offer', sdp: desc.sdp});
  voip_client.chat({type: 'phone', num: _calledphno});
}

function voip_hangup() {
  voip_trace("Ending call");
  voip_pc.close(); 
  voip_pc = null;
  voip_client.chat({type: 'bye', reason: 'normal'});
}

function voip_iceCallback(event){
  if (event.candidate) {
    voip_client.chat({type: 'candidate',
                 label: event.candidate.sdpMLineIndex, candidate: event.candidate.candidate});
    voip_trace("ice candidate: \n" + event.candidate.candidate);
  }
}

// *********************************      
function voip_receive(msg) {
    if (msg.type === 'offer') {
      voip_trace("offer received.");
      voip_calleeStart();
      var Offer = new RTCSessionDescription({type:'offer',sdp:msg.sdp});
      voip_pc.setRemoteDescription(Offer);
      voip_pc.createAnswer(voip_doAnswer);
	} else if (msg.type === 'answer') {
      voip_trace("answer received.\n" + msg.sdp);
      voip_pc.setRemoteDescription(new RTCSessionDescription(msg));
      _onanswer();
    } else if (msg.type === 'candidate') {
      voip_trace("candidate received.");
      var candidate = new RTCIceCandidate({sdpMLineIndex:msg.label,
                                           candidate:msg.candidate});
      voip_pc.addIceCandidate(candidate);
    } else if (msg.type === 'bye') {
      voip_trace("bye received.");
      voip_onRemoteHangup();
    } else if (msg.type === 'status') {
      voip_trace("sip status: "+msg.name);
    }
}
function voip_calleeStart() {
  var servers = null;
  voip_pc = new webkitRTCPeerConnection(servers);
  voip_pc.onicecandidate = voip_iceCallback;
  voip_pc.onconnecting = function(event) {voip_trace("ee Session connecting.");};
  voip_pc.onopen = function(event) {voip_trace("ee Session openned.");};
  voip_pc.onaddstream = function(event) {voip_trace("ee Remote stream added.");};
  voip_pc.onremovestream = function(event) {voip_trace("ee Remote stream removed.");};
  // callee local setting
  voip_pc.addStream(voip_localstream);
}

function voip_doAnswer(desc) {
  voip_pc.setLocalDescription(desc);
  voip_client.chat({type: 'answer', sdp: desc.sdp});
}

function voip_onRemoteHangup() {
  voip_pc.close();
  voip_pc = null;
  _onhookon();
}