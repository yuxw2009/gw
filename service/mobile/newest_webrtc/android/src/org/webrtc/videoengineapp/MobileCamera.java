package org.webrtc.videoengineapp;

/* system import */
import android.util.Log;


/* self import */
import org.webrtc.videoengineapp.Control;
import org.webrtc.videoengineapp.ViEAndroidJavaAPI;

public class MobileCamera implements Control
{
	private final String TAG = "MobileCamera";
	
	// 1 means front camera , 0 means back camera
	private int camera = 1;
	private int direct = 1;
	private final int degree = 90;
	
	private int cameraId;
	
	public String start(ViEAndroidJavaAPI webrtcAPI,int videoChannel)
	{
		// 1 means front camera
    	cameraId = webrtcAPI.StartCamera(videoChannel, camera);
		return "ok";
	}
	
	public String stop(ViEAndroidJavaAPI webrtcAPI,int videoChannel)
	{
		if (0 != webrtcAPI.StopCamera(cameraId))
    	{
    		Log.d(TAG, "Video stop Camera failed");
    		return "stop Camera failed";
    	}
		return "ok";
	}
	
	public void setCameraFrontOrBack(int which)
	{
		switch(which)
		{
		    case 0:
		    case 1:
		    	camera = which;
		    	break;
		    default:
		    	break;
		}
		return;
	}
	
	public String rotationCamera(ViEAndroidJavaAPI webrtcAPI)
	{
		if (0 != webrtcAPI.SetRotation(cameraId, degree * direct))
		{
			Log.d(TAG, "Video rotation Camera failed");
			return "rotation Camera failed";
		}
		else
		{
			direct = (direct + 1) % 4;
			return "ok";
		}
	}
	
	public void changeCamera()
	{
		camera = camera == 0 ? 1 : 0;
		return;
	}
}