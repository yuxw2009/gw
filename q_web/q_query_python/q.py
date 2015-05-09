# -*- coding: utf-8 -*-
import cookielib, urllib2,urllib,socket
import json,base64,time,string,random,re
import mainframe

def get_all_info_2(uuid,qnos,type="no_jfcode"):
	def query_status(qno,auth,cj):
		Status=get_status(qno,auth,cj)
		if type!="no_jfcode" and Status["state"]=="lock":
			Status["jfcode"]=get_jfcode(qno,auth,cj)
		return Status
	mainframe.g_parrel_num+=1
	cookiejar=cookielib.CookieJar()
	Jpgbin=getimg(cookiejar)
	cookie=get_cookie_from_cj(cookiejar)
	if not cookie: return ({"status":"failed","reason":"imgcookie_empty"},{"status":"failed","reason":"imgcookie_empty"})
	print '1 ', qnos, time.ctime()   
	mainframe.g_add_counter()
	response=recognize_code_2(uuid,Jpgbin)
	print '2 ', qnos, time.ctime()
	result=0
	if dict.get(response,"status") == "ok":
		AuthCode,imgId=response["authcode"],response["imgId"]
		balance=dict.get(response,"balance")
		if balance: mainframe.set_balance(balance)
		Status1= query_status(qnos[0],AuthCode,cookiejar)
		if dict.get(Status1,"status")=="ok":
			print "8888888888888888888888888888",mainframe.g_counter
			mainframe.set_short_pause()
			cookiejar.clear()
			cookiejar.set_cookie(cookie)
			time.sleep(2)
			Status2=query_status(qnos[1],AuthCode,cookiejar)
			if dict.get(Status2,"status")!="ok":
				r=restore_fee(uuid,1)
				print 'second query error restore 1 result:',r
			result= (Status1,Status2)
		else:
			r=restore_fee(uuid,2)
			print 'query error restore 2 result:',r
			if dict.get(Status1,"reason") == 'verify_code_err':
				r=report_authcode_err(uuid,imgId)
				print 'report_authcode_err result:',r
			result= (Status1,Status1)
	else:
		result= (response,response)
	if mainframe.g_parrel_num>0: mainframe.g_parrel_num-=1
	return result
def get_all_info(uuid,qno,type="no_jfcode"):
	cookiejar=cookielib.CookieJar()
	Jpgbin=getimg(cookiejar)
	cookie=get_cookie_from_cj(cookiejar)
	if not Jpgbin: return {'status':'failed','reason':'jpg_not_availablele'}
	AuthCode=recognize_code(uuid,Jpgbin)
	if AuthCode:
		Status=get_status(qno,AuthCode,cookiejar)
		if dict.get(Status,"status") == "failed":
			restore_fee(uuid,1)
		if dict.get(Status,"reason") == 'verify_code_err':
			r=report_authcode_err(uuid,imgId)
			print 'report_authcode_err result:',r
		if type!="no_jfcode" and Status["state"]=="lock":
			Status["jfcode"]=get_jfcode(qno,AuthCode,cookiejar)
		cookiejar.clear()
		cookiejar.set_cookie(cookie)
		return Status.update({"cj":cookiejar})
	else:
		return {"status":"failed", "reason":"authcode_not_available"}

def get_cookie_from_cj(cookiejar):
	try:
		return cookiejar._cookies['.qq.com']['/']['verifysession']
	except:
		return None
def cur_proxy_handler():
	global g_proxy_index
	proxyHandler=urllib2.ProxyHandler()
	gl=mainframe.g_proxy_list
	if gl:
		if not g_proxy_index: 
			g_proxy_index=0
		else:
			g_proxy_index=(g_proxy_index+1)%len(gl)
		cur_proxystr=gl[g_proxy_index]
		proxyHandler=urllib2.ProxyHandler({"http" : 'http://'+cur_proxystr})
	return proxyHandler
def get_status(Acc,AuthCode,cookiejar):
	proxyHandler=cur_proxy_handler()
	response= get_verify_code(Acc,AuthCode,cookiejar,proxyHandler=proxyHandler)
	if dict.get(response,"Err") == "0":
		return get_checkstate(Acc,AuthCode,cookiejar,proxyHandler)
	if dict.get(response, 'reason') == 'refresh_too_frequent':
		return response
	else:
		return {"reason":"verify_code_err","status":"failed"}

