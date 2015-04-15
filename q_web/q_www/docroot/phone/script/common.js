var uuid;
var subscriptArray = {};
var employer_status = new Array();
var name2user = {};
var groupsArray = {};
var myScroll = {};
var comt_index = "-1";
var currentpage = 'home';
//数组操作
var array = {
    sort_Aarray: function (a, b) {
        return a.convertname > b.convertname ? 1 : -1
    }
}

//常用函数
function bind(obj, type, fun) {
    obj.unbind(type).bind(type, fun);
}

function tips(txt){
	$('#tips').text(txt).fadeIn();
   setTimeout(function(){
	$('#tips').fadeOut();},2000)
}	

//获取数组下标
function employer_status_sub(employerId) {
    return subscriptArray[employerId.toString()];
}

//延迟加载图片
function loadImage(url, callback) {
    var img = new Image(); 
    img.src = url;
    if(img.complete) { 
        callback.call(img);
        return; 
    }
    img.onload = function () {
        callback.call(img);
    };
};

function extract_uuid(msg_content) {
    var reg = /(@[^\s]+)\s*/g;
    var m = "", temp = "", employerId;
    var to = {};
    var members = new Array();
    while (m = reg.exec(msg_content)) {
        temp = (m[0].substr(1)).replace(/(^\s*)|(\s*$)/g, "");
        if (typeof (name2user[temp]) === 'object') {
            employerId = (name2user[temp].uuid).toString();
            to[employerId] = employerId;
        } else {
            if (temp == 'all') { to['all'] = (groupsArray['all']['employer_uuid']).toString(); }
        }
    }
    for (var key in to) {
        members.push(to[key]);
    }
    return members;
}

function parsePhoneNameStr(str){
    return str.split(';').map(function (elem) {
                var nameS = elem.indexOf('['), nameE = elem.indexOf(']');
                var nameStr = (nameS < 0 || nameE < 0 || nameS >= nameE) ? "" : elem.substring(nameS + 1, nameE);
                var phoneStr = nameS < 0 ? elem : elem.substring(0, nameS);
                return { "phone": phoneStr, "name": nameStr };
            });
}

function filterInvalidPhoneNums(phoneNameL) {
    var i = 0;
    var invalids = new Array();
    while (i < phoneNameL.length) {
        if (!isPhoneNum(phoneNameL[i]["phone"])) {
            invalids.push(phoneNameL[i]);
            phoneNameL.splice(i, 1);
        }
        i++
    }
    return { 'ok': phoneNameL, 'invalidNums': invalids };
}

function filterRepeatedPhoneNums(phoneNameL) {
    var i = 0;
    while (i < phoneNameL.length) {
        for (var j = 0; j < i; j++) {
            if (phoneNameL[j]["phone"] === phoneNameL[i]["phone"]) {
                phoneNameL.splice(i);
                break;
            }
        }
        i++;
    }
    return phoneNameL;
}

//界面切换
function animute(type) {
    var id;
    id = $('.current_box').attr('id');
    if (type === 'add') {
        $('#' + id).hide().next().addClass('current_box').fadeIn();
    } else {
        // id == 'login' ?  navigator.app.exitApp() : $('#' + id).hide().prev().fadeIn();	
    }
}

function login() {
    this.obj = $('#login');
}
login.prototype = {
    createNew: function () {
        var login_proto = this;
        var obj = this.obj;
        bind(obj.find('a'), 'click', function () {
            var _this = $(this);
            var account = obj.find('.username_input').val();
            account = account.replace(/(^\s*)|(\s*$)/g, "");
            var password = obj.find('.password_input').val();
            var company = obj.find('.company_input').val();
            if ('' === account) {
                obj.find('.username_input').focus();
                return false;
            };
            if ('' === password) {
                obj.find('.password_input').focus();
                return false;
            }
            if ('' === company) {
                obj.find('.company_input').focus();
                return false;
            }
            _this.find('.login_text').text('正在登录...');
            password = md5(password);
            login_proto.loginIn(company, account, password);
            return false;
        })
    },
    loginIn: function (company, account, password) {
        var loginObj = this;
        var obj = this.obj;
        api.content.login(company, account, password, function (data) {
            uuid = (data['uuid']).toString();
            obj.find('.login_text').text('登录');
            localStorage.setItem('company', company);
            localStorage.setItem('account', account);
            localStorage.setItem('password', password);
            myScroll['home_box'] = new iScroll('home_box', {});
            loginObj.profile();
        }, function () {
            tips('用户名或者密码错误');
            obj.find('.username_input').focus();
            obj.find('.login_text').text('登录');
        });
    },
    profile: function () {
        var loginObj = this;
        api.content.profile(uuid, function (data) {
		    $('#home').find('.myname').text(data['profile']['name']);
            loginObj.profile_handle.getAllgroupsId(data['groups'], loginObj);
            loginObj.profile_handle.loadAllMembers(groupsArray['all']['groupId'], loginObj);
        });
    },
    profile_handle: {
        getAllgroupsId: function (groups, loginObj) {
            for (var i = 0; i < groups.length; i++) {
                var group = groups[i], group_members = {};
                if (group['name'] === 'all') {
                    groupsArray['all'] = { 'name': 'all', 'groupId': group['group_id'] };
                } else if (group['name'] === 'recent') {
                    groupsArray['recontact'] = { 'name': 'recontact', 'groupId': group['group_id'], 'members': group['members'] };
                }
            }
        },
        loadAllMembers: function (group_id, loginObj) {
            api.content.get_members(uuid, group_id, function (data) {
                if (data.status === 'ok') {
                    var len = data['members'].length;
                    var convertname, value, temp = {}, getmembers = new Array;
                    for (var i = 0; i < len; i++) {
                        value = data['members'][i];
                        convertname = ConvertPinyin(value.name);
                        temp = { 'uuid': value['member_id'], 'name': value['name'], 'employid': value['empolyee_id'], 'phone': value['phone'], 'department': value['department'], 'mail': value['mail'], 'photo': value['photo'], 'convertname': convertname.toUpperCase(), 'name_employid': value['name'] + value['empolyee_id'], 'status': value['status'], 'department_id': value['department_id'] };
                        employer_status.push(temp);
                        name2user[value['name'] + value['empolyee_id']] = { 'uuid': value.member_id };
                    }
                    employer_status = employer_status.sort(array.sort_Aarray);
                    for (var i = 0; i < employer_status.length; i++)
                        subscriptArray[employer_status[i].uuid] = i;												
					$('#login').hide().next().addClass('current_box').show();												
                }
            });
        }
    },
}

