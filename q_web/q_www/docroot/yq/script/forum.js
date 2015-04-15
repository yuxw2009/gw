var forum_topics = {};   //返回：{id:topic}
				//Topic = {id:id,from:From,title:Title, content:Content,type:Type,reply_num:Num, readers:Readers,
				//                         timestamp:Time_stamp, repository:Repository}
var PAGE_NUM  = '20';
var current_topics_pgno=1;
var current_replies_pgno=1;
function GetForumCategories(uuid,cb,fb) {
	var url = '/lwork/forum/categories?uuid='+uuid;
	RestChannel.get(url, {}, cb, fb);
}

function CreateForumCategories(uuid,Categories) {
	var url = '/lwork/forum/categories';

	RestChannel.post(url, {uuid:uuid,categories:Categories}, 
		function(data){console.log('板块设置成功！');})
}

//GET /lwork/forum/topics?uuid=UUID&cindex=Index&page_index=Page&page_num=Num
//{uuid:uuid,cindex:cindex,page_index:pindex,page_num:num}
//返回：{status:ok, uuid:uuid,today_num:Today, total_num:Total, topics:Topics}
//Topic = {id:id,from:From,title:Title, content:Content,type:Type,reply_num:Num, readers:Readers,
//                         timestamp:Time_stamp, repository:Repository}
function GetForumTopics(paras,cb, fail) {   
	var url = '/lwork/forum/topics'
	RestChannel.get(url, paras, cb,fail);
}

function GetForumReplies(paras, cb, fail) {
	var url = '/lwork/forum/replies';
	RestChannel.get(url, paras, cb, fail);
}

function ConfigForumTopic(paras) {  //{uuid:uuid, topic_id:topic, type:Type}  //Type: notice/global_top/top/best
	var url = '/lwork/forum/topics';
	RestChannel.put(url, paras, function(data) {console.log('设置帖子属性成功:',data)});
}

//POST /lwork/forum/topics
//	{uuid:UUiD,title:Title, content:Content, category_id:category_id, repository:Repository}
//          Repository: == image:Image,attach:Attatch_name
//    返回：
//        {status:ok,topic_id:Topic_id,time_stamp:Time_stamp, from:From}
//        {status:failed, reason:Reason} 
//	{uuid:UUiD,title:Title, content:Content,repository:Repository}
//          Repository: == image:Image,attach:Attatch_name
function PostForumTopic(paras) { 
	RestChannel.post('/lwork/forum/topics',paras,function(data) {
		show_cur_category_topics();
		$('#forum').find('.title').val('');
		$('#forum').find('.detail_content').val('');
		upload_images ={};
		$('#forum').find('.uploadtip').html('').remove();	
		LWORK.msgbox.show(lw_lang.ID_FORUM_SUCCESS,4,2000);

	});
}

/*%% 发回复
POST /lwork/forum/replies
	{uuid:UUiD,content:Content, topic_id:topic_id, repository:Repository}
          Repository: == refer_id:Refer_id,image:Image,attach:Attatch_name
    返回：
        {status:ok,reply_id:Reply_id,time_stamp:Time_stamp, from:From}
        {status:failed, reason:Reason} */
function PostForumReply(paras) {
	RestChannel.post('/lwork/forum/replies',paras,function(data) {
		LWORK.msgbox.show(lw_lang.ID_REPLY_SUCCESS,4,2000); 		
		var tipic_id = paras.topic_id ;
		var reply_obj = $('#forum_' + tipic_id).find('.forum_reply_num');
		var reply_num = parseInt(reply_obj.text()) ;
		$('#forum').find('.title').val('');
		$('#forum').find('.detail_content').val('');
		forum_show_topic_detail(tipic_id,'1');
		reply_obj.text(reply_num + 1);
	},
	function(){ LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 3, 1000); });
}

