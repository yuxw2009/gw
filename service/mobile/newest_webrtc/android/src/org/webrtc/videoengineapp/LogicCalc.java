package org.webrtc.videoengineapp;

import java.util.ArrayList;
import java.util.List;

import org.webrtc.videoengineapp.Control;

class LogicCalc
{
	static public String and(ViEAndroidJavaAPI webrtcAPI,int voiceChannel,List<Control> control,int method)
	{
		String status = "";
		int num = control.size();
		Control[] aControl = control.toArray(new Control[num]);
		for (int i = 0 ; i < num ; i++)
		{
			status = (method == 0)?aControl[i].start(webrtcAPI,voiceChannel):aControl[i].stop(webrtcAPI,voiceChannel);
			if (0 != status.compareTo("ok"))
			{
				for (int j = i - 1;j >= 0;j--)
				{
					if (method == 0)
					{
						aControl[j].stop(webrtcAPI,voiceChannel);
					}
					else
					{
						aControl[j].start(webrtcAPI,voiceChannel);
					}
				}
				return status;
			}
		}
		return "ok";
	}
	
	static public String or(ViEAndroidJavaAPI webrtcAPI,int voiceChannel,List<Control> control,int method)
	{
		String status = "";
		List<String> values = new ArrayList<String>();
		int num = control.size();
		Control[] aControl = control.toArray(new Control[num]);
		for (int i = 0 ; i < num ; i++)
		{
			status = (method == 0)?aControl[i].start(webrtcAPI,voiceChannel):aControl[i].stop(webrtcAPI,voiceChannel);
			if (0 != status.compareTo("ok"))
			{
				values.add(status);
			}
		}
		return orValue(values);
	}
	
	static public String orValue(List<String> values)
	{
		String rtn = "";
		int num = values.size();
		String[] aValues = values.toArray(new String[num]);
		for (int i = 0 ; i < num ; i++)
		{
			if (aValues[i].compareTo("ok") != 0)
			{
				rtn += (aValues[i] + "&");
			}
		}
		return (rtn.compareTo("") == 0) ? "ok" : rtn.substring(0, rtn.length() - 1);
	}
}