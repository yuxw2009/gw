// JavaScript Document

var clientHeight = document.documentElement.clientHeight > document.body.clientHeight ? document.documentElement.clientHeight : document.body.clientHeight;
var tabheight = clientHeight - 150;


function loadContent() {
    this.dttab1 = null;
}
loadContent.prototype = {
    loadOrgs: function () {
        api.loadOrgs(superAdminUser, superAdminToken, function(data){
            //var data = test_get_orgs();
            var orgs = data['orgs'];
            if (orgs.length > 0){
                var html1 = loadContent_Instance.createTab1Html(orgs);
                $('#orgInfoTable tbody').html(html1);
                loadContent_Instance.refreshTab1();
                $('.modMarkName').unbind('click').bind('click', modifyOrgMarkName);
                $('.resetAdminPW').unbind('click').bind('click', resetOrgAdminPW);
                $('.modFullName').unbind('click').bind('click', modifyOrgFullName);
								
				 $('.max_conf_members, .max_vconf_rooms, .max_cost , .max_members').unbind('click').bind('click', modifyCompanyItem);
				 
                existingMarkNames.splice(0, existingMarkNames.length);
                $('#orgInfoTable tbody').find('a.modMarkName').each(function(){
                    existingMarkNames.push($(this).text());
                });
            }
        });
    },
    createTab1Html: function(orgs){
        var html = '';
		
//           <th style="width:5%">选择</th>
//			 <th style="width:5%">公司ID</th>
//			 <th style="width:10%">公司简称</th>                                         
//			 <th style="width:5%">当前会议数</th>
//			 <th style="width:5%">最大会议数</th>     
                                                       
//			 <th style="width:10%">已用视频会议室</th>
//			 <th style="width:10%"> 最大会议室数</th>

//			 <th style="width:5%">总消费</th>
//			 <th style="width:5%"> 消费限额</th>                                                                                  
//			 <th style="width:10%"> 人员限制</th>             
//			 <th style="width:10%">管理员密码</th>
//			 <th style="width:10%">公司全称</th>

//cur_conf_members: 0
//cur_cost: "0.00"
//cur_vconf_rooms: 0
//full_name: "ZTE政企业务"
//mark_name: "zteenterprise"
//max_conf_members: 10
//max_cost: 1000
//max_members: 1000
//max_vconf_rooms: 5
//org_id: 289


        for (var i = 0; i < orgs.length; i++){
            html +=['<tr orgid="' + orgs[i].org_id+ '">',
						 '<td><input type="checkbox"></input></td>',
						 '<td>' + orgs[i].org_id + '</td>',
						 '<td><a href="###" class="modMarkName">' + orgs[i].mark_name+ '</td>',
						 '<td>' + orgs[i].cur_conf_members + '</a></td>',
						 '<td><a href="###" modItem="MCM" class="max_conf_members">' + orgs[i].max_conf_members + '</a></td>',
						 '<td>' + orgs[i].cur_vconf_rooms + '</td>',
						 '<td><a href="###" modItem="MVR" class="max_vconf_rooms">' + orgs[i].max_vconf_rooms + '</a></td>',						 
						 '<td>' + orgs[i].cur_cost + '</td>',
						 '<td><a href="###" modItem="MC" class="max_cost">' + orgs[i].max_cost  + '</a></td>',						 
						 '<td><a href="###" modItem="MM" class="max_members">' + orgs[i].max_members + '</a></td>',
						 '<td><a href="###" class="resetAdminPW">重置</a></td>',
						 '<td class="txtleft"><a href="###" class="modFullName">' + orgs[i].full_name+ '</a></td>',
                    '</tr>'].join("");
        }
        return html;
    },
    refreshTab1: function(){
        var html = $('#orgInfoTable tbody').html();
        if (loadContent_Instance.dttab1 !== null){
            loadContent_Instance.dttab1.fnDestroy();
        }
        $('#orgInfoTable tbody').html(html);
//        loadContent_Instance.dttab1 = $('#orgInfoTable').dataTable({
//            "bPaginate": false,
//            "bAutoWidth": false,
//            "aoColumns": [
//                    { "bSortable": false, "bVisible": true},
//                    { "sType": 'string-case' },
//                    { "sType": 'string-case' },
//                    { "bSortable": false, "bVisible": true},
//                    { "sType": 'string-case' }
//                ],
//            "sPaginationType": "full_numbers"
//        });
    }
}

