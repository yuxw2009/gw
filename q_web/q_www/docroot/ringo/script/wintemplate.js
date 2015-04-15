//任务栏模板
var taskTemp = 
'<li id="taskTemp_{id}" class="taskmenu {statuscss}" window="{id}">'+
	'<b class="focus">'+
		'<img src="{photo}">'+
		'<span class="task_title">{title}</span>'+
	'</b>'+
'</li>';


//聊天窗体模板
var p2pchatwinTemplate = 
    ['<div  id="window_{id}_warp" class="chat_win window-container window-current" window="{id}"  style="width:{width}px; height:{height}px;top:{top}px;left:{left}px;z-index:{zIndex}">',
      '<dl class="chatWin_header header">',
        '<dd class="cw_l"></dd>',
        '<dd class="cw_c">',
          '<div class="chat_obj  {statuscss}"> <img src="{photo}"  width="50" height="50" />',
            '<div class="chatObj_name"> <span class="chatObjText">{name}</span> <span class="status">({status})</span></div>',
            '<div class="Signature" title={Signature}>{Signature}</div>',
          '</div>',
            '<div class="cw_btn"> <a class="cw_min" href="###" title="Min"></a><a btn="max" href="###" class="cw_max" title="Max"></a><a class="cw_revert"  href="###" title="Middle"></a><a href="###"  class="cw_close" title="Close"></a></div>',
        '</dd>',
      '</dl>',
        '<dl class="cw_optBtn"><dd>',
      '<a href="###" title="Video call" class="S_video"><span> </span> </a>',
        '<a href="###" title="Busy" class="Disabled_video"> </a>',  
        '<a href="###" title="Send file"  class="S_file"><span> </span> </a> ',
        '<a href="###" title="Audio Call" class="S_audio"><span> </span> </a>',
        '<a href="###" onclick ="paytoUse(this)" title="Call a phone" class="S_call"><span> </span> </a>',     
        '<a href="###" onclick ="paytoUse(this)" title="SMS" class="S_sms"><span> </span> </a>',             
            '<div class="sharefile_handle">',		
	         '<form enctype="multipart/form-data" action="/lw_upload.yaws" method="post">',
			   '<input type="file" class="DiskFile" onchange="sharefiles_handle(this)" title="Send file"  name="upld"  />',
			 ' <input type="submit" value="submit_files" class="submit_sharefile" style="display:none"/>',
			'</form>',			
			'</div>',
		'<a href="###" title="Create discuss group" class="S_addm"><span></span></a></dd></dl>',	
      '<dl>',
        '<dd class="chatWin_box discussBox">',
          '<div class="chatWin_conbox">',
            '<div  class="chatWin_con"> </div>',
            '<div  class="chat_expression"><a href="###" class="expressionBtn"></a></div>',				
            '<div class="chat_mbox">',
              '<div class="chat_mcon" id="chat_mcon_{id}" contenteditable="true"></div>',
            '</div>',
            '<dl class="chatWin_foot">',
              '<dd class="cw_c"><a href="###" class="sendmsg">Send</a> </dd>',
            '</dl>',
          '</div>',
         '<div class="ribbonBox" style="display:none"> ',   
            '<div class="ribbonMenu">',
              '<a link ="video" class="videomenu" href="###">Video call</a>',
              '<a link ="voice" class="audiomenu" href="###">Audio call</a>',	
              '</div>',
            '<div>',			
			   '<div class="video p2pVideo" style="display:block">',		   
					'<dl>',
					  '<dd class="p2pvideoBox">' ,
						 '<div class="p2pVideoTip"> Waiting... </div>',
						 '<video class="p2p_video_screen big_video_Screen"  id="p2pvideo_{id}_big" autoplay  preload="auto" width="100%" height="100%" data-setup="{}"></video>',
						 '<video class="p2p_video_screen small_video_Screen" autoplay  preload="auto" width="100%" height="100%" data-setup="{}"></video>',
					  '</dd>',
					'</dl>',
					'<div class="videoOpt">',
					   '<div class="videOpt_c"> <span class="videoTime">Time: <span class="videoCurrentTime"> 00:00:00 </span> </span> <a href="###" class="fullscreen">Full Screen</a> <a href="###" class="vhangUp hangUp">Hangup</a> </div>',
					'</div>',
				'</div>',
				  '<div class="audio p2pAudio" style="display:none">',
						'<div class="p2pAudioTip">Waiting...</div>',
            '<div class="p2pAudioStatus"><img src="images/micromark.gif"/></div>',
						'<dl>',
						  '<dd class="p2paudioBox">',
							 '<video class="p2p_audio_screen big_audio_Screen"  id="p2paudio_{id}_big" autoplay  preload="auto" width="100%" height="100%" data-setup="{}"></video>',
							 '</dd>',
						'</dl>',
					   '<div class="audioOpt"><a href="###" class="ahangUp hangUp">Hangup</a> </div>',
				'</div>',			 
            '</div>',
           '</div> ',
		'</div> ',
        '</div>',
        '</dd>',
      '</dl>',
//	  '{resize}',
//	   '<div style="position:absolute;overflow:hidden;background:url(images/transparent.gif) repeat;display:block" resize="min_width"></div>',
//	   '<div style="position:absolute;overflow:hidden;background:url(images/transparent.gif) repeat;display:block" resize="min_height"></div>',
    '</div>'].join('')
	
	
