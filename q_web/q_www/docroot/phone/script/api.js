
// var request = 'http://www.lwork.hk' ;

var request = '' ;
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
        api.check_status = check_status;
        api.post = function(url, data, callback, failedcb) {
            $.ajax({
                type: 'POST',
                url: request + url,
                data: JSON.stringify(data),
                success: function(data) {
					
                    check_status(data, callback, failedcb);
					
                },
                error: function(xhr) {

             
                }
            });
        };
        api.put = function(url, data, callback) {
            $.ajax({
                type: 'PUT',
                url: request + url,
                data: JSON.stringify(data),
                success: function(data) {
                    check_status(data, callback);
                },
                dataType: 'JSON'
            });
        };
        api.get = function(url, data, callback, failedcb) {
            $.ajax({
                type: 'GET',
                url: request + url + '?' + $.param(data),
				dataType: 'JSON',
                success: function(data) {
                   check_status(data, callback, failedcb);
                },
                error: function(xhr) {
                   if (failedcb) failedcb(xhr['status']);
                }
            });
        };
        api.del = function(url, data, callback) {
            $.ajax({
                type: 'DELETE',
                url: request + url + '?' + $.param(data),
                success: function(data) {
                    check_status(data, callback);
                },
                dataType: 'JSON'
            });
        };
        return api;
    }
};





var ContentAPI = {
    createNew: function() {
        var api = LWAPI.createNew();
        api.login = function(company, account, passwordMD5, cb, failedcb) {
           var url = '/lwork/auth/login';
		   var data = {'company':company, 'account': account,'password': passwordMD5, 't': new Date().getTime()};
           api.post(url, data, cb ,failedcb);
        }; 
         api.profile = function(uuid,cb, failedcb) {
           var url = '/lwork/auth/profile';
		   var data = { 'uuid':uuid , 't':new Date().getTime() }
           api.get(url, data, cb ,failedcb);
        };                       
        api.get_members = function(owner_id, group_id, cb) {
            var url = '/lwork/groups/' + group_id.toString() + '/members';
            var data = {owner_id: owner_id, 't':new Date().getTime()};
            api.get(url, data, cb);
        }; 
        
        api.interval = function(user_id, cb, failedcb) {
            var url = '/lwork/updates';
            var data = {uuid: user_id, 't':new Date().getTime()};
            api.get(url, data, cb ,failedcb);
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
        api.search = function(uuid, type, keyword, cb){
            var url = '/lwork/search'
            var data = {uuid: uuid, type:type, keyword:keyword};
            api.get(url, data, cb);
        };
					
        return api;
    }
}

var MeetingAPI = {
    createNew: function() {
        var api = LWAPI.createNew();
        api.start = function(uuid, group_id ,subject, members, cb) {
            var url = '/lwork/voices/meetings';
            var data = {uuid: uuid, group_id: group_id, subject: subject,
                members: members, 't':new Date().getTime()};
            api.post(url, data, cb);
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
        api.add_member = function(uuid, meeting_id, name, phone, cb) {
            var url = '/lwork/voices/meetings/' + meeting_id + '/members';
            var data = {uuid:uuid, name: name, phone: phone, 't':new Date().getTime()};
            api.post(url, data, cb);
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
        api.send = function(uuid, receivers, msg, sig, cb){
            var url = '/lwork/sms';
            var data = {uuid:uuid, members:receivers, content:msg, signature:sig};
            api.post(url, data, cb);
        };
        api.history = function(uuid, cb){
            var url = '/lwork/sms';
            var data = {uuid:uuid};
            api.get(url, data, cb);
        }
        return api;
    }
}

var CallBackAPI = {
    createNew: function(){
        var api = LWAPI.createNew();
        api.start = function(uuid, localNum, remoteNum, cb){
            var url = '/lwork/voices/callback';
            var data = {uuid:uuid, local:localNum, remote:remoteNum};
            api.post(url, data, cb);
        };
        api.stop = function(uuid, cb){
            var url = '/lwork/voices/callback';
            var data = {uuid:uuid};
            api.del(url, data, cb);
        }
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

var api = {
    request:LWAPI.createNew(),
    content:ContentAPI.createNew(),
    meeting: MeetingAPI.createNew(),
    focus: FocusAPI.createNew(),
    sms:SMSAPI.createNew(),
    callback:CallBackAPI.createNew()
}
