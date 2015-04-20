if (!document.styleSheets['lw_style']) { //先检查要建立的样式表ID是否存在，防止重复添加  
 var ss = document.createStyleSheet();  
 ss.owningElement.id = 'lw_style';  
 ss.cssText = 'width: 325px;height: 205px;padding: 15px;background: url(../images/login_bg.png) no-repeat left top;margin: 0 auto;position: relative;text-align: center;margin-top: -50px;  ';
}  



