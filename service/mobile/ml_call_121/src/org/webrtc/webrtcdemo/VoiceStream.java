package org.webrtc.webrtcdemo;

/* system import */
import android.content.Context;
import android.media.AudioManager;
import android.util.Log;
import android.widget.Toast;

import org.webrtc.voiceengine.WebRTCAudioDevice;


public class VoiceStream implements Control
{
	private final String TAG = "VoiceStream";	

	private int sendCodec = 11;

	private int volumeLevel = 255;	
	
	private WebRTCAudioDevice WebRTCAudioDevice= null;
	private final Context context;
	private int audioMode;

	public VoiceStream(Context context, int audioMode)
	{
		 this.context = context;
		 this.audioMode = audioMode;
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
	  
	public void setVolumeLevel(int vol)
	{
		volumeLevel = vol;
		return;
	}		
	
	public String start(VoiceEngine webrtcAPI,int voiceChannel)
	{
		
		WebRTCAudioDevice = new WebRTCAudioDevice(context);	
		
		//Log.d("setmode", "setmode" + audioMode);
		WebRTCAudioDevice.setAudioMode(audioMode);		
        
		// Set SetPlayoutSpeaker
      if (0 != WebRTCAudioDevice.SetPlayoutSpeaker(false)) 
	  {
		    Log.d(TAG, "Failed setLoudspeakerStatus");
		    return "Failed setLoudspeakerStatus";
	  }  
     
    
	 // setLoudspeakerStatus
     if (0 != webrtcAPI.setLoudspeakerStatus(false)) 
		{
		    Log.d(TAG, "setLoudspeakerStatus failed");
		    return "setLoudspeakerStatus failed";
		}
     
     Log.d(TAG, "setLoudspeakerStatus success");
		
		// Set Volume
     if (0 != webrtcAPI.setSpeakerVolume(volumeLevel)) 
		{
		    Log.d(TAG, "VoE set speaker volume failed");
		    return "set speaker volume failed";
		}
        

/*		if (0 != webrtcAPI.setSendDestination(voiceChannel, destPort, remoteIP)) 
		{
		    Log.d(TAG, "VoE set send destination failed");
		    return "set send destination failed";
		}  */
 		
		 VoiceEngine.AgcConfig agc_config =  new VoiceEngine.AgcConfig(3, 9, true);
		 
		 if(0 != webrtcAPI.setAgcConfig(agc_config)){
			 
			    Log.d(TAG, "VoE set AGC config failed");
			    return "set AGC config failed";	
		 }
		
		
		if (0 != webrtcAPI.setAgcStatus(true, VoiceEngine.AgcModes.DEFAULT)) 
		{
		    Log.d(TAG, "VoE set AGC Status failed");
		    return "set AGC Status failed";
		}
		
		if (0 != webrtcAPI.setNsStatus(true, VoiceEngine.NsModes.DEFAULT)) 
		{
		    Log.d(TAG, "VoE set NS Status failed");
		    return "set NS Status failed";
		} 
		
		if (0 != webrtcAPI.setEcStatus(true, VoiceEngine.EcModes.AECM)) 
		{
		    Log.d(TAG, "VoE set Ec Status failed");
		    return "set NS Status failed";
		} 
				 
		return "ok";
	}
	
	public String stop(VoiceEngine webrtcAPI,int voiceChannel)
	{
        if (0 != webrtcAPI.stopSend(voiceChannel)) 
        {
            Log.d(TAG, "VoE stop send failed");
            return "stop send failed";
        }
        Log.d(TAG, "VoE stop send ok");
        return "ok";
	}
}