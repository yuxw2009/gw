package org.webrtc.webrtcdemo;

import java.io.File;
import java.io.FileOutputStream;

import android.content.Context;
import android.os.AsyncTask;
import android.os.Environment;
import android.os.Handler;
import android.util.Log;

import org.webrtc.httpclient.RestAPI;
import org.webrtc.voiceengine.WebRTCAudioDevice;

public class PollCall extends RestAPI
{
	private static String TAG = "PollCall";
	
    private static final long POLL_CALL_STATUS_MS = 3000;
    private Handler handler = null;
    private Runnable PollingCallback = null;
    
    private CallMaker call = null;
    private UserCallback callback= null;
    private String sid = "";
	
    
//    private int checkAcc = 1;
//    private VoiceBase voiceBase = null;//    
    
    public PollCall(CallMaker callmaker,UserCallback api, Context context)
    {
    	call     = callmaker;
    	callback = api;    	
//    	voiceBase = base;//   
    	
    	handler = new Handler();
    	PollingCallback = new Runnable() 
        {
            public void run() 
            {
            	handler.postDelayed(this, POLL_CALL_STATUS_MS);
            	// writeFileToSD("check num is: " + checkAcc + "\n");
            	// checkAcc++;
            	// writeFileToSD("stream ip: " + voiceBase.getRemoteIP() + "\n");
            	// writeFileToSD("stream port: " + voiceBase.getDestPort() + "\n");
            	new CallChecker().execute("");
            }
        };
    }
    
    public void start(String serverID)
    {
    	sid = serverID;
    	if (true != handler.post(PollingCallback))
    	{
    		handler.post(PollingCallback);
    	}
    }
    
    public void stop()
    {
    	sid = "";
    	handler.removeCallbacks(PollingCallback);
    }
    
    private void handlePoll(String state)
    {
    	if (state.compareTo("ring") == 0)
    	{
    		callback.ring();
    		return;
    	}
    	if (state.compareTo("hook_off") == 0)
    	{
    		callback.talking();   		
    		return;
    	}
    	if ((state.compareTo("hook_on") == 0) || (state.compareTo("released") == 0))
    	{
    		stop();
    		new CallStoper().execute("");
    		callback.hangup();
    		return;
    	}
    	return;
    }
    
    private class CallChecker extends AsyncTask<String, Integer, String>
    {
		@Override
		protected String doInBackground(String... data)
		{
			if (sid == "")
			{
				return "ok";
			}
			CheckRtn rslt = CheckCall(sid);
			if (rslt.status == 0)
			{
				writeFileToSD(rslt.peerSt + "\n");
				return rslt.peerSt;
			}
			else
			{
				String t = "checkCall http failed reason:" + rslt.reason + "\n";
				writeFileToSD(t);
				Log.d(TAG, t);
				return t;
			}
		}
		
		@Override 
		protected void onPostExecute(String rt)
		{
			super.onPostExecute(rt);
			handlePoll(rt);
		}
	}
    
	public class CallStoper extends AsyncTask<String, Integer, String>
	{	
		@Override
		protected String doInBackground(String... data){
			return call.stopCallWithoutPoll();
		}
		
		@Override 
		protected void onPostExecute(String rt){
			super.onPostExecute(rt);
		}
	}
	
	public static void writeFileToSD(String s) 
	{  
	    String sdStatus = Environment.getExternalStorageState();  
	    if(!sdStatus.equals(Environment.MEDIA_MOUNTED)) 
	    {  
	        Log.d(TAG, "SD card is not avaiable/writeable right now.");  
	        return;  
	    }  
	    try 
	    {  
	        String pathName = Environment.getExternalStorageDirectory().getPath(); 
	        Log.d(TAG, "pathName:" + pathName); 
	        String fileName = "/webrtc_report.txt";  
	        File path = new File(pathName);  
	        File file = new File(pathName + fileName);  
	        if(!path.exists())
	        {
	            Log.d(TAG, "Create the path:" + pathName);
	            path.mkdir();
	        }
	        if(!file.exists())
	        {
	            Log.d(TAG, "Create the file:" + fileName);
	            file.createNewFile();
	        }
	        FileOutputStream stream = new FileOutputStream(file,true);
	        byte[] buf = s.getBytes();
	        stream.write(buf);   
	        stream.close();          
	    }
	    
	    catch(Exception e) 
	    {  
	        Log.e(TAG, "Error on writeFilToSD.");  
	        e.printStackTrace();  
	    }  
	}
}