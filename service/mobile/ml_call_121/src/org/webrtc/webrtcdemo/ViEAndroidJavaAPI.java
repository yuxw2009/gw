/*
 *  Copyright (c) 2012 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

package org.webrtc.webrtcdemo;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

public class ViEAndroidJavaAPI {
	
    public ViEAndroidJavaAPI(Context context) {
        Log.d("*WEBRTCJ*", "Loading ViEAndroidJavaAPI...");
        System.loadLibrary("webrtc-video-demo-jni");
        Log.d("*WEBRTCJ*", "Calling native init...");
        
  /*   if (!NativeInit(context)) {
            Log.e("*WEBRTCJ*", "Native init failed");
            throw new RuntimeException("Native init failed");
        }
        else {
            Log.d("*WEBRTCJ*", "Native init successful");
        } */
        
        String a = "";
        a.getBytes();
    }

    
  
   // API Native
    private native boolean NativeInit(Context context);
    
    
    
 /*   
   // Voice Engine API
   // Create and Delete functions
    public native boolean VoE_Create(Context context);
    public native boolean VoE_Delete();
    // Initialization and Termination functions
    public native int VoE_Init(boolean enableTrace);
    public native int VoE_Terminate();
    // Channel functions
    public native int VoE_CreateChannel();
    public native int VoE_DeleteChannel(int channel);
    public native int ViE_DeleteChannel(int channel);
    // Receiver & Destination functions
    public native int VoE_SetLocalReceiver(int channel, int port);
    public native int VoE_SetSendDestination(int channel, int port, String ipaddr);
    // Media functions
    public native int VoE_StartListen(int channel);
    public native int VoE_StartPlayout(int channel);
    public native int VoE_StartSend(int channel);
    public native int VoE_StopListen(int channel);
    public native int VoE_StopPlayout(int channel);
    public native int VoE_StopSend(int channel);
    // Volume
    public native int VoE_SetSpeakerVolume(int volume);
    // Hardware
    public native int VoE_SetLoudspeakerStatus(boolean enable);
    // Playout file locally
    public native int VoE_StartPlayingFileLocally(
        int channel,
        String fileName,
        boolean loop);
    public native int VoE_StopPlayingFileLocally(int channel);
    // Play file as microphone
    public native int VoE_StartPlayingFileAsMicrophone(
        int channel,
        String fileName,
        boolean loop);
    public native int VoE_StopPlayingFileAsMicrophone(int channel);
    // Codec-setting functions
    public native int VoE_NumOfCodecs();
    public native String[] VoE_GetCodecs();
    public native int VoE_SetSendCodec(int channel, int index);
    //VoiceEngine funtions
    public native int VoE_SetECStatus(boolean enable);
    public native int VoE_SetAGCStatus(boolean enable);
    public native int VoE_SetNSStatus(boolean enable);
    public native int VoE_StartDebugRecording(String file);
    public native int VoE_StopDebugRecording();
    public native int VoE_StartIncomingRTPDump(int channel, String file);
    public native int VoE_StopIncomingRTPDump(int channel);
         
  */
    
}
