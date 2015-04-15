
function formatDateTimeString(d)
{
      var s;
      s = d.getFullYear() + "-";             //取年份
      s = s + (d.getMonth() < 9 ? '0' : '') + (d.getMonth() + 1) + "-";//取月份
      s += d.getDate() + " ";         //取日期
      s += d.getHours() + ":";       //取小时
      s += d.getMinutes() + ":";    //取分
      s += d.getSeconds();         //取秒   
      return(s); 
}

function sessionClient(){
	this.sessions = {};/*key:sid_String, value:{chatwin:$('#window_sid_warp')|null, members:[uuid]*/
    this.orderedOperations = {p2p:{},mp:{}};
}

sessionClient.prototype = {
	//Received data from UserAgent.
	onSessionOpen: function(sid, stype, sname, members, history){
        if (!this.isActive(sid)){
            this.sessions[sid] = {chatwin:this.createWindow(sid, stype, sname, members), 
                                  stype:stype,
                                  sname:sname,
                                  members:members,
                                  chatCtlr: (new webChat(sid)).bindHandlers(),
                                  videoCtlr: (stype == 'p2p' ? (new p2pVideo(sid)).bindHandlers().ready() : (new mpVideo(sid)).bindHandlers().ready()),
                                  audioCtlr: (stype == 'p2p' ? (new p2pAudio(sid)).bindHandlers().ready() : null)};
        }
        this.updateMemberList(sid);
        this.sessions[sid].chatCtlr.displayMsgs('append', history);
        this.query_ongoing(sid);
        this.executeOrderedOperation(sid, stype, (stype == 'mp'? sid : (members[0] == myID()?members[1]:members[0])));
	},
	onMemberAdd: function(sid, invitor, newMembers){
        if (this.isActive(sid)){
            this.sessions[sid].members = this.sessions[sid].members.concat(newMembers);
            this.updateMemberList(sid);
        }
    },
	onMemberDelete: function(sid, quiter){
        if (this.isActive(sid)){
            this.sessions[sid].members.splice(this.sessions[sid].members.indexOf(quiter), 1);
            this.updateMemberList(sid);
        }
    },
    onMessage: function(sid, payload){
        if (this.isActive(sid)){
            this.processMsg(sid, payload);
        }else{
            this.tipMsg(sid, payload);            
        }
        this.desktopTip(sid, payload);
    },
    processMsg: function(sid, payload){
        switch (payload.media_type){
            case 'chat':
                this.sessions[sid].chatCtlr.displaySingleMsg('append', payload);
                Core.onNewMsg(sid);
                break;
            case 'video_conf':
                if (payload.action == 'invite' || payload.action == 'conf_ongoing'){
                    this.sessions[sid].chatCtlr.displaySingleMsg('append', payload);
                    this.sessions[sid].videoCtlr.onNewTip();
                    Core.onNewMsg(sid);
                    ManageSoundControl('play', 3);
                }
                this.sessions[sid].videoCtlr.processVideoMsg(payload);
                break;
            case 'video_p2p':
                if (payload.action == 'peer_invite'){
                    this.sessions[sid].chatCtlr.displaySingleMsg('append', payload);
                    this.sessions[sid].videoCtlr.onNewTip();
                    Core.onNewMsg(sid);
                    ManageSoundControl('play', 3);
                }
                this.sessions[sid].videoCtlr.processVideoMsg(payload);
                break;
            case 'audio_p2p':
                if (payload.action == 'peer_invite'){
                    this.sessions[sid].chatCtlr.displaySingleMsg('append', payload);
                    this.sessions[sid].audioCtlr.onNewTip();
                    Core.onNewMsg(sid);
                    ManageSoundControl('play', 3);
                }
                this.sessions[sid].audioCtlr.processVideoMsg(payload);
                break;
            default:
                break;
        }
    },
    tipMsg: function(sid, payload){
        switch (payload.media_type){
            case 'chat':
                tipbox.scheduleTip(sid, payload.name, payload.content);
                break;
            case 'video_conf':
                if (payload.action == 'invite'){
                    tipbox.scheduleTip(sid, "System", "Video call invitation");
                    ManageSoundControl('play', 3);
                }else if (payload.action == 'conf_ongoing'){
                    tipbox.scheduleTip(sid, "System", "Not finished videoconference");
                }
                break;
            case 'video_p2p':
                if (payload.action == 'peer_invite'){
                    tipbox.scheduleTip(sid, 'System', "Video call invitation");
                    ManageSoundControl('play', 3);
                }
                break;
            case 'audio_p2p':
                if (payload.action == 'peer_invite'){
                    tipbox.scheduleTip(sid, 'System', "Audio call invitation");
                    ManageSoundControl('play', 3);
                }
                break;
            default:
                break;
        }
    },
    desktopTip:function(sid, payload){
        switch(payload.media_type){
            case 'chat':
                var usr = mainmark.getContactAttr(payload.uuid);
                showNotification(usr.photo, 'Notification',  usr.name+' send you a new message.');
                break;    
            case 'video_conf':
                if (payload.action == 'invite'){
                    var usr = mainmark.getContactAttr(payload.host_id);
                    showNotification(usr.photo, 'Notification',  usr.name+' invite you to join a videoconference.');
                }
                break; 
            case 'video_p2p':
                if (payload.action == 'peer_invite'){
                    var usr = mainmark.getContactAttr(payload.uuid);
                    showNotification(usr.photo, 'Notification',  usr.name+' want a video chat with you.');
                }
                break;
            case 'audio_p2p':
                if (payload.action == 'peer_invite'){
                    var usr = mainmark.getContactAttr(payload.uuid);
                    showNotification(usr.photo, 'Notification',  usr.name+' want an audio chat with you. ');
                }
                break;
            default:
                break;
        }
    },
    onHistory: function(sid, history){
        this.sessions[sid].chatCtlr.displayMsgs('prepend', history);
    },
    onSessionThemeChanged: function(sid, newTheme){
        Core.changeWindowTitle(sid, newTheme);
    },
    isVideoOngoing: function(){
        for (var sid in this.sessions){
            if (this.sessions[sid].videoCtlr.isOngoing()){
                return true;
            }
        }
        return false;
    },
    //Notifications to UserAgent.
	contactWith: function(tos){
        var ongoingSession = this.findOngoing(tos.concat([myID()]));
        if (ongoingSession){
            Core.create({'id':ongoingSession});
        }else{
    		hp.sendData({type:"new_session", friend_ids:tos});
        }
	},
    activate: function(sid){
        if (this.isActive(sid)){
            Core.create({'id':sid});
        }else{
            hp.sendData({type:"query_session", session_id:sid});
        }
    },
    deactivate: function(sid){
        hp.sendData({type:"close_session", session_id:sid});
        delete(this.sessions[sid]);
    },
	inviteMember: function(sid, newMembers){
		hp.sendData({type:"join_session", session_id:sid, new_members:newMembers});
	},
	quit: function(sid){
		hp.sendData({type:"delete_session", session_id:sid});
	},
    query_ongoing: function(sid){
        hp.sendData({type:'query_ongoing_conf', session_id:sid});
    },
    loadHistory: function(sid){
        hp.sendData({type:"session_history", session_id:sid});
    },

    //ordered operation.
    orderOperation: function(stype, target, oper){
        var curObj = this;
        if (curObj.orderedOperations[stype][target] && curObj.orderedOperations[stype][target][oper]){
            clearTimeout(curObj.orderedOperations[stype][target][oper].timerID);
        }
        if (curObj.orderedOperations[stype][target]){
            if (curObj.orderedOperations[stype][target][oper]){
                curObj.removeOrder(stype, oper, target);
            }
        }else{
            curObj.orderedOperations[stype][target]={};
        }
        var tid = setTimeout(function(){
            var opername = "";
            switch (oper){
                case 'video':
                    opername = "Video call";
                    break;
                case 'audio':
                    opername = "Audio call";
                    break;
                default:
                    break;
            }
            LWORK.msgbox.show(opername+" failed.", 5, 2000);
            curObj.removeOrder(stype, oper, target);
        }, 5000);
        curObj.orderedOperations[stype][target][oper] = tid;
    },
    executeOrderedOperation: function(sid, stype, target){
        var curObj = this;
        if (curObj.orderedOperations[stype][target]){
            for (var oper in curObj.orderedOperations[stype][target]){
                curObj.doOperation(sid, stype, target, oper);
                curObj.removeOrder(stype, target, oper);
            }
        }
    },
    doOperation: function(sid, stype, target, oper){
        var curObj = this;
        var operBtn = "";
        switch (oper){
            case "video":
                operBtn = "S_video";
                break;
            case "audio":
                operBtn = "S_audio";
                break;
            case "file":
                break;
            default:
                break;
        }
        if (operBtn != ""){
            curObj.sessions[sid].chatwin.find('.'+operBtn).click();
        }
    },
    removeOrder: function(stype, target, oper){
        var curObj = this;
        if (curObj.orderedOperations[stype][target]){
            if (curObj.orderedOperations[stype][target][oper]){
                clearTimeout(curObj.orderedOperations[stype][target][oper]);
                delete curObj.orderedOperations[stype][target][oper];
            }
            delete curObj.orderedOperations[stype][target];
        }
    },

    //html DOM operation.
    bindWindowHandler: function(sid, members){
    	var curObj = this;
    	var winDom = $('#window_'+sid+'_warp');

        winDom.find('.S_addm').unbind('click').bind('click', function(){
            if (curObj.isActive(sid)){
                if (curObj.sessions[sid].stype == 'mp'){
                    (new addMember('friends_in_'+sid, 'Add members', function(flist){
                        //winDom.find('.discusMem').show().append(flist.html());
                        curObj.inviteMember(sid, flist);
                        return false;
                    })).init(curObj.sessions[sid].members);
                }else{
                    (new addMember('friends_in_'+sid, 'New discuss group', function(flist){
                        //winDom.find('.discusMem').show().append(flist.html());
                        curObj.contactWith(flist.concat(curObj.sessions[sid].members.map(function(item){return item.toString();})));
                        return false;
                    })).init(curObj.sessions[sid].members);
                }
            }
            return false;
        });
		
        winDom.find('.eiditDiscusGroupName').focus(function(){
		  $(this).val('');
		  return false;
		}).blur(function(){
			var newName = $(this).val();
			if(newName == '' || newName == 'Edit name') {
				$(this).val('Edit name');
				return false;
			}
			hp.sendData({type:"change_session_name", new_name:newName, session_id:sid});
        }).keyup(function(event){
			e = event ? event : (window.event ? window.event : null);
			if (e.keyCode === 13) {		 
                 $(this).blur();
			}
			return false;
		});

        winDom.find('.S_quit').unbind('click').bind('click', function(){
            if (curObj.sessions[sid].stype == 'mp' && curObj.sessions[sid].videoCtlr.isOngoing()){
                LWORK.msgbox.show("There is an ongoing videoconference, please stop it.");
            }else{
                curObj.quit(sid);
                winDom.find('.cw_close').click();
                mainmark.quitChat(sid);
            }
            return false;
        });
    },
    createWindow: function(sid, stype, sname, members){
        var curObj = this;
    	if (stype == 'p2p'){
    		var peerUser = mainmark.getContactAttr(members[0] == myID() ? members[1] : members[0]);
    	    Core.create({'id':sid, 'photo':peerUser.photo ,'name':peerUser.name ,'status':peerUser.status == 'online' ? 'Online' : 'Offline','Signature':peerUser.signature, 'resize':true, onCloseCallback: function(){curObj.closeWindow(sid);}});
    	}else{			
           Core.create({'id':sid, 'type':'mp', 'service':'chat', 'photo':'images/discu_group.jpg', 'name':sname==''?'Group':sname, 'resize':true, onCloseCallback: function(){curObj.closeWindow(sid);}});
    	}
    	curObj.bindWindowHandler(sid, members);
        return $('#window_'+sid+'_warp');
    },
    updateMemberList: function(sid){
        var curObj = this;
        var members = curObj.sessions[sid].members;
        var myItem = ''; online_html = '' , offline_html = '';
		 //members =  members.sort(sort_Aarray);
        for (var i = 0; i < members.length; i++){
            var memberInfo = mainmark.getContactAttr(members[i].toString());
			if(memberInfo['uuid'] == myID()){
			    myItem = FormatModel(friendItemTemplate2, memberInfo);
				continue;
			}
			if(memberInfo['status'] == 'online' ){
              online_html += FormatModel(friendItemTemplate2, memberInfo);
			}else{
              offline_html += FormatModel(friendItemTemplate2, memberInfo);				
			}
        }
            curObj.sessions[sid].chatwin.find('.memberList').html(myItem + online_html + offline_html);				
            curObj.sessions[sid].chatwin.find('.memberList .frienditem').unbind('click').bind('click', function(){
				var temp_uuid = $(this).attr('uuid').toString();
				if(temp_uuid !=  myID()) curObj.contactWith([temp_uuid]);
            });
        if (curObj.sessions[sid].stype == 'mp'){
            mainmark.newDiscussIfNotExist(sid, curObj.sessions[sid].stype, curObj.sessions[sid].sname, curObj.sessions[sid].members);
            mainmark.updateMemberCount(sid, curObj.sessions[sid].members.length);
        }
    },
    closeWindow: function(sid){
        this.sessions[sid].videoCtlr.onWindowClosed();
        this.deactivate(sid);        
    },
    updateMemberInfo: function(UUID, Attr, Val){
        for (var i in this.sessions){
            if (this.sessions[i].members.indexOf(parseInt(UUID, 10)) != -1){
                Core.updatePeerInChatWindow(i, UUID, Attr, Val);
            }
        }
    },

    //Inner functions
    isActive: function(sid){
        return this.sessions[sid] ? true : false;
    },
    findOngoing: function(memberList){
        for (var sid in this.sessions){
            if (this.isMemberListEqual(memberList, this.sessions[sid].members)){
                return sid;
            }
        }
        return false;
    },
    isMemberListEqual: function(l1, l2){
        if (l1.length != l2.length){
            return false;
        }

        var sl1 = l1.sort(), sl2 = l2.sort();
        for (var i = 0; i < sl1.length; i++){
            if (sl1[i] != sl2[i]){
                return false;
            }
        }
        return true;
    }
}

 /*桌面提醒*/
