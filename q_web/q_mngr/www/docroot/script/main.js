// JavaScript Document
// 搜索框插件
var adminUser = 'unknown';
var companyid = $.cookie("orgId"), companymarkname=$.cookie("markName"), departmentid = 'top', employid, isEditingDpt = false;
var modifyingEmployee = {'name':'未指定', 'id':'未指定', 'password':'888888', 'phone':'', 'email':'', 'balance':'200', 'service':{'voip':true, 'phoneconf':false, 'sms':true, 'dataconf':false}};
var clientHeight = document.documentElement.clientHeight > document.body.clientHeight ? document.documentElement.clientHeight : document.body.clientHeight;
var tabheight = clientHeight - 210;

 



jQuery.fn.dataTableExt.oSort['alt-string-asc'] = function (a, b) {
    a = $(a).find('.employ_id').text();
    b = $(b).find('.employ_id').text();
    var x = a;
    var y = b;
    return ((x < y) ? -1 : ((x > y) ? 1 : 0));
};

jQuery.fn.dataTableExt.oSort['alt-string-desc'] = function (a, b) {
    a = $(a).find('.employ_id').text();
    b = $(b).find('.employ_id').text();
    var x = a;
    var y = b;
    return ((x < y) ? 1 : ((x > y) ? -1 : 0));
};

jQuery.fn.dataTableExt.oSort['numeric-comma-asc'] = function (a, b) {
    a = $(a).text();
    b = $(b).text();
    var x = (a == "-") ? 0 : a.replace(/,/, ".");
    var y = (b == "-") ? 0 : b.replace(/,/, ".");
    x = parseFloat(x);
    y = parseFloat(y);
    return ((x < y) ? -1 : ((x > y) ? 1 : 0));
};

jQuery.fn.dataTableExt.oSort['numeric-comma-desc'] = function (a, b) {
    a = $(a).text();
    b = $(b).text();
    var x = (a == "-") ? 0 : a.replace(/,/, ".");
    var y = (b == "-") ? 0 : b.replace(/,/, ".");
    x = parseFloat(x);
    y = parseFloat(y);
    return ((x < y) ? 1 : ((x > y) ? -1 : 0));
};

/* Define two custom functions (asc and desc) for string sorting */
jQuery.fn.dataTableExt.oSort['string-case-asc'] = function (x, y) {
    return ((x < y) ? -1 : ((x > y) ? 1 : 0));
};

jQuery.fn.dataTableExt.oSort['string-case-desc'] = function (x, y) {
    return ((x < y) ? 1 : ((x > y) ? -1 : 0));
};

function createDptNameBar(name, level){
    return '<a href="###" olddata="' + name + '" class="dptbar dptLevel_' + level + '">' + name + '</a>';
};

function createDptOptBtns(level){
    if (level < 4){
        return '<span class="item_opertion"><a href="###" class="add_subdpt"></a><a href="###" class="edit_dpt"></a><a href="###" class="del_dpt"></a></span>';
    }else{
        return '<span class="item_opertion"><a href="###" class="edit_dpt"></a><a href="###" class="del_dpt"></a></span>';
    }
};

function createDptEditBtns(){
    return '<span class="editCurrentItem"><a href="###" class="ok_btn"></a><a href="###" class="cancel_btn"></a></span>';
}

function createOrgTree(topName, departments){
    function createDom(prtDptPath, opt, level){
        var dom ='<ul class="childrenList">';
        for(var j = 0 ; j< opt.length ; j++){
            dom += ['<li id="' + opt[j]['department_id'] + '" department_bt="' + prtDptPath + ' > ' + opt[j]['department_name'] + '" dpt_level=' + level.toString() + '>',
                    createDptNameBar(opt[j]['department_name'], level),
                    createDptOptBtns(level),
                    createDptEditBtns(),
                    '</li>'].join("");
        }
        dom +="</ul>";
        return dom;
    }

    for(var i = 0; i< departments.length ; i++){
        var department_id = departments[i]['department_id'];        
        switch (department_id) {
            case 'top':
                $('#top').append(createDom(topName, departments[i]['sub_departments'], 1))
                break;
            default:
                var prtDptPath = $('#' + department_id).attr('department_bt');
                var prtLevel = $('#' + department_id).attr('dpt_level');             
                $('#' + department_id).append(createDom(prtDptPath, departments[i]['sub_departments'], parseInt(prtLevel) + 1));
                break;
        }
    }
}

function selectedSubDpt(Obj){
    var curChainLevel = $(Obj).attr('chainLevel');
    var curDptId = $(Obj).val();
    if (curDptId === "unselected"){
        return false;
    }
    $('#dptChain').find('.subDptList').each(function(){if (parseInt($(this).attr('chainLevel')) > parseInt(curChainLevel)){$(this).remove()}});
    if ($('#'+curDptId).children('ul.childrenList').children('li').length > 0){
        createCandidateSubDpts(curDptId, curChainLevel, departmentid);
    }

    return false;
};

var createCandidateSubDpts = function(parentDpt, parentChainLevel, exceptDpt){
    var html = '<select class="subDptList" chainLevel="' + (parseInt(parentChainLevel) + 1) + '" onchange="selectedSubDpt(this)">';
        html += '<option value="unselected">请选择' + (parseInt(parentChainLevel) + 1) + '级部门</option>';
    $('#'+parentDpt).children('ul.childrenList').children('li').each(function(){
        if (exceptDpt !== $(this).attr('id')){
            html += '<option value="' + $(this).attr('id') +'">' + $(this).find('a').eq(0).text() + '</option>';
        }
    });
    html +='</select>';
    $('#dptChain').append(html);
}

