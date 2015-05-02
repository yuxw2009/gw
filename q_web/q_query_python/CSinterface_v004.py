# -*- coding: utf-8 -*-
import hashlib
import json
import urllib2
import socket
import q

SERVER_LOAD_URL = 'http://119.29.62.190:8180/aqqq/qv/login'
SERVER_QUERY_QQ_URL = 'http://119.29.62.190:8180/aqqq/qv/query_qno_status'
SERVER_EXIT_URL = 'http://119.29.62.190:8180/aqqq/qv/logout'
SERVER_QUERY_BALANCE_URL = 'http://119.29.62.190:8180/aqqq/qv/query_balance?uuid=u'
SERVER_REGISTERED_ACCOUNT_URL = 'http://119.29.62.190:8180/aqqq/qv/register'
SERVER_QUERY_QQ_MANUAL_URL = 'http://119.29.62.190:8180/aqqq/qv/manual_query'
SERVER_RECHARGE_URL = 'http://119.29.62.190:8180/aqqq/qv/recharge'
SERVER_UPLOAD_QNO_URL = 'http://119.29.62.190:8180/aqqq/qv/manual_upload'

def load_server(acc,pwd):
    pwd_md5 = hashlib.md5(pwd.encode('utf-8')).hexdigest()
    values ={'acc':'%s'%acc,'pwd':'%s'%pwd_md5}
    #response_dict = main(values,SERVER_LOAD_URL)
    #return response_dict
    return q.my_send_http(SERVER_LOAD_URL,values)  

def query_state(uuid,qno):
    values ={'uuid':'%s'%uuid,'qno':'%s'%qno}
    #response_dict = main(values,SERVER_QUERY_QQ_URL)
    response_dict = q.get_all_info(uuid,qno)
    for i in response_dict.keys():
        response_dict[i]=response_dict[i].decode('utf-8')
    return response_dict

def convert_unicode(response_dict):
    for i in response_dict.keys():
        response_dict[i]=response_dict[i].decode('utf-8')
    return response_dict

def query_state_2(uuid,qnos):
    (response1,response2) = q.get_all_info_2(uuid,qnos)
    return (convert_unicode(response1),convert_unicode(response2))

def exit_server(uuid):
    values = {'uuid':'%s'%uuid}
    response_dict = main(values,SERVER_EXIT_URL)
    return response_dict

def query_balance(uuid):
    url = SERVER_QUERY_BALANCE+'?uuid=%s'%uuid
    response = urllib2.urlopen(SERVER_QUERY_BALANCE_URL)
    response_dict = json.loads(response.read(),encoding='UTF-8')
    return response_dict

def registerd_account(acc,pwd,auth_code):
    pwd_md5 = hashlib.md5(pwd.encode('utf-8')).hexdigest()
    values = {'acc':'%s'%acc,'pwd':'%s'%pwd_md5,'auth_code':'%s'%auth_code}
    #response_dict = main(values,SERVER_REGISTERED_ACCOUNT_URL)
    #return response_dict
    return q.my_send_http(SERVER_REGISTERED_ACCOUNT_URL,values)

def query_state_manual(uuid,qno,verify_code,clidata):
    values = {'uuid':'%s'%uuid,'qno':'%s'%qno,'verify_code':'%s'%verify_code,'clidata':'%s'%clidata}
    response_dict = main(values,SERVER_QUERY_QQ_MANUAL_URL)
    return response_dict

def recharge(acc,auth_code):
    values = {'acc':'%s'%acc,'auth_code':'%s'%auth_code}
    #response_dict = main(values,SERVER_RECHARGE_URL)
    #return response_dict
    return q.my_send_http(SERVER_RECHARGE_URL,values)

def upload_qno_manual(uuid):
    values={'uuid':'%s'%uuid}
    response_dict = main(values,SERVER_UPLOAD_QNO_URL)
    return response_dict

def main(values,url):
    jdata = json.dumps(values)
    req = urllib2.Request(url, jdata)
    req.add_header('Content-Type', 'application/json')
    fail = 0
    while fail<=3:
        try:
            response = urllib2.urlopen(req,timeout=15)
            response_dict = json.loads(response.read(),encoding='UTF-8')
            return response_dict
        except IndexError:
            fail+=1
            print u'服务器访问失败'
            return {'status':'failed','reason':u'1)服务器访问失败'}
        except socket.timeout:
            fail+=1
            return {'status':'failed','reason':u'2)服务器访问失败'}
            print 'socket.timeout,fail=%d'%fail
        except urllib2.URLError:   #4-29
            return {'status':'failed','reason':u'3)服务器访问失败'}#4-29



    
