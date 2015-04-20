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
			//LWORK.msgbox.show(lw_lang.ID_REQUEST_ERROR, 5, 1000);	
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
			    dataType: "JSON",
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
                },
                dataType: 'JSON'
            });
        };
        return api;
    }
};

var wcgAPI = {
    createNew: function(){
        var api = LWAPI.createNew();
        api.addWcg = function(Node, Total, cb, failedcb){
            var url = '/wcg/nodes';
            var data = {node: Node, total: Total, 't': new Date().getTime()};
            api.post(url, data, cb, failedcb);
        };
        api.delWcg = function(Node, cb, failedcb){
            var url = '/wcg';
            var data = {'node':Node,'t': new Date().getTime()};
            api.del(url, data, cb, failedcb);
        };
        api.getWcgStatus = function(cb, failedcb){
            var url = '/wcg/stats';
            var data = {'t': new Date().getTime()};
            api.get(url, data, cb, failedcb);
        };


        api.getDkStatus = function(cb, failedcb){
            var url = '/wcg/net_stats';
            var data = {'t': new Date().getTime()};
            api.get(url, data, cb, failedcb);
        };


        return api;
    }
}

var api = {
    wcg:wcgAPI.createNew()
}
