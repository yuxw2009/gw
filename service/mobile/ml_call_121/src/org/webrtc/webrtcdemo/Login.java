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
	
	/** 以下是UI */
	private EditText view_userName;
	private EditText view_password;
	private CheckBox view_rememberMe;
	private Button view_loginSubmit;
	
	private static final int MENU_EXIT = Menu.FIRST - 1;
	private static final int MENU_ABOUT = Menu.FIRST;
	
	/** 用来操作SharePreferences的标识 */
	private final String SHARE_LOGIN_TAG = "MAP_SHARE_LOGIN_TAG";

	/** 如果登录成功后,用于保存用户名到SharedPreferences,以便下次不再输入 */
	private String SHARE_LOGIN_USERNAME = "MAP_LOGIN_USERNAME";

	/** 如果登录成功后,用于保存PASSWORD到SharedPreferences,以便下次不再输入 */
	private String SHARE_LOGIN_PASSWORD = "MAP_LOGIN_PASSWORD";

	/** 如果登陆失败,这个可以给用户确切的消息显示,true是网络连接失败,false是用户名和密码错误 */
	
	private boolean isNetError;

	/** 登录loading提示框 */
	private ProgressDialog proDialog;
	

	/** 登录后台通知更新UI线程,主要用于登录失败,通知UI线程更新界面 */
	Handler loginHandler = new Handler() {
		public void handleMessage(Message msg) {
			Log.d("login rst", msg + "  127 line");
			isNetError = msg.getData().getBoolean("isNetError");
			if (proDialog != null) {
				proDialog.dismiss();
			}
			if (isNetError) {
				Toast.makeText(Login.this, "登陆失败:请检查您网络连接!",
			    Toast.LENGTH_SHORT).show();
			}
			// 用户名和密码错误
			else {
				Toast.makeText(Login.this, "登陆失败,请输入正确的用户名和密码!",
				Toast.LENGTH_SHORT).show();
				// 清除以前的SharePreferences密码
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

	/** 初始化注册View组件 */
	private void findViewsById() {
		view_userName = (EditText) findViewById(R.id.loginUserNameEdit);
		view_password = (EditText) findViewById(R.id.loginPasswordEdit);
		view_rememberMe = (CheckBox) findViewById(R.id.loginRememberMeCheckBox);
		view_loginSubmit = (Button) findViewById(R.id.loginSubmit);
	}

	/**
	 * 初始化界面
	 * 
	 * @param isRememberMe *  如果当时点击了RememberMe,并且登陆成功过一次,则saveSharePreferences(true,ture)后,则直接进入
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
		// 如果密码也保存了,则直接让登陆按钮获取焦点
		if (view_password.getText().toString().length() > 0) {
			
			 // view_loginSubmit.requestFocus();
			// view_password.requestFocus();
			
			  proDialog = ProgressDialog.show(Login.this, "登录提示", "正在登录，请稍后....", true, true);
			  toLogin();
		}
		share = null;
	}
	

	/**
	 * 如果登录成功过,则将登陆用户名和密码记录在SharePreferences
	 * 
	 * @param saveUserName
	 *            是否将用户名保存到SharePreferences
	 * @param savePassword
	 *            是否将密码保存到SharePreferences
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
	

	/** 记住我的选项是否勾选 */
	private boolean isRememberMe() {
		if (view_rememberMe.isChecked()) {
			return true;
		}
		return false;
	}

	/** 登录Button Listener */
	private OnClickListener submitListener = new OnClickListener() {
		@Override
		public void onClick(View v) {
		  userName = view_userName.getText().toString();
		  password = view_password.getText().toString();			
		  proDialog = ProgressDialog.show(Login.this, "登录提示", "正在登录，请稍后....", true, true);
		  toLogin();
		}
	};
	
	private boolean GetSettings(){
		if (userName.length() == 0){
			Toast.makeText(this, "用户名不能为空！", Toast.LENGTH_LONG).show();	
			return false;
		}
		if (password.length() == 0){
			Toast.makeText(this, "密码不能为空！", Toast.LENGTH_LONG).show();	
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
	    	   
				// 需要传输数据到登陆后的界面,
				Intent intent = new Intent();
				intent.setClass(Login.this, Mailcall.class);	
				Bundle bundle = new Bundle();				
			    bundle.putString("my_Selfphone", userName);	
				intent.putExtras(bundle);
				// 转向登陆后的页面
			    startActivity(intent);
		  }else{
			  
			  showToast("登录失败，请稍后再试");
		  }
	}
	
	
	/** 记住我checkBoxListener */
	private OnCheckedChangeListener rememberMeListener = new OnCheckedChangeListener() {
		@Override
		public void onCheckedChanged(CompoundButton buttonView,
				boolean isChecked) {
			if (view_rememberMe.isChecked()) {
				Toast.makeText(Login.this, "如果登录成功,以后账号和密码会自动输入!",
						Toast.LENGTH_SHORT).show();
			}
		}
	};

	/** 设置监听器 */
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

	/** 弹出关于对话框 */
	private void alertAbout() {
		new AlertDialog.Builder(Login.this).setTitle(R.string.MENU_ABOUT).setMessage(R.string.aboutInfo).setPositiveButton(
			R.string.ok_label,
			new DialogInterface.OnClickListener() {
				public void onClick(
						DialogInterface dialoginterface, int i) {
				}
		}).show();
	}

	/** 清除密码 */
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

			// 登陆成功
			if (loginState) {
			
				// 需要传输数据到登陆后的界面,
				Intent intent = new Intent();
				
				//intent.setClass(Login.this, Mailcall.class);				
				Bundle bundle = new Bundle();				
				//bundle.putString("MAP_USERNAME", userName);				
				//intent.putExtras(bundle);
				// 转向登陆后的页面
				//startActivity(intent);
				proDialog.dismiss();
			
			} else {
				// 通过调用handler来通知UI主线程更新UI,
				Message message = new Message();
				Bundle bundle = new Bundle();
				bundle.putBoolean("isNetError", isNetError);
				message.setData(bundle);
				loginHandler.sendMessage(message);
			}
		}

	}*/
	
}
