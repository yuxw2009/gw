// 输入框插件
$.fn.InputFocus = function () {		
   var _this = $(this);
   var tip = _this.prev();
	_this.focus(function(){
		$(this).val() === '' ? tip.css('color','#ccc') : tip.hide();
    }).keyup(function (){		   
		if( $(this).val() !== '')  tip.hide();
		return false;
	}).blur(function(){
	   if( $(this).val() === '') tip.css('color','#999').show();
	   return false;			
	})
   tip.bind('click', function(){ $(this).next().focus(); return false;})	
}

// 同事录筛选插件		   
$.fn.filter_addressbook = function (options) {
    var defaults = {container: $('#search_list') },   params = $.extend(defaults, options || {}), _this = $(this);
	var reg = /[\u4E00-\u9FA5\uF900-\uFA2D]/; 
	 _this.bind('keyup', keyhandel);
     function keyhandel(e){	
		 var str = $(this).val();
		 var flag = reg.test(str);
		 console.log(str)
		 var employer_temp = new Array();
		 if ('' !== str) {
			for (var i = 0; i < employer_status.length; i++) {				
				 if (flag) {
					  if (employer_status[i].name_employid.indexOf(str) === 0)
					    employer_temp.push(employer_status[i].uuid);
					} else {
					  if (employer_status[i].convertname.indexOf(str.toUpperCase()) === 0)
					   employer_temp.push(employer_status[i].uuid);
					}
			}
			
			console.log(employer_temp.length)
			$('#Address_Book_box_2').show().prev().hide();
			if(employer_temp.length >0 ){
				pageMngr.getPageObj('Address_Book').showemployer(employer_temp , params.container);
				if($('#Address_Book_box_2').attr('bindscroll') === 'no'){
				  myScroll['Address_Book2'] = new iScroll('Address_Book_box_2', {});		
				  $('#Address_Book_box_2').attr('bindscroll','yes');				
				}else{
				  myScroll['Address_Book2'].refresh();
				}	
			    $('#employer_list').find('.checked_box').each(function(){
			       var employId = $(this).parent().attr('uuid');
			       params.container.find('.'+employId).find('.check_box').addClass('checked_box');				
		        })
			}else{ 
			   params.container.html('<div style="text-align:center;font-size:12px;">通讯录中没有"'+ str+'"相关同事</div>');
			}

	   }else{	
		    $('#Address_Book_box_2').hide().prev().fadeIn();
	   }   
  }
}

