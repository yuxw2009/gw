package org.webrtc.videoengineapp;

/* system import */
import android.util.Log;

/* self import */
import org.webrtc.videoengineapp.Control;
import org.webrtc.videoengineapp.ViEAndroidJavaAPI;

public class MobilePlayout implements Control 
{
	private final String TAG = "MobilePlayout";
	
    public String start(ViEAndroidJavaAPI webrtcAPI,int voiceChannel)
    {
		// Start playout
		if (0 != webrtcAPI.VoE_StartPlayout(voiceChannel)) 
		{
		    Log.d(TAG, "VoE start playout failed");
		    return "start playout failed";
		}
		Log.d(TAG, "VoE start playout ok");
		return "ok";
    };
    
    public String stop(ViEAndroidJavaAPI webrtcAPI,int voiceChannel)
    {
    	if (0 != webrtcAPI.VoE_StopPlayout(voiceChannel))
        {
            Log.d(TAG, "VoE stop playout failed");
            return "stop playout failed";
        }
    	Log.d(TAG, "VoE stop playout ok");
        return "ok";
    }
};