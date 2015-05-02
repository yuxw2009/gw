# -*- coding: utf-8 -*-
import cookielib, urllib2,urllib,socket
import json,base64,time,string,random
import query_v004 as query

def get_all_info_2(uuid,qnos,type="no_jfcode"):
	def query_status(qno,auth,cj):
		Status=get_status(qno,auth,cj)
		if type!="no_jfcode" and Status["state"]=="lock":
			Status["jfcode"]=get_jfcode(qno,auth,cj)
		return Status
	cookiejar=cookielib.CookieJar()
	Jpgbin=getimg(cookiejar)
	cookie=get_cookie_from_cj(cookiejar)
	if not cookie: return ({"status":"failed",reason:"imgcookie_empty"},{"status":"failed",reason:"imgcookie_empty"})
	response=recognize_code_2(uuid,Jpgbin)
	if dict.get(response,"status") == "ok":
		AuthCode,imgId=response["authcode"],response["imgId"]
		balance=dict.get(response,"balance")
		if balance: query.set_balance(balance)
		Status1= query_status(qnos[0],AuthCode,cookiejar)
		if dict.get(Status1,"status")=="ok":
			cookiejar.clear()
			cookiejar.set_cookie(cookie)
			time.sleep(1)
			Status2=query_status(qnos[1],AuthCode,cookiejar)
			if dict.get(Status2,"status")!="ok":
				r=restore_fee(uuid,1)
				print 'second query error restore 1 result:',r
			return (Status1,Status2)
		else:
			r=restore_fee(uuid,2)
			print 'query error restore 2 result:',r
			r=report_authcode_err(uuid,imgId)
			print 'report_authcode_err result:',r
			return (Status1,Status1)
	else:
		return (response,response)
def get_cookie_from_cj(cookiejar):
	try:
		return cookiejar._cookies['.qq.com']['/']['verifysession']
	except:
		return None
def get_all_info(uuid,qno,type="no_jfcode"):
	cookiejar=cookielib.CookieJar()
	Jpgbin=getimg(cookiejar)
	response=recognize_code(uuid,Jpgbin)
	if dict.get(response,"status") == "ok":
		AuthCode=response["authcode"]
		Status=get_status(qno,AuthCode,cookiejar)
		if type!="no_jfcode" and Status["state"]=="lock":
			Status["jfcode"]=get_jfcode(qno,AuthCode,cookiejar)
		return Status
	else:
		return response

def get_status0(Acc,AuthCode):
    response= get_verify_code0(Acc,AuthCode)
    if dict.get(response,"Err") == "0":
    	return get_checkstate0(Acc,AuthCode)
    else:
    	return {"reason":"verify_code_err","status":"failed"}
def get_status(Acc,AuthCode,cookiejar):
    response= get_verify_code(Acc,AuthCode,cookiejar)
    if dict.get(response,"Err") == "0":
    	return get_checkstate(Acc,AuthCode,cookiejar)
    else:
    	return {"reason":"verify_code_err","status":"failed"}

#jpg
def getimg0():
	jpgurl="http://captcha.qq.com/getimage?aid=2001601&0.59576614107888888"
	req = urllib2.Request(jpgurl)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rr= urlOpener.open(req).read()
	output = open('e:/work/yzm1.jpg', 'wb')
	output.write(rr)
	output.close()
	return rr

def getimg(cookiejar):
	jpgurl="http://captcha.qq.com/getimage?aid=2001601&0.5957661410793789"
	r= my_get_form(jpgurl,cookiejar)
	return r

def restore_fee(uuid,Qua):
    Url="http://119.29.62.190:8180/aqqq/qv/restore_fee"
    response=my_send_http(Url,{"uuid":uuid,"qua":Qua})
    return response

def report_authcode_err(uuid,imgId):
    Url="http://119.29.62.190:8180/aqqq/qv/report_autherr"
    response=my_send_http(Url,{"uuid":uuid,"imgId":imgId})
    return response

def recognize_code(uuid,JpgBin):
    Url="http://119.29.62.190:8180/aqqq/qv/get_code"
    response=send_form_http(Url,{"uuid":uuid,"jpgbin":base64.b64encode(JpgBin)})
    return response

def recognize_code_2(uuid,JpgBin):
    Url="http://119.29.62.190:8180/aqqq/qv/get_code"
    response=send_form_http(Url,{"uuid":uuid,"jpgbin":base64.b64encode(JpgBin),"qua":2})
    return response

def get_verify_code0(Acc,Code):
	verifyurl="http://aq.qq.com/cn2/ajax/check_verifycode?verify_code="+Code+"&account="+Acc+"&session_type=on_rand"
	req = urllib2.Request(verifyurl)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rsp = urlOpener.open(req)
	return json.loads(rsp.read(),encoding='UTF-8')
'''
def get_verify_code(Acc,Code,cookiejar):
	verifyurl="http://aq.qq.com/cn2/ajax/check_verifycode?verify_code="+Code+"&account="+Acc+"&session_type=on_rand"
	req = urllib2.Request(verifyurl)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rsp = urlOpener.open(req)
	return json.loads(rsp.read(),encoding='UTF-8')
'''
def get_verify_code(Acc,Code,cookiejar):
        print "get_verify_code",Acc,Code
	verifyurl="http://aq.qq.com/cn2/ajax/check_verifycode?verify_code="+Code+"&account="+Acc+"&session_type=on_rand"
	return my_get_json(verifyurl,cookiejar)

