var send_email_no=1;
var loading_hint_default=lw_lang.ID_LOADING;
var reply_logo=lw_lang.ID_REPLY;
var transfer_log=email_lang.ID_MAIL_TRANSFER;
var DRAFT_LOG="draft";
var FAKE_NEW_MAIL_FOLDER='send_email';
var last_folder_tab;
var MINUTE_ = 60*1000;
var INTERVAL_LEN=10*MINUTE_;

function gen_send_mail_no() {
	send_email_no = send_email_no+1
	return send_email_no;
}

function show_write_emails(container,params) {
	var name =params['sender'][0]
	var sender_addr = params['sender'][1]
	container.find('.sender_name').text(name);
	container.find('.sender_addr').text('<'+sender_addr+'>');
}

function transfer_header_dom(subject, sender, date, receiver){
	return ['<br /><pre> ------------------------------- source mail --------------------------------',
	' subject:    '+subject,
	' sender:  '+sender,
	' date:    '+date,
	' receiver: '+receiver,
	' --------------------------------------------------------------------------</pre>'
	].join('\r\n\r\n')	
}
var ueditor_readyed=false;
function mail_details(dom){
	var sender = '', receiver='', subject='',date='',copy_to='';
	if(dom) {
		receiver=dom.find('.receiver').text();
		copy_to=dom.find('.copy_to').text();
		sender=dom.find('.sender').text();
		subject=dom.find('.subject').text();
		date=dom.find('.date').text();

	}
	var src={'From':sender, 'To':receiver, 'Subject':subject,'Date':date, 'Body':dom.find('.mailText').html(),'Cc':copy_to };
	return src;
}

function get_tab(contain){
	var label=contain.attr('id');
	return $('.mail_tabs').find('.'+label);
}
function set_tab_closable(tab, flag) {
	tab.find('.close').attr('closable',flag);
}
function receiver_addr_control(container) {
	return $('#'+container.find('.receiver_addr').attr('id')+'_tag');
}
function receiver_addr_cc_control(container) {
	return $('#'+container.find('.receiver_addr_cc').attr('id')+'_tag');
}
function is_draft(opts) {return opts&& opts['draft']; }
function do_show_write_email(container,src_infos,options,editor) {
	var sender=Email_Client.acc;
	var receiver = src_infos&&src_infos['From'] ||'';
	var to = src_infos&&src_infos['To'] || '';
	var cc=src_infos&&src_infos['Cc'] ||'';
	var operator=src_infos&&src_infos['operator']||'';
	var sep= operator ? ': ' :'';
	var subject=operator+sep+(src_infos&&src_infos['Subject'] || '');
	var date=src_infos&&src_infos['Date'] || '';
	var body=src_infos&&src_infos['Body']||'';
	var body_dom=$('<div></div>').html(body);
	var attach_dom=body_dom.find('.pagecontent_attachment').remove();
	var receiver_control = receiver_addr_control(container);
	var receiver_cc_control =receiver_addr_cc_control(container);

	container.find('.sender_addr').text(sender);
	if(operator==reply_logo) {
		var rcvs = (options && options['all'])? receiver+';'+cc+';'+to : receiver;
		receiver_control.val(rcvs);
		receiver_control.focus().blur();
	}

	if(is_draft(options)) {
		receiver_control.val(to);
		receiver_control.focus().blur();
		if(cc) {
			container.find('.add_cc').click();
			receiver_cc_control.val(cc);
			receiver_cc_control.focus().blur();
		}
	}
	container.find('.subject').val(subject);
	function setContent() {
		editor.setContent(transfer_header_dom(subject, sender, date, receiver)+'<pre>'+body_dom.html()+'</pre>');
	}
	function editor_changed(){
		set_tab_closable(get_tab(container),'false');
	}
	editor.addListener('keyup', editor_changed);
	with_src=options && options['with_src'];
	if(with_src&&src_infos){
		if(ueditor_readyed) {
			setContent();
		}else {
			editor.addListener('ready', setContent);
			ueditor_readyed=true;
		}
	}
}

function update_send_email_header(detail) {

}
function update_send_email_body(editor, body, tab_name) {
	var o=editor.getContent();
	var content = tab_name == DRAFT_LOG ? body : o+body;
	editor.setContent(content);
}

function send_mail_json_paras(container,editor) {
	var account=Email_Client.acc;   
	var recv=container.find('.receiver_addr').attr('data');
	var cc=container.find('.receiver_addr_cc').attr('data');
	var bcc=container.find('.receiver_addr_bcc').attr('data');
	var subj=container.find('.subject').val()
	var text=editor.getContent();
	var fid_doms=container.find('.success')
	var fids=[]
	fid_doms.each(function(){ fids.push($(this).attr('data'));})
	return {uuid:top.uuid,account:account, pwd:Email_Client.pwd,addr:Email_Client.smtp,receiver:recv,cc:cc,
			bcc:bcc,subject:subj,text:text,attachments:fids, sent_folder:Email_Client.sent_folder };
}

function save_mail_json_paras(container,editor) {
	var recv=container.find('.receiver_addr').attr('data');
	var cc=container.find('.receiver_addr_cc').attr('data');
	var bcc=container.find('.receiver_addr_bcc').attr('data');
	var subj=container.find('.subject').val()
	var text=editor.getContent();
	var fid_doms=container.find('.success')
	var fids=[]
	fid_doms.each(function(){ fids.push($(this).attr('data'));})
	return {uuid:top.uuid,receiver:recv,cc:cc,bcc:bcc,subject:subj,text:text,attachments:fids};
}

