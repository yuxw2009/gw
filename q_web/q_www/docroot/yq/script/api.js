var LWAPI = {
    createNew: function() {
        var api = {};
        var check_status = function(data, cb, failedcb) {
            var status = data['status'];
            if (status == 'ok') {
                cb(data);
            } else {
			    if(failedcb) failedcb(data['reason']);
            }
        };
		var errorHandle = function(){			
			LWORK.msgbox.show(lw_lang.ID_REQUEST_ERROR, 5, 1000);	
			$('.loadmore_msg').remove();
		}
        api.check_status = check_status;
        api.post = function(url, data, callback, failedcb) {
            $.ajax({
                type: 'POST',
                url: url,
                data: JSON.stringify(data),
                success: function(data) {
                    check_status(data, callback, failedcb);
                },
                error: function(xhr) {
                   errorHandle();
                }
            });
        };
        api.put = function(url, data, callback) {
            $.ajax({
                type: 'PUT',
                url: url,
                data: JSON.stringify(data),
                success: function(data) {
                    check_status(data, callback);
                },
                error: function(xhr) {
                   errorHandle();
                },		
                dataType: 'JSON'
            });
        };
        api.get = function(url, data, callback, failedcb, errorHandle) {
            $.ajax({
                type: 'GET',
                url: url + '?' + $.param(data),
				dataType: 'JSON',
                success: function(data) {
                    check_status(data, callback, failedcb);
                },
                error: function(xhr) {
                    failedcb();
                }
            });
        };
        api.del = function(url, data, callback) {
            $.ajax({
                type: 'DELETE',
                url: url + '?' + $.param(data),
                success: function(data) {
                    check_status(data, callback);
                },
				error: function(xhr) {
                    errorHandle();
                //  if (failedcb) failedcb(xhr['status']);
                },
                dataType: 'JSON'
            });
        };
        return api;
    }
};

var DocumentAPI = {
    createNew: function() {
        var api = LWAPI.createNew();
        api.get_share = function(user_id, cb) {
            var url = '/lwork/documents';
            var data = {uuid: user_id};
            api.get(url, data, cb);
        };
        api.upload = function(form, cb) {
            form.ajaxSubmit({
                clearForm: true,
                url: '/lw_upload.yaws',
                dataType:'JSON',
                success: function(data) {
                    api.check_status(data, cb);
                },
                error: function(xhr) {
                 //   console.log(xhr);
                }
            });
        };
        api.make_download_link = function(fid) {
            return '/lw_download.yaws?fid=' + fid;
        };
        api.share = function(user_id, doc_id, targets, cb) {
            var url = '/lwork/documents/' + doc_id + '/shares';
            var data = {uuid: user_id, targets:targets};
            api.put(url, data, cb);
        };	
        return api;
    }
}

var GroupAPI = {
    createNew: function() {
        var api = LWAPI.createNew();
        api.list_groups = function(owner_id, cb) {
            var url = '/lwork/groups';
            var data = {owner_id: owner_id};
            api.get(url, data, cb);
        };
        api.get_members = function(owner_id, group_id, cb) {
            var url = '/lwork/groups/' + group_id.toString() + '/members';
            var data = {owner_id: owner_id, 't':new Date().getTime()};
            api.get(url, data, cb);
        };
		
        api.create_group = function(owner_id, group_name, group_attr, cb) {
            var data = {owner_id:owner_id, name:group_name, attribute:group_attr, 't':new Date().getTime()};
            var url = '/lwork/groups';
            api.post(url, data, cb);
        };
        api.delete_group = function(owner_id, group_id, cb) {
           var data = {owner_id:owner_id, group_id:group_id, 't':new Date().getTime()};
           var url = '/lwork/groups';
           api.del(url, data, cb);
        };
        api.add_members = function(owner_id, group_id, member_ids, cb) {
            var data = {owner_id:owner_id, member_ids:member_ids};
            var url = '/lwork/groups/' + group_id.toString() + '/members';
            api.post(url, data, cb);
        };
        api.delete_members = function(owner_id, group_id, member_ids, cb) {
            var data = {owner_id:owner_id, member_ids:member_ids};
            var url = '/lwork/groups/' + group_id.toString() + '/members';
            api.del(url, data, cb);
        };
        api.rename_group = function(owner_id, group_id, new_name, cb) {
            var data = {owner_id:owner_id, name:new_name};
            var url = '/lwork/groups/' + group_id.toString();
            api.put(url, data, cb);
        };
        return api;
    }
};