var superAdminToken = '', superAdminUser='';
var loadContent_Instance = new loadContent();
var existingMarkNames = new Array();
if (false/*!$.cookie("godToken")*/){
    window.location = "index.html";
}else{
    superAdminToken = $.cookie("godToken");
    superAdminUser = $.cookie("superAdminName");
    $.cookie("godToken", "");
    $('#admin').text(superAdminUser);
    loadContent_Instance.loadOrgs();
}


//向DOM元素填日期
var current_data = new Date();
$('#current_data').html(current_data.getFullYear() + "年" + ((current_data.getMonth() + 1) > 10 ? (current_data.getMonth() + 1) : "0" + (current_data.getMonth() + 1)) + "月" + (current_data.getDate() > 10 ? current_data.getDate() : "0" + current_data.getDate()) + "日");
//表格内容滚动最小高度
$("#tab1").height(tabheight);
window.onresize = function () {
    var clientHeight = document.documentElement.clientHeight > document.body.clientHeight ? document.documentElement.clientHeight : document.body.clientHeight;
    tabheight = clientHeight - 150;
    $("#tab1").height(tabheight);
};

//退出
$('#goback').click(function () {
    $.cookie("godToken", "");
    window.location.href = "index.html";
})

//修改密码	 	
$('#modifypassword').click(function () {
    var contentId = document.getElementById('modifyPswInfo');
    var re = 1;
    var dialog = art.dialog({
        title: '修改密码',
        content: contentId,
        lock: true,
        fixed: true,
        width: 300,
        height: 180,
        button: [{
            name: '关闭',
            callback: function () {
                $('#totips').hide();
                $('#floatCorner_top').hide();
            }
        }, {
            name: '提交',
            callback: function () {
                var oldpsw = $('#oldpsw').val();
                var newpsw1 = $('#newpsw1').val();
                var newpsw2 = $('#newpsw2').val();
                if ('' === oldpsw) {
                    totips($('#oldpsw'), 120, '初始密码不能为空！', -30, -18, 1);
                    $('#oldpsw').focus();
                    return false;

                } else {
                    if ('' === newpsw1) {
                        totips($('#newpsw1'), 120, '新密码不能为空！', -30, -18, 1);
                        $('#newpsw1').focus();
                        return false;
                    } else if (newpsw1.length < 6) {
                        totips($('#newpsw1'), 140, '密码长度不能小于6位！', -30, -18, 1);
                        return false;
                    } else {
                        if (newpsw1 !== newpsw2) {
                            totips($('#newpsw2'), 120, '两次密码不一致！', -30, -18, 1);
                            $('#newpsw2').focus();
                            return false;
                        } else {
                            api.godModPW(superAdminUser, superAdminToken, md5(oldpsw), md5(newpsw1), function (data) {
                                if (data.message == 'ok') {
                                    art.dialog.tips('密码修改成功！');
                                    re = 1;
                                } else {
                                    totips($('#oldpsw'), 120, '初始密码有误！', -30, -18, 1);
                                    $('#oldpsw').focus();
                                    re = 0;
                                    return false;
                                }
                            });

                            if (re === 0) { return false; }
                        }
                    }
                }
            },
            focus: true
        }]
    });
})