function do_send_email(container,editor, options) {
//	post /mail/send?uuid=uuid
//		{uuid:uuid,account:account, pwd:pwd, receiver:receiver, subject:subject, text:text, attachements:attachments}     
	var url='/mail/send?uuid='+top.uuid;

	RestChannel.post(url, send_mail_json_paras(container,editor),
						function(e) {
							msg_box(lw_lang.ID_MAIL_SENT_SUCCESS,true);
							$('.'+container.attr('id')).find('.close').attr('closable','true').click();
							loading_hide();
						},
						function(e) {
							var info=(e.reason && e.reason.toString()) || e.toString();
							msg_box(lw_lang.ID_MAIL_SENT_FAIL_REASON+info,false,5000);
							loading_hide();
						});
	loading_hint(lw_lang.ID_MAIL_SENDING,0);

}
function modify_tab_width() {
	var tabWidth = $('.mail_tabs').width();
	var curTabWidth = parseInt($('.mail_tabs').width());
	var tabLength = parseInt($('.mail_tabs').find('.tabI').length);
	var conLen =  Math.floor(curTabWidth/100) 
	if(tabLength>conLen){
		$('.mail_tabs').find('.tabI').width(Math.floor((curTabWidth - tabLength*25)/tabLength))
	}

}

function editor_name(fake_uid) {return 'ueditor'+fake_uid;}
function new_sendmail(src,options){
	var fake_folder = (src && src.folder) || FAKE_NEW_MAIL_FOLDER;
	var fake_uid = (src && src.Uid) || gen_send_mail_no();

	function fill_subcontainer() {
		var container = $('#subContainer');
		var obj=$('#write_emails_container').clone().appendTo(container).attr('id', gen_email_tab(fake_folder,fake_uid));
		obj.find('.send_payload').attr('id', editor_name(fake_uid)).live('keyup', function(){
			console.log('adfafasff');
		});
		function sendmail_to_id() {return 'sendmail_obj_'+fake_uid;}
		var rcv_addr_obj=obj.find('.receiver_addr').attr('id', sendmail_to_id());
		function sendmail_cc_id() {return 'sendmail_obj_cc_'+fake_uid;}
		var rcv_cc_obj=obj.find('.receiver_addr_cc').attr('id', sendmail_cc_id());
		function sendmail_bcc_id() {return 'sendmail_obj_bcc_'+fake_uid;}
		var rcv_bcc_obj=obj.find('.receiver_addr_bcc').attr('id', sendmail_bcc_id());
		function ueditor_func() {
		    var editor = new UE.ui.Editor();
		    editor.render(editor_name(fake_uid));
		    return editor;
		}
		function bind_search_and_member_div() {
			rcv_addr_obj.tagsInput({'width':'auto',	'type':'email',	'delimiter':';','height':'30px' ,
				'delimiter':';','getuuid': 'no', 'defaultText':lw_lang.ID_MAIL_RECEIVER_TIP
			});
			$('#'+rcv_addr_obj.attr('id')+'_tag').membersearch({
			    target: obj, isgroup: 'no',	from:'sendMail', symbol: ';'
			});
			rcv_cc_obj.tagsInput({'width':'auto',	'type':'email',	'delimiter':';','height':'30px' ,
				'delimiter':';','getuuid': 'no', 'defaultText':lw_lang.ID_MAIL_RECEIVER_TIP
			});
			$('#'+rcv_cc_obj.attr('id')+'_tag').membersearch({
			    target: obj, isgroup: 'no',	from:'sendMail', symbol: ';'
			});
			rcv_bcc_obj.tagsInput({'width':'auto',	'type':'email',	'delimiter':';','height':'30px' ,
				'delimiter':';','getuuid': 'no', 'defaultText':lw_lang.ID_MAIL_RECEIVER_TIP
			});
			$('#'+rcv_bcc_obj.attr('id')+'_tag').membersearch({
			    target: obj, isgroup: 'no',	from:'sendMail', symbol: ';'
			});
		}
		bind_search_and_member_div();
		var editor=ueditor_func();

		function is_attachment_uploading(){
			return obj.find('.uping').length >0 || obj.find('.dealing').length;
		}
		obj.find('.send_btn').unbind('click').click(function() {
			if (is_attachment_uploading()) {
				pageTips(obj.find('.stb'), lw_lang.ID_MAIL_ATTACH_UPLOADING);
			}else if(obj.find('.receiver_addr').attr('data').split(';').join('') ||
				obj.find('.receiver_addr_cc').attr('data').split(';').join('') ||
				obj.find('.receiver_addr_bcc').attr('data').split(';').join('') ){
				do_send_email(obj, editor, options);
			}else{
				msg_box(lw_lang.ID_MAIL_NO_RECEIVER,false);
			}
		});
		obj.find('.add_cc').unbind('click').click(function() {
			var _this=$(this);
			if(_this.attr('show')=='true') {
				obj.find('.ccs').hide().find('.tag').remove();
				obj.find('.receiver_addr_cc').attr('data','').val('');
				_this.text(email_lang.ID_MAIL_ADD_CC).attr('show', 'false');

			}else {
				obj.find('.ccs').show();
				_this.text(email_lang.ID_MAIL_DEL_CC).attr('show','true');
			}
		});
		obj.find('.add_bcc').unbind('click').click(function() {
			var _this=$(this);
			if(_this.attr('show')=='true') {
				obj.find('.bccs').hide().find('.tag').remove();
				obj.find('.receiver_addr_bcc').attr('data','').val('');
				_this.text(email_lang.ID_MAIL_ADD_BCC).attr('show', 'false');
			}else {
				obj.find('.bccs').show();
				_this.text(email_lang.ID_MAIL_DEL_BCC).attr('show','true');
			}
		});

		obj.find('.wm_input').change(function(){
			set_tab_closable(get_tab(obj), 'false');
		});
		obj.find('input').change(function(){
			set_tab_closable(get_tab(obj),'false');
		});
		//ready_for_upload(obj);
		do_show_write_email(obj, src,options,editor);
		return editor;
	}
	var editor=fill_subcontainer();
//	src['editor'] = editor;
	var tab = insert_mail_tab(fake_folder,fake_uid,lw_lang.ID_MAIL_NEW, src);
	tab.click();
	return editor;
}

