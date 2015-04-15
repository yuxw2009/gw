 // JavaScript Document
(function ($) {
    var adminUser = parent.adminUser;
	var companyid = parent.companyid;
	var departmentid = parent.departmentid;
	var modEmployee = parent.modifyingEmployee;
	//var modEmployee = {'name':'未指定', 'employeeid':'未指定', 'phone':'', 'email':'', 'balance':'100', 'service':{'voip':'enable', 'phoneconf':'enable', 'sms':'enable', 'dataconf':'disable'}};
	
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
		var reg = /^[+]{0,1}(0){2}(\d){1,3}[ ]?([-]?((\d)|[ ]){11})+$/ ;
        return reg.test(str);
    };
	function changeTwoDecimal_f(x){
		var f_x = parseFloat(x);
		if (isNaN(f_x)){
		return x;
		}
		f_x = Math.round(f_x*100)/100;
		var s_x = f_x.toString();
		var pos_decimal = s_x.indexOf('.');
		if (pos_decimal < 0){
		pos_decimal = s_x.length;
		  s_x += '.';
		}
		while (s_x.length <= pos_decimal + 2){
		  s_x += '0';
		}
		return s_x;
	};
    var checkMobileNum = function(mblNumObj){
        var mblNumStr = mblNumObj.val();        

        if(''!==mblNumStr){          
            mblNumStr = correctPhoneNumber(mblNumStr);                
            var a = mobile_test(mblNumStr);
            if (!a) {
                mblNumObj.focus();
                totips(mblNumObj, 220, '请输入正确的手机号（包含国家码）！', 31, 50);
                return false;
            }   
        }
        return true;
    }
    var blurMobile = function () {
        checkMobileNum($(this));
		return false;				
    };

    function auth2str(auth){return (auth === 'enable') ? '开通' : '取消';}
    function str2auth(str){return (str === '开通')? 'enable' : 'disable';}
			

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
	    var inputJobNums = new Array();

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
			var len = inputJobNums.length;				 
			for (var i=0;i<len;i++){
				if(temp===inputJobNums[i]){
	                totips(obj, 130, '该工号已经添加！', 22, -5);
					$(this).focus();
			     	return false;
				}
		    }
			if(''!==obj.val()){			   	
			   inputJobNums.push(temp);			   
			   obj.attr('currentvalue',temp)	
			 }
			   return false;				
        };	
        var focushandle = function(){
            var obj = $(this);
            var current_obj = obj.parent().parent().prev();
            var inputTag = current_obj.find('input');
			var currentvalue;
	        if(obj.attr('class')==='jobNumber'){
				currentvalue= obj.attr('currentvalue');	
                if(''!==currentvalue){
					inputJobNums.remove(currentvalue)
				}
			}
		   
			if(current_obj.length > 0) {
                inputTag.each(function () {
                    if ('' === $(this).val()) {
						if($(this).attr('add_data')==='personsName' || $(this).attr('add_data')==='jobNumber'){
							totips($(this), 170, '请逐项添加,标*的项不能为空！', 26, 0);
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
                voipAuth = 'disable', phoneconfAuth = 'disable', smsAuth = 'disable', dataconfAuth = 'disable';			
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
                                jobNumber = flagValue;
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
						 totips($(this), 170, '请逐项添加,标*的项不能为空！', 26, 0);
						 flag = 0;
						 return false;
					  }						
				    }
                });
                money = $(this).find('.monthLimit').find('select').val();
                $(this).find('.serviceAuth').find('select').each(function(Obj){
                    switch ($(this).attr('add_data')){
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
                addItem_obj = {'name': name, 'eid': jobNumber, 'password':md5(defaultPassword), 'phone': (mobileNumber.length > 0) ? correctPhoneNumber(mobileNumber) : '', 'email': emailAddr, 'banlance': changeTwoDecimal_f(money),
                               'auth':{'voip':voipAuth, 'phoneconf':phoneconfAuth, 'sms':smsAuth, 'dataconf':dataconfAuth}};
                addItem.push(addItem_obj);
                name = '', jobNumber = '', defaultPassword = '', mobileNumber = '', emailAddr = '', money = '';  
            });

			if(flag===1 && addItem.length > 0){
                api.addEmployee(adminUser, companyid, departmentid, addItem, function(data){
                    var duplicated = data.duplicated;
                    if(duplicated.length > 0){
                      var str = "以下员工工号：" + duplicated.join("") +"添加失败，原因：已经包含在数据库中！";
                    }
                    window.parent.loadContent_Instance.loadEmployeeContent(departmentid,str);
                    parent.$.dialog({ id: "addMember" }).close();
                });                
            }
			return false;				
        })
    }

    $.fn.modMember = function(options)
    {
    	var defaults = {
            oldInfo:modEmployee
        },
        params = $.extend(defaults, options || {}),
	    _this = $(this);
	    $('#prsnName').text(params.oldInfo.name);
	    $('#prsnID').text(params.oldInfo.employeeid);
	    $('#resetPassword').val(0);
        $('#monthLimit').val(params.oldInfo.balance);
        $('#voipAuth').val(auth2str(params.oldInfo.service.voip));
	    $('#phoneconfAuth').val(auth2str(params.oldInfo.service.phoneconf));
	    $('#smsAuth').val(auth2str(params.oldInfo.service.sms));
	    $('#dataconfAuth').val(auth2str(params.oldInfo.service.dataconf));
	    console.log('to modify======'+JSON.stringify(params.oldInfo));
        $('.mobileNumber').bind('blur', blurMobile);
        $('#cancel').click(function () {
            parent.$.dialog({ id: "modMember" }).close();
        });				
        $('#modSubmit').die('click').live('click', function(){
        	var resetPW = $('#resetPassword').attr('checked');

            var employeemodifyInfo = {'resetPW':resetPW === true || resetPW === 'checked' ? 'yes' : 'no', 
                    'balance': changeTwoDecimal_f($('#monthLimit').val()),
                    'auth':{'voip':str2auth($('#voipAuth').val()), 
                            'phoneconf':str2auth($('#phoneconfAuth').val()), 
                            'sms':str2auth($('#smsAuth').val()), 
                            'dataconf':str2auth($('#dataconfAuth').val())}};

            api.modEmployee(adminUser, companyid, $('#prsnID').text(), employeemodifyInfo, function(data){
                if (data.status == 'ok') {
                    var str = '修改员工信息成功！';
                } else {
                    var str = '修改失败，请跟管理员联系！';
                }
                window.parent.loadContent_Instance.loadEmployeeContent(departmentid, str);
                parent.$.dialog({ id: "modMember" }).close();
            });
        
            return false;
        });
    }
})(jQuery);