function loadContent() {
    this.defaultEmployeeTab = "#tab2";
    this.dtTab2 = null;
    this.dtTab3 = null;
}
loadContent.prototype = {
    loadMenu: function () {
        api.loadOrg(companymarkname, function (data) {
            companyid = data['hierarchy']['org_id'];
            var hierarchy = data['hierarchy'];
            var roothtml = ['<div id="org_tree"><ul>',
                  '<li id="top" department_bt="' + hierarchy['short_name'] + '", dpt_level="0"><a href="###" class="dptbar dptLevel_0">' + hierarchy['short_name'] + '</a><span class="item_opertion" style="padding-right:20px;"><a href="###" class="add_subdpt"></a></span>',
                  '</li></ul></div>'].join("");
            $('#menu_contianer').html(roothtml);
            createOrgTree(hierarchy['short_name'], hierarchy['departments']);
            //调用导航菜单插件
            $("#org_tree").Menu();
            //操作cookie
            if ($.cookie("departmentid") && $.cookie("departmentid") != 'top') {
                var rcdId = $.cookie("departmentid");
                var dptPath = [];
                var parentObj = $('#' + rcdId);
                dptPath.push(parentObj);
                while( parseInt(parentObj.attr('dpt_level')) > 1){
                    parentObj = parentObj.parent().parent();
                    dptPath.push(parentObj);
                }
                for (var i = dptPath.length - 1; i > -1; i--){
                    dptPath[i].find('a:first').click();
                }
            } else {
                //expand the first leaf department..
                var foundfirstleafdpt = false;
                $("#org_tree").find('ul.childrenList li').each(function(){
                    if(!foundfirstleafdpt && $(this).find('ul.childrenList li').length === 0){
                        foundfirstleafdpt = true;
                        $(this).find('a.dptbar').click();
                    }
                });
            }
            isEditingDpt = false ;
            $("#ajax_loading").hide();
        });
    },
    loadDepartmentContent: function (departmentid) {
        //api.loadDpt(adminUser, companyid, departmentid, function (data) {
            var html1 = '', obj = [];
            $('#'+departmentid).children('ul.childrenList').children('li').each(function(){
                var id = $(this).attr('id');
                var name = $(this).find('a.dptbar').eq(0).attr('olddata');
                obj.push({'id': id, 'name': name});
            });
            for (var i = 0; i < obj.length; i++) {
                html1 += [
						'<tr>',
                          '<td class="txtleft"><a link_id="' + obj[i].id + '" class="deparemtName" href="#">' + obj[i].name + '</a></td>',
                        '</tr>'
					  ].join("");
            }

            $("#tab1 #departmentCostTable").find('tbody').html(html1);
            $('#department_Overview').siblings().hide();
            $('#department_Overview').show();
            $("#ajax_loading").hide();
            loadContent_Instance.departmentView($("#tab1"));
        //});
    },
    createTable2Html: function(data){
        var html2 = '',
            obj = data['members'],
            len = parseInt(obj.length);
        function auth2disStr(auth){ return auth === 'enable' ? '已开通' : '未开通';}
        for (var i = 0; i < len; i++) {
            var phoneJSON = JSON.parse(obj[i].phone);
            html2 += [
                    '<tr><td style="width:5%"><input id="employeeid_' + obj[i].employee_id + '" type="checkbox" name="echeckbox"></input></td>',
                    '<td class="txtleft"><a href="###" class="employee" name="' + obj[i].name + '" employeeid="' + obj[i].employee_id+ '">' + obj[i].name + '<span class="employ_id">' + obj[i].employee_id + '</span></a></td>',
                    '<td style="width:15%" mobileNum="' + phoneJSON.mobile + '">' + phoneJSON.mobile + '</td>',
                    '<td style="width:20%" emailAddr="' + obj[i].mail + '">' + obj[i].mail + '</td>',
                    '<td style="width:8%" class="blnc" balance="' + parseInt(obj[i].privilege.balance) + '">' + obj[i].privilege.balance + '</td>',
                    '<td style="width:7.2%" class="cba" callbackAuth="' + obj[i].privilege.callback + '">' + auth2disStr(obj[i].privilege.callback) + '</td>',
                    '<td style="width:7.2%" class="voipa" voipAuth="' + obj[i].privilege.voip + '">' + auth2disStr(obj[i].privilege.voip) + '</td>',
                    '<td style="width:7.2%" class="pca" phoneconfAuth="' + obj[i].privilege.phoneconf + '">' + auth2disStr(obj[i].privilege.phoneconf) + '</td>',
                    '<td style="width:7.2%" class="smsa" smsAuth="' + obj[i].privilege.sms + '">' + auth2disStr(obj[i].privilege.sms) + '</td>',
                    '<td style="width:7.2%" class="dca" dataconfAuth="' + obj[i].privilege.dataconf + '">' + auth2disStr(obj[i].privilege.dataconf) + '</td>',
                    '</tr>'
                  ].join("");
        }
        return html2;
    },
    createTable3Html: function(data){
        var html3 = '',
            obj = data,
            len = parseInt(obj.length);
        for (var i = 0; i < len; i++) {
            html3 += [
                    '<tr name="' + obj[i].name + '" employeeid="' + obj[i].jobNumber + '">',
                    '<td class="txtleft">' + obj[i].name + '<span class="employ_id">' + obj[i].jobNumber + '</span></td>',
                    '<td class="width1">' + obj[i].cost + '</td>',
                    '<td class="width1">' + obj[i].cost + '</td>',
                    '<td class="width1">' + obj[i].cost + '</td>',
                    '<td class="width1">' + obj[i].cost + '</td>',
                    '<td class="width1">' + obj[i].cost + '</td>',
                    '<td class="width1">'+ obj[i].cost + '</td>',
                    '</tr>'
                  ].join("");
        }
        return html3;
    },
    showTableRelated: function(tabHref){
        switch (tabHref){
            case "#tab2":
                $('#tab2_supplements').show();
                $('#tab2_operations').show();
                $('#tab3_supplements').hide();
                $('#tab3_operations').hide();
                break;
            case "#tab3":
                $('#tab2_supplements').hide();
                $('#tab2_operations').hide();
                $('#tab3_supplements').show();
                $('#tab3_operations').show();
                break;
            default:
                break;
        }
    },
    refreshTab2: function(){        
        var html = $('#employeeInfoTable tbody').html();
        if (loadContent_Instance.dtTab2 !== null){
            loadContent_Instance.dtTab2.fnDestroy();
        }
        $('#employeeInfoTable tbody').html(html);
        loadContent_Instance.dtTab2 = $('#employeeInfoTable').dataTable({
                "bPaginate": false,
                "bAutoWidth": false,
                "aaSorting": [[1, 'asc']],
                "bScrollCollapse": true,
                "aoColumns": [
                        { "bSortable": false, "bVisible": true},
                        { "sType": "alt-string" },
                        { "bSortable": false, "bVisible": true},
                        { "bSortable": false, "bVisible": true},
                        { "bSortable": false, "bVisible": true},
                        { "bSortable": false, "bVisible": true},
                        { "bSortable": false, "bVisible": true},
                        { "bSortable": false, "bVisible": true},
                        { "bSortable": false, "bVisible": true},
                        { "bSortable": false, "bVisible": true}
                    ]
            });
        document.getElementById('check-all').checked = false;
    },
    refreshTab3: function(){
        var html =  $('#employeeCostTable tbody').html();
        if (loadContent_Instance.dtTab3 !== null){
            loadContent_Instance.dtTab3.fnDestroy();
        }
        $('#employeeCostTable tbody').html(html);
        loadContent_Instance.dtTab3 = $('#employeeCostTable').dataTable({
            "bPaginate": false,
            "bAutoWidth": false,
            "sPaginationType": "full_numbers"
        });     
    },
    loadEmployeeContent: function (departmentid, str) {
        api.loadEmployees(adminUser, companyid, departmentid, function (data) {
            var html2 = loadContent_Instance.createTable2Html(data);
            var html3 = loadContent_Instance.createTable3Html(data);
            $("#tab2 #employeeInfoTable").find("tbody").html(html2);
            $("#tab3 #employeeCostTable").find("tbody").html(html3);
            $('#member_manager').siblings().hide();
            $('#member_manager').show();
            loadContent_Instance.refreshTab2();
            loadContent_Instance.refreshTab3();
            $('#member_manager .content-box-tabs').find('a[href="'+ loadContent_Instance.defaultEmployeeTab +'"]').click();
            $('#tab2').employeeManageOps();
            loadContent_Instance.modifyemployeeinfo($("#tab2"));
            loadContent_Instance.viewEmployeeVoipBill($("#tab3"));
            loadContent_Instance.viewDepartmentBill();
            if (str) { 
                art.dialog.wraning(str, 2); 
            }
            $("#ajax_loading").hide();
			$("#companyid").val(companyid);
			$("#departmentid").val(departmentid);
            if ($(".dataTables_scrollBody").length > 0) $(".dataTables_scrollBody").height(tabheight - 80);
        })
    },
    departmentView: function (obj) {
        obj.find('.deparemtName').die('click').live('click', function () {
            var link_id = $(this).attr('link_id');
            $('#' + link_id).parent().show();
            $('#' + link_id).find('a').eq(0).click();
        });
    },
    viewDepartmentBill: function () {
        $('#viewDptBill').click(function () {
            var url = "departmentBill.htm";
            art.dialog.open(url,
				{ title: '详细账单：' + $('#employ_intro').text(),
				    width: 1000,
				    id: 'departmentBill',
				    height: tabheight + 100,
				    lock: true,
				    fixed: true
				});
        })
    },
    viewEmployeeVoipBill: function (obj) {
        obj.find('a.billDetail').die('click').live('click', function () {
            if ($(this).text() !== '0.00') {
                var url = "employeeVoipBill.htm";
                var name = $(this).parent().parent().attr('name');
                employid = $(this).parent().parent().attr('employeeid');
                art.dialog.open(url,
						{ title: '网络电话账单 <span>姓名：' + name + '</span> <span style="padding-left:35px;">工号：' + employid + '</span><span style="padding-left:35px;">部门：' + $('#employ_intro').text() + '</span>',
						    width: 1000,
						    id: 'employeeVoipBill',
						    height: tabheight + 100,
						    lock: true,
						    fixed: true
						});
            } else {
                art.dialog.wraning('该员工当月没有消费记录！');
            }

        });

    },
    modifyemployeeinfo: function (obj) {
        obj.find('a.employee').die('click').live('click', function () {
            var contentId = document.getElementById('modifyEmployeeInfo'),
                c_this = $(this),
                name = c_this.attr('name'),
                employeeId = c_this.attr('employeeid'),

                balance = c_this.parent().parent().find('.blnc').attr('balance'),
                callbackAuth =  c_this.parent().parent().find('.cba').attr('callbackAuth'),
                voipAuth =      c_this.parent().parent().find('.voipa').attr('voipAuth'),
                phoneconfAuth = c_this.parent().parent().find('.pca').attr('phoneconfAuth'),
                smsAuth =       c_this.parent().parent().find('.smsa').attr('smsAuth'),
                dataconfAuth =  c_this.parent().parent().find('.dca').attr('dataconfAuth');
            $('#modEname').text(name);
            $('#modEid').text(employeeId);
            $('#resetPW').attr("checked", false);
            $('#monthLimit').val(balance);
			
			
            $('#callbackAuth').val(auth2str(callbackAuth));
            $('#voipAuth').val(auth2str(voipAuth));
            $('#phoneconfAuth').val(auth2str(phoneconfAuth));
            $('#smsAuth').val(auth2str(smsAuth));
            $('#dataconfAuth').val(auth2str(dataconfAuth));
            var dialog = art.dialog({
                title: '修改员工信息 所在部门：' + $('#employ_intro').text(),
                content: contentId,
                lock: true,
                fixed: true,
                width: 400,
                height: 250,
                button: [{
                    name: '关闭',
                    callback: function () {
                        $('#totips').hide();
                        $('#floatCorner_top').hide();
                    }
                }, {
                    name: '提交',
                    callback: function () {
                        var resetPW = $('#resetPW').attr('checked');
                        var employeemodifyInfo = {'resetPW':resetPW === true || resetPW === 'checked' ? 'yes' : 'no', 
                                'balance': changeTwoDecimal_f($('#monthLimit').val()),
                                'auth':{'callback':str2auth($('#callbackAuth').val()), 
                                        'voip':str2auth($('#voipAuth').val()), 
                                        'phoneconf':str2auth($('#phoneconfAuth').val()), 
                                        'sms':str2auth($('#smsAuth').val()), 
                                        'dataconf':str2auth($('#dataconfAuth').val())}};

                        console.log('employeemodifyInfo', employeemodifyInfo);
                        api.modEmployee(adminUser, companyid, $('#modEid').text(), employeemodifyInfo, function(data){
                            if (data.status == 'ok') {
                                art.dialog.tips('修改员工信息成功！');
                            } else {
                                art.dialog.error('修改失败，请跟管理员联系！');
                            }
                            loadContent_Instance.loadEmployeeContent(departmentid);
                        });
                    },
                    focus: true
                }]
            });
        })
    },
    add: function (id, current_id, obj, target) {
        api.addDpt(adminUser, companyid, id, obj.val(), function (data) {
        	if (data.status == 'ok') {
			    $.cookie("departmentid", data.department_id);
			    art.dialog.tips('添加成功！');
			    loadContent_Instance.loadMenu();
			} else if (data.reason == 'error_exist_employer') {
                art.dialog.error('该部门还包含员工，不能添加子部门！');
                $("#" + current_id).remove();
            } else {
			    art.dialog.error('添加失败,请检查或跟管理员联系！');
			    $("#" + current_id).remove();
			}
            isEditingDpt = false;
		});
    },
    del: function (id, name) {
        api.delDpt(adminUser, companyid, id, function (data) {    
            if (data.status == 'ok') {
		        var tempid;
		        $('#' + id).prev().attr('id') ? tempid = $('#' + id).prev().attr('id') : tempid = $('#' + id).parent().parent().attr('id');
		        $.cookie("departmentid", tempid);
		        $("#" + id).remove();
		        art.dialog.tips('删除成功！');
		    } else if (data.reason == 'error_exist_employer') {
		        art.dialog.error('该部门还包含员工，不能删除！');
		        $("#" + id).find('a').eq(0).click();
		    } else {
		        art.dialog.error('删除失败，请跟管理员联系！');
		        $("#" + id).find('a').eq(0).click();
		        $.cookie("departmentid", id);
		    }
		    loadContent_Instance.loadMenu();
		});
    },
    edit: function (id, obj, target) {
        var value = obj.val();
        api.modDpt(adminUser, companyid, id, value, function (data) {
        	if (data.status == 'ok') {
			    art.dialog.tips('修改成功！');
			} else {
			    art.dialog.error('修改失败，请跟管理员联系！');
			}
			isEditingDpt = false;
			$.cookie("departmentid", id);
			loadContent_Instance.loadMenu();
		});
    }
}