function sms_history_page() {
    this.pageDom = $('#sms_history');
}
sms_history_page.prototype = {
    pageEnter: function () {
        var pageObj = this;
        api.sms.history(uuid, function(data){
            var history = data["history"];
            if (history.length > 0){
                $('#sms_history_box').find('.opt_msg').eq(0).html('');
                for (i = 0; i < history.length; i++){
                    $('#sms_history_box').find('.opt_msg').eq(0).append(pageObj.createSmsHistoryItem(history[i]));
                }
                myScroll['sms_history'].refresh();
                bind($('#sms_history_box').find('.pageForward'), 'click', pageMngr.pageForward);
            }
        });
    },
    createSmsHistoryItem: function(item){   
        var receiversDisplay = item.members.map(function(receiver){return '<div ><span class="linkuser">' + receiver.name +'</span>'+ receiver.phone + '</div>';}).join("");
        var receiversDataRecord = item.members.map(function(receiver){return receiver.phone + (receiver.name.length > 0 ? '[' + receiver.name + ']' : '');}).join(";")
        var html = ['<dl class="history_item" style="display:block">',
                    '<dd><span class="itemDetail">短信内容 :</span><span class="history_val sms_content">' + item.content  + '</span></dd>', 
                    '<dd><span class="itemDetail">发送对象 :</span><span class="history_val sms_to">' + receiversDisplay + '</span></dd>', 
                    '<dd><span class="itemDetail">发送时间 :</span><span class="history_val">' + item.timestamp + '</span></dd>',    
                    '<dd class="pagefoot" style="clear:both">',
                    '<a href="###" class="reSendSMS pageForward" from="sms_history" link="sms_new" pagepara="content=:=' + item.content + '|^|phone_name=:='+ receiversDataRecord + '">重新发送</a>',
                    '</dd></dl>'].join("");
        return html; 
    },
    bindHandlers: function () {
    }
}

function sms_new_page() {
    this.pageDom = $('#sms_new');
}
sms_new_page.prototype = {
    pageParaSet: function (paras) {
        if (paras.phone_name) {
            this.pageDom.find('textarea.new_sms_receivers').focus().val(paras.phone_name);
        }
        if (paras.content) {
            this.pageDom.find('textarea.new_sms_content').focus().val(paras.content);
        }
    },
    pageEnter: function () {
    },
    bindHandlers: function () {
        var pageObj = this;
        this.pageDom.find('.sendsms').unbind('click').bind('click', function () {
            var receiversStr = $('#sms_new').find('textarea.new_sms_receivers').focus().val(),
                msgContent = $('#sms_new').find('textarea.new_sms_content').focus().val();

            var receiverList = parsePhoneNameStr(receiversStr);
            var filtered = filterInvalidPhoneNums(receiverList);
            receiverList = filtered['ok'].map(function (elem) { return { "phone": correctPhoneNumber(elem["phone"]), "name": elem["name"] }; });
            receiverList = filterRepeatedPhoneNums(receiverList);
            if (filtered['invalidNums'].length > 0) {
                tips('下面的接收者手机号不对，请核对改正后再发送！' + filtered['invalidNums'].map(function(item){return item.phone + item.name;}).join("、"));
            } else {
                pageObj.doSendShortMsg(receiverList, msgContent);
            }
            return false;
        });
    },
    doSendShortMsg: function (receivers, msg) {
        var me = employer_status[employer_status_sub(uuid)];
        var sig = '来自:' + me.name_employid + '-' + localStorage.getItem('company');
        api.sms.send(uuid, receivers, msg, sig, function (data) {
            if (data['fails'].length > 0) {
                alert("向" + data['fails'].join("、") + "的发送失败了，请确认这些接收号码的正确性！");
            } else {
                alert("短信已发送成功！", 4, 1000);
            }
            $('#sms_new').find('textarea.new_sms_receivers').val('').blur();
            $('#sms_new').find('textarea.new_sms_content').val('').blur();
            pageMngr.pageJump('sms_new', 'sms_history', false);
        });
    }
}

function callback_page() {
    this.isCallbackOngoing = false;
}
callback_page.prototype = {
    pageEnter: function () {
    },
    pageParaSet: function (paras) {
        if (paras.phone_name){
            $('#callback #callback_peer_num').focus().val(paras.phone_name);
        }
    },
    bindHandlers: function () {
        var pageObj = this;
        bind($('#callback .start_callback'), 'click', function(){
            if (pageObj.isCallbackOngoing){
                pageObj.stopCallback();
            }else{
                pageObj.startCallback();
            }
            return false;
        })
    },
    startCallback: function(){
        var myNum = employer_status[employer_status_sub(uuid)].phone;
        var phoneNames = parsePhoneNameStr($('#callback_peer_num').focus().val());
        var peerNum = null;
        if (phoneNames.length < 1 || !isPhoneNum(phoneNames[0].phone)){
            tips("所填对端号码不正确，请改正后再拨打！");
            $('#callback_peer_num').focus();
            return false;
        }else{
            peerNum = phoneNames[0].phone;
        }
        if (myNum.length == 0){
            tips("您没有设置电话号码，请先设置后再拨打！");
            return false;
        }else if (!isPhoneNum(myNum)){
            tips("您设置的电话号码不正确，请重新设置后再拨打！");
            return false;
        }else {
            api.callback.start(uuid, myNum, peerNum, function(data){
                if (data.status === 'ok'){
                    //console.log('make a callback between[' + myNum + ']and[' + peerNum + ']');
                }else{
                    tips("回拨业务执行失败，请与管理员联系！");
                }
            });
        }
    },
    stopCallback: function(){}
}

