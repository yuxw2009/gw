 function loadChat(){
  
 }

loadChat.prototype = {
    setOptions: function(max, color) {
             var num;
         switch(max){
           case 100:
             num = 30;
             break;
           case 250:
             num = 75;
             break;
           case 16:
             num = 5;
             break;  
           case 500:
             num = 100;
             break;                                        
         }
        return  options = {
            series: {
                lines: {
                  show: true,
                  lineWidth: 0,
                  fill: true,
                  fillColor: color
                }
            },
            xaxis: {
                mode: "time",
                tickSize: [2, "second"],
                tickFormatter: function (v, axis) {
                    var date = new Date(v);
                    if (date.getSeconds() % 60 == 0 && date.getMinutes() % 1 == 0) {
                      var hours = date.getHours() < 10 ? "0" + date.getHours() : date.getHours();
                      var minutes = date.getMinutes() < 10 ? "0" + date.getMinutes() : date.getMinutes();
                      return hours + ":" + minutes;
                    } else {
                      return "";
                    }
                },
                axisLabelFontSizePixels: 12,
                axisLabelFontFamily: 'Segoe UI, Helvetica, Droid Sans, Tahoma, Geneva, sans-serif',
                axisLabelPadding: 10
            },
            yaxis: {
                min: 0,
                max: max,       
                tickSize: 5,
                axisLabelFontFamily: 'Segoe UI, Helvetica, Droid Sans, Tahoma, Geneva, sans-serif',
                tickFormatter: function (v, axis) {
                  if (v % num == 0) {                    
                    return v;
                  } else {
                    return "";
                  }
                },
                axisLabelFontSizePixels: 12,
                axisLabelFontFamily: 'Verdana, Arial',
                axisLabelPadding: 6
            },
            grid: {
                  show: true,
                  backgroundColor: '#ffffff',
                  labelMargin: 10,
                  axisMargin: 10,
                  borderWidth: 0.2,
                  borderColor: '#e9e9e9'
             },
            legend: {       
                labelBoxBorderColor: "#fff"
            }
        }
    },
    createChat: function(chartContainer, data, num, color){
      var curObj = this,
      dataset = [{data:data}];
      $.plot($('#' +chartContainer), dataset , curObj.setOptions(num, color));
    },
    updateChat: function(chartContainer, data, num, color){
      var curObj = this;
      dataset = [{data:data}];
      $.plot($('#' +chartContainer), dataset , curObj.setOptions(num, color));
    }
}