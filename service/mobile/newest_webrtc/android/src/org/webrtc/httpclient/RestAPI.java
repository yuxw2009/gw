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

import android.text.format.Time;
import android.util.Log;

public class RestAPI 
{
	private final String URL = "http://10.61.59.21:7000/lwork/mobile/voip/calls";
//	private final String TV_ONLINE_URL = "http://58.221.59.169:8082/lwork/tv/online";
//	private final String TV_OFFLINE_URL = "http://58.221.59.169:8082/lwork/tv/offline";
//	private final String TV_CALL_URL = "http://58.221.59.169:8082/lwork/tv/calls";
	
	/*************************************************************************/
	
/*	public class TvOnlineRtn
	{
		public String status = "";
		public String reason = "";
	}
	
	public TvOnlineRtn tryOnline(String IP)
	{
		HttpPost httpPost = new HttpPost(TV_ONLINE_URL);
		
		HttpResponse resp = null;
		TvOnlineRtn rslt = new TvOnlineRtn();
		try
		{
			JSONObject reqJSON = new JSONObject();
			reqJSON.put("user_id", IP);
			StringEntity se = new StringEntity(reqJSON.toString());   
			httpPost.setEntity(se);
			resp = new DefaultHttpClient().execute(httpPost);
			JSONObject respJSON = BuildResponseJson(resp);
			
			if (respJSON.getString("status").compareTo("ok") == 0)
			{
				rslt.status = "ok";
				Log.d("RestAPI", "Start parse json ok");
			}
			else
			{
				Log.d("RestAPI", "Start http response code NOT 200");
				rslt.status = "failed";
				rslt.reason = "http response code NOT 200";
			}
		}
		catch (JSONException e) 
		{
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Start Response JSON exception");
			rslt.status = "failed";
        	rslt.reason = "Response JSON exception";
        } 
		catch (ClientProtocolException e) 
        {
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Start Http Client Protocol exception");
			rslt.status = "failed";
        	rslt.reason = "Http Client Protocol exception";
        }
		catch (IOException e) 
        {
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Start Http IO exception");
			rslt.status = "failed";
        	rslt.reason = "Http IO exception";
        }
		return rslt;
	}*/
	
	/*************************************************************************/
		
/*	public class TvOfflineRtn
	{
		public String status = "";
		public String reason = "";
	}
	
	public TvOnlineRtn tryOffline(String IP)
	{
		HttpPost httpPost = new HttpPost(TV_OFFLINE_URL);
		
		HttpResponse resp = null;
		TvOnlineRtn rslt = new TvOnlineRtn();
		try
		{
			JSONObject reqJSON = new JSONObject();
			reqJSON.put("user_id", IP);
			StringEntity se = new StringEntity(reqJSON.toString());   
			httpPost.setEntity(se);
			resp = new DefaultHttpClient().execute(httpPost);
			JSONObject respJSON = BuildResponseJson(resp);
			
			if (respJSON.getString("status").compareTo("ok") == 0)
			{
				rslt.status = "ok";
				Log.d("RestAPI", "Start parse json ok");
			}
			else
			{
				Log.d("RestAPI", "Start http response code NOT 200");
				rslt.status = "failed";
				rslt.reason = "http response code NOT 200";
			}
		}
		catch (JSONException e) 
		{
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Start Response JSON exception");
			rslt.status = "failed";
        	rslt.reason = "Response JSON exception";
        } 
		catch (ClientProtocolException e) 
        {
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Start Http Client Protocol exception");
			rslt.status = "failed";
        	rslt.reason = "Http Client Protocol exception";
        }
		catch (IOException e) 
        {
            // TODO Auto-generated catch block
			Log.d("RestAPI", "Start Http IO exception");
			rslt.status = "failed";
        	rslt.reason = "Http IO exception";
        }
		return rslt;
	}*/
	
	/*************************************************************************/
	
	
	
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
			JSONArray  ipList  = new JSONArray();
			for (int i = 0; i < myIPs.size(); i++)
			{
				ipList.put(myIPs.get(i));
			}
			selfSDP.put("ip", ipList);
			selfSDP.put("port", Integer.toString(myPort));
			selfSDP.put("codec", Integer.toString(myCodec));
			
			reqJSON.put("sdp", selfSDP);
			
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
				Log.d("RestAPI", "Start http response code NOT 200");
				rslt.status = -1;
				rslt.reason = "http response code NOT 200";
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
			Log.d("RestAPI", "Stop Http IO exception");
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
