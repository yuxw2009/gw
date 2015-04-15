function tipBox(){
	this.roundPlayTimer = null;
	this.roundPlayPaused = false;
}
tipBox.prototype = {
	scheduleTip: function(sid, from, content){
		var curObj = this;
		var div = document.createElement('div')
		$(div).html(content);
		content =   $(div).text();		
		var alreadyExist = $('#newMsgTips').find('.tip_of_session_'+sid);
		if (alreadyExist.length == 0){
			var tipMsg = FormatModel(msgTipTemplate, {sid:sid, from:from, content:content});
			$('#newMsgTips .tipsCon_list').prepend(tipMsg);
            $('#newMsgTips .newMsgDetail_con').prepend(tipMsg);
            $('#newMsgTips').find('.tip_of_session_'+sid).unbind('click').bind('click', function(){
		    	sc.activate(sid);
		    	curObj.cancelTip(sid);
		    });
		}else{
			alreadyExist.find('.msg_from').html(from);
			$(content).appendTo(alreadyExist.find('.msg_content'))
			alreadyExist.find('.tipNum').html(parseInt(alreadyExist.find('.tipNum').html())+1);
		}
		$('#newMsgTips .totalTipCount').html(parseInt($('#newMsgTips .totalTipCount').html())+1);
		$('#newMsgTips').show();
		curObj.startRoundPlay();
	},
	cancelTip: function(sid){
		var removedCount = parseInt($('#newMsgTips .tipsCon_list').find('.tip_of_session_'+sid).find('.tipNum').html());
		$('#newMsgTips').find('.tip_of_session_'+sid).remove();
    	var restTips = $('#newMsgTips .newMsgDetail_con').find('.tipItem');
    	if (restTips.length == 0){
    		$('#newMsgTips').hide();
    		$('#newMsgTips .totalTipCount').html('0');
    		this.stopRoundPlay();
    	}else{
    		$('#newMsgTips .totalTipCount').html(parseInt($('#newMsgTips .totalTipCount').html())-removedCount);
    	}
	},
	startRoundPlay: function(){
		var curObj = this;
		var curShowIndex = 0;
		if (curObj.roundPlayTimer){
			clearInterval(curObj.roundPlayTimer);
		}
		curObj.roundPlayTimer = setInterval(function(){
			var num = $('#newMsgTips').find(".tipsCon_list dl").length;	
            curShowIndex += 1;
		    if (curShowIndex >= num) {
		        curShowIndex = 0;
		        $('#newMsgTips').find(".tipsCon_list").css("top",0)
		    }else{
		    	if (!curObj.roundPlayPaused){
			        $('#newMsgTips').find(".tipsCon_list").animate({
						top: curShowIndex * - 30
					 }, 500);
			    }
		    }
		}, 2000);

		$("#newMsgTips").mouseenter(function () {
			curObj.roundPlayPaused = true;
			$("#newMsgTips .newMsgDetail").fadeIn();
		}).mouseleave(function () {
			curObj.roundPlayPaused = false;
			$("#newMsgTips .newMsgDetail").fadeOut();
		})
	},
	stopRoundPlay: function(){
		if (this.roundPlayTimer){
			clearInterval(this.roundPlayTimer);
		}
		this.roundPlayTimer = null;
	}
}