function modifyOrgMarkName(){
    var _this = $(this), orgid=_this.parent().parent().attr('orgid'), oldMarkName = _this.text();
    var html = ['<div>',
                    '<table width="480"><tbody width=100%>',
                        '<tr><td>',
                                '<span class="tdTitle">旧简称：</span>',
                                oldMarkName,
                            '</td></tr>',
                        '<tr><td>',
                                '<span class="tdTitle">新简称：</span>',
                                '<input type="text" id="newMarkName" value="' + oldMarkName + '" style="width:400px"></input>',
                            '</td></tr>',
                    '</tbody></table></div>'].join("");
    var existingPos = existingMarkNames.indexOf(_this.text());
    var dialog = art.dialog({
        title: '修改公司简称',
        content: html,
        lock: true,
        fixed: true,
        width: 400,
        height: 180,
        button: [{
            name: '取消',
            callback: function () {
                    _this.removeClass('modifying');
                    $('#totips').hide();
                    $('#floatCorner_top').hide();
                }
            }, {
            name: '确定',
            callback: function () {
                    var newMarkName = $('#newMarkName').val();
                    if (newMarkName.length === 0){
                        totips($('#newMarkName'), 200, '公司简称不能为空！', -30, -18, 1);
                        $('#newMarkName').focus();
                        return false;
                    }
                    for (var i = 0; i < existingMarkNames.length; i++){
                        if ((newMarkName === existingMarkNames[i]) && (i !== existingPos)){
                            totips($('#newMarkName'), 200, '不能与其他公司简称重复！', -30, -18, 1);
                            $('#newMarkName').focus();
                            return false;
                        }
                    }
                    
                    if (newMarkName !== oldMarkName){
                        api.modMarkName(superAdminUser, superAdminToken, orgid, newMarkName, function(){
                            art.dialog.tips('公司简称修改成功！');
                            _this.text(newMarkName);
                            existingMarkNames[existingPos] = newMarkName;
                        });
                    }
                }
            }]
    });
    return false;
}

function resetOrgAdminPW(){
    var _this = $(this), orgid=_this.parent().parent().attr('orgid');
    var html = ['<div>',
                '<div>此操作将会把管理员密码重新设置为“888888”，原密码将失效!</div>',
                '<div>你确认执行此操作吗？</div>',
                '</div>'].join("");
    var dialog = art.dialog({
        title: '重置管理员密码',
        content: html,
        id: 'reset_admin_pw_confirm_dialog',
        lock: true,
        fixed: true,
        width: 400,
        height: 60,
        cancel: false,
        button: [{  name: '确认',
                    focus: true,
                    callback: function(){
                        api.resetAdminPW(superAdminUser, superAdminToken, orgid, function(){
                            art.dialog.tips('管理员密码重置成功！');
                        });
                    }
                 },{name:'取消',
                    callback: function () {
                        $('#totips').hide();
                        $('#floatCorner_top').hide();
                    }
                }]
    });
    return false;
}


function modifyCompanyItem( ){	

    var _this = $(this), obj =  _this.parent().parent(), 
	    orgId = obj.attr('orgid'), comItem = _this.text() , modiItem= _this.attr('moditem');
	var MCM = obj.find('.max_conf_members').text(), MVR = obj.find('.max_vconf_rooms').text() , MC = obj.find('.max_cost').text() , MM = obj.find('.max_members').text();
	console.log(modiItem)
	switch (modiItem){
			 case 'MCM':
			    label = '最大会议人数'				
				break;
			 case 'MVR':
			    label = '最大视频会议室数'
				break;		
			 case 'MC':
			    label = '企业消费限额'
				break;								   
			 case 'MM':
			    label = '开户限数'
				break;					
	 }
    var html = ['<div>',
                    '<table width="480"><tbody width=100%>',
                        '<tr><td>',
                                '<span class="tdTitle">原'+ label +'：</span>',
                                comItem,
                            '</td></tr>',
                        '<tr><td>',
                                '<span class="tdTitle">修改为：</span>',
                                '<input type="text" id="newcomItem" value="' + comItem + '" style="width:400px"></input>',
                            '</td></tr>',
                    '</tbody></table></div>'].join("");	
		  var dialog = art.dialog({
				title: '修改' + label,
				content: html,
				lock: true,
				fixed: true,
				width: 400,
				height: 180,
				button: [{
					name: '取消',
					callback: function () {
						$('#totips').hide();
						$('#floatCorner_top').hide();
					}
				}, {
					name: '确定',
					callback: function () {
						var inputBox = $('#newcomItem')
						var newcomItem = inputBox.val();
						if (newcomItem.length === 0){
							totips(inputBox, 200, '新' + label + '不能为空！', -30, -18, 1);
							inputBox.focus();
							return false;
						}else if (newcomItem !== comItem){
								switch (modiItem){
										 case 'MCM':
											MCM =  newcomItem;
											break;
										 case 'MVR':
											MVR =  newcomItem;					
											break;		
										 case 'MC':
											 MC =  newcomItem;						
											break;								   
										 case 'MM':
											MM =  newcomItem;
											break;					
								}	
								api.modComItem(orgId, MCM, MVR, MC, MM, function(){
									art.dialog.tips('修改成功！');
									_this.text(newcomItem);
								});
								
						}else{
						  totips(inputBox, 200, '请输入修改后的值！', -30, -18, 1);
						  return false
						}
					}
				}]
			});
			return false;					
	
	
}

