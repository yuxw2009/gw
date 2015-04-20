package org.webrtc.webrtcdemo;

import java.util.ArrayList;
import org.webrtc.httpclient.RestAPI;
import android.util.Log;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder; 

public class smsMaker {
	
	private RestAPI   restAPI   = null;	
	
	public smsMaker()
	{
		restAPI = new RestAPI();
        return;
    }
	

	
	private String encodeUTF(String str){
		String message = str;		
		try {  			
            message = URLEncoder.encode(str, "UTF-8");  
   
        } catch (UnsupportedEncodingException e) {  
            e.printStackTrace();  
        }  
		
		return message;		
	}

	
	public String sendSms(String content, String signature, ArrayList<String> members)	
	{		
		RestAPI.SMSRtn rslt = restAPI.sendSms("206", content, signature, members);	
			if (rslt.status == 0){	
				return "ok";
			}else{
				Log.d("sendSMS", "login http failed reason:" + rslt.reason);
				return  rslt.reason;		
			
			}
			
	} 
		
	
	
}