function show_tab_item(_this){
	$('.mail_tabs').find('.tabI').removeClass('current');
	$('.nui-menu').find('a').removeClass('active');	
	$('.nui-menu').find('.subMenu_' + _this.attr('link')).addClass('active');	
	$('.nui-menu').hide();	
	_this.addClass('current');
	var obj = $('#'+_this.attr('link'));
	obj.show().siblings().hide();
}
function tabswitch(){
	var _this = $(this);
	show_tab_item(_this);
	if(_this.attr('folder_id')) {
		if(!Email_Client.isGettingFolder[_this.attr('folder_id')])
		    Email_Client.get_folder_list(top.uuid,_this,undefined, undefined);
		last_folder_tab = _this;
	}
//	tab_show_manager.push(_this);
}
function tab_bind_handler(tab) {
	var tabs = tab ? tab : $('#container').find('.th a.tabI');
	tabs.unbind('click').bind('click', tabswitch);
	var closable_tabs=$('#container .mail_tabs').find('.close');
	closable_tabs.unbind('click').bind('click',function(e) {
		var _this=$(this);
		var tab =_this.parent();
		var link=tab.attr('link');
		var container = $('#'+link);
		function do_close(){
			$('.nui-menu').find('.subMenu_' + link).remove();
			container.remove();
			tab.remove();
			if(last_folder_tab){
				show_tab_item(last_folder_tab);
			}else{
				$('.mail_tabs').find('.inbox').click();
			}
		}
		function save2draft() {//['uuid','uid','src_folder','receiver','subject','text','attachments','cc','bcc','draft_folder']
			var folder=tab.attr('folder');
			if(folder==FAKE_NEW_MAIL_FOLDER) folder='';
			var uid = tab.attr('uid');
			var editor = UE.getEditor(editor_name(uid));
			var params=save_mail_json_paras(container,editor);
			params['uid']=uid;
			params['src_folder'] = folder;
			params['draft_folder']=Email_Client.draft_folder;
			var url="/mail/save";
			RestChannel.post(url, params, function(data) {
				if(folder) {
					delete_or_move_mails(folder, folder,uid,function() {
									Email_Client.draft_tab.click();
									do_close();
								});
				} else {
					Email_Client.draft_tab.click();
					do_close();
				}
			}, function(e){
			});
		}
		function query_close(){
			var dialog = art.dialog({
				title: lw_lang.ID_MAIL_CLOSE_NEW,
				content: '<span style="line-height:20px; font-size: 13px;">' + lw_lang.ID_MAIL_CLOSE_NEW_TIP  + '</span>' ,
				width: '400px',
				button: [{
				  name: lw_lang.ID_OK,
				  callback: function () {
				  		save2draft();
					},
					focus: true
				},{
				  name: lw_lang.ID_CANCEL,
				  callback: do_close
				}]
			});	
		}
		(_this.attr('closable')=='false') ? query_close() : do_close();
	})

	$('.nui-menu').find('a').unbind('click').bind('click', function(){
		var action = $(this).attr('action');
		if(action === 'emailsetup'){
			$('#MailSetUp').show().siblings().hide();
		}else{
			$('.mail_tabs').parent().find('.' + action).click(); 			
		}
		$(this).parent().hide();
		return false;
	})
}

tab_bind_handler();
$('.more_icon').click(function(){
    $(this).next().show();	
})

function Adjust_EmailList_Height() {
	$('.emailList').height(parseInt($('#email', parent.document).height())-110);
}
Adjust_EmailList_Height()
window.onresize=Adjust_EmailList_Height;

function email_tab_dom(folder, uid, subject) {
	//var title='阅读邮件:'+subject.substr(0,6)
	return ['<a href="###" class="'+gen_email_tab(folder, uid)+' pr tabI" ',
		'link="'+gen_email_tab(folder, uid)+'" ',
		'folder="'+folder+'" ',
		'uid="'+uid+'"',
		'>'+subject+'<span class="close"> </span></a>'].join(' ');
}

function email_submenu_dom(folder, uid, subject) {
	//var title='阅读邮件:'+subject.substr(0,6)
	return '<a href="###" class="subMenu_'+ gen_email_tab(folder, uid) +'" action="'+gen_email_tab(folder, uid)+'">'+subject+'</a>'
}


var unicode_ = function(str) {
    var res=[];
    for(var i=0;i < str.length;i++)
        res[i]=("00"+str.charCodeAt(i).toString(16)).slice(-4);
    return "\\u"+res.join("\\u");
}

