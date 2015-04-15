  // web socket js
  var _onlinkok = null;
  var _onlinkbroken = null;
  var VWS = false;
  if (window.WebSocket) VWS = WebSocket;
  if (!VWS && window.MozWebSocket) VWS = MozWebSocket;
  function wsClient(wsURL, on_receive, on_ok, on_brkn){
  	if(!VWS) return false;
  	//console.log('new:'+wsURL);
  	this.connect = function(){
        this._ws = new VWS(wsURL);
        this._ws.owner = this;
        this._ws.rsOK = false;
	  	this._ws.onopen = function(){
	  		this.send('connect='+uuid.toString());
	  		if(on_ok){
		  		on_ok();
		  	}
		};
	  	this._ws.onclose = function(){
	  		if(on_brkn){
	  			this.rsOK=false;
	  			on_brkn();
	  			var wsowner = this.owner;
	  			setTimeout(function(){wsowner.connect();}, 1000);
	  		}
	  	};
	  	this._ws.onmessage = function(msg){
	  		if(msg.data){
	  			if (this.rsOK){
		          	var data = JSON.parse(msg.data);
		          	on_receive(data);
		        }else if(msg.data == 'connect-ok'){
		            this.rsOK = true;
		        }else{
		        }	
	        }
	    };
  	};
  }
  wsClient.prototype = {
    send: function(data){
    	try{
            if (this._ws){
                this._ws.send(data);
            }
        }catch(e){
            if(console && console.log){
            	console.log(e.error);
            }
        }
    }
  }

     
 /*桌面提醒*/
var notification ;

function RequestPermission(callback) {        
   window.webkitNotifications.requestPermission(callback);     
} 

function artdialog(con, btnname , btnname2, icon,  fun, fun2){
	var button;
	if(btnname2 === ''){
	 button = [{
		 name: btnname,
		focus: true,
	 callback: fun }];
	}else{
	  button = [{
		 name: btnname,
		focus: true,
	  callback: fun },
		{
		 name: btnname2,
	     callback: fun2
		}];
	}
	var dialog = art.dialog({
		title: lw_lang.ID_NOTI_TITLE,
		content: con, 
		id: 'Notification_dialog',
		width: 400,
	   height: 100,
		 lock: true,
		 icon: icon,
	   button: button
	});
}

var Notification_time = 0;
function showNotification(icon, Title , content) {
  if(window_focus == true) return false;
  if(!Title || !content) return false;
  if (!!window.webkitNotifications) {
      if (window.webkitNotifications.checkPermission() == 1 ) {
		if(Notification_time == 0){
			var con = '<div style="line-height:25px;"><span style="color:#0078B6; font-size:15px;">'+ lw_lang.ID_NOTI_QUS+'</span><br/>'
					 + '<span style="color:#666; font-size:14px;">'+ lw_lang.ID_NOTI_TIP +'<br/></span></div>';
			artdialog(con, lw_lang.ID_NOTI_BTN1, lw_lang.ID_NOTI_BTN2, 'question', function(){
				   window.webkitNotifications.requestPermission();
				   $.dialog({ id: "Notification_dialog" }).close();
				}, function(){
				   $.dialog({ id: "Notification_dialog" }).close();
				})
			Notification_time++;
		}		
    } else if(window.webkitNotifications.checkPermission() == 2){
		if(Notification_time == 0){
			var con = '<div style="line-height:25px;"><span style="color:#0078B6; font-size:15px;">'+ lw_lang.ID_NOTI_QUS+'</span><br/>'	
					 + '1、'+ lw_lang.ID_NOTI_ICON +' <img src="/images/notifications.png"/><br/>'
					 + '2、' + lw_lang.ID_NOTI_SELECT + '</span></div>';				 	
			 artdialog(con, lw_lang.ID_NOTI_BTN3,'', 'warning', function(){
					$.dialog({ id: "Notification_dialog" }).close();
				});
			 Notification_time++;
		}	
	} else {
          window.webkitNotifications.requestPermission()
	        if( '' === content ){
			 return false;			
		  }else{	
			  if(notification) {
			  }else{
				  notification =window.webkitNotifications.createNotification(icon, Title, content);	
				  notification.show();	   
			  }		   
			   notification.onclose = function() {			
				   notification = null; 
			   };
			   notification.onclick = function(event) { 
				   window.focus();
				   notification.cancel();
				   notification = null;
			   };		   
		 }
	   
	}
  }       
}
