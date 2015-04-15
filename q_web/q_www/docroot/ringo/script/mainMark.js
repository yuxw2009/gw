
function sort_Aarray(a, b){
	return a.englishName > b.englishName ? 1 : -1
} 
function tabSwitch(){
	var _this = $(this),
	    linkHref = _this.attr('link'),
	    obj = $('#' + linkHref).length > 0 ? $('#' + linkHref) :$(this).parents().find('.' + linkHref).eq(0);	
		_this.addClass('active').siblings().removeClass('active');
		obj.fadeIn(400, function(){
		   if($('#' + linkHref).length > 0){
		    oScrollbar.tinyscrollbar_update();
		   }	
		}).siblings().hide();
}


var imageMenu1Data = [
        [{ text: 'Instant Message',
           css: 'smartMenu_im',
            func: function () {
			  $(this).click();
            }
        }],
        [{ text: 'Video Call',
           css: 'smartMenu_video',
            func: function () {
			   $(this).click();
			   sc.orderOperation('p2p', $(this).attr('uuid').toString(), 'video');		
            }
        }],
         [{ text: 'Audio Call',
            css: 'smartMenu_audio',                 
            func: function () {
			    $(this).click();
			    sc.orderOperation('p2p', $(this).attr('uuid').toString(), 'audio');	
            }
        }],               
        [{ text: 'Remove Friend',
           css: 'smartMenu_delete',               
           func: function () {
               mainmark.deleteFriend($(this).attr('uuid').toString());
           }
        }]
]

function mainMark(){
	this.groups = {};
	this.friends = {};
    this.groupObj = {};
	this.friendList = new Array();
	this.contacts = {};
}

