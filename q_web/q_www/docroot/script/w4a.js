var oSdpLocal, oSdpRemote;
var oPeerConnection;

// this is not part of the standard but is required
WebRtc4all_Init();

// creates the peerconnection
oPeerConnection = new w4aPeerConnection("STUN stun.l.google.com:19302",
        function (o_candidate, b_moreToFollow) {
            if (o_candidate) {
                oSdpLocal.addCandidate(o_candidate);
            }
            if (!b_moreToFollow) {
                // No more ICE candidates: 
                //Send the SDP message to the remote peer (e.g. as content of SIP INVITE request)
                SendSdp(oSdpLocal.toSdp());
            }
        }
);

// creates SDP offer, starts ICE and wait until ICE gathering finish (see above)
oSdpLocal = oPeerConnection.createOffer({ has_audio: true, has_video: true });
oPeerConnection.setLocalDescription(w4aPeerConnection.SDP_OFFER, oSdpLocal);
oPeerConnection.startIce({ use_candidates: "all" });

// some time later...we receive the SDP answer (DOMString) from the remote peer
onmessage = function(sSdpRemote){
 oSdpRemote = new w4aSessionDescription(sSdpRemote); // converts DOMString to "SessionDescription" object
 // set remote SDP and start media streaming
 oPeerConnection.setRemoteDescription(w4aPeerConnection.SDP_ANSWER, oSdpRemote);
};

// start media streaming
//oPeerConnection.startMedia();

// to stop audio/video streaming, shutdown ICE connections and clear resources
// oPeerConnection.close();