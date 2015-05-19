# -*- coding: utf-8 -*-
import cookielib, urllib2,urllib,socket,Cookie
import json,base64,time,string,random,re
import mainframe,binascii

def get_all_info_2(uuid,qno1,qno2,if_jfcode="no_jfcode",use_auth2=True,VERSION_TYPE='not_used',proxy_str=None):
	Res1=get_all_info(uuid,qno1,if_jfcode,use_auth2,VERSION_TYPE,proxy_str)
	Res2=get_all_info(uuid,qno2,if_jfcode,use_auth2,VERSION_TYPE,proxy_str)
	return (Res1,Res2)

def my_get_code(uuid,cookiejar,use_auth2,proxyHandler):
	response= use_auth2 and fetch_code(uuid,proxyHandler)
#	print 'my_get_code',use_auth2,response
	if response and dict.get(response,'status')=='ok':
		session_value=dict.get(response,'clidata')
		cookiejar.set_cookie(make_cookie('verifysession',session_value))
		return response
	Jpgbin=getimg(cookiejar,proxyHandler)
	if not Jpgbin: return {'status':'failed','reason':'jpg_not_availablele'}
	response=recognize_code(uuid,Jpgbin,proxyHandler)
	cookie=get_cookie_from_cj(cookiejar)
	if dict.get(response,'status') == 'ok':
		upload_code(dict.get(response,'authcode'),cookie.value,proxyHandler=proxyHandler,uuid=uuid)
	return response

def superman_get_code(uuid,cookiejar,proxyHandler):
	Jpgbin=getimg(cookiejar,proxyHandler)
	if not Jpgbin: return {'status':'failed','reason':'jpg_not_availablele'}
	response=superman_recognize_code(uuid,Jpgbin,proxyHandler)
	cookie=get_cookie_from_cj(cookiejar)
	if dict.get(response,'status') == 'ok':
		upload_code(dict.get(response,'authcode'),cookie.value,proxyHandler=proxyHandler,uuid=uuid)
	return response

def fetch_code(uuid,proxyHandler):
	Url="http://119.29.62.190:8180/aqqq/qv0/hqyzdm"
	response=my_send_http(Url,{"uuid":uuid},proxyHandler)
	#print 'fetch_code',response
	return response

def upload_code(code,session_value,proxyHandler=urllib2.ProxyHandler(),uuid=""):
	Url="http://119.29.62.190:8180/aqqq/qv0/hcyzdm"
	response=my_send_http(Url,{"verify_code":code,'clidata':session_value,'uuid':uuid},proxyHandler=proxyHandler)
	#print 'upload_code',response,code,session_value,uuid
	return response


def get_all_info(uuid,qno,if_jfcode="no_jfcode",use_auth2=True,VERSION_TYPE='not_used',proxy_str=None):
	if proxy_str: proxyHandler=urllib2.ProxyHandler({"http" : 'http://'+proxy_str})
	else: proxyHandler=urllib2.ProxyHandler()
	if not is_superman_logined():
		return my_get_all_info(uuid,qno,if_jfcode=if_jfcode,use_auth2=use_auth2,proxyHandler=proxyHandler)
	else:
		return superman_get_all_info(uuid,qno,if_jfcode=if_jfcode,use_auth2=use_auth2,proxyHandler=proxyHandler)

def my_get_all_info(uuid,qno,if_jfcode="no_jfcode",use_auth2=True,proxyHandler=urllib2.ProxyHandler()):
	cookiejar=cookielib.CookieJar()
	response=my_get_code(uuid,cookiejar,use_auth2,proxyHandler)
	if dict.get(response,"status") == "ok":
		AuthCode,imgId=dict.get(response,"authcode",""),dict.get(response,"imgId")
		Status=get_status(qno,AuthCode,cookiejar,proxyHandler)
		if dict.get(Status,"status") == "failed":
			restore_fee(uuid,1,proxyHandler)
		if dict.get(Status,"reason") == 'verify_code_err':
			r=report_authcode_err(uuid,imgId,proxyHandler)
			print 'report_authcode_err result:',r
		if if_jfcode!="no_jfcode" and Status["state"]=="lock":
			Status["jfcode"]=get_jfcode(qno,AuthCode,cookiejar)
		return Status
	else:
		return {"status":"failed", "reason":"authcode_not_available"}
