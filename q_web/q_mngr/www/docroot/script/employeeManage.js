 // JavaScript Document

function auth2str(auth){return (auth === 'enable') ? '开通' : '取消';}
function str2auth(str){return (str === '开通')? 'enable' : 'disable';}

function correctPhoneNumber(phone) {
    phone = phone.replace(/-/g, "");
    phone = phone.replace(/ /g, "");
    phone = phone.replace(/\(/g, "");
    phone = phone.replace(/\)/g, "");
    phone = phone.replace("+", "00");
    if (phone.substring(0, 2) == "00") {
        return phone;
    }
    if (phone[0] == "0") {
        return "0086" + phone.substring(1);
    }
    return "0086" + phone;
};
var totips = function (obj, width, txt, top, left) {
    var offset, top, left;
    offset = obj.offset();
    obj.length > 0 ? top = parseInt(offset.top) - top : top = 123;
    obj.length > 0 ? left = parseInt(offset.left) - left : left = 50;
    obj.focus();
    $('#totips').text(txt).css({ top: top + 'px', width: width + 'px', left: left + 'px' }).show();
    $('#floatCorner_top').css({ top: top + 26 + 'px',  left: left + 50 + 'px' }).show();
    obj.keyup(function(){
        $('#totips').hide();
        $('#floatCorner_top').hide();
    });     
};
var mobile_test = function (str) {
    var reg = /^(([+]{1}|(0){2})(\d){1,3})?((\d){10,15})+$/;
    return reg.test(str);
};