var loadContent_Instance = new loadContent();
if (!$.cookie("orgId")){
    window.location = "index.html";
}else{
    companyid = $.cookie("orgId");
    companymarkname = $.cookie("markName");
    adminUser = $.cookie("userName");
    $.cookie("orgId", "");
    $('#admin').text(adminUser);
    loadContent_Instance.loadMenu();
}

//退出	  	  
$('#goback').click(function () {
    $.cookie("orgId", "");
    window.location.href = "index.html";
})
//切换内容页
$('ul.content-box-tabs li a').click(
    function() {
        $(this).parent().siblings().find("a").removeClass('current');
        $(this).addClass('current');
        var currentTab = $(this).attr('href');
        $(currentTab).siblings().hide();
        $(currentTab).show();
        $('.tableSupplement').show();
        loadContent_Instance.showTableRelated(currentTab);
        return false; 
    }
)
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
                            api.adminModPW(adminUser, companyid, md5(oldpsw), md5(newpsw1), function (data) {
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

$('#business_statistic_btn').click(function(){
    art.dialog.open('businessStatistic.htm',
    { title: companymarkname + ' 月度业务统计',
        width: 1000,
        id: 'businessStatistic',
        height: tabheight + 100,
        lock: true,
        fixed: true
    });
});

$('#nav_manage_btn').click(function(){
    api.getNavLinks(adminUser, companyid, function(data){
        var navLinks = data['navs'];
        var html = '';    
        for (var i = 0; i < navLinks.length; i++){
            html += ['<tr>',
                     '<td><input name="' + navLinks[i].name + '" type="checkbox" /></td>',
                     '<td>' + navLinks[i].name + '</td>',
                     '<td class="txtleft"><a class="modNavLink" href="###" urlAddr="' + navLinks[i].url + '" navName="' + navLinks[i].name + '">' + navLinks[i].url + '</a></td>',
                     '</tr>'].join("");

        }
        if (navLinks.length > 0){
            $('#navInfoTable').find('tbody').empty();
            $('#navInfoTable').find('tbody').append(html);
            $('.modNavLink').bind('click', modifyNavLink);
        } 
        console.log('got navlinks...');
        $('#nav_management').siblings().hide();
        $('#nav_management').show();
    });
    return false;
})

function modifyNavLink(){
    var _this = $(this), navName=_this.attr('navName'), oldUrlAddr = _this.attr('urlAddr');
    var html = ['<div>',
                    '<table width="480"><tbody width=100%>',
                        '<tr><td>',
                                '<span class="tdTitle">链接名称：</span>',
                                navName,
                            '</td></tr>',
                        '<tr><td>',
                                '<span class="tdTitle">链接地址：</span>',
                                '<input type="text" id="newUrlAddr" value="' + oldUrlAddr + '" style="width:400px"></input>',
                            '</td></tr>',
                    '</tbody></table></div>'].join("");
    var dialog = art.dialog({
        title: '修改导航地址',
        content: html,
        lock: true,
        fixed: true,
        width: 500,
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
                var newUrlAddr = $('#newUrlAddr').val();
                if (newUrlAddr.length === 0){
                    totips($('#newUrlAddr'), 120, '新链接地址不能为空！', -30, -18, 1);
                    $('#newUrlAddr').focus();
                    return false;
                }
                else if (newUrlAddr !== oldUrlAddr){
                    api.modNavLink(adminUser, companyid, navName, newUrlAddr, function(){
                        art.dialog.tips('链接地址修改成功！');
                        _this.attr('href', newUrlAddr).text(newUrlAddr);
                    });
                }
            }
        }]
    });
    return false;
}

