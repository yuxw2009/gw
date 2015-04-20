package org.webrtc.webrtcdemo;

import org.webrtc.httpclient.RestAPI;

import android.util.Log;

public class authcodeMaker {
	
private RestAPI   restAPI   = null;	
	
	public authcodeMaker()
	{
		restAPI = new RestAPI();
        return;
    }
		
	public String getAuthCode(String uuid)	
	{		
		RestAPI.authCodeRtn rslt = restAPI.getAuthCode(uuid);		
		  if (rslt.status == 0){	
				Log.d("sendSMS", "login http failed reason:" + rslt.reason);
			return "ok";
		  }else{
			Log.d("sendSMS", "login http failed reason:" + rslt.reason);
			return  rslt.reason;			
		  }			
	}

}
