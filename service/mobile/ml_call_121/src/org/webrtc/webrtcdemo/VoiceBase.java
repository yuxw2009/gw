package org.webrtc.webrtcdemo;

import java.util.ArrayList;
import java.util.List;

import android.media.AudioManager;
import android.util.Log;
import android.content.Context;

public class VoiceBase
{
	private String TAG = "VoiceBase";
	
	private int voiceChannel = -1;
	
	private MobileListen  listen = null;
	private MobilePlayout playout = null;
	private VoiceStream   stream = null;
	private VoiceReceiver receiver = null;
	private VoiceEngine webrtcAPI = null;
	private final Context context;
	
	public VoiceBase(Context context,WebRtcBase base, int audioMode)
	{
		webrtcAPI = base.getAPI();
	    this.context = context;		
        voiceChannel = webrtcAPI.createChannel();        
        listen     = new MobileListen();
        playout    = new MobilePlayout();
        stream     = new VoiceStream(context, audioMode);
        receiver   = new VoiceReceiver();        
        Log.d(TAG, "VoE construct ok");
        return;
	}
	
	public void release()
	{
		if (0 != webrtcAPI.deleteChannel(voiceChannel))
		{
			Log.d(TAG, "VoE delete voice channel failed");
            throw new RuntimeException("VoE delete voice channel failed");
		}
		Log.d(TAG, "VoE delete voice channel success");
        voiceChannel = -1;        
        return;
	}	
	
	/*************************************************************************/
	
	public int getVoiceChannel()
	{
		return voiceChannel;
	}
	
    /*************************************************************************/	
	public String getRemoteIP()
	{
		return receiver.getRemoteIP();
	}
	
	public int getDestPort()
	{
		return receiver.getDestPort();
	}
	
	public int getSendCodec()
	{
		return stream.getSendCodec();
	}
	
	public void setRemoteIP(String IP)
	{
		receiver.setRemoteIP(IP);
		return;
	}
	
	public void setDestPort(int port)
	{
		receiver.setDestPort(port);
		return;
	}
	
	/*************************************************************************/
	
	public void setReceivePort(int port)
	{
		receiver.setReceivePort(port);
		return;
	}
	
	public int getReceivePort()
	{
		return receiver.getReceivePort();
	}

	/*************************************************************************/
	
	public String startVoiceReceive()
	{
		List<Control> controls = new ArrayList<Control>();
		
    	controls.add(receiver);    	
    	controls.add(listen);
    	
	//	setEnableLoudSpeaker(false);	
    	
    	return LogicCalc.and(webrtcAPI, voiceChannel, controls, 0);
	}
	
	public String stopVoiceReceive()
	{
		List<Control> controls = new ArrayList<Control>();
		
		controls.add(listen);
    	controls.add(receiver);
    	
    	return LogicCalc.or(webrtcAPI, voiceChannel, controls, 1);
	}
	
	/*************************************************************************/
	
	public String startVoiceSend()
	{
		List<Control> controls = new ArrayList<Control>();	
		controls.add(playout);
    	controls.add(stream);
    	return LogicCalc.and(webrtcAPI, voiceChannel, controls, 0);
	}
	
	public String stopVoiceSend()
	{
		List<Control> controls = new ArrayList<Control>();
		controls.add(stream);
    	controls.add(playout);
    	return LogicCalc.or(webrtcAPI, voiceChannel, controls, 1);
	}
	
	/*************************************************************************/

	public int setAudioCodec() {		 
	    CodecInst codec = webrtcAPI.getCodec(getIsacIndex());	    
	    Log.d("send-codec", "" + codec);	    
	    if(webrtcAPI.setSendCodec(voiceChannel, codec) != 0){	    	 
	      Log.d(TAG, "Failed setSendCodec");
          return -1;
	    }	
	    Log.d("send-codec", "success");
	    codec.dispose();
	    return 0;		    
	}
		
	private CodecInst[] defaultAudioCodecs() {			  
	   Log.d(TAG, "defaultAudioCodecs begin" + webrtcAPI.numOfCodecs()); 			
	   CodecInst[] retVal = new CodecInst[webrtcAPI.numOfCodecs()];		    
	   Log.d(TAG, "defaultAudioCodecs begin" + retVal);			
	   for (int i = 0; i < webrtcAPI.numOfCodecs(); ++i) {
	    retVal[i] = webrtcAPI.getCodec(i);
	   }
	   return retVal;
	}
		
	public int getIsacIndex() {
	   Log.d(TAG, "getIsacIndex begin");
	   CodecInst[] codecs = defaultAudioCodecs();
	   Log.d(TAG, "getcodecs begin" + codecs);
	   for (int i = 0; i < codecs.length; ++i) {
		  if (codecs[i].name().contains("ILBC")) {
		    return i;
		  }
	   }
	   return 0;
	}

}