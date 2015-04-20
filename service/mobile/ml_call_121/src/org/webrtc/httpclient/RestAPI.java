package org.webrtc.httpclient;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.List;
import java.util.Locale;

import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.methods.*;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.DefaultHttpClient;

//import org.apache.http.params.BasicHttpParams;
//import org.apache.http.params.HttpConnectionParams;

import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

import android.os.Build;
import android.text.format.Time;
import android.util.Log;

public class RestAPI
{
	 private final String URL = "http://58.221.60.121:8080/lwork/mobile/voip/calls";	
	 // private final String URL = "http://58.221.60.37/lwork/mobile/voip/calls";      
	  private final String loginUrl="http://58.221.60.121:8080/lwork/mobile/login";
	  private final String smsURL = "http://fc2fc.com/lwork/sms";
	  private final String authcodeURL = "http://58.221.60.121:8080/lwork/sms/auth_code";
	  
	
	/*************************************************************************/
	
	// call
		public class CallRtn
		{
			public int status = -1;
			public String sessionId = "";
			public String Rtn = null;
			public String peerIP = null;
			public int peerPort = -1;
			public int peerCodec = -1;
			public String reason = null;
		};

		public CallRtn startCall(String phone,String userclass,String selfPhone,List<String> myIPs,int myPort,int myCodec)
		{
			HttpPost httpPost = new HttpPost(URL);
			httpPost.addHeader("Origin","http://fzd.lw.mobile");
			
			HttpResponse resp = null;
			
			CallRtn rslt = new CallRtn();
			try 
			{
				JSONObject reqJSON = new JSONObject();
				reqJSON.put("user_id", selfPhone);
				reqJSON.put("caller_phone", "unused");
				reqJSON.put("userclass", userclass);				
				reqJSON.put("callee_phone", phone);				
				JSONObject selfSDP = new JSONObject();				
				JSONObject clidata = new JSONObject();					
				JSONArray  ipList  = new JSONArray();
				for (int i = 0; i < myIPs.size(); i++)
				{
					ipList.put(myIPs.get(i));
				}
				selfSDP.put("ip", ipList);
				selfSDP.put("port", Integer.toString(myPort));
				selfSDP.put("codec", Integer.toString(myCodec));				
				reqJSON.put("sdp", selfSDP);
				
				clidata.put("BRAND", Build.BRAND);
				clidata.put("MODEL", Build.MODEL.replaceAll(" ", ""));
				clidata.put("osVersion",  android.os.Build.VERSION.RELEASE);
				clidata.put("sdkVersion",  android.os.Build.VERSION.SDK);
				
				reqJSON.put("clidata", clidata);
				
				StringEntity se = new StringEntity(reqJSON.toString()); 
				
				httpPost.setEntity(se);

				//BasicHttpParams httpParameters = new BasicHttpParams();
				//HttpConnectionParams.setSoTimeout(httpParameters, 3000);
				
				resp = new DefaultHttpClient().execute(httpPost);
				
				Log.d("RestAPI", "Start Send Request");
				JSONObject respJSON = BuildResponseJson(resp);
				
				Log.d("RestAPI", "Start return jason:" + respJSON.toString());
				
				Log.d("RestAPI", "Start http response code:" + resp.getStatusLine().getStatusCode());
				if (respJSON.getString("status").compareTo("ok") == 0)
				{
					rslt.status    = 0;
					rslt.sessionId = respJSON.getString("session_id");
					rslt.peerIP    = respJSON.getString("ip");
					rslt.peerPort  = respJSON.getInt("port");
					rslt.peerCodec = respJSON.getInt("codec");
					Log.d("RestAPI", "Start parse json ok");
				}
				else
				{
					Log.d("RestAPI", "request failed: " + respJSON.getString("reason"));
					rslt.status = -1;					
					rslt.reason =respJSON.getString("reason");
				}
			}
			catch (JSONException e) 
			{
	            // TODO Auto-generated catch block
				Log.d("RestAPI", "Start Response JSON exception");
				rslt.status = -1;
	        	rslt.reason = "Response JSON exception";
	        } 
			catch (ClientProtocolException e) 
	        {
	            // TODO Auto-generated catch block
				Log.d("RestAPI", "Start Http Client Protocol exception");
	        	rslt.status = -1;
	        	rslt.reason = "Http Client Protocol exception";
	        }
			catch (IOException e) 
	        {
	            // TODO Auto-generated catch block
				Log.d("RestAPI", "Start Http IO exception");
	        	rslt.status = -1;
	        	rslt.reason = "Http IO exception";
	        }
			return rslt;
		}
	
