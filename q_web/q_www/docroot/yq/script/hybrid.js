var externalEmployees = {};  // {uuid:{uuid:uuid,markname:m, name:n, eid:eid, phone:p}}
var externalEnterpris_logo = lw_lang.ID_EXT_CONTANTS ;
var external_dep_id = 'external';
var external_members = [];


function getExternalEnterpris_a(){
	return $('.members_name[title="'+externalEnterpris_logo+'"]').parent();
}

var hybrid_globals = {
    name_default : lw_lang.ID_EXT_ACCOUNT,
    phone_default : lw_lang.ID_EXT_PHONE,
    mail_default : lw_lang.ID_EXT_EMAIL
};
var addPendingPartner =function (e) {
    var eidAtMarkname = ($('#add_partner').val() == hybrid_globals.name_default ? '' : $('#add_partner').val());
    var phone = ($('#add_partner_phone').val() == hybrid_globals.phone_default ? '' : $('#add_partner_phone').val());
    var mail = ($('#add_partner_mail').val() == hybrid_globals.mail_default ? '' : $('#add_partner_mail').val());
/*    var is_already_in=getExternalDepObj().find('.employ_id').filter(function() {return $(this).text() == eidAtMarkname}).length >0;
    if (is_already_in) {
        LWORK.msgbox.show(lw_lang.ID_EXT_ADDED, 5, 1000);
        return;
    }*/
    if ('' != eidAtMarkname) {  //yxwnext
        e = e || window.event;
        e.preventDefault();
        e.stopPropagation();
        var deleteStr=$('<a href="###" class="del_member" style="display: none;">×</a>')
        var partnerTuple = eidAtMarkname.split('@');
        var account = partnerTuple[0];
        var markname = partnerTuple[1];
        var li = $('<li>').text(eidAtMarkname).attr('account', account).attr('markname',markname).attr('mail',mail).attr('phone',phone).append(deleteStr);

        if ($('#addpartnerlist li[account="'+account+'"]'+'[markname="'+markname+'"]').length == 0){
            $('#addpartnerlist').append(li);
            li.hover(function () {$(this).find('.del_member').show();}, 
                    function () {$(this).find('.del_member').hide();}
                )
            $('.del_member').click(function () {$(this).parent().remove();})
        }

        $('#add_partner').val(hybrid_globals.name_default);
        $('#add_partner_phone').val(hybrid_globals.phone_default);
        $('#add_partner_mail').val(hybrid_globals.mail_default);
    }
}

function addExternalPartnerUrl(item) {
    eidAtMarkname = (item && item.eidAtMarkname) ? item.eidAtMarkname : hybrid_globals.name_default;
    mail = (item && item.mail) ? item.mail : hybrid_globals.mail_default;
    phone = (item && item.phone) ? item.phone : hybrid_globals.phone_default;
    return ['<div id="add_external_partner">',
            '<li>',
//              '<span style="display:inline-block">',
              ' <input id="add_partner" class="lwork_mes" type="text" value="'+eidAtMarkname+'" />',
              '<a href="###" class="pending_add" title="put into to-add list" style="text-align: right; display:none;" onclick="addPendingPartner()"></a> ',
              '<input id="add_partner_phone" class="lwork_mes" type="text" style="margin-top:5px" value="'+phone+'" />',
              '<input id="add_partner_mail" class="lwork_mes" type="text" style="margin-top:5px" value="'+mail+'" />',
//              '</span>',
              '<div class="seatips" style="width: 410px;"> </div>',
            '</li>',
            '<li>',
              '<ul id="addpartnerlist">',
              '</ul>',
            '</li>',
            '</div>',
            ''
            ].join("\n")


}

