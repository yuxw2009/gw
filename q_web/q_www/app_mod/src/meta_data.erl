-module(meta_data).
-compile(export_all).

-include("yaws_api.hrl").
trans(ID, Arg)->
    case yaws_api:queryvar(Arg,"language") of
        {ok, Lan} -> trans(ID, Arg, utility:atom(Lan));
        undefined -> trans(ID, Arg, ch)
    end.

trans("ID_ORIGINAL_IP", Arg, _) ->  (Arg#arg.headers)#headers.host;
trans("ID_FULLNAME", Arg, _)    ->
    {ClientIp, _} = Arg#arg.client_ip_port,
    case yaws_api:queryvar(Arg,"uuid") of
        {ok, UUID} -> 
	        auth_handler:get_com_full_name(list_to_integer(UUID), ClientIp);					 
        undefined ->
            "Unknown"
    end;
trans("ID_NAV_LIST", Arg, _) ->
    {ClientIp, _} = Arg#arg.client_ip_port,
    case yaws_api:queryvar(Arg,"uuid") of
        {ok, UUID} ->  
		    Navs = auth_handler:get_com_navigators(list_to_integer(UUID), ClientIp),
		    nav_to_html(Navs);
        undefined ->
            nav_to_html([])
    end;
	
trans(ID, _Arg, Lan) -> t(ID, Lan).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
t("ID_IT_NAV", en) -> "IT Navs";
t("ID_IT_NAV", ch) -> "企业IT导航";

t("ID_SETTINGS", en) -> "My profile";
t("ID_SETTINGS", ch) -> "个人设置";

t("ID_LWORK_PLATFORM", en) -> "Lwork Working Platform";
t("ID_LWORK_PLATFORM", ch) -> "Lwork工作平台";

t("ID_PLATFORM", en) -> "Working Platform";
t("ID_PLATFORM", ch) -> "工作平台";

t("ID_CHANGE_PASSWORD", en) -> "Change Password";
t("ID_CHANGE_PASSWORD", ch) -> "更改密码";

t("ID_EXIT", en) -> "Sign Off";
t("ID_EXIT", ch) -> "退出系统";

t("ID_WEIBO", en) -> "Enterprise Weibo";
t("ID_WEIBO", ch) -> "企业微博";

t("ID_NEW_TOPIC", en) -> "New Topic";
t("ID_NEW_TOPIC", ch) -> "新话题";

t("ID_NEW_REPLY", en) -> "New Reply";
t("ID_NEW_REPLY", ch) -> "新回复";

t("ID_TASK", en) -> "Task";
t("ID_TASK", ch) -> "工作任务";

t("ID_NEW_TASK", en) -> "New Task";
t("ID_NEW_TASK", ch) -> "新任务";

t("ID_VIDEO_CALL", en) -> "Web Video";
t("ID_VIDEO_CALL", ch) -> "Web视频";

t("ID_VOTE", en) -> "Vote";
t("ID_VOTE", ch) -> "投票";

t("ID_NEW_VOTE", en) -> "New Vote";
t("ID_NEW_VOTE", ch) -> "新投票";

t("ID_TASK_COMPLETE", en) -> "You have<span class=\"new_msg_num\">0</span>task to be completed by organizer";
t("ID_TASK_COMPLETE", ch) -> "您当前有<span class=\"new_msg_num\">0</span>条任务被发起人完成！";

t("ID_KEYWORD_SEARCH", en) -> "Search Keyword";
t("ID_KEYWORD_SEARCH", ch) -> "搜索关键字";

t("ID_TIPS", en) -> "Tips";
t("ID_TIPS", ch) -> "温馨提示";

t("ID_INSTALL", en) -> "Voip and Video Call in Lwork take the leading technology of HTML5.Click to install";
t("ID_INSTALL", ch) -> "Lwork工作平台网络电话、视频通话部分功能使用了HTML5中的领先特性。点击安装";

t("ID_CHROME_BROWSER", en) -> "Chrome Browser";
t("ID_CHROME_BROWSER", ch) -> "chrome浏览器";

t("ID_HARDWARE_CHECK", en) -> "In addition:Please check the MIC and Camera are normal on your computer when you are using VoIP and Video calls.";
t("ID_HARDWARE_CHECK", ch) -> "另外：当您打网络电话和使用视频通话功能时，请检查您的电脑是否安装麦克风、摄像头等设备。";

t("ID_CLICK_INSTALL", en) -> "Install Chrome online";
t("ID_CLICK_INSTALL", ch) -> "在线安装";

t("ID_CLICK_OFFLINEINSTALL", en) -> "Download form Cloud disk";
t("ID_CLICK_OFFLINEINSTALL", ch) -> "离线下载";

t("ID_LATE_TIME", en) -> "Try it at a later time";
t("ID_LATE_TIME", ch) -> "看看再说";

t("ID_MY_FAVORITE", en) -> "My Favorite";
t("ID_MY_FAVORITE", ch) -> "我的关注";

t("ID_CLOUD_DISK", en) -> "My Disk";
t("ID_CLOUD_DISK", ch) -> "我的网盘";

t("ID_LETS_WORK", en) -> "Team Collaboration";
t("ID_LETS_WORK", ch) -> "工作协同";

t("ID_LETS_FORUM", en) -> "Forum";
t("ID_LETS_FORUM", ch) -> "交流论坛";

t("ID_ENTERPRISE_WEIBO", en) -> "Enterprise Weibo";
t("ID_ENTERPRISE_WEIBO", ch) -> "企业微博";

t("ID_BALLOT", en) -> "Poll";
t("ID_BALLOT", ch) -> "集体决策";

t("ID_QA", en) -> "Enterprise Wiki";
t("ID_QA", ch) -> "企业百科";

t("ID_CONFERENCE_CALL", en) -> "Voice Conference";
t("ID_CONFERENCE_CALL", ch) -> "电话会议";

t("ID_VOIP", en) -> "Web Call";
t("ID_VOIP", ch) -> "Web电话";

t("ID_SMS", en) -> "Web SMS";
t("ID_SMS", ch) -> "Web短信";

t("ID_POST_WEIBO", en) -> "Post a Weibo!@Colleague @Group @Department";
t("ID_POST_WEIBO", ch) -> "发个微博吧 @同事 @群组 @部门";

t("ID_POST", en) -> "Post";
t("ID_POST", ch) -> "发布";

t("ID_CHARACTER_LEFT", en) -> "You can only enter";
t("ID_CHARACTER_LEFT", ch) -> "还能输入";

t("ID_CHARACTER_RIGHT", en) -> "Characters left";
t("ID_CHARACTER_RIGHT", ch) -> "个字";

t("ID_ALL_WEIBO", en) -> "All Weibos";
t("ID_ALL_WEIBO", ch) -> "全部微博";

t("ID_MY_SARLARY", en) -> "My Salary";
t("ID_MY_SARLARY", ch) -> "我的工资";

t("ID_UNREAD_WEIBO", en) -> "You have<span class=\"unreadmsg_num\">1</span>unread Weibo";
t("ID_UNREAD_WEIBO", ch) -> "你当前有<span class=\"unreadmsg_num\">1</span>条未读微博";

t("ID_UNREAD_REPLY", en) -> "You have<span class=\"unreadmsg_num\">1</span>unread reply";
t("ID_UNREAD_REPLY", ch) -> "你当前有<span class=\"unreadcomt_num\">1</span>条未读回复";

t("ID_START_WORK", en) -> "Start working with your @colleague @group @department";
t("ID_START_WORK", ch) -> "为了提高同事间配合的效率，发起一个工作协同吧！ @同事 @群组 @部门";

t("ID_IMAGE", en) -> "Image";
t("ID_IMAGE", ch) -> "图片";

t("ID_ATTACHMENT", en) -> "Attachment";
t("ID_ATTACHMENT", ch) -> "附件";

t("ID_FROM_OTHERS", en) -> "From Others";
t("ID_FROM_OTHERS", ch) -> "我协同的工作";

t("ID_TO_OTHERS", en) -> "To Others";
t("ID_TO_OTHERS", ch) -> "我发起的工作";

t("ID_COMPLETE", en) -> "Completed";
t("ID_COMPLETE", ch) -> "已完成的工作";

t("ID_UNREAD_TASK", en) -> "You have<span class=\"unreadmsg_num\">1</span>unread task";
t("ID_UNREAD_TASK", ch) -> "你当前有<span class=\"unreadmsg_num\">0</span>条未读工作任务";

t("ID_EXPLAIN_QA", en) -> "Post a question from your issue, maybe someone else has same issue.";
t("ID_EXPLAIN_QA", ch) -> "你遇到的问题也许其他同事也碰到过并解决了，问问看吧";

t("ID_ASK_QUESTION", en) -> "Ask a question";
t("ID_ASK_QUESTION", ch) -> "问题";

t("ID_DETAILS", en) -> "Describtion";
t("ID_DETAILS", ch) -> "详细描述";

t("ID_SET_TAG", en) -> "Easy to find after setting a tag. Can be set 5 tags in max,separated by a space.";
t("ID_SET_TAG", ch) -> "打个标签便于今后查找，可以设置5个标签，空格分开";

t("ID_MODETIPS_CONFERENCE", en) -> "The conference call will take up the time of all participants, let's proceed efeciently!";
t("ID_MODETIPS_CONFERENCE", ch) -> "电话会议将占用所有参会者的时间，请注意会议效率！";

t("ID_CONFERENCE_TOPIC", en) -> "Conference Topic: New Meeting";
t("ID_CONFERENCE_TOPIC", ch) -> "会议主题:新会议";

t("ID_USERNAME", en) -> "Enter a phone number or the name of your staff.";
t("ID_USERNAME", ch) -> "输入电话号码/拼音或汉字";

t("ID_ONGOING_MEMBER", en) -> "Current participants";
t("ID_ONGOING_MEMBER", ch) -> "当前会议成员";

t("ID_CONFERENCE_MEMBER", en) -> "Conference member";
t("ID_CONFERENCE_MEMBER", ch) -> "会议成员";

t("ID_DELETE", en) -> "Delete";
t("ID_DELETE", ch) -> "删除";

t("ID_HOST", en) -> "Host";
t("ID_HOST", ch) -> "设为主持人";

t("ID_START_MEETING", en) -> "Start";
t("ID_START_MEETING", ch) -> "开始会议";

t("ID_END_MEETING", en) -> "END";
t("ID_END_MEETING", ch) -> "结束会议";

t("ID_MODETIPS_VOIP", en) -> "For important thing, Voice Call is better!";
t("ID_MODETIPS_VOIP", ch) -> "紧急事情通过电话沟通吧！";

t("ID_VOIP_PHONENUMBER", en) -> "Search by phone number or name";
t("ID_VOIP_PHONENUMBER", ch) -> "输入电话号码/拼音或汉字搜索！";

t("ID_CALL_STATUS", en) -> "Talking with<span class=\"peerNumStr\">xxxx</span>...";
t("ID_CALL_STATUS", ch) -> "与<span class=\"peerNumStr\">xxxx</span>通话中...";

t("ID_CALLING", en) -> "Call";
t("ID_CALLING", ch) -> "呼叫";

t("ID_HANG_UP", en) -> "Hang up";
t("ID_HANG_UP", ch) -> "挂断";

t("ID_P2P_VIDEO", en) -> "Video Call";
t("ID_P2P_VIDEO", ch) -> "视频通话";

t("ID_MP_VIDEO", en) -> "Multi-part Video";
t("ID_MP_VIDEO", ch) -> "多方视频";

t("ID_START_VIDEO", en) -> "Start";
t("ID_START_VIDEO", ch) -> "发起";

t("ID_END_VIDEO", en) -> "End";
t("ID_END_VIDEO", ch) -> "结束";

t("ID_EXIT_VIDEO", en) -> "Exit";
t("ID_EXIT_VIDEO", ch) -> "退出";

t("ID_REMOVE_VIDEO", en) -> "Remove";
t("ID_REMOVE_VIDEO", ch) -> "请出";

t("ID_MODETIPS_BALLOT", en) -> "Let everyone together to help your decision-making. @colleague@Group@Department";
t("ID_MODETIPS_BALLOT", ch) -> "拿不定主意吗？ 那就让大家一起帮你决策吧 @同事 @群组 @部门";

t("ID_MAKE_DECISION", en) -> "Poll Topic";
t("ID_MAKE_DECISION", ch) -> "决策事项";

t("ID_NEW_BALLOT", en) -> "You have<span class=\"unreadmsg_num\">1</span>new ballot";
t("ID_NEW_BALLOT", ch) -> "你当前有<span class=\"unreadmsg_num\">1</span>条新投票";

t("ID_MODETIPS_DISK", en) -> "Easy Store, Easy Search";
t("ID_MODETIPS_DISK", ch) -> "保存您的工作文件，方便查找！";

t("ID_FILE_NAME", en) -> "File name";
t("ID_FILE_NAME", ch) -> "文件名";

t("ID_FILE_CHOOSEFILE", en) -> "Choose File";
t("ID_FILE_CHOOSEFILE", ch) -> "本地文件";

t("ID_FILE_UPLOADFILE", en) -> "Upload Files";
t("ID_FILE_UPLOADFILE", ch) -> "上传文件";

t("ID_ALL_FILE", en) -> "All Files";
t("ID_ALL_FILE", ch) -> "所有文件";

t("ID_IMAGES_FILE", en) -> "Images";
t("ID_IMAGES_FILE", ch) -> "图片";

t("ID_DOC_FILE", en) -> "Documents";
t("ID_DOC_FILE", ch) -> "文档";

t("ID_RAR_FILE", en) -> "Compression";
t("ID_RAR_FILE", ch) -> "压缩包";

t("ID_OTHER_FILE", en) -> "Other Files";
t("ID_OTHER_FILE", ch) -> "其他文件";

t("ID_UPDATED", en) -> "Updated";
t("ID_UPDATED", ch) -> "更新时间";

t("ID_SIZE", en) -> "Size";
t("ID_SIZE", ch) -> "文件大小";

t("ID_MODETIPS_VIDEO", en) -> "Start a video call with a colleague";
t("ID_MODETIPS_VIDEO", ch) -> "向同事发起视频通话！";

t("ID_TIP_CHROME", en) -> "This feature takes the leading technology of HTML5.Require the use of a browser that supports these features.We recommend Chrome((22.0.1229.8 dev-m or above).Click to install:";
t("ID_TIP_CHROME", ch) -> "本功能使用了HTML5中的领先特性，因此需要使用支持这些特性的浏览器，我们推荐Chrome(22.0.1229.8 dev-m或以上版本)， 点击安装：";

t("ID_RESTART_BROWSER", en) -> "Restart the browser";
t("ID_RESTART_BROWSER", ch) -> "重启浏览器";

t("ID_CALLEE", en) -> "Callee";
t("ID_CALLEE", ch) -> "视频对象";

t("ID_MODETIPS_SMS", en) -> "SMS for offline notice.";
t("ID_MODETIPS_SMS", ch) -> "同事不在线？发送手机短信给他吧！手机短信存在延时，紧急情况请选择其他联系方式。";

t("ID_SMS_RECEIVER", en) -> "Phone Number/@colleague/@Group";
t("ID_SMS_RECEIVER", ch) -> "手机号码/@同事/@群组(分号\";\"隔开)";

t("ID_SMS_CONTENT", en) -> "SMS Content";
t("ID_SMS_CONTENT", ch) -> "输入短信内容";

t("ID_SEND", en) -> "Send";
t("ID_SEND", ch) -> "发送";

t("ID_SMS_LIMIT", en) -> "<span class=\"maxNum\">120</span><span>Characters";
t("ID_SMS_LIMIT", ch) -> "还能输入<span class=\"maxNum\">120</span><span>个字，最多可输入120个字";

t("ID_SMS_HISTORY", en) -> "SMS history";
t("ID_SMS_HISTORY", ch) -> "查看已发短信";

t("ID_FAVORITE_TOTAL", en) -> "(Total <span class='focus_num'>0</span>)";
t("ID_FAVORITE_TOTAL", ch) -> "(共<span class='focus_num'>0</span>条)";

t("ID_MY_FAVORITE1", en) -> "The task and Weibo which I am interested with";
t("ID_MY_FAVORITE1", ch) -> "我关注的工作任务和微博";

t("ID_RECYCLE_BIN", en) -> "Recycle Bin";
t("ID_RECYCLE_BIN", ch) -> "回收站";

t("ID_DELETED_MESSAGE", en) -> "Deleted message";
t("ID_DELETED_MESSAGE", ch) -> "已删除的消息";

t("ID_RECYCLE_ENPTY", en) -> "Clear";
t("ID_RECYCLE_ENPTY", ch) -> "清空回收站";

t("ID_SEARCH_RESULT", en) -> "Search result";
t("ID_SEARCH_RESULT", ch) -> "我的搜索结果";

t("ID_SEARCH_RESULT_NUM", en) -> " (Total <span class='search_result_num'>0</span>)";
t("ID_SEARCH_RESULT_NUM", ch) -> "（共<span class='search_result_num'>0</span>条）";

t("ID_KEY_WORD", en) -> "与<span class=\"search_keyword\">某关键字</span>相关的<span class=\"search_type\">某类消息";
t("ID_KEY_WORD", ch) -> "与<span class=\"search_keyword\">某关键字</span>相关的<span class=\"search_type\">某类消息";

t("ID_ABANDON_SEARCH", en) -> "Abandon_search";
t("ID_ABANDON_SEARCH", ch) -> "放弃搜索";

t("ID_ORG_STRUCTURE", en) -> "Company";
t("ID_ORG_STRUCTURE", ch) -> "组织架构";

t("ID_ORG_GROUP", en) -> "My Group";
t("ID_ORG_GROUP", ch) -> "自定义分组";

t("ID_ORG_RECENT", en) -> "Recent";
t("ID_ORG_RECENT", ch) -> "最近联系人";

t("ID_OPTION", en) -> "Option";
t("ID_OPTION", ch) -> "选项";

t("ID_VIDEO_SEARCH", en) -> "Search/Choose a contact";
t("ID_VIDEO_SEARCH", ch) -> "搜索/右边选择联系人";

t("ID_ORG_SEARCH", en) -> "Search";
t("ID_ORG_SEARCH", ch) -> "搜索联系人";

t("ID_ORG_SEARCHRESULTS", en) -> "Results";
t("ID_ORG_SEARCHRESULTS", ch) -> "搜索结果";

t("ID_GROUP_CREATE", en) -> "Create";
t("ID_GROUP_CREATE", ch) -> "创建组";

t("ID_SEARCH_LOADING", en) -> "Loading...";
t("ID_SEARCH_LOADING", ch) -> "正在加载...";

t("ID_CREATE_EXIST", en) -> "The group is existed";
t("ID_CREATE_EXIST", ch) -> "不能与现有的组重复";

t("ID_GROUP_NAME", en) -> "Group Name:";
t("ID_GROUP_NAME", ch) -> "组名称：";

t("ID_APP_DIREC", en) -> "Apps";
t("ID_APP_DIREC", ch) -> "移动客户端下载";

t("ID_APP_ANDROID", en) -> "Lwork for android";
t("ID_APP_ANDROID", ch) -> "android客户端";

t("ID_APP_IPHONE", en) -> "Lwork for iphone";
t("ID_APP_IPHONE", ch) -> "iphone客户端";

t("ID_TIP_GROUPNAME", en) -> "The group name can not be same with the existed group";
t("ID_TIP_GROUPNAME", ch) -> "输入组名不能与现有的组重复";

t("ID_TIP_GROUPEMPTY", en) -> "The group name can not be empty!";
t("ID_TIP_GROUPEMPTY", ch) -> "组名称不能为空！";

t("ID_TIP_SEARCH", en) -> "Add members by searching";
t("ID_TIP_SEARCH", ch) -> "通过拼音或汉字搜索添加成员";

t("ID_CHANGE", en) -> "Change";
t("ID_CHANGE", ch) -> "更换";

t("ID_TDTITLE_STAFFID", en) -> "Name and Staffid:";
t("ID_TDTITLE_STAFFID", ch) -> "姓名工号：";

t("ID_TDTITLE_DEPT", en) -> "Department:";
t("ID_TDTITLE_DEPT", ch) -> "所在部门：";

t("ID_TDTITLE_PHONE_MOBILE", en) -> "Mobile Number:";
t("ID_TDTITLE_PHONE_MOBILE", ch) -> "手机：";

t("ID_TDTITLE_PHONE_PSTN", en) -> "PSTN Number:";
t("ID_TDTITLE_PHONE_PSTN", ch) -> "固话：";

t("ID_TDTITLE_PHONE_EXTENSION", en) -> "Ext Number:";
t("ID_TDTITLE_PHONE_EXTENSION", ch) -> "分机：";

t("ID_TDTITLE_PHONE_OTHER", en) -> "Other Number:";
t("ID_TDTITLE_PHONE_OTHER", ch) -> "其他：";

t("ID_TDTITLE_MAIL", en) -> "E-Mail:";
t("ID_TDTITLE_MAIL", ch) -> "公司邮箱：";

t("ID_TIP_PASSWORD", en) -> "Password can not be empty";
t("ID_TIP_PASSWORD", ch) -> "原密码不能为空";

t("ID_OLD_PASSWORD", en) -> "Old Password:";
t("ID_OLD_PASSWORD", ch) -> "原密码：";

t("ID_NEW_PASSWORD", en) -> "New Password:";
t("ID_NEW_PASSWORD", ch) -> "新密码：";

t("ID_REPEAT_PASSWORD", en) -> "Repeat New Password:";
t("ID_REPEAT_PASSWORD", ch) -> "重复新密码：";

t("ID_IMAGE_RECOMMENDED", en) -> "Recommended image";
t("ID_IMAGE_RECOMMENDED", ch) -> "推荐图像";

t("ID_IMAGE_PREVIEW", en) -> "Preview";
t("ID_IMAGE_PREVIEW", ch) -> "预览";

t("ID_IMAGE_PX", en) -> "Please upload a 100 × 100 pixel picture";
t("ID_IMAGE_PX", ch) -> "请上传100×100像素图片";

t("ID_IMAGE_UPLOAD", en) -> "Uploading your image...";
t("ID_IMAGE_UPLOAD", ch) -> "正在上传您的图像...";

t("ID_ATTACHMENT_UPLOAD", en) -> "The largest single file support 100M";
t("ID_ATTACHMENT_UPLOAD", ch) -> "单个文件最大支持100M";

t("ID_UPLOAD_FILE", en) -> "Upload failed!";
t("ID_UPLOAD_FILE", ch) -> "上传失败！";

t("ID_UPLOAD_FAILED", en) -> "Upload failed!";
t("ID_UPLOAD_FAILED", ch) -> "上传文就按";

t("ID_UPLOAD_LIMITED", en) -> "Please upload Image files less than 1M!";
t("ID_UPLOAD_LIMITED", ch) -> "请上传不超过1M图片文件！";

t("ID_TIP_EXIT", en) -> "Are you sure to exit Lwork?";
t("ID_TIP_EXIT", ch) -> "该操作将会退出Lwork工作平台";

t("ID_FORUM_BACK", en) -> "Back";
t("ID_FORUM_BACK", ch) -> "返回";

t("ID_FORUM_PREV", en) -> "Prev";
t("ID_FORUM_PREV", ch) -> "上一页";

t("ID_FORUM_NEXT", en) -> "Next";
t("ID_FORUM_NEXT", ch) -> "下一页";

t("ID_FORUM_REPLY", en) -> "Reply";
t("ID_FORUM_REPLY", ch) -> "回复";

t("ID_FORUM_SEARCHPOSTS", en) -> "Search for posts";
t("ID_FORUM_SEARCHPOSTS", ch) -> "搜索帖子";

t("ID_FORUM_SUBJECT", en) -> "Subject: ";
t("ID_FORUM_SUBJECT", ch) -> "主题: ";

t("ID_FORUM_TODAY", en) -> "Today: ";
t("ID_FORUM_TODAY", ch) -> "今日: ";

t("ID_FORUM_POST", en) -> "Post";
t("ID_FORUM_POST", ch) -> "发帖";

t("ID_FORUM_WELCOM", en) -> "Welcome to participate in community discussions!";
t("ID_FORUM_WELCOM", ch) -> "欢迎参与社区讨论";

t("ID_FORUM_Room", en) -> "Discussion Room";
t("ID_FORUM_Room", ch) -> "社区版面";


t("ID_FORUM_POSTS", en) -> "Posts";
t("ID_FORUM_POSTS", ch) -> "帖子";

t("ID_OFFLINE_NOTICE", en) -> "Offline";
t("ID_OFFLINE_NOTICE", ch) -> "下线通知";

t("ID_OFFLINE_CONTENT", en) -> "Your account is logon in another location or network connection is interrupted, please click to login again";
t("ID_OFFLINE_CONTENT", ch) -> "由于账号另一个地点登录或网络连接中断等问题，您已被迫下线，请点击重新登录.";

t("ID_LOGIN_AGIN", en) -> "Login again";
t("ID_LOGIN_AGIN", ch) -> "重新登录";

t("ID_WEBIM_DRAG", en) -> "Drag user from contacts for group conversation.";
t("ID_WEBIM_DRAG", ch) -> "拽在线同事头像到对话框即可加入多人聊天";

t("ID_WEBIM_MINTIP", en) -> "Read message";
t("ID_WEBIM_MINTIP", ch) -> "查看即时消息";

t("ID_WEBIM_MINBTN", en) -> "Minimum";
t("ID_WEBIM_MINBTN", ch) -> "最小化";

t("ID_WEBIM_CLOSE", en) -> "Close";
t("ID_WEBIM_CLOSE", ch) -> "关闭";

t("ID_MY_EMAIL", en) -> "My email";
t("ID_MY_EMAIL", ch) -> "我的邮箱";




%%"您当前有<span class=\"new_msg_num\">0</span>条任务被发起人完成！"

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
t(_, _) ->  "not_found".

nav_to_html(Navs) ->
    lists:append(["<li><a href=" ++ URL ++ " target=\"_blank\">"++Name++ "</a> </li>" || {Name,URL} <- Navs]).