	/*************************************************************************/
	
	// login
		public class LoginRtn
		{
			public int status = -1;
			public String reason = null;
		};
		
		public LoginRtn startLogin(String userName, String password) {
			
			HttpPost httpPost = new HttpPost(loginUrl);
			httpPost.addHeader("Origin","http://fzd.lw.mobile");
			Log.d("login rst", "send before startlogin" + loginUrl);
			HttpResponse resp = null;
			LoginRtn rslt = new LoginRtn();

			
			try 
			{

				JSONObject reqJSON = new JSONObject();
				reqJSON.put("uuid", userName);
				reqJSON.put("pwd", password);			
				Log.d("loginAPI", "login info" + userName +  password);
				
				StringEntity se = new StringEntity(reqJSON.toString()); 
				
				Log.d("loginAPI", "param" + reqJSON.toString());
				
				httpPost.setEntity(se);	
				
				Log.d("loginAPI", "param" + httpPost);
				Log.d("loginAPI", "send before startlogin" );
				
				resp = new DefaultHttpClient().execute(httpPost);				
				Log.d("RestAPI", "Send Request" + resp);	
				JSONObject respJSON = BuildResponseJson(resp);
				
				Log.d("RestAPI", "Start return jason:" + respJSON.toString());
				
				if (respJSON.getString("status").compareTo("ok") == 0)
				{
					rslt.status    = 0;
					Log.d("RestAPI", "Start parse json ok");
				}
				else
				{
					Log.d("RestAPI", "request failed: " + respJSON.getString("reason"));
					rslt.status = -1;					
					rslt.reason =respJSON.getString("reason");
				}		
				
			}
			
			catch (JSONException e) 
			{
	            // TODO Auto-generated catch block
				Log.d("RestAPI", "Start Response JSON exception");
				rslt.status = -1;
	        	rslt.reason = "Response JSON exception";
	        } 
			catch (ClientProtocolException e) 
	        {
	            // TODO Auto-generated catch block
				Log.d("RestAPI", "Start Http Client Protocol exception");
	        	rslt.status = -1;
	        	rslt.reason = "Http Client Protocol exception";
	        }
			catch (IOException e) 
	        {
	            // TODO Auto-generated catch block
				Log.d("RestAPI", "Start Http IO exception");
	        	rslt.status = -1;
	        	rslt.reason = "Http IO exception";
	        }
			
			return rslt;
			
			
		} 	
	
		private String correctPhoneNumber(String phone) {
			StringBuffer sb = new StringBuffer();		
			if (phone.charAt(0) != '0'){
				if (phone.charAt(0) != '+'){
				    sb.append("0086");
				}
			}else{
				if (phone.charAt(1) != '0'){
					phone = phone.substring(1);
					sb.append("0086");
				}
			}
			
			for (int i = 0; i < phone.length(); i++){
				char c = phone.charAt(i);
				if ( c == '-' || c == ' ' || c == '(' || c == ')'){
					continue;
				}else if (c == '+'){
					sb.append("00");
				}else{
					sb.append(c);
				}
			}
			return sb.toString();
		}	
		
		
		
		
        // sms
		public class SMSRtn
		{
			public int status = -1;
			public String reason = null;			
		};
		