function getExternalMembersToAdded() {
    var externalHybridArray=[];
    function add(li_obj) {
        externalHybridArray.push(
            {account:li_obj.attr('account'), markname:li_obj.attr('markname'),
            mail:li_obj.attr('mail')||'', phone:li_obj.attr('phone')||''});
    }
    $('#addpartnerlist').children().each(function() {add($(this))});
    return externalHybridArray;
}
function restAddExternalPartner(externalHybridArray,add_or_modify) {
    if (!externalHybridArray || externalHybridArray.length==0) return;
    var url = "/lwork/groups/external/members";
    var data = {uuid:uuid, members:externalHybridArray};
    RestChannel.post(url, data,function(data) {
        add_external_employees(data.external);
        var result = add_or_modify == 'add' ? lw_lang.ID_EXT_SUCCESS +data.external.length+lw_lang.ID_EXT_ADDNUM :
                                               lw_lang.ID_CHANGE_SUCCESS;
        LWORK.msgbox.show(result,4,2000);
    })
}

function getExternalDepObj() {return $('.department_'+external_dep_id);}

function addExternalEmployee2GlobalDb(value) // value:{uuid:uuid,name:n,eid:id,markname:m,phone:p}
{
    var index = subscriptArray[value.uuid] || employer_status.length;
    subscriptArray[value.uuid] = index;
    var convertname = ConvertPinyin(value.name);
    externalEmployees[value.uuid] = value;
    status_item = { 'uuid': value.uuid, 'name': value.name, 'employid': value.eid, 'phone': {extension: "",mobile: value.phone,other: [],pstn: ""}, 
      'department': externalEnterpris_logo, 'mail': value.mail||"",'photo': value.photo||'images/photo/defalt_photo.jpg',
       'convertname': convertname.toUpperCase(), 'name_employid': value.name + value.eid+'@'+value.markname, 
       'status': value.status||'offline' , 'department_id': value.department_id ||external_dep_id,
       markname:value.markname };
    employer_status[index] = status_item;
    name2user[status_item.name_employid] = {'uuid': value.uuid};

}

function BindModifyInfoSmartMenu(objs) {
    var Menu = [[{ text: lw_lang.ID_MODIFY_MEMBER,
                    func: function () {
                        var _this = $(this);
                        var group_id = _this.attr('department_id');
                        var group_name = _this.text();
                        var _uuid = _this.find('.sendmsn').attr('uuid');
                        var eidAtMarkname = _this.find('.employ_id').text();
                        var mail = externalEmployees[_uuid]['mail'];
                        var phone = externalEmployees[_uuid]['phone'];
                        ShowModifyExternalPartnerDialog({eidAtMarkname:eidAtMarkname, mail:mail, phone:phone});
                    }
                }]    ];
//    external_obj.smartMenu(addMenu, {
    objs.smartMenu(Menu, {
        name: "modifyExternalHybrid",
        obj: this,
        beforeShow: function () {
           // if(external_obj.parent().find('ul').css('display') !==  'block') external_obj.click(); 
        }
    });

}
var add_external_employees = function(externals) {
    if (!externals) return;
    for (var i=0; i<externals.length; i++) {
        var value = externals[i]
        addExternalEmployee2GlobalDb(value)
        departmentArray[external_dep_id]['members'][value.uuid] = value.uuid;
        if ($('.department_external').find('.'+eid_class_name(value.eid, value.markname)).length<1)
            loadContent.showemployer([value.uuid], getExternalDepObj(), true);
        BindModifyInfoSmartMenu($('.department_external').find('.employer_list'))
    }
}

function get_eid_class_name_by_uuid(UUID){
    return eid_class_name(getEmployeeByUUID(UUID)['employid'], getEmployeeByUUID(UUID)['markname'])
}
function eid_class_name(eid, markname) {
    var eid_class_suffix = markname ? "_"+markname : "";
    return eid+eid_class_suffix;
}

function restGetMembersByUUIDs(uuids,ok_fun) {
    var url = "/lwork/auth/members"+"?uuid="+uuids.join(',')
    var data = {};
    RestChannel.get(url, data,ok_fun)
}

var restDeleteExternalEmployee = function(uuid, employer_uuid,ok_fun) {
    var url = "/lwork/groups/external/members"+"?uuid="+uuid+"&external_uuid="+employer_uuid
    var data = {};
    RestChannel.del(url, data,ok_fun)

}

