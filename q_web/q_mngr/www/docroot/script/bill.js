
var adminUser = parent.adminUser;
var companyid = parent.companyid;
var departmentid = parent.departmentid;

var firstDayInMonth = function(year, month){
	return year + '-' + month + '-01';
}
var lastDayInMonth = function(year, month){
	return year + '-' + month + '-' + (new Date(year, month, '0')).getDate().toString();
}
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

var excelPrint = function(objStr){
    var tempStr = document.getElementById('export').outerHTML;
    var newWin = window.open();
    newWin.document.write(tempStr);
    newWin.document.close();
    newWin.document.execCommand('Saveas',false,objStr+'.xls');
    newWin.window.close();
}
//	$('#export_excel').click(function(){						
//		excelPrint(parent.companyid);
//	})