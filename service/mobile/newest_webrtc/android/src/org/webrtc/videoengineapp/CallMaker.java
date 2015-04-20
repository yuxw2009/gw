package org.webrtc.videoengineapp;

import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;

import android.content.Context;
import android.util.Log;

import org.apache.http.conn.util.InetAddressUtils;
import org.webrtc.httpclient.RestAPI;
import org.webrtc.videoengineapp.LogicCalc;
import org.webrtc.videoengineapp.UserCallback;
import org.webrtc.videoengineapp.VoiceBase;
import org.webrtc.videoengineapp.WebRtcBase;

public class CallMaker
{	
	private String TAG = "CallMaker";
	
	private String curSID = "";
	
	private RestAPI   restAPI   = null;
	private VoiceBase voiceBase = null;
	
	private PollCall poll = null;
	private WebRtcBase webrtcBase = null;
	
	/*************************************************************************/
    
	public CallMaker(Context ctxt,UserCallback api)
	{
		webrtcBase = new WebRtcBase(ctxt,1);
		voiceBase  = new VoiceBase(webrtcBase);
		restAPI    = new RestAPI();
        poll       = new PollCall(this,api);
        return;
    }
	
	public void release()
	{
		voiceBase.release();
		webrtcBase.release();
        return;
	}
	
	/*************************************************************************/
	
	public String setSendCodecType(String codec)
	{
		return voiceBase.setSendCodecType(codec);
	}
	
	public void setReceivePort(int port)
	{
		voiceBase.setReceivePort(port);
		return;
	}
	
	public void setVolumeLevel(int vol)
	{
		voiceBase.setVolumeLevel(vol);
		return;
	}
	
	public void setLoudSpeaker(boolean bool)
	{
		voiceBase.setLoudSpeaker(bool);
		return;
	}
	
	/*************************************************************************/
	
	public String startCall(String phone,String userclass,String selfPhone)
	{
		List<String> localIps = getLocalIpAddress();
		if (localIps.size() > 0)
		{
			int port  = voiceBase.getReceivePort();
			int codec = voiceBase.getSendCodec();
			
			RestAPI.CallRtn rslt = restAPI.startCall(phone,userclass,selfPhone,localIps,port,codec);
			
			if (rslt.status == 0)
			{
				voiceBase.setRemoteIP(rslt.peerIP);
				voiceBase.setDestPort(rslt.peerPort);
				
				String rtn = doStartCall();
				
				if (0 == rtn.compareTo("ok"))
				{
					curSID = rslt.sessionId;
					poll.start(curSID);
				}
				else
				{
					curSID = "";
				}
				return rtn;
			}
			else
			{
				Log.d(TAG, "startCall http failed reason:" + rslt.reason);
				return "startCall http failed reason:" + rslt.reason;
			}
		}
		else
		{
			Log.d(TAG, "get local ip failed");
			return "get local ip failed";
		}
	}
	
	public String stopCall()
	{
		poll.stop();
		return stopCallWithoutPoll();
	}
	
	public String stopCallWithoutPoll()
	{
		List<String> values = new ArrayList<String>();
		
		String localStop = doStopCall();
		values.add(localStop);
		
		RestAPI.TerminateRtn rslt = restAPI.terminateCall(curSID);
		
		if (rslt.status == 0)
		{
			curSID = "";
			values.add("ok");
		}
		else
		{
			String t = "stopCall http failed reason:" + rslt.reason;
			Log.d(TAG, t);
			values.add(t);
		}
		return LogicCalc.orValue(values);
	}
	
	/*****************************private method******************************/
    
    private String doStartCall()
    {
    	String receive = voiceBase.startVoiceReceive();
    	if (receive.compareTo("ok") == 0)
    	{
    		String send = voiceBase.startVoiceSend();
    		if (send.compareTo("ok") != 0)
    		{
    			voiceBase.stopVoiceReceive();
    		}
    		return send;
    	}
    	else
    	{
    		return receive;
    	}
	}
    
    private String doStopCall()
    {
    	List<String> values = new ArrayList<String>();
    	String send    = voiceBase.stopVoiceSend();
    	String receive = voiceBase.stopVoiceReceive();
    	values.add(send);
    	values.add(receive);
    	return LogicCalc.orValue(values);
    }
    
    private List<String> getLocalIpAddress() 
    {
    	List<String> localIPs = new ArrayList<String>();
        try 
        {
            for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); 
            	 en.hasMoreElements();) 
            {
                NetworkInterface intf = en.nextElement();
                for (Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses();
                     enumIpAddr.hasMoreElements(); ) 
                {
                    InetAddress inetAddress = enumIpAddr.nextElement();
                    if (!inetAddress.isLoopbackAddress() && 
                    	InetAddressUtils.isIPv4Address(inetAddress.getHostAddress())) 
                    {
                        localIPs.add(inetAddress.getHostAddress().toString());
                    }
                }
            }
        } 
        catch (SocketException ex) 
        {
            Log.e(TAG, "get local ip address failed.reason:" + ex.toString());
        }
        Log.e(TAG, "localIPs" + localIPs.toString());
        return localIPs;
    }
}