function gen_email_tab(folder, uid){
	return (unicode_(folder).replace(/\\/g, "")+'_'+uid).replace('.', '_');
}
function get_mail_opt_con_dom(tab_link) {
	var result = '';
	var mail_opt_dom= '<a href="###" class="reply_mail">'+lw_lang.ID_REPLY+'</a> <a href="###" class="reply_mail_with_src">'+lw_lang.ID_REPLY+'('+lw_lang.ID_WITH_SRC+')</a> <a href="###" class="replyall_mail">'+lw_lang.ID_REPLYALL+'</a> <a href="###" class="replyall_mail_with_src">'+lw_lang.ID_REPLYALL+'('+lw_lang.ID_WITH_SRC+')</a> <a href="###" class="trasfer_mail">'+transfer_log+'</a> <a href="###" class="delete_mail">'+lw_lang.ID_DELETE+'</a>';
	var maps = {
		'inbox_container':' <div class="email_opt_con"> '+mail_opt_dom+'  </div>',
		'draft_container':' <div class="email_opt_con"> <a href="###" class="send_mail">'+lw_lang.ID_IM_SEND_MSG+'</a>',// <a href="###" class="save_mail">保存草稿</a> <a href="###" class="delete_mail">删除</a>  </div>',
		'sent_container':' <div class="email_opt_con"> '+mail_opt_dom+'  </div>',
		'trash_container':' <div class="email_opt_con"> '+mail_opt_dom+'  </div>'
	};
	return maps[tab_link] || result;
}
function address_string(address){  //[[name, addr],...]
	if(!address){
		return '';
	}else if(typeof(address) == 'string'){
		return address;
	}else{
		var address_no_name= address.map(function(i){return i[1]});
		return address_no_name.join(';');
	}
}
function email_content_dom(folder,uid,from,to,subject,date,body,cc,bcc) {
	var tab_link=$('#container .mail_tabs').find('.current').attr('link');
	var email_opt_dom=get_mail_opt_con_dom(tab_link);
	var id=gen_email_tab(folder, uid);
	var cc_dom=function(cc){
		if (cc){
			return ['<li class="fS dZ">',
					  '<div class="fT">'+lw_lang.ID_MAIL_CC+':</div>',
					  '<div class="fU">',
					    '<div class=""><span class="nui-addr-name">'+'</span><span class="nui-addr-email copy_to">'+address_string(cc)+'</span></div>',
					  '</div>',
					'</li>'
					].join('');
		}else{
			return '';
		}
		
	}
	var bcc_dom=function(bcc){
		if (bcc){
			return ['<li class="fS dZ">',
					  '<div class="fT">'+lw_lang.ID_MAIL_BCC+':</div>',
					  '<div class="fU">',
					    '<div class=""><span class="nui-addr-name">'+'</span><span class="nui-addr-email copy_to">'+address_string(bcc)+'</span></div>',
					  '</div>',
					'</li>'
					].join('');
		}else{
			return '';
		}
		
	}
	return ['<div id="'+id+'"'+' folder="'+folder+'" '+' uid="'+uid+'">',
	  '<div class="email_opt">',
	   email_opt_dom,
	  '</div>',
	  '<div class="readmailist">',
	    '<div class="mail_top">',
	      '<h1 class="nui-fIBlock lv subject" tabindex="0" title="邮件标题" hidefocus="hidefocus">'+subject+'</h1>',
	      '<ul>',
	        '<li class="fS dj">',
	          '<div class="fT">'+lw_lang.ID_MAIL_SENDER+':</div>',
	          '<div class="fU">',
	            '<div class="js-component-addr nui-addr nui-addr-hasAdd"><span class="nui-addr-name">'+'</span><span class="nui-addr-email sender">'+address_string(from)+'</span></div>',
	          '</div>',
	        '</li>',
	        '<li class="fS dZ">',
	          '<div class="fT">'+lw_lang.ID_MAIL_RECEIVER+':</div>',
	          '<div class="fU">',
	            '<div class=""><span class="nui-addr-name">'+'</span><span class="nui-addr-email receiver">'+address_string(to)+'</span></div>',
	          '</div>',
	        '</li>',
	        cc_dom(cc),
	        bcc_dom(bcc),
	        '<li class="fS dk">',
	          '<div class="fT">'+lw_lang.ID_SEND_TIME+'：</div>',
	          '<div class="fU date">'+get_mail_date(date)+'</div>',
	        '</li>',
	      '</ul>',
	    '</div>',
	    decorate_body(body),
	  '</div>',
	'</div>'].join('')
}
function get_mail_date(imap_date) {
	var date = new Date(imap_date)
	return date.format("yyyy/MM/dd hh:mm");
}