function DeleteForumTopic(paras) { //{uuid:UUiD,topic_id:Topic_id}
	RestChannel.del('/lwork/forum/topics',paras,function(data) {
	   LWORK.msgbox.show(lw_lang.ID_DELETE_SUCCESS, 3, 1000);
	});
}

function forum_category_item(label, categs) {
	function categ_html(categ) {
		return ['<li>', '<a href="###" ', 'class="forum_categ_bind forum_category_'+categ.index+'"'+' index='+categ.index+'>',
						categ.title,
						'</a></li>'].join('');
	}
	function categs_html(Categs) {
		var html='';
		for (var i=0; i< Categs.length; i++) {
			html+=categ_html(Categs[i]);
		}
		return html;
	}
	return ['<li>',label,'<ul>', categs_html(categs),'</ul>','</li>'].join('');
}

function forum_category_items(Categ_data) {
	var html = '';
    for (var label in Categ_data) {
    	html+=forum_category_item(label, Categ_data[label])
    }
    return html;
}

//GET /lwork/forum/topics?uuid=UUID&cindex=Index&page_index=Page&page_num=Num
//{uuid:uuid,cindex:cindex,page_index:pindex,page_num:num}
//返回：{status:ok, uuid:uuid,today_num:Today, total_num:Total, topics:Topics}
//Topic = {id:id,from:From,title:Title, content:Content,type:Type,reply_num:Num, readers:Readers,
//                         timestamp:Time_stamp, repository:Repository}

function forum_postby_html(UUID) {
	function queryNameLogo(UUID) {
		var logo="";
		if(!getEmployeeByUUID(UUID)) logo+=('delete_uuid delete_'+UUID);
		return logo;
	}
	return ['<span class="postby lanucher '+queryNameLogo(UUID)+'" '+'employer_uuid="'+UUID+'" '+'>',
	getEmployeeDisplayname(UUID), '</span>'].join('');
}

function forum_posttime_html(timestamp) {
	return ['<span class="posttime">',timestamp, '</span>'].join('');
}

function forum_topic_replies_num_html(num) {
	return ['<span class="reply_hint">', '<span class="forum_reply_num">',num, '</span>', '</span>'].join('');
}
function forum_topic_html(topic) {
	function imageAttachHtml(repos) {
		var image_attach_logo = '';
		if(repos && repos.image) {
			var image = repos.image.upload_images_url;
			var attach = repos.image.attachment_name;
			if ((attach && attach.length>0) ||(repos.image.multi_attachment && repos.image.multi_attachment.length>0) ) 
				image_attach_logo += '<a href="###" class="include_attachment"></a>';
			if((image && image.length>0) || (repos.image.multi_images && repos.image.multi_images.length>0))	
				image_attach_logo += '<a href="###" class="include_image"></a>';
		}
		return image_attach_logo;
	}
	function topicTitleHtml(title,id) {
		var titl = title.length > 50 ? title.substring(0,50)+'...' : title;
		return html = '<a href="###" class="forum_topic_bind "'+'id="'+id+'">'+ 
				loadContent.format_message_content(titl, 'linkuser')+'</a>';

	}
	var type_map = {normal:'', global_top:'overall',top:'forum_top',notice:'announcement'};
	var html = ['<dl class="msg_item" id="forum_'+ topic['id'] +'">',
	'<dd class="personal_icon">','<img src="',getEmployeePhoto(topic.from),'" width="48" height="48"></dd>',
	'<dd class="pagecontent">',
	'<span class="',type_map[topic.type],'"></span>', 
		topicTitleHtml(topic.title,topic.id),
	'</dd>',
	'<dd class="forum_foot">',
	forum_postby_html(topic.from),
	forum_posttime_html(topic.timestamp),
//	'<span class="viewstime">', topic.readers, '次阅读</span>',
	imageAttachHtml(topic.repository),
	forum_topic_replies_num_html(topic.reply_num),
	'</dd>', '</dl>'].join('');
	return html;
}

