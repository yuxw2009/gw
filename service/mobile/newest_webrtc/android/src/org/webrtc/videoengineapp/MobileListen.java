package org.webrtc.videoengineapp;

/* system import */
import android.util.Log;

/* self import */
import org.webrtc.videoengineapp.Control;
import org.webrtc.videoengineapp.ViEAndroidJavaAPI;

public class MobileListen implements Control 
{
	private final String TAG = "MobileListen";
	
	private int volumeLevel = 255;
	private boolean enableLoudSpeaker = false;
	
	public void setEnableLoudSpeaker(boolean enable)
	{
		enableLoudSpeaker = enable;
		return;
	}
	
	public void setVolumeLevel(int vol)
	{
		volumeLevel = vol;
		return;
	}
	
    public String start(ViEAndroidJavaAPI webrtcAPI,int voiceChannel)
    {
    	// Start Listen
		if (0 != webrtcAPI.VoE_StartListen(voiceChannel)) 
		{
		    Log.d(TAG, "VoE start listen failed");
		    return "start listen failed";
		}
		// Set Speaker
		if (0 != webrtcAPI.VoE_SetLoudspeakerStatus(enableLoudSpeaker)) 
		{
            Log.d(TAG, "VoE set louspeaker status failed");
            return "set louspeaker status failed";
        }
		// Set Volume
        if (0 != webrtcAPI.VoE_SetSpeakerVolume(volumeLevel)) 
		{
		    Log.d(TAG, "VoE set speaker volume failed");
		    return "set speaker volume failed";
		}
		Log.d(TAG, "VoE start listen ok");
    	return "ok";
    }
    
    public String stop(ViEAndroidJavaAPI webrtcAPI,int voiceChannel)
    {
	    // Stop listen
	    if (0 != webrtcAPI.VoE_StopListen(voiceChannel)) 
	    {
	        Log.d(TAG, "VoE stop listen failed");
	        return "stop listen failed";
	    }
	    Log.d(TAG, "VoE stop listen ok");
	    return "ok";
    }
};