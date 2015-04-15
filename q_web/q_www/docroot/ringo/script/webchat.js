
function paytoUse(obj){
  pageTips($(obj).parent(), 'Only for paid user!', 'info');
  setTimeout(function(){ removePageTips($(obj).parent()); }, 2000)
  return false;
}



//将Dom编辑到可编辑div最后并让其获取焦点

function insertAfter(targetEl){
    var parentEl = targetEl.parentNode;  
	 var space = document.createTextNode("\u00a0");  
    if(parentEl.lastChild == targetEl){
		  parentEl.appendChild(space);
    }else{
		  parentEl.insertBefore(space,targetEl.nextSibling);
   
    }  
	return space;          
}

function isOrContainsNode(ancestor, descendant) {
    var node = descendant;
    node_index = 0;
    while (node) {
        if (node === ancestor) {
            return true;
        }
        node = node.parentNode;
        node_index++;
    }
    return false;
}

function appendHtmlToDiv(textBox, node) {
    var sel,  html, text, range, focusAfterNode;
    var containerNode = document.getElementById($(textBox).attr('id'));

    if (window.getSelection) {
		containerNode.blur();
        sel = window.getSelection();
        if (sel.getRangeAt && sel.rangeCount) {
			 range = sel.getRangeAt(0);
            if (isOrContainsNode(containerNode, range.commonAncestorContainer)) {
                range.insertNode(node);
            } else {    
                containerNode.appendChild(node); 
            }
        }
		focusAfterNode = insertAfter(node);
		range.setStartAfter(focusAfterNode);
		range.setEndAfter(focusAfterNode);
		getSelection().addRange(range);
		containerNode.focus();	

		
    } else if (document.selection && document.selection.createRange) {        
           range3 = document.selection.createRange();
        if (isOrContainsNode(containerNode, range3.parentElement())) {
            html = (node.nodeType == 3) ? node.data + '&nbsp;' : node.outerHTML + '&nbsp;';
           range3.pasteHTML(html);
        } else {
            containerNode.appendChild(node);
            containerNode.innerHTML += '&nbsp;';
        }
        containerNode.innerHTML = containerNode.innerHTML.replace(str , '');
    }
}


String.prototype.replaceAll = function(s1,s2){  
  return this.replace(new RegExp(s1,"gm"),s2);    
}


function webChat(sid){
	this.sid = sid;
	this.winDom = $('#window_'+sid+'_warp');
}