var mpchatwinTemplate = 
    ['<div  id="window_{id}_warp" class="mp_caht_win chat_win window-container window-current" window="{id}"  style="width:{width}px; height:{height}px;top:{top}px;left:{left}px;z-index:{zIndex}">',
      '<dl class="chatWin_header header">',
        '<dd class="cw_l"></dd>',
        '<dd class="cw_c">',
          '<div class="chat_obj"> <img src="{photo}"  width="50" height="50" />',
            '<div class="chatObj_name">{name}</div>',

          '</div>',
         '<div class="cw_btn"> <a class="cw_min" href="###" title="Min"></a><a btn="max" href="###" class="cw_max" title="Max"></a><a class="cw_revert"  href="###" title="Middle"></a><a href="###"  class="cw_close" title="Close"></a></div>',
        '</dd>',
      '</dl>',

	  '<dl  class="cw_optBtn"><dd> ',
	    '<div class="Signature editDiscuGroupNameBox"><input value="Edit name" class="eiditDiscusGroupName" type="text"/></div>',
		'<a href="###" title="Video call" class="S_video"><span> </span> </a>', 
	//	'<a href="###" title="Busy" class="Disabled_video"> </a>',	
		'<a href="###" title="Send file"  class="S_file"><span> </span> </a>', 
    '<a href="###" title="Audio call"  onclick ="paytoUse(this)" class="S_audio"><span> </span> </a>', 
    '<a href="###" title="Call a phone" onclick ="paytoUse(this)" onclick ="paytoUse(this)" class="S_call"><span> </span> </a> ',  
    '<a href="###" title="SMS"  onclick ="paytoUse(this)" onclick ="paytoUse(this)" class="S_sms"><span> </span> </a>',        
		'<div class="sharefile_handle">',		
		 '<form enctype="multipart/form-data" action="/lw_upload.yaws" method="post">',
		   '<input type="file"  class="DiskFile" onchange="sharefiles_handle(this)" title="Send file"  name="upld"  />',
		 ' <input type="submit" value="submit_files" class="submit_sharefile" style="display:none"/>',
		'</form>',			
		'</div>',	
		'<a href="###" title="Add members" class="S_addm"><span></span></a>', 
		'<a href="###" title="Leave this group" class="S_quit"><span></span></a></dd></dl>',
      '<dl>',
	  
        '<dd class="chatWin_box discussBox">',
          '<div class="chatWin_conbox">',
            '<div  class="chatWin_con"></div>',
            '<div  class="chat_expression"><a href="###" class="expressionBtn"></a></div>',	
            '<div class="chat_mbox">',
              '<div class="chat_mcon"  id="chat_mcon_{id}" contenteditable="true"></div>',
            '</div>',
            '<dl class="chatWin_foot">',
              '<dd class="cw_c"><a href="###" class="sendmsg">Send</a> </dd>',
            '</dl>',
          '</div>',
          		  
        '<div class="ribbonBox">',   
              '<div class="ribbonMenu">',
                '<a link = "discusMem" class="TabDiscusMem" href="###">Members</a><span> | </span><a link ="video" href="###" class="active">Video</a>',
              '</div>',
              '<div class="winTabBox">',
                  '<div class="discusMem" style="display:none;">',
                    '<dl class="memberList">',
                    '</dl>',
                  '</div>',
                  '<div class="video">',
                    '<video class="video_screen" id="mpvideo_{id}_box" autoplay controls preload="auto" width="100%" height="100%" data-setup="{}"></video>', 
                    '<dl>',
                      '<dd class="fvideo seat seat0 free" seat="0" mUUID="">',
					    '<span class="videObjInfo"> </span>',
						'<span class="freeTip">Idle<br>+ Invite friend</span>',								
					    '<div class="videoStatus"><span class="videoObjName"></span> <span class="videoTip">Waiting...</span></div>',
                        '<div class="videoObjOpt">',
                          '<div class="videOptCon"> <input class="inputToInvite" type="text" value="" toInviteID=""> <a href="###" class="inviteInVideo">Invite</a>',
						    '<dl class="inviteList">',
														
							'</dl> ',
						  '</div>',
                        '</div>',
                      '</dd>',
                      '<dd class="fvideo seat seat1 free" seat="1" mUUID="">',					  
					    '<span class="videObjInfo"> </span>',
						'<span class="freeTip">Idle<br>+ Invite friend</span>',	
					    '<div class="videoStatus"><span class="videoObjName"></span> <span class="videoTip">Waiting...</span></div>',											  
                        '<div class="videoObjOpt">',
                          '<div class="videOptCon"> <input class="inputToInvite" type="text" value="" toInviteID=""> <a href="###" class="inviteInVideo">Invite</a>',
						    '<dl class="inviteList">',							
							'</dl> ',
						  '</div>',
                        '</div>',
                      '</dd>',
                      '<dd class="tvideo seat seat2 free" seat="2" mUUID="">',
					    '<span class="videObjInfo"> </span>',
						'<span class="freeTip">Idle<br>+ Invite friend</span>',
					    '<div class="videoStatus"><span class="videoObjName"></span> <span class="videoTip">Waiting...</span></div>',					  
                        '<div class="videoObjOpt">',
                          '<div class="videOptCon"> <input class="inputToInvite" type="text" value="" toInviteID=""> <a href="###" class="inviteInVideo">Invite</a>',
						    '<dl class="inviteList">',							
							'</dl> ',
						  '</div>',
                        '</div>',
                      '</dd>',
					  
                      '<dd class="tvideo seat seat3 free" seat="3" mUUID="">',
					    '<span class="videObjInfo"> </span>',
						'<span class="freeTip">Idle<br>+ Invite friend</span>',
					    '<div class="videoStatus"><span class="videoObjName"></span> <span class="videoTip">Waiting...</span></div>',					  
                        '<div class="videoObjOpt">',
                          '<div class="videOptCon"> <input class="inputToInvite" type="text" value="" toInviteID=""> <a href="###" class="inviteInVideo">Invite</a>',
						    '<dl class="inviteList">',							
							'</dl> ',
						  '</div>',
                        '</div>',
                      '</dd>',
					  
                    '</dl>',
                    '<div class="videoOpt">',
                      '<div class="videOpt_c"> <span class="videoTime">Time: <span class="videoCurrentTime"> 00:00:00 </span> </span> <a href="###" class="fullscreen">Full screen</a> <a href="###" class="vhangUp hangUp">Hangup</a> </div>',
                    '</div>',
                  '</div>',
             '</div>', 
          '</div>',
        '</dd>',
      '</dl>',
//	  '{resize}',
//	   '<div style="position:absolute;overflow:hidden;background:url(images/transparent.gif) repeat;display:block" resize="min_width"></div>',
//	   '<div style="position:absolute;overflow:hidden;background:url(images/transparent.gif) repeat;display:block" resize="min_height"></div>',
    '</div>'].join('')	
	
	
	