function modifyOrgFullName(){
    var _this = $(this), orgid=_this.parent().parent().attr('orgid'), oldFullName = _this.text();
    var html = ['<div>',
                    '<table width="480"><tbody width=100%>',
                        '<tr><td>',
                                '<span class="tdTitle">旧简称：</span>',
                                oldFullName,
                            '</td></tr>',
                        '<tr><td>',
                                '<span class="tdTitle">新简称：</span>',
                                '<input type="text" id="newFullName" value="' + oldFullName + '" style="width:400px"></input>',
                            '</td></tr>',
                    '</tbody></table></div>'].join("");
    var dialog = art.dialog({
        title: '修改公司全称',
        content: html,
        lock: true,
        fixed: true,
        width: 400,
        height: 180,
        button: [{
            name: '取消',
            callback: function () {
                $('#totips').hide();
                $('#floatCorner_top').hide();
            }
        }, {
            name: '确定',
            callback: function () {
                var newFullName = $('#newFullName').val();
                if (newFullName.length === 0){
                    totips($('#newFullName'), 200, '新公司全称不能为空！', -30, -18, 1);
                    $('#newFullName').focus();
                    return false;
                }
                else if (newFullName !== oldFullName){
                    api.modFullName(superAdminUser, superAdminToken, orgid, newFullName, function(){
                        art.dialog.tips('公司全称修改成功！');
                        _this.text(newFullName);
                    });
                }
            }
        }]
    });
    return false;
}