function meeting_history_page(){
}
meeting_history_page.prototype = {
    pageEnter: function () {
        var pageObj = this;
        var d = new Date();
        var y = d.getFullYear();
        var m = d.getMonth() + 1;
        api.meeting.history(uuid, y, m, function(data){
            var history = data["details"];
            if (history.length > 0){
                $('#meeting_history_box').find('.opt_msg').eq(0).html('');
                for (i = 0; i < history.length; i++){
                    $('#meeting_history_box').find('.opt_msg').eq(0).append(pageObj.createMeetingHistoryItem(history[i]));
                }
                myScroll['meeting_history'].refresh();
                bind($('#meeting_history_box').find('.reMeeting'), 'click', pageMngr.pageForward);
            }
            else{
                $('#meeting_history_box').find('.opt_msg').eq(0).html('没有记录！');
            }
        });
    },
    createMeetingHistoryItem: function(item){     
        var membersDisplay = item.members.map(function(member){return '<span class="linkuser">' + member.name + '</span>' +  member.phone;}).join("、");
        var membersDataRecord = item.members.map(function(member){return member.phone + (member.name.length > 0 ? '[' + member.name + ']' : '');}).join(";")
        var html = ['<dl class="history_item" style="display:block">',
                    '<dd><span class="itemDetail">会议成员：</span><span class="history_val">' + membersDisplay + '</span></dd>', 
                    '<dd><span class="itemDetail">开始时间：</span><span class="history_val">' + item.timestamp + '</span></dd>',    
                    '<dd class="pagefoot" style="clear:both">',
                    '<a href="###" class="reMeeting pageForward" from="meeting_history" link="meeting_new" pagepara="subject=:=' + item.subject + '|^|phone_name=:='+ membersDataRecord + '">重新发起</a>',
                    '</dd></dl>'].join("");
        return html; 
    },
    bindHandlers: function () {
    }
}