#jpg
def getimg(cookiejar):
	jpgurl="http://captcha.qq.com/getimage?aid=2001601&0.5957661410793789"
	r= my_get_form(jpgurl,cookiejar)
	return r

def restore_fee(uuid,Qua):
    Url="http://119.29.62.190:8180/aqqq/qv0/restore_fee"
    response=my_send_http(Url,{"uuid":uuid,"qua":Qua})
    return response

def report_authcode_err(uuid,imgId):
    Url="http://119.29.62.190:8180/aqqq/qv0/report_autherr"
    response=my_send_http(Url,{"uuid":uuid,"imgId":imgId})
    return response

def recognize_code(uuid,JpgBin):
	if is_superman_logined():
		return get_superman_code(JpgBin)
	else:
		Url="http://119.29.62.190:8180/aqqq/qv0/get_code0"
		response=my_send_http(Url,{"uuid":uuid,"jpgbin":base64.b64encode(encrypt(JpgBin))})
	return dict.get(response,"status") == "ok" and response["authcode"]

def recognize_code_2(uuid,JpgBin):
    Url="http://119.29.62.190:8180/aqqq/qv0/get_code0"
    response=my_send_http(Url,{"uuid":uuid,"jpgbin":base64.b64encode(encrypt(JpgBin)),"qua":2})
    return response

def get_verify_code(Acc,Code,cookiejar,proxyHandler=urllib2.ProxyHandler()):
	verifyurl="http://aq.qq.com/cn2/ajax/check_verifycode?verify_code="+Code+"&account="+Acc+"&session_type=on_rand"
	return my_get_json(verifyurl,cookiejar,proxyHandler=proxyHandler)

#checkstate
def get_checkstate(Acc,Code,cookiejar,proxyHandler=urllib2.ProxyHandler()):
    response=checkstate(Acc,Code,cookiejar,proxyHandler)
    if dict.get(response,"if_lock") == 1:
    	(T,Loc,Reason,AddInfo)=get_lock_detail(get_limit_detail(Acc,Code,cookiejar,proxyHandler=proxyHandler))
    	return {"status":"ok","state":"lock", "time":T,"loc":Loc,"reason":Reason,"addinfo":AddInfo}
    elif dict.get(response,"if_lock") == 0:
    	return {"status":"ok","state":"unlock"}
    elif dict.get(response,"if_lock") == 2:
    	return {"status":"failed","reason":"checkstate_timeout"}
    else:
    	return {"status":"failed","reason":"get_checkstate_err"}

def checkstate(Acc,Code,cookiejar,proxyHandler):
	stateUrl="http://aq.qq.com/cn2/login_limit/checkstate?from=1&account="+Acc+"&verifycode="+Code+"&_=1428751303426"
	return my_get_json(stateUrl,cookiejar,proxyHandler=proxyHandler)

#limt_detail
def get_limit_detail(Acc,Code,cookiejar,proxyHandler=urllib2.ProxyHandler()):
	stateUrl="http://aq.qq.com/cn2/login_limit/limit_detail_v2?account="+Acc+"&verifycode="+Code+"&_="+str(int(time.time()*1000))
	return my_get_form(stateUrl,cookiejar,proxyHandler=proxyHandler)

def get_lock_detail(Body):
	import re
	Match1= re.match(".*(已被冻结|改密立即恢复登录|申诉成功立即恢复登录).*",Body,re.DOTALL)
	if Match1:
		AddInfo=Match1.groups()[0]
	else:
		AddInfo=""
	Match2=re.match(".*<td>(.*)</td>\n.*<td>(.*)</td>\n.*<td>(.*)</td>\n.*</tr>[\t\n]+.*</tbody>",Body,re.DOTALL)
	if Match2:
		return Match2.groups()+(AddInfo,)
	else:
		return ("","","",AddInfo)

def get_jfcode(Acc,Code,cookiejar):
	try:
	    response=json.loads(getsms(Acc,Code,cookiejar))
	    jfcode=dict.get(response,"sms")
	    if len(jfcode)==6:
	    	return jfcode
	    else:
	        return ""
	except:
		print "except in getjfcode"
		return ""

# sms is post form format
def getsms(Acc,Code,cookiejar):
	smsurl="http://aq.qq.com/cn2/login_limit/getsms"
	req = urllib2.Request(smsurl,"verifycode="+Code)
	req.add_header('Content-Type', "application/x-www-form-urlencoded")
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rsp = urlOpener.open(req)
	return rsp.read()