mainMark.prototype = {
	build: function(data){	
		this.createGroupDom(data['labels']);
		this.AppendDomToContactList(data['friends']);
		this.createDiscuGroup(data['sessions']);
		this.setConTopDom(data['attributes']);
		this.updateContacts(this.friendList);
		this.bindHandlers();
        if (!oScrollbar){
			oScrollbar = $('#friendBox');
	        oScrollbar.tinyscrollbar();	
	    }
		this.mianMarkScrollUpdate();
		$('#contactBox').find('.con_nav a').bind('click', tabSwitch);
		$('#contactBox .myphoto').removeClass('offline')
		$('#friendList').find('dt').eq(0).click();
	},
	mianMarkScrollUpdate:function(){
		var oldTop = $('#contactBox').find('.overview').css('top'),
		thumbTop =  $('#contactBox').find('.thumb').css('top');
		oScrollbar.tinyscrollbar_update();
		if(parseInt($('#contactBox').find('.overview').height()) > parseInt($('#friendBox').height())){
			$('#contactBox').find('.overview').css('top', oldTop);	
			$('#contactBox').find('.thumb').css('top', thumbTop);
		}
	},
	setConTopDom: function(info){
		var topBox = $('#contactBox').find('.cb_header');
		$('.preview').find('img').attr('src', info['photo']);
		topBox.find('img').attr('src', info['photo']);
		topBox.find('.chatObj_name').text(info['nick_name']);
		if(info['signature'] != '')		
		topBox.find('.Signature').find('input').val(info['signature']);	
	},	
    sort_friendList: function(){
		var curObj = this;
	    for(var key in curObj.groupObj){
			 curObj.groupObj[key]['friendList'] =   curObj.groupObj[key]['friendList'].sort(sort_Aarray);			 
		}
	    curObj['friendList'] = curObj['friendList'].sort(sort_Aarray);
    },
	createGroupDom: function(labels){
		var curObj = this;
		var html = '';
		$('#friendList').html('');
		for(var i =0; i<labels.length; i++){
			 curObj.groupObj[labels[i]] = {'groupName': labels[i], 'groupID': 'groupID_'+ i, 'friendList' :[] , 'Num' :0 , 'onlineNum' : 0}
			 html += FormatModel(groupItemTemplate, curObj.groupObj[labels[i]]);
	    }		
	    $('#friendList').html(html);
	},
	createContactList: function(friends){
		 var curObj = this;
		 var dom = {}, temp = {}, groupName ;		 
	     this.friendList = new Array();
		 for (var i = 0; i < friends.length; i++){
			groupName = friends[i]['label'];
			if(!dom[groupName]) dom[groupName] =[];
		    temp = {label:groupName, uuid:friends[i]['uuid'], name:friends[i]['attributes']['nick_name'], englishName:ConvertPinyin(friends[i]['attributes']['nick_name']).toUpperCase(),  photo:friends[i]['attributes']['photo'], signature:friends[i]['attributes']['signature'], status:friends[i]['status']};	
			curObj.friendList.push(temp);
			curObj.groupObj[friends[i]['label']]['friendList'] = curObj.groupObj[friends[i]['label']]['friendList'] || [];	
			curObj.groupObj[friends[i]['label']]['friendList'].push(temp);		
		 }
		 curObj.sort_friendList();
	},
	AppendDomToContactList: function(friends){
		var curObj = this;		 
		var groupIdm, arr, appendDom, selectAppendDOM, groupDom, slelectDom;
		curObj.createContactList(friends);
		for(var key in curObj.groupObj){
		   groupId = curObj.groupObj[key]['groupID'];
		   arr = curObj.groupObj[key]['friendList'];
		   groupDom = $('#contactBox').find('.' + groupId).find('.grouplistcon');
		   for(var i= 0; i< arr.length; i++){
			    appendDom = FormatModel(friendItemTemplate1, arr[i]);
			    if(arr[i]['status'] == 'online'){
		            if(groupDom.parent().find('.online').length > 0 ){
					    $(appendDom).insertAfter(groupDom.parent().find('.online:last'));			  
				    }else{
					    $(appendDom).prependTo(groupDom);			  				   
				    }
			    }else{
			        $(appendDom).appendTo(groupDom);
			    }
		    }
		    $('#contactBox').find('.' + groupId).find('.allnum').html(arr.length);
		    $('#contactBox').find('.' + groupId).find('.onlineNum').html(groupDom.find('.online').length);
		}
	},
	createDiscuGroup:function(duscgroup){		
		var temp ={};
		var discusBox = $('#discuGroupList');
		discusBox.find('.discuGroupListCon').html('<div class="noDiscus"><img src="images/users.png"/> No discuss group</div>');
		//discusBox.find('dt').hide();
		for(var i=0; i< duscgroup.length;i++ ){
			if(duscgroup[i]['session_type'] == 'mp'){
              discusBox.find('.noDiscus').remove();
			   temp = {session_id:duscgroup[i]['session_id'], name: duscgroup[i]['name'] == '' ? 'Group' : duscgroup[i]['name'], photo: 'images/discu_group.jpg', members: duscgroup[i]['members'] , num: duscgroup[i]['members'].length };
			   $(FormatModel(discusItemTemplate, temp)).appendTo('#discuGroupList .discuGroupListCon').data('info', temp);
			  // discusBox.find('dt').show();
			}
		}			
	},
	updateContacts: function(contactInfo){
		for (var i = 0; i < contactInfo.length; i++){
			this.contacts[contactInfo[i].uuid.toString()] = contactInfo[i];
		}
	},
	getContactAttr: function(UUID){
        return this.contacts[UUID.toString()] ? this.contacts[UUID.toString()] : {uuid:UUID, name:"Unknown", photo:'images/photo/defalt_photo.gif', signature:'', status:'offline'};
    },
	bindHandlers: function(){
		var curObj = this;
		$('#contactBox .discuslist').unbind('click').bind('click', function(){
			var sid = $(this).data('info').session_id.toString();
			sc.activate(sid);
			return false;
		});		
		
		$('.groupIc').unbind('click').bind('click', function(){		 
	    $(this).parent().find('dl').eq(0).slideToggle(500, function(){		
			curObj.mianMarkScrollUpdate();
		  });
		$(this).toggleClass('groupICUp');
          // $(this).parent().siblings().find('dl').slideToggle();		   
			return false;
		});		
		$('#contactBox').find('.seaFriendInput').InputFocus();
	    $('#contactBox').find('.seaFriendInput').bind('keyup',function(){
	        var str = $(this).val();
            curObj.seaFriedList(str);
		});
		$('#contactBox .myphoto img').unbind('click').bind('click', function(){
			(new personalSet()).bindHandlers();
			return false;
		});
		$('#contactBox .eidtSignature').blur(function(){
			if ($(this).val() != mySignature() || $(this).val() !== ''){
				curObj.setSignature($(this).val());
			}else{
	           if('' == $(this).val())  $(this).val('Edit your signature');				
			}
		}).focus(function(){
			if($(this).val() == 'Edit your signature')
			$(this).val('');
		}).keyup(function(event){
			e = event ? event : (window.event ? window.event : null);
			if (e.keyCode === 13) {	
               $('#contactBox .eidtSignature').blur();
			   return false;
			}
		});
		$('#contactBox .createDiscugroup').unbind('click').bind('click', function(){
			(new addMember('friends_in_newDiscusgroup', 'New discuss group', function(flist){
				sc.contactWith(flist.concat([myID()]));
				return false;
			})).init([]);
		});
		$('#contactBox').find('.cb_close').click(function(){
			//var html = '<span class="confirmIcon">你点击了关闭按钮，你想：</span>' + 
			//           '<div class="loginoutItem"><input name="loginout" data="closeWin" type="radio" checked ="checked" /><label>退出当前聊天 （不清除cookie,下次自动登录）</label></div>' +
			//		   '<div class="loginoutItem"><input name="loginout" data="switchAccount" type="radio"/><label>注销当前账号 （清除cookie,下次不自动登录）</label></div>';
			var html = '<span class="confirmIcon">Do you really want to logout?</span>';			
			//$('.loginoutItem').live('click', function(){
			//	 $(this).find('input').attr('checked', true);
			//})

            Core.confirm(html, function(obj){
              	hp.sendData({type:'log_out'});
              	setTimeout(function(){
	              //	if((obj.find('input:radio:checked').attr('data')) ==  'closeWin'){
				  //	var opened=window.open('about:blank','_self');
				  //		opened.close();
				  //	}else{
						$.cookie('account','');
						$.cookie('password', '');
						window.location.reload();
				//	}
              	}, 300);
			    return false; 
			});
		});

		$('#contactBox').find('.search_friendList').click(function(){
           (new findFriend()).bindHandlers();
           return false;
		});

        curObj.bindFriendItemHandlers();
	},
	bindFriendItemHandlers: function(){
		$('#friendList').find('.frienditem').unbind('click').bind('click', function(){
			var toUser = $(this).attr('uuid').toString();
			sc.contactWith([toUser]);
			return false;
		});

		$("#friendList").find('.frienditem').each(function () {
            var obj = $(this);
            var imageMenu = imageMenu1Data;
            obj.smartMenu(imageMenu, {
                name: "application",
                obj: obj
            });
        });
	},
	seaFriedList:function(str){
		var curObj = this;	
		var arr = curObj.friendList;
		var reg = /[\u4E00-\u9FA5\uF900-\uFA2D]/, flag = reg.test(str);
		var online_html = '', offline_html = '';
		if(str === ''){ $('.seaResultBox').hide(); return false; }
		for(var i =0; i < arr.length; i++){
			 if(flag){				 
				if (arr[i].name.indexOf(str) >= 0){
				    arr[i]['status'] === 'online' ? online_html += FormatModel(friendItemTemplate2, arr[i]) : offline_html += FormatModel(friendItemTemplate2, arr[i]);
				}			 
			 }else{
				if (arr[i].englishName.indexOf(str.toUpperCase()) === 0){
					arr[i]['status'] === 'online' ?  online_html += FormatModel(friendItemTemplate2, arr[i]) : offline_html += FormatModel(friendItemTemplate2, arr[i]);
				}

			 }
		}

		if('' == online_html + offline_html){ $('.seaResultBox').show().html('<span style="padding:10px; color:#ccc; font-size:13px; text-align:center">No friend found</span>'); return false; }
		$('.seaResultBox').show().html(online_html + offline_html);			
		$('.seaResultBox').find('dd').click(function(){
			$('.friend_item_' + $(this).attr('uuid')).click();
			$('#contactBox').find('.seaFriendInput').val('').next().show();
			$(this).parent().hide();
		})
	},
	copyFriendListDom: function(){
		$('#slelectFriendbox .selectLeft').html($('#friendList').html());
		$('#slelectFriendbox .selectLeft').find('dd.frienditem').each(function(){
			var self = $(this);
			self.find('.signa').remove();
			self.append(self.find('.sendmsn').html());
			self.find('.sendmsn').remove();
		});
		$('#slelectFriendbox .groupIc').unbind('click').bind('click', function(){		 
	    $(this).parent().find('dl').eq(0).slideToggle();
		$(this).toggleClass('groupICUp');	   
			return false;
		});	
	},
    updateUserInfo: function(UUID, Attr, Val){
        if (UUID ==myID()){
        	switch (Attr){
        		case 'photo':
        		    $('#contactBox .myphoto img').attr('src', Val);
        		    selfphoto = Val;
        		    LWORK.msgbox.show("Photo has been changed successfully", 4, 1000);
        		    break;
        		case 'signature':
        		    $('#contactBox .eidtSignature').val(Val);
        		    selfSignature = Val;
        		    break;
        		default:
        		    break;
        	}
        }else{
        	this.updateFriendAttr(UUID, Attr, Val);
        	sc.updateMemberInfo(UUID, Attr, Val);
        }
    },
    quitChat: function(sid){
		setTimeout(function(){	
		    var disObj =$('#discuGroupList').find('.discuGroupListCon').eq(0);	
		 	disObj.find('.discus_item_'+sid).html('').remove();			
			if(disObj.find('dd').length ==0 ){
			 //  $('#discuGroupList').find('dt').hide();
			   disObj.html('<div class="noDiscus"><img src="images/users.png"/> No groups</div>');	
			}				
		}, 600);		
    },
    deleteFriend: function(friendUUID){
    	hp.sendData({type:"del_friend", uuid:friendUUID.toString()});
    },
    newDiscussIfNotExist: function(sid, stype, sname, members){
    	if ($('.discus_item_'+sid).length == 0){
    		$('#discuGroupList').find('.noDiscus').remove();
			var temp = {session_id:sid, name: sname == '' ? 'Group' : sname, photo: 'images/discu_group.jpg', members:members, num:members.length };
			$(FormatModel(discusItemTemplate, temp)).appendTo('#discuGroupList .discuGroupListCon').data('info', temp);
			$('#contactBox .discuslist').unbind('click').bind('click', function(){
				var sid = $(this).data('info').session_id.toString();
				sc.activate(sid);
				return false;
			});
    	}
    },
    updateMemberCount: function(sid, memberCount){	
    	$('#discuGroupList').find('.discus_item_' + sid).find('em').text('(' +memberCount+')');
    },
    updateFriendAttr: function(UUID, Attr, Val){
    	var UserItemDom = $('#friendList .friend_item_'+UUID);
		var Info = this.getContactAttr(UUID);
        Info.uuid = UUID;
		switch (Attr){
            case "presence":
                if (Val == 'offline'){
                	UserItemDom.removeClass('online').addClass('offline');					
					UserItemDom.appendTo(UserItemDom.parent());					
                }else{
                	UserItemDom.removeClass('offline').addClass('online');					
					UserItemDom.prependTo(UserItemDom.parent());
                }
				
				var groupDom = UserItemDom.parents('.friendgroup').eq(0);
		        groupDom.find('.onlineNum').html(groupDom.find('.online').length); 
                break;
            case "signature":
                UserItemDom.find('.signa').attr('title', Val).html(Val);
                Info.signature = Val;
                break;
            case "nick_name":
                UserItemDom.find('.friendname').html(Val);
                Info.name = Val;
                break;
            case "photo":
                UserItemDom.find('img').attr('src', Val);
                Info.photo = Val;
                break;
            default:
                break;
        }
        this.updateContacts([Info]);
    },
    setSignature: function(sig){
    	hp.sendData({type:'change_attr', attr_name:'signature', attr_new_value:sig, attr_old_value:''});
    },
    onNetworkBroken: function(){
    	$('#contactBox .myphoto').addClass('offline');
    	$('#contactBox').find('.online').removeClass('online').addClass('offline');
    },
	onSessionThemeChanged:function(sid, newName){
	    $('#contactBox').find('.discus_item_' + sid).find('.discuTheme').text(newName);
	},
	onQueryFriendResult: function(candidates){
		var curObj = this;
		var findFriendDom = $('#window_find_friend_warp');
		if (findFriendDom.length > 0){
			var cdList = findFriendDom.find('.searchResult');
			cdList.html('');
			findFriendDom.find('.noCandidateTips').hide();
			for (var i = 0; i < candidates.length; i++){
				if (candidates[i].uuid != myID()){
	                cdList.append(FormatModel(friendCandidateTemplate, candidates[i]));
	            }
			}
			for (var j = 0; j < curObj.friendList.length; j ++){
				cdList.find('.friend_item_'+curObj.friendList[j].uuid).addClass('alreadyAdded');
			}
			cdList.find('.addBtn').unbind('click').bind('click', function(){
				var toAddUUID = $(this).parent().attr('uuid');
				hp.sendData({type:'add_friend', uuid:toAddUUID});
				return false;
			});
		}
	},
	onFriendAddSucc: function(friendUUID, friendName){
		LWORK.msgbox.show("Add friend "+friendName+" successfully!", 4, 2000);
		$('#window_find_friend_warp .searchResult').find('.friend_item_'+friendUUID).addClass('alreadyAdded');
	},
	onFriendAdded: function(Label, UUID, Name, Photo, Signature, Status){
		var curObj = this;
		var temp = {label:Label, uuid:UUID, name:Name, englishName:ConvertPinyin(Name).toUpperCase(),  photo:Photo, signature:Signature, status:Status};	
		for (var i = 0 ; i < curObj.friendList.length; i++){
			if (curObj.friendList[i].uuid == UUID){
				return false;
			}
		}
		curObj.friendList.push(temp);
		curObj.groupObj[Label]['friendList'].push(temp);	
		var appendDom = FormatModel(friendItemTemplate1, temp);
		var groupId = curObj.groupObj[Label]['groupID'];
		var groupDom = $('#contactBox').find('.' + groupId).find('.grouplistcon');
		   
		if(temp['status'] == 'online'){
		    if(groupDom.parent().find('.online').length > 0 ){
				$(appendDom).insertAfter(groupDom.parent().find('.online:last'));			  
			}else{
				$(appendDom).prependTo(groupDom);				   
			}

		    $('#contactBox').find('.' + groupId).find('.onlineNum').html(groupDom.find('.online').length);
		}else{
			$(appendDom).appendTo(groupDom);
	    }

	    $('#contactBox').find('.' + groupId).find('.allnum').html(curObj.groupObj[Label]['friendList'].length);
	    
	    curObj.bindFriendItemHandlers();
	    curObj.updateContacts([{uuid:UUID, name:Name, photo:Photo, signature:Signature, status:Status}]);
	},
	onFriendDelSucc: function(friendUUID, friendName){
		LWORK.msgbox.show("Remove friend "+friendName+" successfully!", 4, 2000);
		$('#window_find_friend_warp .searchResult').find('.friend_item_'+friendUUID).removeClass('alreadyAdded');
	},
	onFriendDeleted: function(friendUUID){
		var curObj = this;
		for (var i = 0 ; i < curObj.friendList.length; i++){
			if (curObj.friendList[i].uuid == friendUUID){
				var Label = curObj.friendList[i].label;
				for (var j = 0; j < curObj.groupObj[Label]['friendList'].length; j++){
					if (curObj.groupObj[Label]['friendList'][j].uuid == friendUUID){
						curObj.groupObj[Label]['friendList'].splice(j, 1);
						break;
					}
				}
				var groupId = curObj.groupObj[Label]['groupID'];
		        var groupDom = $('#contactBox').find('.' + groupId).find('.grouplistcon');
                $('#contactBox .friend_item_'+friendUUID).remove();
                $('#contactBox').find('.' + groupId).find('.onlineNum').html(groupDom.find('.online').length);
				$('#contactBox').find('.' + groupId).find('.allnum').html(curObj.groupObj[Label]['friendList'].length);
				curObj.friendList.splice(i, 1);
				break;
			}
		}
	}
}

