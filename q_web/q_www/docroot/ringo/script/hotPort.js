var VWS = false;
if (window.WebSocket) VWS = WebSocket;
if (!VWS && window.MozWebSocket) VWS = MozWebSocket;
function RobustWebSocket(on_receive, on_ok, on_brkn){
	if(!VWS) return false;
	this.wsURL = "";
	this.connect = function(){
	    this._ws = new VWS(this.wsURL);
	  	this._ws.onopen = function(){
			on_ok();
		};
	  	this._ws.onclose = function(){
	  		on_brkn();
	  	};
	  	this._ws.onmessage = function(msg){
	  		if(msg.data){
			    var data = JSON.parse(msg.data);
			    on_receive(data);
	        }
	    };
	};
	this.send = function(data){
    	try{
		    if (this._ws){
		        this._ws.send(JSON.stringify(data));
		    }
		}catch(e){
		    if(console && console.log){
		    	console.log(e.error);
		    }
		}
    };

}

function RobustPost(on_receive, on_ok, on_brkn){
	this.postURL = "/notify";
	this.connect = function(){
        this.postAJAX({uuid:myID(), notify:[]}, function(rst){
            on_ok();
            on_receive(rst);
        }, function(){
            on_brkn();
        });
	};
	this.send = function(data){
        this.postAJAX(data, on_receive, on_brkn);
	};
    this.postAJAX = function(data, onSucc, onErr){
        $.ajax({
                type: 'POST',
                url: this.postURL,
                data: JSON.stringify(data),
                success: function(Reps) {
                    onSucc(Reps);
                },
                error: function(xhr) {
                   onErr();
                }
            });
    };
}


function RobustChannel(onMsg, onIamBroken, onIamResumed){
	this.onMsg = onMsg;
    this.onIamBroken = onIamBroken;
    this.onIamResumed = onIamResumed;
    this.channelOK = false;
	this.channel = null;
    this.loopTimer = null;
    this.sendBuffer = new Array();
    this.ackBuffer = new Array();
    this.timeoutCount = 0;
    this.isTryingReconnecting = false;
}
RobustChannel.prototype = {
    connect: function (){
    	var curObj = this;
    	//curObj.channel = new RobustWebSocket(curObj.onReceived(curObj), curObj.onChannelOK(curObj), curObj.onChannelBroken(curObj));
    	curObj.channel = new RobustPost(curObj.onReceived(curObj), curObj.onChannelOK(curObj), curObj.onChannelBroken(curObj));
    	curObj.channel.connect();
    },
    send: function(req){
    	if (this.channelOK){
    		this.sendBuffer.push(req);
            this.doSend();
    		return true;
    	}else{
            if (this.onIamBroken){
                this.onIamBroken([req]);
            }
    		return false;
    	}
    },
    doSend: function(){
        this.channel.send({uuid:myID(), notify:this.sendBuffer});
        this.ackBuffer = this.ackBuffer.concat(this.sendBuffer);
        this.sendBuffer = [];
    },
    onReceived: function(obj){
    	return function(msg){
    		obj.timeoutCount = 0;
	  		obj.ackBuffer = [];
            for (var i = 0; i < msg.length; i++){
                obj.onMsg(msg[i]);
            }   
    	}
    },
    onChannelOK: function(obj){
    	return function(){
    	    obj.channelOK = true;
            if (obj.ackBuffer.length > 0){
                obj.sendBuffer = obj.ackBuffer.concat(obj.sendBuffer);
                obj.ackBuffer = [];
            }
    	    obj.doSend();
    	    obj.loopTimer = setInterval(function(){
                if (obj.timeoutCount >= 2){
                    obj.onChannelBroken(obj);
                    obj.timeoutCount = 0;
                }else{
                    obj.doSend();
                    obj.timeoutCount += 1;
                }
            }, 3000);
            if (obj.isTryingReconnecting){
                obj.onIamResumed();
                obj.isTryingReconnecting = false;
            }
        }
    },
    onChannelBroken: function(obj){
    	return function(){
    	    obj.channelOK = false;
    	    if (obj.loopTimer){
	  			clearInterval(obj.loopTimer);
	  		}
            if (obj.onIamBroken){
                if (!obj.isTryingReconnecting){
                    obj.onIamBroken(obj.ackBuffer);
                }
            }
            obj.isTryingReconnecting = true;
    	    setTimeout(function(){obj.connect();}, Math.floor(Math.random()*5000));
        }
    }
}


