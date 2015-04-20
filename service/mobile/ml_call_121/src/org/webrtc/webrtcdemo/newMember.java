package org.webrtc.webrtcdemo;

public class newMember {
	  private String name;   //姓名
	  private String phone;  //手机号
	  
	 public newMember(String memname, String memphone){
		 name = memname;
		 phone = memphone;
	 }
	 
	 public newMember() {
			
	 }
	  //set/get 方法，成员列表
	 public String getName() {
	  return name;
	 }
	 public void setName(String name) {
	  this.name = name;
	 }
	 public String getPhone() {
	  return phone;
	 }
	 public void setPhone(String phone) {
	  this.phone = phone;
	 }

}
