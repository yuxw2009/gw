// JavaScript Document
// 搜索框插件
var companyid = '2', departmentid = '1', employid, flag = 1;
var clientHeight = document.documentElement.clientHeight > document.body.clientHeight ? document.documentElement.clientHeight : document.body.clientHeight;
var tabheight = clientHeight - 210;
$('#admin').text('livecomtester');

function loadContent() {
}
loadContent.prototype = {
    loadMenu: function () {		
        loadContent_Instance.ajax('service.yaws', { 'command': 'load_org', 'companyid': companyid, 't': new Date().getTime() }, function (data) {
            var html = '', html2 ='', 
			    obj = data.department,
				count = obj.length,
				sec_count, third_count, Fourth_count, obj_1, obj_2, obj_3, newID_1, newID_2, newID_3, newID_4;				
			
            html += ['<div id="main_nav"><ul>',
					  '<li id="' + data.id + '" department_bt="' + data.name + '"><a href="###" addmenu_attr="nav_first_item" class="nav_first_item">' + data.name + '</a><span class="item_opertion" style="padding-right:20px;"><a href="###" class="add_submenu"></a></span>',
				   ].join("");	
				   
            if (count > 0) {
                html += ['<ul>'].join("");
				html2 += ['<ul>'].join("");
                for (var i = 0; i < count; i++) {
                    obj[i].department ? sec_count = obj[i].department.length : sec_count = 0;
                    newID_1 = data.id + '-' + obj[i].id;					
                    html += ['<li id="' + newID_1 + '" department_bt="' + data.name + ' > ' + obj[i].name + '"> <a href="###" olddata="' + obj[i].name + '" addmenu_attr="nav_top_item" class="nav_top_item">' + obj[i].name + '</a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span>'
				   ].join("");	
				   			   
                    html2 += ['<li class="topdep" type="' + newID_1 + '" department_bt="' + data.name + ' > ' + obj[i].name + '"> <a href="###" olddata="' + obj[i].name + '" addmenu_attr="nav_top_item" class="nav_top_item">' + obj[i].name + '</a>'
				   ].join("");				   				   
                    if (sec_count > 0) {
                        html += ['<ul>'].join("");
						html2 += ['<ul>'].join("");
                        for (var j = 0; j < sec_count; j++) {
                            obj_1 = obj[i].department[j];
                            newID_2 = newID_1 + '-' + obj_1.id;							
                            html += ['<li id="' + newID_2 + '" department_bt="' + data.name + ' > ' + obj[i].name + ' > ' + obj_1.name + '"><a href="###" olddata="' + obj_1.name + '" addmenu_attr="nav_sub_item" class="nav_sub_item">' + obj_1.name + '</a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span>'
						].join("");						
                            html2 += ['<li type="' + newID_2 + '" department_bt="' + data.name + ' > ' + obj[i].name + ' > ' + obj_1.name + '"><a href="###" olddata="' + obj_1.name + '" addmenu_attr="nav_sub_item" class="nav_sub_item">' + obj_1.name + '</a>'
						].join("");
                            obj_1.department ? third_count = obj_1.department.length : third_count = 0;
                            if (third_count > 0) {
                                html += ['<ul>'].join("");
								html2 += ['<ul>'].join("");
                                for (var k = 0; k < third_count; k++) {
                                    obj_2 = obj_1.department[k];
                                    newID_3 = newID_2 + '-' + obj_2.id;									
                                    html += ['<li id="' + newID_3 + '"  department_bt="' + data.name + ' > ' + obj[i].name + ' > ' + obj_1.name + ' > ' + obj_2.name + '"><a href="###" olddata="' + obj_2.name + '" addmenu_attr="nav_second_item" class="nav_second_item">' + obj_2.name + '</a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span>'
							 ].join("");							 
                                    html2 += ['<li type="' + newID_3 + '"  department_bt="' + data.name + ' > ' + obj[i].name + ' > ' + obj_1.name + ' > ' + obj_2.name + '"><a href="###" olddata="' + obj_2.name + '" addmenu_attr="nav_second_item" class="nav_second_item">' + obj_2.name + '</a>'
							 ].join("");
                                    obj_2.department ? Fourth_count = obj_2.department.length : Fourth_count = 0;
                                    if (Fourth_count > 0) {
                                        html += ['<ul>'].join("");
										html2 += ['<ul>'].join("");
                                        for (var l = 0; l < Fourth_count; l++) {
                                            obj_3 = obj_2.department[l];
                                            newID_4 = newID_3 + '-' + obj_3.id;											
                                            html += ['<li id="' + newID_4 + '" department_bt="' + data.name + ' > ' + obj[i].name + ' > ' + obj_1.name + ' > ' + obj_2.name + ' > ' + obj_3.name + '"><a href="###" olddata="' + obj_3.name + '" addmenu_attr="nav_third_item" class="nav_third_item">' + obj_3.name + '</a><span class="item_opertion"><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li>'
							     ].join("");								 
                                            html2 += ['<li type ="' + newID_4 + '" department_bt="' + data.name + ' > ' + obj[i].name + ' > ' + obj_1.name + ' > ' + obj_2.name + ' > ' + obj_3.name + '"><a href="###" olddata="' + obj_3.name + '" addmenu_attr="nav_third_item" class="nav_third_item">' + obj_3.name + '</a></li>'
							     ].join("");								 
								 
                                        }
                                        html += ['</ul>'].join("");
										html2 += ['</ul>'].join("");
					
                                    }
                                    html += ['</li>'].join("");
									html2 += ['</li>'].join("");
                                }
                                html += ['</ul>'].join("");
								html2 += ['</ul>'].join("");
                            }
                            html += ['</li>'].join("");
							html2 += ['</li>'].join("");
                        }
                        html += ['</ul>'].join("");
						html2 += ['</ul>'].join("");
                    }
                    html += ['</li>'].join("");
					html2 += ['</li>'].join("");
                }
                html += ['</ul>'].join("");
				html2 += ['</ul>'].join("");
            }			
            html += ['</li></ul></div>'].join("");			
            $('#menu_contianer').html(html);			
			$('.deparementList').html(html2);
            //调用导航菜单插件
            $("#main_nav").Menu();
			
			$(".deparementList").find('a').click(function(){
				  var obj = $(this).parent();
				  if(obj.find('ul').length>0){
					  if( obj.find('ul').eq(0).css('display') =='none'){
						  obj.siblings().find("ul").slideUp();
						//obj.find('ul').eq(0).siblings().hide();
					    obj.find('ul').eq(0).slideDown();	
					  }else{
					    obj.find('ul').eq(0).slideUp();						  
					  }
					  			  
				  }else{
					  $(".deparementList").find('li').removeClass('current');
					  obj.addClass('current');				  
				  }
			}).each(function(){
				 var obj = $(this).parent();
				  if(obj.find('ul').length > 0){
					  obj.addClass('havebg');						  
				  }else{
					obj.addClass('nosubnav'); 
				  }
		   });
			
			
            //操作cookie
            if ($.cookie("departmentid")) {
                //	flag = 1 ;
                var link_id = $.cookie("departmentid");
                var arr = link_id.split('-');
                var ul = arr[0];
                for (var i = 1; i < arr.length; i++) {
                    ul = ul + '-' + arr[i];
                    $('#' + ul).parent().show();
                }
                $('#' + link_id).find('a:first').click();
            } else {
                loadContent_Instance.loadDepartmentContent(departmentid);
                $('#department_intro').text($("#main_nav").find('.nav_first_item').eq(0).text());
            }
            $("#ajax_loading").hide();
        });
    },
    loadDepartmentContent: function (departmentid) {
       loadContent_Instance.ajax('service.yaws', { 'command': 'load_sub_org_stat', 'companyid': companyid, 'departmentid': departmentid, 't': new Date().getTime() }, function (data) {
  //    loadContent_Instance.ajax_get('json3.txt', { 'command': 'load_department', 'companyid': companyid, 'departmentid': departmentid, 't': new Date().getTime() }, function (data) {
      //      eval("var data=" + data);
            var html = '', obj = data, len = parseInt(obj.length), memberNum = 0, curMonrate = 0, oneMonrate = 0, twoMonrate = 0, thirMonrate = 0, fourMonrate = 0;
            var first_1 = 'NAN', tw = 'NAN', th = 'NAN', foru = 'NAN';
            html += ['<table id="dataTables_2">',
					 '<thead><tr><th>下属部门</th>',
					 '<th style="width: 15%;">当月实时</th>',
					 '<th style="width: 15%;" id="first_1"></th>',
					 '<th style="width: 15%;" id="tw"></th>',
					 '<th style="width: 15%;" id="th"></th>',
					 '<th style="width: 15%;" id="foru"></th></thead></tbody>',
					].join("");
            for (var i = 0; i < len; i++) {
                var str = obj[i].stat.split(';');
                var str_0, str_1, str_2, str_3, str_4, curM, oneM, twoM, thirM, fourM;

                for (var j = 0; j < str.length; j++) {
                    switch (j) {
                        case 0: str_0 = str[0].split(':');
                            curM = str_0[1];
                            break;
                        case 1: str_1 = str[1].split(':');
                            oneM = str_1[1];
                            first_1 = str_1[0];
                            break;
                        case 2: str_2 = str[2].split(':');
                            twoM = str_2[1];
                            tw = str_2[0];
                            break;
                        case 3: str_3 = str[3].split(':');
                            thirM = str_3[1];
                            th = str_3[0];
                            break;
                        case 4: str_4 = str[4].split(':');
                            fourM = str_4[1];
                            foru = str_4[0];
                            break;
                    }
                }
                curM = parseFloat(curM); oneM = parseFloat(oneM); twoM = parseFloat(twoM); thirM = parseFloat(thirM); fourM = parseFloat(fourM);
                //	first=parseFloat(first); tw=parseFloat(tw); th=parseFloat(th);foru=parseFloat(foru);              
                html += [
						'<tr><td><a link_id="' + obj[i].id + '" class="deparemtName" href="#">' + obj[i].name + '</a></td>',
						'<td style="width:15%;">' + curM + '</td>',
						'<td style="width:15%;">' + oneM + '</td>',
						'<td style="width:15%;">' + twoM + '</td>',
						'<td style="width:15%;">' + thirM + '</td>',
						'<td style="width:15%;">' + fourM + '</td>',
					  ].join("");
                if (!isNaN(curM)) curMonrate = curMonrate + parseFloat(curM);
                if (!isNaN(oneM)) oneMonrate = oneMonrate + parseFloat(oneM);
                if (!isNaN(twoM)) twoMonrate = twoMonrate + parseFloat(twoM);
                if (!isNaN(thirM)) thirMonrate = thirMonrate + parseFloat(thirM);
                if (!isNaN(fourM)) fourMonrate = fourMonrate + parseFloat(fourM);
            }
            html += ['</tbody></table>'].join("");

            $("#tab1").html(html);
            if ('' === first_1) first_1 = 'NAN';
            $('#first_1').text(first_1);
            $('#tw').text(tw);
            $('#th').text(th);
            $('#foru').text(foru);
            $('#curMonrate').text(Math.round(curMonrate * 100) / 100);
            $('#oneMonrate').text(Math.round(oneMonrate * 100) / 100);
            $('#twoMonrate').text(Math.round(twoMonrate * 100) / 100);
            $('#thirMonrate').text(Math.round(thirMonrate * 100) / 100);
            $('#fourMonrate').text(Math.round(fourMonrate * 100) / 100);
            $('#member_manager').hide();
            $('#department_Overview').show();
            $("#ajax_loading").hide();
            loadContent_Instance.departmentView($("#tab1"));
        });
    },
    loadEmployeeContent: function (departmentid, str) {
   loadContent_Instance.ajax('service.yaws', { 'command': 'load_employer', 'companyid': companyid, 'departmentid': departmentid, 't': new Date().getTime() }, function (data) {
  //  loadContent_Instance.ajax_get('json2.txt', { 'command': 'load_employee', 'companyid': companyid, 'departmentid': departmentid, 't': new Date().getTime() }, function (data) {
      //       eval("var data=" + data);
            var html = '',
                   //   obj = data.data,
                   obj = data,
				   len = parseInt(obj.length);
            html += ['<table id="dataTables">',
					 '<thead><tr><th style="width: 10%"><input class="check-all" id="check-all" type="checkbox" /></th>',
					 '<th style="">姓名工号</th>',
					 '<th style="width:18%">手机号码1</th>',
					 '<th style="width:18%"><span>手机号码2</span></th>',
					 '<th style="width:18%">每月额度</th>',
					 '<th style="width:18%">当月账单</th></tr></thead><tbody>',
					].join("");
            for (var i = 0; i < len; i++) {
                html += [
						'<tr><td style="width:10%"><input id="' + obj[i].jobNumber + '" type="checkbox" /></td>',
						'<td class="txtleft"><a href="###" class="employee" name="' + obj[i].name + '" jobnumber="' + obj[i].jobNumber + '">' + obj[i].name + '<span class="employ_id">' + obj[i].jobNumber + '</span></a></td>',
						'<td style="width:18%" phone1="' + obj[i].phone1 + '">' + obj[i].phone1 + '</td>',
						'<td style="width:18%" phone2="' + obj[i].phone2 + '">' + obj[i].phone2 + '</td>',
						'<td style="width:18%" banlance="' + obj[i].banlance + '">' + obj[i].banlance + '</td>',
						'<td style="width:18%" banlance="' + obj[i].cost + '"> <a href="###" class="billDetail">' + obj[i].cost + '</a></td></tr>'
				      ].join("");
            }
            html += ['</tbody></table>'].join("");


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

            $("#tab2").html(html);
            $('#department_Overview').hide();
            $('#member_manager').show();
            $('#dataTables').dataTable({
                "bPaginate": false,
                "bAutoWidth": false,
                "sScrollY": "410px",
                "aaSorting": [[1, 'asc']],
                "aoColumns": [
						{ "asSorting": ["asc"] },
						{ "sType": "alt-string" },
						{ "sType": 'string-case' },
						{ "sType": 'string-case' },
						{ "sType": 'string-case' },
						{ "sType": "numeric-comma" }
					],
                //"bStateSave": true,
                "bScrollCollapse": true
            });
            $('#check-all').cheboxInput();
            loadContent_Instance.modifyemployeeinfo($("#tab2"));
            loadContent_Instance.viewBilldetail($("#tab2"));
            loadContent_Instance.bill_Statistics();
            if (str) { art.dialog.wraning(str, 2); }
            $("#ajax_loading").hide();
			$("#companyid").val(companyid);
			$("#departmentid").val(departmentid);
            if ($(".dataTables_scrollBody").length > 0) $(".dataTables_scrollBody").height(tabheight - 80);
			
			
        })
    },
    departmentView: function (obj) {
        obj.find('.deparemtName').die('click').live('click', function () {
            var link_id = $(this).attr('link_id');
            var arr = link_id.split('-');
            var ul = arr[0];
            for (var i = 1; i < arr.length; i++) {
                ul = ul + '-' + arr[i];
                $('#' + ul).parent().show();
            }
            $('#' + link_id).find('a').eq(0).click();
        });
    },
    bill_Statistics: function () {
        $('#Statistics').click(function () {
            var url = "department_detail.htm";
            art.dialog.open(url,
				{ title: '账单统计：' + $('#employ_intro').text(),
				    width: 1000,
				    id: 'departmentDetail',
				    height: tabheight + 100,
				    lock: true,
				    fixed: true
				});
        })
    },
    viewBilldetail: function (obj) {
        obj.find('a.billDetail').die('click').live('click', function () {
            if ($(this).text() !== '0.00') {
                var url = "Billdetail.htm";
                var name = $(this).parent().parent().find('a').attr('name');
                employid = $(this).parent().parent().find('a').attr('jobnumber');
                art.dialog.open(url,
						{ title: '<span>姓名：' + name + '</span> <span style="padding-left:35px;">工号：' + employid + '</span><span style="padding-left:35px;">部门：' + $('#employ_intro').text() + '</span>',
						    width: 1000,
						    id: 'Billdetail',
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
            var mobile_test = function (str) {
                reg = /^[+]{0,1}(0){2}(\d){1,3}[ ]?([-]?((\d)|[ ]){11})+$/,
				 flag_2 = reg.test(str);
                return flag_2;
            };
            var content_new = document.getElementById('modifyEmployeeInfo'),
			    c_this = $(this), reset_bill,
			    name = c_this.attr('name'),
				jobnumber = c_this.attr('jobnumber'),
			    phone1 = c_this.parent().next().attr('phone1'),
			    phone2 = c_this.parent().next().next().attr('phone2'),
			    banlance = c_this.parent().next().next().next().attr('banlance'),
				employermodify = {};
            function changeTwoDecimal_f(x) {
                var f_x = parseFloat(x);
                if (isNaN(f_x)) {
                    return x;
                }
                f_x = Math.round(f_x * 100) / 100;
                var s_x = f_x.toString();
                var pos_decimal = s_x.indexOf('.');
                if (pos_decimal < 0) {
                    pos_decimal = s_x.length;
                    s_x += '.';
                }
                while (s_x.length <= pos_decimal + 2) {
                    s_x += '0';
                }
                return s_x;
            }
            $('#password').attr('checked', false);
            $('#name').text(name);
            $('#jobnumber').text(jobnumber);
            $('#phone1').val(phone1);
            $('#phone2').val(phone2);
            $('#banlance').val(banlance);
            var dialog = art.dialog({
                title: '个人信息修改',
                content: content_new,
                lock: true,
                fixed: true,
                width: 300,
                height: 250,
                button: [{
                    name: '关闭',
                    callback: function () {
                        $('#totips').hide();
                        $('#floatCorner_top').hide();
                    }
                    // focus: true
                }, {
                    name: '提交',
                    callback: function () {
                        phone1 = $('#phone1').val(); 
						                
                        if('' !== phone1){
                            if (!mobile_test(phone1)) {
                                totips($('#phone1'), 220, '*请输入正确的手机号，须包含国家码！', -30, -38, 1);
                                $('#phone1').focus();
                                return false;
                            } else {
                                $('#modify_tips').hide();
                                phone2 = $('#phone2').val();
                                if ('' !== phone2) {
                                    if (!mobile_test(phone2)) {
                                        totips($('#phone2'), 220, '*请输入正确的手机号，须包含国家码！', -30, -38, 1);
                                        $('#phone2').focus();
                                        return false;
                                    } else if (phone2 === phone1) {
                                        totips($('#phone2'), 220, '*两个手机号不能相同，手机号2可为空', -30, -38, 1);
                                        $('#phone2').focus();
                                        return false;
                                    }
                                }
							 }
								
						}
                                balance = $('#banlance').val();
                                reset_bill = $('#password').attr('checked');
                                reset_bill === true || reset_bill === 'checked' ? reset_bill = '1' : reset_bill = '0';
                                employermodify = { 'phone1': phone1, 'phone2': phone2, 'balance': changeTwoDecimal_f(balance), 'reset': reset_bill }						
                                employermodify = JSON.stringify(employermodify);
                                $.post("service.yaws", { 'command': 'modify_employer', 'companyid': companyid, 'employerid': jobnumber, 'employermodify': employermodify }, function (data) {
                                    if (data.message == 'ok') {
                                        c_this.parent().next().text(phone1).attr('phone1', phone1);
                                        c_this.parent().next().next().text(phone2).attr('phone2', phone2);
                                        c_this.parent().next().next().next().text(balance).attr('banlance', balance);
                                        art.dialog.tips('修改成功！');
                                    } else {
                                        art.dialog.error('修改失败，请跟管理员联系！');
                                    }
                                });
                       
            
                    },
                    focus: true
                }]
            });
        })
    },
    ajax: function (url, opt, fun) {
        $.ajax({
            type: "post",
            url: url,
            dataType: "json",
            data: opt,
            contentType: "application/json; charset=utf-8",
            beforeSend: function () { $("#ajax_loading").show(); },
            success: function (data) {
                fun(data);
            }
        });
    },
    ajax_get: function (url, opt, fun) {
        $.ajax({
            type: "get",
            url: url,
            dataType: "html",
            beforeSend: function () { $("#ajax_loading").show(); },
            data: opt,
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                fun(data);
            }
        });
    },
    add: function (id, current_id, obj, target) {
        $.post("service.yaws",
			 { "command": "add_org", "companyid": companyid, "departmentid": id, "departmentname": obj.val() }, function (data) {
			     if (data.id) {
			         flag = 1;
			         $.cookie("departmentid", data.id);
			         art.dialog.tips('添加成功！');
			         loadContent_Instance.loadMenu();
			     } else {
			         flag = 1;
			         data.message === 'error_exist_employer' ? art.dialog.error('该部门还包含员工，不能添加子部门！') : art.dialog.error('添加失败,请检查或跟管理员联系！');
			         $("#" + current_id).remove();
			     }
			 });
    },
    del: function (id, name) {
        $.post("service.yaws",
			 { "command": "del_org", "companyid": companyid, "departmentid": id }, function (data) {
			     if (data.message == 'ok') {
			         var tempid;
			         $('#' + id).prev().attr('id') ? tempid = $('#' + id).prev().attr('id') : tempid = $('#' + id).parent().parent().attr('id');
			         $.cookie("departmentid", tempid);
			         $("#" + id).remove();
			         art.dialog.tips('删除成功！');
			     } else if (data.message == 'error_exist_employer') {
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
        $.post("service.yaws",
			 { "command": "modify_org", "companyid": companyid, "departmentid": id, "departmentname": value }, function (data) {
			     if (data.message == 'ok') {

			         art.dialog.tips('修改成功！');
			     } else {
			         art.dialog.error('修改失败，请跟管理员联系！');
			     }
			     flag = 1;
			     $.cookie("departmentid", id);
			     loadContent_Instance.loadMenu();
			 });
    }
}

var loadContent_Instance = new loadContent();
loadContent_Instance.loadMenu();
//退出	  	  
$('#goback').click(function () {
    $.cookie("userName", "");
    window.location.href = "login.htm";
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

                            $.ajax({
                                type: "post",
                                url: 'service.yaws',
                                cache: false,
                                async: false,
                                dataType: "json",
                                data: { 'command': 'modify_password', 'username': $.cookie("userName"), 'oldpassword': oldpsw, 'newpassword': newpsw1 },
                                contentType: "application/json; charset=utf-8",
                                success: function (data) {
                                    if (data.message == 'ok') {
                                        art.dialog.tips('密码修改成功！');
                                        re = 1;
                                    } else {
                                        totips($('#oldpsw'), 120, '初始密码有误！', -30, -18, 1);
                                        $('#oldpsw').focus();
                                        re = 0;
                                        return false;
                                    }
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
        del_menu: "a.del_menu",
        add_submenu: "a.add_submenu",
        nav_first_item: ".nav_first_item",
        nav_top_item: ".nav_top_item",
        nav_sub_item: ".nav_sub_item",
        nav_second_item: ".nav_second_item",
        edit_submenu: ".edit_submenu",
        nav_third_item: ".nav_third_item"
    },
        params = $.extend(defaults, options || {}),
	    _this = $(this), currentclass, current_obj, id, liLEN, num, current_id, obj;
    var newItemFun = function (current_id, obj, id, opertion, css) {
        var flagtext, inputValue, obj_flag = 0;
        $('#' + current_id).find('.add_comint').mouseover(function () {
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
                    handler($('#' + current_id).find('a').eq(0), css);
                    option_item();
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
        $('#' + current_id).find('.cancle_btn').die('click').live('click', function () {
            if (opertion == 'add') {
                $(this).parent().parent().html('').remove();
            } else {
                obj.parent().html(obj.parent().attr('olddata'));
                $(this).parent().hide();
            }
            flag = 1;
        })
    };
    var handler = function (obj, css) {
        _this.find(obj).click(function () {
            var c_this = $(this), department_bt;
            new_obj = c_this.parent().find('ul li');
            new_obj_ul = c_this.parent().find('ul').eq(0);
            departmentid = c_this.parent().attr('id');
            department_bt = c_this.parent().attr("department_bt");
            $.cookie("departmentid", departmentid);
            if (flag == 1) {
                _this.find("a").removeClass("nav_top_current nav_sub_current nav_second_current nav_first_current nav_third_current");
                _this.find("li").removeClass("current_flag");
                c_this.parent().siblings().find("ul").slideUp();
                if (new_obj.length == '0') {
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
                        if (obj !== defaults.nav_first_item) {
                            new_obj_ul.slideDown();
                        }
                    } else {
                        c_this.addClass(css + "_current");
                        c_this.parent().addClass("current_flag");
                        if (obj !== defaults.nav_first_item) {
                            new_obj_ul.slideUp();
                        }
                    }
                }
            } else {
                totips(_this.find('input'), 120, '请完成当前编辑操作！', -35, -25);
                _this.find('input').focus();
            }
        }).mouseover(function () {
            if (flag == 1) {
                _this.find('.item_opertion').hide();
                if ($(this).parent().find('ul').length > 0) {
                    $(this).next().find('.del_menu').hide();
                    $(this).next().css('padding-right', '10px');
                }
                $(this).next().show();
            }
        });
        _this.mouseleave(function () {
            $('.item_opertion').hide();
        })
    };
    var option_item = function () {
        //编辑应用		
        _this.find(defaults.edit_submenu).die('click').live('click', function () {
            if (_this.find('input').length > 0) {
                _this.find('input').focus();
            } else {
                var flag_html = $(this).parent().prev().html();
                var obj = $(this).parent().prev();
                var current_id = $(this).parent().parent().attr('id');
                var defaultValue = obj.attr('olddata');
                flag = 0;
                obj.html('<input name="menutext2" value="' + defaultValue + '" class="menutext2" type="text" />');
                obj.find('input').val(defaultValue).focus();
                $(this).parent().css('display', 'none');
                $(this).parent().next().show();
                newItemFun(current_id, obj.find('input'), current_id, 'edit');
                //ajax调用更新数据库函数
                return false;
            }
        })
        //删除应用		
        _this.find(defaults.del_menu).die('click').live('click', function () {
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
        //添加二级部门		
        _this.find(defaults.add_submenu).die('click').live('click', function () {
            current_obj = $(this);
            var curObjParent = current_obj.parent().parent();
            var curObjParent_len = curObjParent.find('ul').length;
            currentclass = current_obj.parent().prev().attr("addmenu_attr");
            curObjParent.siblings().find("ul").slideUp();
            current_obj.parent().next().next().slideDown();
            id = curObjParent.attr("id");
            $('#' + id).find("#" + id + "-1").length > 0 ? liLEN = $('#' + id).find("#" + id + "-1").siblings().length : liLEN = -1;
            num = parseInt(liLEN) + 2;
            num == 2 ? num = 1 : num = num;
            current_id = id + "-" + num + "_temp";
            if (_this.find('input').length > 0) {
                _this.find('input').focus();
            } else {
                switch (currentclass) {
                    case 'nav_first_item':
                        if (curObjParent_len > 0) {
                            curObjParent.find("ul:first").append('<li id="' + current_id + '"> <a href="###"  addmenu_attr="nav_top_item"  class="nav_top_item"><input name="menutext3" class="menutext3" type="text" /></a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li>');
                        } else {
                            curObjParent.append('<ul style="display:block;"><li id="' + current_id + '"> <a href="###"  addmenu_attr="nav_top_item"  class="nav_top_item"><input name="menutext3" class="menutext3" type="text" /></a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li></ul>');
                        }
                        $('#' + current_id).find('input').focus();
                        flag = 0;
                        newItemFun(current_id, $('#' + current_id).find('input'), id, 'add', 'nav_top');
                        break;
                    case 'nav_top_item':
                        if (curObjParent_len > 0) {
                            curObjParent.find("ul:first").append('<li id="' + current_id + '"><a href="###"  addmenu_attr="nav_sub_item" class="nav_sub_item"><input name="menutext" class="menutext" type="text" /></a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li>');
                        } else {
                            curObjParent.append('<ul style="display:block;"><li id="' + current_id + '"><a href="###"  addmenu_attr="nav_sub_item" class="nav_sub_item"><input name="menutext" class="menutext" type="text" /></a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li></ul>');
                        }
                        $('#' + current_id).find('input').focus();
                        flag = 0;
                        newItemFun(current_id, $('#' + current_id).find('input'), id, 'add', 'nav_sub');
                        break;
                    case 'nav_sub_item':
                        if (curObjParent_len > 0) {
                            curObjParent.find("ul:first").append('<li id="' + current_id + '"><a href="###"  addmenu_attr="nav_second_item"  class="nav_second_item"><input name="menutext2" class="menutext2" type="text" /></a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li>');
                        } else {
                            curObjParent.append('<ul style="display:block;"><li id="' + current_id + '"><a href="###" addmenu_attr="nav_second_item" class="nav_second_item"><input name="menutext2" class="menutext2"  type="text" /></a><span class="item_opertion"><a href="###" class="add_submenu"></a><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li></ul>');
                            curObjParent.find("ul").show();
                        }
                        $('#' + current_id).find('input').focus();
                        flag = 0;
                        newItemFun(current_id, $('#' + current_id).find('input'), id, 'add', 'nav_second');
                        break;
                    case 'nav_second_item':
                        if (curObjParent_len > 0) {
                            curObjParent.find("ul:first").append('<li id="' + current_id + '"><a href="###"  addmenu_attr="nav_third_item" class="nav_third_item"><input name="menutext2" class="menutext2" type="text" /></a><span class="item_opertion"><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li>');
                        } else {
                            curObjParent.append('<ul style="display:block;"><li id="' + current_id + '"><a href="###" addmenu_attr="nav_third_item" class="nav_third_item"><input name="menutext2" class="menutext2"  type="text" /></a><span class="item_opertion"><a href="###" class="edit_submenu"></a><a href="###" class="del_menu"></a></span><span class="editCurrentItem" style="display:inline;"><a href="###" class="add_comint"></a><a href="###" class="cancle_btn"></a></span></li></ul>');
                            curObjParent.find("ul").show();
                        }
                        $('#' + current_id).find('input').focus();
                        flag = 0;
                        newItemFun(current_id, $('#' + current_id).find('input'), id, 'add', 'nav_third');
                        break;
                }
            }
        })
    }
    //点击显示子菜单
    handler(defaults.nav_first_item);
    handler(defaults.nav_top_item, 'nav_top');
    handler(defaults.nav_sub_item, 'nav_sub');
    handler(defaults.nav_second_item, 'nav_second');
    handler(defaults.nav_third_item, 'nav_third');
    option_item();
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
$.fn.cheboxInput = function (options, url) {
    var defaults = {
        target_id: "#tab2",  //查找ID 
		importExcel_btn: "#importExcel_btn",       //批量导入 
        delbtn: "#delbtn",       //删除成员按钮 
        addbtn: "#addbtn" ,     //添加成员按钮 '
		switchdepartment: "#switchdepartment"       //添加成员按钮		
    },
        params = $.extend(defaults, options || {}),
	    _this = $(this),
		obj = $(params.target_id).find("input[type=checkbox]"),
		falg = 1;
    obj.click(function () {
        if ($(this).attr("checked") == "checked") {
        } else {
            _this.attr("checked", false);
        }
    })
    _this.unbind("click").bind('click', function () {
        obj.each(function () {
            if ($(this).attr("checked") == false) {
            } else {
                falg = 0;
                return;
            }
        })
        if (falg == 0 && _this.attr("checked") == "checked") {
            obj.attr("checked", true);
            falg = 1;
        } else {
            obj.attr("checked", false);
            _this.attr("checked", false);
        }
    })
	
	//批量导入  
    $(params.importExcel_btn).unbind('click').bind('click', function () {
		    var importexcel = document.getElementById('importexcel');
			$('#fileToUpload').val('');
			$('#loading').hide();		
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
        var url = "addMember.htm";
        art.dialog.open(url,
				{ title: '添加成员：' + $('#employ_intro').text(),
				    width: 1000,
				    id: 'addMember',
				    height: tabheight + 100,
				    lock: true,
				    fixed: true
				});
    })	
	
    $(params.switchdepartment).unbind('click').bind('click', function () {
			var switch_id = $(':checkbox[checked=checked]').map(function () {
				if (this.id !== 'check-all') {
					return this.id;
				}
			}).get().join(',');		
		   if(switch_id == ''){
			 art.dialog.wraning('请选择你要转换部门的员工！');
			 return false;
		   }

        art.dialog({
			 content: $('.deparementList')[0],
			 title: '请选择要转移的部门',
			 width: 600,
			 id: 'switchdepartmentdialog',
			 height: 400,
			 lock: true,
			 fixed: true,
			 ok:function(){				 				 				
			       var  depart_id =  $('.deparementList').find('.current').attr('type');
				   console.log(switch_id)
					$.post("service.yaws", { "command": "trans_dep", "companyid": companyid, 'eid': switch_id, 'new':  depart_id }, function (data) {
						if (data.message == 'ok') {
							 $(':checkbox[checked=checked]').map(function () {
							 	 if (this.id !== 'check-all') {
									$(this).parent().parent().remove();
									$('#check-all').attr('checked', false);
								 }
							 })
														
						    art.dialog.tips('操作成功！');	
						} else {
							art.dialog.error('系统异常，请跟管理员联系！');
						}
					});
				
						 
			 },
			 cancel: true		
		});
    })	
		
	
    //删除成员按钮		  
    $(params.delbtn).die('click').live('click', function () {
        var del_id = $(':checkbox[checked=checked]').map(function () {
            if (this.id !== 'check-all') {
                return this.id;
            }
        }).get().join(',');
        if ('' !== del_id) {
            $.post("service.yaws", { "command": "del_employer", "companyid": companyid, 'employeridlist': del_id }, function (data) {
                if (data.message == 'ok') {
                    $(':checkbox[checked=checked]').map(function () {
                        if (this.id !== 'check-all') {
                            $(this).parent().parent().remove();
                            $('#check-all').attr('checked', false);
                        }
                    })
                    art.dialog.tips('删除成功！');
                } else {
                    art.dialog.error('系统异常，请跟管理员联系！');
                }
            });
        } else {
            art.dialog.wraning('请选择你要删除的项！');
        }
    })
}
//向DOM元素填日期
var current_data = new Date();
$('#current_data').html(current_data.getFullYear() + "年" + ((current_data.getMonth() + 1) > 10 ? (current_data.getMonth() + 1) : "0" + (current_data.getMonth() + 1)) + "月" + (current_data.getDate() > 10 ? current_data.getDate() : "0" + current_data.getDate()) + "日");
//表格内容滚动最小高度
$("#tab2").height(tabheight);
$("#tab1").height(tabheight);
window.onresize = function () {
    var clientHeight = document.documentElement.clientHeight > document.body.clientHeight ? document.documentElement.clientHeight : document.body.clientHeight;
    $("#tab2").height(tabheight);
    $("#tab1").height(tabheight);
};


function cancel_export(){
   $.dialog({ id: "exportexcel" }).close();
}	
	
function cancel_btn(){
   $('#totips').hide();
   $('#floatCorner_top').hide();
   $.dialog({ id: "importcancel" }).close();

}

function openwin1(url) {
	var a = document.createElement("a");
	a.setAttribute("href", url);
	a.setAttribute("target", "_blank");
	a.setAttribute("id", "openwin_blank");
	document.body.appendChild(a);
	if (document.all) {
		a.click();
	}
	else {
		var evt = document.createEvent("MouseEvents");
		evt.initEvent("click", true, true);	
		a.dispatchEvent(evt);
	}  
//	window.open(url,'daochu')


}   


function export_excel(){
  var data = new Date(), year = parseInt(data.getFullYear(), 10), month = parseInt(data.getMonth()+1, 10),  premonth , pretmonth;	  
  var html2 ; 
  if(month == 1){
	premonth = 12;
	pretmonth = 11;	
	html2 = '<option selected="selected">'+ year +'</option><option>'+ (year-1) +'</option>';   	  
  }else if(month ==2 ){
	premonth = 1;
	pretmonth = 12;	
	html2 = '<option selected="selected">'+ year +'</option><option>'+ (year-1) +'</option>';   	 
  }else{
	premonth = parseInt(month)-1;
	pretmonth = parseInt(month)-2;	 
	html2 = '<option selected="selected">'+ year +'</option>';  
  }	  
  var html = [
		'<option selected="selected">'+ month +'</option>', 
		'<option>'+ premonth +'</option>' ,
		'<option>'+ pretmonth +'</option>'
	  ].join("");	   
   $('#export_month').html(html);
   $('#export_year').html(html2);
}
   export_excel();
   $('#export_xls').click(function(){
		var exportexcel = document.getElementById('exportexcel');   
		var dialog = art.dialog({
			title: '导出月份账单',
			content: exportexcel,
			id:'exportexcel',
			lock: true,
			fixed: true,
			width: 300
		});	
   })
   
  $('#export_excel_btn').click(function(){
	  var year =  $('#export_year').val();
	  var month = $('#export_month').val();
	   loadContent_Instance.ajax('my_excel.yaws', { 'year': year.toString(), 'month': month.toString(), 't': new Date().getTime() }, function (data) { 
	      $('#ajax_loading').hide();
		  if('db_err' !== data['message']&& data['message'] !== 'excel_err'){
			openwin1(data['message']);
		    $.dialog({ id: "exportexcel" }).close();
		  }	else{
			 art.dialog.wraning('导出文件失败！');  
		  }	   
	   })
  })


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
			url: 'my_upload.yaws',
			secureuri: false,
			fileElementId: 'file',		
			//cache:false,
			dataType: 'json',
			data: {'companyid': companyid, 'departmentid': departmentid},
			success: function (data,status) {	
				
			     var data =	$(data).html();
				     eval("data = " + data);   
				 var err = data.err;
				 var repeat = data.repeat;
					if (err === '') {										
						if(repeat !== 'ok'){		
						  var str = "工号为:" + repeat.replace(/(&amp;)/g,'、') +"已经包含在数据库中！";
					       loadContent_Instance.loadEmployeeContent(departmentid,data.msg);												
					       $.dialog({ id: "importcancel" }).close();
						   art.dialog.alert(str);						   						   					
					    }else{									
						   loadContent_Instance.loadEmployeeContent(departmentid,data.msg);												
					       $.dialog({ id: "importcancel" }).close();
						   art.dialog.tips('添加成功！',1.5);
						   return false;
						 }
					} else if(err === 'xls_err') {
						art.dialog.alert('您上传的文件有,请按照模板格式上传 <br/>点击：<a href="employee.xls">下载模板</a>！',1.5);		
						return false;				
					} else if(err === 'db_err'){
						$.dialog({ id: "importcancel" }).close();
                        art.dialog.alert('系统数据库出现异常，请跟管理员联系！',2);
						return false;

					}else{						
						if(repeat !== 'ok'){					
						  var str = "工号为：" +repeat.replace(/(&amp;)/g,'、') +"已经包含在数据库中，<br />" +"其余员工导入成功！";
					       loadContent_Instance.loadEmployeeContent(departmentid,data.msg);												
					       $.dialog({ id: "importcancel" }).close();
						   art.dialog.alert('您上传的excel第 ' + err.replace(' ','、')+ '行数据有误，' + str ,4);	
						     						   					
					    }else{													
							loadContent_Instance.loadEmployeeContent(departmentid,data.msg);							
							$.dialog({ id: "importcancel" }).close();
							art.dialog.alert('您上传的excel第 ' + err.replace(' ','、')+ '数据有误，其余员工导入成功！',2.5);
							return false;
						 }
				     }
			},
			error: function (data, status, e) {
			
			}
		}
	  )
		return false;

})