function meeting_new_page(){
    this.pageDom = $('#meeting_new');
    this.isMeetingOngoing = false;
    this.curMeetingID = null;
    this.intervalID = null;
    this.memberid2Item = {};
}
meeting_new_page.prototype = {
    pageEnter: function(){
    },
    pageParaSet: function(paras){
        if (paras.subject){
            $('#meeting_sheme_input').focus().val(paras.subject);
        }
        if (paras.phone_name){
            this.addNewMembers(parsePhoneNameStr(paras.phone_name));
        }
    },
    bindHandlers: function(){
        var pageObj = this;
        bind($('#meeting_new').find('.new_members'), 'click', function(){
            var thisObj = this;
            if ($('#meeting_member_input').focus().val().length > 0){
                pageObj.addMembersByInput();
            }else{
                pageMngr.pageForwardCall('meeting_new', 'Address_Book', {'select':'multi', 'require':'phone_name'});
            }
        });
        bind($('#meeting_new').find('.ctrl_meeting'), 'click', this.ctrlMeeting(pageObj));
    },
    isPhoneInMemberList: function(phoneNum){
        return $('#meeting_member_list').find('.' + phoneNum).length > 0;
    },
    addMembersByInput: function(){
        var inputTxt = $('#meeting_member_input').focus().val();
        var membersList = parsePhoneNameStr(inputTxt);
        var filtered = filterInvalidPhoneNums(membersList);
        membersList = filtered['ok'].map(function (elem) { return { "phone": correctPhoneNumber(elem["phone"]), "name": elem["name"] }; });
        membersList = filterRepeatedPhoneNums(membersList);
        if (filtered['invalidNums'].length > 0) {
            tips(filtered['invalidNums'].map(function(item){return item.phone + item.name;}).join("、") + '等会议成员的手机号不对，请核对改正后再添加！');
        } else {
            this.addNewMembers(membersList);
            $('#meeting_member_input').focus().val('').blur();
        }
    },
    addNewMembers: function(memberList){
        if (this.curMeetingID){
            this.addMembers2OngoingMeeting(memberList);
        }else{
            this.addMembersBeforeMeeting(memberList);
        }
    },
    addMembersBeforeMeeting: function(memberList){
        var existingPhones = [];
        for (var i = 0; i < memberList.length; i++){
            if (this.isPhoneInMemberList(memberList[i].phone)){
                existingPhones.push(memberList[i]);
            }else{
                $('#meeting_member_list').append(this.createMemberDom(memberList[i]));
            }
        }
        this.bindMemberHandlers();
        if ($('#meeting_member_list').find('.current_host').length === 0){
            $('#meeting_member_list').find('.sethost').eq(0).click();
        }
        if (existingPhones.length > 0){
            var itemL = existingPhones.slice(0, 3).map(function(item){return item.phone + (item.name.length > 0 ? '[' + item.name + ']' : '');}).join('、');
            tips(itemL + '等号码已经存在！');
        }        
    },
    addMembers2OngoingMeeting: function(newComers){
        var pageObj = this;
        console.log('addMembers2OngoingMeeting');
        console.log(newComers);
        if (newComers.length > 0){
            if (pageObj.curMeetingID){
                var comer1 = newComers[0];
                var restComers = newComers.slice(1);
                api.meeting.add_member(uuid, pageObj.curMeetingID, comer1.name, comer1.phone, function (data) {
                    var member_id = data['new_member']['member_id'];
                    $('#meeting_member_list').append(pageObj.createMemberDom(comer1));
                    pageObj.bindMemberHandlers();
                    pageObj.memberid2Item[member_id] = $('#meeting_member_list').find('.' + comer1.phone).eq(0);
                    pageObj.memberid2Item[member_id].attr('member_id', member_id);
                    pageObj.updateMemberItem(member_id, 'connecting');
                    pageObj.addMembers2OngoingMeeting(restComers);
                });
            }else{
                tips('会议已经结束了，这些成员没有加入该会议：' + newComers.map(function(ele){return ele.phone + ele.name}).join('、'));
            }
        }
    },
    createMemberDom: function(member){
        var dl="";
        var displayName = (member.name === '') ? '会议成员' : member.name,
            phone = correctPhoneNumber(member.phone);
        if(mobile_test(phone)){
            dl = ['<dl class="meeting_member_item '+ phone +'" phone="'+ phone +'" name="' + displayName + '">',
                    '<dd class="meeting_member clearboth">',
                      '<a class="sethost" href="###"></a>',
                      '<span class="meeting_member_name">'+ displayName +'</span><span class="meeting_member_tel">'+ phone +'</span><span class="member_status">未连接</span>',
                      '<a href="##" class="member_btns_ex">',
                    '</dd>',
                    '<dd class="member_btns pagefoot" style="display:none">',
                      '<a class="del_member meeting_member_btn flright" href="###">删除</a>',
                      '<a class="reconnect meeting_member_btn flright" href="###" style="display:none">重拨</a>',
                      '<a class="hungup meeting_member_btn flright" href="###" style="display:none">挂断</a>',
                    '</dd>',
                  '</dl>'           
                ].join(""); 
        }
        return dl;
    },
    bindMemberHandlers: function(){
        var pageObj = this;
        bind($('#meeting_member_list').find('.sethost'), 'click', this.setHost);
        bind($('#meeting_member_list').find('.member_btns_ex'), 'click', this.expandBtns);
        bind($('#meeting_member_list').find('.del_member'), 'click', this.delMember);
        bind($('#meeting_member_list').find('.reconnect'), 'click', this.reconnectMember(pageObj));
        bind($('#meeting_member_list').find('.hungup'), 'click', this.hungupMember(pageObj));
    },
    setHost: function(){
        $('#meeting_member_list').find('.current_host').removeClass('current_host');
        $(this).parent().parent().addClass('current_host');
        return false;
    },
    expandBtns: function(){
        if ($(this).parent().parent().hasClass('btns_expanded')){
            $(this).parent().next().slideUp('fast');
            $(this).parent().parent().removeClass('btns_expanded');
        }else{
            $('#meeting_member_list').find('.btns_expanded').each(function(){
                $(this).find('.member_btns').slideUp('fast');
                $(this).removeClass('btns_expanded');
            });
            $(this).parent().next().slideDown('fast');
            $(this).parent().parent().addClass('btns_expanded')
        }
        return false; 
    },
    delMember: function(){
        $(this).parent().parent().remove();
        if ($('#meeting_member_list').find('.current_host').length === 0){
            $('#meeting_member_list').find('.sethost').eq(0).click();
        }
        return false;
    },
    reconnectMember: function(pgObj){
        var pageObj = pgObj;
        return function(){
            var member_id = $(this).parent().parent().attr('member_id');
            api.meeting.redial(uuid, pageObj.curMeetingID, member_id, function () {
                    pageObj.updateMemberItem(member_id, 'connecting');
                });
            return false;
        }
    },
    hungupMember: function(pgObj){
        var pageObj = pgObj;
        return function(){
            var member_id = $(this).parent().parent().attr('member_id');
            api.meeting.hangup(uuid, pageObj.curMeetingID, member_id, function () {
                    pageObj.updateMemberItem(member_id, 'offline');
                });
            return false;
        }
    },
    extractMeetingMembers: function(){
        var members = new Array();
        $('#meeting_member_list').find('.meeting_member_item').each(function(){
            var cur_member = {'phone':$(this).attr('phone'), 'name':$(this).attr('name')};
            if ($(this).hasClass('current_host')){
                members.splice(0, 0, cur_member);
            }else{
                members.push(cur_member);
            }
        });
        return members;
    },
    ctrlMeeting: function(pageObj){
        return function(){
            var clickObj = $(this);
            console.log('pageObj.curMeetingID===' + pageObj.curMeetingID);
            if (pageObj.curMeetingID){
                pageObj.stopMeeting(clickObj);
            }else{
                pageObj.startMeeting(clickObj);
            }
            return false;
        };
    },
    startMeeting: function(clickObj){
        var pageObj = this;
        var meetingMembers = pageObj.extractMeetingMembers();
        console.log('to start a new meeting...')
        console.log(meetingMembers);
        if (meetingMembers.length < 2){
            tips('会议成员不能少于2位');
        }else{
            var subject = employer_status[employer_status_sub(uuid)].name_employid + '-' + (new Date()).toLocaleDateString();
            api.meeting.start(uuid, 'phoneMeeting', subject, meetingMembers, function (data) {
                    if (data.status === 'ok'){
                        console.log('meeting detail::');
                        console.log(data['details']);
                        pageObj.meetingStarted(data['meeting_id'], data['details']);
                    }
                });
        }
    },
    stopMeeting: function(clickObj){
        var pageObj = this;
        console.log('to stop meeting::' + this.curMeetingID);
        api.meeting.stopmeeting(uuid, this.curMeetingID, function (data) {
                pageObj.meetingStopped();
                tips('会议已结束');
            });
    },
    meetingStarted: function(meetingID, meetingDetail){
        $('#meeting_new').find('.ctrl_meeting').eq(0).text("停止");
        $('#meeting_new').find('.meeting_new_title').eq(0).text("开会中...");
        this.curMeetingID = meetingID;
        for (var i = 0; i < meetingDetail.length; i++){
            var item = $('#meeting_member_list').find('.' + meetingDetail[i].phone).eq(0);
            this.memberid2Item[meetingDetail[i].member_id] = $('#meeting_member_list').find('.' + meetingDetail[i].phone).eq(0);
            $('#meeting_member_list').find('.' + meetingDetail[i].phone).eq(0).attr('member_id', meetingDetail[i].member_id);
            this.updateMemberItem(meetingDetail[i].member_id, meetingDetail[i].status);
        }
        this.intervalID = setInterval(this.intervalCheck(this), 3000);
    },
    meetingStopped: function(){
        $('#meeting_new').find('.ctrl_meeting').eq(0).text("开始");
        $('#meeting_new').find('.meeting_new_title').eq(0).text("新会议");
        this.curMeetingID = null;
        $('#meeting_member_list').html('');
        this.memberid2Item = {};
        clearInterval(this.intervalID);
    },
    intervalCheck: function(pgObj){
        var pageObj = pgObj;
        return function (){
            api.meeting.get_status(uuid, pageObj.curMeetingID, function (data) {
                    if (data['meeting_status']){
                        pageObj.updateMeetingStatus(data['meeting_status']);
                    }
                    pageObj.updateMembersStatus(data['members']);
                });
        }
    },
    updateMeetingStatus: function(meetingStatus){
        if(meetingStatus === 'finished'){
            console.log('meeting automatically stopped...');
            $('#meeting_new').find('.ctrl_meeting').eq(0).click();
        }
    },
    updateMembersStatus: function(membersStatus){
        var pageObj = this;
        console.log(membersStatus);
        if (!membersStatus || membersStatus.length == 0) {
            api.meeting.stopmeeting(uuid, this.curMeetingID, function (data) {
                pageObj.meetingStopped();
            });
        }
        for (var i = 0; i < membersStatus.length; i++) {
            pageObj.updateMemberItem(membersStatus[i]['member_id'], membersStatus[i]['status']);
        }
    },
    updateMemberItem: function(memberID, status){
        var memberItem = this.memberid2Item[memberID];
        var statusBar = memberItem.find('.member_status'),
            delBtn = memberItem.find('.del_member'),
            reconnectBtn = memberItem.find('.reconnect'),
            hungupBtn = memberItem.find('.hungup');
        switch (status) {
            case 'connecting':
                statusBar.text('连接中..');
                delBtn.css('display', 'none');
                reconnectBtn.css('display', 'none');
                hungupBtn.css('display', 'none');
                break;
            case 'online':
                statusBar.text('在线');
                delBtn.css('display', 'none');
                reconnectBtn.css('display', 'none');
                hungupBtn.css('display', 'inline');            
                break;
            case 'offline':
                statusBar.text('离线');
                delBtn.css('display', 'none');
                reconnectBtn.css('display', 'inline');
                hungupBtn.css('display', 'none');
                break;
            default:
                break;
        }
    }
}