var ContentAPI = {
    createNew: function() {
        var api = LWAPI.createNew();
        api.interval = function(user_id, cb, failedcb, errorHandle) {
            var url = '/lwork/updates';
            var data = {uuid: user_id, 't':new Date().getTime()};
            api.get(url, data, cb ,failedcb, errorHandle);
        };
	    api.publish = function(mode, opt, cb) {     
            var url = '/lwork/'+mode;
            api.post(url, opt, cb);
        };
		api.load_msg = function(mode, uuid ,type , status , page_index, page_num , cb, error){
	        var data = {uuid:uuid, type:type, status:status,  page_index:page_index,  page_num:page_num, 't':new Date().getTime()};	
			var url = '/lwork/' + mode;
            api.get(url, data, cb, error);
		};
	    api.load_comt = function(mode, opt, cb){	    
			var url = '/lwork/'+ mode +'/replies';
            api.get(url, opt, cb);
		};
	    api.load_dialog = function(mode, opt, cb){	    
			var url = '/lwork/'+ mode +'/dialog';
            api.get(url, opt, cb);
		};		
	    api.setstatus = function(msg_id, uuid, value, cb) {			
            var url = '/lwork/tasks/' + msg_id + '/status';			
            var data = {uuid: uuid, value:value, 't':new Date().getTime()};
            api.put(url, data, cb);
        };
	    api.votestatus = function(msg_id, uuid, choice, cb) {			
            var url = '/lwork/polls/' + msg_id;			
            var data = {uuid: uuid, choice:choice, 't':new Date().getTime()};
            api.put(url, data, cb);
        };	
	   api.voteresult = function(entity_id, uuid, cb) {		   		
            var url = '/lwork/polls/results';			
            var data = {uuid: uuid, entity_id:entity_id, 't':new Date().getTime()};
            api.get(url, data, cb);			
        };		
	    api.sendreplies = function(mode, msg_id, uuid, content, to ,index , cb) {
            var url = '/lwork/'+ mode +'/' + msg_id + '/replies';
            var data = {uuid: uuid, content:content, to:to ,index:index, 't':new Date().getTime()};
            api.post(url, data, cb);
        };	
		api.msginvite = function(mode, msg_id, uuid, new_members, cb) {
            var url = '/lwork/'+ mode +'/' + msg_id + '/members';
            var data = {uuid: uuid, new_members:new_members, 't':new Date().getTime()};
            api.post(url, data, cb);
        };	
		api.tasktrace = function(mode, msg_id, uuid, cb) {
            var url = '/lwork/'+ mode +'/' + msg_id + '/traces';
            var data = {uuid: uuid, 't':new Date().getTime()};
            api.get(url, data, cb);
        };
		
		api.setpersonalinfo = function(uuid, department,mail , phone , cb) {
            var url = '/lwork/settings/profile';
            var data = {uuid: uuid, department: department, mail: mail, phone: phone, 't':new Date().getTime()};
            //console.log(JSON.stringify(data));
            api.put(url, data, cb);
        };		
		api.updatephoto = function(uuid, photo  , cb) {
            var url = '/lwork/settings/photo';
            var data = {uuid: uuid, photo: photo, 't':new Date().getTime()};
            api.put(url, data, cb);
        };						
		api.modifypassword = function(uuid, company, account, old_pass , new_pass , cb) {
            var url = '/lwork/settings/password';
            var data = {uuid:uuid, company: company, account: account, old_pass: old_pass, new_pass: new_pass, 't':new Date().getTime()};
            api.put(url, data, cb);
        };
							
		api.loadnewcomt = function(mode, uuid, cb) {
            var url = '/lwork/'+ mode +'/replies/unread';
            var data = {uuid: uuid, 't':new Date().getTime()};
            api.get(url, data, cb);
        };
		api.accptvideo = function(uuid, cb) {
            var url = '/lwork/videos/invited';
            var data = {uuid: uuid, 't':new Date().getTime()};
            api.get(url, data, cb);
        };
        api.del= function(uuid, items, cb) {
            var url = '/lwork/recycle';
            var data = {uuid: uuid, action:"delete", items:items};
            api.put(url, data, cb);
        };
        api.recover = function(uuid, items, cb) {
            var url = '/lwork/recycle';
            var data = {uuid: uuid, action:"recover", items:items};
            api.put(url, data, cb);
        };
        api.remove = function(uuid, items, cb) {
            var url = '/lwork/recycle';
            var data = {uuid: uuid, action:"remove", items:items};
            api.put(url, data, cb);
        };
        api.search = function(uuid, type, keyword, cb, failedcb){
            var url = '/lwork/search'
            var data = {uuid: uuid, type:type, keyword:keyword};
            api.get(url, data, cb, failedcb);
        };
        api.SearchSalary = function( year, month, cb, failedcb){
            var url = ' /lwork/settings/salary'
            var data = {uuid: uuid, year:year, month:month};
            api.get(url, data, cb, failedcb);
        };					
        return api;
    }
}