function mail_list_item_dom(item, haveseen) {
	var size=item['Size']
	var classname = (item['Flags'] && item['Flags'].search('\\Seen') !=-1) ? '' : 'unread';
	var png = haveseen ? "readed.png" : unread.png;
	var maisize = getfilesize(item['Size'])
	var attach_url= item['has_attach']=='True'? '<span class="attachment_tag"></span>' : '';
    return ['<dl class="mail ',classname,'" uid="',item['Uid'], '" to=','"',item['To'],'" ','cc=','"',item['Cc'],'"' ,'bcc=','"',item['Bcc'],'"' ,'>',
                '<dd><span class="checkBox"><input type="checkbox"/></span>',
                '<span class="readStatus"><img src="images/',png,'" width="14" height="12" /></span>',
                '<span class="from" title="'+ item['From'] +'">', item['From'], '</span>',
                '<span class="subject" title="'+ item['Subject'] +'">',attach_url, item['Subject'], '</span>',		
				'<span class="mailSize" title="'+maisize +'">', maisize, '</span>',						
                '<span class="mailTime">', get_mail_date(item['Date']), '</span></dd>',

              '</dl>'].join('')
}
function email_body_deal(bodys,folder,UUID,uid) {
	var result = ""
    var html = ['<div class="pagecontent_attachment">',
	            '<div class="attachment_header">'+lw_lang.ID_ATTACHED+'</div><ul>'].join('');				
	var isContainAttachment = function (){
		for (var i in bodys){
			if(bodys[i]['type'] == 'attachname') return true;
		}
		return false;
	}				
	for (var i in bodys) {
		var part = bodys[i]
		if(part['type']=='text') result+=part['payload'];
		if(part['type']=='attachname') {
			var href = ['/mail/open_file/'+part['payload']+'?filename='+part['payload'],
						'&uuid='+UUID,'&section_no='+part['no'],'&folder='+folder,
						'&uid='+uid
						].join('')
	          html += ['<li class="attachment_content"  section_no="'+part['no']+'" ><div class="attachment docx"><span>'+part['payload']+'</span></div><div class="download_attachment">',
	          	                   '<a class="" target="_blank"  href="'+href+'" >'+lw_lang.ID_DOWNLOAD+'</a>'].join('');	
		}
	}
	return result + (isContainAttachment() ? html+'</ul></div>' : '');
}
function check_unseen_mail_items(email_list_table,folder_id, UUID) {
	if (folder_id !='INBOX') return;
	var url = '/mail/unseen_uids';
	RestChannel.get(url, {foler:folder_id, uuid:UUID}, function(data){
		var uids = data.uids;
		for (var i=0; i<uids.length;i++) {
			email_list_table.find('dl[uid='+uids[i]+']').addClass('unread');
		}
	})
}

function insert_mail_tab(folder, uid, subject, src_infos) {
	var date = src_infos && src_infos['Date'];
	subject = subject.trim()||get_mail_date(date);
	var new_tab_dom = email_tab_dom(folder, uid, subject);
	var new_submenu_dom = email_submenu_dom(folder, uid, subject);
	var mail_tab=$(new_tab_dom).appendTo($('.mail_tabs').find('.volatile_tablist'));
//	$('.mail_tabs').find('.volatile_tablist').append(new_tab_dom);
	$('.mail_tabs').find('.nui-menu').append(new_submenu_dom);
	modify_tab_width();
	tab_bind_handler(mail_tab);
	return $('.mail_tabs').find('.'+gen_email_tab(folder, uid));
}

function gen_email_content(folder,uid,from,to,subject,date,body,cc,bcc) {
	var mail_content = $(email_content_dom(folder,uid,from,to,subject,date,body,cc,bcc)).appendTo($('#subContainer'));
	mail_content_bind(mail_content);
	return mail_content;
}
function update_email_content(dom, to, body) {
	dom.find('.receiver').text(to);
	dom.find('.mailText').append(body);
}
function hunt_mail_details(folder, uid, UUID, func){
	var url = '/mail/detail';
	RestChannel.get(url, {folder:folder, uid:uid, uuid:UUID},
		function(data){
			var detail=data['detail'];
			detail['Body'] = email_body_deal(detail['Body'],folder,UUID,uid);
			detail['To']=address_string(detail['To']);
			detail['From']=address_string(detail['From']);
			detail['Cc']=address_string(detail['Cc']);
			detail['Bcc']=address_string(detail['Bcc']);
			if(func) func(detail);
			loading_hide();
		},
		function(e) {
			loading_hide();
			msg_box(lw_lang.ID_MAIL_LOADING_MAIL_FAILED,false);
	});
	loading_hint(lw_lang.ID_MAIL_LOADING);

}
function get_mailitem_infos(item){
	var _this=item;
	var uid = _this.attr('uid')
	var subject = _this.find('.subject').text();
	var date = _this.find('.mailTime').text();
	var from = _this.find('.from').text();
	var to=_this.attr('to')||'';
	var cc=_this.attr('cc') ||'';
	var bcc=_this.attr('bcc') ||'';
	return {Uid:uid, 'Subject':subject, 'Date':date, From:from,To:to,Cc:cc,Bcc:bcc};
}
function bind_mail_list_item(email_list_table,folder, UUID) {
	email_list_table.find('dl').unbind('click').click( function(e) {
		if(e.target.tagName=='INPUT') {	return;	}

		var _this=$(this);
		var infos=get_mailitem_infos(_this);
		var mail_tab=$('.mail_tabs').find('.'+gen_email_tab(folder, infos.Uid))
		if (mail_tab.length == 0 ) {
			function draft_items_bind() {
				mail_infos=infos;
				mail_infos['folder'] = folder;
				var editor = new_sendmail(mail_infos,{draft:true});
				hunt_mail_details(folder, mail_infos.Uid, top.uuid, function(detail){
					update_send_email_header(detail);
					update_send_email_body(editor, decorate_body(detail.Body), DRAFT_LOG);
				});
			}

			function other_bind() {
				mail_tab=insert_mail_tab(folder, infos.Uid, infos.Subject, infos);
				var mail_content_dom=gen_email_content(folder,infos.Uid,infos.From,infos.To,infos.Subject,infos.Date,'',infos.Cc);
				mail_tab.click();
				hunt_mail_details(folder, infos.Uid, UUID, function(detail){
					_this.removeClass('unread');
					update_email_content(mail_content_dom, detail['To'], detail['Body']);			
				});
			}
			get_current_tab().attr('link') == 'draft_container' ? draft_items_bind() : other_bind();
//			other_bind();
		}
		mail_tab.click();
	})
	
	var allow_loading = 0;
	email_list_table.unbind('scroll').bind("scroll", function (event){
	    var top = document.documentElement.scrollTop + document.body.scrollTop;	
	    var textheight = $(document).height();	
	    if(textheight - top - $(window).height() <= 100) { if (allow_loading >= 1) { return; }
	      allow_loading++;
	    }
	});
}

