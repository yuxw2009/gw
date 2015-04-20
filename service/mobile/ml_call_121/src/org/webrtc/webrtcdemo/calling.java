package org.webrtc.webrtcdemo;

import org.webrtc.voiceengine.WebRTCAudioDevice;


import android.app.Activity;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

public class calling extends Activity implements View.OnClickListener, UserCallback {
	private CallMaker call = null;
	
	private Button btStopCall;
	private TextView peerPhone;
	private TextView callStatus;
	private String mySelfPhone; 
	private String callPeerPhone; 
	private int audioMode;
	private WebRTCAudioDevice WebRTCAudioDevice= null;

	
	public void ring(){
	 callStatus.setText("对端正在振铃");
	 // Toast.makeText(this, , Toast.LENGTH_LONG).show();
	};
		
	public void talking(){
		callStatus.setText("正在通话");
	 //  Toast.makeText(this, "正在通话...", Toast.LENGTH_LONG).show();
	};
	
	public void hangup(){
		release();		
	};
	
	private enum State {  
       IDLE, CALLING, TALKING  
    }; 
    
    private State state = State.IDLE;
    
@Override
	
	protected void onCreate(Bundle savedInstanceState) { 
		super.onCreate(savedInstanceState);
		setContentView(R.layout.calling);		
	    Bundle bundle=this.getIntent().getExtras();		    
	    mySelfPhone=bundle.getString("my_Selfphone");
	    callPeerPhone=bundle.getString("call_PeerPhone");	    
	    audioMode = bundle.getInt("audioMode");
	    
		Log.d("callbefore", "mySelfPhone" + mySelfPhone);		
		Log.d("callbefore", "callPeerPhone" + callPeerPhone);
		
		WebRTCAudioDevice = new WebRTCAudioDevice(this);
		 
		call = new CallMaker(this,this, audioMode);	
		
		btStopCall   = (Button) findViewById(R.id.btStopCall);
		peerPhone = (TextView) findViewById(R.id.peerPhone);
		callStatus = (TextView) findViewById(R.id.callStatus);			
		peerPhone.setText(callPeerPhone);		
		btStopCall.setOnClickListener(this);		
		toMakeCall();	
	}  


    
	@Override
	protected void onDestroy() {
		WebRTCAudioDevice.setPlayoutSpeekNormal();
		super.onDestroy();         
	}

	@Override
	public void onClick(View v) {
		// TODO Auto-generated method stub		
		switch (v.getId()){
		case R.id.btStopCall:
			new CallStoper().execute("");
			break;
		default:
			break;
	 }
	}
	
	
	
	private void release(){
		call.release();
		call = null;  
		finish();
	}  	

	private void showToast(String msg){
		Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
	}
	
	private void toMakeCall(){	
		new CallStarter().execute("");

	}
	
	
	public class CallStarter extends AsyncTask<String, Integer, String>{
		@Override
		protected String doInBackground(String... data){		
			// return call.startCall(callPeerPhone + "@my_token@my_finger" , "registered", mySelfPhone);
		 return call.startCall(callPeerPhone , "game", mySelfPhone);
		}
		
		@Override
		protected void onPostExecute(String rt){
			super.onPostExecute(rt);
			//showToast(rt);
			showToast( "发起成功，音频模式为" + WebRTCAudioDevice.getAudioMode());
		}
	}	


	public class CallStoper extends AsyncTask<String, Integer, String>{	
		@Override
		protected String doInBackground(String... data){
			return call.stopCall();
		}
		
		@Override 
		protected void onPostExecute(String rt){
			super.onPostExecute(rt);
			release();
		}
	}
	

	
}
