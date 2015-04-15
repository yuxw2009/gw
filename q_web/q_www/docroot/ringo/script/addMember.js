//$('#slelectFriend .selectbox').html(this.createFriendList(ci));
function addMember(winID, winName, onOKCallback){
	  this.winID = winID;
	  this.winName = winName;
	  this.onOKCallback = onOKCallback;	
	  this.leftSel = '';
	  this.rightSel = '' ;
}
addMember.prototype = {
	init: function(initMembers){
		var curObj = this;
		mainmark.copyFriendListDom();
		Core.create({ 'id': curObj.winID, 'name':  curObj.winName , 'resize':false, 'content': $('#slelectFriendbox').find('.slelectFriend').clone(true), height:417});		
		var winBox = $('#window_'+ curObj.winID  +'_warp');
		curObj.leftSel = winBox.find('.selectLeft');
		curObj.rightSel = winBox.find('.selectRight');
		curObj.bindHandlers();
		for (var i = 0; i < initMembers.length; i++){
			curObj.leftSel.find('.friend_item_'+initMembers[i]).dblclick();
			curObj.rightSel.find('.friend_item_'+initMembers[i]).addClass('init_member');
		}		
	},
	bindHandlers: function(){
		var curobj = this;
		var winBox = $('#window_'+ curobj.winID  +'_warp');
		winBox.find('dd.frienditem').click(function(){
			var _this = $(this);
			if (!_this.hasClass('init_member'))
				_this.hasClass('current') ? _this.removeClass('current') :_this.addClass('current');
			return false;
		});
		curobj.leftSel.find('dd.frienditem').live('dblclick', function(){
			$('body').addClass('noSelect');		
			$(this).clone(true).appendTo(curobj.rightSel);
			$(this).hide();
			curobj.rightSel.find('dd:last').show();
			curobj.rightSel.find('dd').removeClass('current');
			return false;
		});			
		curobj.rightSel.find('dd.frienditem').live('dblclick', function(){
			$('body').addClass('noSelect');	
			if ($(this).hasClass('init_member')){
				LWORK.msgbox.show('不能移除初始成员', 3, 1000);
			}else{
				var UUID = $(this).attr('uuid');
				curobj.leftSel.find('dd.friend_item_'+UUID).show();
				$(this).remove();
				curobj.leftSel.find('dd.frienditem').removeClass('current');	
			}
			return false;
		});
		winBox.find(".toright").bind("click",function(){	
			curobj.leftSel.find(".current").each(function(){
				$(this).clone(true).appendTo(curobj.rightSel);
				$(this).hide();
				curobj.rightSel.find('dd').removeClass('current');
			});
			return false;
		});		
		winBox.find(".toleft").bind("click",function(){		
			curobj.rightSel.find(".current").each(function(){
				var UUID = $(this).attr('uuid');
				curobj.leftSel.find('dd.friend_item_'+UUID).show();
				$(this).remove();
				curobj.leftSel.find('dd.frienditem').removeClass('current');				
			});
			return false;			
		});
		winBox.find('.addMemberBtn').bind('click', function(){
			var toAddlist = new Array();
			$('body').removeClass('noSelect')	
			curobj.rightSel.find('dd').each(function(){
			  	if (!$(this).hasClass('init_member')){
					toAddlist.push($(this).attr('uuid'))
			    }
			});
			if (toAddlist.length == 0){
				LWORK.msgbox.show('没有新增成员', 3, 1000);
			}else{
			    curobj.onOKCallback(toAddlist);
				winBox.find('.cw_close').click();
			}
			return false;			  
		});
		winBox.find('.cancelAddBtn').unbind('click').bind('click', function(){
			$('body').removeClass('noSelect')		
			winBox.find('.cw_close').click();
			return false;
		});
	}
}