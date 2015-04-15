var lworkVideoPostUrl = lworkVideoDomain+'/channel/';//'http://10.32.3.38:82/channel/';//'http://203.222.195.109:82/channel/';//'http://116.228.53.181/channel/';//'http://202.122.107.66/channel/';

function RestConnection(owner){
	var self=this;
	this.poll_url = lworkVideoPostUrl;
	self.cbs = {};
	self.socket={sessionid:null};
	self.owner = owner;
}

RestConnection.prototype.room_connect=function(connectionid) {
	var self = this;
	self.socket.connectionid = connectionid;
	lw_log('room_connect:', connectionid);
	self.room_long_poll();
	return self;
}

RestConnection.prototype.room_disconnect=function() {
	var self = this;
	lw_log('room_disconnect:', self.socket.connectionid);
	clearTimeout(self.poll_timer);
	self.socket.connectionid=null;
	return self;
}

RestConnection.prototype.room_long_poll = function() {
	var self=this;
	if(!self.socket.connectionid) {
		console.log("room connection quit!", self.owner.room);
		return;
	}
	lw_log('room_long_poll*******************');
	var repoll = function(interval) {
		self.poll_timer = setTimeout(function() {self.room_long_poll();}, interval);
	}
	this.poll('fetch?connectionid='+this.socket.connectionid, function(data){
		lw_log("long_poll ok! data:", data);
		if(data.event=="disconnect") {
			lw_log("server disconnected");
			return;
		}
		self.msgs_handler(data.msgs);
		repoll(2000);
	},
	function(err){
		lw_log("long_poll fail! err:", err);
		repoll(20000);
	});
};

RestConnection.prototype.connectionid = function() {
	return this.socket.connectionid;
}
RestConnection.prototype.poll = function(url,cb,fb) {
	RestChannel.get(this.poll_url+url, {}, cb,fb);
}
RestConnection.prototype.on = function(event, cb) {
	this.cbs[event] && this.cbs[event].push(cb) || (this.cbs[event]=[cb]);
}

RestConnection.prototype.emit=function(event, params, cb,fb) {
	this.senddata0(this.connectionid(),{event:event, params:params},cb,fb);
}

RestConnection.prototype.sendData=function(params, cb,fb) {
	this.senddata0("room", params, cb,fb);
}
RestConnection.prototype.senddata0=function(url, params, cb,fb) {
	var url=this.poll_url+url;
//    lw_log("<===========", params);
	RestChannel.post(url, params, function(data){
		cb && cb(data);
	}, function(err){
		fb && fb(err);
	})
}

RestConnection.prototype.msgs_handler = function(msgs) {
	for(var i=0; i<msgs.length;i++) {
		var msg = msgs[i];
		this.msg_handler(msg);
	}
};

RestConnection.prototype.msg_handler = function(msg) {
	lw_log("=========>:", msg);
	this.owner.processDownMsg(msg);
};



var hp=new RestConnection(null);