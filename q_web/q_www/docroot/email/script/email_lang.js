var email_lang_cn={ID_MAIL_MANAGER:"邮箱管理",
ID_MAIL_LOGIN_NAME:"邮箱登录" ,
ID_MAIL_ADDRESS:"电子邮箱地址：",
ID_MAIL_PWD:"密码",
ID_MAIL_NOEMPTY:"不能为空",
ID_MAIL_PASSWORD:"密码：",
ID_MAIL_LOGIN:"登录",
ID_MAIL_INBOX:"收件箱",
//ID_MAIL_SENT: "已发送"
ID_MAIL_TRASH:"已删除",
ID_MAIL_SET:"切换邮箱",
ID_MAIL_LOGIN:"登录",
ID_MAIL_OUTBOX:"发件箱",
ID_MAIL_DRAFT:"草稿箱",
ID_MAIL_WRITE_MAIL:"写信",
ID_MAIL_TRANSFER:"转发",
ID_MAIL_REFRESH:"刷新",
ID_MAIL_RESTORE_INBOX:"恢复到收件箱",
ID_MAIL_DELETE_FOREVER:"彻底删除",
ID_MAIL_ADD_CC:"增加抄送",
ID_MAIL_ADD_BCC:"增加密送",
ID_MAIL_DEL_CC:"删除抄送",
ID_MAIL_DEL_BCC:"删除密送",
ID_MAIL_CC: "抄送:",
ID_MAIL_BCC: "密送:",
ID_MAIL_SUBJECT: "主题：",
ID_MAIL_ATTACH_CHOOSE: "选择文件(小于1M)",
ID_MAIL_INPUT_MAIL_CONTENT:"输入邮件内容"};

var email_lang_en={ID_MAIL_MANAGER:"Email Management",
ID_MAIL_LOGIN_NAME:"Email Login" ,
ID_MAIL_ADDRESS:"Email Address",
ID_MAIL_PWD:"Password",
ID_MAIL_NOEMPTY:"no empty",
ID_MAIL_PASSWORD:"Password:",
ID_MAIL_LOGIN:"Login",
ID_MAIL_INBOX:"Inbox",
ID_MAIL_TRASH:"Trash",
ID_MAIL_SET:"Email Setting",
ID_MAIL_OUTBOX:"Outbox",
ID_MAIL_DRAFT:"Draft",
ID_MAIL_WRITE_MAIL:"write mail",
ID_MAIL_TRANSFER:"transfer",
ID_MAIL_REFRESH:"refresh",
ID_MAIL_RESTORE_INBOX:"restore",
ID_MAIL_DELETE_FOREVER:"delete forever",
ID_MAIL_ADD_CC:"add cc",
ID_MAIL_ADD_BCC:"add bcc",
ID_MAIL_DEL_CC:"del cc",
ID_MAIL_DEL_BCC:"del bcc",
ID_MAIL_CC: "cc:",
ID_MAIL_BCC: "bcc:",
ID_MAIL_SUBJECT: "subject:",
ID_MAIL_ATTACH_CHOOSE: "upload attachment(<1M)",
ID_MAIL_INPUT_MAIL_CONTENT:"enter mail content"};

var lw_lang = top.lw_lang;
var email_lang = (top.lw_lang == top.lw_lang_en ? email_lang_en: email_lang_cn);

$('#email_title').text(email_lang.ID_MAIL_MANAGER);
$('#email_login_name').text(email_lang.ID_MAIL_LOGIN_NAME);
$('#mail_password').text(email_lang.ID_MAIL_PASSWORD);
$('#email_addr_name').text(email_lang.ID_MAIL_ADDRESS);
$('.tip_no_empty').text(email_lang.ID_MAIL_NOEMPTY);
$('.submit_setmail').text(email_lang.ID_MAIL_LOGIN);
$('.cancel_setmail').text(lw_lang.ID_CANCEL);
$('.inbox_name').text(email_lang.ID_MAIL_INBOX);
$('.sent_name').text(email_lang.ID_MAIL_OUTBOX);
$('.draft_name').text(email_lang.ID_MAIL_DRAFT);
$('.trash_name').text(email_lang.ID_MAIL_TRASH);
$('.nui-menu .setup').text(email_lang.ID_MAIL_SET);
$('.write_mail_name').text(email_lang.ID_MAIL_WRITE_MAIL);
$('.transfer_mails').text(email_lang.ID_MAIL_TRANSFER);
$('.delete_to_trash').text(lw_lang.ID_DELETE);
$('.refresh_mails').text(email_lang.ID_MAIL_REFRESH);
$('.restore_mail').text(email_lang.ID_MAIL_RESTORE_INBOX);
$('.delete_forever').text(email_lang.ID_MAIL_DELETE_FOREVER);
$('.add_cc').text(email_lang.ID_MAIL_ADD_CC);
$('.add_bcc').text(email_lang.ID_MAIL_ADD_BCC);
$('.send_btn').text(lw_lang.ID_IM_SEND_MSG);
$('.sender').text(lw_lang.ID_MAIL_SENDER);
$('.receiver').text(lw_lang.ID_MAIL_RECEIVER);
$('.writemail_top .cc').text(email_lang.ID_MAIL_CC);
$('.writemail_top .subject_name').text(email_lang.ID_MAIL_SUBJECT);
$('.upload_attachment').text(email_lang.ID_MAIL_ATTACH_CHOOSE);
//$('.send_payload').text(email_lang.ID_MAIL_INPUT_MAIL_CONTENT);
$('.upload_attachment').text(email_lang.ID_MAIL_ATTACH_CHOOSE);