var notification ;
var window_focus = true;
$(window).bind( 'blur', function(){ 
   window_focus = false; 
}).bind( 'focus', function(){
    if(notification){
      notification.cancel();
      notification = null;
   }
   window_focus = true; 
}); 
function RequestPermission() {      
     window.webkitNotifications.requestPermission();    
} 
var Notification_time = 0, notification ;
function showNotification(icon, Title , content) {	
  if(!window.webkitNotifications || window_focus == true || !Title || !content ) return false;
  if (!!window.webkitNotifications) {
      if (window.webkitNotifications.checkPermission() == 1 ) {
		  RequestPermission();
     }else if(window.webkitNotifications.checkPermission() == 2){
	 	//if(Notification_time == 0){
		//}
	} else {
          window.webkitNotifications.requestPermission()
	      if( '' === content ){
			 return false;			
		  }else{	
			  if(notification) {
				  
			  }else{
				 notification =window.webkitNotifications.createNotification(icon, Title, content);	
				 notification.show();	   
				 setTimeout('notification.cancel()', 4000)  
			  }  
			     notification.onclose = function() {			
				 notification = null; 
			   };
			   notification.onclick = function(event) { 
				 window.focus();
				 notification.cancel();
				 notification = null;
			  };		   
		 }
	}
  }       
}


