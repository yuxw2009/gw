package org.webrtc.videoengineapp;

import android.content.Context;
import android.util.Log;

public class WebRtcBase
{
	private String TAG = "WebRtcBase";
	private boolean enableTrace = true;
	private int choice = -1;
	
	private ViEAndroidJavaAPI webrtcAPI = null;
	
	/*************************************************************************/
	
	private void initVoice(Context ctxt)
	{
		if (!webrtcAPI.VoE_Create(ctxt.getApplicationContext()))
        {
        	Log.d(TAG, "VoE create failed");
        	throw new RuntimeException("VoE create failed");
        }
        
        if (0 != webrtcAPI.VoE_Init(enableTrace))
        {
        	Log.d(TAG, "VoE init failed");
        	throw new RuntimeException("VoE init failed");
        }
        
        return;
	}
	
	private void releaseVoice()
	{
		// Terminate
        if (0 != webrtcAPI.VoE_Terminate()) 
        {
            Log.d(TAG, "VoE terminate failed");
            throw new RuntimeException("VoE terminate failed");
        }
        
        if (!webrtcAPI.VoE_Delete()) 
        {
            Log.d(TAG, "VoE Delete failed");
            throw new RuntimeException("VoE Delete failed");
        }
        
        return;
	}
	
	/*************************************************************************/
	
	private void initVideo()
	{
		if (0 != webrtcAPI.GetVideoEngine())
        {
        	Log.d(TAG, "ViE get failed");
        	throw new RuntimeException("ViE get failed");
        }
		
		if (0 != webrtcAPI.Init(enableTrace))
		{
			Log.d(TAG, "ViE init failed");
        	throw new RuntimeException("ViE init failed");
		}
		
		return;
	}
	
	private void releaseVideo()
	{
		if (0 != webrtcAPI.Terminate())
        {
        	Log.d(TAG, "ViE terminate failed");
        	throw new RuntimeException("ViE terminate failed");
        }
		
		return;
	}
	
	/*************************************************************************/
	
	public WebRtcBase(Context ctxt,int c)
	{
		webrtcAPI = new ViEAndroidJavaAPI(ctxt);
		choice = c;
		
		switch(choice)
		{
		    case 1:
		    	initVoice(ctxt);
		    	break;
		    case 2:
		    	initVideo();
		    	break;
		    case 3:
		    	initVoice(ctxt);
		    	initVideo();
		    	break;
		    default:
		    	throw new RuntimeException("invalid arg");
		}
        
        return;
	}
	
	/*************************************************************************/
	
	public void release()
	{
		switch(choice)
		{
		    case 1:
		    	releaseVoice();
		    	break;
		    case 2:
		    	releaseVideo();
		    	break;
		    case 3:
		    	releaseVoice();
		    	releaseVideo();
		    	break;
		    default:
		    	break;
		}
        
        return;
	}
	
	/*************************************************************************/
	
	public ViEAndroidJavaAPI getAPI()
	{
		return webrtcAPI;
	}
	
	/*************************************************************************/
}