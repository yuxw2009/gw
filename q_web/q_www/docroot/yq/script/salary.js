function salary_decode(Key,Text)
{
  var res = []; 
    
    var keylen = Key.length;
    var textlen = Text.length 
   
    var round = parseInt(textlen/keylen);
    var remain = textlen % keylen;

  for (var r=0; r< round; r++) {
      for(var i= 0; i< keylen; i++) {
            res.push(String.fromCharCode(Key.charCodeAt(i) ^ Text[r*keylen+i]));
        }
  }
  for(var i = 0; i< remain; i++) {
        res.push(String.fromCharCode(Key.charCodeAt(i) ^ Text[round*keylen+i]));
    }

  return decodeURIComponent(escape(res.join("")));
}

function salaryHandle() {

}
salaryHandle.prototype = {
  init:function(){
    var obj = this;
    obj.AddOpt();
	$('#searchBTN').unbind('click').bind('click', obj.SearchSalary(obj));
  },
  AddOpt:function(){
    var data = new Date(), year = parseInt(data.getFullYear(), 10), month = parseInt(data.getMonth()+1, 10);   
    var html = '<option selected="selected">'+ year +'</option><option>'+ (year-1) +'</option>';  
     $('#select_year').html(html);  
     $('#select_month').val(month -1); 
    //$('#searchBTN').click();
  },
  loadSalary:function(year, month){
     $('#loading').show();
     api.content.SearchSalary(year, month, function (data) {
       if(data.status == 'ok'){
          var html = salary_decode($.cookie('password'), data.salary_info);
          $('#loading').hide();  
          $('#salary_msg').html(html);
	      if($('#salary_msg').find('.salarytable').find('td').length == 0){
			 $('#salary_msg').find('.salarytable').html('<tr><td>当月没有您的工资单数据</td></tr>')
		  }	
          $('#titleTime').text(year+ '年' + month + '月')
       }
     });
  },
  SearchSalary:function(salaryObj){
   
    return function(){
	   var okfun =  function(){
		  var input = document.getElementById('inputPsw');
			  if(md5(input.value) == $.cookie('password')){
				   var year = $('#select_year').val();
				   var month = $('#select_month').val();
				   salaryObj.loadSalary(year, month);
			  }else{
				  	LWORK.msgbox.show('密码错误，请重新输入！', 5, 1000);
					return false;
			  }
		}
		
			var dialog = art.dialog({
				content: '<p>请输入Lwork登录密码：</p>'
					+ '<input type="password" id="inputPsw" style="width:15em; padding:4px" />',
				fixed: true,
				id: 'Fm7',
				title:'工资单查询',
				icon: 'question',
				okVal: '确定',
				ok: okfun,
				cancel: true
			});
		
	}
	
	
  }

}
