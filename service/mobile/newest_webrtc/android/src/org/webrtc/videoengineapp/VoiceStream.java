package org.webrtc.videoengineapp;

/* system import */
import android.util.Log;

/* self import */
import org.webrtc.videoengineapp.Control;
import org.webrtc.videoengineapp.ViEAndroidJavaAPI;

public class VoiceStream implements Control
{
	private final String TAG = "VoiceStream";
	
	private int destPort;
	private int sendCodec = 12;
	private String remoteIP;
	
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
	
	public void setSendCodec(int codec)
	{
		sendCodec = codec;
		return;
	}
	
	public int getSendCodec()
	{
		return sendCodec;
	}
	
	public String getRemoteIP()
	{
		return remoteIP;
	}
	
	public int getDestPort()
	{
		return destPort;
	}
	
	public String start(ViEAndroidJavaAPI webrtcAPI,int voiceChannel)
	{
		if (0 != webrtcAPI.VoE_SetSendDestination(voiceChannel, destPort, remoteIP)) 
		{
		    Log.d(TAG, "VoE set send destination failed");
		    return "set send destination failed";
		}
		
		if (0 != webrtcAPI.VoE_SetSendCodec(voiceChannel, sendCodec)) 
		{
		    Log.d(TAG, "VoE set send codec failed");
		    return "set send codec failed";
		}
		
		if (0 != webrtcAPI.VoE_SetECStatus(true)) 
		{
		    Log.d(TAG, "VoE set EC Status failed");
		    return "set EC Status failed";
		}
		
		if (0 != webrtcAPI.VoE_SetAGCStatus(true)) 
		{
		    Log.d(TAG, "VoE set AGC Status failed");
		    return "set AGC Status failed";
		}
		
		if (0 != webrtcAPI.VoE_SetNSStatus(true)) 
		{
		    Log.d(TAG, "VoE set NS Status failed");
		    return "set NS Status failed";
		}
		
		if (0 != webrtcAPI.VoE_StartSend(voiceChannel)) 
		{
		    Log.d(TAG, "VoE start send failed");
		    return "start send failed";
		}
		Log.d(TAG, "VoE start send ok");
		return "ok";
	}
	
	public String stop(ViEAndroidJavaAPI webrtcAPI,int voiceChannel)
	{
        if (0 != webrtcAPI.VoE_StopSend(voiceChannel)) 
        {
            Log.d(TAG, "VoE stop send failed");
            return "stop send failed";
        }
        Log.d(TAG, "VoE stop send ok");
        return "ok";
	}
}