$('#addOrg').click(function(){
    var html = ['<div>',
                    '<table width="340"><tbody>',
                        '<tr><td colspan="2">',
                                '<span class="tdTitle">公司简称：</span>',
                                '<input type="text" id="newOrgMarkName" value="" style="width:270px"></input>',
                            '</td></tr>',
                        '<tr><td colspan="2">',
                                '<span class="tdTitle">公司全称：</span>',
                                '<input type="text" id="newOrgFullName" value="" style="width:270px"></input>',
                            '</td></tr>',
                        '<tr><td style="width:50%">',
                                '<span class="tdTitle">管理员账号：</span>',
                                'admin',
                            '</td><td>',
                                '<span class="tdTitle">管理员密码：</span>',
                                '<input type="text" id="newOrgAdminPW" value="888888" style="width:88px"></input>',
                            '</td></tr>',
                    '</tbody></table></div>'].join("");
    console.log('to add org....');
    var dialog = art.dialog({
        title: '添加公司',
        content: html,
        lock: true,
        fixed: true,
        width: 360,
        height: 180,
        button: [{
            name: '取消',
            callback: function () {
                $('#totips').hide();
                $('#floatCorner_top').hide();
            }
        }, {
            name: '确定',
            callback: function () {
                var tbl = $('#orgInfoTable');
                var newOrgMarkName = $('#newOrgMarkName').val(),
                    newOrgFullName = $('#newOrgFullName').val(),
                    newOrgAdminPW = $('#newOrgAdminPW').val();

                for (var i = 0; i < existingMarkNames.length; i++){
                    if (newOrgMarkName === existingMarkNames[i]){
                        totips($('#newOrgMarkName'), 200, '公司简称已存在，请重新填写！', -30, -18, 1);
                        $('#newOrgMarkName').val('').focus();
                        return false;
                    }
                }
                if (newOrgMarkName.length === 0){
                    totips($('#newOrgMarkName'), 200, '公司简称不能为空！', -30, -18, 1);
                    $('#newOrgMarkName').focus();
                    return false;
                }
                if (newOrgFullName.length === 0){
                    totips($('#newOrgFullName'), 200, '公司全称不能为空！', -30, -18, 1);
                    $('#newOrgFullName').focus();
                    return false;
                }
                console.log('before api addOrg...');
                var newOrgInfo = {mark_name:newOrgMarkName, full_name:newOrgFullName, admin_pw:newOrgAdminPW}
                api.addOrg(superAdminUser, superAdminToken, newOrgInfo, function(){
                    art.dialog.tips('公司添加成功！');
                    loadContent_Instance.loadOrgs();
                });
            }
        }]
    });
    return false;
})

$('#delOrgs').click(function(){
    var toDellist = [];
    $('#orgInfoTable').find('input[type="checkbox"]').each(function(){
        if ($(this).attr("checked") || $(this).attr("checked")){
            toDellist.push($(this).parent().parent().attr('orgid'));
        }
    })
    if (toDellist.length > 0){
        api.delOrgs(superAdminUser, superAdminToken, toDellist, function(){
            art.dialog.tips('删除公司成功！');
            $('#orgInfoTable').find('input[type="checkbox"]').each(function(){
                if ($(this).attr("checked") || $(this).attr("checked")){
                    $(this).parent().parent().remove();
                }
            })
        }, function(){
            art.dialog.tips('删除公司失败！公司不为空。');
        });
    }else{
        art.dialog.tips('请选择要删除的公司！');
    }
    return false;
})

var totips = function (obj, width, txt, leftv, topv, flag) {
    var offset, top, left;
    offset = obj.offset();
    obj.length > 0 ? top = parseInt(offset.top) + leftv : top = 123;
    obj.length > 0 ? left = parseInt(offset.left) + topv : left = 50;
    $('#totips').text(txt).css({ top: top + 'px', width: width + 'px', left: left + 'px' }).show();
    $('#floatCorner_top').css({ top: top + 26 + 'px', left: left + 50 + 'px' }).show();

    if (flag) {

        obj.keyup(function () {
            $('#totips').hide();
            $('#floatCorner_top').hide();
        }).click(function () {
            $('#totips').hide();
            $('#floatCorner_top').hide();
        })

    } else {
        setTimeout(function () {
            $('#totips').hide();
            $('#floatCorner_top').hide();
        }, 1000);

    }
};

// 搜索框插件			   
$.fn.searchInput = function (options) {
    var defaults = {
        color: "#343434",
        defaultcolor: "#999",
        defalutText: "请输入关键字..."
    },
        params = $.extend(defaults, options || {}),
	    _this = $(this);
    _this.css("color", params.defaultcolor);
    _this.focus(function () {
        _this.val("");
        _this.css("color", params.color);
    }).blur(function () {
        if ("" == _this.val()) {
            _this.css("color", params.defaultcolor);
            _this.val(params.defalutText);
        }
    })
}

function test_get_orgs()
{return {status:'ok', orgs:[{org_id:"201", mark_name:"zte", full_name:"中兴通讯"}, 
                          {org_id:"202", mark_name:"hw", full_name:"华为公司"}, 
                          {org_id:"203", mark_name:"ers", full_name:"爱立信"}]};}



