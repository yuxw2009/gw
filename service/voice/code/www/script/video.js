var pc = null;
var rtcpeer = {
	to:"",
	from:""
	};
	
var ws = {
        connect: function(opt){
           this._ws = new WebSocket(getVideoWebSocketURL());
           this._ws.onopen = this._onopen;
           this._ws.onmessage = this._onmessage(opt);
           this._ws.onclose = this._onclose;
        },
        close: function() {
           this._ws.close();
        },
        _onopen: function(){
			send_message({'command':'connect', 'from':uuid});           
        },
        send: function(message){
           if (this._ws)
                this._ws.send(message);
        },
        _onmessage: function(opt) { 
			return function(m) {
				if(m.data == "connected-ok") {
					   start(opt);
				}
				else if(m.data == "hangup-ok") {
				    hangup();
				}
				else {
					var msg = JSON.parse(m.data);
					if(msg.command == "answer"){
						answer = msg.sdp;
						pc.setRemoteDescription(new RTCSessionDescription({type:'answer',sdp:msg.sdp}));
						trace("SetRemoteDesc1");
					}if(msg.command == "offer"){
						rtcpeer.to = msg.from;
						rtcpeer.from = msg.to;
						trace("offer from " + msg.from + " to " + msg.to);
						    
						var server = null;
						pc = new webkitRTCPeerConnection(server);
						pc.onicecandidate = iceCallback;
						trace("Created local peer connection object pc");
						pc.onaddstream = gotRemoteStream(RemoteMediaReadyCallback);
						pc.addStream(localstream);
						var offer = new RTCSessionDescription({type:'offer',sdp:msg.sdp});
						pc.setRemoteDescription(offer);
						pc.createAnswer(doAnswer);
					}if(msg.command == "accepted"){
							rtcpeer.to = msg.from;
							rtcpeer.from = msg.to;
							trace("accepted from " + msg.from + " to " + msg.to);
						  trace("Starting call");
						    if (localstream.videoTracks.length > 0)
						      trace('Using Video device: ' + localstream.videoTracks[0].label);  
						    if (localstream.audioTracks.length > 0)
						      trace('Using Audio device: ' + localstream.audioTracks[0].label);   
						    pc = new webkitRTCPeerConnection(null);
						    pc.onicecandidate = iceCallback;
						    trace("Created local peer connection object pc");
						    pc.onaddstream = gotRemoteStream(RemoteMediaReadyCallback);
						    pc.addStream(localstream);
						    trace("Adding Local Stream to peer connection");
						    pc.createOffer(gotDescription);
					}
					else if(msg.command == "candidate"){
						trace("process candidate");
						var candidate = new RTCIceCandidate({sdpMLineIndex:msg.label, candidate:msg.sdp});
						pc.addIceCandidate(candidate);
					}
					else if(msg.command == "hangup"){
							$('#video').find('.video_input').attr('disabled', false);
							$('#video').find('.endVedio').hide().prev().show();	
							$('#video').find('.navigator_tips').hide();										
							vid1.src = '';
							vid2.src = '';
							LWORK.msgbox.show("对方已终止视频！", 2, 1000);
							hangup();
					}
				}
        }},
        _onclose: function(m) {
         // alert("take a break, please.");
            this._ws = null;
        }
    };
	
var vid1 = document.getElementById("vid1");
var vid2 = document.getElementById("vid2");
var pc;
var localstream;
function LocalMediaReadyCallback(MediaURL,opt) {
    vid1.src = MediaURL;
	
	opt['sdp']? called(opt['sdp'], opt['from'] ,opt['to'] ): call(opt['from'],opt['to']);	
	
}
function RemoteMediaReadyCallback(RemoteMediaURL) {
    vid2.src = RemoteMediaURL;
    trace("Received remote stream");
    videoswitch();
}
function trace(text) {
  // This function is used for logging.
  if (text[text.length - 1] == '\n') {
    text = text.substring(0, text.length - 1);
  }
  console.log( ": " + text);
}
function start(opt) {	
   start_session(LocalMediaReadyCallback, opt);
}
function call(from, to) {
  call_peer(from, to, RemoteMediaReadyCallback);
  
}
function called(sdp, from ,to ){	

    send_message({command:'accepted', 'from':from, 'to': to});
}

function start_session(LocalMediaReadyCallback, opt) {
  trace("Requesting local stream");
 // btn1.disabled = true;
  navigator.webkitGetUserMedia({audio:true, video:true},
                               on_media_ready(LocalMediaReadyCallback,opt), function() {  LWORK.msgbox.show("获取媒体失败，请安装摄像头！", 2, 1000);	});

} 
function on_media_ready(Callback,opt) {
    return function (stream) {
              trace("Received local stream");
              MediaURL = webkitURL.createObjectURL(stream);
              localstream = stream;
              Callback(MediaURL,opt);
           }
}
function call_peer(from, to) {
	  send_message({ command:'invite', from:from, to:to });	
}  
function send_message(Message) {
    var msgString = JSON.stringify(Message);
    ws.send(msgString);
}
function hangup() {
  videoswitch2()
  trace("Ending call");
  pc.close(); 
  ws.close();
  pc = null;
}
function gotRemoteStream(RemoteMediaReadyCallback){
  return function (e) {
             RemoteMediaURL = webkitURL.createObjectURL(e.stream);
             RemoteMediaReadyCallback(RemoteMediaURL);
         }
}
function videoswitch(){	
  $('#vid1').parent().removeClass('video_object').addClass('video_personal');
  $('#vid2').parent().removeClass('video_personal').addClass('video_object'); 	
}

function videoswitch2(){	
  $('#vid2').parent().removeClass('video_object').addClass('video_personal');
  $('#vid1').parent().removeClass('video_personal').addClass('video_object'); 	
}

function iceCallback(event) {

               if (event.candidate) {
                   trace("send candidate to peer from " + rtcpeer.from + " to " + rtcpeer.to);
                   send_message({command:'candidate', from:''+rtcpeer.from, to:''+rtcpeer.to, 
                                   'label':event.candidate.sdpMLineIndex, 'sdp':event.candidate.candidate});
                  }
}

function doAnswer(desc) {
	trace("SetLocalDesc1");
	pc.setLocalDescription(desc);
	send_message({command:'answer', 'from':rtcpeer.from, 'to': rtcpeer.to,'sdp':desc.sdp});
}

function gotDescription(desc){
  trace("SetLocalDesc1"); 
  pc.setLocalDescription(desc);
  send_message({command:'offer', from:rtcpeer.from, to:rtcpeer.to, sdp:desc.sdp});
}