function BindExternalEnterpris(externals) {
    var createDom = function(opt){
        var dom ="<ul>";
        for(var j = 0 ; j< opt.length ; j++){
            dom += ['<li class="department  department_'+ opt[j]['department_id'] +'"> <a class="structre"  department_id = "'+ opt[j]['department_id'] +'" href="###"><span class="members_name"  title = "' + opt[j]['department_name'] + '">'+ opt[j]['department_name'] +'</span><span class="members_tongji"></span></a><span class="send_department"  titile="@该部门"></span></li>'].join("");
            name2user[opt[j]['department_name']] = {'department_id': opt[j]['department_id']};
            departmentArray[opt[j]['department_id']] = {'members': {}};
        }
        dom +="</ul>";
        return $(dom);
    }

    var external_obj = createDom([{department_id:external_dep_id,department_name:externalEnterpris_logo}])
    $('#org_structure').prepend(external_obj);
    var addMenu = [[{ text: lw_lang.ID_ADD_MEMBER,
                    func: function () {
                        ShowModifyExternalPartnerDialog();
                    }
                }]    ];
//    external_obj.smartMenu(addMenu, {
    external_obj.find('.structre').smartMenu(addMenu, {
        name: "externalHybrid",
        obj: external_obj.find('.structre'),
        beforeShow: function () {
           // if(external_obj.parent().find('ul').css('display') !==  'block') external_obj.click(); 
        }
    });
    external_members = externals;
}

function ShowGeneralDialog(title,content,confirmHandle) {
            var dialog = art.dialog({
            title: title,
            content: content,
            id: 'addgroupmembers',
            lock: true, 
            fixed: true,
            width: 410,
            height: 300,           
            button: [{
              name: lw_lang.ID_OK,
              focus: true,
              callback:  confirmHandle ? confirmHandle :function(){}
            },{
              name: lw_lang.ID_CANCEL
            }]  
        });
}

function ShowModifyExternalPartnerDialog(item) {
    function restAddAndShowExternalMembers() {
       // $('#add_external_partner .pending_add').click();
        addPendingPartner();
        restAddExternalPartner(getExternalMembersToAdded(), item ? 'modify' : 'add')
    }
    function ShowDialogToAddHybrid(func) {
        ShowGeneralDialog(lw_lang.ID_EXT_DIALOGTITLE, addExternalPartnerUrl(item),func);
        $('#add_partner').searchInput({defalutText: hybrid_globals.name_default});     
        $('#add_partner_phone').searchInput({defalutText: hybrid_globals.phone_default});     
        $('#add_partner_mail').searchInput({defalutText: hybrid_globals.mail_default});     
    }
    ShowDialogToAddHybrid(restAddAndShowExternalMembers);
}

function deleteMemberInExternalDep(UUID) {
    delete departmentArray[external_dep_id]['members'][UUID]
}
function isUserInExternalDep(UUID) {  
    return !!departmentArray[external_dep_id]['members'][UUID];
}

function isUserExternalEmployee(UUID) {
    return !!externalEmployees[UUID]
}

function needAdd2ExternalDep(UUID){
    return isUserExternalEmployee(UUID) && !isUserInExternalDep(UUID)
}

function getMarkname(UUID) { return externalEmployees[UUID].markname}
function getEmployeeByUUID(UUID) { return employer_status[loadContent.employstatus_sub(UUID)];}
function getEmployeeDisplayname(UUID) {
    var employee =employer_status[loadContent.employstatus_sub(UUID)];
    if (employee) {
        var name_suffix = 
            isUserExternalEmployee(employee.uuid) ? '@'+getMarkname(employee.uuid) : ''
        return employee.name+name_suffix;
    } else {
        return "未知";
    }
}

function getEmployeePhoto(UUID) {
    var employer =employer_status[loadContent.employstatus_sub(UUID)];
    return (employer &&employer['photo']) ? employer['photo'] : '/images/photo/defalt_photo.gif';
}