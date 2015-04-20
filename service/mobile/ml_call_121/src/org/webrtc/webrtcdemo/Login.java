package org.webrtc.webrtcdemo;


//import cn.waps.AppConnect;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.Toast;
import android.widget.CompoundButton.OnCheckedChangeListener;



public class Login extends Activity {	
	
	private String userName;
	private String password;

	private loginMaker login = null;
	
	/** ������UI */
	private EditText view_userName;
	private EditText view_password;
	private CheckBox view_rememberMe;
	private Button view_loginSubmit;
	
	private static final int MENU_EXIT = Menu.FIRST - 1;
	private static final int MENU_ABOUT = Menu.FIRST;
	
	/** ��������SharePreferences�ı�ʶ */
	private final String SHARE_LOGIN_TAG = "MAP_SHARE_LOGIN_TAG";

	/** �����¼�ɹ���,���ڱ����û�����SharedPreferences,�Ա��´β������� */
	private String SHARE_LOGIN_USERNAME = "MAP_LOGIN_USERNAME";

	/** �����¼�ɹ���,���ڱ���PASSWORD��SharedPreferences,�Ա��´β������� */
	private String SHARE_LOGIN_PASSWORD = "MAP_LOGIN_PASSWORD";

	/** �����½ʧ��,������Ը��û�ȷ�е���Ϣ��ʾ,true����������ʧ��,false���û������������ */
	
	private boolean isNetError;

	/** ��¼loading��ʾ�� */
	private ProgressDialog proDialog;
	

	/** ��¼��̨֪ͨ����UI�߳�,��Ҫ���ڵ�¼ʧ��,֪ͨUI�̸߳��½��� */
	Handler loginHandler = new Handler() {
		public void handleMessage(Message msg) {
			Log.d("login rst", msg + "  127 line");
			isNetError = msg.getData().getBoolean("isNetError");
			if (proDialog != null) {
				proDialog.dismiss();
			}
			if (isNetError) {
				Toast.makeText(Login.this, "��½ʧ��:��������������!",
			    Toast.LENGTH_SHORT).show();
			}
			// �û������������
			else {
				Toast.makeText(Login.this, "��½ʧ��,��������ȷ���û���������!",
				Toast.LENGTH_SHORT).show();
				// �����ǰ��SharePreferences����
				clearSharePassword();
			}
		}
	};
	

