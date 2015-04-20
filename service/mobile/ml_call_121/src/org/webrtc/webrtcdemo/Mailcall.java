package org.webrtc.webrtcdemo;

import java.util.ArrayList;



import android.app.Activity;
import android.app.ProgressDialog;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;
import android.widget.EditText;
import android.widget.Toast;

public class Mailcall extends Activity 
{
	private EditText txtPhone;
	private String PrNo = "";
	private String mySelfPhone; 
	private Button btCall;
	
	private ArrayList<CheckBox> list = new ArrayList<CheckBox>();  
	private CheckBox setModeNormal,setModeIncall,MODE_IN_COMMUNICATION, MODE_4; 
	private int audioMode = 2 ;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) { 
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_mailcall);	
	    Bundle bundle=this.getIntent().getExtras();		
	    mySelfPhone=bundle.getString("my_Selfphone");
	    Toast.makeText(this, "主叫号码为:" + mySelfPhone, Toast.LENGTH_LONG).show();	
		txtPhone = (EditText) findViewById(R.id.peerNum);
		btCall   = (Button) findViewById(R.id.StartCall);		
		btCall.setOnClickListener(startCallListener);
        findCheckboxViews(); 
	}
	
	
	private void findCheckboxViews() {  
		setModeNormal = (CheckBox) this.findViewById(R.id.setModeNormal);  
		setModeIncall = (CheckBox) this.findViewById(R.id.setModeIncall);  
		MODE_IN_COMMUNICATION = (CheckBox) this.findViewById(R.id.MODE_IN_COMMUNICATION);  
		MODE_4 = (CheckBox) this.findViewById(R.id.MODE_4);  
      
        //注册事件监听器  
		setModeNormal.setOnCheckedChangeListener(listener);  
		setModeIncall.setOnCheckedChangeListener(listener);  
		MODE_IN_COMMUNICATION.setOnCheckedChangeListener(listener);  
		MODE_4.setOnCheckedChangeListener(listener);  		
    } 

	//响应事件  
    private OnCheckedChangeListener listener = new OnCheckedChangeListener(){  
        @Override 
        public void onCheckedChanged(CompoundButton buttonView, boolean isChecked)  
        {  
            //cBox1被选中  
            if (buttonView.getId()==R.id.setModeNormal){  
                if (isChecked){
                	setModeIncall.setChecked(false);
                	MODE_IN_COMMUNICATION.setChecked(false);
                 	MODE_4.setChecked(false);
                	audioMode = 1;
                    Toast.makeText(Mailcall.this, "你选择普通模式", Toast.LENGTH_LONG).show();  
                }  
            }  
            //cBox2被选中  
            else if (buttonView.getId()==R.id.setModeIncall){  
                if (isChecked){  
                	setModeNormal.setChecked(false);
                	MODE_IN_COMMUNICATION.setChecked(false);
                 	MODE_4.setChecked(false);
                	audioMode = 2;
                    Toast.makeText(Mailcall.this, "你选择通话模式", Toast.LENGTH_LONG).show();  
                }  
            }  
            //cBox3被选中  
            else if (buttonView.getId()==R.id.MODE_IN_COMMUNICATION){  
                if (isChecked){ 
                	setModeNormal.setChecked(false);
                	setModeIncall.setChecked(false);
                 	MODE_4.setChecked(false);
                	audioMode = 3;
                    Toast.makeText(Mailcall.this, "你选择通话2模式", Toast.LENGTH_LONG).show();  
                }  
            }
            //cBox4被选中  
            else if (buttonView.getId()==R.id.MODE_4){  
                if (isChecked){ 
                	setModeNormal.setChecked(false);
                	setModeIncall.setChecked(false);
                	MODE_IN_COMMUNICATION.setChecked(false);               
                	audioMode = 4;
                    Toast.makeText(Mailcall.this, "你选择voip mode", Toast.LENGTH_LONG).show();  
                }  
            }          
            
        }  
    };   
	
	@Override
	protected void onDestroy() {  
		super.onDestroy();         
	}
	
	private boolean GetSettings(){					
		PrNo = txtPhone.getText().toString();		
		if (PrNo.length() == 0){
			Toast.makeText(this, "呼叫号码不能为空！", Toast.LENGTH_LONG).show();
			txtPhone.requestFocus();
			return false;
		}
		return true;
	}
	
	
	/** 呼叫Button Listener */
	private OnClickListener startCallListener = new OnClickListener() {
		@Override
		public void onClick(View v) {
			if (GetSettings()){
				gotoCallingActivity(txtPhone.getText().toString());
			}
		}
	};
	
	public void gotoCallingActivity(String peerPhone){
			// 需要传输数据到登陆后的界面,
			Intent intent = new Intent();
			intent.setClass(Mailcall.this, calling.class);	
			Bundle bundle = new Bundle();	
			
		    bundle.putString("call_PeerPhone", peerPhone);
		    
		    bundle.putString("my_Selfphone", mySelfPhone);	
		    bundle.putInt("audioMode", audioMode);	
		    
			intent.putExtras(bundle);
			// 转向登陆后的页面
		    startActivity(intent);
	}	
	

	
	
}