function hotPort(){
    this.chn = new RobustChannel(this.receivedData(), this.channelBroken(), this.channelResumed());
    this.chn.connect();
}

hotPort.prototype = {
    sendData: function(Data){
        return this.chn.send(Data);
    },
    channelBroken: function(){
        return function(unAckedMsgs){
            if (unAckedMsgs.length > 0){
                var txt = "由于网络原因，如下消息发送失败："+ unAckedMsgs.map(function(item){return JSON.stringify(item);}).join(';');
                LWORK.msgbox.show(txt, 5, 1000);
            }else{
                LWORK.msgbox.show("当前网络状况不稳定，请检查网络。", 5, 1000);
            }
            mainmark.onNetworkBroken();
        }
    },
    channelResumed: function(){
        return function(){
            doLogin(curAccount, curPassword, function(){}, function(){});
        }
    },
    receivedData: function(){
        var curObj = this;
        return function(Data){
            switch (Data['type']){
                case "re_login":
                    doLogin(curAccount, curPassword, function(){}, function(){});
                    break;
                case "session_open":
                    sc.onSessionOpen(Data.session_id.toString(), Data.session_type, Data.session_name, Data.member_ids, Data.history_message);
                    break;
                case "session_member_add":
                    sc.onMemberAdd(Data.session_id.toString(), Data.inviter_id, Data.new_members);
                    break;
                case "session_member_delete":
                    sc.onMemberDelete(Data.session_id.toString(), Data.member);
                    break;
                case "session_message":
                    sc.onMessage(Data.session_id.toString(), Data.payload);
                    break;
                case "session_history":
                    sc.onHistory(Data.session_id.toString(), Data.history_message);
                    break;
                case "info_update":
                    mainmark.updateUserInfo(Data.uuid.toString(), Data.attribute, Data.value);
                    break;
                case "update_contacts":
                    mainmark.updateContacts(Data.contacts);
                    break;
                case "query_friend_result":
                    mainmark.onQueryFriendResult(Data.results);
                    break;
                case "friend_add_succ":
                    mainmark.onFriendAddSucc(Data.uuid, Data.name);
                    break;
                case "friend_add":
                    mainmark.onFriendAdded(Data.label, Data.uuid.toString(), Data.name, Data.photo, Data.signature, Data.status);
                    break;
                case "friend_del_succ":
                    mainmark.onFriendDelSucc(Data.uuid.toString(), Data.name);
                    mainmark.onFriendDeleted(Data.uuid.toString());
                    break;
                case "friend_del":
                    mainmark.onFriendDeleted(Data.uuid.toString());
                    break;
                case "change_password_ok":
                    if ($.cookie('password')){
                        $.cookie('password', Data.new_pass, {expires: 30});
                        curPassword = Data.new_pass;
                    }
                    LWORK.msgbox.show("修改密码成功！", 4, 1000);
                    break;
                case "change_password_failed":
                    LWORK.msgbox.show("修改密码失败！", 5, 1000);
                    break;
                case "change_session_name_ok":
                    sc.onSessionThemeChanged(Data.session_id.toString(), Data.new_name.toString());
					mainmark.onSessionThemeChanged(Data.session_id.toString(), Data.new_name.toString());
                    break;
                default:
                    if (console && console.log){
                        console.log("hotPort received unexpected data:"+JSON.stringify(Data));
                    }
                    break;
            }
        }
    }
}
