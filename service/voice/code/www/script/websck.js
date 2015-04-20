  // web socket js
  var _onlinkok = null;
  var _onlinkbroken = null;
  var VWS = false;
  if (window.WebSocket) VWS = WebSocket;
  if (!VWS && window.MozWebSocket) VWS = MozWebSocket;
    var voip_client = {
        connect: function(cb_ok,cb_brkn){
         this._ws=new VWS(getVoipWebSocketURL());
         this._ws.onopen=this._onopen;
         this._ws.onmessage=this._onmessage;
         this._ws.onclose=this._onclose;
         _onlinkok = cb_ok;
         _onlinkbroken = cb_brkn;
        },
        _onopen: function(){
          voip_client._send('client-connected='+uuid.toString());
          _onlinkok();
        },
        _send: function(message){
          try{
            if (this._ws)
              this._ws.send(message);
          }catch(e){
             console.log(e.error);
          }
        },
        _onmessage: function(m) {
          if(m.data){
          	var msg = JSON.parse(m.data);
          	voip_receive(msg);
          }
		},
        _onclose: function(m) {
          this._ws=null;
          _onlinkbroken();
        },
        chat: function(message) {
       	  var text = JSON.stringify(message);
          voip_client._send(text);
        },
        disconnect: function(){
          voip_client._send('client-disconnected='+uuid.toString());
        }
    };
     
 /*桌面提醒*/
var notification ;
function RequestPermission(callback) {
   window.webkitNotifications.requestPermission(callback);     
} 
function showNotification(Title , content) {

  //通过window.webkitNotifications判断浏览器是否支持notification 
  if (!!window.webkitNotifications) {
    if (window.webkitNotifications.checkPermission() != 0 ) {        
      RequestPermission(function (){ showNotification('', '');});        
    } else {
	      if( '' === content ){
			 return false;			
		 }else{	
			  if(notification) {
				  
			  }else{
				  notification =window.webkitNotifications.createNotification("/images/note.png", Title, content);	
				  notification.show();	   
			   }		   
			   notification.onclose = function() {
				   //关闭通知		
				   notification = null; 
			   };
			  //当点击时调用
			   notification.onclick = function(event) {    
				   //点击跳转页面
				   window.focus();								  
				   //关闭通知
				   notification.cancel();
				   notification = null;
			   };		   
		}
	}
  }       
}
