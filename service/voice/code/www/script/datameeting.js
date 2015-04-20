var DataMeetingController = {
    createNew: function () {
        var memberID2Li = {};
        var memberList = {};
        var activeMeetingID = null;
		var intervalID_ = null;
        var c = {};
        var update_member_item = function (li, status, member_id) {
            var statusDiv = li.children('.member_status');
            var buttonDiv = li.children('.member_button');
			var status_handler = {
				'pending' : 
                    function() {
                        statusDiv.hide();
                        buttonDiv.show().append($('<a href="###">删除</a>').click(function () {
                            li.hide('slow', function () {
                                var uuid = li.find('.meeting_member_name').attr('uuid');
                                delete memberList[uuid];
                                li.remove();
                                if ($('#meeting_current_list').find('.meeting_source').length <= 0) {
                                    $('#meeting_current_list').find('li').eq(0).addClass('meeting_source').find('.meetingHost').text('主持人');
                                }
                            });
                        })).append($('<a class="meetingHost" href="###">设为主持人</a>').click(function () {
                            li.siblings().removeClass('meeting_source').find('.meetingHost').text('设为主持人');
                            li.addClass('meeting_source').find('.meetingHost').text('主持人');
                        }));
                    },
				'connecting' : 
                    function() {
                        statusDiv.show().text('正在连接...');
                        buttonDiv.hide();
                        setOfflineTimeout(li, member_id);
                    },
				'online':       
                    function() {
                        statusDiv.show().text('在线');					
                        buttonDiv.show().html('<a href="###">挂断</a>').unbind('click').bind('click',function () {												
                           loadContent.createGeneralConfirm($(this), '您确认要挂断吗？', '挂断后系统将终止与其开会。', function(){
                                $('.float_corner3').css('right','50px');
                                api.datameeting.hangup(uuid, activeMeetingID, member_id, function () {
                                update_member_item(li, 'offline', member_id);
                                });
                            });
                        return false;					
                        });				
                    },
				'offline': function() {
                                statusDiv.show().text('离线');
                                buttonDiv.show().html('<a href="###">重拨</a>').unbind('click').bind('click',function () {
                                    api.datameeting.redial(uuid, activeMeetingID, member_id, function () {
                                        update_member_item(li, 'connecting', member_id);
                                    });
                                    return false;
                                });
                           },
                'idle': function() {
                            statusDiv.show().text('空闲');
                            buttonDiv.show().html('<a href="###">重拨</a>').unbind('click').bind('click',function () {
                                api.meeting.redial(uuid, activeMeetingID, member_id, function () {
                                    update_member_item(li, 'connecting', member_id);
                                });
                                return false;
                            });
                        }
            };
            if (status_handler[status]) (status_handler[status])();
            li.removeClass('pending connecting online offline');
            li.addClass(status);
        };

        var setOfflineTimeout = function (li, member_id) {
            setTimeout(function () {
                if (li.hasClass('connecting')) {
                    update_member_item(li, 'offline', member_id);
                }
            }, 45000);
        };
        var build_member_item = function (name, uuid, status, member_id, cb) {
            name = name || '会议成员';
            var nameElement = $('<span class="meeting_member_name" uuid="'+uuid+'">' + name + '</span>');
            var statusDiv = $('<span class="member_status">' + status + '</span>');
            var buttonDiv = $('<span class="member_button" />');
            var li = $('<li>').append(nameElement).append(statusDiv).append(buttonDiv);
            update_member_item(li, status, member_id);
            if (cb) cb(li);
        };

        var parsePendingList = function (pendingList, cbForEach) {
            var members = pendingList.val().split(' ');
            for (var i = 0; i < members.length; i++) {
                var name = '', uuid_ = '';
                if (members[i][0] == '@') {
                    name = members[i].substr(1);
                }
                else {
                    name = members[i];
                }
                var user = name2user[name];
                if (user) {
                    name = user['name'];
                    uuid_ = user['uuid'];
                }
                if (uuid_) {
                    cbForEach(name, uuid_);
                }
            }
        }
        
        var getCurrentMembers = function()
        {
            var current_members = new Array;
            c.current_list.children().each(function () {
                var name = $(this).find('.meeting_member_name').text();
                var uuid_ = $(this).find('.meeting_member_name').attr('uuid');
                if ($(this).hasClass('meeting_source')) {
                    current_members.splice(0, 0, { name: name, uuid: uuid_ });
                } else {
                    current_members.push({ name: name, uuid: uuid_ });
                }
            });					
            return current_members;
        }
        var stop_action_clicked = function(e) {
            e = e || window.event;
            e.preventDefault();
            e.stopPropagation();				
			if (intervalID_) {
				clearInterval(intervalID_);
				intervalID_ =false;
			}
            api.datameeting.stopmeeting(uuid, activeMeetingID, function (data) {
                activeMeetingID = null;
                c.reloadlist([]);
                c.startAction.show();
                datameetingController.load_history();	
            });
            return false;
        }
        var start_action_clicked = function () { 
            var current_members = getCurrentMembers();
            var subject = $('.datameetingTheme').val();
            if(current_members.length<2){
               LWORK.msgbox.show("会议成员不能少于两位！", 1, 2000);
            }else{
                api.datameeting.start(uuid,  $.cookie('company') + '_' + $('#username').text() + '_' + $.cookie('account'), subject, current_members, function (data) {						
					activeMeetingID = data['meeting_id'];
					c.reloadlist(data['details']);
                });
            }
            return false;
        }
        var pending_add_clicked = function (e) {
            if ('' !== c.pending_list.val() && c.pending_list.val() != '输入电话号码/拼音或汉字') {
                e = e || window.event;
                e.preventDefault();
                e.stopPropagation();
                parsePendingList(c.pending_list, function (name, uuid_) {
                    c.addto_current_list(name, uuid_);
                });
                c.pending_list.val('');
            }
        }
        c.init = function (meeting_container) {
            c.pending_list = meeting_container.find('.meeting_box .inputText');
            c.pending_add = meeting_container.find('.meeting_pending_add');
            c.pending_add.click(pending_add_clicked);
            c.current_list = meeting_container.find('.meeting_current_list');
            c.stopAction = meeting_container.find('#meeting_stop_action');
            c.stopAction.unbind('click').bind('click', stop_action_clicked);
            c.startAction = meeting_container.find('#meeting_start_action');
            c.startAction.unbind('click').bind('click', start_action_clicked);
            c.history_list = meeting_container.find('.meeting_history_list');
        };

        c.checkActive = function () {
            api.datameeting.get_info(uuid, function (data) {
                activeMeetingID =data['meeting_id'];
                c.reloadlist(data["details"]);
            });
        };

        c.load_history = function () {
            var d = new Date();
            var y = d.getFullYear();
            var m = d.getMonth() + 1;
            api.datameeting.history(uuid, y, m, function (data) {
                c.history_list.children().remove();
                var history = data['details'];
                for (var j = 0; j < history.length; j++) {
                    var members = history[j]['members'];
                    var subject = history[j]['subject'];
                    subject === '' || subject === "会议主题:新会议" ? subject = "新会议" : subject = subject;
                    var h = sprintf('<span class="gray">会议主题：</span> %s %s',  subject, '<span class="gray">' + history[j]['timestamp'] +'</span>');
                    var content = '';
                    for (var i = 0; i < members.length; i++) {
                        content += sprintf('@%s\n', members[i]['name']);
                    }
                    //var f = sprintf('会议时长：%s', members[0]['duration']+'s' );
					var f='';			
                    var ret = loadContent.format_message(h, content, f, { '重新发起': (function (members) {
                        return function () { c.reloadlist(members);   $("html, body").animate({ scrollTop: 0 }, 120);}
                    })(members)
                    });
                    c.history_list.append(ret);
                }
                $('#loading').hide();
            });
        };
        c.addto_current_list = function (name, addedUUId) {
            if (memberList[addedUUId]) return;
            memberList[addedUUId] = true;
            if (activeMeetingID) {
                api.datameeting.add_member(uuid, activeMeetingID, name, addedUUId, function (data) {
                    var member_id = data['new_member']['member_id'];
                    build_member_item(name, addedUUId, 'connecting', member_id, function (li) {
                        memberID2Li[member_id] = li;
                        c.current_list.append(li);
                    });
                });
            } else {
                build_member_item(name, addedUUId, 'pending', '', function (li) {
                    if (c.current_list.children().length <= 0) {
                        li.addClass('meeting_source').find('.meetingHost').text('主持人');
                    }
                    c.current_list.append(li);
                });
            }
            return true;
        };
        c.reloadlist = function (initialMembers) {
            memberID2Li = {};
            memberList = {};
            c.current_list.children().remove();
            for (var i = 0; i < initialMembers.length; i++) {
                var uuid_ = initialMembers[i]['uuid'];
                memberList[uuid_] = 1;
                var name = initialMembers[i]['name'];
                var status = initialMembers[i]['status'];
                if (!status) status = activeMeetingID ? 'connecting' : 'pending';
                var member_id = initialMembers[i]['member_id'] || '';
                memberList[uuid_] = true;
                build_member_item(name, uuid_, status, member_id, function (li) {
                    if (member_id) {
                        memberID2Li[member_id] = li;
                    } else if (i == 0) {
                        li.addClass('meeting_source').find('.meetingHost').text('主持人');
                    }
                    c.current_list.append(li);
                });
            }
            if (activeMeetingID) {
                c.startAction.hide();
				var interval = function(){
				  api.datameeting.get_status(uuid, activeMeetingID, function (data) {
                        changedMembers = data['members'];
                        if (!changedMembers || changedMembers.length == 0) {
                            if (intervalID_) clearInterval(intervalID_);
                            api.datameeting.stopmeeting(uuid, activeMeetingID, function (data) {
                                activeMeetingID = null;
                                c.reloadlist([]);
								c.startAction.show();
								datameetingController.load_history();									
                            });
                        }
                        for (var i = 0; i < changedMembers.length; i++) {
                            var mid = changedMembers[i]['member_id'];
                            var status = changedMembers[i]['status'];
                            update_member_item(memberID2Li[mid], status, mid);
                        }
                    });	
				}
                intervalID_ = setInterval(interval , 8000);
                c.stopAction.show();
            } else {
                c.stopAction.hide();
            }
        };
        return c;
    }
};
