package org.webrtc.webrtcdemo;

public class newMember {
	  private String name;   //����
	  private String phone;  //�ֻ���
	  
	 public newMember(String memname, String memphone){
		 name = memname;
		 phone = memphone;
	 }
	 
	 public newMember() {
			
	 }
	  //set/get ��������Ա�б�
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
