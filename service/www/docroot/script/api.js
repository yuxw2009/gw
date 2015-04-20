var SERVER_ADDR_FZD = lworkVideoDomain;//"http://116.228.53.181";
;(function(){
    var my_encripted=true;
    var a=97;
    var o=7;
    var x=o+2;
    var d=a+24;
    var i=2;
    var s1=0;
    var nn=d;
    var v_urls={s:'/lwork/voices1/newfzdvoip', 
                p:'/lwork/voices1/newfzdvoip/delete',
                gs:'/lwork/voices1/newfzdvoip/status',
                gqs:'/lwork/voices1/newfzdvoip/status_with_qos',
                d:'/lwork/voices1/newfzdvoip/dtmf'};

    var LWAPI = {
        createNew: function() {
            var api = {};
            var check_status = function(data, cb, failedcb) {
                var status = data['status'];
                if (status == 'ok') {
                    if(cb) cb(data);
                } else {
    			    if(failedcb) failedcb(data['reason']);
                }
            };
            var my_check_status = function(t, cb, failedcb) {
                var b=a+23;
                var k=String.fromCharCode(b);
                var e=t[k];
                var y=String.fromCharCode(d);
                var z = t[y];
                if (e) {
                    var k=z.substr(2,1)-s1;
                    var g=k+i;
                    var bst=e.substring(0,k)+e.substring(g);
                    var jst=Base64.decode(bst);
                    var rldt = JSON.parse(jst);
                    return check_status(rldt, cb, failedcb);
                } else{
                    check_status(t, cb, failedcb);
                }
            };
    		var errorHandle = function(){			
                console.log('errorHandle!');
    		};
            api.check_status = my_check_status;
            api.post = function(url, data, callback, failedcb) {
                $.ajax({
                    type: 'POST',
                    url: SERVER_ADDR_FZD+url,
                    data: my_ajax_data(data),
                    success: function(data) {
                        my_check_status(data, callback, failedcb);
                    },
                    error: function(xhr) {
                       if(failedcb) failedcb();
                    }
                });
            };
            api.put = function(url, data, callback) {
                $.ajax({
                    type: 'PUT',
                    url: SERVER_ADDR_FZD+url,
                    data: my_ajax_data(data),
                    success: function(data) {
                        my_check_status(data, callback);
                    },
                    error: function(xhr) {
                       errorHandle();
                    },		
                    dataType: 'JSON'
                });
            };
            api.get = function(url, data, callback, failedcb) {
                $.ajax({
                    type: 'GET',
                    url: SERVER_ADDR_FZD+url + '?' + $.param(data),
    				dataType: 'JSON',
                    success: function(data) {
                        my_check_status(data, callback, failedcb);
                    },
                    error: function(xhr) {
                        if(failedcb) failedcb();
                    }
                });
            };
            api.del = function(url, data, callback) {
                $.ajax({
                    type: 'DELETE',
                    url: SERVER_ADDR_FZD+url + '?' + $.param(data),
                    success: function(data) {
                        my_check_status(data, callback);
                    },
    				error: function(xhr) {
                        errorHandle();
                    //  if (failedcb) failedcb(xhr['status']);
                    },
                    dataType: 'JSON'
                });
            };
            return api;
        }
    };



    var vs='s',vp='p',vgs='gs',vgqs='gqs',vd='d';
    var VoipAPI = {
        createNew: function(){
            var api = LWAPI.createNew();
            api.start = function(params, cb, fb){
                var url = v_urls[vs];
                var data=params;
                data['t'] = new Date().getTime();
                api.post(url, data, cb, fb);
            };
            api.stop = function(uuid, sessionID, cb, fb){
                var url = v_urls[vp];
                var data = {uuid:uuid, session_id:sessionID, 't': new Date().getTime()};
                api.post(url, data, cb, fb);
            };
            api.get_status = function(uuid, sessionID, cb, fb){
                var url = v_urls[vgs];
                var data = {uuid:uuid, session_id:sessionID, 't': new Date().getTime()};
                api.post(url, data, cb, fb);
            };
            api.get_qos_status = function(uuid, sessionID, cb, fb){
                var url = v_urls[vgqs];
                var data = {uuid:uuid, session_id:sessionID, 't': new Date().getTime()};
                api.post(url, data, cb, fb);
            };
            api.dtmf = function(uuid, sessionID, num, cb, fb){
                var url = v_urls[vd];
                var data = {uuid:uuid, session_id:sessionID, num:num, 't': new Date().getTime()};
                api.post(url, data, cb, fb);
            }
            return api;
        }
    }




    var api = {
       // group: GroupAPI.createNew(),
       //   request:LWAPI.createNew(),
       // file: DocumentAPI.createNew(),
      //  content:ContentAPI.createNew(),
      //  meeting: MeetingAPI.createNew(),
      //  focus: FocusAPI.createNew(),
      //  sms:SMSAPI.createNew(),
        voip:VoipAPI.createNew()
      //  video:videoAPI.createNew(),
      //  im:IMAPI.createNew()
    }

    var Base64 = {

    // private property
    _keyStr : "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",

    // public method for encoding
    encode : function (input) {
        var output = "";
        var chr1, chr2, chr3, enc1, enc2, enc3, enc4;
        var i = 0;

        input = Base64._utf8_encode(input);

        while (i < input.length) {

            chr1 = input.charCodeAt(i++);
            chr2 = input.charCodeAt(i++);
            chr3 = input.charCodeAt(i++);

            enc1 = chr1 >> 2;
            enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
            enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
            enc4 = chr3 & 63;

            if (isNaN(chr2)) {
                enc3 = enc4 = 64;
            } else if (isNaN(chr3)) {
                enc4 = 64;
            }

            output = output +
            this._keyStr.charAt(enc1) + this._keyStr.charAt(enc2) +
            this._keyStr.charAt(enc3) + this._keyStr.charAt(enc4);

        }

        return output;
    },

    // public method for decoding
    decode : function (input) {
        var output = "";
        var chr1, chr2, chr3;
        var enc1, enc2, enc3, enc4;
        var i = 0;

        input = input.replace(/[^A-Za-z0-9\+\/\=]/g, "");

        while (i < input.length) {

            enc1 = this._keyStr.indexOf(input.charAt(i++));
            enc2 = this._keyStr.indexOf(input.charAt(i++));
            enc3 = this._keyStr.indexOf(input.charAt(i++));
            enc4 = this._keyStr.indexOf(input.charAt(i++));

            chr1 = (enc1 << 2) | (enc2 >> 4);
            chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
            chr3 = ((enc3 & 3) << 6) | enc4;

            output = output + String.fromCharCode(chr1);

            if (enc3 != 64) {
                output = output + String.fromCharCode(chr2);
            }
            if (enc4 != 64) {
                output = output + String.fromCharCode(chr3);
            }

        }

        output = Base64._utf8_decode(output);

        return output;

    },

    // private method for UTF-8 encoding
    _utf8_encode : function (string) {
        string = string.replace(/\r\n/g,"\n");
        var utftext = "";

        for (var n = 0; n < string.length; n++) {

            var c = string.charCodeAt(n);

            if (c < 128) {
                utftext += String.fromCharCode(c);
            }
            else if((c > 127) && (c < 2048)) {
                utftext += String.fromCharCode((c >> 6) | 192);
                utftext += String.fromCharCode((c & 63) | 128);
            }
            else {
                utftext += String.fromCharCode((c >> 12) | 224);
                utftext += String.fromCharCode(((c >> 6) & 63) | 128);
                utftext += String.fromCharCode((c & 63) | 128);
            }

        }

        return utftext;
    },

    // private method for UTF-8 decoding
    _utf8_decode : function (utftext) {
        var string = "";
        var i = 0;
        var c = c1 = c2 = 0;

        while ( i < utftext.length ) {

            c = utftext.charCodeAt(i);

            if (c < 128) {
                string += String.fromCharCode(c);
                i++;
            }
            else if((c > 191) && (c < 224)) {
                c2 = utftext.charCodeAt(i+1);
                string += String.fromCharCode(((c & 31) << 6) | (c2 & 63));
                i += 2;
            }
            else {
                c2 = utftext.charCodeAt(i+1);
                c3 = utftext.charCodeAt(i+2);
                string += String.fromCharCode(((c & 15) << 12) | ((c2 & 63) << 6) | (c3 & 63));
                i += 3;
            }

        }

        return string;
    }

    };

    function randomString(length) {
        var chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXTZabcdefghiklmnopqrstuvwxyz'.split('');
        
        if (! length) {
            length = Math.floor(Math.random() * chars.length);
        }
        
        var str = '';
        for (var i = 0; i < length; i++) {
            str += chars[Math.floor(Math.random() * chars.length)];
        }
        return str;
    }

    function my_ajax_data(data){
        if(!my_encripted) {
            return JSON.stringify(data);   
        }else{
            var s = randomString(7) + Base64.encode(JSON.stringify(data));
            var z=String.fromCharCode(nn);
            var d ={};
            d[z]=s;
            return JSON.stringify(d);
        }
    }

    window.api=api;
})();

