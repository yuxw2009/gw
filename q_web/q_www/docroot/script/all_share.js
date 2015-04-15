// ajaxErrorTips('video' , lw_lang.ID_WRONG_VOIP , 'weibv');

function ajaxErrorTips(mode, data, type){
   var text = "";
   switch(data){
          case 'disable':
             text = lw_lang.ID_ERROR_PERMISSION;
             break;
          case 'out_of_money':
             text = lw_lang.ID_ERROR_NOBLANCE;
             break; 
          case 'org_out_of_money':
             text = lw_lang.ID_ERROR_COMNOBLANCE;
             break;
          case 'out_of_res':
             text = lw_lang.ID_ERROR_NORESOURCE;
             break;
          case 'service_not_available':
             text = lw_lang.ID_REQUEST_ERROR;
             break;
          default:
             text = data;
             break;
   }
    $('.'+ mode +'Tips').addClass(type).show().text(text);
}

function  HideajaxErrorTips(mode){
	setTimeout(function(){
        $('.'+ mode +'Tips').fadeOut();
	}, 2000)
}


function Iframe(Frames) {
	this.get = function(target){
		return $(target, this.getDoc(Frames))
	}
	this.getWindow = function () {
		var w = top
		for (var i=0; Frames && i<Frames.length;i++) {
			w=w.frames[Frames[i]]
		}
		return w
	}
	this.getDoc = function () {
		return this.getWindow(Frames).document
	}
	return this;
}
function getFileName(val){
   var valArray = val.split('\\');
   return valArray[valArray.length - 1];
}

function getFileType(filename){
   var str = filename.split('.');
   return css = (str[str.length-1]).toLowerCase();	
}

function getfilesize(filesize){
   var show_len = parseFloat(filesize)/ 1024;
   return show_len > 1024 ? show_len = (show_len / 1024).toFixed(2) + 'MB' : show_len = show_len.toFixed(2) + 'KB';		
}	

var isPhoneNum = function(str){
    var reg = /^(([+*]{1}|(0){2})(\d){1,3})?((\d){10,15})+$/;
    var reg_sub = /^([*]{1})?((\d){3,8})+$/;
    return reg.test(str.replace(/[\(\)\- ]/ig, '')) || reg_sub.test(str.replace(/[\(\)\- ]/ig, ''));
};


function ifNotInnerClick(clickEventAccepterList, callback){
    var func = function(e){
        var isInnerEvent = false;
        var eTarget = e.target ? e.target : (e.srcElement ? e.srcElement : null);
        if (eTarget && eTarget.nodeType && (eTarget.nodeType === 3)) { // defeat Safari bug
            eTarget = eTarget.parentNode;
        }
        for (var i = 0; i < clickEventAccepterList.length; i++){
            if ($(eTarget).hasClass(clickEventAccepterList[i])){
                isInnerEvent = true;
                break;
            }
        }
        if (!isInnerEvent && (callback)){
            callback(function(){
                $(document).unbind('click');
                $(document).unbind('contextmenu');});
        }
    };
    $(document).unbind('click').bind('click', func);
    $(document).unbind('contextmenu').bind('contextmenu', func);
}

email_frame =new Iframe(['email'])
//write_email_frame=new Iframe(['email',])

function get_uuid() {
	return top.uuid;
}

function my_mail_addr() {
	var mail=top && top.getEmployeeByUUID(top.uuid) && top.getEmployeeByUUID(top.uuid).mail || '';
	return mail;
}

function get_mail_addr(UUID) {
	var employee = top.getEmployeeByUUID(UUID);
	return employee || employee.mail;
}

Date.prototype.format = function(format){
	var o = {
				"M+" : this.getMonth()+1, //month
				"d+" : this.getDate(), //day
				"h+" : this.getHours(), //hour
				"m+" : this.getMinutes(), //minute
				"s+" : this.getSeconds(), //second
				"q+" : Math.floor((this.getMonth()+3)/3), //quarter
				"S" : this.getMilliseconds() //millisecond
			}
		if(/(y+)/.test(format))
		format=format.replace(RegExp.$1,(this.getFullYear()+"").substr(4 - RegExp.$1.length));
		for(var k in o)
		if(new RegExp("("+ k +")").test(format))
		format = format.replace(RegExp.$1,RegExp.$1.length==1 ? o[k] : ("00"+ o[k]).substr((""+ o[k]).length));
		return format;
}