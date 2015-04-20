var wcgStatusObj = { };
(function(){
	var g_status="normal";
	var g_alarm_num =10000;
	var chartsObj = {}; 
	var maxcallstotal = 0;	
	$.fn.searchInput = function (options) {
	    var defaults = {
	        color: "#fff",
	        defaultcolor: "#cfcfcf",
	        defalutText: ""
	    },
	    params = $.extend(defaults, options || {}),
		 _this = $(this);
	    _this.css("color", params.defaultcolor);
	    _this.focus(function () {
		 if ("" === _this.val() || _this.val() === params.defalutText){		
	        _this.val("");
	        _this.css("color", params.color);
		  }
	    }).blur(function () {
	        if ("" == _this.val()) {
	            _this.css("color", params.defaultcolor);
	            _this.val(params.defalutText);
	        }
	    })
	}

	function audio_tpl(hint) {
	    return ['<div class="audio p2pAudio" style="display:none">',
	             '<div class="p2pAudioTip p2p_hint">'+hint+'</div>',
	             '<div class="p2pAudioStatus"></div>',
	              '<dl>',
	                '<dd class="p2paudioBox">',
	                  '<video class="p2p_audio_screen big_audio_Screen p2p_remote_Screen" id="p2pvideo_96_big" autoplay  preload="auto" width="100%" height="100%" data-setup="{}"></video>',
	                '</dd>',
	              '</dl>',
	             '<div class="audioOpt"><a href="###" class="ahangUp hangUp">挂断</a> </div>',
	            '</div>'].join('');
	}
    function addWcgDom(){
		return ['<div class="control-grouplist">',
	          '<div class="control-group">',
	            '<label class="control-label">WCG标识：</label>',
	              '<input type="text" class="span11 wcgNode" placeholder="设备名称">',
	            '</div>',
	            '<div class="control-group">',
	              '<label class="control-label">最大并发数：</label>',
	              '<input type="text" class="span11 wcgTotal" placeholder="最大并发数">',
	            '</div>',
	        '</div>'
		].join('')
   }


 	function cgListDom(opts){
		return ['<tr id="wcgList_'+ getNode(opts.node) +'" class="searchlist" data = "'+ opts.node +'">',
              '<td><a class="goWcgstatus" type="'+ opts.node +'" href="###">'+ opts.node +'</a></td>',	 
			  '<td><span class="current_num curcpuitem">'+ opts.cpu +'%</span></td>',       
			  '<td><span class="current_num curRequestitem">'+ opts.calls[1] + '</span>/' + opts.calls[0] +'</td>',           
              '<td><span class="current_num curmemitem">'+ getbytesize(opts.memory[1], 2) + '</span>/' +  getbytesize(opts.memory[0], 0) +' (单位: G)</td>',
              '<td><span class="current_num">'+ getbytesize(opts.disk[1], 2)  + '</span>/' + getbytesize(opts.disk[0], 2) +' (单位: G) </td>',
              '<td id="wcglist_status'+ opts.node +'" class="'+ getStatus_css(opts.status) +'">'+ opts.status + '</td>',  
              '<td><a data = "'+ opts.node +'" class="btn btn-danger btn-mini deletewcgBtn" href="###">Delete</a></td>',	                
            '</tr>'].join('');
	}

	function wcgGirdDom(opts){
		var cpu = opts.cpu;
        var css = 'safe'
        if(cpu >= 100) css = 'danger';        
        else if(cpu >= 85) css = 'alarm';
        return  ['<div data = "'+ opts.node +'" id="wcgGird_'+ getNode(opts.node) +'" class="wcglist searchlist '+ css + '">',
          '<span data="'+ opts.cpu +'" class="cpuitem curcpuitem">'+ opts.cpu +'%</span>', 
          '<span data="'+ opts.calls[1] +'" reqtol = "'+ opts.calls[0] +'"  class="requestitem"> <em class="curRequestitem">'+ opts.calls[1] + '</em>/' + opts.calls[0] +'</span>',
          '<span data="'+ getbytesize(opts.memory[1], 2) +'" memtol ="'+ getbytesize(opts.memory[0], 0) +'"  class="memorytitem"><em class="curmemitem">'+ getbytesize(opts.memory[1], 2) + '</em>/' +  getbytesize(opts.memory[0], 0) +' G</span>',
          '<span class="disktitem"><em class="curdiskitem">'+ getbytesize(opts.disk[1], 2)  + '</em>/' + getbytesize(opts.disk[0], 2) +'G </span>',           
          '<div class="hosttag">'+ opts.node +'</div>',
          '<a class="wcgloadtips" href="###">图表查看负载情况</a>',              
         '</div>'].join('');
	}

	function timeFormat(v) {
		var date = new Date(v);
        if (date.getSeconds() % 60 == 0 && date.getMinutes() % 1 == 0) {
          var hours = date.getHours() < 10 ? "0" + date.getHours() : date.getHours();
          var minutes = date.getMinutes() < 10 ? "0" + date.getMinutes() : date.getMinutes();
          return hours + ":" + minutes;
        } else {
          return "";
        }
	}

	// tab分页
	function tabSwitch(){
		var _this = $(this),
		  tag = _this.attr('link'),
		  curBox = $('#' + tag);
		if(_this.hasClass('current')) return false;
		modeToggle(tag);
		_this.addClass('current').siblings().removeClass('current');
		curBox.siblings().hide();
		curBox.fadeIn();
	}
   
    function modeToggle(tag){
   	switch(tag){
      case 'wsBox':
        $('.page_info').show();
      	$('.result_num').text($('#wsBox tbody').find('tr').length);
		$('.viewmode').hide();
		$('.page_opts,.result_count,.seabox').show();
		break;
	  case 'wcgBox':
	  	$('.page_info').show();
	  	$('.result_num').text($('#wcgGird .wcglist').length);
		$('.viewmode,.result_count, .seabox').show();
	    break;
	  case 'callBox':
	    $('.page_info').hide();
	    break; 
   	}
   }

    //表格隔行换色
    function tabDiscolor(){
		$('tbody').find('tr:even').addClass('even');
		$('tbody').find('tr:odd').addClass('odd');
    }
	  
   function getNode(node){
		var newnode = node.replace('@', '_'),
		newnode2 = newnode.replace('.', '-'),
		newnode3 = newnode2.replace('.', '-'),
		newnode4 = newnode3.replace('.', '-');
		return  newnode4;
   }

   function formatFloat(src, pos){
	   return Math.round(src*Math.pow(10, pos))/Math.pow(10, pos);
   }

  function getbytesize(filesize, num){
	 var show_len = parseFloat(filesize)/ (1024 * 1024);
	 show_len = formatFloat(show_len / 1024, num);
	 return show_len;
  }

  function failedCb(){
    $('#loading').hide();
    LWORK.msgbox.show('操作失败，请跟管理员联系', 5, 2000);
  }

 function getStatus_css(status){
	  switch(status){
	  	case 'down':
	  	   css = "danger"
	  	   break;
	  	case 'up':
	  	   css = "success"		  	   
	  	   break;	
	  	default:
	  	   css = "danger"
	  	   break;		  		  	   
	  }
	  return css;
 }

  function setGirdWidth(){
	   var winWidth = ($(window).width()) - 60,
	    row =Math.floor(winWidth/300),
	    target = $('#wcgGird');
	    target.find('.base_info').width(row *300 -20);
	    target.find('.wcglist').css('margin-right', '20px').each(function(i) {
	        if((i+1)%row === 0){
	         $(this).css('margin-right', 0)
	        }
	    })
	}

  function delWcgHandle(){
		var _this = $(this),
		  data = _this.attr('data');		
		  api.wcg.delWcg(data, function(){
	        LWORK.msgbox.show('删除成功！', 4, 2000);
		  },failedCb)
	}

    function fillwcgList(html,html2){
    	$('#wcgBox').find('tbody').html(html);
    	$('#wcgGird').find('.base_info').html(html2);
        wcgGirdHandle();
    }

    function wcgGirdHandle () {
    	tabDiscolor();
		setGirdWidth();
		$('.deletewcgBtn').bind('click', delWcgHandle); 
        $('.wcgloadtips').lwDialog({
          width: 850,
          height: $(window).height() - 300,
		  title:'图表查看负载情况',
		  onpreEvent:function (obj){
		  	var target = obj.parent(),
		  	node = getNode(target.find('.hosttag').text()),
		  	chartbox = $('.avgrund-content').eq(0);
		  	chartbox.find('.header-text').text(target.find('.hosttag').text());
            console.log(target.find('.requestitem').attr('reqtol'))
            $('#reqTol').text(target.find('.requestitem').attr('reqtol')); 
            $('#Totalmemory').text(target.find('.memorytitem').attr('memtol') + 'G');
		    createCharts(node);
		    updateCharts(node);
		  },
		  includeOk:false,
		  cancelText:'关闭',
		  template: $('#wcgchart'),
		  onClose:function() {
		  	var node = getNode($('#wcgchart').find('.header-text').text());
		  	chartsObj['charts' + node] = null;
		  }
	    })
    }
    function AddWcgRequest(Node, Total){    	
		api.wcg.addWcg(Node, Total, function(data){
			fillwcgList(cgListDom({wcgNode:Node, total:Total}))
		}, failedCb)
	}
    function onAddWcgList(){
    	var grouplist = $('.control-grouplist');
    	grouplist.find('input').each(function(){
			var inputbox = $(this).parent();
			if('' == $(this).val()){
			  inputbox.removeClass('success').addClass('error');
			  if(inputbox.find('.help-inline').length == 0)
			  inputbox.append( '<span class="help-inline" style="">不能为空！</span>')
			}else{	
			  inputbox.find('.help-inline').remove();
			  inputbox.removeClass('error').addClass('success');
			}
    	}).focus(function(){
    		$(this).parent().removeClass('error').find('.help-inline').remove();
    	})
	    if(grouplist.find('.error').length > 0 ){
    	  return false;
		}else{
		  var node =  grouplist.find('.wcgNode').val();
		  var total = grouplist.find('.wcgTotal').val();
		  AddWcgRequest(node, total);
		  return true;
		}
    }

	$('.addwcgbtn').lwDialog({
		title:'添加WCG列表',
		width:700,
		height:200, 
		template: $(addWcgDom()),
		onOk:onAddWcgList
	})

    function createWcgList(wcglist){
       var html = '', html2 = '', temp = {}, obj ;
	   for(var i = 0; i< wcglist.length; i++){
	   	 obj = wcglist[i];
	   	 html += cgListDom(obj);
	   	 html2 += wcgGirdDom(obj)
	   }
	   $('.result_num').text(wcglist.length);
	   fillwcgList(html, html2);
	   listGirdHandle();
    }

    function listGirdHandle() {
    	$('.wcglist').hover(function () {
		  $(this).find('.wcgloadtips').show().animate({
			height:50
		  },100)
		}, function () {
		  $(this).find('.wcgloadtips').animate({
			height:0
		  },100, function() {
			$(this).hide();
	      })		
		})
    }

	function getwcgStatus(cb){		
       api.wcg.getWcgStatus(cb, failedCb)
	}
    
    function initPageWidth() {
		var clientWidth = document.body.clientWidth;
		if(clientWidth < 660){
		 $('.result_count, .viewmode, .page_opts').hide();
		 $('#filterWcgCharts').width(150);
		}else{
		 $('.result_count, .viewmode, .page_opts').width();
		 $('#filterWcgCharts').width(280);
		}
		 $('#RequestChartTotalContainer').width(clientWidth-300).css('padding-top','10px');
    }

    window.onresize = initPageWidth;

	function initWcgPage(cb){
	   initPageWidth();
	   var tpl_html=audio_tpl("alert");
	   $(tpl_html).appendTo($("body"));

	   $('#loading').show();
	   getwcgStatus(function(data){
		  createWcgList(data['stats']);
		  creatChatData(data['stats']);
		  createTotalCallsCharts();
		  $('#loading').hide();
	  })
	   getdk();
	}

   function getdk(falg){
   	  var createdkDom = function(wcgname,dkinfo){
   	  	return ['<tr class="bstr">',
                '<td class="wcgname" style="vertical-align:top; padding-top:10px;">'+wcgname+'</td>',
                '<td class="dk_con">',
                  '<table style="width:100%;"><thead><tr><td width="150">上行</td><td width="150">下行</td><td width="">时间</td></tr></thead>',
                  '<tbody class="dkinfo_'+ getNode(wcgname) +'">'+ dkinfo+'</tbody>',
                  '</table>',
                '</td>',    
              '</tr>'].join('');
  	  }

  	  function createdkinfoDom(sx, xx, sj){
     	  var html =  ['<tr>',
               '<td>'+ sx+'</td>',
               '<td>'+ xx +'</td>',
               '<td>'+ sj +'</td>',                
               '</tr>'].join('');	
               return html
  	  }

  	  var html ='';
      api.wcg.getDkStatus(function(data){
      	  var obj = data.stats;      	
      	  for(var i =0; i< obj.length; i++){ 
      	  	var len = parseInt(obj[i].net_stats.length);
      	  	var html2= "";
      	  	for(var j=0; j < len ;j++){
      	  	 	var str = obj[i].net_stats[j].split(' ');
                html2 += createdkinfoDom(str[0], str[3], str[6].replace('_', '&nbsp;&nbsp;&nbsp;&nbsp;'))
      	  	 }
/*      	  	 console.log('str0' + str[0])
      	  	 console.log('str1' + str[3])
      	  	 console.log('str2' + str[6])*/
      	  	 if(falg&& 1==falg){

      	  	 	 $('#daikuanBox').find('.dkinfo_'+ getNode(obj[i].node)).html(html2);

      	  	 }else{
               html += createdkDom(obj[i].node, html2);
             }
          }

            if(!falg){   
              $('#daikuanBox').find('tbody').html(html); 
            } 
          	$('tbody').find('.bstr:even').addClass('even');
		    $('tbody').find('.bstr:odd').addClass('odd');

      }, failedCb)
   }



	function getChartsArray(arr, item, type){
	  var now = new Date().getTime();
	  var oldtime =  now - 250000;	  
	  var pushArr = function(x){
	  	  now += 10;
	  	  var temp = [now , x];
          arr.push(temp);
	  }
	  arr.shift();
      while(arr.length < 50) {
    	var axis =  oldtime + arr.length*5000;
        arr.push([axis , 0]);
      }      
      if(item instanceof Array){
         var value = (type && type == "calls" ? item[1] : getbytesize(item[1], 2) );
         pushArr(value);
      }else{
      	 pushArr(item);
      }
         return arr;
	}

	function getAllCallsArr (item) {
	  var now = new Date().getTime();
	  var oldtime =  now - 250000;
	  now += 10;	
	  if(!wcgStatusObj['allCalls_arr'])  
	  wcgStatusObj['allCalls_arr'] = [];	
	  wcgStatusObj['allCalls_arr'].push([now , item]);
	}

    function give_alarm() {
    	$("#p2pvideo_96_big").attr('src', 'tone/opr_ring.mp3');
      		alert("system abnormal!");
    }
    function creatChatData(data, flag){
      var node, html ='', arr;
      var curcallstotal = 0;
      maxcallstotal = 0;
      for(var i =0; i<data.length;i++){
      	node = getNode(data[i].node);
      	maxcallstotal += data[i].calls[0];
      	curcallstotal += data[i].calls[1];
      	if(curcallstotal>g_alarm_num && g_status == "normal") {
            give_alarm();
      		g_status = "abnormal";
      	}
        if(!wcgStatusObj[node]){
        	wcgStatusObj[node] = {
		         calls_arr: getChartsArray([], data[i].calls, 'calls'),		          
		           cpu_arr: getChartsArray([], data[i].cpu),
		        memory_arr: getChartsArray([], data[i].memory, 'mem')
        	}
        }else{
        	wcgStatusObj[node] = {
		         calls_arr: getChartsArray(wcgStatusObj[node].calls_arr, data[i].calls, 'calls'), 
		           cpu_arr: getChartsArray(wcgStatusObj[node].cpu_arr, data[i].cpu),
		        memory_arr: getChartsArray(wcgStatusObj[node].memory_arr, data[i].memory, 'mem')
        	}
        }
        updateDomInfo(node);
      }
      if(curcallstotal<g_alarm_num) {g_status="normal";}
        if(!wcgStatusObj['callsTotal_arr']){
           wcgStatusObj['callsTotal_arr'] =  getChartsArray([], curcallstotal);
        }else{
           wcgStatusObj['callsTotal_arr'] =  getChartsArray(wcgStatusObj['callsTotal_arr'], curcallstotal);
        }
        getAllCallsArr(curcallstotal);
        $('#currequestNumberTotal').text(curcallstotal);
    }

    $('#filterWcgCharts').searchInput({defalutText: '输入WCG标识筛选数据'});  
    $('#filterWcgCharts').keyup(function(){
    	var str =$(this).val(),
    	target = ($('#wcgGird').css('display') == 'block' ? $('#wcgGird') : $('#wcgList'));
    	if(str == '') target.find('.searchlist').show();
    	target.find('.searchlist').hide().each(function(){
    		var data = $(this).attr('data');
    		if(data.indexOf(str) >= 0){
    			$(this).show();               
    		}
    	})
    })

    function wcgStatusUpdata(){
    	setInterval(function(){
    	  getdk(1);
          getwcgStatus(function(data){
			creatChatData(data['stats']);
          });
    	}, 5000);
    }
   
    initWcgPage(); 
    wcgStatusUpdata();
    

	$('#navbox, .viewmode').find('a').bind('click', tabSwitch);
	// $(window).scroll(function () {
	//   var scrollTop = document.body.scrollTop >=  document.documentElement.scrollTop ?  document.body.scrollTop : document.documentElement.scrollTop;
	//   scrollTop >= 55 ? $('#navbox').css('position', 'fixed'): $('#navbox').css('position', 'relative');		
	//   return false;
	// });
	function createCharts (node) {
		$('#CPUChartContainer, #RequestChartContainer, #memoryChartContainer').html('');
		chartsObj['charts' + node] = new loadChat();
	    chartsObj['charts' + node].createChat('CPUChartContainer', wcgStatusObj[node].cpu_arr, 100, '#75c0e0');
	    chartsObj['charts' + node].createChat('RequestChartContainer', wcgStatusObj[node].calls_arr, 250, '#7cd2c7');
	    chartsObj['charts' + node].createChat('memoryChartContainer', wcgStatusObj[node].memory_arr, 16, '#96a3d4');
	    updateChartsDom(node)
	}

	function createTotalCallsCharts() {
		chartsObj['chartscallsTotal'] = new loadChat();
		chartsObj['chartscallsTotal'].createChat('RequestChartTotalContainer', wcgStatusObj['callsTotal_arr'], maxcallstotal, '#7cd2c7');
	    updateCallsTotalCharts();
	    $('#requestNumberTotal').text(maxcallstotal);
	}

	var  updateCharts = function (node) {
        var Interval =   setInterval(function updateRandom() {
           var node = getNode($('.header-text').text());         
           if(!node) { 
           	 clearInterval(Interval); 
           	 return false;
           }
           updateChartsDom(node);
           chartsObj['charts' + node].updateChat('CPUChartContainer', wcgStatusObj[node].cpu_arr, 100, '#75c0e0');
	       chartsObj['charts' + node].updateChat('RequestChartContainer', wcgStatusObj[node].calls_arr, 250, '#7cd2c7');
	       chartsObj['charts' + node].updateChat('memoryChartContainer', wcgStatusObj[node].memory_arr, 16, '#96a3d4');
         }, 5000);
	}


	var updateCallsTotalCharts = function () {
	   var Interval =   setInterval(function updateRandom() {
         chartsObj['chartscallsTotal'].createChat('RequestChartTotalContainer', wcgStatusObj['callsTotal_arr'], maxcallstotal, '#7cd2c7');
	   }, 5000);
	}

	var updateChartsDom = function (node) {
	 	var cpu_arr = wcgStatusObj[node].cpu_arr ,
		    calls_arr = wcgStatusObj[node].calls_arr ,
		    mem_arr = wcgStatusObj[node].memory_arr , 
		    calls = calls_arr[calls_arr.length -1][1],
		    cpu = cpu_arr[cpu_arr.length-1][1],
		    mem = mem_arr[mem_arr.length-1][1]; 
	     $('#requestNumber').text(calls);
         $('#CPU').text(cpu);
         $('#memoryConsumption').text(mem);      
	}

	var updateDomInfo = function (node) {
	    var cpu_arr = wcgStatusObj[node].cpu_arr ,
         calls_arr = wcgStatusObj[node].calls_arr ,
         mem_arr = wcgStatusObj[node].memory_arr , 
         calls = calls_arr[calls_arr.length -1][1],
         cpu = cpu_arr[cpu_arr.length-1][1],
         mem = mem_arr[mem_arr.length-1][1],
         girdTag = $('#wcgGird_' + node),
         listTag = $('#wcgList_' + node);
         girdTag.find('.curcpuitem').text(cpu + '%');
	     girdTag.find('.curRequestitem').text(calls);
	     girdTag.find('.curmemitem').text(mem);
         listTag.find('.curcpuitem').text(cpu + '%');
	     listTag.find('.curRequestitem').text(calls);
	     listTag.find('.curmemitem').text(mem);
	}


})();