		public SMSRtn sendSms(String uuid, String content, String signature, List<String> members) {			
			HttpPost httpPost = new HttpPost(smsURL);
			httpPost.addHeader("Origin","http://fzd.lw.mobile");
			httpPost.setHeader("Accept", "application/json");			
			Log.d("sendSMS", "send before sendsms" + smsURL);			
			HttpResponse resp = null;			
			SMSRtn rslt = new SMSRtn();			
			try 
			{
				JSONObject reqJSON = new JSONObject();	
				String tempphone;
				reqJSON.put("uuid", uuid);
				reqJSON.put("content", content);				
				reqJSON.put("signature", signature);				
				JSONArray  sendmemberList  = new JSONArray();
				
				for (int i = 0; i < members.size(); i++)
				{
					JSONObject sendmemberItem = new JSONObject();
					tempphone = correctPhoneNumber(members.get(i));
					Log.d("sendSMS", "sendSMS info" + tempphone);	
    				sendmemberItem.put("name", tempphone);
					sendmemberItem.put("phone",tempphone);
					sendmemberList.put(sendmemberItem);
				}	
				
				reqJSON.put("members", sendmemberList);	
				
				StringEntity se = new StringEntity(reqJSON.toString()); 
				
				Log.d("sendSMS", "param" + reqJSON.toString());
				
				httpPost.setEntity(se);					
				resp = new DefaultHttpClient().execute(httpPost);	

				JSONObject respJSON = BuildResponseJson(resp);
				
				Log.d("sendSMS", "Start return jason:" + respJSON.toString());
				
				if (respJSON.getString("status").compareTo("ok") == 0)
				{
					rslt.status    = 0;
					Log.d("sendSMS", "Start parse json ok");
				}
				else
				{
					Log.d("RestAPI", "request failed: " + respJSON.getString("reason"));
					rslt.status = -1;					
					rslt.reason =respJSON.getString("reason");
				}		
				
			}
			
			catch (JSONException e) 
			{
	            // TODO Auto-generated catch block
				Log.d("RestAPI", "Start Response JSON exception");
				rslt.status = -1;
	        	rslt.reason = "Response JSON exception";
	        } 
			catch (ClientProtocolException e) 
	        {
	            // TODO Auto-generated catch block
				Log.d("RestAPI", "Start Http Client Protocol exception");
	        	rslt.status = -1;
	        	rslt.reason = "Http Client Protocol exception";
	        }
			catch (Exception e) 
	        {
	            // TODO Auto-generated catch block
				Log.d("RestAPI",  e.toString());
	        	rslt.status = -1;
	        	rslt.reason = "Http IO exception";
	        }
			
			return rslt;
			
		} 			
	

		//authcode
		
		public class authCodeRtn
		{
			public int status = -1;
			public String reason = null;			
		};
		
		public authCodeRtn getAuthCode(String uuid){
			
			HttpPost httpPost = new HttpPost(authcodeURL);
			
			httpPost.addHeader("Origin","http://fzd.lw.mobile");			
			Log.d("requestCode", "send before get authcode" + authcodeURL);	
			
			HttpResponse resp = null;
			
			authCodeRtn rslt = new authCodeRtn();			
			try 
			{
				JSONObject reqJSON = new JSONObject();		
				reqJSON.put("uuid", uuid);	
				
				StringEntity se = new StringEntity(reqJSON.toString()); 			
				
				Log.d("requestCode", "param" + reqJSON.toString());
				
				httpPost.setEntity(se);	
				
				Log.d("requestCode", "set se");
				
				resp = new DefaultHttpClient().execute(httpPost);	
				
				Log.d("requestCode", "Start return jason:");

				JSONObject respJSON = BuildResponseJson(resp);
				
				Log.d("requestCode", "Start return jason:" + respJSON.toString());
				
				if (respJSON.getString("status").compareTo("ok") == 0)
				{
					rslt.status    = 0;
					Log.d("requestCode", "Start parse json ok");
				}
				else
				{
					Log.d("RestAPI", "request failed: " + respJSON.getString("reason"));
					rslt.status = -1;					
					rslt.reason =respJSON.getString("reason");
				}		
				
			}
			
			catch (JSONException e) 
			{
	            // TODO Auto-generated catch block
				Log.d("requestCode", "Start Response JSON exception");
				rslt.status = -1;
	        	rslt.reason = "Response JSON exception";
	        } 
			catch (ClientProtocolException e) 
	        {
	            // TODO Auto-generated catch block
				Log.d("requestCode", "Start Http Client Protocol exception");
	        	rslt.status = -1;
	        	rslt.reason = "Http Client Protocol exception";
	        }
			catch (Exception e) 
	        {
	            // TODO Auto-generated catch block
				Log.d("requestCode",  e.toString());
	        	rslt.status = -1;
	        	rslt.reason = "Http IO exception";
	        }			
			return rslt;
			
		} 	
		
