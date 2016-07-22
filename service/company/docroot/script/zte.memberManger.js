 // JavaScript Document
(function ($) {	
	var companyid = parent.companyid;
	var departmentid = parent.departmentid;
	var emplyerid = new Array();
	var mobileNumber=new Array();	
	
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
	}	
			

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
    $('#container').find('input').eq(0).focus();
    // 搜索框插件			   
    $.fn.addMember = function (options) {
        var defaults = {
            personsName: ".personsName",
            jobNumber: ".jobNumber",
            defaultPssword: ".defaultPssword",
            monthLimit: ".monthLimit",
            mobileNumber: ".mobileNumber",
            cancel: "#cancel",
            addSubmit: "#addSubmit"
        },
       params = $.extend(defaults, options || {}),
	   _this = $(this);
        var request = {
            submint: function (opt) {     
                $.ajax({
                    type: "post",
                    url: "service.yaws",
                    dataType: "json",
                    data: "command=add_employer&companyid=" + companyid + "&departmentid=" + departmentid + "&employerlist=" + opt + "&t=" + new Date().getTime(),
                    contentType: "application/json; charset=utf-8",
                    success: function (data) {
						var ms = data.message;
						if(ms!=='ok'){
						  var str = "以下员工工号" + ms.replace('&','、') +"添加失败，原因：已经包含在数据库中！";
						}
                        window.parent.loadContent_Instance.loadEmployeeContent(departmentid,str);
                        parent.$.dialog({ id: "addMember" }).close();
                    }
                });
            }
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
        var blurhandle = function () {
			var obj = $(this);
			var temp = obj.val();
			var len = emplyerid.length;				 
			for (var i=0;i<len;i++){
				if(temp===emplyerid[i]){
	                totips(obj, 130, '该工号已经添加！', 22, -5);
					$(this).focus();
			     	return false;
				}
		    }
			if(''!==obj.val()){			   	
			   emplyerid.push(temp);			   
			   obj.attr('currentvalue',temp)	
			 }
			   return false;				
        };		
        var blurMobile = function () {
			var obj = $(this);
			var temp = obj.val();
			var len = mobileNumber.length;				 
			for (var i=0;i<len;i++){		
				if(temp===mobileNumber[i]){
	                totips(obj, 130, '该手机号已经存在！', 22, -5);
					$(this).focus();
			     	return false;
				}
		    }
			if(''!==obj.val()){			   	
			   mobileNumber.push(temp);			   
			   obj.attr('currentvalue',temp)	
			 }
			   return false;				
        };		
        var focushandle = function () {
            var obj = $(this);
            var index = parseInt(_this.find('tr').index(obj.parent().parent()));
            var current_obj = obj.parent().parent().prev();
            var inputTag = current_obj.find('input');
			var currentvalue;
	        if(obj.attr('class')==='jobNumber'){
				currentvalue= obj.attr('currentvalue');	
                if(''!==currentvalue){
					emplyerid.remove(currentvalue)
				}
			}else if(obj.attr('class')==='mobileNumber'){
				 currentvalue= obj.attr('currentvalue');				
                if(''!==currentvalue){
					mobileNumber.remove(currentvalue)
				}
		   }	
		   
			if(current_obj.length > 0) {
                inputTag.each(function () {
                    if ('' === $(this).val()) {
						if($(this).attr('add_data')!=='mobileNumber2' &&  $(this).attr('add_data')!=='mobileNumber1'){
							totips($(this), 170, '请逐项添加,标*的项不能为空！', 26, 0);
							$(this).focus();
							return false;
						}						
                    }else {
						   newDom_focus(obj);
                        if ($(this).attr('class') ==='mobileNumber') {
							var cur_str = $(this).val();
							if('' !== cur_str){
								cur_str = correctPhoneNumber(cur_str);				
								a = mobile_test(cur_str);
								if (!a) {
									$(this).focus();
									totips($(this), 220, '请输入正确的手机号（包含国家码）！', 31, 50);
								} else {
									$(this).val(cur_str);
									current_obj.attr('class','validate');
								}
						   }
                        }
                    }
                })
            }
        }
        var newDom_focus = function (obj) {
            if (obj.parent().parent().next().length <= 0) {				
                obj.parent().parent().clone().appendTo(_this.find('tbody'));
                _this.find('tbody').find(params.personsName + ':last').val('').bind('focus', focushandle);
                _this.find('tbody').find(params.jobNumber + ':last').val('').bind('focus', focushandle).bind('blur',blurhandle);
                _this.find('tbody').find(params.mobileNumber + ':last').val('').bind('focus', focushandle).bind('blur', blurMobile);
            }
        }
        $(params.personsName).bind('focus', focushandle);
		$(params.jobNumber).bind('focus', focushandle).bind('blur',blurhandle);
		$(params.mobileNumber).bind('focus', focushandle).bind('blur', blurMobile);;
        $(params.cancel).click(function () {
            parent.$.dialog({ id: "addMember" }).close();
        });		
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
		}		
        $(params.addSubmit).die('click').live('click',function () {
			var flag = 1;
            var opt = {}, addItem = new Array(), addItem_obj = {};
            var name = '', jobNumber = '',/* defaultPssword = '8888', */mobileNumber1 = '', mobileNumber2 = '', money = '';			
            //遍历table成JSON对象
            _this.find('tr').each(function () {			
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
                            case 'mobileNumber1':
								var cur_str = $(this).val();	
							    if('' !== cur_str){
							   	   cur_str = correctPhoneNumber(cur_str);				
								   a = mobile_test(cur_str);
									if (!a) {																
										$(this).focus();
										totips($(this), 220, '请输入正确的手机号（包含国家码）！', 31, 50);
										flag = 0;
										return false;
									} else {
										$(this).val(cur_str);
										mobileNumber1 = flagValue;
									}
								}
                                break;
                        }
                    }else{						
					  if($(this).attr('add_data')!=='mobileNumber2' &&  $(this).attr('add_data')!=='mobileNumber1'){						
						 $(this).focus();
						 totips($(this), 170, '请逐项添加,标*的项不能为空！', 26, 0);
						 flag = 0;
						 return false;
					  }						
				    }
                });
                money = $(this).find('select').val();				
                addItem_obj = { 'name': name, 'jobNumber': jobNumber, 'phone1': mobileNumber1, 'phone2': mobileNumber2, 'banlance': changeTwoDecimal_f(money)}
				name = '', jobNumber = '',/* defaultPssword = '8888', */mobileNumber1 = '', mobileNumber2 = '', money = '';
                addItem.push(addItem_obj);
            });
			if(flag===1){
              addItem = JSON.stringify(addItem);
              request.submint(addItem);
			  return false;	
			}else{
			  return false;	
			}			
        })
    }	
       $("#tab1").height(parent.tabheight-70);
})(jQuery);