package org.webrtc.webrtcdemo;

/* system import */
import android.util.Log;

/* self import */


public class MobilePlayout implements Control 
{
	private final String TAG = "MobilePlayout";	
    public String start(VoiceEngine webrtcAPI,int voiceChannel)
    {
		if (0 != webrtcAPI.startPlayout(voiceChannel)) 
		{
		    Log.d(TAG, "VoE start playout failed");
		    return "start playout failed";
		}
		
		Log.d(TAG, "VoE start playout ok");	
		
		if (0 != webrtcAPI.startSend(voiceChannel)) 
		{
		    Log.d(TAG, "VoE start send failed");
		    return "start send failed";
		}
		
		Log.d(TAG, "VoE start send ok");		
		return "ok";
		
    };
    
    public String stop(VoiceEngine webrtcAPI,int voiceChannel)
    {
		if (0 != webrtcAPI.stopSend(voiceChannel)) 
		{
		    Log.d(TAG, "VoE start send failed");
		    return "start send failed";
		}
		Log.d(TAG, "VoE start send ok"); 	
		
    	
    	if (0 != webrtcAPI.stopPlayout(voiceChannel))
        {
            Log.d(TAG, "VoE stop playout failed");
            return "stop playout failed";
        }
    	Log.d(TAG, "VoE stop playout ok");
        return "ok";
    }
    
};