/*
 *  Copyright (c) 2012 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

package org.webrtc.voiceengine;

import java.nio.ByteBuffer;
import java.util.concurrent.locks.ReentrantLock;

import android.annotation.SuppressLint;
import android.content.Context;
import android.media.AudioManager;
import android.util.Log;
import android.widget.Toast;
import android.os.Build;
public class WebRTCAudioDevice {
	
    private Context _context;
    private AudioManager _audioManager;
    
    private ByteBuffer _playBuffer;
    private ByteBuffer _recBuffer;
    private byte[] _tempBufPlay;
    private byte[] _tempBufRec;
    private final ReentrantLock _playLock = new ReentrantLock();
    private final ReentrantLock _recLock = new ReentrantLock();
    private int audioMode;
    
    public WebRTCAudioDevice(Context context) {    
    	this._context = context;		
        try {
            _playBuffer = ByteBuffer.allocateDirect(2 * 480); // Max 10 ms @ 48
                                                              // kHz
            _recBuffer = ByteBuffer.allocateDirect(2 * 480); // Max 10 ms @ 48
                                                             // kHz
        } catch (Exception e) {
            DoLog(e.getMessage());
        }
        _tempBufPlay = new byte[2 * 480];
        _tempBufRec = new byte[2 * 480];           
        setDefaultAudioMode();           
    }
    
    private void setDefaultAudioMode(){
         
         String str = Build.BRAND;
 	     String str2 = Build.MODEL.replaceAll(" ", "");
 	     
    	 audioMode = AudioManager.MODE_IN_COMMUNICATION;  
    	 
         _audioManager = (AudioManager) _context.getSystemService(_context.AUDIO_SERVICE);	
         
 	   if ((str != null) && ((str.equals("yusu")) || (str.equals("yusuH701")) || (str.equals("yusuA2")) || (str.equals("qcom")) || (str.equals("motoME525"))))
       {
          audioMode = AudioManager.MODE_IN_CALL;
       }
 	  
 	    else if ((str.equals("Huawei")) && (str2.equals("HUAWEIP6-C00")))
        {         
         audioMode = AudioManager.MODE_NORMAL;
        }
 	  
 	    else if ((str.equals("Lenovo")) && (str2.equals("LenovoA788t")))
        {
         audioMode = AudioManager.MODE_IN_CALL;
                       
        }
 	    else if ((str.equals("Lenovo")) && (str2.equals("LenovoA760")))
        {
         audioMode = AudioManager.MODE_IN_CALL;
              
        } 	   
 	    else if (str2.equals("MI2SC"))
        {
           audioMode = AudioManager.MODE_IN_CALL;              
        } 	   
 	    else if ((str.equals("ZTE")) && (str2.equals("ZTEV5S")))
        {
 		  DoLog("SetPlayoutSpeaker ZTE V5S");
    	  audioMode = AudioManager.MODE_IN_CALL;                    
        } 
 	    else if ((str.equals("ZTE")) && (str2.equals("ZTEN5S")))
        {
 		  DoLog("SetPlayoutSpeaker ZTE V5S");
    	  audioMode = AudioManager.MODE_IN_CALL;                    
        }
 	   
 	    else if ((str.equals("samsung")) && (str2.equals("GT-I9508")))
        {
 		  DoLog("SetPlayoutSpeaker samsung GT-I9508");
    	  audioMode = AudioManager.MODE_IN_CALL;                    
        }   
 	   
    }
    
    
    public int setAudioMode(int mode){ 
        if(mode == 1 ){
        	audioMode = AudioManager.MODE_NORMAL;        	
         }
        if(mode == 2){
        	audioMode = AudioManager.MODE_IN_CALL;
        }        
        if(mode == 3){         
           audioMode = AudioManager.MODE_IN_COMMUNICATION;
        } 
        if(mode == 4){         
           audioMode = 4;
         }         
    	return 0;
    }
    
    public String getAudioMode(){
    	int currentMode = _audioManager.getMode();
    	String modeDescript = null;
     
        if(currentMode == AudioManager.MODE_NORMAL){
        	modeDescript = "MODE_NORMAL";
        }
        
        if(currentMode == AudioManager.MODE_IN_CALL){
        	modeDescript = "MODE_IN_CALL";
        }
        
        if(currentMode == AudioManager.MODE_IN_COMMUNICATION ){
        	modeDescript = "MODE_IN_COMMUNICATION";       
        }  
        if(currentMode == 4 ){
        	modeDescript = "voip mode";       
        }        
    	return modeDescript;
    }  
  
    
    
    public int setPlayoutMicrophone(boolean microphoneMute){    	
    	
        // create audio manager if needed
    	DoLog("setPlayoutMicrophone:" + microphoneMute);
        if (_audioManager == null && _context != null) {
            _audioManager = (AudioManager)
                _context.getSystemService(Context.AUDIO_SERVICE);
        }

        if (_audioManager == null) {
            DoLogErr("Could not change audio routing - no audio manager");
            return -1;
        }
        
    	_audioManager.setMicrophoneMute(microphoneMute);   
    	return 0;
    }
    
    
    public boolean getMicrophoneMute(){    	
        // create audio manager if needed
    	DoLog("getMicrophoneMute");
        if (_audioManager == null && _context != null) {
            _audioManager = (AudioManager)
            _context.getSystemService(Context.AUDIO_SERVICE);
        }

        if (_audioManager == null) {
            DoLogErr("Could not change audio routing - no audio manager");
            return false;
        }        
      return _audioManager.isMicrophoneMute();
    }

    
    @SuppressLint("InlinedApi")
	public  int SetPlayoutSpeaker(boolean loudspeakerOn) {
    	
        // create audio manager if needed
    	DoLog("SetPlayoutSpeaker:" + loudspeakerOn);
    	
        if (_audioManager == null && _context != null) {
         _audioManager = (AudioManager) _context.getSystemService(Context.AUDIO_SERVICE);
        }
        
        if (_audioManager == null) {
            DoLogErr("Could not change audio routing - no audio manager");
            return -1;
        }
        
		int apiLevel = Integer.parseInt(Build.VERSION.SDK);		
        
        DoLog("SetPlayoutSpeaker apiLevel:" + apiLevel);
        
        if ((3 == apiLevel) || (4 == apiLevel)) {
            // 1.5 and 1.6 devices
        	DoLog("SetPlayoutSpeaker apiLevel 3 4:" + loudspeakerOn);
            if (loudspeakerOn) {
                // route audio to back speaker
                _audioManager.setMode(AudioManager.MODE_NORMAL);
            } else {
                // route audio to earpiece
                _audioManager.setMode(AudioManager.MODE_IN_CALL);
            }
        } else {
            // 2.x devices
            if ((android.os.Build.BRAND.equals("Samsung") ||
                            android.os.Build.BRAND.equals("samsung")) &&
                            ((5 == apiLevel) || (6 == apiLevel) || (7 == apiLevel)))
            {                
            	// Samsung 2.0, 2.0.1 and 2.1 devices
            	DoLog("SetPlayoutSpeaker Samsung:" + loudspeakerOn);
            	
                if (loudspeakerOn) {
                    // route audio to back speaker
                	_audioManager.setMode(AudioManager.MODE_IN_CALL);
                    _audioManager.setSpeakerphoneOn(loudspeakerOn);
                    
                } else {
                    // route audio to earpiece
                    _audioManager.setSpeakerphoneOn(loudspeakerOn);
                    _audioManager.setMode(AudioManager.MODE_NORMAL);
                }
            } else { 
               // Non-Samsung and Samsung 2.2 and up devices            	
                DoLog("phone BRAND:" + android.os.Build.BRAND + "  phone MODEL:" + android.os.Build.MODEL);
                _audioManager.setMode(audioMode);
            	System.out.println("模式设置为" + _audioManager.getMode());  
            	_audioManager.setSpeakerphoneOn(loudspeakerOn);            	
            }
            
        }

        return 0;
    }
    
    
   public int setRingMode(){
       if (_audioManager == null && _context != null) {
           _audioManager = (AudioManager)
               _context.getSystemService(Context.AUDIO_SERVICE);
       }

       if (_audioManager == null) {
           DoLogErr("Could not change audio routing - no audio manager");
           return -1;
       }        
       _audioManager.setMode(AudioManager.MODE_RINGTONE);        
		return 0;  	   

   } 
   
	
    public int setPlayoutSpeekNormal(){    	
        // create audio manager if needed
        if (_audioManager == null && _context != null) {
            _audioManager = (AudioManager)
                _context.getSystemService(Context.AUDIO_SERVICE);
        }

        if (_audioManager == null) {
            DoLogErr("Could not change audio routing - no audio manager");
            return -1;
        }        
        _audioManager.setMode(AudioManager.MODE_NORMAL);        
		return 0;  
        
    }
    

    public boolean getSpeakerphoneOn(){   	
        if (_audioManager == null && _context != null) {
            _audioManager = (AudioManager)
                _context.getSystemService(Context.AUDIO_SERVICE);
        }

        if (_audioManager == null) {
            DoLogErr("Could not change audio routing - no audio manager");
            return false;
        }     	
    	return _audioManager.isSpeakerphoneOn();
    }
    


    final String logTag = "WebRTC AD java";

    private void DoLog(String msg) {
        Log.d(logTag, msg);
    }

    private void DoLogErr(String msg) {
        Log.e(logTag, msg);
    }
}
