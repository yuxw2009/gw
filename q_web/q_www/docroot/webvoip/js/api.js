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


var VoipAPI = {
    createNew: function(){
        var api = LWAPI.createNew();
        api.start = function(uuid, SDP, phone, cb,failedcb){
            var url = '/lwork/webcall/voip';
            var data = {uuid:uuid, sdp:SDP, phone:phone};
            api.post(url, data, cb, failedcb);
        };
        api.stop = function(uuid, sessionID, cb){
            var url = '/lwork/webcall/voip';
            var data = {uuid:uuid, session_id:sessionID};
            api.del(url, data, cb);
        };
        api.get_status = function(uuid, sessionID, cb, failedcb){
            var url = '/lwork/webcall/voip/status';
            var data = {uuid:uuid, session_id:sessionID};
            api.get(url, data, cb, failedcb);
        };
        api.dtmf = function(uuid, sessionID, dtmfList, cb){
            var url = '/lwork/webcall/voip/dtmf';
            var data = {uuid:uuid, session_id:sessionID, dtmf:dtmfList};
            api.post(url, data, cb);
        };
		api.sendsuggestion = function(uuid, comments, cb, failedcb){
            var url = '/lwork/webcall/voip/comments';
            var data = {uuid:uuid, comments:comments};
            api.post(url, data, cb, failedcb);
		}
        return api;
    }
}


var videoAPI = {
    createNew: function(){
        var api = LWAPI.createNew();
        api.getRooms = function(cb, failedcb){
            var url = '/lwork/webcall/video/room';
            var data = {};
            api.get(url, data, cb, failedcb);
        };
        api.releaseRoom = function(RoomID, cb){
            var url = '/lwork/webcall/video';
            var data = {room:RoomID};
            api.del(url, data, cb);
        };
        api.enterRoom = function(roomID, sdp, cb, failedcb){
            var url = '/lwork/webcall/video?room='+roomID.toString();
            var data = {room:roomID, sdp:sdp};
            api.post(url, data, cb, failedcb);
        };
        api.roomInfo = function(roomID, cb, failedcb){
            var url = '/lwork/webcall/video/status';
            var data = {room:roomID};
            api.get(url, data, cb, failedcb);
        };
        return api;
    }
}


var api = {
    voip:VoipAPI.createNew(),
    video:videoAPI.createNew()
}
