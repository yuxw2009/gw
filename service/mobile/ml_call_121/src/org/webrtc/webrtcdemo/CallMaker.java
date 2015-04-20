package org.webrtc.webrtcdemo;

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

import org.webrtc.voiceengine.WebRTCAudioDevice;



public class CallMaker
{	

	private String TAG = "CallMaker";	
	private String curSID = "";	
	private RestAPI   restAPI   = null;
	private VoiceBase voiceBase = null;
	private PollCall poll = null;
	private WebRtcBase webrtcBase = null;	
	private NativeWebRtcContextRegistry contextRegistry = null;
    private UserCallback callback= null;
	private WebRTCAudioDevice WebRTCAudioDevice= null;
	
	/*************************************************************************/
    
	public CallMaker(Context context, UserCallback api, int audioMode)
	{
	 // load library	
		contextRegistry = new NativeWebRtcContextRegistry();		
	    contextRegistry.register(context); 	    
		webrtcBase = new WebRtcBase(context,1);
		voiceBase  = new VoiceBase(context, webrtcBase, audioMode);
		restAPI    = new RestAPI();
        poll       = new PollCall(this,api, context);
        callback   = api;
        WebRTCAudioDevice = new WebRTCAudioDevice(context);
        return;        
    }
	
	
	public void release()
	{
		WebRTCAudioDevice.setPlayoutSpeekNormal();
		voiceBase.release();		
		unRegisterLibaray();
        return;
	}
	
	public void unRegisterLibaray(){		
		contextRegistry.unRegister();
	}
	
	/*************************************************************************/
	
	public void setReceivePort(int port)
	{
		voiceBase.setReceivePort(port);
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
				
				Log.d(TAG, "startCall rslt:" + rslt);				
				voiceBase.setRemoteIP(rslt.peerIP);	
				
				if (0 != voiceBase.setAudioCodec()) {
					Log.d(TAG, "Failed setSendCodec");
					return "Failed setSendCodec";		
				}		
				
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