#checkstate
def get_checkstate0(Acc,Code):
    response=checkstate0(Acc,Code)
    if dict.get(response,"if_lock") == 1:
    	(T,Loc,Reason,AddInfo)=get_lock_detail(get_limit_detail(Code,Acc,cookiejar))
    	return {"status":"ok","state":"lock", "time":T,"loc":Loc,"reason":Reason,"addinfo":AddInfo}
    elif dict.get(response,"if_lock") == 0:
    	return {"status":"ok","state":"unlock"}
    elif dict.get(response,"if_lock") == 2:
    	return {"status":"failed","reason":"checkstate_timeout"}
    else:
    	return {"status":"failed","reason":"get_checkstate_err"}
def get_checkstate(Acc,Code,cookiejar):
    response=checkstate(Acc,Code,cookiejar)
    if dict.get(response,"if_lock") == 1:
    	(T,Loc,Reason,AddInfo)=get_lock_detail(get_limit_detail(Acc,Code,cookiejar))
    	return {"status":"ok","state":"lock", "time":T,"loc":Loc,"reason":Reason,"addinfo":AddInfo}
    elif dict.get(response,"if_lock") == 0:
    	return {"status":"ok","state":"unlock"}
    elif dict.get(response,"if_lock") == 2:
    	return {"status":"failed","reason":"checkstate_timeout"}
    else:
    	return {"status":"failed","reason":"get_checkstate_err"}

def checkstate0(Acc,Code):
	stateUrl="http://aq.qq.com/cn2/login_limit/checkstate?from=1&account="+Acc+"&verifycode="+Code+"&_=1428751303426"
	req = urllib2.Request(stateUrl)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rsp = urlOpener.open(req)
	return json.loads(rsp.read(),encoding='UTF-8')
'''
def checkstate(Acc,Code,cookiejar):
	stateUrl="http://aq.qq.com/cn2/login_limit/checkstate?from=1&account="+Acc+"&verifycode="+Code+"&_=1428751303426"
	req = urllib2.Request(stateUrl)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rsp = urlOpener.open(req)
	return json.loads(rsp.read(),encoding='UTF-8')
'''
def checkstate(Acc,Code,cookiejar):
	stateUrl="http://aq.qq.com/cn2/login_limit/checkstate?from=1&account="+Acc+"&verifycode="+Code+"&_=1428751303426"
	return my_get_json(stateUrl,cookiejar)

#limt_detail
'''
def get_limit_detail(Acc,Code,cookiejar):
	stateUrl="http://aq.qq.com/cn2/login_limit/limit_detail_v2?account="+Acc+"&verifycode="+Code+"&_="+str(int(time.time()*1000))
	req = urllib2.Request(stateUrl)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	rsp = urlOpener.open(req)
	return rsp.read()
'''
def get_limit_detail(Acc,Code,cookiejar):
	stateUrl="http://aq.qq.com/cn2/login_limit/limit_detail_v2?account="+Acc+"&verifycode="+Code+"&_="+str(int(time.time()*1000))
	return my_get_form(stateUrl,cookiejar)

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
	    print jfcode
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
def my_send_http(url,values):
    payload = json.dumps(values)
    ranheader=string.join(random.sample(string.letters+string.digits, 7),"")
    jdata=json.dumps({"data_enc":ranheader+base64.b64encode(payload)})
    req = urllib2.Request(url, jdata)
    req.add_header('Content-Type', "application/json")
    try:
        response = urllib2.urlopen(req,timeout=60)#4-28YJ修改超时为60
        response_dict = json.loads(response.read(),encoding='UTF-8')
        return response_dict
    except IndexError:
        print u'服务器访问失败'
        return {}
    except socket.timeout:
        print 'socket.timeout'
        return {'status':'failed','reason':'network_exception'}
    except:
        print 'unknown except my_send_http'
        return {'status':'failed','reason':'network_exception'}

def my_get_json(url,cookiejar,values={}):
	payload=my_get_form(url,cookiejar,values)
	try:
		return json.loads(payload,encoding='UTF-8')
	except:
		print 'my_get_json ack ERROR'
		return {'status':'failed','reason':'error_ack_no_json'}

def my_get_form(url,cookiejar,values={}):
	payload = urllib.urlencode(values)
	if payload!='':
		url=url+'?'+payload
	req = urllib2.Request(url)
	req.add_header('User-Agent', 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)')
	urlOpener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookiejar))
	try:
		rr= urlOpener.open(req,timeout=60).read()#4-28YJ修改超时为60
		return rr
	except IndexError:
		print u'服务器访问失败'
		return ''
	except socket.timeout:
		print 'socket.timeout'
		return ''
	except Exception as e:
		print 'my_get_form excepttion is:',e
		return ''



def send_form_http(url,values):
	payload = urllib.urlencode(values)
	#    jdata=json.dumps({"data_enc":base64.b64encode(payload)})
	req = urllib2.Request(url, payload)
	req.add_header('Content-Type', "application/x-www-form-urlencoded")
	try:
		response = urllib2.urlopen(req,timeout=60)#4-28YJ修改超时为60
		response_dict = json.loads(response.read(),encoding='UTF-8')
		return response_dict
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

