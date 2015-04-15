function dragable(el){
	var els = el,
		x = y = 0,
		dragX = dargY = 0;
	var img, employer_uuid;
	var dragContianer = $('#chat_box');
	var employer_status;
	el.mousedown(function(e){
		x = e.clientX + document.body.scrollLeft,
		y = e.clientY + document.body.scrollTop,
		img = $(this).attr('src'),
		employer_uuid = $(this).next().attr('uuid'),
		dragX = dragContianer.position().left,
        dargY = dragContianer.position().top;
        employer_status =  $(this).parent().find('.buddyChat').length > 0 ? true :false;
		el.setCapture ? (
			el.setCapture(),
			el.onmousemove = function(ev){
				mouseMove(ev || event)
			},
			el.onmouseup = mouseUp
		) : (
			$(document).bind("mousemove",mouseMove).bind("mouseup",mouseUp)
		)
		e.preventDefault();
	});

	 


	function allowMove(curX, curY){
		  var f1 = curX - x > 20 || curY - x < -20,
		   f2 = curX > dragX,
		   f3 = curX < dragX + 660  && curY < dargY +250;
		  return f1 && f2 && f3;
	}
	function removeDom(dragDom){
	    dragDom.animate({
		    left: x,
		    top: y
		  }, 500, function() {
		     $(this).remove();
		  });
        $('body').css({'cursor':'default'});
	}
	function mouseMove(e){ 
	    var curX =  e.clientX + document.body.scrollLeft,
		    curY = e.clientY + document.body.scrollTop;
		var dragDom = $('#dragDom');
		if(allowMove(curX, curY) && employer_status){
			if(dragDom.length <= 0){
		       $('body').css({'cursor':'move'});
		       $('<div id="dragDom" uuid ="'+ employer_uuid +'" style="display:none"><img width="38" height="38" src="'+ img+'"/></div>').appendTo('body');
            }
            dragDom.css({'position':'absolute','cursor':'move','left':curX - 10, 'top':curY - 10, 'display':'block'});
        }else{
        	removeDom(dragDom);
            $('body').css({'cursor':'default'});
        }
	}  
     function mouseUpHandle(curX, curY){
		var dragDom = $('#dragDom');
        if(curX > dragX + 80 && curX < dragX + 440 && curY > dargY && employer_status){
        	imClient.invitePerson(employer_uuid.toString());           
           $('#dragDom').remove();
        }else{
           removeDom(dragDom);
        }
     }

	function mouseUp(e){
		el.releaseCapture ? (
			el.releaseCapture(),
			el.onmousemove = el.onmouseup = null
		) : (
		    mouseUpHandle(e.clientX + document.body.scrollLeft, e.clientY + document.body.scrollTop),
		    $('body').css({'cursor':'default'}),
			$(document).unbind("mousemove", mouseMove).unbind("mouseup", mouseUp)
		)
	}
}

$('#chat_box .chat_ico_mini').unbind('click').bind('click', function(){
  	$('#chat_box').removeClass('present_chat_view').hide();
  	$('#chatMiniRoot').addClass('present_chat_view').show();
  	return false;
});

$('#chatMiniRoot').unbind('click').bind('click', function(){
    $(this).removeClass('present_chat_view').removeClass('chatMiniNewmsg').hide().find('.chatMiniRootName').text(lw_lang.ID_IM_VIEW_MY_IM);
    $('#chat_box').addClass('present_chat_view').show();
    imClient.chooseChat(imClient.curActive);
    return false;
});

$('#chat_box').find('.chat_ico_x').unbind('click').bind('click', function(){
    $(this).parent().remove();
	return false;
});

function isListEqual(l1, l2){
	if (l1.length != l2.length){
		return false;
	}

	var sl1 = l1.sort(), sl2 = l2.sort();
	for (var i = 0; i < sl1.length; i++){
		if (sl1[i] != sl2[i]){
			return false;
		}
	}
	return true;
}

