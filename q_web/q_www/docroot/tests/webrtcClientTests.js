module("webrtcClient");

function mockOwner(){
	this.onLocalSDP = function(localSDP){this.called_log.push('sdp:'+localSDP)};
	this.onRemoteStream = function(remoteURI){this.called_log.push('uri:'+remoteURI)};
	this.onError = function(error){this.called_log.push('error:' + error);};
    this.getCalledLog = function(){return this.called_log;};
    this.called_log = new Array();
}


test("mvideo", function(){
	var owner = new mockOwner();
    var client = new webrtcClient(owner);

	ok(client.cur_state == 'idle');
	equal(client.pc, null);
	equal(client.localStream, null);

	client.prepareCall("video");
	ok(client.cur_state == 'localStreaming');
	equal(client.pc, null);
	equal(client.localStream, null);

    var mockStream = {};
	client.onGotLocalStream()(mockStream);
	ok(client.cur_state == 'iceing');
	ok(client.pc);
	equal(JSON.stringify(client.localStream), JSON.stringify(mockStream));

    client.pc_onICE()({candidate:'aa'});
    ok(owner.getCalledLog().length == 0);
});