$('#addNavLink').click(function(){
    var oldNames = [];
    var html = ['<div>',
                    '<table width="480"><tbody width=100%>',
                        '<tr><td>',
                                '<span class="tdTitle">链接名称：</span>',
                                '<input type="text" id="newName" value="" style="width:400px"></input>',
                            '</td></tr>',
                        '<tr><td>',
                                '<span class="tdTitle">链接地址：</span>',
                                '<input type="text" id="newUrlAddr" value="" style="width:400px"></input>',
                            '</td></tr>',
                    '</tbody></table></div>'].join("");
    $('#navInfoTable').find('a.modNavLink').each(function(){
        oldNames.push($(this).attr('name'));
    });
    console.log('to add navlink....');
    var dialog = art.dialog({
        title: '添加导航',
        content: html,
        lock: true,
        fixed: true,
        width: 500,
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
                var tbl = $('#navInfoTable');
                var newName=$('#newName').val(), newUrlAddr = $('#newUrlAddr').val();
                if (newName.length === 0){
                    totips($('#newName'), 120, '链接名称不能为空！', -30, -18, 1);
                    $('#newName').focus();
                    return false;
                }
                for (var i = 0; i < oldNames.length; i++){
                    if (newName === oldNames[i]){
                        totips($('#newName'), 120, '链接名称已存在，请重新填写！', -30, -18, 1);
                        $('#newName').val('').focus();
                        return false;
                    }
                }
                if (newUrlAddr.length === 0){
                    totips($('#newUrlAddr'), 120, '链接地址不能为空！', -30, -18, 1);
                    $('#newUrlAddr').focus();
                    return false;
                }
                console.log('before api addNavLink...');
                api.addNavLink(adminUser, companyid, newName, newUrlAddr, function(){
                    art.dialog.tips('导航添加成功！');
                    var newItem = ['<tr>',
                                     '<td><input name="' + newName + '" type="checkbox" /></td>',
                                     '<td>' + newName + '</td>',
                                     '<td class="txtleft"><a class="modNavLink" href="###" urlAddr="' + newUrlAddr + '" navName="' + newName + '">' + newUrlAddr + '</a></td>',
                                     '</tr>'].join("");
                    $('#navInfoTable').find('tbody').append(newItem);
                    $('.modNavLink').bind('click', modifyNavLink);
                });
            }
        }]
    });
    return false;
})