	@Override
	protected void onDestroy() {
		super.onDestroy();
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.login);
		login = new loginMaker();	
		findViewsById();
		initView(false);
		setListener();
	}

	/** ��ʼ��ע��View��� */
	private void findViewsById() {
		view_userName = (EditText) findViewById(R.id.loginUserNameEdit);
		view_password = (EditText) findViewById(R.id.loginPasswordEdit);
		view_rememberMe = (CheckBox) findViewById(R.id.loginRememberMeCheckBox);
		view_loginSubmit = (Button) findViewById(R.id.loginSubmit);
	}

	/**
	 * ��ʼ������
	 * 
	 * @param isRememberMe *  �����ʱ�����RememberMe,���ҵ�½�ɹ���һ��,��saveSharePreferences(true,ture)��,��ֱ�ӽ���
	 * */
	
	private void initView(boolean isRememberMe) {
		SharedPreferences share = getSharedPreferences(SHARE_LOGIN_TAG, 0);
		String shareuserName = share.getString(SHARE_LOGIN_USERNAME, "");
		String sharepassword = share.getString(SHARE_LOGIN_PASSWORD, "");
		Log.d(this.toString(), "shareuserName=" + shareuserName + " sharepassword="+ sharepassword);
		if (!"".equals(shareuserName)) {
			view_userName.setText(shareuserName);
			userName = shareuserName;
		}
		if (!"".equals(sharepassword)) {
			view_password.setText(sharepassword);
			view_rememberMe.setChecked(true);
			password = sharepassword;
			
		}
		// �������Ҳ������,��ֱ���õ�½��ť��ȡ����
		if (view_password.getText().toString().length() > 0) {
			
			 // view_loginSubmit.requestFocus();
			// view_password.requestFocus();
			
			  proDialog = ProgressDialog.show(Login.this, "��¼��ʾ", "���ڵ�¼�����Ժ�....", true, true);
			  toLogin();
		}
		share = null;
	}
	

	/**
	 * �����¼�ɹ���,�򽫵�½�û����������¼��SharePreferences
	 * 
	 * @param saveUserName
	 *            �Ƿ��û������浽SharePreferences
	 * @param savePassword
	 *            �Ƿ����뱣�浽SharePreferences
	 * */
	private void saveSharePreferences(boolean saveUserName, boolean savePassword) {
		SharedPreferences share = getSharedPreferences(SHARE_LOGIN_TAG, 0);
		if (saveUserName) {
			Log.d(this.toString(), "saveUserName="	+ view_userName.getText().toString());
			share.edit().putString(SHARE_LOGIN_USERNAME, view_userName.getText().toString()).commit();
		}
		if (savePassword) {
			share.edit().putString(SHARE_LOGIN_PASSWORD, view_password.getText().toString()).commit();
		}
		share = null;
	}
	

	/** ��ס�ҵ�ѡ���Ƿ�ѡ */
	private boolean isRememberMe() {
		if (view_rememberMe.isChecked()) {
			return true;
		}
		return false;
	}

	/** ��¼Button Listener */
	private OnClickListener submitListener = new OnClickListener() {
		@Override
		public void onClick(View v) {
		  userName = view_userName.getText().toString();
		  password = view_password.getText().toString();			
		  proDialog = ProgressDialog.show(Login.this, "��¼��ʾ", "���ڵ�¼�����Ժ�....", true, true);
		  toLogin();
		}
	};
	
	private boolean GetSettings(){
		if (userName.length() == 0){
			Toast.makeText(this, "�û�������Ϊ�գ�", Toast.LENGTH_LONG).show();	
			return false;
		}
		if (password.length() == 0){
			Toast.makeText(this, "���벻��Ϊ�գ�", Toast.LENGTH_LONG).show();	
			return false;
		}		
		return true;
	}		
	
	public void toLogin(){
		if (GetSettings()){
			new LoginStarter().execute("");
		}
	}
	
	private void showToast(String msg){
		Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
	}	
	
	public class LoginStarter extends AsyncTask<String, Integer, String>{
		@Override
		protected String doInBackground(String... data){		
		   return login.startLogin(userName, password);
		}
		
		@Override
		protected void onPostExecute(String rt){
			super.onPostExecute(rt);
			gotoCallActivity(rt);

		}
	}
		
	
	public void gotoCallActivity(String rslt){
	      proDialog.dismiss();
	      if (rslt.compareTo("ok") == 0){
	    	  
	    	  
	    	   if (isRememberMe()) {
					saveSharePreferences(true, true);
				} else {
					saveSharePreferences(true, false);
				}
	    	   
				// ��Ҫ�������ݵ���½��Ľ���,
				Intent intent = new Intent();
				intent.setClass(Login.this, Mailcall.class);	
				Bundle bundle = new Bundle();				
			    bundle.putString("my_Selfphone", userName);	
				intent.putExtras(bundle);
				// ת���½���ҳ��
			    startActivity(intent);
		  }else{
			  
			  showToast("��¼ʧ�ܣ����Ժ�����");
		  }
	}
	
	
	/** ��ס��checkBoxListener */
	private OnCheckedChangeListener rememberMeListener = new OnCheckedChangeListener() {
		@Override
		public void onCheckedChanged(CompoundButton buttonView,
				boolean isChecked) {
			if (view_rememberMe.isChecked()) {
				Toast.makeText(Login.this, "�����¼�ɹ�,�Ժ��˺ź�������Զ�����!",
						Toast.LENGTH_SHORT).show();
			}
		}
	};

	/** ���ü����� */
	private void setListener() {
		view_loginSubmit.setOnClickListener(submitListener);
		
	//	view_rememberMe.setOnCheckedChangeListener(rememberMeListener);
		
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		menu.add(0, MENU_EXIT, 0, getResources().getText(R.string.MENU_EXIT));
		menu.add(0, MENU_ABOUT, 0, getResources().getText(R.string.MENU_ABOUT));
		return true;
	}

	@Override
	public boolean onMenuItemSelected(int featureId, MenuItem item) {
		super.onMenuItemSelected(featureId, item);
		switch (item.getItemId()) {
		case MENU_EXIT:
			finish();
			break;
		case MENU_ABOUT:
			alertAbout();
		//	AppConnect.getInstance(this).showPopAd(this);
			break;
		}
		return true;
	}

	/** �������ڶԻ��� */
	private void alertAbout() {
		new AlertDialog.Builder(Login.this).setTitle(R.string.MENU_ABOUT).setMessage(R.string.aboutInfo).setPositiveButton(
			R.string.ok_label,
			new DialogInterface.OnClickListener() {
				public void onClick(
						DialogInterface dialoginterface, int i) {
				}
		}).show();
	}

	/** ������� */
	private void clearSharePassword() {
		SharedPreferences share = getSharedPreferences(SHARE_LOGIN_TAG, 0);
		share.edit().putString(SHARE_LOGIN_PASSWORD, "").commit();
		share = null;
	}
	
	/*
	class LoginFailureHandler implements Runnable {
		@Override
		public void run() {			
			userName = view_userName.getText().toString();
			password = view_password.getText().toString();			
			Log.d("login rst", "startlogin" + userName + password);			
			boolean loginState = loginHandle.startLogin(userName, password);			
			Log.d("login rst", "validateLogin" + loginState);

			// ��½�ɹ�
			if (loginState) {
			
				// ��Ҫ�������ݵ���½��Ľ���,
				Intent intent = new Intent();
				
				//intent.setClass(Login.this, Mailcall.class);				
				Bundle bundle = new Bundle();				
				//bundle.putString("MAP_USERNAME", userName);				
				//intent.putExtras(bundle);
				// ת���½���ҳ��
				//startActivity(intent);
				proDialog.dismiss();
			
			} else {
				// ͨ������handler��֪ͨUI���̸߳���UI,
				Message message = new Message();
				Bundle bundle = new Bundle();
				bundle.putBoolean("isNetError", isNetError);
				message.setData(bundle);
				loginHandler.sendMessage(message);
			}
		}

	}*/
	
}