/*replies: [{id:Id,from:From,content:Content,timestamp:Time_stamp,repository:Repository}]}

//                  Repository: == refer_id:Refer_id,image:Image,attach:Attatch_name*/                
function forum_topic_Or_reply_msg_item(paras,floor) {
	var prefix=(paras.title) ? '<strong>'+ lw_lang.ID_FORUM_CONTENT+': </strong>' : '<strong>'+ lw_lang.ID_REPLY +': </strong>';
	var image=paras.repository.image;
    var attachment = image ? loadContent.getImgAttacheDom(image,'B') : '';
	var text = ['<dl class="msg_item">',
                  '<dt class="personal_icon">',
                    '<img src="/images/photo/5.gif" width="20" height="20"> ',
                    forum_postby_html(paras.from),
                    forum_posttime_html(paras.timestamp),
                    '<span class="floor"> <em>',floor, '</em> <sup>#</sup> </span>',
                  '</dt>',
                  '<dd class="pagecontent">',
                  	prefix+loadContent.format_message_content(paras.content, 'linkuser'),
                  '</dd>',
                  attachment,
                '</dl>'].join('');
    return text;
}               

//GET /lwork/forum/replies?uuid=UUID&topicId=Id&page_index=Page&page_num=Num
//    {uuid:uuid, topic_id:topicId, page_index:page_index, page_num:page_num}
//返回：{status:ok, uuid:uuid, num:Num, replies: [{id:Id,from:From,content:Content,timestamp:Time_stamp,repository:Repository}]}

//                  Repository: == refer_id:Refer_id,image:Image,attach:Attatch_name
//            replies = [T1,T2,T3...] //前20个 按照时间从新到旧的排序
function forum_topic_details_html(detail_items) {
	var html='';
	for (var i=-0; i<detail_items.length; i++){
		html+=forum_topic_Or_reply_msg_item(detail_items[i],i+1);
	}
	return html;
}
//GET /lwork/forum/replies?uuid=UUID&topicId=Id&page_index=Page&page_num=Num
//    {uuid:uuid, topic_id:topicId, page_index:page_index, page_num:page_num}
//返回：{status:ok, uuid:uuid, num:Num, replies: [{id:Id,from:From,content:Content,timestamp:Time_stamp,repository:Repository}]}

//                  Repository: == refer_id:Refer_id,image:Image,attach:Attatch_name
//            replies = [T1,T2,T3...] //前20个 按照时间从新到旧的排序
function forum_pg_html(no) {return ['<a  href="###" ','class="page_num_',no,'" page="',no, '"">',no,'</a>'].join('');}

function forum_show_pg_num(pg,pages, load) {
	var pg_num_obj = pg.find('.pg_number');
	pg_num_obj.empty();
	for (var i=0;i<pages;i++){pg_num_obj.append(forum_pg_html(i+1));}
	pg_num_obj.find('a').unbind('click').click(function(){
		load($(this).attr('page'));
	});
}

