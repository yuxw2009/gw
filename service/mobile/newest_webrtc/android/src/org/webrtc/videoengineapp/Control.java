package org.webrtc.videoengineapp;

import org.webrtc.videoengineapp.ViEAndroidJavaAPI;

public interface Control 
{
    String start(ViEAndroidJavaAPI webrtcAPI,int channel);
    String stop(ViEAndroidJavaAPI webrtcAPI,int channel);
};