(function ($) {
    var adminUser = parent.adminUser;
	var companyid = parent.companyid;
	var departmentid = parent.departmentid;
	var modEmployee = parent.modifyingEmployee;
	//var modEmployee = {'name':'未指定', 'employeeid':'未指定', 'phone':'', 'email':'', 'balance':'100', 'service':{'voip':'enable', 'phoneconf':'enable', 'sms':'enable', 'dataconf':'disable'}};
	var checkMobileNum = function(mblNumObj){
        var mblNumStr = mblNumObj.val();        

        if(''!==mblNumStr){          
            mblNumStr = correctPhoneNumber(mblNumStr);                
            var a = mobile_test(mblNumStr);
            if (!a) {
                mblNumObj.focus();
                totips(mblNumObj, 250, '请输入正确的手机号（包含国家码）！', 31, 50);
                return false;
            }   
        }
        return true;
    };

    var blurMobile = function () {
        checkMobileNum($(this));
		return false;				
    };

	Array.prototype.indexOf = function(val) {
		for (var i = 0; i < this.length; i++) {
			if (this[i] == val) return i;
		}
		return -1;
	};		
	Array.prototype.remove = function(val) {
			var index = this.indexOf(val);
			if (index > -1) {
				this.splice(index, 1);
			}
	};

    // 搜索框插件			   
    $.fn.addMember = function (options) {
        var defaults = {
            personsName: ".personsName",
            jobNumber: ".jobNumber",
            defaultPassword: ".defaultPassword",
            mobileNumber: ".mobileNumber",
            emailAddr:".emailAddr",
            monthLimit: ".monthLimit",
            cancel: "#cancel",
            addSubmit: "#addSubmit"
        },
        params = $.extend(defaults, options || {}),
	    _this = $(this);

        var clone2TableTail = function(){
            _this.find('tbody').find('tr:last').clone().appendTo(_this.find('tbody'));
            _this.find('tbody').find(params.personsName + ':last').val('').bind('focus', focushandle);
            _this.find('tbody').find(params.jobNumber + ':last').val('').bind('focus', focushandle).bind('blur',blurJobNum);
            _this.find('tbody').find(params.defaultPassword + ':last').val('888888').bind('focus', focushandle);
            _this.find('tbody').find(params.mobileNumber + ':last').val('').bind('focus', focushandle).bind('blur', blurMobile);
            _this.find('tbody').find(params.emailAddr + ':last').val('').bind('focus', focushandle);
        }
        var blurJobNum = function(){
			var obj = $(this);
			var temp = obj.val();
            var inputJobNums = new Array();
            obj.addClass('curEditingJobNum');
            $('tbody').find('.jobNumber').each(function(){
                if($(this).val().length > 0 && !$(this).hasClass('curEditingJobNum')){
                    inputJobNums.push($(this).val());
                }
            });
			for (var i=0; i<inputJobNums.length; i++){
				if(temp===inputJobNums[i]){
	                totips(obj, 150, '该工号已经添加！', 22, -5);
                    obj.removeClass('curEditingJobNum').focus();
			     	return false;
				}
		    }
            obj.removeClass('curEditingJobNum');
			return false;				
        };	
        var focushandle = function(){
            var obj = $(this);
            var current_obj = obj.parent().parent().prev();
            var inputTag = current_obj.find('input');
		   
			if(current_obj.length > 0) {
                inputTag.each(function () {
                    if ('' === $(this).val()) {
						if($(this).attr('add_data')==='personsName' || $(this).attr('add_data')==='jobNumber'){
							totips($(this), 200, '请逐项添加，标*的项不能为空！', 26, 0);
							$(this).focus();
							return false;
						}						
                    }else {
                            if (obj.parent().parent().next().length <= 0) {  
                                clone2TableTail();
                            }
                        if ($(this).attr('class') ==='mobileNumber') {
                            if (checkMobileNum($(this))){
                                current_obj.attr('class','validate');
                            }
                        }
                    }
                })
            }
            return false;
        };

        clone2TableTail();
        $(params.personsName).bind('focus', focushandle);
		$(params.jobNumber).bind('focus', focushandle).bind('blur',blurJobNum);
		$(params.defaultPassword).bind('focus', focushandle);
		$(params.mobileNumber).bind('focus', focushandle).bind('blur', blurMobile);
		$(params.emailAddr).bind('focus', focushandle);
        $(params.cancel).click(function () {
            parent.$.dialog({ id: "addMember" }).close();
        });				
        $(params.addSubmit).die('click').live('click',function () {
			var flag = 1;
            var opt = {}, addItem = new Array(), addItem_obj = {};
            var name = '', jobNumber = '', defaultPassword = '', mobileNumber = '', emailAddr = '', money = '',
                callbackAuth = 'disable', voipAuth = 'disable', phoneconfAuth = 'disable', smsAuth = 'disable', dataconfAuth = 'disable';			
            
            function isJobNumExist(jn){
                for (var i = 0; i < addItem.length; i++){
                    if (addItem[i]['eid'] == jn){
                        return true;
                    }
                }
                return false;
            }
            //遍历table成JSON对象
            _this.find('tbody').find('tr').each(function () {		
                if ('' === $(this).find('input').eq(0).val()) {
                    return false;
                }
                $(this).find('input').each(function (i) {
                    var obj = $(this);
                    var flagValue = obj.val();
                    var currentClass = obj.attr('add_data');
                    if ('' !== flagValue) {
                        switch (currentClass) {
                            case 'personsName':
                                name = flagValue;
                                break;
                            case 'jobNumber':
                                if (isJobNumExist(flagValue)){
                                    totips($(this), 200, '工号不能重复，请修改后再提交！', 26, 0);
                                    flag = 0;
                                }else{
                                    jobNumber = flagValue;
                                }
                                break;
                            case 'defaultPassword':
                                defaultPassword = flagValue;
                                break;
                            case 'emailAddr':
                                emailAddr = flagValue;
                                break;
                            case 'mobileNumber':
                                if (checkMobileNum($(this))){
                                    mobileNumber = flagValue;
                                }else{
                                    flag = 0;
                                }
                                break;
                        }
                    }else{						
					  if($(this).attr('add_data')==='personsName' || $(this).attr('add_data')==='jobNumber'){						
						 $(this).focus();
						 totips($(this), 200, '请逐项添加，标*的项不能为空！', 26, 0);
						 flag = 0;
						 return false;
					  }						
				    }
                });
                money = $(this).find('.monthLimit').find('select').val();
                $(this).find('.serviceAuth').find('select').each(function(Obj){
                    switch ($(this).attr('add_data')){
                        case 'callbackAuth':
                             callbackAuth = str2auth($(this).val());
                             break;
                        case 'voipAuth':
                             voipAuth = str2auth($(this).val());
                             break;
                        case 'phoneconfAuth':
                             phoneconfAuth = str2auth($(this).val());
                             break;
                        case 'smsAuth':
                             smsAuth = str2auth($(this).val());
                             break;
                        case 'dataconfAuth':
                             dataconfAuth = str2auth($(this).val());
                             break;
                    }
                });	
                var phoneJSONstr = {"mobile":(mobileNumber.length > 0) ? correctPhoneNumber(mobileNumber) : "", "pstn":"","extension":"","other":[]};
                addItem_obj = {'name': name, 'eid': jobNumber, 'password':md5(defaultPassword), 'phone': phoneJSONstr, 'email': emailAddr, 'banlance': changeTwoDecimal_f(money),
                               'auth':{'callback':callbackAuth, 'voip':voipAuth, 'phoneconf':phoneconfAuth, 'sms':smsAuth, 'dataconf':dataconfAuth}};
                addItem.push(addItem_obj);
                name = '', jobNumber = '', defaultPassword = '', mobileNumber = '', emailAddr = '', money = '';  
            });

			if(flag===1 && addItem.length > 0){
                api.addEmployee(adminUser, companyid, departmentid, addItem, function(data){
                    var duplicated = data.duplicated;
                    var str = null;
                    if(duplicated.length > 0){
                        str = "以下员工工号：" + duplicated.join("") +"添加失败，原因：已经包含在数据库中！";
                    }
                    window.parent.loadContent_Instance.loadEmployeeContent(departmentid,str);
                    parent.$.dialog({ id: "addMember" }).close();
                }, function(reason){
                    var str = null;
                    if(reason == "out_of_employee"){
                        str = "添加失败，原因：超出授权用户数，请与livecom联系扩容！";
                    }
                    window.parent.loadContent_Instance.loadEmployeeContent(departmentid,str);
                    parent.$.dialog({ id: "addMember" }).close();
                });                
            }
			return false;				
        })
    }
})(jQuery);