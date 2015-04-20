package org.webrtc.webrtcdemo;

/* system import */
import android.util.Log;


/* self import */
import org.webrtc.webrtcdemo.Control;


public class VoiceReceiver implements Control
{
	private final String TAG = "VoiceReceiver";
			
	private int receivePort = 56000;
	
	private int destPort;
	private String remoteIP;	
	
	public void setReceivePort(int port)
	{
		receivePort = port;
		return;
	}
	
	public int getReceivePort()
	{
		return receivePort;
	}
	
	public void setRemoteIP(String ip)
	{
		remoteIP = ip;
		return;
	}
	
	public void setDestPort(int port)
	{
		destPort = port;
		return;
	}	

	
	public String getRemoteIP()
	{
		return remoteIP;
	}
	
	public int getDestPort()
	{
		return destPort;
	}		
	
	public String start(VoiceEngine webrtcAPI,int voiceChannel)
	
	{
		if(0 != webrtcAPI.setLocalReceiver(voiceChannel, receivePort)){
			
			Log.d(TAG, "VoE set LocalReceiver failed");
			return "set LocalReceiver failed";	
			
		}
		Log.e(TAG, "VoE set local receiver ok");
		
        

		if (0 != webrtcAPI.setSendDestination(voiceChannel, destPort, remoteIP)) 
		{
		    Log.d(TAG, "VoE set send destination failed");
		    return "set send destination failed";
		}
		
		
		return "ok";
	}
	
	
	public String stop(VoiceEngine webrtcAPI,int voiceChannel)
	{
		
		Log.e(TAG, "VoE stop local receiver ok");
		return "ok";
		
	}
		
}