function personalSet(){
	Core.create({ 'id': 'personal_set',  'width': 560, 'height':430,  'name': "settings", 'resize':false, 'content': $('#personalSetbox').find('.personalSet').clone(true)});
    this.winDom = $('#window_personal_set_warp');
    this.winDom.find('.pwInputs input.oldpw').val('');
    this.winDom.find('.pwInputs input.newpw1').val('');
    this.winDom.find('.pwInputs input.newpwe').val('');
	this.winDom.find('.curPhoto img').attr('src', myPhoto());
	this.winDom.find('.setPhoto').click();
}
personalSet.prototype = {
	bindHandlers: function(){
		var curObj = this;
        var img =curObj.winDom.find('.preview_img img');					
		curObj.winDom.find('.settab').unbind('click').bind('click', tabSwitch);		
		curObj.winDom.find('.recommend_images img').click(function(){
		  var url = $(this).attr('src');
		  img.attr({'src': url, 'upload':'no'});
		})	
		
		curObj.winDom.find('.setPWPage .okBtn').unbind('click').bind('click', function(){
			var oldpwObj = curObj.winDom.find('.pwInputs input.oldpw'),
			 newpw1Obj = curObj.winDom.find('.pwInputs input.newpw1'),
			 newpw2Obj = curObj.winDom.find('.pwInputs input.newpw2'),
			 oldpw = oldpwObj.val(),
			 newpw1 = newpw1Obj.val(),
			 newpw2 = newpw2Obj.val();
			 			
			if ('' === oldpw) {
				pageTips(oldpwObj.parent(), 'Blank is not allowed');
	            oldpwObj.focus();
				return false;
	        } else {
	            if ('' === newpw1) {
					pageTips(newpw1Obj.parent(), 'Blank is not allowed');
	                newpw1Obj.focus();
					return false;
	            } else if (newpw1.length < 6) {
					pageTips(newpw1Obj.parent(), 'Length should be greater than 6');
	                newpw1Obj.focus();
	                return false;
	            } else {
	                if (newpw1 !== newpw2) {
						pageTips(newpw2Obj.parent(), 'These passwords do not match');
	                    newpw2Obj.focus();
	                    return false;
	                }
	            }
	        }
	        curObj.setPassword(oldpw, newpw1);
	        return false;
		});
		
		curObj.winDom.find('input').keyup(function(){
			removePageTips($(this).parent());
		});
		
		curObj.winDom.find('.setPhotoPage .okBtn').unbind('click').bind('click', function(){
			var newPhoto = curObj.winDom.find('.preview_img img').attr('src');
			curObj.setPhoto(newPhoto);
			$('#contactBox .myphoto img').attr('src', newPhoto);
			return false;
		});
	},
	setPassword: function(oldpw, newpw){
		var data = {type:'change_password', old_pass:md5(oldpw), new_pass:md5(newpw)};
		hp.sendData(data);
	},
	setPhoto: function(photo){
		var data = {type:'change_attr', attr_name:'photo', attr_new_value:photo};
		hp.sendData(data);
	}
}