var MeetingAPI = {
    createNew: function() {
        var api = LWAPI.createNew();
        api.start = function(uuid, group_id ,subject, members, cb, failedcb) {
            var url = '/lwork/voices/meetings';
            var data = {uuid: uuid, group_id: group_id, subject: subject,
                members: members, 't':new Date().getTime()};
            api.post(url, data, cb, failedcb);
        };
        api.stopmeeting = function(uuid, meeting_id, cb) {
            var url = '/lwork/voices/meetings/' + meeting_id;
            var data = {uuid: uuid, 't':new Date().getTime()};
            api.del(url, data, cb);
        };
        api.get_info = function(uuid, cb, error) {
            var url = '/lwork/voices/meetings';
            var data = {uuid:uuid, status:'active', 't':new Date().getTime()};
            api.get(url, data, cb, error);
        };
        api.get_status = function(uuid, meeting_id, cb) {
            var url = '/lwork/voices/meetings/' + meeting_id + '/status';
            var data = {uuid: uuid, 't':new Date().getTime()};
            api.get(url, data, cb);
        };
        api.add_member = function(uuid, meeting_id, name, phone, cb, failedcb) {
            var url = '/lwork/voices/meetings/' + meeting_id + '/members';
            var data = {uuid:uuid, name: name, phone: phone, 't':new Date().getTime()};
            api.post(url, data, cb, failedcb);
        };
        api.redial = function(uuid, meeting_id, member_id, cb) {
            var url = sprintf('/lwork/voices/meetings/%s/members/%s', meeting_id,
                    member_id);
            var data = {uuid:uuid, status: 'online', 't':new Date().getTime()};
            api.put(url, data, cb);
        };
        api.hangup = function(uuid, meeting_id, member_id, cb) {
            var url = sprintf('/lwork/voices/meetings/%s/members/%s', meeting_id,
                    member_id);
            var data = {uuid:uuid, status: 'offline', 't':new Date().getTime()};
            api.put(url, data, cb);
        };		
        api.history = function(uuid, year, month, cb) {
            var url = '/lwork/voices/meetings/cdrs';
            var data = {uuid:uuid, year: year, month: month, 't':new Date().getTime()};
            api.get(url, data, cb);
        };
        return api;
    }
}

var SMSAPI = {
    createNew: function(){
        var api = LWAPI.createNew();
        api.send = function(uuid, receivers, msg, sig, cb, failedcb){
            var url = '/lwork/sms';
            var data = {uuid:uuid, members:receivers, content:msg, signature:sig};
            api.post(url, data, cb, failedcb);
        };
        api.history = function(uuid, cb){
            var url = '/lwork/sms';
            var data = {uuid:uuid};
            api.get(url, data, cb);
        }
        return api;
    }
}

var VoipAPI = {
    createNew: function(){
        var api = LWAPI.createNew();
        api.start = function(uuid, SDP, phone, cb, failedcb){
            var url = '/lwork/voices/voip';
            var data = {uuid:uuid, sdp:SDP, phone:phone};
            api.post(url, data, cb, failedcb);
        };
        api.stop = function(uuid, sessionID, cb){
            var url = '/lwork/voices/voip';
            var data = {uuid:uuid, session_id:sessionID};
            api.del(url, data, cb);
        };
        api.get_status = function(uuid, sessionID, cb){
            var url = '/lwork/voices/voip/status';
            var data = {uuid:uuid, session_id:sessionID};
            api.get(url, data, cb);
        };
        api.dtmf = function(uuid, sessionID, dtmfList, cb){
            var url = '/lwork/voices/voip/dtmf';
            var data = {uuid:uuid, session_id:sessionID, dtmf:dtmfList};
            api.post(url, data, cb);
        }
        return api;
    }
}

