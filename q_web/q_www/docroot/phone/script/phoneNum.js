
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

var isPhoneNum = function(str){
    var reg = /^(([+]{1}|(0){2})(\d){1,3})?((\d){10,12})+$/;
    return reg.test(str.replace(/[\(\)\- ]/ig, ''));
};
var mobile_test = function (str) {
    reg = /^[+]{0,1}(0){2}(\d){1,3}[ ]?([-]?((\d)|[ ]){11})+$/,
	flag_2 = reg.test(str);
    return flag_2;
};