function forum_show_topic_detail(id,page_index) {
	var paras ={uuid:uuid, topic_id:id, page_index:page_index,page_num:PAGE_NUM};
	function result(data) {
		function set_top_logo(type) {
			var r ={top:"/images/forum_top.gif",
					global_top:"/images/forum_global_top.gif",
					notice:"/images/forum_notice.gif"};
			if (r[type]) {
				$('#forum_detail .forumtop').find('img').attr('src', r[type]);
				$('#forum_detail .forumtop').show();
			}
			else
				$('#forum_detail .forumtop').hide();
		}

		function show_forum_detail(topic){
			$('#forum_detail').show();
			$('#forum_detail .thread_subject').text(lw_lang.ID_FORUM_TITLE + ': '+topic.title);
			var detail_items = [topic].concat(data.replies);
  			 $('#forum_reply').html(forum_topic_details_html(detail_items));
  			 loadContent.contentmemberdetail();
		}

		function load_replies_page(pageno){
			var p = paras;
			p.page_index = pageno;
			current_replies_pgno = pageno;
			forum_show_topic_detail(id,pageno);
		}

		function bind_last_next_page(pg,pages) {
			pg.find('.last').unbind('click').click(function(){
				var pgno = parseInt(current_replies_pgno)-1;
				if (pgno>=1 && pgno <=pages)
					load_replies_page(pgno.toString());
			});				
			pg.find('.next').unbind('click').click(function(){
				var pgno = parseInt(current_replies_pgno)+1;
				if (pgno>=1 && pgno <=pages)
					load_replies_page(pgno.toString());
			});				
		}
		function show_forum_replies_pgt(total_num,page_num) {
			var pg = $('#forum .pg');
			var pages = Math.floor(total_num%page_num ? total_num/page_num+1 : total_num/page_num);
			if (pages<=1) {
				pg.hide();
				return;
			}else
			{
				forum_show_pg_num(pg,pages, load_replies_page);
				bind_last_next_page(pg,pages);
				pg.show();
			}
			pg.find('.page_num_'+current_replies_pgno).addClass('current');
		}
		var topic=forum_get_topic(id);
		if(topic) {
			$('.forum_topics_page').hide();
			show_forum_replies_pgt(topic.reply_num, PAGE_NUM); 
			show_forum_detail(topic);
			set_top_logo(topic.type);
			set_forum_sendmessage_in_detail_state(id);
		}
	}
	GetForumReplies(paras, result, function(xhr){console.log('get replies failed! reason is:',xhr);})
}

function set_forum_sendmessage_in_post_topic_state() {
//	$('#forum .gotolist').show();
	$('#forum .sendBtn').addClass('disabledBtn');
	$('#forum .sendmessage').find('.reply_content').hide();
	var default_title = lw_lang.ID_SUBFORUM_TIP ;
	$('#forum .sendmessage').find('.title').show().val(default_title).searchInput({defalutText: default_title})  //val('标题(少于80字)').show();
	var default_content = lw_lang.ID_CONFORUM_TIP ;
	$('#forum .sendmessage').find('.detail_content').show().val(default_content).searchInput({defalutText: default_content})  //val('输入内容').show();
	$('#forum .title').unbind('keyup').bind('keyup', function() {
		return loadContent.checkInputLimit($(this), $('#forum'), 200,$('#forum .sendBtn'));
	});
    $('#forum .detail_content').unbind('keyup').bind('keyup', function() {
    	loadContent.checkInputLimit($(this), $('#forum'), 1000,$('#forum .sendBtn'));
    	return false;
    });
	$('#forum .sendBtn').text(lw_lang.ID_FORUM_POST).unbind('click').click(function() {
		var _this = $(this);
		if (_this.hasClass('disabledBtn')) return;
		totips.hidetips();
		$('#forum_post').show();
		$('#forum_reply').hide();
		var target = $('#forum');
	    var title = target.find('.title').val();
	    var content = target.find('.detail_content').val();
	    if (title.trim()=='' || title.trim()==default_title ||
	    	 content.trim() =='' || content.trim() ==default_content) {
	    	LWORK.msgbox.show("请在标题栏和内容栏内输入信息",5,1000);  
	    	return;
	    }
	    var cur_categ_class=$.cookie('category_id');
	    var cindex=$('.'+cur_categ_class).attr('index');	    
		var upload_images = loadContent.getAttachmentObj(_this.parent());
	    var repos = {image:upload_images};
	    PostForumTopic({uuid:uuid,title:title,content:content,cindex:cindex,repository:repos});
	})
}