$('#delNavLink').click(function(){
    var toDellist = [];
    $('#navInfoTable').find('input[type="checkbox"]').each(function(){
        if ($(this).attr("checked") || $(this).attr("checked")){
            toDellist.push($(this).attr('name'));
        }
    })
    if (toDellist.length > 0){
        api.delNavLinks(adminUser, companyid, toDellist, function(){
            art.dialog.tips('导航删除成功！');
            $('#navInfoTable').find('input[type="checkbox"]').each(function(){
                if ($(this).attr("checked") || $(this).attr("checked")){
                    $(this).parent().parent().remove();
                }
            })
        });
    }else{
        art.dialog.tips('请选择要删除的导航链接！');
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

//左边菜单导航插件
$.fn.Menu = function (options) {
    var defaults = {
        del_dpt: "a.del_dpt",
        add_subdpt: "a.add_subdpt",
        edit_dpt: ".edit_dpt",
        dptLevel_0: ".dptLevel_0",
        dptLevel_1: ".dptLevel_1",
        dptLevel_2: ".dptLevel_2",
        dptLevel_3: ".dptLevel_3",
        dptLevel_4: ".dptLevel_4"
    },
        params = $.extend(defaults, options || {}),
	    _this = $(this), currentLevel, current_obj, id, liLEN, num, current_id, obj;
    var inputDptName = function (current_id, obj, id, opertion, css) {
        var flagtext, inputValue, obj_flag = 0;
        $('#' + current_id).find('.ok_btn').mouseover(function () {
            $(this).parent().show();
        }).die("click").live("click", function () {
            inputValue = obj.val();
            $(this).parent().parent().siblings().each(function () {
                flagtext = $(this).find('a').eq(0).text();
                if (flagtext === inputValue) {
                    obj_flag = 1;
                    return false;
                }
            });
            if ("" != inputValue) {
                if (obj_flag === 0) {
                    //ajax调用更新数据库函数
                    if (opertion == 'add') {
                        loadContent_Instance.add(id, current_id, obj, $(this));
                    } else {
                        loadContent_Instance.edit(id, obj, $(this));
                    }
                    dptLovesMouse($('#' + current_id).find('a').eq(0), css);
                    dptOperations();
                } else {
                    totips($(this).parent().parent().prev(), 90, '已包含此部门！', 15, 15);
                    obj.focus();
                    obj_flag = 0;
                    return false;
                }
            } else {
                obj.focus();
                totips($(this).parent().parent().prev(), 120, '部门名称部能为空！', 15, 15);
            }
        });
        $('#' + current_id).find('.cancel_btn').die('click').live('click', function () {
            if (opertion == 'add') {
                $(this).parent().parent().html('').remove();
            } else {
                obj.parent().html(obj.parent().attr('olddata'));
                $(this).parent().hide();
            }
            isEditingDpt = false;
        })
    };
    var dptLovesMouse = function (obj, css) {
        _this.find(obj).click(function () {
            var c_this = $(this), department_bt;
            new_obj = c_this.parent().find('ul li');
            new_obj_ul = c_this.parent().find('ul').eq(0);
            departmentid = c_this.parent().attr('id');
            department_bt = c_this.parent().attr("department_bt");
            $.cookie("departmentid", departmentid);
            if (!isEditingDpt) {
                _this.find("a").removeClass("level_1_current level_2_current level_3_current level_0_current level_4_current");
                _this.find("li").removeClass("current_flag");
                c_this.parent().siblings().find("ul").slideUp();
                if (new_obj.length === 0) {
                    $('#employ_intro').text(department_bt).attr('currentID', departmentid);
                    c_this.addClass(css + "_current");
                    c_this.parent().addClass("current_flag");
                    loadContent_Instance.loadEmployeeContent(departmentid);
                } else {
                    loadContent_Instance.loadDepartmentContent(departmentid);
                    $('#department_intro').text(department_bt).attr('currentID', departmentid);
                    if (new_obj_ul.css('display') == 'none') {
                        c_this.addClass(css + "_current");
                        c_this.parent().addClass("current_flag");
                        if (obj !== defaults.dptLevel_0) {
                            new_obj_ul.slideDown();
                        }
                    } else {
                        c_this.addClass(css + "_current");
                        c_this.parent().addClass("current_flag");
                        if (obj !== defaults.dptLevel_0) {
                            new_obj_ul.slideUp();
                        }
                    }
                }
            } else {
                totips(_this.find('input'), 120, '请完成当前编辑操作！', -35, -25);
                _this.find('input').focus();
            }
        });
        _this.find(obj).mouseover(function () {
            if (!isEditingDpt) {
                _this.find('.item_opertion').hide();
                if ($(this).parent().find('ul').length > 0) {
                    $(this).next().find('.del_dpt').hide();
                    $(this).next().css('padding-right', '10px');
                }
                $(this).next().show();
            }
        });
        _this.mouseleave(function () {
            $('.item_opertion').hide();
        })
    };
    var dptOperations = function () {
        //编辑部门名称		
        _this.find(defaults.edit_dpt).die('click').live('click', function () {
            if (_this.find('input').length > 0) {
                _this.find('input').focus();
            } else {
                var flag_html = $(this).parent().prev().html();
                var obj = $(this).parent().prev();
                var current_id = $(this).parent().parent().attr('id');
                var current_level = $(this).parent().parent().attr('dpt_level');
                var defaultValue = obj.attr('olddata');
                isEditingDpt = true;
                obj.html('<input name="level_' + current_level + '_dpt_name_txt" value="' + defaultValue + '" class="level_' + current_level + '_dpt_name_txt" type="text" />');
                obj.find('input').val(defaultValue).focus();
                $(this).parent().css('display', 'none');
                $(this).parent().next().show();
                inputDptName(current_id, obj.find('input'), current_id, 'edit');
                //ajax调用更新数据库函数
                return false;
            }
        })
        //删除部门		
        _this.find(defaults.del_dpt).die('click').live('click', function () {
            var id = $(this).parent().parent().attr("id");
            if ($(this).parent().parent().find("li").length > 0) {
                $(this).parent().parent().siblings().find("ul").slideUp();
                $(this).parent().next().next().slideDown();
                totips($(this).parent().parent().prev(), 140, '包含子部门，不能删除！', 15, 15);
            } else {
                //ajax调用更新数据库函数
                loadContent_Instance.del(id, $(this));
            }
            return false;
        })
        //添加子部门		
        _this.find(defaults.add_subdpt).die('click').live('click', function () {
            var curObjParent = $(this).parent().parent();
            var parent_level = curObjParent.attr('dpt_level');
            var parent_id = curObjParent.attr("id");
            var child_id = "child_of_" + curObjParent.attr("id");

            curObjParent.siblings().find("ul").slideUp();
            $(this).parent().next().next().slideDown();

            if (_this.find('input').length > 0) {
                _this.find('input').focus();
            } else {
                if (parseInt(parent_level) < 4){
                    var child_level = (parseInt(parent_level) + 1).toString();
                    if (curObjParent.find('ul').length < 1){
                        curObjParent.append('<ul class="childrenList" style="display:block;"></ul>');
                    }
                    curObjParent.find("ul:first").append('<li id="' + child_id + '"><a href="###" class="dptLevel_' + child_level+ '"><input name="level_' + child_level+ '_dpt_name_txt" class="level_' + child_level+ '_dpt_name_txt" type="text" /></a><span class="item_opertion"><a href="###" class="add_subdpt"></a><a href="###" class="edit_dpt"></a><a href="###" class="del_dpt"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="ok_btn"></a><a href="###" class="cancel_btn"></a></span></li>');

                    $('#' + child_id).find('input').focus();
                    isEditingDpt = true;
                    inputDptName(child_id, $('#' + child_id).find('input'), parent_id, 'add', 'level_' + child_level);
                }
            }
        })
    }
    //点击显示子菜单
    dptLovesMouse(defaults.dptLevel_0, 'level_0');
    dptLovesMouse(defaults.dptLevel_1, 'level_1');
    dptLovesMouse(defaults.dptLevel_2, 'level_2');
    dptLovesMouse(defaults.dptLevel_3, 'level_3');
    dptLovesMouse(defaults.dptLevel_4, 'level_4');
    dptOperations();
}
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
// 表格隔行换色	

//成员管理插件
$.fn.employeeManageOps = function (options) {
    var defaults = {
        targetObj: $(this),  //查找ID 
        checkall:"#check-all",
		importExcel_btn: "#importExcel_btn",       //批量导入 
        delbtn: "#delbtn",       //删除成员按钮 
        addbtn: "#addbtn",       //添加成员按钮 
        tranDptbtn: "#tranDptbtn" //部门调动按钮
    },
    params = $.extend(defaults, options || {}),
	checkitems = $('#tab2 tbody').find("input[type=checkbox]");

    //单选
    $('#tab2 tbody').find("input[type=checkbox]").unbind("click").bind('click', function () {
        var checkedCount = 0, uncheckedCount = 0;
        var curCheckbox = document.getElementById($(this).attr('id'));
        //console.log("cur_checkbox:"+curCheckbox.checked);
        checkitems.each(function(){
            if (document.getElementById($(this).attr('id')).checked) {
                checkedCount += 1;
            } else {
                uncheckedCount += 1;
            }
        });

        //console.log('checked:'+checkedCount+'unchecked:'+uncheckedCount+'total:'+checkitems.length);
        
        if (checkedCount > 0 && checkedCount === checkitems.length)
        {
            document.getElementById('check-all').checked = true;
        }else{
            document.getElementById('check-all').checked = false;
        }
        return true;
    });

    //全选
    $(params.checkall).unbind("click").bind('click', function () {
        //console.log('check-all:'+document.getElementById('check-all').checked);
        if (document.getElementById('check-all').checked) {
            checkitems.each(function(){document.getElementById($(this).attr('id')).checked = true;});
        } else {
            checkitems.each(function(){document.getElementById($(this).attr('id')).checked = false;});
        }
        return true;
    });
	
	//批量导入  
    $(params.importExcel_btn + ', #companyimportExcel_btn').unbind('click').bind('click', function () {
            var importexcel = document.getElementById('importexcel');
			$('#fileToUpload').val('');
			$('#loading').hide();

            $('#uploadfile').attr('uptype', $(this).attr('type') ? $(this).attr('type'):'');

            var dialog = art.dialog({
                title: '批量增加员工',
                content: importexcel,
				id:'importcancel',
                lock: true,
                fixed: true,
                width: 300
            });	
    })	
	


    //添加成员按钮
    $(params.addbtn).unbind('click').bind('click', function () {
        var url = "addEmployee.htm";
        art.dialog.open(url,
				{ title: '添加成员：' + $('#employ_intro').text(),
				    width: 1000,
				    id: 'addMember',
				    height: tabheight + 100,
				    lock: true,
				    fixed: true
				});
    })	
	
    //删除成员按钮		  
    $(params.delbtn).die('click').live('click', function () {
        var del_id = [];
        $('tbody input[type=checkbox]').each(function(){
            if($(this).attr('checked') === 'checked'){
                var idStr = $(this).attr('id');
                del_id.push(idStr.substring(idStr.indexOf('_') + 1));
            }
        });
        if (del_id.length > 0) {
            api.delEmployee(adminUser, companyid, del_id.join(","), function (data) {
                if (data.status == 'ok') {
                    $('tbody input[type=checkbox]').each(function(){
                        if($(this).attr('checked') === 'checked'){
                            //var pos = loadContent_Instance.dtTab2.fnGetPosition($(this).parent().parent().get(0));
                            //loadContent_Instance.dtTab2.fnDeleteRow(pos);
                            $(this).parent().parent().remove();
                        }
                    });
                    loadContent_Instance.refreshTab2();
                    $('#check-all').attr('checked', false);
                    art.dialog.tips('删除成功！');
                } else {
                    art.dialog.error('系统异常，请跟管理员联系！');
                }
            });
        } else {
            art.dialog.wraning('请选择你要删除的员工！');
        }
    })

    //部门调动按钮          
    $(params.tranDptbtn).die('click').live('click', function () {
        var tran_id = [];
        var tran_nameid = [];
        $('tbody input[type=checkbox]').each(function(){
            if($(this).attr('checked') === 'checked'){
                var idStr = $(this).attr('id');
                tran_id.push(idStr.substring(idStr.indexOf('_') + 1));
                tran_nameid.push($(this).parent().next().text());
            }
        });
        var transDpt = function(fromDpt, toDpt){
            api.transEmployee(adminUser, companyid, fromDpt, toDpt, tran_id, function (data) {
                if (data.status == 'ok') {
                    $('tbody input[type=checkbox]').each(function(){
                        if($(this).attr('checked') === 'checked'){
                            //var pos = loadContent_Instance.dtTab2.fnGetPosition($(this).parent().parent().get(0));
                            //loadContent_Instance.dtTab2.fnDeleteRow(pos);
                            $(this).parent().parent().remove();
                        }
                    });
                    loadContent_Instance.refreshTab2();
                    $('#check-all').attr('checked', false);
                    art.dialog.tips('调动部门成功！');
                } else {
                    art.dialog.error('系统异常，请跟管理员联系！');
                }
            });
        }
        var html = ['<div id="transEmployeeDlg">',
                    '<div id="transEmployeeList">调动人员：' + tran_nameid.join("，") + '</div>',
                    '<div>请选择要调动到哪个部门？</div>',
                    '<div id="dptChain"></div>',
                    '</div>'].join("");
        if (tran_id.length > 0) {
            art.dialog({
                title: '调动部门',
                content: html,
                lock: true,
                fixed: true,
                width: 500,
                height: 180,
                button: [{
                    name: '取消',
                    callback: function () {}
                }, {
                    name: '提交',
                    callback: function(){
                        var toDpt=$('#dptChain').find('.subDptList:last').val();
                        if (toDpt === 'unselected'){
                            art.dialog.wraning('请准确选择要调动到哪个部门！');
                            $('#dptChain').find('.subDptList:last').focus();
                            return false;
                        }
                        transDpt(departmentid, toDpt);
                    },
                    focus: true
                }]
            });
            createCandidateSubDpts('top', '0', departmentid);
            
        } else {
            art.dialog.wraning('请选择你要调动的员工！');
        }
    })
}
//向DOM元素填日期
var current_data = new Date();
$('#current_data').html(current_data.getFullYear() + "年" + ((current_data.getMonth() + 1) > 10 ? (current_data.getMonth() + 1) : "0" + (current_data.getMonth() + 1)) + "月" + (current_data.getDate() > 10 ? current_data.getDate() : "0" + current_data.getDate()) + "日");
//表格内容滚动最小高度
$("#tab4").height(tabheight);
$("#tab3").height(tabheight);
$("#tab2").height(tabheight);
$("#tab1").height(tabheight);
window.onresize = function () {
    var clientHeight = document.documentElement.clientHeight > document.body.clientHeight ? document.documentElement.clientHeight : document.body.clientHeight;
    tabheight = clientHeight - 210;
    $("#tab4").height(tabheight);
    $("#tab3").height(tabheight);
    $("#tab2").height(tabheight);
    $("#tab1").height(tabheight);
};

function cancel_btn(){
   $('#totips').hide();
   $('#floatCorner_top').hide();
   $.dialog({ id: "importcancel" }).close();
}

//批量导入函数

$('#uploadfile').click(function(){
	var file= $('#file').val();
	if(file.indexOf('.xls')<=0){
      totips($('#file'), 220, '*只能上传扩展名为XLS的文件！', -40, -18, 1);		
	  return false;
	}
	departmentid = $('#employ_intro').attr('currentid');	
	$("#loading").ajaxStart(function () {
		$(this).show();
	})
	.ajaxComplete(function () {
		$(this).hide();
	});
	$.ajaxFileUpload({
			url: '/lw_upload_user.yaws',
			secureuri: false,
			fileElementId: 'file',		
			//cache:false,
			dataType: 'json',			
			data: {'companyid': companyid, 'departmentid': departmentid},
			success: function (data,status) {
			     var data =	$(data).html();
				 eval("data = " + data); 					 
				// if(data.state === 'ok'){
				 $('.current_flag').find('.dptbar').eq(0).click();
			     var err = data.state;
				 var repeat = data.repeat;
					if (err === 'ok') {
						$.dialog({ id: "importcancel" }).close();
						art.dialog.tips('添加成功！',1.5); 
				        return false;						
					} else if(err === 'fail') {		
						$.dialog({ id: "importcancel" }).close();
                        var uptype = $('#uploadfile').attr('uptype');
                        var excelHref = (uptype && uptype == 'company' ? 'companyemployee.xls' : 'employee.xls' )				
						art.dialog.alert('您上传的文件有误,请按照模板格式上传 <br/>点击：<a href="'+ excelHref +'">下载模板</a>！',1.5);		
						return false;
					} else if(err === 'no_org') {       
                        $.dialog({ id: "importcancel" }).close();               
                        art.dialog.alert('请确认你的公司名称是否正确！',1.5);     
                        return false;
                    }  else if(err == 'repeat'){
						$.dialog({ id: "importcancel" }).close();
                        art.dialog.tips('工号为：' + data.reason + '员工已在库中，其余员工已导入成功！',2);
						return false;

					}else{		
						$.dialog({ id: "importcancel" }).close();
						art.dialog.alert('您上传的文件有误,请按照模板格式上传 <br/>点击：<a href="employee.xls">下载模板</a>！',1.5);		
						return false;				
//	                   if(repeat !== 'ok'){					
//						 var str = "工号为：" +repeat.replace(/(&amp;)/g,'、') +"已经包含在数据库中，<br />" +"其余员工导入成功！";
//					       loadContent_Instance.loadEmployeeContent(departmentid,data.msg);												
//					       $.dialog({ id: "importcancel" }).close();
//						   art.dialog.alert('您上传的excel第 ' + err.replace(' ','、')+ '行数据有误，' + str ,4);
//					   }else{													
//						   loadContent_Instance.loadEmployeeContent(departmentid,data.msg);							
//						   $.dialog({ id: "importcancel" }).close();
//						   art.dialog.alert('您上传的excel第 ' + err.replace(' ','、')+ '数据有误，其余员工导入成功！',2.5);
//						   return false;
//					   }
   		 }

			},
			error: function (data, status, e) {
			
			}
		}
	  )
		return false;
})



