/* video.js version 1.0 */
$.fn.videoPlayer = function (opts) {
	var defaults = {
			resize: true,
			volume: true,
			fullscreen : true,
      vdType: 'p2pvideo',
			time: '00:00:00',
      snap:true,
      skin: 'default',
      onStart:function(){ },
      onHangup:function(){ }
  },
  params = $.extend(defaults, opts || {}),
  controlDom = function(){
    return ['<div class="vp_con">',
              '<a class="vd_play" title="播放" href="###"></a>',
              '<a class="vd_pause" title="暂停" href="###"></a>',   
                '<div class="vd_flbtn">',
                  '<span class="vd_time">00:00:00</span>', 
                  '<a class="vd_volume" href="###"></a>',
                  '<span class="vd_pr"></span>',             
                    '<div class="vd_volume_bar">',
                      '<div class="vd_volume_bar_value"></div>',
                      '<span class="vd_handle"></span>',                  
                    '</div>',
                   params.vdType == 'p2pvideo' ? '<a class="vd_switch" title="切屏" href="###"></a>':'',  
                   params.vdType == 'p2pvideo' ? '<a class="vd_hidesm" title="隐藏小窗口" href="###"></a>':'',    
                   params.snap == true ? '<a class="vd_snap" title="拍照" href="###"></a>':'',                                     
                  '<a class="vd_fullscreen" title="全屏" href="###"></a>',
                  '<a class="vd_start" title="发起视频会话" href="###"></a>',
                  '<a class="vd_hangup" title="挂断" href="###"></a>',
                '</div>',
            '</div>'].join('');
    },
    _this = $(this), obj = _this.parent(),
    video, videoBox , volume_value;
    (function(){
      var vd_id = _this.attr('id') ;
      if(!vd_id) _this.attr('id', 'videoplayer' + Math.random(15)*10e20);
      var $id = function(id){ return document.getElementById(id); }
      video = $id(_this.attr('id'));
      videoBox = $id(obj.attr('id'));
    })();
  var vdCurTime = function(curTime){
      var Time = Math.floor(curTime),
        hour = parseInt(Time / 3600),
        min = parseInt(Time / 60),
        sec = parseInt(Time % 60);
      return (parseInt(hour, 10) < 10 ? '0' + hour : hour)  + ":" + (parseInt(min, 10) < 10 ? '0' + min : min)  + ":" + (parseInt(sec, 10) < 10 ? '0' + sec : sec);
  }
  
 var btn_handle = {
     vdEvent: function(e, fun){ 
        video.addEventListener(e,fun); 
     },
     vdBind: function(dom,  fun, vent){
       obj.find('.' + dom).bind(vent?vent:'click',fun)
     },
     vdbindHandle: function(){
        var curObj = this;
        curObj.vdBind('vd_fullscreen' , curObj.toggleFullScreen);
        curObj.vdBind('vd_play' , curObj.vdPlay);
        curObj.vdBind('vd_pause' , curObj.vdStop);       
        curObj.vdBind('vd_hangup' , curObj.vdHangup);
        curObj.vdBind('vd_start' , curObj.vdStart);
        curObj.vdBind('vd_volume' , curObj.vdToggleMuted);
        curObj.vdBind('vd_hidesm' , curObj.vdToggleShowsm);
        curObj.vdmediaEvent(); 
        if(params.vdType == 'p2pvideo'); 
        curObj.vdBind('vd_switch' , curObj.vdSwitch);
        if(params.snap == true);
        curObj.vdBind('vd_snap' , curObj.vdSnap);
     },
     toggleFullScreen:function(){
        $(this).attr('title', '退出全屏').addClass('vd_cancelfullscreen');
        if (!document.fullscreenElement && !document.mozFullScreenElement && !document.webkitFullscreenElement) {  
          if (document.documentElement.requestFullscreen) {
            videoBox.requestFullscreen();
          } else if (document.documentElement.mozRequestFullScreen) {
            videoBox.mozRequestFullScreen();
          } else if (document.documentElement.webkitRequestFullscreen) {
            videoBox.webkitRequestFullscreen(Element.ALLOW_KEYBOARD_INPUT);
          }
        } else {
            $(this).attr('title', '全屏').removeClass('vd_cancelfullscreen');
            if (document.cancelFullScreen) {
              document.cancelFullScreen();
            } else if (document.mozCancelFullScreen) {
              document.mozCancelFullScreen();
            } else if (document.webkitCancelFullScreen) {
              document.webkitCancelFullScreen();
            }
        }
    },
    vdmediaEvent:function(){
      var curObj = this;
      curObj.vdEvent('timeupdate', function(){
        obj.find('.vd_time').text(vdCurTime(video.currentTime));
		    if(parseInt(video.currentTime) > 0)
		    obj.find('.vd_hangup').show().siblings().hide();
        obj.find('.vdTip').hide();       
      })
      curObj.vdEvent('ended', function(){
        curObj.vdStop();
        obj.find('.vd_time').text('00:00:00');
        obj.find('.vdTip').show();         
      })
    },
    vdToggleMuted:function(){
      var volume_obj = obj.find('.vd_volume_bar_value');
      var volumeControl = function(width, flag){
          volume_obj.animate({
            width:width
          }, 300).next().animate({
            'left':width
          },300, function(){
            video.muted= flag;
          })
      }
      $(this).hasClass('vd_muted') ? volumeControl(volume_value, false) : (volume_value =volume_obj.width(), volumeControl(0, true));
      $(this).toggleClass('vd_muted');
    },
    vdSwitch:function(){
       _this.show().toggleClass('bgvideo').toggleClass('smvideo');   
       _this.next().show().toggleClass('bgvideo').toggleClass('smvideo');
       obj.find('.vd_hidesm').removeClass('vd_showsm');
    },
    vdPlay:function(){
       $(this).hide().next().css('display', 'inline-block');
       video.play();
    },
    vdStop:function(){
       $(this).hide().prev().css('display', 'inline-block');
       video.pause();
    },
    
    vdStart: function(){
//        var errBack = function(error){
//          console.log("Video capture error: ", error.code);  
//        }
//        if (navigator.getUserMedia) { 
//             navigator.getUserMedia({video:true,audio:true}, function (stream) {   
//                video.src = stream;   
//                video.play();   
//             }, errBack);   
//            } else if (navigator.webkitGetUserMedia) {   
//             navigator.webkitGetUserMedia({video:true,audio:true}, function (stream) {   
//               video.src = window.webkitURL.createObjectURL(stream);   
//               video.play();
//            }, errBack);
//        }
        params.onStart();
    },

    vdHangup: function(){
      _this.attr('src', '');
      _this.next().attr('src', '');
      params.onHangup();
    },
    vdSnap: function(){
      var canvas = document.getElementById("canvas"),   
       context = canvas.getContext("2d");
       context.drawImage(video, 0, 0, 400, 300);
    },
    vdToggleShowsm: function(){
       var tar = $(this);
       obj.find('.smvideo').fadeToggle();
       tar.hasClass('vd_showsm') ? tar.attr('title','隐藏小窗口'): tar.attr('title','显示小窗口');
       tar.toggleClass('vd_showsm');
    }    
  }
  function conHandle(){
    obj.append(controlDom());
    btn_handle.vdbindHandle();
  }
    conHandle();
}