var videoAPI = {
    createNew: function(){
        var api = LWAPI.createNew();

        api.startP2P = function(uuid, sdp, peerUUID, cb, failedcb){
            var url = '/lwork/video';
            var data = {uuid:uuid, sdp:sdp, to_uuid:peerUUID};
            api.post(url, data, cb, failedcb);
        };

        api.endP2P = function(uuid, peerUUID, cb){
            var url = '/lwork/video';
            var data = {uuid:uuid, peer_uuid:peerUUID};
            api.del(url, data, cb);
        };

        api.acceptP2P = function(uuid, sdp, peerUUID, rcv_pid, cb, failedcb){
            var url = '/lwork/video';
            var data = {uuid:uuid, sdp:sdp, from_uuid:peerUUID, revc_pid:rcv_pid};
            api.put(url, data, cb, failedcb);
        }

        api.startMP = function(uuid, sdp, members, cb, failedcb){
            var url = '/lwork/mvideo';
            var data = {uuid:uuid, sdp:sdp, members:members};
            //console.log(JSON.stringify(data));
            api.post(url, data, cb, failedcb);
        };
        api.endMP = function(uuid, roomNo, cb){
            var url = '/lwork/mvideo';
            var data = {uuid:uuid, room:roomNo};
            api.del(url, data, cb);
        };
        api.invite = function(uuid, guestUUID, guestPos, roomNo, cb){
            var url = '/lwork/mvideo/members'
            var data = {uuid:uuid, position:guestPos, guest:guestUUID, room:roomNo};
            api.put(url, data, cb);
        };
        api.enterMP = function(uuid, sdp, roomNo, pos, cb, failedcb){
            var url = sprintf('/lwork/mvideo/%s', roomNo);
            var data = {uuid:uuid, sdp:sdp, position:pos};
            //console.log(JSON.stringify(data));
            api.put(url, data, cb, failedcb);
        };
        api.leaveMP = function(uuid, roomNo, cb){
            var url = sprintf('/lwork/mvideo/%s', roomNo);
            var data = {uuid:uuid};
            api.del(url, data, cb);
        };
        api.get_roomInfo = function(uuid, roomNo, cb, failedcb){
            var url = '/lwork/mvideo/status';
            var data = {uuid:uuid, room:roomNo};
            //console.log("get_roomInfo:"+JSON.stringify(data));
            api.get(url, data, cb, failedcb);
        };
        api.get_my_ongoing = function(uuid, cb){
            var url = "/lwork/mvideo/ongoing";
            var data = {uuid:uuid};
            api.get(url, data, cb)
        };

        return api;
    }
}

var FocusAPI = {
    createNew: function(){
        var api = LWAPI.createNew();
        api.setFocus = function(uuid, items, cb){
            var url = '/lwork/focus/entities';
            var data = {uuid:uuid, items:items};
            api.post(url, data, cb);
        };
        api.cancelFocus = function(uuid, type, targetEntityID, cb){
            var url = sprintf('/lwork/focus/entities/%s/%s', type, targetEntityID);
            var data = {uuid:uuid, type:type, entigy_id:targetEntityID};
            api.del(url, data, cb);
        };

        return api;
    }
}

var IMAPI = {
    createNew: function(){
        var api = LWAPI.createNew();
        api.createSession = function(uuid, members, cb, failedcb){
            var url = '/lwork/im/sessions';
            var data = {uuid:uuid, members:members};
            api.post(url, data, cb, failedcb);
        };
        api.invite = function(uuid, sessionID, members, cb, failedcb){
            var url = sprintf('/lwork/im/session/%s/members', sessionID);
            var data = {uuid:uuid, members:members};
            api.post(url, data, cb);
        };
        api.sendmsg = function(uuid, sessionID, content, cb, failedcb){
            var url = sprintf('/lwork/im/session/%s/messages', sessionID);
            var data = {uuid:uuid, content:content};
            api.post(url, data, cb, failedcb);
        };
        api.leave = function(uuid, sessionID, cb){
            var url = sprintf('/lwork/im/session/%s/members', sessionID);
            var data = {uuid:uuid};
            api.del(url, data, cb);
        }

        return api;
    }
}


var api = {
    group: GroupAPI.createNew(),
    request:LWAPI.createNew(),
    file: DocumentAPI.createNew(),
    content:ContentAPI.createNew(),
    meeting: MeetingAPI.createNew(),
    focus: FocusAPI.createNew(),
    sms:SMSAPI.createNew(),
    voip:VoipAPI.createNew(),
    video:videoAPI.createNew(),
    im:IMAPI.createNew()
}
