package org.webrtc.webrtcdemo;

/* system import */
import android.util.Log;
import android.media.AudioManager;
import android.content.Context;

public class MobileListen implements Control 
{
	private final String TAG = "MobileListen";	

    public String start(VoiceEngine webrtcAPI,int voiceChannel)
    {     	
    	// Start Listen
		if (0 != webrtcAPI.startListen(voiceChannel)) 
		 {
			Log.d(TAG, "VoE start listen failed");
			return "start listen failed";
		 }    	
        
		Log.d(TAG, "VoE start listen ok");
    	return "ok";
    	
    }
    
    public String stop(VoiceEngine webrtcAPI,int voiceChannel)
    {
	    // Stop listen
	    if (0 != webrtcAPI.stopListen(voiceChannel)) 
	    {
	        Log.d(TAG, "VoE stop listen failed");
	        return "stop listen failed";
	    }
	    Log.d(TAG, "VoE stop listen ok");
	    return "ok";
    }
};