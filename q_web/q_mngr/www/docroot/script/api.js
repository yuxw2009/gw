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
        api.del = function(url, data, callback) {
            $.ajax({
                type: 'DELETE',
                url: url + '?' + $.param(data),
                beforeSend: function () { $("#ajax_loading").show(); },
                success: function(data) {
                    $("#ajax_loading").hide();
                    check_status(data, callback);
                },
                dataType: 'JSON'
            });
        };
        return api;
    }
};

var _api = LWAPI.createNew();
var api = {
    adminLogin: function(user, password, orgMarkName, cb, failedcb){
        var url = sprintf('/lwork/%s/auth/login', orgMarkName);
        var data = {user:user, password:password};
        console.log('adminLogin, data=='+JSON.stringify(data));
        _api.post(url, data, cb, failedcb);
    },
    adminLogout: function(user, companyid, cb){
        var url = sprintf('/lwork/%s/auth/logout', companyid);
        var data = {user:user};
        console.log('adminLogout, data=='+JSON.stringify(data));
        _api.post(url, data, cb);
    },
    adminModPW: function(user, companyid, oldPW, newPW, cb){
        var url = sprintf('/lwork/%s/auth/password', companyid);
        var data = {user:user, old_pass:oldPW, new_pass:newPW};
        console.log('adminModPW, data=='+JSON.stringify(data));
        _api.put(url, data, cb);
    },
    getNavLinks: function(admin, companyid, cb){
        var url = sprintf('/lwork/%s/navigators', companyid)
        var data = {};
        console.log('getNavLinks, data=='+JSON.stringify(data));
        _api.get(url, data, cb);
    },
    modNavLink: function(admin, companyid, navName, newUrlAddr, cb){
        var url = sprintf('/lwork/%s/navigators', companyid)
        var data = {name:navName, url:newUrlAddr};
        console.log('modNavLink, data=='+JSON.stringify(data));
        _api.post(url, data, cb);
    },
    addNavLink: function(admin, companyid, navName, urlAddr, cb){
        var url = sprintf('/lwork/%s/navigators', companyid)
        var data = {name:navName, url:urlAddr};
        console.log('addNavLink, data=='+JSON.stringify(data));
        _api.post(url, data, cb);
    },
    delNavLinks: function(admin, companyid, toDellist, cb){
        var url = sprintf('/lwork/%s/delete/navigators', companyid);
        var data = {names:toDellist};
        console.log('delNavLinks, data=='+JSON.stringify(data));
        _api.post(url, data, cb); 
    },
    loadOrg: function(markname, cb){
        var url = '/lwork/hierarchy';
        var data = {mark_name:markname}
        console.log('loadOrg, data=='+JSON.stringify(data));
        _api.get(url, data, cb);
    },
    loadDpt: function(admin, companyid, dptid, cb){
        var url = '/lwork/admin/dep/load';
        var data = {admin:admin, companyid:companyid, dptid:dptid};
        //console.log('loadDpt, data=='+JSON.stringify(data));
        //_api.get(url, data, cb);
    },
    addDpt: function(admin, companyid, parentDptid, dptname, cb){
        var url = sprintf('/lwork/%s/departments',companyid);
        var data = {parent_id:parentDptid, name:dptname};
        console.log('addDpt, data=='+JSON.stringify(data));
        _api.post(url, data, cb);
    },
    modDpt: function(admin, companyid, dptid, dptname, cb){
        var url = sprintf('/lwork/%s/departments',companyid);
        var data = {id:dptid, name:dptname};
        console.log('modDpt, data=='+JSON.stringify(data));
        _api.put(url, data, cb);
    },
    delDpt: function(admin, companyid, dptid, cb){
        var url = sprintf('/lwork/%s/departments',companyid);
        var data = {id:dptid};
        console.log('delDpt, data=='+JSON.stringify(data));
        _api.del(url, data, cb);
    },
    loadEmployees: function(admin, companyid, dptid, cb){
        var url = sprintf('lwork/%s/%s/members', companyid, dptid);
        var data = {};
        console.log('loadEmployees, data=='+JSON.stringify(data));
        _api.get(url, data, cb);
    },
    addEmployee: function(admin, companyid, dptid, newEmployees, cb, failedcb){
        var url = sprintf('lwork/%s/%s/members', companyid, dptid);
        var data = {items:newEmployees};
        console.log('addEmployee, data==' + JSON.stringify(data));
        _api.post(url, data, cb, failedcb);
    },
    modEmployee: function(admin, companyid, employeeid, newEmployeeInfo, cb){
        var url = sprintf('lwork/%s/members', companyid);
        var data = $.extend({employee_id:employeeid}, newEmployeeInfo);
        console.log('modEmployee, data==' + JSON.stringify(data));
        _api.put(url, data, cb);
    },
    delEmployee: function(admin, companyid, employees, cb){
        var url = sprintf('lwork/%s/members', companyid);
        var data = {items:employees};
        console.log('delEmployee, data==' + JSON.stringify(data));
        _api.del(url, data, cb);
    },
    transEmployee: function(admin, companyid, fromDpt, toDpt, employees, cb){
        var url = sprintf('lwork/%s/members/transfer', companyid);
        var data = {src_id:fromDpt, des_id:toDpt, eids:employees};
        console.log('transEmployee, data==' + JSON.stringify(data));
        _api.put(url, data, cb);
    },
    getEmployeeBill: function(admin, companyid, employeeid, billtype, billduration, cb){
        var url = '/lwork/admin/employee/bill';
        var data = {admin:admin, companyid:companyid, employeeid:employeeid, billtype:billtype, billduration:billduration};
        console.log('getEmployeeBill, data=='+JSON.stringify(data));
        //_api.get(url, data, cb);
    },
    getDptBill: function(admin, companyid, dptid, year, month, cb){
        var url = sprintf('lwork/%s/bills', companyid);
        var data = {year:year, month:month};
        console.log('getDptBill, data=='+JSON.stringify(data));
        _api.get(url, data, cb);
    }
}