var commonTemplate =  [
    '<div id="window_{id}_warp" class="commonwin window-container window-current"  window="{id}" style="width:{width}px; height:{height}px;top:{top}px;left:{left}px;z-index:{zIndex}">',
      '<dl class="comwin_header header">',
        '<dd class="cm_l"></dd>',
        '<dd class="cm_c">',
          '<span class="cm_title">{name}</span>',
          '<div class="cm_btn"> <a href="###" class="cw_min"></a> <a href="###" class="cw_close"></a> </div>',
        '</dd>',
      '</dl>',
      '<dl class="comwinCon">',           
        '<dd class="comWin_box">',
        '</dd>',
      '</dl>',
    '</div>'].join('')
	


var txtMsgItemTemplate = [
      '<dl class="{author}">',
        '<dt>{name} {timestamp}</dt>',
        '<dd>{content}</dd>',
      '</dl>'].join('');

var mpvInviteMsgItemTemplate = [
      '<dl class="system_msg video_invitation">',
        '<dd>System: <span class="host_name">{host_name}</span>invite you to join a videoconference<a class="accept" host_id="{host_id}" room_no="{room_no}" seat_no="{seat_no}">Join</a></dd>',        
      '</dl>'].join('');

var mpvOngoingMsgItemTemplate = [
      '<dl class="system_msg video_ongoing">',
        '<dd>System: there is an ongoing conference<a class="accept" room_no="{room_no}" seat_no="{seat_no}">Enter</a>或<a class="endIt" room_no="{room_no}">End</a></dd>',        
      '</dl>'].join('');

