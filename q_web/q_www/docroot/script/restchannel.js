var RestChannel = {
    init : function() {
	},
	check_status : function(data, cb, failedcb) {
		var status = data && data['status'];
		if (status == 'ok') {
			cb(data);
		} else {
			if(failedcb) failedcb(data);
		}
	},
    post : function(url, data, callback,failcb, hint) { 
        RestChannel.act('POST', url, data, callback,failcb); 
    },
    del : function(url, data, callback,failcb, hint) { 
    	var data_str=$.param(data);
    	data_str = data_str.length>0 ? '?'+data_str : '';
    	var url = url+data_str;
        RestChannel.act('DELETE', url, {}, callback,failcb); 
    },
    put : function(url, data, callback,failcb, hint) { 
        RestChannel.act('PUT', url, data, callback,failcb); 
    },
    get : function(mainUrl, data, callback,failcb, hint) { 
    	var data_str=$.param(data);
    	data_str = data_str.length>0 ? '?'+data_str : '';
    	var url = mainUrl+data_str;
        RestChannel.act('GET', url, {}, callback,failcb); 
    },
	act : 	function(method, url, data, callback,failcb, hint) {
		$.ajax({
			type: method,
			url: url,
			data: JSON.stringify(data),
			dataType: 'JSON',
			success: function(data) {
				RestChannel.check_status(data, callback,failcb);
			},
			error: function(xhr) {
              if (failcb) failcb(xhr);
			}
		});
	}
};












