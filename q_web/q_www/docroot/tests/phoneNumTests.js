
module("phoneNum string validate");

test("valid phone numbers.", function(){
	ok(isPhoneNum("13745168241"));
	ok(isPhoneNum("008615845784125"));
	ok(isPhoneNum("+862178765432"));
	ok(isPhoneNum("0086-13541256985"));
	ok(isPhoneNum("(027)76384628"));
	ok(isPhoneNum("027 76384628"));
});

test("invalid phoneNum strings.", function(){
	ok(!isPhoneNum("你好"));
	ok(!isPhoneNum("邓辉0131000020"));
});