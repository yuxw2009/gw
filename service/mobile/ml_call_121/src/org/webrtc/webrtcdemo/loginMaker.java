package org.webrtc.webrtcdemo;

import org.webrtc.httpclient.RestAPI;
import android.util.Log;


public class loginMaker {
	private String TAG = "LoginMaker";
	private RestAPI   restAPI   = null;
	public loginMaker()
	{
		restAPI    = new RestAPI();
        return;
    }
	
	public String startLogin(String userName, String password)
	{
		
		RestAPI.LoginRtn rslt = restAPI.startLogin(userName, password);	
		if (rslt.status == 0)
		{
			return "ok";			
			
		}else{		
			
			Log.d(TAG, "login http failed reason:" + rslt.reason);
			return rslt.reason;		
			
		}		
	}
	

}

