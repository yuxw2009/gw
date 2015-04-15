//页面初始化页面内容
var loadContent = new loadContent();
var meetingController = MeetingController.createNew();
var oScrollbar = $('#contianer_contact');


var uriQuery = function(type){
    var sea = window.location.search.slice(1);
    var query = (sea.indexOf('&') >= 0 ? sea.split('&') : sea.slice(1)),  arr;
    if($.isArray(query)){
      for(var i = 0; i < query.length; i++){
        arr = query[i].split('=');
        if( arr[0] == type) return arr[1];
      }
    }else{
      arr = query.split('=');
      if( arr[0] == type) return  arr[1];
    }
}

var save2Cookie = function(company, account, password, uuid){ 
   $.cookie('company',company, {expires: 30});
   $.cookie('account',account, {expires: 30});
   $.cookie('password', password, {expires: 30});    
   $.cookie('uuid',uuid);
}

var doLogin = function(company, account, passwordMD5,  failCallback){
  var url = '/lwork/auth/login';
  var language =  $.cookie('language')?  $.cookie('language'):$('.current_lan').attr('lang');
  var data = {'company':company, 'account': account,'password': passwordMD5, 'deviceToken':'', t: new Date().getTime()};
  $.post(url,JSON.stringify(data),function(data){
      if(data.status === 'ok'){
         save2Cookie(company, account, passwordMD5, data['uuid']);
         oScrollbar.tinyscrollbar();
         meetingController.init($('#meeting'));
         loadContent.init();
         setHeight(); 
         // language == 'en' ?  window.location = "lwork.yaws?language=en&uuid=" + data['uuid'] :  window.location = "lwork.yaws?uuid=" + data['uuid'];
         //window.location = "lwork.html";
      }else{
        if (failCallback){
          failCallback(data.reason);
        }
      }
  })
}



    
    function setHeight() {
       var clientHeight = document.documentElement.clientHeight;
       var clientWidth = parseInt(document.documentElement.clientWidth);
       var setwidth = function(s1, s2){
         $('#container, #header, .lwork_content').width(clientWidth - s1);
         $('.meeting_current_list').css('width',s2);
         $('#chat_box, #chatMiniRoot').css('right', s1/2 + 220);
       }
       oScrollbar.tinyscrollbar_update();    
       clientWidth > 1400 ? setwidth(350, '80%') : ( clientWidth > 1200 ?  setwidth(100, '95%') : setwidth(0, '95%')) ;
       $('#article').css('min-height', clientHeight + 110 + 'px');
       $('#email').css('height', clientHeight-120+'px');
       $('#container').css('min-height', clientHeight-120+'px');            
       $('#contianer_contact , #contact').css('height', clientHeight - 250 +'px');
       $('.forum_box').css('min-height', clientHeight -250 +'px');
       return false;
    };




    window.onresize = setHeight;
    var $backToTopTxt = "", $backToTopEle = $('<div id="goto_top"/>').appendTo($("body"))
      .attr("title", $backToTopTxt).click(function() {
      $("html, body").animate({ scrollTop: 0 }, 120);
    }), $backToTopFun = function() {
      var st = $(document).scrollTop(), winh = $(window).height();
      (st > 0)? $backToTopEle.show(): $backToTopEle.hide();    
      //IE6下的定位
      if (!window.XMLHttpRequest) {
        $backToTopEle.css("top", st + winh - 166);    
      }
    };    
      $backToTopFun();
        //右侧栏目浮动     
      $(window).scroll(function () {
            $backToTopFun();
            return false;
      });
      $('#modify_images').find('form').ajaxForm({ 
         complete: function(xhr) {         
          var data = JSON.parse(xhr['responseText']);
             if(data['status'] === 'ok'){
               return loadContent.updateimg.updateimages(data['file_name']);
             }else{
                LWORK.msgbox.show("%%ID_UPLOAD_FAILED%%", 1, 2000); 
                return false;
             }
        }
    });

    /*集体决策传图片*/  
     $('#polls_option').find('form').ajaxForm({
         dataType:  'json', 
         complete: function(xhr) {
          var data = JSON.parse(xhr['responseText']);
          if(data['status'] === 'ok'){
            var url = loadContent.getpicphoto(data['file_name'], 'S');
            $('#polls_option').find('.current_item img').removeClass('loading_img').addClass('display_img').attr({'src':url, 'source': data['file_name'] });
            $('#polls_option').find('.current_item').removeClass('current_item');
          }else{
             LWORK.msgbox.show("%%ID_UPLOAD_FAILED%%", 1, 2000); 
          }
       }
    }); 

    function upload_itemimages(obj){
      var _this = $(obj); 
      var $val = _this.val();
      var valArray = $val.split('\\');
      var filename = valArray[valArray.length - 1];
      var filetype = getFileType(filename);
          filetype = filetype.replace(/(^\s*)|(\s*$)/g, "");
      if(filetype !== 'jpg' && filetype !== 'png'&& filetype !== 'jpeg' && filetype !== 'gif'&& filetype !== 'bmp'){
           LWORK.msgbox.show("%%ID_UPLOAD_LIMITED%%", 2, 1500); 
           return false;
      }        
      var index =  $('#polls_option').find('li').index(_this.parent().parent().parent()); 
      _this.next().find('img').removeClass('display_img').addClass('loading_img').attr('src', '/images/uploading.gif');   
      _this.parent().find('input[type=submit]').click();
      _this.parent().addClass('current_item');
    }
    window.onbeforeunload = function () {
      if($('.Interrupt').css('display') !=='block'){
          return "%%ID_TIP_EXIT%%";
      }
    }
    $('#sendsms_input').tagsInput({
       'width':'auto', 
       'height':'30px' ,
       'delimiter':';',
       'getuuid': 'no',     
       'defaultText':lw_lang.ID_SEPERATED
    });

   $('#add_member').tagsInput({
     'width':'auto', 
     'height':'30px' ,
     'getuuid': 'yes',
     'delimiter':';',
     'defaultText':lw_lang.ID_SEARCH_NAME
   });

doLogin("livecom", uriQuery("account"), md5(uriQuery("password")), function(){
    alert("登录失败");  
});

