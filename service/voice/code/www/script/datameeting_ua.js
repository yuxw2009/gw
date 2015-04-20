// datameeting_ua.js

var Datameeting_UA = {
    createNew : function() {
        var url_ = "/lwork/datameeting/ua";
        var check_status = function(data, cb, failedcb) {
            var status = data['status'];
            if (status == 'ok') {
                cb(data);
            } else {
			    if(failedcb) failedcb(data['reason']);
            }
        };
        var api = {
            put_func : function(url, data, callback) {
                $.ajax({
                    type: 'PUT',
                    url: url,
                    data: JSON.stringify(data),
                    success: function(data) {
                        check_status(data, callback);
                    },
                    dataType: 'JSON'
                });
            };
        };
        api.submit = function(data, callback) {
            api.put_func(url_, data, callback);
        };
        return api;
    }

}