#################################
from pyDes import *
def k():
	Key = "\x31\x23\x45\x67\x89\xab\xcd\xfe"
	IVec = "\x33\x34\x56\x78\x90\xab\xcd\xfe"
	return des(Key,CBC,IVec,pad=' ')
def encrypt(data):
    return k().encrypt(data)
def decrypt(data):
    return k().decrypt(data)

def json_decode(response_dict):
    enc=dict.get(response_dict,"data_enc")
    return enc and json.loads(decrypt(base64.b64decode(enc)),encoding='UTF-8') or response_dict

def my_send_http(url,values):
    payload = json.dumps(values)
    Enc=encrypt(payload)
    Enc=base64.b64encode(Enc)
    jdata=json.dumps({"data_enc":Enc})
    req = urllib2.Request(url, jdata)
    req.add_header('Content-Type', "application/json")
    try:
        response = urllib2.urlopen(req,timeout=60)#4-28YJ修改超时为60
        response_dict = json.loads(response.read(),encoding='UTF-8')
        return json_decode(response_dict)
    except IndexError:
        print u'服务器访问失败'
        return {}
    except socket.timeout:
        print 'socket.timeout'
        return {'status':'failed','reason':'network_exception'}
    except Exception as e:
        print 'unknown except my_send_http',e
        return {'status':'failed','reason':'network_exception'}

def my_get_json(url,cookiejar,values={},tout=15,proxyHandler=urllib2.ProxyHandler()):
	payload=my_get_form(url,cookiejar,values,tout,proxyHandler=proxyHandler)
	try:
		return json.loads(payload,encoding='UTF-8')
	except:
		Match1= re.match(".*(刷新).*",payload,re.DOTALL)
		if Match1:
			print 'my_get_json ack ERROR',payload
			mainframe.set_long_pause()
			return {'status':'failed','reason':'refresh_too_frequent'}
		else:
			print 'my_get_json ack ERROR',len(payload)
			return {'status':'failed','reason':'error_ack_no_json'}

def my_get_form(url,cookiejar,values={},tout=60,proxyHandler=urllib2.ProxyHandler()):
	payload = urllib.urlencode(values)
	if payload!='':
		url=url+'?'+payload
	req = urllib2.Request(url)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar),proxyHandler)
	try:
		rr= urlOpener.open(req,timeout=tout).read()
		return rr
	except Exception as e:
		print 'my_get_form exception is:',e
		try:
			rr= urlOpener.open(req,timeout=tout).read()
			return rr
		except Exception as e:
			print 'my_get_form exception2 is:',e
			return ''



def send_form_http(url,values):
	payload = urllib.urlencode(values)
	#    jdata=json.dumps({"data_enc":base64.b64encode(payload)})
	req = urllib2.Request(url, payload)
	req.add_header('Content-Type', "application/x-www-form-urlencoded")
	try:
		response = urllib2.urlopen(req,timeout=60)#4-28YJ修改超时为60
		response_dict = json.loads(response.read(),encoding='UTF-8')
		return json_decode(response_dict)
	except IndexError:
		print u'服务器访问失败:'+url
		return {'status':'failed','reason':'network_exception'}
	except socket.timeout:
		print 'socket.timeout'
		return {'status':'failed','reason':'network_exception'}
	except:
		print 'unknown except send_form_http'
		return {'status':'failed','reason':'network_exception'}


cookiejar = cookielib.CookieJar()


def test():
	jpgurl="http://captcha.qq.com/getimage?aid=2001601&0.59576614107888888"
	req = urllib2.Request(jpgurl)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rr= urlOpener.open(req).read()
	output = open('e:/work/yzm1.jpg', 'wb')
	output.write(rr)
	output.close()


def test1(Acc,Code):	
	verifyurl="http://aq.qq.com/cn2/ajax/check_verifycode?verify_code="+Code+"&account="+Acc+"&session_type=on_rand"
	req = urllib2.Request(verifyurl)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rsp=urlOpener.open(req)
	return rsp.read()

#--------------  superman账户直接访问方式相关接口----------------------------------
#import superman
g_superman=None
def is_superman_logined():
	return False
#	return g_superman and g_superman.is_logined()
def login_superman(uname,pwd):
	global g_superman
	g_superman=superman.dcVerCode(uname,pwd)
	return g_superman.getUserInfo()
def logout_superman():
	global g_superman
	g_superman=None
def get_superman_code(img):
	return g_superman.recByte(img)