function findFriend(){
	Core.create({ 'id': 'find_friend', width:600, height:500, 'name': "Find Friends", 'resize':false, 'content': $('#findFriendbox').find('.findFriend').clone(true)});
    this.winDom = $('#window_find_friend_warp');
    this.winDom.find('.seaAllFriendInput').InputFocus();		
}

findFriend.prototype = {
	bindHandlers: function(){
		var self = this;
		self.winDom.find('.seaAllFriendInput').keyup(function(){
			var curInputTxt = $(this).val();
			if (curInputTxt == ''){
                self.resetCandidates();
                $(this).attr("seed", "");
			}else {
				var seed = $(this).attr("seed");
				if (curInputTxt.length == 1 || curInputTxt.indexOf(seed) == -1){
	                self.getInitCandidates(curInputTxt);
	                $(this).attr("seed", curInputTxt);
				}else {
					self.furtherFind(curInputTxt);
				}
			}
		});
		return self;
	},
	getInitCandidates: function(firstLetter){
		hp.sendData({type:'query_friend', account_prefix:firstLetter});
	},
	furtherFind: function(prefixStr){
		var noMatched = true;
		this.winDom.find('.searchResult .candidate').each(function(){
			var candName = $(this).find('.friendname').html();
			if (candName.indexOf(prefixStr) != -1){
				$(this).show();
				noMatched = false;
			}else{
				$(this).hide();
			}
		});
		if (noMatched){
			this.winDom.find('.noCandidateTips').show();
		}else{
			this.winDom.find('.noCandidateTips').hide();
		}
	},
	resetCandidates: function(){
		this.winDom.find('.searchResult').html('');
		this.winDom.find('.noCandidateTips').show();
	}
}