    /*************************************************************************/
	
	// terminate
	public class TerminateRtn
	{
		public int status = -1;
		public String reason = "";
	}
	
	public TerminateRtn terminateCall(String sid)
	{
		String url = String.format(Locale.US, "?session_id=%s&user_id=%s", sid, "Anonymous");
		HttpDelete httpdel = new HttpDelete(URL + url);
		httpdel.addHeader("Origin","http://fzd.lw.mobile");
		TerminateRtn rslt  = new TerminateRtn();
		
		try
		{
		    HttpResponse resp = new DefaultHttpClient().execute(httpdel);
		    JSONObject respJSON = BuildResponseJson(resp);
		    if (respJSON.getString("status").compareTo("ok") == 0)
		    {
				rslt.status = 0;
			}
		    else
			{
		    	rslt.status = -1;
				rslt.reason = respJSON.getString("reason");
			}
		} 
		catch (JSONException e)
		{
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Stop JSONException");
			rslt.status = -1;
        	rslt.reason = "Response JSON exception";
        } 
		catch (ClientProtocolException e) 
		{
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Stop ClientProtocolException");
			rslt.status = -1;
        	rslt.reason = "Http Client Protocol exception";
        } 
		catch (IOException e) 
		{
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Stop Http IO exception" + e.toString());
			rslt.status = -1;
        	rslt.reason = "Http IO exception";
        }
		return rslt;
	}
	
	/*************************************************************************/
	
	// check
	public class CheckRtn
	{
		public int status = -1;
		public String peerSt = "";
		public String reason = "";
	}
	
	public CheckRtn CheckCall(String sid)
	{
		String url = String.format(Locale.US, "?session_id=%s&user_id=%s", sid, "Anonymous");
		HttpGet httpget = new HttpGet(URL + url + "?unused=" + new Time().toString ());
		httpget.addHeader("Origin","http://fzd.lw.mobile");
		CheckRtn rslt = new CheckRtn();

		try
		{
		    HttpResponse resp = new DefaultHttpClient().execute(httpget);
		    JSONObject respJSON = BuildResponseJson(resp);
		    if (respJSON.getString("status").compareTo("ok") == 0)
		    {
				rslt.status = 0;
				rslt.peerSt = respJSON.getString("peer_status");
			}
		    else
		    {
		    	rslt.status = -1;
				rslt.reason = respJSON.getString("reason");
			}
		} 
		catch (JSONException e) 
		{
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Check Response JSON exception");
			rslt.status = -1;
			rslt.reason = "Response JSON exception";
        }
		catch (ClientProtocolException e)
        {
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Check Http Client Protocol exception");
        	rslt.status = -1;
        	rslt.reason = "Http Client Protocol exception";
        } 
		catch (IOException e) 
		{
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Check Http IO exception");
			rslt.status = -1;
        	rslt.reason = "Http IO exception";
        }
		return rslt;
	}
	
	/*************************************************************************/
	
	private JSONObject BuildResponseJson(HttpResponse response)
	{
		JSONObject rslt = null;
		try 
		{
			BufferedReader reader = new BufferedReader(new InputStreamReader(response.getEntity().getContent(), "UTF-8"));
			StringBuilder builder = new StringBuilder();
			for (String line = null; (line = reader.readLine()) != null;) 
			{
			    builder.append(line).append("\n");
			}
			Log.d("RestAPI", "builder string:" + builder.toString());
			rslt = new JSONObject(builder.toString());
        } 
		catch (JSONException e)
		{
            // TODO Auto-generated catch block
			Log.d("RestAPI", "build json JSONException");
        	rslt = null;
        } 
		catch (IOException e) 
        {
            // TODO Auto-generated catch block
			Log.d("RestAPI", "build json IOException");
        	rslt = null;
        }
		return rslt;
	}
}
