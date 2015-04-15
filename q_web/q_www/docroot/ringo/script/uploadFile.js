
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


  /*上传*/
  function FormSubmit(index, winBox, formBox, type, val, filetype){
    var List = winBox.find('dl.filelist').eq(index);
    var FormL = formBox.find('form').eq(index);
    FormL.ajaxForm({ 
       beforeSend: function() {
        List.removeClass('queue').addClass('uping');
        List.find('.Dsa').text('Preparing...');
        List.find('.Dopt').text('').unbind('click').bind('click', function(){
             return false;
        })
       },
       uploadProgress: function(event, position, total, percentComplete){
          var percentVal = percentComplete + '%';
              List.find('.Dsa').text(percentVal);
              List.find('.inline_mask').show().width(percentVal);
              List.find('.Dopt').addClass('delete').text('').unbind('click').bind('click', function(){
                FormL.clearForm();
                FormL.remove();
                $(this).parent().parent().remove();   
                DiskUpSub(winBox, formBox, type, val, filetype);         
             });              
          if(percentComplete == 100){
             List.find('.inline_mask').hide();
             List.find('.Dsa').text('Processing..');
             List.removeClass('uping').addClass('dealing');
             DiskUpSub(winBox, formBox, type, val, filetype);
          }
       },
       complete: function(xhr) {
         var data = xhr['responseText'] && JSON.parse(xhr['responseText']);
          List.find('.Dopt').addClass('delete').text('').unbind('click').bind('click', function(){
                 $(this).parent().parent().remove();
                 FormL.remove();
          }); 
         List.removeClass('uping').removeClass('dealing');
         if(!winBox.find('.uping').length && !winBox.find('.dealing').length){
            removePageTips(winBox.parent());
         }
         if(!data || data['status'] === 'failed'){           
             List.addClass('failed');
             DiskUpSub(winBox, formBox, type, val, filetype); 
             List.find('.Dsa').text('Sending failure');
             List.find('.reupload').show().text('Resend').unbind('click').bind('click', function(){
                  $(this).fadeOut();
                  List.removeClass('failed').addClass('queue');
                  FormL.find('.submit_sharefile').submit();
             });
             if(!data) List.find('.reupload').hide();
         }else{
           List.addClass('success'); 
           List.parents().find('.sendBtn').eq(0).removeClass('disabledBtn');
           List.find('.Dsa').text('Sending success');
           upHandle(winBox, data, List, val, FormL, filetype)
         }

      },
      error: function(xhr) {
        console.log('ajaxForm xhr:',xhr);
      }
    });
  }
  
  function upHandle(winBox, data, List, val, FormL, filetype){
    var url ='/lw_download.yaws?fid='+data['doc_id'];
    var fileName = data["name"];
    var fileSize = getfilesize(data['length']);
    var filetype = getFileType(fileName);    
    var sid = winBox.attr('window');    
    var wc = sc.sessions[sid].chatCtlr;
     txt = ['<dl class="shareFile">',
             '<dt>File sharing:<dt>',
             '<dd><i class="file_icon '+ filetype+'"></i>',
               '<span class="filename">'+ fileName  +'( ' + fileSize +')</span>',
               '<a class="download" href="'+ url +'" target="_blank">download</a>',
             '</dd>',
            '</dl>'].join('');
     setTimeout(function(){
          List.slideUp(400,function(){ $(this).remove(); });
          FormL.remove();
     },1000)          
    wc.displaySingleMsg('append',  wc.sendMsg(txt));
   }





function sharefiles_handle(obj){
    var val = $(obj).val(),
     filename = getFileName(val),
     filetype = getFileType(filename),
     dl = FileListDom(filename, filetype ),

     Dbox =  $(obj).parents('.window-container'),
     List = Dbox.find('.chatWin_con'),
     z_index = parseInt($(obj).css('z-index')),
     parObj = $(obj).parent(), flag = 1, 
     formBox =  $(obj).parent().parent();



     formBox.find('form').each(function(i){
        if(val == $(this).attr('filepath')){
          pageTips($(obj).parent(), '您选择的文件已包含在列表中！');
          flag = 0; 
          return;
         }
     }) 
	 
     if(flag === 0) return false;
     List.append(dl);


     List.find('dl.filelist:last').attr('filePath', val);
     List.find('dl.filelist:last').find('.Dopt').text('取消').unbind('click').bind('click',function(){ 
          $(this).parent().parent().remove();
          parObj.remove();
     })

     parObj.clone(true).appendTo(formBox);

     parObj.attr('filePath', val);

     parObj.next().find('.DiskFile').css('z-index', z_index +1);

      DiskUpSub(Dbox, formBox, val, filetype);
  }
  
  
  function DiskUpSub(winBox, formBox, val, filetype){
    var submObj = winBox.find('.queue').eq(0);
    var filePath = ""
    if(winBox.find('.uping').length == 0){
      if(submObj.length>0){
        filePath = submObj.attr('filepath');
        formBox.find('form').each(function(i){
            if(filePath == $(this).attr('filepath')){
               submObj.find('.Dsa').text('请稍候...');
                 FormSubmit(i, winBox, formBox, val, filetype);
                 $(this).find('.submit_sharefile').submit();
               return;
            }
        })
      }
    }
  }


  function FileListDom(filename, filetype){
    return ['<dl class="queue filelist">',
              '<dd>',
                '<i class="file_icon '+ filetype +'" ></i>',
                '<span class="Dfn">'+ filename +'</span>',
                '<span class="Dsa ">排队中...</span>', 
                '<span class="Dopt"></span>',
                '<span class="reupload"></span>',                
              '</dd>',
              '<div class="inline_mask"></div>',
            '</dl>'].join('');
  }