function set_forum_sendmessage_in_detail_state(id) {
	var default_text = lw_lang.ID_FORUM_REPLY;
	$('#forum .sendBtn').addClass('disabledBtn');
	$('#forum_post').show();
	$('#forum_reply').show();
	$('#forum .sendmessage').find('.title').hide();
	$('#forum .sendmessage').find('.detail_content').hide(); //val('输入回复内容').show();
	$('#forum .sendmessage').find('.reply_content').show().val(default_text).searchInput({defalutText:default_text}); //val('输入回复内容').show();
    $('#forum .reply_content').unbind('keyup').bind('keyup', function() {
    	loadContent.checkInputLimit($(this), $('#forum'), 1000,$('#forum .sendBtn'));
    	return false;
    });
	$('#forum .sendBtn').text(lw_lang.ID_REPLY).unbind('click').click(function() {
		var target = $('#forum');
		var _this = $(this);
        var content = target.find('.reply_content').val();
        if (content.trim() != default_text && content.trim() != '') {
            var cur_categ_class=$.cookie('category_id');
            var cindex=$('.'+cur_categ_class).attr('index');
            var upload_images = loadContent.getAttachmentObj(_this.parent());
            var repos = {image:upload_images};
            PostForumReply({uuid:uuid,content:content,topic_id:id,repository:repos});
        }
	})
}

function load_forum_topics(paras) {
	function result(data){
		function topics_html() {
			var html='';
			for(var i=0; i<data.topics.length; i++) {
				html+=forum_topic_html(data.topics[i]);
			}
			return html;
		}
		function update_topic_db() {
			forum_topics={};
			for(var i=0; i<data.topics.length; i++) {
				forum_topics[data.topics[i].id]=data.topics[i];
			}
		}
		function bindTopicClick(){
			$('.forum_topic_bind').unbind('click').click(function(){
				var id=$(this).attr('id');
				var topic = $(this);
				var titl = $(this).text().substring(0,10);
				forum_show_topic_detail(id,'1');
				forum_show_gotolist_in_replies_state();
				if(titl.length == 10) titl += '...';
				record_history_nav(function() {topic.click()}, lw_lang.ID_FORUM_FORUMS + ':'+titl,true);
		    
		    })
		}

		function load_topics_page(pageno){
			var p = paras;
			p.page_index = pageno;
			current_topics_pgno = pageno;
			load_forum_topics(p);
		}
		function show_forum_topics_pgt(total_num,page_num) {
			var pg = $('#forum .pg');
			var pg_num_obj = pg.find('.pg_number');
			pg_num_obj.empty();
			var pages = Math.floor(total_num%page_num ? total_num/page_num+1 : total_num/page_num);
			if (pages<=1) {
				pg.hide();
			}else{
				for (var i=0;i<pages;i++){pg_num_obj.append(forum_pg_html(i+1));}
				pg_num_obj.find('a').unbind('click').click(function(){
					var cur_page = $(this).attr('page');
					load_topics_page(cur_page);
//					record_history_nav(function(){load_topics_page(cur_page);},cur_page,true);
				});
				pg.find('.last').unbind('click').click(function(){
					var last_page = parseInt(current_topics_pgno)-1;
					if (last_page<1) return;
					load_topics_page(last_page.toString());
//					record_history_nav(function(){load_topics_page(last_page.toString());},last_page,true);
				});				
				pg.find('.next').unbind('click').click(function(){
					var next_page = parseInt(current_topics_pgno)+1;
					if (next_page>pages) return;
					load_topics_page(next_page.toString());
//					record_history_nav(function(){load_topics_page(next_page.toString());},next_page,true);
				});
				pg.show();
			}
			pg.find('.page_num_'+current_topics_pgno).addClass('current');
		}

		(function update_topics_sum() {
			$('#forum .today').text(data.today_num);
			$('#forum .total').text(data.total_num);
		})();

		function show_topics_page(flag){
			var reply_obj;
			$('#forum .forum_pgt').show();
			current_topics_pgno = paras.page_index;
			show_forum_topics_pgt(data.total_num,PAGE_NUM);
			flag ? $('#forum_msg').show() : $('#forum_msg').html(topics_html());
			$('#forum_detail').hide();
			$('.forum_topics_page').find('li').hide()
			$('.forum_topics_page').show();	
			loadContent.contentmemberdetail();
			loadContent.getdelete_name($('#forum_msg'));
		};
		function local_update_replies_num() {
			result(data);
		}
		forum_show_gotolist_in_topics_state();
		show_topics_page();
		set_forum_sendmessage_in_post_topic_state();
		update_topic_db();
		bindTopicClick();
		record_history_nav(function() {
										//local_update_replies_num();
                                        show_topics_page(1);
										$('#forum_post').show();
										}, $('.'+$.cookie('category_id')).text());
	}
	GetForumTopics(paras,result, function(){console.log('load topic failed!')});
}

