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
                url: url,
                data: JSON.stringify(data),
                beforeSend: function () { $("#ajax_loading").show(); },
                success: function(data) {
                    $("#ajax_loading").hide();
                    check_status(data, callback, failedcb);
                },
                error: function(xhr) {
                    $("#ajax_loading").hide();
                  //  console.log(xhr);
                }
            });
        };
        api.put = function(url, data, callback) {
            $.ajax({
                type: 'PUT',
                url: url,
                data: JSON.stringify(data),
                beforeSend: function () { $("#ajax_loading").show(); },
                success: function(data) {
                    $("#ajax_loading").hide();
                    check_status(data, callback);
                },
                dataType: 'JSON'
            });
        };
        api.get = function(url, data, callback, failedcb) {
            $.ajax({
                type: 'GET',
                url: url + '?' + $.param(data),
				dataType: 'JSON',
                beforeSend: function () { $("#ajax_loading").show(); },
                success: function(data) {
                    $("#ajax_loading").hide();
                    check_status(data, callback, failedcb);
                },
                error: function(xhr) {
                 //   console.log(xhr);
                    $("#ajax_loading").hide();
                    if (failedcb) failedcb(xhr['status']);
                }
            });
        };
        api.del = function(url, data, callback, failedcb) {
            $.ajax({
                type: 'DELETE',
                url: url + '?' + $.param(data),
                beforeSend: function () { $("#ajax_loading").show(); },
                success: function(data) {
                    $("#ajax_loading").hide();
                    check_status(data, callback, failedcb);
                },
                dataType: 'JSON'
            });
        };
        return api;
    }
};

var _api = LWAPI.createNew();
var api = {
    godLogin: function(user, password, cb, failedcb){
        var url = '/lwork/god/login';
        var data = {user:user, password:password};
        console.log('adminLogin, data=='+JSON.stringify(data));
        _api.post(url, data, cb, failedcb);
    },
    godLogout: function(user, cb){
        var url = '/lwork/god/logout';
        var data = {user:user};
        console.log('adminLogout, data=='+JSON.stringify(data));
        _api.post(url, data, cb);
    },
    godModPW: function(user, token, oldPW, newPW, cb){
        var url = '/lwork/god/modpw';
        var data = {user:user, old_pass:oldPW, new_pass:newPW};
        console.log('adminModPW, data=='+JSON.stringify(data));
        _api.put(url, data, cb);
    },
    loadOrgs: function(user, token, cb){
        var url = '/lwork/orgs';
        var data = {}
        console.log('loadOrgs,url=='+url);
        _api.get(url, data, cb);
    },
    addOrg: function(user, token, orgInfo, cb){
        var url = sprintf('/lwork/orgs/%s/%s', orgInfo.full_name, orgInfo.mark_name);
        var data = {};
        console.log('addOrg, url=='+url);
        _api.post(url, data, cb);
    },
    modMarkName: function(user, token, orgId, newMarkName, cb){
        var url = sprintf('/lwork/%s/markname/%s', orgId, newMarkName);
        var data = {};
        console.log('modMarkName, url=='+url);
        _api.put(url, data, cb);
    },
    modFullName: function(user, token, orgId, newFullName, cb){
        var url = sprintf('/lwork/%s/fullname/%s', orgId, newFullName);
        var data = {};
        console.log('modFullName, url=='+url);
        _api.put(url, data, cb);
    },		
    modComItem: function(orgId, MCM, MVR, MC, MM, cb){		
        var url = sprintf('/lwork/%s/license', orgId);
        var data =    {max_conf_members:MCM,  max_vconf_rooms:MVR,  max_cost:MC, max_members:MM};
        _api.put(url, data, cb);
    },		
    resetAdminPW: function(user, token, orgId, cb){
        var url = sprintf('/lwork/%s/admin', orgId);
        var data = {};
        console.log('resetAdminPW, url=='+url);
        _api.put(url, data, cb);
    },
    delOrgs: function(user, token, orgList, cb, failedcb){
        var url = sprintf('/lwork/orgs/%s', orgList[0]);
        var data = {};
        console.log('delOrg, url=='+url);
        _api.del(url, data, cb, failedcb);
    }
}
