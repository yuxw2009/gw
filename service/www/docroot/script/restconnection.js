var lworkVideoPostUrl = lworkVideoDomain+'/channel/';


function RestConnection(owner,poll_url){
	var self=this;
	this.poll_url = poll_url||lworkVideoPostUrl;
	self.cbs = {};
	self.socket={sessionid:null};
	self.owner = owner;
	self.disc_num = 0;
}

RestConnection.prototype.channel_connect=function(connectionid) {
	var self = this;
	self.socket.connectionid = connectionid;
	lw_log('channel_connect:', connectionid);
	self.room_long_poll();
	return self;
}

RestConnection.prototype.chan_disconnect=function() {
	var self = this;
	lw_log('chan_disconnect:', self.socket.connectionid);
	clearTimeout(self.poll_timer);
	this.delete_channel();
	self.socket.connectionid=null;
	return self;
}

var DISCONNECT_NUM = 20;
var SHAKE_TIME_LEN= 3000;
RestConnection.prototype.room_long_poll = function() {
	var self=this;
	var disc_fun= function(){
		self.msgs_handler([{event:'server_disc',reason:'server_no_response'}]);
		clearTimeout(self.poll_timer);
		clearTimeout(self.poll_tid);
	};
	if(!self.socket.connectionid) {
		console.log("room connection quit!", self.owner.room);
		return;
	};
	var repoll = function(interval) {
		self.poll_timer = setTimeout(function() {self.room_long_poll();}, interval);
	}
	self.poll_tid = setTimeout(disc_fun,DISCONNECT_NUM*SHAKE_TIME_LEN);
	self.poll('fetch?connectionid='+self.socket.connectionid, 
		function(data){
//			lw_log("long_poll ok! data:", data);
			self.msgs_handler(data.msgs);
			repoll(2000);
			self.disc_num =0;
			clearTimeout(self.poll_tid);
	},
	function(err){
		self.disc_num +=1;
		if(self.disc_num<=2){
			lw_log("long_poll fail! err:", err);
			repoll(20000);
		} else{
			disc_fun();
		}
	});
};

RestConnection.prototype.connectionid = function() {
	return this.socket.connectionid;
}

RestConnection.prototype.poll = function(url,cb,fb) {
	RestChannel.post(this.poll_url+url, {}, cb,fb);
}
RestConnection.prototype.delete_channel = function() {
	RestChannel.post(this.poll_url+"del_channel"+"?connectionid="+this.connectionid(), {});
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
	if(!msgs) {
		console.log("msgs empty!!!");
		return;
	}
	for(var i=0; i<msgs.length;i++) {
		var msg = msgs[i];
		this.msg_handler(msg);
	}
};

RestConnection.prototype.msg_handler = function(msg) {
	lw_log("=========>:", msg);
	this.owner.processDownMsg(msg);
};

var lhp=new RestConnection(null);