def superman_get_all_info(uuid,qno,if_jfcode="no_jfcode",use_auth2=True,proxyHandler=urllib2.ProxyHandler()):
	if not is_superman_logined(): 
		#print 'superman_not_logined'
		return {'status':'failed','reason':'superman_not_logined'}
	cookiejar=cookielib.CookieJar()
	response=superman_get_code(uuid,cookiejar,proxyHandler)
	if dict.get(response,"status") == "ok":
		AuthCode,imgId=dict.get(response,"authcode",""),dict.get(response,"imgId")
		Status=get_status(qno,AuthCode,cookiejar,proxyHandler)
		if dict.get(Status,"reason") == 'verify_code_err':
			r=superman_report_authcode_err(uuid,imgId,proxyHandler)
			print 'supermreport_authcode_err result:',r
		if if_jfcode!="no_jfcode" and Status["state"]=="lock":
			Status["jfcode"]=get_jfcode(qno,AuthCode,cookiejar)
		return Status
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
def get_status(Acc,AuthCode,cookiejar,proxyHandler):
	response= get_verify_code(Acc,AuthCode,cookiejar,proxyHandler=proxyHandler)
	if dict.get(response,"Err") == "0":
		return get_checkstate(Acc,AuthCode,cookiejar,proxyHandler)
	if dict.get(response, 'reason') == 'refresh_too_frequent':
		return response
	else:
		print 'get_verify_code err',response
		return {"reason":"verify_code_err","status":"failed"}

#jpg
def getimg(cookiejar,proxyHandler):
	jpgurl="http://captcha.qq.com/getimage?aid=2001601&0.5957661410793789"
	r= my_get_form(jpgurl,cookiejar,proxyHandler=proxyHandler)
	return r

def restore_fee(uuid,Qua,proxyHandler):
    Url="http://119.29.62.190:8180/aqqq/qv0/restore_fee"
    response=my_send_http(Url,{"uuid":uuid,"qua":Qua},proxyHandler)
    return response

def report_authcode_err(uuid,imgId,proxyHandler):
    if not imgId: return 'report_authcode_err no_img_id'
    Url="http://119.29.62.190:8180/aqqq/qv0/report_autherr"
    response=my_send_http(Url,{"uuid":uuid,"imgId":imgId},proxyHandler)
    return response
def superman_recognize_code(uuid,JpgBin,proxyHandler):
	return get_superman_code(JpgBin,proxyHandler)
def recognize_code(uuid,JpgBin,proxyHandler):
	Url="http://119.29.62.190:8180/aqqq/qv0/get_code0"
	response=my_send_http(Url,{"uuid":uuid,"jpgbin":base64.b64encode(encrypt(JpgBin))},proxyHandler)
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
	    response=json.loads(getsms(Acc,Code,cookiejar),encoding='UTF-8')
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

def my_send_http(url,values,proxyHandler=urllib2.ProxyHandler()): # encrypt http
    payload = json.dumps(values)
    Enc=encrypt(payload)
    Enc=base64.b64encode(Enc)
    jdata=json.dumps({"data_enc":Enc})
    req = urllib2.Request(url, jdata)
    req.add_header('Content-Type', "application/json")
    urlOpener = urllib2.build_opener(proxyHandler)
    try:
        response = urlOpener.open(req,timeout=60)#4-28YJ修改超时为60
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

def my_get_json(url,cookiejar=cookielib.CookieJar(),values={},tout=15,proxyHandler=urllib2.ProxyHandler()):
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

def my_form_request(method,url,cookiejar,values={},tout=60,proxyHandler=urllib2.ProxyHandler()):
	payload = urllib.urlencode(values)
	if method!='POST':
		if payload!='':		url=url+'?'+payload
		req = urllib2.Request(url)
	else:
		req = urllib2.Request(url,payload)
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
def my_get_form(url,cookiejar=cookielib.CookieJar(),values={},tout=60,proxyHandler=urllib2.ProxyHandler()):
	return my_form_request('GET',url,cookiejar,values,tout,proxyHandler)
def my_post_form(url,cookiejar=cookielib.CookieJar(),values={},tout=60,proxyHandler=urllib2.ProxyHandler()):
	return my_form_request('POST',url,cookiejar,values,tout,proxyHandler)



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

def imgCookieStr(ck):
	return ck.name+'='+ck.value+'; PATH=/; DOMAIN=qq.com;'

def make_cookie(name, value):
    return cookielib.Cookie(
        version=0,
        name=name,
        value=value,
        port=None,
        port_specified=False,
        domain="qq.com",
        domain_specified=True,
        domain_initial_dot=False,
        path="/",
        path_specified=True,
        secure=False,
        expires=None,
        discard=False,
        comment=None,
        comment_url=None,
        rest=None
    )	
#--------------  superman账户直接访问方式相关接口----------------------------------
g_superman=None
def superman_ins():
	global g_superman
	return g_superman
def is_superman_logined():
#	return False
	return g_superman and g_superman.is_logined()
def login_superman(uname,pwd):
	global g_superman
	g_superman=Chaoren(uname,pwd)
	return g_superman.getUserInfo()
def logout_superman():
	global g_superman
	g_superman=None
def get_superman_code(img,proxyHandler):
	url='http://api2.sz789.net:88/RecvByte.ashx'
	res= g_superman.recv_byte(img,proxyHandler=proxyHandler)
	print 'superman authcode',res
	if res:
		return {'status':'ok','authcode':res[0],'imgId':res[1]}
	else:
		return {'status':'failed','reason':'no_authcode'}
