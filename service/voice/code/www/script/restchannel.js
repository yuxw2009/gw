var RestChannel = {
    init : function() {
	},
	check_status : function(data, cb, failedcb) {
		var status = data['status'];
		if (status == 'ok') {
			cb(data);
		} else {
			if(failedcb) failedcb(data);
		}
	},
    post : function(url, data, callback,failcb) { 
        RestChannel.act('POST', url, data, callback,failcb); 
    },
    delete : function(url, data, callback,failcb) { 
        RestChannel.act('DELETE', url, data, callback,failcb); 
    },
    put : function(url, data, callback,failcb) { 
        RestChannel.act('PUT', url, data, callback,failcb); 
    },
    get : function(url, data, callback,failcb) { 
        RestChannel.act('GET', url, data, callback,failcb); 
    },
	act : 	function(method, url, data, callback,failcb) {
		$.ajax({
			type: method,
			url: url,
			data: JSON.stringify(data),
			success: function(data) {
				RestChannel.check_status(data, callback,failcb);
			},
			error: function(xhr) {
			  //  console.log(xhr);
              failcb(xhr);
			}
		});
	}
};