function create_replymail(obj){
	var infos=mail_details(obj);
	infos['operator']=reply_logo;
	new_sendmail(infos);
}

function create_replymail_with_src(obj){
	var infos=mail_details(obj);
	infos['operator']=reply_logo;
	var options={with_src:true};
	new_sendmail(infos,options);
}
function createall_replymail(obj){
	var infos=mail_details(obj);
	infos['operator']=reply_logo;
	var options={all:true};
	new_sendmail(infos,options);
}

function createall_replymail_with_src(obj){
	var infos=mail_details(obj);
	infos['operator']=reply_logo;
	var options={with_src:true,all:true};
	new_sendmail(infos,options);
}
function create_transfermail(obj){
	var infos=mail_details(obj);
	infos['operator']=transfer_log;
	new_sendmail(infos,true);
}

function delete_opened_mail(obj){
	delete_notrash_mails(obj.attr('folder'), obj.attr('uid'), function(){
		$('.mail_tabs').find('.'+obj.attr('id')).find('.close').click();
		msg_box(lw_lang.ID_DELETE_SUCCESS,true);
	})
}

function delete_or_move_mails(src_folder, dest_folder,uids, other_action){
	var trash_folder = $('.mail_tabs .trash').attr('folder_id');
	var url='/mail';
	RestChannel.del(url, {uuid:top.uuid, uids:uids, folder:src_folder, dest:dest_folder}, 
	function(data){
		loading_hide();
		var link=email_frame.get('.mail_tabs').find('.tabI[folder_id="'+src_folder+'"]').attr('link');
		var src_list_container=$('#'+link);
		var uid_list=uids.split(',');
		for(var i=0; i< uid_list.length; i++) src_list_container.find('.mail[uid="'+uid_list[i]+'"]').remove();
		if(other_action) other_action();
	},
	function(){
		loading_hide();
//		msg_box(fail_name+'失败',false);
	});
	loading_hint();
}
function delete_notrash_mails(src_folder, uids, other_action){
	var dest_folder=$('.mail_tabs').find('.trash').attr('folder_id');
	delete_or_move_mails(src_folder, dest_folder, uids, other_action);
}

