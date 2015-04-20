package org.webrtc.videoengineapp;

/* system import */
import android.util.Log;


/* self import */
import org.webrtc.videoengineapp.Control;
import org.webrtc.videoengineapp.ViEAndroidJavaAPI;

public class VoiceReceiver implements Control
{
	private final String TAG = "VoiceReceiver";
			
	private int receivePort = 56000;
	
	public void setReceivePort(int port)
	{
		receivePort = port;
		return;
	}
	
	public int getReceivePort()
	{
		return receivePort;
	}
	
	public String start(ViEAndroidJavaAPI webrtcAPI,int voiceChannel)
	{
		webrtcAPI.VoE_SetLocalReceiver(voiceChannel, receivePort);
		Log.e(TAG, "VoE set local receiver ok");
		return "ok";
	}
	
	public String stop(ViEAndroidJavaAPI webrtcAPI,int voiceChannel)
	{
		Log.e(TAG, "VoE stop local receiver ok");
		return "ok";
	}
}