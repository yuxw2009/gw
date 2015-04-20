package org.webrtc.videoengineapp;

import java.util.ArrayList;
import java.util.List;

import android.util.Log;

import org.webrtc.videoengineapp.LogicCalc;

public class VoiceBase
{
	private String TAG = "VoiceBase";
	
	private int voiceChannel = -1;
	
	private MobileListen  listen = null;
	private MobilePlayout playout = null;
	private VoiceStream   stream = null;
	private VoiceReceiver receiver = null;
	private ViEAndroidJavaAPI webrtcAPI = null;
	
	public VoiceBase(WebRtcBase base)
	{
		webrtcAPI = base.getAPI();
        voiceChannel = webrtcAPI.VoE_CreateChannel();
        
        listen     = new MobileListen();
        playout    = new MobilePlayout();
        stream     = new VoiceStream();
        receiver   = new VoiceReceiver();
        
        Log.d(TAG, "VoE construct ok");
        return;
	}
	
	public void release()
	{
		if (0 != webrtcAPI.VoE_DeleteChannel(voiceChannel))
		{
			Log.d(TAG, "VoE delete voice channel failed");
            throw new RuntimeException("VoE delete voice channel failed");
		}
		
        voiceChannel = -1;
        return;
	}
	
	/*************************************************************************/
	
	public int getVoiceChannel()
	{
		return voiceChannel;
	}
	
	/*************************************************************************/
	
	public String setSendCodecType(String codec)
	{
	    int codeNum = getCodec(codec);
	    if (-1 == codeNum)
	    {
	    	return "codec not support";
	    }
	    else
	    {
	    	stream.setSendCodec(codeNum);
	    	return "ok";
	    }
	}
	
    /*************************************************************************/
	
	public String getRemoteIP()
	{
		return stream.getRemoteIP();
	}
	
	public int getDestPort()
	{
		return stream.getDestPort();
	}
	
	public int getSendCodec()
	{
		return stream.getSendCodec();
	}
	
	public void setRemoteIP(String IP)
	{
		stream.setRemoteIP(IP);
		return;
	}
	
	public void setDestPort(int port)
	{
		stream.setDestPort(port);
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
	
	public void setVolumeLevel(int vol)
	{
		listen.setVolumeLevel(vol);
		return;
	}
	
	public void setLoudSpeaker(boolean bool)
	{
		listen.setEnableLoudSpeaker(bool);
		return;
	}
	
	/*************************************************************************/
	
	public String startVoiceReceive()
	{
		List<Control> controls = new ArrayList<Control>();
    	controls.add(receiver);
    	controls.add(listen);
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
	
	private int getCodec(String Codec)
	{
		String[] mVoiceCodecsStrings = webrtcAPI.VoE_GetCodecs();
		for (int i = 0; i < mVoiceCodecsStrings.length; i++) 
		{
            if (mVoiceCodecsStrings[i].contains(Codec)) 
            {
            	return i;
            }
        }
		return -1;
	}
	
	/*************************************************************************/
}