var p2pInviteMsgItemTemplate = [
      '<dl class="system_msg {invite}_invitation">',
        '<dd>System: <span class="peer_name">{peer_name}</span> want {invitestr} chat with you. <a class="accept" from="{peer_id}" sdp="{sdp}">Accept</a></dd>',        
      '</dl>'].join('');

var groupItemTemplate =[
      '<dl class="friendgroup {groupID}">',
        '<dt class="groupIc groupICUp"><a class="groupname">{groupName}</a>[<span class="onlineNum">{onlineNum}</span>/<span class="allnum">{Num}</span>]</dt>',
        '<dd class="groupmembers"><dl class="grouplistcon"></dl></dd>',   
    '</dl>'].join(''); 

var discusItemTemplate = [
    '<dd sid="{session_id}" class="discuslist discus_item_{session_id}">',
        '<img src="{photo}"/>',
        '<a href="###" class="sendmsn">',
          '<div class="discusdname"><span class="discuTheme">{name}</span> <em>({num})</em></div>',
        '</a>',
    '</dd>'].join('');

var friendItemTemplate1 = [
    '<dd uuid="{uuid}" class="{status} frienditem friend_item_{uuid}">',
        '<img src="{photo}"/>',
        '<a href="###" class="sendmsn">',
          '<span class="friendname">{name}</span>',
          '<span class="signa" title={signature}>{signature}</span>',
        '</a>',
      //  '<a href="###" class="thisisme" uuid="{uuid}">这是我</a>',
    '</dd>'].join('');


var friendItemTemplate2 = [
    '<dd uuid="{uuid}" class="{status} frienditem friend_item_{uuid}">',
        '<img src="{photo}"/>',
        '<span class="friendname">{name}</span>',
    '</dd>'].join('');


var msgTipTemplate = [
    '<dl class="tipItem tip_of_session_{sid}" sid="{sid}">',
        '<span class="tipicon"><img src="images/photo/1.gif" width="20" height="20" /></span>',
        '<span class="tipTxt"><span class="msg_from">{from}</span>：<span class="msg_content">{content}</span></span>',  
        '<span class="tipcount">(<span class="tipNum">1</span>)</span>',
    '</dl>'].join('');

var friendCandidateTemplate = [
    '<dd class="online candidate frienditem friend_item_{uuid}" uuid="{uuid}">',
    '<img src="{photo}" />',
      '<a href="#" class="sendmsn"><span class="friendname">{name}</span><span class="signa" title="{signature}">{signature}</span></a>',
      '<a href="#" class="addBtn" title="Add to friend list"></a>',
      '<span class="existFriend" title="Already in friend list"></span>',
    '</dd>'].join('');


//窗口拖动模板
var resizeTemp = '<div resize="{resize_type}" style="position:absolute;overflow:hidden;background:url(images/transparent.gif) repeat;display:block;{css}" class="resize"></div>';