webChat.prototype = {
	bindHandlers: function(){
		var curObj = this;
    	curObj.winDom.find('.sendmsg').unbind('click').bind('click', function(){
    		var txt = curObj.winDom.find('.chat_mcon').eq(0).html();
            if (txt.length > 0){
        		curObj.displaySingleMsg('append', curObj.sendMsg(txt));
        		curObj.winDom.find('.chat_mcon').eq(0).html('');
            }
            return false;
    	});
    	curObj.winDom.find('.expressionBtn').unbind('click').bind('click', function(){
            if( curObj.winDom.find('.faceBox').length == 0){
    	      $('#faceBox').find('.faceBox').clone().appendTo($(this).parent());
		      curObj.winDom.find('.faceBox').hide();
			}
			curObj.winDom.find('.faceBox').fadeToggle().find('li').unbind('click').bind('click', function(){
				var _this = $(this);
				var img = document.createElement("img");
			//	var id = 'faceimg'+ parseInt(Math.random()*10E20);
				img.src = _this.find('img').attr('src');
				img.width = 32;
				img.height = 32;
			//	img.id = id;
				_this.parent().parent().hide();
			    appendHtmlToDiv(curObj.winDom.find('.chat_mcon').eq(0),img);	
			    return false;
		    })
    	});


	  curObj.winDom.find('.chat_mcon').bind($.browser.msie?"beforepaste":"paste",function(e){
		   var _this = $(this);
		   $("#pasteTextarea").focus();       
		   setTimeout(function(){ 
			  _this.html(_this.html() + '<pre>' + $("#pasteTextarea").val().replaceAll('<', '< ')+ '</pre>');  
			  _this.focus();  
			 $("#pasteTextarea").val('');
		   },0); 
      });
				
		
    	document.getElementById('window_'+curObj.sid+'_warp').onkeydown = function(event){
            e = event ? event : (window.event ? window.event : null);
            //if (e.keyCode == 13 && e.ctrlKey) {
            if (e.keyCode == 13) {
                curObj.winDom.find('.sendmsg').click();
                return false;
            }
        };
    	return this;
	},
	sendMsg: function(msgTxt){
		var dt = formatDateTimeString(new Date()); 
		var msgPayload = {uuid:myID(), name:myName(), media_type:'chat', timestamp:dt, content:msgTxt};
		
		hp.sendData({type:"session_message", session_id:this.sid, payload:msgPayload});
		return msgPayload;
	},
	displayMsgs: function(preOrappend, Msgs){
        var html = '';
        for (var i = 0; i < Msgs.length; i++){
            switch (Msgs[i].media_type){
                case 'chat':
                    html += FormatModel(txtMsgItemTemplate, {author:(Msgs[i].uuid == myID() ? 'fromMe' : 'fromOthers'), name:Msgs[i].name, timestamp:Msgs[i].timestamp, content:Msgs[i].content});
                    break;
                case 'video_conf':
                    html += '';
                    break;
                default:
                    break;
            }
            
        }
        if (preOrappend == 'prepend'){
            this.winDom.find('.chatWin_con').prepend(html);
            this.winDom.find('.chatWin_con').scrollTop(0);
        }else{
            this.winDom.find('.chatWin_con').append(html);
            if (html.length > 0){
                var history_line = '<div class="readed_hr"><span class="readed_line"></span><span class="readed_content"> time line </span><span class="readed_line"></span></div>';
                this.winDom.find('.chatWin_con').append(history_line);
            }
            this.winDom.find('.chatWin_con').scrollTop(this.winDom.find('.chatWin_con')[0].scrollHeight);
        }
    },
    displaySingleMsg: function(preOrappend, msgPayload){
        var html = this.createMsgDom(msgPayload);
        if (preOrappend == 'prepend'){
            this.winDom.find('.chatWin_con').prepend(html);
            this.winDom.find('.chatWin_con').scrollTop(0);
        }else{
            this.winDom.find('.chatWin_con').append(html);
            this.winDom.find('.chatWin_con').scrollTop(this.winDom.find('.chatWin_con')[0].scrollHeight);
        }
    },
    createMsgDom: function(msgPayload){
    	var html = '';
    	switch (msgPayload.media_type){
    		case 'chat':
    		    html = FormatModel(txtMsgItemTemplate, {author:(msgPayload.uuid == myID() ? 'fromMe' : 'fromOthers'), name:msgPayload.name, timestamp:msgPayload.timestamp, content:msgPayload.content});
    		    break;
    		case 'video_conf':
    		    if (msgPayload.action == 'invite'){
    		    	html = FormatModel(mpvInviteMsgItemTemplate, {host_name:msgPayload.host_name, host_id:msgPayload.host_id, room_no:msgPayload.conf_no, seat_no:msgPayload.position});
    		    }else if (msgPayload.action == 'conf_ongoing'){
                    if (msgPayload.host_id == myID()){
        		    	html = FormatModel(mpvOngoingMsgItemTemplate, {room_no:msgPayload.conf_no, seat_no:msgPayload.position});
                    }else{
                        html = FormatModel(mpvInviteMsgItemTemplate, {host_name:msgPayload.host_name, host_id:msgPayload.host_id, room_no:msgPayload.conf_no, seat_no:msgPayload.position});
                    }
    		    }
    		    break;
            case 'video_p2p':
                if (msgPayload.action == 'peer_invite'){
                    html = FormatModel(p2pInviteMsgItemTemplate, {invite:'video', invitestr:'a video', peer_name:msgPayload.name, peer_id:msgPayload.uuid, sdp:msgPayload.sdp});
                }
                break;
            case 'audio_p2p':
                if (msgPayload.action == 'peer_invite'){
                    html = FormatModel(p2pInviteMsgItemTemplate, {invite:'audio', invitestr:'an audio', peer_name:msgPayload.name, peer_id:msgPayload.uuid, sdp:msgPayload.sdp});
                }
                break;
            default:
                break;
    	}
    	return html;
    }
}