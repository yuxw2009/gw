# -*- coding: utf-8 -*-
import hashlib
import json
import urllib2
import socket

headers(req)->
    [{"Referer","http://aq.qq.com/cn2/login_limit/login_limit_index"},
    {"Content-Type","application/x-www-form-urlencoded"},
    {"User-Agent","Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727)"}].    

header_getimage = {
        "Accept":"*/*",
        "Referer": "http://aq.qq.com/cn2/login_limit/login_limit_index",
        "Accept-Language": "zh-cn",
        "User-Agent": "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)",
        "Accept-Encoding": "gzip, deflate",
        "Host": "captcha.qq.com",
        "Connection": "Keep-Alive"

        }
header_getcheckverify = {
        "X-Requested-With":"XMLHttpRequest",
        "Accept":"image/gif, image/jpeg, image/pjpeg, */*",
        "Referer": "http://aq.qq.com/cn2/login_limit/login_limit_index",
        "Accept-Language": "zh-cn",
        "User-Agent": "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727)",
        "Accept-Encoding": "gzip, deflate",
        "Host": "aq.qq.com",
        "Connection": "Keep-Alive",
        "Content-Type":"application/x-www-form-urlencoded"
        }

header_getcheckstate = {
        "X-Requested-With":"XMLHttpRequest",
        "Accept":"image/gif, image/jpeg, image/pjpeg, */*",
        "Referer": "http://aq.qq.com/cn2/login_limit/login_limit_index",
        "Accept-Language": "zh-cn",
        "User-Agent": "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727)",
        "Accept-Encoding": "gzip, deflate",
        "Host": "aq.qq.com",
        "Connection": "Keep-Alive",
        "Content-Type":"application/x-www-form-urlencoded"
        }



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
    response_dict = main(values,SERVER_LOAD_URL)
    return response_dict

'''
def query_state(uuid,qno):
    values ={'uuid':'%s'%uuid,'qno':'%s'%qno}
    response_dict = main(values,SERVER_QUERY_QQ_URL)
    return response_dict
'''
def query_state(uuid,qno):
    return q.get_all_info(uuid,qno)
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
    response_dict = main(values,SERVER_REGISTERED_ACCOUNT_URL)
    return response_dict

def query_state_manual(uuid,qno,verify_code,clidata):
    values = {'uuid':'%s'%uuid,'qno':'%s'%qno,'verify_code':'%s'%verify_code,'clidata':'%s'%clidata}
    response_dict = main(values,SERVER_QUERY_QQ_MANUAL_URL)
    return response_dict

def recharge(acc,auth_code):
    values = {'acc':'%s'%acc,'auth_code':'%s'%auth_code}
    response_dict = main(values,SERVER_RECHARGE_URL)
    return response_dict

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
            print u'服务器访问失败'
        except socket.timeout:
            fail+=1
            print 'socket.timeout,fail=%d'%fail


headers(req)->
    [{"Referer","http://aq.qq.com/cn2/login_limit/login_limit_index"},{"Content-Type","application/x-www-form-urlencoded"},{"User-Agent","Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727)"}].    

    