function pageManager() {
    this.pageObjs = {
        'sms_history': new sms_history_page(),
        'sms_new': new sms_new_page(),
        'topics': new loadContent('topics'),
		'tasks': new loadContent('tasks'),
        'new_msg': new new_msg_page(),
        'Address_Book': new addresBook_page(),
		'msgdetail': new msgdetail(),
        'callback': new callback_page(),
        'meeting_history': new meeting_history_page(),
        'meeting_new': new meeting_new_page(),
		'focus': new loadContent('focus')
    };
}
pageManager.prototype = {
    getPageObj: function (pageName) {
        return this.pageObjs[pageName];
    },

    bindJumpers: function () {
        bind($('.pageBackward'), 'click', this.pageBackward);
        bind($('.pageForward'), 'click', this.pageForward);
    },
    bindHandlers: function(){
        for (pageName in this.pageObjs){
            this.pageObjs[pageName].bindHandlers();
        }
    },
    pageJump: function (fromPage, toPage, jumpBack) {
        var obj = $('#' + toPage);
        var obj_box = $('#' + toPage + '_box');
        if (jumpBack) {
            obj.find('.pageBackward').attr('link', fromPage);
        }
		currentpage =  toPage;
        obj.siblings().hide();
        obj.show();
        if (obj_box.length > 0 ) {
            if ('yes' === obj_box.attr('bindscroll')) {
                myScroll[toPage].refresh();
            }else{
                myScroll[toPage] = new iScroll(toPage + '_box', {});
                obj_box.attr('bindscroll', 'yes');
    		}
        }
    },
    pageBackward: function () {
        pageMngr.pageJump('any', $(this).attr('link'), false);
		return false;
    },
    pageForward: function () {
        var domPara = null;
        if ($(this).attr('pagepara')){
            domPara = pageMngr.pageParaParse($(this).attr('pagepara'));
        }
        pageMngr.pageForwardCall($(this).attr('from'), $(this).attr('link'), domPara);
		return false;
    },
    pageForwardCall: function(fromPage, toPage, paras){
        this.pageJump(fromPage, toPage, true);
        if (paras){
            this.pageObjs[toPage].pageParaSet(paras);
        }
        this.pageEnter(toPage);
    },
    pageParaSet: function (pageName, paras) {
        this.pageObjs[pageName].pageParaSet(paras);
    },
    pageEnter: function (pageName) {
        pageMngr.pageObjs[pageName].pageEnter();
    },
    pageParaParse: function (parasStr) {
        var rslt = {};
        var paras = parasStr.split('|^|').map(function(item){
          var vS = item.indexOf('=:=');
          return {'key':item.substring(0, vS), 'val':item.substring(vS+3)};
        });
        for (var i = 0; i < paras.length; i++) {
            rslt[paras[i].key] = paras[i].val;
        }
        return rslt;
    }
}
//加载员工信息
function addresBook_page() {
   this.select = 'multi';
   this.require = 'name_eid';
   this.pageDom = $('#Address_Book');
}
addresBook_page.prototype = {
    pageEnter: function(){
        this.showemployer(groupsArray['recontact']['members'], $('#employer_list'), 1);
    },
    bindHandlers: function() {},
    pageParaSet: function(paras){
        if (paras.select){
          this.select = paras.select;
        }
        if (paras.require){
          this.require = paras.require;
        }
	   if(paras['title']){		
			this.pageDom.find('.newmsg_title').text(paras['title']);	
	    }
    },
    showemployer: function (arr, container, flag) {
        var html = '', html2 = '';
        var temp_id, subtag;
        var newarr = new Array();
        var pageObj = this;
        var createlistDom = function (status, photo, name, phone, employid, uuid) {
            return ['<li class="' + status + ' employer_item ' + uuid + '" uuid="' + uuid + '">',
		       '<img src="' + photo + '" width="38" height="38">',
		       '<a href="###" name="" phone="" class="sendmsn" uuid="' + employid + '">',
		       '<div class="employ_name">' + name + '<span class="employ_id" >' + employid + ' </span></div><span class="employ_phone">' + phone + '</span>',
		       '</a><span class="check_box"></span></li>'].join('');
        }
        for (var j = 0; j < arr.length; j++) {
            subtag = subscriptArray[arr[j]];
            newarr.push(employer_status[subtag]);
        }
		
        newarr = newarr.sort(array.sort_Aarray);
        for (var i = 0; i < newarr.length; i++) {
            var obj = newarr[i];
            if (obj) {
                obj['status'] === 'online' ? html += createlistDom('online', obj['photo'], obj['name'], obj['phone'], obj['employid'], obj['uuid']) : html2 += createlistDom('offline', obj['photo'], obj['name'], obj['phone'], obj['employid'], obj['uuid']);
            }
        }
        html += html2;
        container.html(html);		
		if(flag) myScroll['Address_Book'].refresh();
        bind($('.employer_item'), 'click', pageObj.employerhandle.listHandle(pageObj));
        bind($('.select_employ'), 'click', pageObj.employerhandle.submitHandle(pageObj));
    },
    employerhandle: {
        listHandle: function (pObj) {
            var pageObj = pObj;
            return function(){
                var _this = $(this);
                var obj = _this.find('.check_box');
                var selected_num = parseInt($('.selected_num').text(), 10);
                var employerId = _this.attr('uuid');
                if (obj.hasClass('checked_box')) {
                    if ($('#employer_list').find('.' + employerId).length > 0) {
                        $('#employer_list').find('.' + employerId).find('.check_box').removeClass('checked_box');
                    }
                    _this.find('.check_box').removeClass('checked_box');
                    $('.selected_num').text(selected_num - 1);
                } else {
                    if (pageObj.select === 'single'){
                        $('#employer_list').find('.checked_box').removeClass('checked_box');
                        //$('#employer_list2').find('.checked_box').removeClass('checked_box');
                        selected_num = 0;
                    }
                    if ($('#employer_list').find('.' + employerId).length > 0) {
                        $('#employer_list').find('.' + employerId).find('.check_box').addClass('checked_box');
                    }
                    _this.find('.check_box').addClass('checked_box');
                    $('.selected_num').text(selected_num + 1);
                }
            };
        },
        submitHandle: function (pObj) {
            var pageObj = pObj;
            return function(){
                var bPage = $('#Address_Book').find('.pageBackward').eq(0).attr('link');
                var gotData = null;
                var selectedUUID = [];
                $('#employer_list').find('.employer_item').each(function () {
                    if ($(this).find('.check_box').eq(0).hasClass('checked_box')){
                        selectedUUID.push($(this).attr('uuid'));
                        $(this).removeClass('checked_box');
                    }
                });		
		        $('#Address_Book').find('.selected_num').text(0);
                switch (pageObj.require){
                    case 'name_eid':
                        var text = selectedUUID.map(function(id){
                            return '@' + employer_status[employer_status_sub(id.toString())].name_employid;}
                          ).join(' ');
                        gotData = {'name_eid':text};
				
                        break;
                    case 'phone_name':
                        var text = selectedUUID.map(function(id){
                          var e = employer_status[employer_status_sub(id)];
                          return e.phone + '[' + e.name + ']';}
                          ).join(';');
                        gotData = {'phone_name':text};
                        break;
				   case 'invite':	
				   	   gotData = {'invitemembers':selectedUUID};
				        break;
                }
                   $('#Address_Book').find('.pageBackward').click();
                   pageMngr.pageParaSet(bPage, gotData);
            };
        }
    }

}