function imClient(){
	this.sessions = {};
	this.curActive = null;
}
imClient.prototype = {
	bindHandlers: function(){
		var curObj = this;
		dragable($('.employer_list').find('img'));

		$('.buddyChat').unbind('click').bind('click', function(){
			var aUUID = $(this).attr('uuid');
			var inSession = curObj.findInSession([aUUID, uuid]);
			if (inSession){
				curObj.chooseChat(inSession);
			}else{
				curObj.newChat([aUUID, uuid]);
			}
			return false;

		});

		document.getElementById('chat_win').onkeydown = function(event){
        //document.onkeydown = function(event){	
			e = event ? event : (window.event ? window.event : null);
			//&& e.ctrlKey
			if (e.keyCode == 13) {
				var fsid = curObj.curActive;
				$('#im_post_'+fsid+' .chat_bt_post').click();
			    return false;
			}
		};

	},
	onReceivedMsg : function(msg){
		var sid = msg.session_id.toString();
		//console.log(msg);
		if (!this.sessions[sid]){
			if(msg.content.type == 'leave' && msg.members.length == 1 && msg.members[0] == uuid){
				api.im.leave(uuid, sid, function(){});
				return;
			}
            this.newSession(sid, msg.members);
		}else{
			this.checkMemberList(sid, msg.members);
		}
		this.appendMsg(sid, msg.from, msg.content);
		this.sessions[sid]['latestSpeaker'] = msg.from.toString();

		if ($('#chat_box').hasClass('present_chat_view') && this.curActive == sid){
			this.showSpeakerInTitle(msg.from);
		}else{
			this.indicateChat(sid, msg.from);
		}
		showNotification("/images/unread_chat.gif", lw_lang.ID_MESSAGE_NOTE, lw_lang.ID_WEBIM_NOTEMSG + employer_status[subscriptArray[msg.from]].name);

		if (!this.curActive){
			this.chooseChat(sid);
		}
	},
	checkMemberList: function(sid, ml){
		var oldList = this.sessions[sid].members;
		var newList = ml.sort().map(function(item){return item.toString();});
		oldList.sort();
		if (!isListEqual(newList, oldList)){
            this.sessions[sid]['members'] = newList;
            this.updateMemberList(sid, newList);
		}
	},
	updateLatestSpeaker: function(sid, latest){
		this.sessions[sid]['latestSpeaker'] = latest.toString();
		if (this.curActive == sid){
			this.showSpeakerInTitle(latest);
		}
	},
	newSession: function(sid, members){
		this.sessions[sid] = {"members":members.map(function(item){return item.toString();})};
		this.createChat(sid);
		this.bindChatHandlers(sid);
	},
	findInSession: function(ml){
		var newl = ml.sort();
		for (sid in this.sessions){
			var oldl = this.sessions[sid]['members'];
			if (isListEqual(ml, oldl)){
				return sid;
			}
		}
		return false;
	},
	isChatting: function(){
        return $('#chat_box').hasClass('present_chat_view') || $('#chatMiniRoot').hasClass('present_chat_view');
	},
	//User click actions
	newChat: function(initMembers){
		var curObj = this;
        var members = initMembers;
        api.im.createSession(uuid, members, function(data){
        	    var sid = data.session_id.toString();
        	    curObj.sessions[sid] = {'members':members, 'latestSpeaker':uuid};
        	    curObj.createChat(sid);
        	    curObj.bindChatHandlers(sid);
                $('#chatMiniRoot').click();
                curObj.chooseChat(sid);
            }, function(faildata){
            	LWORK.msgbox.show(lw_lang.ID_IM_CREATE_SESSION_FAILED, 5, 2000);
            });
	},
	invitePerson: function(iUUID){
		var curObj = this;
		var user = employer_status[subscriptArray[iUUID]];
		if (user.status == 'online'){
			if (curObj.sessions[curObj.curActive].members.indexOf(iUUID) < 0){
				api.im.invite(uuid, curObj.curActive, [iUUID], function(){
					var content = {"type":"invite",
					               "txt": lw_lang.ID_IM_I_INVITE + user.name + lw_lang.ID_IM_TO_JOIN_CHAT, 
					               "attachments":[], 
					               "images":[]};
					curObj.sendMessage(content);
				}, function(){})
			}else{
				LWORK.msgbox.show(user.name+lw_lang.ID_IM_ALREADY_IN_SESSION, 3, 2000);
			}
		}else{
			LWORK.msgbox.show(lw_lang.ID_IM_CANT_INVITE_OFFLINES, 3, 2000);
		}
	},
	chooseChat: function(sid){
		if (sid != this.curActive){
            if (this.curActive != null){
            	this.hideChat(this.curActive);
            }
            this.curActive = sid;
            this.showChat(this.curActive);
            this.showSpeakerInTitle(this.sessions[sid].latestSpeaker);
		    var chatMsgObject = document.getElementById('sid_'+ sid);
		    chatMsgObject.scrollTop=chatMsgObject.scrollHeight;
		}
		$('#chat_box').find('ul.chat_win_list .im_session_'+sid).removeClass('indicating_msg');
		$('#sid_'+sid).find('.chat_box_post_ta').focus();
	},
	closeChat: function(sid){
		var curObj = this;
		if (sid == curObj.curActive){
			api.im.leave(uuid, curObj.curActive, function(){
				var content = {"type":"leave",
				           "txt": lw_lang.ID_IM_I_QUITED, 
			               "attachments":[], 
			               "images":[]};
				curObj.sendMessage(content);
				curObj.destoryChat(curObj.curActive);
				delete curObj.sessions[sid];
				if ($('#chat_box').find('ul.chat_win_list li.chat_rooom').length > 0){
					var newActive = $('#chat_box').find('ul.chat_win_list li.chat_rooom').eq(0).attr('sid');
					curObj.chooseChat(newActive);
				}else{
					$('#chat_box').removeClass('present_chat_view').hide();
					curObj.curActive = null;
				}
			});
					
		}
	},
	sendMessage: function(contentJSON){
		var curObj = this;
		var inTalkingSid = curObj.curActive;
		api.im.sendmsg(uuid, inTalkingSid, contentJSON, function(){}, function(){});
	},
	//Dom updating functions
	bindChatHandlers: function(sid){
		var curObj = this;
		$('#chat_box').find('ul.chat_win_list .im_session_'+sid).unbind('click').bind('click', function(){
			var fsid = $(this).attr('sid');
			$('#chatMiniRoot').removeClass('chatMiniNewmsg');
            curObj.chooseChat(fsid);
            return false;
        });
        $('#chat_win').find('.chat_bt_post').unbind('click').bind('click', function(){
        	var fsid = $(this).attr('sid');
        	var txt = loadContent.format_message_content($('#chat_win').find('.im_session_'+fsid+ ' .chat_box_post_ta').getPreText(), 'linkuser');
        	if (txt.length > 0){
	        	curObj.sendMessage({'type':'talk','txt':txt});
	        	$('#chat_win').find('.im_session_'+fsid+ ' .chat_box_post_ta').text('');
	        }
	        return false;
        });

	    $('#chat_box').find('.chat_rooom').live('mouseover', function(){
	      	$(this).find('.chatroom_close').show();
	    }).live('mouseout', function(){
	    	$(this).find('.chatroom_close').hide();
	    });

	    $('#chat_box').find('ul.chat_win_list .im_session_'+sid+' a.chatroom_close').unbind('click').bind('click', function(){
	    	var s = $(this).parent().attr('sid');
	    	curObj.closeChat(s);
	    });
	},
	createChat: function(sid){
		var memberlistDom = this.createMLDom(this.sessions[sid].members);
        var chatTabDom = ['<li title=""  class="chat_rooom '+ 'im_session_' + sid + '" sid="'+sid+'">',
				             '<div class="chat_username"><span class="chat_icon"></span>'+lw_lang.ID_IM_CHATROOM+'</div>',
				             '<a class="chatroom_close" href="###"></a>',
				             '<ul class="members_in_chat" style="display:none">',
				             memberlistDom,
				             '</ul>',
				           '</li>',].join('');
		var chatDlgDom = ['<div class="chat_box_cont '+ 'im_session_' + sid + '" style="display:none">',
				             '<div class="chat_box_msg" id="sid_'+sid+'" sid="'+sid+'" isfirstloadhistory="no" offset="0" tabIndex="11"></div>',       
				             '<div class="chat_box_post" id="im_post_'+sid+'">',      
				                '<div class="chat_box_post_img" style="height: 7px; overflow: hidden; visibility: hidden; "></div>',         
				                '<div class="rich_in chat_box_post_ta" contenteditable="true" style="height: 60px; "></div> ' ,        
				                '<div class="chat_box_post_tool">' ,
				                   '<div class="chat_box_post_t2">',
				                    // '<span class="direct_send_tip">'+lw_lang.ID_IM_DIRECT_SEND_TIP+'</span>',
				                      '<a href="#" role="button" class="chat_bt_post" sid="'+sid+'"><b class="button_green"><span class="b-txt">'+lw_lang.ID_IM_SEND_MSG+'</span></b></a>',
				                   '</div>',        
				                '</div>',
				             '</div>',
				          '</div>'].join('');
        $('#chat_box').find('ul.chat_win_list').append(chatTabDom);
        $('#chat_win').append(chatDlgDom);
        //this.showHideChatRooms();
	},
	destoryChat: function(sid){
		$('#chat_box').find('ul.chat_win_list .im_session_'+sid).remove();
		$('#chat_win').find('.im_session_'+sid).remove();
		//this.showHideChatRooms();
	},
	showHideChatRooms: function(){
		if ($('#chat_box').find('ul.chat_win_list li.chat_rooom').length > 1 || 
			($('#chat_box').find('ul.chat_win_list li.chat_rooom').length == 1 &&
			 $('#chat_box').find('ul.members_in_chat li.item').length > 2)){
			$('#chat_box .chat_box_session').show();
		}else{
			$('#chat_box .chat_box_session').hide();
		}
	},
	createMLDom: function(mlist){
		var html = '';
		for (var i = 0; i < mlist.length; i++){
			var user = employer_status[subscriptArray[mlist[i].toString()]];
			html += ['<li class="item" >',
                         '<img src="'+user.photo+'" alt="'+user.name+'" class="chat_user_pic">',
                         '<p class="chat_user_name"> <span class="name">'+user.name+'</span> </p> ',
                      '</li>'].join('');

		}
		html +='';
		return html;
	},
	updateMemberList: function(sid, mlist){
		var memberlistDom = this.createMLDom(this.sessions[sid].members);
		$('#chat_box').find('ul.chat_win_list li.im_session_'+sid+' ul.members_in_chat').html(memberlistDom);
	},
	appendMsg: function(sid, from, content){
		var fromUser = employer_status[subscriptArray[from.toString()]];
		var timeStr = (new Date()).toTimeString().split(' ')[0];
		var chatMsgObj = $('#sid_'+ sid);
		var chatMsgObject = document.getElementById('sid_'+ sid);
		var msgDom = ['<div class="chat_dia_box ' + (from == uuid ? 'chat_dia_r' : 'chat_dia_l') + '">',
		                '<div class="dia_icon"> <img src="'+fromUser.photo+'" alt="'+fromUser.name+'" class="chat_user_pic"> </div>',
		                '<div class="info_from">'+fromUser.name+' (<span class="info_date">'+timeStr+'</span>):</div>',
		                '<div class="chat_dia_bg">',
		                  '<div class="dia_con">',		             
		                    '<p class="dia_txt">'+content.txt+'</p>',
		                    '<div class="dia_att"> </div>',
		                  '</div>',
		                  '<div class="msg_arr"> </div>',
		                '</div>',
		              '</div>',
		              '<div class="chat_dia_line"></div>'
		              ].join('');
		chatMsgObj.append(msgDom);
        chatMsgObject.scrollTop=chatMsgObject.scrollHeight;
	},
	showSpeakerInTitle: function(speakerUUID){
		var user = employer_status[subscriptArray[speakerUUID.toString()]];
		$('#chat_box').find('.chat_box_name').text(user.name);
		$('#chat_box').find('.chat_item_pic img.chat_user_pic').attr('src', user.photo);
	},
	indicateChat: function(sid, speakerUUID){
		var user = employer_status[subscriptArray[speakerUUID.toString()]];
		if ($('#chat_box').hasClass('present_chat_view')){
			$('#chat_box').find('ul.chat_win_list .im_session_'+sid).addClass('indicating_msg');
		}else if ($('#chatMiniRoot').hasClass('present_chat_view')){
			$('#chat_box').find('ul.chat_win_list .im_session_'+sid).addClass('indicating_msg');
			$('#chatMiniRoot').addClass('chatMiniNewmsg').find('.chatMiniRootName').text(user.name);
		}else{
			$('#chatMiniRoot').addClass('present_chat_view').show();
			$('#chat_box').find('ul.chat_win_list .im_session_'+sid).addClass('indicating_msg');
			$('#chatMiniRoot').addClass('chatMiniNewmsg').find('.chatMiniRootName').text(user.name);
		}
	},
	hideChat: function(sid){
		$('#chat_win').find('.im_session_'+sid).hide();
	},
	showChat: function(sid){
		$('#chat_box').find('ul.chat_win_list .im_session_'+sid).addClass('chat_active').find('ul.members_in_chat').show();
		$('#chat_box').find('ul.chat_win_list .im_session_'+sid).siblings().removeClass('chat_active').find('ul.members_in_chat').hide();
		$('#chat_win').find('.im_session_'+sid).show().siblings().hide();
	}
}

