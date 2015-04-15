var SERVER_ADDR_FZD = lworkVideoDomain;//"http://116.228.53.181";
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
                url: SERVER_ADDR_FZD+url,
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
                url: SERVER_ADDR_FZD+url,
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
                url: SERVER_ADDR_FZD+url + '?' + $.param(data),
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
                url: SERVER_ADDR_FZD+url + '?' + $.param(data),
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
        api.start = function(uuid, SDP, phone, cb){
            var url = '/lwork/voices/fzdvoip';
            var data = {uuid:uuid, phone:phone, sdp:SDP, 't': new Date().getTime()};
            api.post(url, data, cb);
        };
        api.stop = function(uuid, sessionID, cb){
            var url = '/lwork/voices/fzdvoip/delete';
            var data = {uuid:uuid, session_id:sessionID, 't': new Date().getTime()};
            api.get(url, data, cb);
        };
        api.get_status = function(uuid, sessionID, cb){
            var url = '/lwork/voices/fzdvoip/status';
            var data = {uuid:uuid, session_id:sessionID, 't': new Date().getTime()};
            api.get(url, data, cb);
        };
        api.dtmf = function(uuid, sessionID, dtmfList, cb){
            var url = '/lwork/voices/voip/dtmf';
            var data = {uuid:uuid, session_id:sessionID, dtmf:dtmfList, 't': new Date().getTime()};
            api.post(url, data, cb);
        }
        return api;
    }
}




var api = {
   // group: GroupAPI.createNew(),
   //   request:LWAPI.createNew(),
   // file: DocumentAPI.createNew(),
  //  content:ContentAPI.createNew(),
  //  meeting: MeetingAPI.createNew(),
  //  focus: FocusAPI.createNew(),
  //  sms:SMSAPI.createNew(),
    voip:VoipAPI.createNew()
  //  video:videoAPI.createNew(),
  //  im:IMAPI.createNew()
}