function new_msg_page() {
    this.pageDom = $('#new_msg');
	this.data ='';
}
new_msg_page.prototype = {
    pageEnter: function() {
	    this.pageDom.find('.lwork_mes').focus().val('');
    },
    pageParaSet: function(paras) {
        if (paras.name_eid){
            var oldTxt = this.pageDom.find('.lwork_mes').val();
            this.pageDom.find('.lwork_mes').focus().val(oldTxt + paras.name_eid + ' ').prev().hide();
        }
		if(paras['title']){		
			this.pageDom.find('.newmsg_title').text(paras['title']);	
	    }
		if(paras['tip']){
		    this.pageDom.find('.write_tip').text(paras['tip']);	
		}
		if(paras['data']){
			this.data = paras['data'];			
		}
    },
    bindHandlers: function() {
		var curobj = this;		
        bind($('.sendmsg'), 'click', function () {
			var mode = $('#new_msg').find('.goback').attr('link');
            var con = $('#new_msg').find('.lwork_mes').val();	
			if(mode !== 'msgdetail'){	
			  pageMngr.getPageObj(mode).sendmsg(mode , con);
			}else{
		      var str = curobj['data'].split('&&');		
			  pageMngr.getPageObj(mode).sendcomt(str[3], str[0], con, 'tip');								
			}
        });
    },
}
//
function msgdetail(){
   this.pageDom = $('#msgdetail');
}
msgdetail.prototype = {
  pageEnter: function () {
	 myScroll['msgdetail'].refresh();
  },
  bindHandlers: function(){
	var curobj = this;
	bind($('.sendcomt'), 'click', function(){
      pageMngr.pageForwardCall('msgdetail', 'new_msg', {'title':'微博回复', 'tip':'说说我的想法', 'data':curobj.pageDom.find('.msgdetail_con').attr('data')});
	})
	bind($('.focusmsg'),'click' , curobj.setfocus(curobj));
	bind($('.cancelFocus'),'click' , curobj.cancelFocus(curobj));
  },
  pageParaSet: function(paras) {
	  if(paras){
		  if(paras['invitemembers']){
		  	  this.invite(paras['invitemembers']);		
			  return false;
	      } 
		  var obj = this.pageDom;
		  var str  = (paras['id']).split('&&');
		  var employer = employer_status[employer_status_sub(str[1])];
		  var owner = '未知', delete_css = 'delete_uuid', photo = '/images/photo/defalt_photo.gif', name_employid = '未知';	
		  var settitle = obj.find('.msgdetail_title');
		   if (employer){
			  owner = employer['name_employid'];
			  photo = employer['photo'];
		  }
		  switch(str[3]){
			  case 'topics': 
			     obj.find('.trace_btn').hide().prev().hide();
				 obj.find('.focusmsg').show().next().hide();	
				 settitle.text('企业微博正文');
				 break;
	          case 'tasks':
			  	 obj.find('.trace_btn').show().prev().show();
				 obj.find('.unreadinvite').text(str[4]);	
				 obj.find('.focusmsg').show().next().hide();				 
				 settitle.text('工作协同正文');
				 break;
		      case 'focus':
				 obj.find('.cancelfocus').show().prev().hide();		
			    if(str[4] !== 'undefined'){
				   obj.find('.trace_btn').show().prev().show();
				   obj.find('.unreadinvite').text(str[4]);	
				   str[3] = 'tasks';
				  }else{
				   obj.find('.trace_btn').hide().prev().hide();	 
				   str[3] = 'topics';	
				  }
				 settitle.text('我的关注');
				 break;					 			      
			}
		  obj.find('.msgdetail_con').attr('data', paras['id']);
		  obj.find('pre').html(paras['content']);
		  obj.find('.modifyperinof_content').find('img').attr('src', photo);
		  obj.find('.modifyperinof_content').find('.name').text(owner);
		  obj.find('.msgcontent').find('.unreadcomt').text(str[2]);	
		  this.loadcomt(str[3], str[0]);
	  }
  },
  createcomtdom: function(msg){	
    var content = msg['content'];
    var employer = employer_status[employer_status_sub(msg['from'])];
    var owner = '未知', delete_css = 'delete_uuid', photo = '/images/photo/defalt_photo.gif', name_employid = '未知';	
       if (employer){
          owner = employer['name'];
          photo = employer['photo'];
		  name_employid = employer['name_employid']
      }	
	return  ['<dl><dt class="sub_dt"><img src="'+ photo +'" width="28" height="28"></dt>',
			 '<dd class="sub_dd">',
			 '<span employer_uuid="259" class="lanucher delete_uuid delete_259">'+ owner +'</span>：'+ content +'</dd>',
			 '<dd class="sub_dd"><span class="gray">'+ msg['timestamp'] +'</span>',
			 '<a href="###" data = "'+ name_employid +'&&'+msg['to'] + '&&' + msg['findex'] + '&&' + msg['tindex'] +'" class="sub_comment">回复 </a>',
			 '</dd>',
			 '</dl>'].join('');
  },
  setfocus: function(curobj){
		  return function(){
			var data = curobj.pageDom.find('.msgdetail_con').attr('data');
		    var str = data.split('&&');	
			var _this = $(this);  
			api.focus.setFocus(uuid, [{"type":str[3], "entity_id":str[0], "tags":[]}], function(){
				_this.hide().next().show();			
				if(str[3] !== 'focus'){		
				  if($('#focus_msg').find('.focus_msg' +str[0]).length <= 0 ){				
				    $('.' + str[3] + '_msg' + str[0]).clone(true).prependTo($('#focus_msg'));		
				  }
				}
				tips('关注成功');				
			})
		  }
	},
  cancelFocus: function(curobj){
		  return function(){
			var data = curobj.pageDom.find('.msgdetail_con').attr('data');
		    var str = data.split('&&');	
			var _this = $(this);
            str[4] !== 'undefined' ? type = 'tasks' : type = 'topics';				
            api.focus.cancelFocus(uuid, type, str[0], function(){
				if(str[3] === 'focus'){
				   $('.focus_msg' + str[0]).remove();
				}else{															
				   $('.' + str[3] + '_msg' + str[0]).clone(true).prependTo($('#focus_msg'));					
				}
				_this.hide().prev().show();	
				tips('已取消关注');
			})
		  }	
  },
  invite: function(new_members){
	var curobj = this ;
	var data = this.pageDom.find('.msgdetail_con').attr('data');
	var str = data.split('&&');
	api.content.msginvite(str[3], str[0], uuid, new_members, function (data) {	
	   console.log(str[3])
       if(str[3] === 'topics'){
		   var content = '邀请了 '; 
		   for ( var i = 0 ; i < new_members.length ; i++ ){
		    content += employer_status[employer_status_sub(new_members[i])]['name_employid'] + ' ';	   
		   }
		    curobj.sendcomt(str[3], str[0], content);
		 } 
		    tips('邀请成功！'); 		
	})
  },
  sendcomt: function(mode, task_id, content, tip){
	var curobj = this;
	var content = content.replace(/(^\s*)|(\s*$)/g, "");		
    var to = "-1";		 
	if(content.indexOf('回复') === 0){	
	  var name = content.slice(parseInt(content.indexOf('@')) + 1,parseInt(content.indexOf(':')));	
	  if(name2user[name]) to = (name2user[name]['uuid']).toString();
	}
	  if(to === '-1'){ comt_index = '-1';to = '-1';}
	  api.content.sendreplies(mode, task_id, uuid, content, -1, -1, function (data) {
         var msg = {
			 'from' : uuid,
			 'timestamp': data['timestamp'],
			 'content': content,
			 'to' : -1,
			 'findex': -1,
			 'tindex' : -1 
		 }
		$('#comt_msg').find('dl').length > 0 ? $('#comt_msg').prepend(curobj.createcomtdom(msg)) : $('#comt_msg').html(curobj.createcomtdom(msg));	 
		if(tip){
		  $('#new_msg').find('.goback').click();
		  $('#new_msg').find('.lwork_mes').val('');
		  tips('回复成功');		
		}
	 })
  },
  loadcomt: function(mode, entity_id){
        var opt, msg_id;
		var curobj = this;
        opt = { uuid: uuid, entity_id: entity_id, 't': new Date().getTime() };
        api.content.load_comt(mode, opt, function (data) {
            var obj = data['replies'],
		        html = '';
			if(obj.length > 0){				 
			  for (var i = 0; i < obj.length; i++) {	
				html += curobj.createcomtdom(obj[i]);				
			  }			  
			  $('#comt_msg').html(html);
			  myScroll['msgdetail'].refresh();
		    }else{
			  $('#comt_msg').html('当前没有任何回复。');
			}
        });
  }
}