function mail_content_bind(obj) {
	obj.find('.reply_mail').click(function(){
		create_replymail(obj);
	});
	obj.find('.reply_mail_with_src').click(function(){
		create_replymail_with_src(obj);
	});

	obj.find('.replyall_mail').click(function(){
		createall_replymail(obj);
	});
	obj.find('.replyall_mail_with_src').click(function(){
		createall_replymail_with_src(obj);
	});

	obj.find('.trasfer_mail').click(function(){
		create_transfermail(obj);
	})
	obj.find('.delete_mail').click(function(){
		delete_opened_mail(obj);
	})
}
function email_client() {
	this.status = 'not_login';  //not_login, logined
	this.isGettingFolder={};
	this.get_folder_list=function (UUID, tab_obj, suc_cb, fail_cb, hint) {
		var from_uid = tab_obj.attr('max_uid');
		var folder_id = tab_obj.attr('folder_id');
		var url = '/mail/folder_items';
		RestChannel.get(url, {folder:folder_id, from_uid:from_uid, uuid:UUID},
			function(data) {
				this.isGettingFolder[folder_id]=false;
				if(hint) loading_hide();
				var items = data.items;
				if (items.length==0) {
					//top.LWORK.msgbox.show('没有新邮件', 1, 1000);
					return;
				}
				var mailItems = []
				var max_uid = tab_obj.attr('max_uid') ? Number(tab_obj.attr('max_uid')) : 1;
				var newitems=items.filter(function(item){return Number(item['Uid'])>=max_uid;});
				for (var i =0; i<newitems.length;i++) {
					var uid = Number(items[i]['Uid']);
					mailItems.push(mail_list_item_dom(items[i],true) )
				    max_uid = Number(uid)+1;
				}
				tab_obj.attr('max_uid', max_uid);
				var email_list_table = $('#'+tab_obj.attr('link')+' .email_list');
				email_list_table.prepend(mailItems.reverse().join(''))
				bind_mail_list_item(email_list_table, folder_id,UUID);
				newitems.length>0 && suc_cb && suc_cb(data);
//				check_unseen_mail_items(email_list_table,folder_id, UUID);
			}, 
			function(e){
				this.isGettingFolder[folder_id]=false;
				if(hint) loading_hide();
				fail_cb && fail_cb(e);
				if(e && e.reason =='not_login') {
					this.login(this.acc, this.pwd,this.imap,this.smtp);
				}
			});
		if(hint) loading_hint(lw_lang.ID_MAIL_FETCH_LIST);
		this.isGettingFolder[folder_id]=true;
	}
	this.load_interval= function () {		
        var origin=this.inbox_tab.attr('max_uid');
        function success_func(data){
        	var newitems=data.items.filter(function(item){return item.Flags.indexOf('\\Seen') == -1;});
        	top.loadContent.dynamic_msgnum('email', newitems.length);
        	this.Interval_time =0;
        }
        function fail_cb(e){
			if(this.Interval_time>=4){
			   clearInterval(this.time);
			   this.Interval_time = 0;
			}
			this.Interval_time++;
        }
        this.get_folder_list(top.uuid,this.inbox_tab, success_func, fail_cb);
    };

	this.loginedHandler = function(folders) {
		this.inbox_folder=inbox_id = folders['inbox']
		this.sent_folder=sent_id = folders['sent']
		this.draft_folder=draft_id = folders['draft']
		this.trash_folder=trash_id = folders['trash']
		this.inbox_tab=$('#container .inbox').attr('folder_id', inbox_id);
		this.sent_tab=$('#container .sent').attr('folder_id', sent_id);
		this.draft_tab=$('#container .draft').attr('folder_id', draft_id);
		this.trash_tab=$('#container .trash').attr('folder_id', trash_id);
		$('#container').find('.th a').attr('max_uid', '1')

		$('#inbox_container .email_list').children().remove();
		$('#sent_container .email_list').children().remove();
		$('#trash_container .email_list').children().remove();

		Email_Client.get_folder_list(top.uuid,this.inbox_tab,undefined, undefined,true);
		this.time = setInterval(this.load_interval, INTERVAL_LEN);
		this.Interval_time =0;
	}
	this.login=function (acc,pwd,imap,smtp) {
		var url = '/mail/login?uuid='+top.uuid;
		RestChannel.post(url, {uuid:top.uuid,account:acc,pwd:pwd,addr:imap}, 
		function(data){
			loading_hide();
			this.loginedHandler(data);
			this.acc=acc;
			this.pwd=pwd;
			this.imap=imap;
			this.smtp = smtp;
			this.status = 'logined';
			$.cookie('mail_addr',acc||$.cookie('mail_addr'), {expires: 30});
			$.cookie('mail_pwd',pwd||$.cookie('mail_pwd'), {expires: 30});
			$.cookie('mail_imap_addr',imap, {expires: 30});
			$.cookie('mail_smtp_addr',$('.smtp_addr').val(), {expires: 30});
			$('#MailSetUp').hide().next().show();
			top.LWORK.msgbox.show(lw_lang.ID_MAIL_LOGIN_SUCCESS, 1, 1000);
		},function(){
			loading_hide();
			top.LWORK.msgbox.show(lw_lang.ID_MAIL_LOGIN_FAIL, 1, 2000);
		})
		loading_hint(lw_lang.ID_MAIL_LOGINING);
	}
	return this
}
Email_Client = email_client()
var my_totips =  {	
	showtip: function(obj, html ,top , left, Direction , id_conner){	
		var id ;
		id_conner ? id =  'floattips' +  id_conner :( id =  'floattips' , $('#floattips').remove());
		var floattips = ['<div id="'+id+'">',
				'<div class="close"><a href="###" class="del">×</a></div>',
				'<div class="floatCorner_top" style=""><span class="corner corner_1">◆</span><span  class="corner corner_2">◆</span></div>',
				'<div class="totips"></div>',
				'</div>'].join("");
			$('body').append(floattips);
			var obj_container = $('#' + id);					
			var offset, top, left, tipswidth, css = "" , addleft, addtop;			
			offset = obj.offset() ;
			obj_container.find('.totips').html(html);			
			tipswidth =obj_container.width();			
			switch(Direction){
			 case 'down':
			    css = "float_corner2" ;
				addtop = top ;
				addleft = tipswidth + left ;
			    break;
			 case 'top':
			    css = "float_corner4";
				addtop = top ;
				addleft =  tipswidth - left;			 
			    break;
			 case 'left':
			    css = "float_corner3  float_corner5";
				addtop = top ;
				addleft =  tipswidth - left;	 
			    break;
			 default:
			    css = "float_corner3";
				addtop = top ;
				addleft =  tipswidth - left;
			}								
			obj.length > 0 ? top = parseInt(offset.top, 10) + addtop : top = 123;
			obj.length > 0 ? left = parseInt(offset.left, 10) - addleft : left = 50;
			obj_container.css({ top: top + 'px', left: left + 'px'}).show();			
			obj_container.find('.floatCorner_top').removeClass('float_corner2 float_corner3 float_corner4').addClass(css);			
			obj_container.find('.del').die('click').live('click', function(){totips.hidetips(id_conner)});
	},
	hidetips: function(id_conner){
			var id_1 =  id_conner ?  'floattips' +  id_conner : 'floattips';
	        $('#' + id_1).html('').remove();		 
	}
};




/*邮箱设置*/
var mail_serveraddr_map = {
	'livecom.hk': ['121.14.57.152','121.14.57.152'],
	'gmail.com': ['173.194.74.109', '74.125.134.108'],
	'':''
};
function set_server_addr(mail){
	$('.imap_addr').val(get_imap_addr(mail));
	$('.smtp_addr').val(get_smtp_addr(mail));
}
function start_login(){
    var obj = $('#MailSetUp');
	var mail=obj.find('.mail_addr').val();
	var pwd=obj.find('.mail_pwd').val() ;
	var imap=obj.find('.imap_addr').val();
	var smtp=obj.find('.smtp_addr').val();
	pwd=pwd && Base64.encode(pwd) || $.cookie('mail_pwd');
	Email_Client.login(mail,pwd, imap, smtp);
}

function get_current_tab() {
	return $('.mail_tabs .current');
}

