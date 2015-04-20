package org.webrtc.webrtcdemo;

import android.content.Context;
import android.util.Log;

public class WebRtcBase
{
	private String TAG = "WebRtcBase";
	private boolean enableTrace = true;
	private int choice = -1;	
	private VoiceEngine webrtcAPI = null;	
	
	/*************************************************************************/
	
	private void initVoice(Context ctxt)
	{
		
   /* if (!(ctxt.getApplicationContext()))
        {
        	Log.d(TAG, "VoE create failed");
        	throw new RuntimeException("VoE create failed");
        } */
		
	    webrtcAPI = new VoiceEngine();
	    
        if (0 != webrtcAPI.init())
        {
        	Log.d(TAG, "VoE init failed");
        	throw new RuntimeException("VoE init failed");
        }        
      //  setTrace(true);        
        return;
	}
	
	  public void setTrace(boolean enable) {
		 if (enable) {
		    webrtcAPI.setTraceFile("/sdcard/webrtcVoice.txt", false);
		    webrtcAPI.setTraceFilter(VoiceEngine.TraceLevel.TRACE_ALL);
		    return;
		 }
		 webrtcAPI.setTraceFilter(VoiceEngine.TraceLevel.TRACE_ALL);
	  }
		  
	
	
	private void releaseVoice(int audioChannel)
	{
     // Terminate
     /* if (0 != webrtcAPI.VoE_Terminate()) 
        {
            Log.d(TAG, "VoE terminate failed");
            throw new RuntimeException("VoE terminate failed");
        } */		
	    if (webrtcAPI.deleteChannel(audioChannel) != 0) 
        {
            Log.d(TAG, "VoE Delete failed");
            throw new RuntimeException("VoE Delete failed");
        }
        
        return;
	}
	

	
	/*************************************************************************/	
	public WebRtcBase(Context ctxt,int c)
	{
		webrtcAPI = new VoiceEngine();
		choice = c;	
		
		switch(choice)
		{
		    case 1:
		    	initVoice(ctxt);
		    	break;		    	
		/* case 2:
		    	initVideo();
		    	break;
		    case 3:
		    	initVoice(ctxt);
		    	initVideo();
		    	break; */		    	
		    default:
		    	throw new RuntimeException("invalid arg");
		}
        
        return;
	}
	
	/*************************************************************************/
	
	public void release(int audioChannel)
	{
		switch(choice)
		{
		    case 1:
		    	releaseVoice(audioChannel);
		    	break;
		/*  case 2:
		    	releaseVideo();
		    	break;
		    case 3:
		    	releaseVoice();
		    	releaseVideo();
		    	break; */
		    default:
		    	break;
		}
        
        return;
	}
	
	/*************************************************************************/
	
	public VoiceEngine getAPI()
	{
		return webrtcAPI;
	}
	
	/*************************************************************************/
}