function loadContent(mode) {
	this.mode = mode;
}
loadContent.prototype = {
    pageEnter: function () {
        this.loadmsg_handle(this.mode, '1');		
    },
    bindHandlers: function() {
		
		
    },
    loadmsg_handle: function (linkhref, page_index, flag, callback) {
		var mode = this.mode;
        var loadmore = flag && '' !== flag ? flag : '';		
		var type = 'none' ,status = 'all' ;		

		if(linkhref === 'tasks') { type = 'assigned';   status = 'unfinished'}		
		if ('no' === $('#'+ mode +'_msg').attr('containdom') || '' !== loadmore) {
			$('#'+ mode +'_msg').prepend('<div class="loading"><img alt="" src="images/loading.gif"> 正在加载.... </div>')
			this.loadmsg(mode, type, status, mode +'_msg', page_index, 2, callback);
		}		
    },
    loadmsg: function (mode, type, status, continer, page_index, callback) {
        var current_obj = this;
        api.content.load_msg(mode, uuid, type, status, page_index, '50', function (data) {
            var html = '',
  		    msg = data[mode];
            for (var i = 0; i < msg.length; i++) {
                html += current_obj.loadmsgfun.createmsgDom(msg[i], mode , continer);
            }
            $('#' + continer).html(html);
			$('#'+ continer).attr('containdom', 'yes');
		    myScroll[mode].refresh();
		    bind($('.msg_item'), 'click', function(){		
				   var _this = $(this);
				   var paras = { 'id': _this.attr('data'), 'content': _this.find('pre').html()}
				   
				   pageMngr.pageForwardCall(mode, 'msgdetail', paras);		   
			   });			   
		    bind($('.pagecontent_img'), 'click', function(){ 
			
			   
			    return false;
			})
        }, function(data){
			 $('#' + continer).find('.loading').remove();
			 tips('加载失败');
		});
    },
    loadmsgfun: {
        format_content: function (content, the_class) {
            var regexp = /((ftp|http|https):\/\/(\w+:{0,1}\w*@)?([A-Za-z0-9][\w#!:.?+=&%@!\-\/]+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?)/gi;
            content = content.replace(/(^\s*)|(\s*$)/g, "");
            content = content.replace(/</g, '<span> <</span>');
            content = content.replace(regexp, '<a class="' + the_class + '" target="_blank" href="$1">$1</a>');
            content = content.replace(/(@[^\s]+)\s*/g, '<span class="' + the_class + '">$1</span>');
            return content.replace(/\n/g, '<br\>');
        },
        createmsgDom: function (msg, mode, continer) {
			if(mode === 'focus') msg = msg['content'];
            var employer = employer_status[employer_status_sub(msg['from'])];
            var owner = '未知', delete_css = 'delete_uuid', photo = '/images/photo/defalt_photo.gif', delete_uuid = 'delete_' + msg['from'], name_employid = '未知',
			 comt_name_uuid = 'comt_name_' + msg['from'];			 
            var content = this.format_content(msg['content'], 'linkuser')
            if (employer) {
                owner = employer['name'];
                photo = employer['photo'];
            }
            return ['<dl class="msg_item '+ continer + msg['entity_id'] +'"  data = "' + msg['entity_id'] + '&&'+ msg['from'] +'&&'+ msg['replies'] +'&&'+ mode +'&&'+ msg['traces']+'" >',
				   '<dd class="personal_icon"><img src="' + photo + '" width="35" height="35"></dd>',
				   '<dd class="pagecontent"><div><span class="lanucher">' + owner + '</span>：<span class="msg_time">' + msg['timestamp'] + '</span></div>',
				   '<pre>' + content + '</pre>'+ this.getimg_url(msg['image']) +'</dd>',
				   '<dd class="pagefoot"><a href="###" mode="" class="comment">回复 (<span class="unreadcomt">' + msg['replies'] + '</span>)</a></dd>',
				   '</dl>'].join('');
        },
		getimg_url: function(img_obj){	
		    var html = "", images = '';	
			if(img_obj){
				if(typeof(img_obj) !== 'object'){
				  if(img_obj.indexOf('share;') < 0){
					  images = this.getpicphoto(img_obj, 'S');
					//  source_imag = img_obj;
				  }
				}
				if('' !== images)  html='<div class="pagecontent_img"><img src ="'+images +'"/></div>';
			}
			return html;			  
			
		},
		getpicphoto: function(filename, type){			
			var str = filename.split('.');
			var len = str.length;
			var newfilename = '';
			var filetype = (str[str.length-1]).toLowerCase();
				//console.log(filetype)
			str[len-2] =  str[len-2] + type + '.';
			if(filetype.indexOf('yaws') < 0){			
			for(var i = 0 ; i<len; i++){
				newfilename += str[i];
			}
			  return newfilename ;
			}else{
			  return filename 
		   }
		   
		}
    },
    sendmsg: function(mode, con){		
		var members = extract_uuid(con);
		opt = { uuid: uuid, content: con, members: members, image: '', 't': new Date().getTime() };
		api.content.publish(mode, opt, function (data) {
			var msg = {
				content: con,
				entity_id: data['entity_id'],
				from: uuid,
				owner_id: uuid,
				image: '',
				replies: 0,
				traces: 0,
				timestamp: data['timestamp']
			}
		 $('#'+ mode +'_msg').prepend(pageMngr.getPageObj(mode).loadmsgfun.createmsgDom(msg))
				$('#new_msg').find('.goback').click();
				$('#new_msg').find('.lwork_mes').val('');
		 });
	}
}