def superman_report_authcode_err(uuid,imgId,proxyHandler):
    return superman_ins() and superman_ins().report_err(imgId,proxyHandler=proxyHandler)

class Chaoren:
	def __init__(self,user,pwd,softId="12926"):
		self.username = user
		self.password = pwd
		self.softId = softId
		self.paras = {'username': self.username,'password': self.password,'softId': softId}

	def is_logined(self):
		return self.leftdot !=None
	def getUserInfo(self):
		url='http://api2.sz789.net:88/GetUserInfo.ashx'
		try:
			r = my_post_form(url, values={'username': self.username,'password': self.password},tout=20)
			d=json.loads(r,encoding='UTF-8')
			self.leftdot=dict.get(d,'left',None)
			return self.leftdot
		except Exception as e:
			print 'getUserInfo exception2 is:',e
			return -5
	def recv_byte(self, imgdata,proxyHandler=urllib2.ProxyHandler()):
		imgstr = binascii.b2a_hex(imgdata).upper()
		url='http://api2.sz789.net:88/RecvByte.ashx'
		data = {
		'username': self.username,
		'password': self.password,
		'softId': self.softId,
		'imgdata':imgstr
		}
		try:
			str0 = my_post_form(url,values=data,proxyHandler=proxyHandler)
			res=json.loads(str0,encoding='UTF-8')
			if isinstance(res,dict):
				if res[u'info'] == -1:
					self.report_err(res['imgId'],proxyHandler=proxyHandler)  # 识别错误
					return False
				return (res['result'],res['imgId'])
			else:
				return False
		except Exception as e:
			print 'recv_byte exception2 is:',e
			return False
	def report_err(self, imgid,proxyHandler=urllib2.ProxyHandler()):
		print 'report_err',imgid
		try:
			url='http://api2.sz789.net:88/ReportError.ashx'
			data = {
			'username': self.username,
			'password': self.password,
			'imgId': imgid
			}
			r = my_post_form(url,values=data,proxyHandler=proxyHandler)
			res=json.loads(r,encoding='UTF-8')
			return res
		except Exception as e:
			print 'superman report_err exception is:',e
			return False

# test8888888888888888888888888888888888888888888888888
import win32com.client
def readJsFile(filename):
    fp = file( filename, 'r' )
    lines = ''
    for line in fp:
        lines += line+' '
    return lines

def driveJsCode(code, func, paras=None):
	js = win32com.client.Dispatch('MSScriptControl.ScriptControl')
	js.Language = 'JavaScript'
	js.AllowUI = False
	js.AddCode(code)
	if paras:
		return js.Run(func, *paras)
	else:
		return js.Run(func)

def mm_pwd(filename,funname,param_list):
	code = readJsFile( filename )
	p = driveJsCode( code, funname, param_list)
	return  p

def check(username,cookiejar):
	r= my_get_form("http://check.ptlogin2.qq.com/check?regmaster=&pt_tea=1&pt_vcode=1&uin="+username+"&appid=636014201&js_ver=10123&js_type=1&login_sig=JOtM13zgzEN8xS5sZrG9FGvrSCEQGJj3n6lpslq2Pbefi4t6a4Btx3YSMKxhjtaB&u1=http%3A%2F%2Fwww.qq.com%2Fqq2012%2FloginSuccess.htm&r=0.9075145779643208",cookiejar)	
	Match1= re.match(".*\'(.*)\'.*\'(.*)\'.*\'(.*)\'.*\'(.*)\'.*\'(.*)\'.*",r,re.DOTALL)
	if Match1:
		AddInfo=Match1.groups()
	else:
		AddInfo=""
	return AddInfo

def test1(username,pwd):
	cookiejar=cookielib.CookieJar()
	res,code,salt,sessionId,other=check(username,cookiejar)
	mypwd=mm_pwd('test.js','myprocess',[pwd,code])
	#mypwd=fff()
	loginurl="http://ptlogin2.qq.com/login?u="+username+"&verifycode="+code+"&pt_vcode_v1=0&pt_verifysession_v1="+sessionId+"&p="+mypwd+"&pt_randsalt=0&ptredirect=0&u1=http%3A%2F%2Fwww.qq.com%2Fqq2012%2FloginSuccess.htm&h=1&t=1&g=1&from_ui=1&ptlang=2052&action=4-23-1431759014704&js_ver=10123&js_type=1&login_sig=JOtM13zgzEN8xS5sZrG9FGvrSCEQGJj3n6lpslq2Pbefi4t6a4Btx3YSMKxhjtaB&pt_uistyle=20&aid=636014201"
	return my_get_form(loginurl,cookiejar)

def fff():
	return mm_pwd('test.js','myprocess',['ILoveYou2',"code"])