function show_cur_category_topics() {
	var cur_categ = $.cookie('category_id');
	var fun = function(){
		$('.'+cur_categ).click();
	}
	fun();
}

function record_history_nav(cb, title, is_append) {
	var nav_dom = $('#forum .history_nav');   //yxwnext
	var seperator = '<em> > </em>';
	var node = '<a href="###">'+title+'</a>';
	if (is_append) {
		nav_dom.append(seperator).append(node);
	}else{
		nav_dom.html(node);	
	}
	nav_dom.find('a').last().unbind('click').click( function() {

		cb();
		$(this).nextAll().each(function(){
			$(this).remove()
		});
	});

}
function load_forum_categories() {
	function result(data) {
		var Categs = data['categories'];
		var categ_data = {};
		$('.forum_box .forum_menu ul').empty();
		for(var i=0; i<Categs.length; i++) {
    		//console.log(Categs[i].index, Categs[i].title, Categs[i].label);
    		var index = Categs[i].index;
    		var title = Categs[i].title;
    		var label = Categs[i].label;
    		if (!categ_data[label]) categ_data[label]=[]
    		categ_data[label].push({title:title,index:index});
		}
		$('.forum_box .forum_menu ul').append(forum_category_items(categ_data));
		$('.forum_categ_bind').click(function() {
			$('#forum_post').show();
			$('#forum_reply').hide();
			var _this = $(this);
			$.cookie('category_id', 'forum_category_'+_this.attr('index'));
			$('.forum_menu').find('.forum_categ_bind').removeClass('current');
			_this.addClass('current');
			load_forum_topics({uuid:uuid, cindex:_this.attr('index'),page_index:'1',page_num:PAGE_NUM});
//			record_history_nav(function(){_this.click()}, _this.text());
		})
		if(!$.cookie('category_id') && Categs.length>0) $.cookie('category_id','forum_category_'+Categs[0].index);
		show_cur_category_topics();
	}
	$('#forum_post').unbind('click').click(function(){
		$('#forum_post').hide();
		$('#forum_reply').hide();
		$('#forum .title').show();
		forum_show_gotolist_in_post_state();
		$('#forum .forum_topics_page').hide();
		$('#forum .forum_detail').hide();
		set_forum_sendmessage_in_post_topic_state();
		record_history_nav(function(){
			  $('#forum_post').click()
		    }, lw_lang.ID_FORUM_POST ,true);
		return false;
	});
	$('#forum .forum_pgt').show();
	GetForumCategories(uuid,result, function(xhr) {console.log('fail to get forum category:',xhr)})
}

function forum_show_gotolist_in_replies_state() {
	$('#forum .forum_pgt').find('.gotolist').show();
	$('#forum .forum_pgt').find('.gotolist').unbind('click').click(function() {
	$('#forum .history_nav').find('a').eq(-2).click()
});

}

function forum_show_gotolist_in_topics_state() {
	$('#forum .forum_pgt').find('.gotolist').hide();
}

function forum_show_gotolist_in_post_state() {
	$('#forum .forum_pgt').find('.pg').hide();
	$('#forum .forum_pgt').find('.gotolist').eq(0).hide();
	$('#forum .forum_pgt').find('.gotolist').eq(1).show();
	$('#forum .forum_pgt').find('.gotolist').unbind('click').click(function() {
		$('#forum .history_nav').find('a').eq(-2).click();
	});
}
function forum_get_topic(id) { return forum_topics[id];}