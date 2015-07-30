<?php
    
    // ??????????deviceToken???????????????
    //$deviceToken = '3408497ce46bd3f65e4b74465929218ba617cf63b838e4029f367cd68c3a9e51';
    $deviceToken="66e0f3aaac56c75a7a1b71b9fbab255e8d05b7b461c6db0abc8b71ebcb839ad2";
    //"53e6572f9ecfbce67712ffb540f9a2a2ca5955712c63b0ceaf8081a183e1c77e";//"24aea5bad9bc6b64f8b6491320feca11502aa5326fe28ca7b9e7a970fa593762";//
    // Put your private key's passphrase here:
    $passphrase = 'livecom2015';
    
    // Put your alert message here:
    $message = '18017813673';
    
    ////////////////////////////////////////////////////////////////////////////////
    
    $ctx = stream_context_create();
    stream_context_set_option($ctx, 'ssl', 'local_cert', 'priv/ck.pem');
    stream_context_set_option($ctx, 'ssl', 'passphrase', $passphrase);
    
    // Open a connection to the APNS server
    //??????????
    //$fp = stream_socket_client(?ssl://gateway.push.apple.com:2195?, $err, $errstr, 60, //STREAM_CLIENT_CONNECT, $ctx);
    //?????????????appstore??????
    $fp = stream_socket_client(
                               'ssl://gateway.sandbox.push.apple.com:2195', $err,
                               $errstr, 60, STREAM_CLIENT_CONNECT|STREAM_CLIENT_PERSISTENT, $ctx);
    
    if (!$fp)
    exit("Failed to connect: $err $errstr" . PHP_EOL);
    
    echo 'Connected to APNS' . PHP_EOL;
    
    // Create the payload body
    $body['aps'] = array(
                         'alert' => $message,
                         'event' => 'login_otherwhere',//'p2p_inform_called',
                         'opdata' => 'test',
                         'content-available' => 1
                     //    'sound' => 'lk_softcall_ringring.mp3'
//                         'badge' => '10'
                         );
    
    // Encode the payload as JSON
    $payload = json_encode($body);
    
    // Build the binary notification
    $msg = chr(0) . pack('n', 32) . pack('H*', $deviceToken) . pack('n', strlen($payload)) . $payload;
    
    // Send it to the server  
    $result = fwrite($fp, $msg, strlen($msg));  
   
    if (!$result)  
    echo 'Message not delivered' . PHP_EOL;  
    else  
    echo 'Message successfully delivered' . PHP_EOL;  
    
    // Close the connection to the server  
    fclose($fp);  
?>