(function(){
    $('.nui-menu').bind('mouseleave', function(){$(this).hide();});		

	$('.writemailBtn').unbind('click').bind('click', function() {new_sendmail()});
	var inbox_tab=$('.mail_tabs').find('.inbox');
    var obj = $('#MailSetUp');
	obj.find('.submit_setmail').click(function(){
		obj.find('input').each(function(){
			var _this =$(this);
			if('' === _this.val()){
			  _this.next().show();
			  _this.focus();
			  return false;	
			}
		})
		start_login();
	})
	
	obj.find('.cancel_setmail').click(function(){
		if (Email_Client.status=='logined') {
			$('#MailSetUp').hide().next().show();
		}
		else {
			top.LWORK.msgbox.show(lw_lang.ID_MAIL_SET_TIP, 1, 2000);
		}
	})
	obj.find('input').keyup(function(){
	    $(this).next().hide();	
	})
	obj.find('.mail_addr').blur(function(){
		set_server_addr($(this).val());
	}).siblings().blur(function(){
		var _this =$(this);
	    if('' === _this.val()){
			  _this.next().show();
			  return false;	
		}
	});
	obj.find('.mail_addr').val($.cookie('mail_addr') || my_mail_addr());
	var pwd = $.cookie('mail_pwd') ? Base64.decode($.cookie('mail_pwd')) : '';
	obj.find('.mail_pwd').val(pwd);
//	obj.find('.imap_addr').val($.cookie('mail_imap_addr'));
	//obj.find('.smtp_addr').val($.cookie('mail_smtp_addr'));

	set_server_addr(obj.find('.mail_addr').val());
	if($.cookie('mail_pwd')) {
		start_login();
	}else{
//		set_server_addr(obj.find('.mail_addr').val());
	}
	
	function get_current_selected_mails() {
		var cur_tab = get_current_tab();
		var cur_container = $('#'+cur_tab.attr('link'));
		var uids=cur_container.find('.email_list').find('input:checked').parent().parent().parent().map(function() {return $(this).attr('uid')} ).toArray().join(',');
		return uids;
	}
	$('.refresh_mails').unbind('click').click(function(){
		get_container(get_current_tab()).find('.email_list').children().remove();
		get_current_tab().attr('max_uid', '1');
		Email_Client.get_folder_list(top.uuid, get_current_tab(), undefined, undefined, "重新获取邮件列表")
	})
	$('.delete_mails').unbind('click').click(function(){ // 包括收件箱、所有的文件夹
		var uids=get_current_selected_mails();
		delete_notrash_mails(get_current_tab().attr('folder_id'), uids, function(){msg_box(lw_lang.ID_DELETE_SUCCESS,true);});
	})
	$('#trash_container .restore_mail').unbind('click').click(function(){
		var uids=get_current_selected_mails();
		delete_or_move_mails(Email_Client.trash_folder, Email_Client.inbox_folder, uids, function(){
			msg_box(lw_lang.ID_RESTORE_SUCCESS,true);
		});
	})
	$('.transfer_mails').unbind('click').click(function(){
		var container=$(this).parent().parent().parent();
		var items=container.find('.email_list').find('input:checked').parent().parent().parent();
		if(items.length!=1) {
			msg_box(lw_lang.ID_MAIL_TRANSFER_ONLY_ONE,false);
			return;
		}else{
			var mail_infos;
			var folder=get_current_tab().attr('folder_id');
			var item = $(items[0]);
			var uid=item.attr('uid');
			var mail_tab=$('.mail_tabs').find('.'+gen_email_tab(folder, uid));
			if(mail_tab.length>0) {
				mail_infos=mail_details(get_container(mail_tab));
				mail_infos['operator']=transfer_log;
				new_sendmail(mail_infos,true);
			}else{
				mail_infos=get_mailitem_infos(item);
				mail_infos['operator']=transfer_log;
				var editor = new_sendmail(mail_infos,true);
				hunt_mail_details(folder, mail_infos.Uid, top.uuid, function(detail){
					update_send_email_body(editor, decorate_body(detail.Body));
				});
			}
		}
	});
})();

function decorate_body(body) {return '<pre class="mailText">'+body+'</pre>';}

function get_container(tab) {
	return $('#'+tab.attr('link'));
}
function get_imap_addr(email){
	return get_imap_smtp_addr(email)[0];
}
function get_smtp_addr(email){
	return get_imap_smtp_addr(email)[1];
}
function get_imap_smtp_addr(email) {
	var domain=email.split('@')[1];
	return mail_serveraddr_map[domain] ? mail_serveraddr_map[domain] : ['',''];
}

var hint_timer;
function default_hint() {
	loading_hint(loading_hint_default);
}

function loading_hint(hint, timelen) {
	function do_hint() {
		hint=hint || '';
		$('#loading').show().find('.hint').text(hint);
	};
	cancel_hint_timer();
	if(timelen == 0){
		do_hint();
	}else {
		hint_timer=setTimeout(do_hint,  1500);
	}
}
function cancel_hint_timer(){
	if(hint_timer) {
		clearTimeout(hint_timer);
		delete hint_timer;
	}
}
function loading_hide() {
	cancel_hint_timer();
	$('#loading').hide();
}

function msg_box(hint, normal, timeout) {
	var level=(normal==true)? 4 : 5;
	timeout = timeout || 2000;
	top.LWORK.msgbox.show(hint, level, timeout);
}

var tab_show_manager=tab_click_history_class();
function tab_click_history_class() {
	this.tab_history_list=[];
	this.del = function(tab_itme) {
		var index=this.tab_history_list.indexOf(tab_itme);
		if(index!=-1) {
			this.tab_history_list.splice(index, 1);
		}
	}
	this.push=function(tab_item){
		this.del(tab_item);
		this.tab_history_list.push(tab_item);
	}
	this.get_last=function(){
		var len=this.tab_history_list.length;
		if(len>0) {
			return this.tab_history_list[len-1];
		}else{
			return 0;
		}
	}
	return this;
}