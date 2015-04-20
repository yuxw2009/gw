package org.webrtc.webrtcdemo;

import org.webrtc.webrtcdemo.VoiceEngine;

public interface Control 
{
    String start(VoiceEngine webrtcAPI,int channel);
    String stop(VoiceEngine webrtcAPI,int channel);
};