#把aps_development.cer文件生成.pem文件
openssl x509 -in aps_development.cer -inform DER -out PushChatCert.pem -outform PEM

#把.p12文件生成为.pem文件
openssl pkcs12 -nocerts -out PushChatKey.pem -in Development证书.p12

Enter Import Password:原先的证书密码："livecom2015
MAC verified OK
Enter PEM pass phrase:现在的密码："livecom2015
Verifying - Enter PEM pass phrase: livecom2015

#把PushChatCert.pem和PushChatKey.pem合并为一个pem文件
cat PushChatCert.pem PushChatKey.pem > ck.pem

#终端测试
openssl s_client -connect gateway.sandbox.push.apple.com:2195 -cert PushChatCert.pem -key PushChatKey.pem
出现" Verify return code: 20  (unable to get local issuer certificate)"

#错误信息：
/*
unable to load client certificate private key file
140735156114256:error:0906D06C:PEM routines:PEM_read_bio:no start line:pem_lib.c:701:Expecting: ANY PRIVATE KEY
livecomdeiMac:远程推送 livecom$ openssl s_client -connect gateway.sandbox.push.apple.com:2195 -cert PushChatCert.pem -key PushChatKey.pem
Enter pass phrase for PushChatKey.pem:
CONNECTED(00000003)
depth=1 C = US, O = "Entrust, Inc.", OU = www.entrust.net/rpa is incorporated by reference, OU = "(c) 2009 Entrust, Inc.", CN = Entrust Certification Authority - L1C
verify error:num=20:unable to get local issuer certificate
---
Certificate chain
0 s:/C=US/ST=California/L=Cupertino/O=Apple Inc./CN=gateway.sandbox.push.apple.com
i:/C=US/O=Entrust, Inc./OU=www.entrust.net/rpa is incorporated by reference/OU=(c) 2009 Entrust, Inc./CN=Entrust Certification Authority - L1C
1 s:/C=US/O=Entrust, Inc./OU=www.entrust.net/rpa is incorporated by reference/OU=(c) 2009 Entrust, Inc./CN=Entrust Certification Authority - L1C
i:/O=Entrust.net/OU=www.entrust.net/CPS_2048 incorp. by ref. (limits liab.)/OU=(c) 1999 Entrust.net Limited/CN=Entrust.net Certification Authority (2048)
---
Server certificate
-----BEGIN CERTIFICATE-----
MIIFMzCCBBugAwIBAgIETCMmsDANBgkqhkiG9w0BAQUFADCBsTELMAkGA1UEBhMC
VVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4xOTA3BgNVBAsTMHd3dy5lbnRydXN0
Lm5ldC9ycGEgaXMgaW5jb3Jwb3JhdGVkIGJ5IHJlZmVyZW5jZTEfMB0GA1UECxMW
KGMpIDIwMDkgRW50cnVzdCwgSW5jLjEuMCwGA1UEAxMlRW50cnVzdCBDZXJ0aWZp
Y2F0aW9uIEF1dGhvcml0eSAtIEwxQzAeFw0xNDA1MjMxNzQyNDJaFw0xNjA1MjQw
NzA1MTNaMHQxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpDYWxpZm9ybmlhMRIwEAYD
VQQHEwlDdXBlcnRpbm8xEzARBgNVBAoTCkFwcGxlIEluYy4xJzAlBgNVBAMTHmdh
dGV3YXkuc2FuZGJveC5wdXNoLmFwcGxlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQAD
ggEPADCCAQoCggEBAOQpUlXpU3+LJ2XR01QdVooN7S9OFOINp3/tomPaenQAwFGo
qIakKFcN7AotWLFXFcR0QXKJkn4PL/zPKDBucyRFkc79S5+ZraGRISWfi7G8XeaG
G3GzgeVQ977Qrn0IdCswnbwLsJoErnmq4AveQajUbYueR9SxhkWBwMimSxXzXoOS
XUOPzRvzObCxVZrvBBDSRJCeNVnVxtCmb17DM3+z5GZatBwWnvw0jgvSQsgof+uC
idXgqcN4msv3tVH54ipmuD9kbbwvtnDCHBZRXMMmhUfFXZRuE8GBEbPfVkqB16ad
JV4TVrVxwFENwdnsX9CXavHCgFJhtHRWKOoCH48CAwEAAaOCAY0wggGJMAsGA1Ud
DwQEAwIFoDAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwMwYDVR0fBCww
KjAooCagJIYiaHR0cDovL2NybC5lbnRydXN0Lm5ldC9sZXZlbDFjLmNybDBkBggr
BgEFBQcBAQRYMFYwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLmVudHJ1c3QubmV0
MC8GCCsGAQUFBzAChiNodHRwOi8vYWlhLmVudHJ1c3QubmV0LzIwNDgtbDFjLmNl
cjBKBgNVHSAEQzBBMDUGCSqGSIb2fQdLAjAoMCYGCCsGAQUFBwIBFhpodHRwOi8v
d3d3LmVudHJ1c3QubmV0L3JwYTAIBgZngQwBAgIwKQYDVR0RBCIwIIIeZ2F0ZXdh
eS5zYW5kYm94LnB1c2guYXBwbGUuY29tMB8GA1UdIwQYMBaAFB7xq4kG+EkPATN3
7hR67hl8kyhNMB0GA1UdDgQWBBSSGfpGPmr9+FPcqRiStH0iKRBL7DAJBgNVHRME
AjAAMA0GCSqGSIb3DQEBBQUAA4IBAQAkj6+okMFVl7NHqQoii4e4iPDFiia+LmHX
BCc+2UEOOjilYWYoZ61oeqRXQ2b4Um3dT/LPmzMkKmgEt9epKNBLA6lSkL+IzEnF
wLQCHkL3BgvV20n5D8syzREV+8RKmSqiYmrF8dFq8cDcstu2joEKd173EfrymWW1
fMeaYTbjrn+vNkgM94+M4c/JnIDOhiPPbeAx9TESQZH+/6S98hrbuPIIlmaOJsOT
GMOUWeOTHXTCfGb1EM4SPVcyCW28TlWUBl8miqnsEO8g95jZZ25wFANlVxhfxBnP
fwUYU5NTM3h0xi3rIlXwAKD6zLKipcQ/YXRx7oMYnAm53tfU2MxV
-----END CERTIFICATE-----
subject=/C=US/ST=California/L=Cupertino/O=Apple Inc./CN=gateway.sandbox.push.apple.com
issuer=/C=US/O=Entrust, Inc./OU=www.entrust.net/rpa is incorporated by reference/OU=(c) 2009 Entrust, Inc./CN=Entrust Certification Authority - L1C
---
Acceptable client certificate CA names
/C=US/O=Apple Inc./OU=Apple Certification Authority/CN=Apple Root CA
/C=US/O=Apple Inc./OU=Apple Worldwide Developer Relations/CN=Apple Worldwide Developer Relations Certification Authority
/C=US/O=Apple Inc./OU=Apple Certification Authority/CN=Apple Application Integration Certification Authority
Client Certificate Types: RSA sign, DSA sign, ECDSA sign
Requested Signature Algorithms: RSA+SHA512:DSA+SHA512:ECDSA+SHA512:0xEF+0xEF:RSA+SHA384:DSA+SHA384:ECDSA+SHA384:RSA+SHA256:DSA+SHA256:ECDSA+SHA256:0xEE+0xEE:0xED+0xED:RSA+SHA224:DSA+SHA224:ECDSA+SHA224:RSA+SHA1:DSA+SHA1:ECDSA+SHA1
Shared Requested Signature Algorithms: RSA+SHA512:DSA+SHA512:ECDSA+SHA512:RSA+SHA384:DSA+SHA384:ECDSA+SHA384:RSA+SHA256:DSA+SHA256:ECDSA+SHA256:RSA+SHA224:DSA+SHA224:ECDSA+SHA224:RSA+SHA1:DSA+SHA1:ECDSA+SHA1
Peer signing digest: SHA512
Server Temp Key: ECDH, P-256, 256 bits
---
SSL handshake has read 5139 bytes and written 2168 bytes
---
New, TLSv1/SSLv3, Cipher is ECDHE-RSA-AES256-GCM-SHA384
Server public key is 2048 bit
Secure Renegotiation IS supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
SSL-Session:
Protocol  : TLSv1.2
Cipher    : ECDHE-RSA-AES256-GCM-SHA384
Session-ID: E791FBE61DBC1A4207201FB1E9F3767D3E2D048A54FF743E2D748BD29B16276E
Session-ID-ctx:
Master-Key: AF44E5F31C2DA70CF233FBA1EFD0154446FA14C3714F33BA7DB7FBFB0D7AD6A7D6F2DA5FD8770651555293A3D0C56479
Key-Arg   : None
PSK identity: None
PSK identity hint: None
SRP username: None
TLS session ticket lifetime hint: 14400 (seconds)
TLS session ticket:
0000 - 97 fc ee 9b 53 23 81 6c-98 f8 eb c7 64 63 af dc   ....S#.l....dc..
0010 - ac b6 45 1a 91 69 93 de-ac c7 cc 58 49 e9 e3 1c   ..E..i.....XI...
0020 - 03 c2 74 4a f6 d3 59 76-a4 35 5d 9b 70 27 5f a2   ..tJ..Yv.5].p'_.
0030 - 27 b3 54 d7 7c be 49 24-9a 95 68 94 15 79 30 70   '.T.|.I$..h..y0p
0040 - 42 98 4c 9b 54 60 f2 ba-aa 6f 1f 6e ec 7c 12 41   B.L.T`...o.n.|.A
0050 - 07 4e f1 48 c7 d4 bd 7e-8c 59 22 d0 a8 f2 91 55   .N.H...~.Y"....U
0060 - 9e 5e 18 f4 dc 73 cf d5-18 11 ec 05 77 e7 17 c9   .^...s......w...
0070 - 84 6b 37 43 80 a5 45 6e-34 de f4 a9 12 e1 13 e2   .k7C..En4.......
0080 - ab b4 ae 7b 00 12 00 24-03 ba 87 9c 23 95 2c 85   ...{...$....#.,.
    0090 - d6 13 bd 5a de 38 82 dc-be 97 71 78 08 28 15 dd   ...Z.8....qx.(..
                                                                           00a0 - 26 a3 78 e2 9a 73 11 31-e8 01 9a 57 f4 a2 a8 d7   &.x..s.1...W....
                                                                           00b0 - d8 a3 b8 78 df a2 a4 b7-03 a9 01 13 43 89 a1 89   ...x........C...
                                                                           00c0 - b9 59 d0 a6 79 91 c5 fb-0e 42 21 ae 85 6d 1a b2   .Y..y....B!..m..
                                                                           00d0 - 36 79 24 d1 9c 6f e1 bb-24 85 e5 94 95 65 c5 0b   6y$..o..$....e..
                                                                           00e0 - f4 21 05 aa e3 eb fb a3-f2 40 e5 cb 59 18 e4 9e   .!.......@..Y...
                                                                           00f0 - 25 5b 31 81 4b 63 50 9f-06 32 fa 14 29 9e 2a 90   %[1.KcP..2..).*.
                                                                                                                                      0100 - fe d3 60 63 87 85 76 8e-16 21 fd 33 bf be f6 b2   ..`c..v..!.3....
                                                                                                                                      0110 - a0 07 f0 b0 d7 ab 03 78-1e cf 90 5d d6 c6 f4 fb   .......x...]....
                                                                           0120 - 0e 81 db d9 bd c5 dc ea-7c eb d7 94 f6 03 d7 bb   ........|.......
                                                                           0130 - a8 d3 57 f1 78 52 fd 3f-eb d3 be aa de ed 8f 39   ..W.xR.?.......9
                                                                           0140 - 23 22 59 6e c9 df 26 11-21 69 10 59 5e 53 14 66   #"Yn..&.!i.Y^S.f
                                                                           0150 - 14 85 45 6c 36 16 a0 b3-d6 a0 9b 08 ae 85 a7 a2   ..El6...........
                                                                           0160 - d2 94 0b f5 35 24 39 0f-52 f6 36 42 01 a2 34 57   ....5$9.R.6B..4W
                                                                           0170 - 96 70 6c b7 03 c0 1b 5f-b9 05 cd 48 61 e2 ba 2e   .pl...._...Ha...
                                                                           0180 - 95 7f 78 b3 3c 6b 55 f2-f7 db b4 03 b3 85 c1 17   ..x.<kU.........
                                                                           0190 - 56 3c 20 d0 7d 27 60 28-fc fe 1a 9a 0a 15 71 71   V< .}'`(......qq
                                                                           01a0 - 3d 50 cb b5 17 86 aa 9d-48 20 ef 73 51 2e 24 a7   =P......H .sQ.$.
                                                                           01b0 - 09 26 e0 7d 8e 4a 86 0b-dc 2a e5 6f cc 4e 82 cd   .&.}.J...*.o.N..
                                                                           01c0 - 5a 05 7a 9b f1 52 26 b9-4c 77 ae 83 77 e1 11 d7   Z.z..R&.Lw..w...
                                                                           01d0 - 30 49 c4 24 71 f4 a6 5d-99 de ee d1 15 b3 ec 28   0I.$q..].......(
                                                                                                                                                    01e0 - f8 05 b0 0a 1b 74 7d c6-4d 65 c5 79 ee b4 04 96   .....t}.Me.y....
                                                                                                                                                    01f0 - 5b fe cf 40 1c 76 b9 57-44 d2 a2 0f 7d 5c 2f 06   [..@.v.WD...}\/.
                                                                                                                                                                                                              0200 - 77 c5 57 b1 d9 fe d9 6a-13 36 6d 6b a5 13 2f 7f   w.W....j.6mk../.
                                                                                                                                                                                                              0210 - d5 80 6e 1c 17 17 dd ac-55 b8 8b 22 df b5 b8 12   ..n.....U.."....
                                                                                                                                                                                                              0220 - b4 6e db 18 5c 87 28 ab-e9 e0 93 cb ca 55 87 de   .n..\.(......U..
                                                                                                                                                                                                                                                                              0230 - 1a d7 8f 37 4a ec a3 ea-64 1d 13 e6 16 4e fd 3a   ...7J...d....N.:
                                                                                                                                                                                                                                                                              0240 - cf d5 60 08 bc 77 64 2b-d1 ce 1e 57 6e 69 b7 7b   ..`..wd+...Wni.{
                                                                                                                                                                                                                                                                                  0250 - e9 20 16 97 66 43 37 8c-fc 42 06 ec ff 4f 6a c6   . ..fC7..B...Oj.
                                                                                                                                                                                                                                                                                  0260 - 4f aa e1 df c4 00 f9 29-1c 5f 23 2f 7e 55 9f 80   O......)._#/~U..
                                                                                                                                                                                                                                                                                  0270 - 43 42 b1 8b c4 fb 06 f5-18 15 d7 16 5a 71 cb 9e   CB..........Zq..
                                                                                                                                                                                                                                                                                  0280 - f8 11 6d 4f 8e 3f ac 6c-76 67 73 6f 36 df ad b5   ..mO.?.lvgso6...
                                                                                                                                                                                                                                                                                  0290 - f1 07 08 8a 2a cd 45 1a-a6 75 89 6a b9 28 e2 3d   ....*.E..u.j.(.=
                                                                                                                                                                                                                                                                                                                                                         02a0 - 58 82 7e 2b 9f 29 4b b5-60 51 d7 34 21 c9 63 e0   X.~+.)K.`Q.4!.c.
                                                                                                                                                                                                                                                                                  02b0 - cb 14 76 98 cc 7c e6 d9-13 0c 45 99 26 b3 b0 c3   ..v..|....E.&...
                                                                                                                                                                                                                                                                                  02c0 - d7 99 30 84 b3 f8 a6 14-ad 0a 11 ff 81 77 a7 07   ..0..........w..
                                                                                                                                                                                                                                                                                  02d0 - 3f db 72 7c 6e 4c 85 02-0f 0f 01 3d 7a ba c9 dd   ?.r|nL.....=z...
                                                                                                                                                                                                                                                                                  02e0 - ef ce ef 05 3a a9 be 74-ea 15 9b e3 c4 90 6d 4b   ....:..t......mK
                                                                                                                                                                                                                                                                                  02f0 - c5 1b ff 8e 8d 06 ed 0b-43 41 61 33 1a 47 9e 45   ........CAa3.G.E
                                                                                                                                                                                                                                                                                  0300 - 8a 1e 01 ae b9 64 6c 3c-ca 92 84 dc 27 3b 11 88   .....dl<....';..
                                                                                                                                                                                                                                                                                  0310 - a5 7d 0b 6f ca 44 f7 20-b8 bb 2b a4 9b c0 c7 50   .}.o.D. ..+....P
                                                                                                                                                                                                                                                                              0320 - 15 26 68 72 13 09 57 75-d8 70 85 e0 5e 98 59 dd   .&hr..Wu.p..^.Y.
                                                                                                                                                                                                                                                                              0330 - 26 1d 3f cb 4b 17 f0 0f-c0 ce 0b 17 0e e8 0d 69   &.?.K..........i
                                                                                                                                                                                                                                                                              0340 - f5 fc 89 ef 40 7c 82 24-b6 34 e2 b5 f1 0b 33 d7   ....@|.$.4....3.
                                                                                                                                                                                                                                                                              0350 - ea 16 4a de 18 10 da 5b-35 09 9f 06 35 86 ef f4   ..J....[5...5...
                                                                                                                                                                                                                                                                                                                                               0360 - 4b 35 52 65 bf 84 6b f2-53 e6 c9 ee 86 29 dc ad   K5Re..k.S....)..
                                                                                                                                                                                                                                                                                                                                               0370 - 2d 1b b4 27 05 d1 25 0f-9f 54 ec 21 02 61 3d 35   -..'..%..T.!.a=5
                                                                                                                                                                                                                                                                                                                                               0380 - f4 20 e7 22 7c be b4 31-a1 9f af a0 39 4c b2 be   . ."|..1....9L..
                                                                                                                                                                                                                                                                                                                                               0390 - cb 95 13 fe aa 11 bd 1a-db 1f 06 ad 5a c1 a7 db   ............Z...
                                                                                                                                                                                                                                                                                                                                               03a0 - 1e 14 e9 c5 1e 0d 37 29-18 8b 2f f1 c1 c9 b1 b6   ......7)../.....
                                                                                                                                                                                                                                                                                                                                               03b0 - 3c de 2a 98 b3 d5 43 dd-94 2f 90 a7 8a 36 74 4d   <.*...C../...6tM
                                                                                                                                                                                                                                                                                                                                               03c0 - 52 c4 fb 58 db d5 b5 b6-c7 b2 d1 a1 5e 3e c3 72   R..X........^>.r
                                                                                                                                                                                                                                                                                                                                               03d0 - 1e 12 67 cc 30 4d 10 55-db 1a ac 89 02 f2 be 89   ..g.0M.U........
                                                                                                                                                                                                                                                                                                                                               03e0 - 83 af 47 70 85 e5 84 ea-1f bb 7d 06 ca a7 43 95   ..Gp......}...C.
                                                                                                                                                                                                                                                                                                                                               03f0 - 74 ad d2 91 e8 54 f2 3c-6d ae bb bc e5 84 2a 03   t....T.<m.....*.
                                                                                                                                                                                                                                                                                                                                               0400 - 61 46 bc e1 8f 9c 00 1b-e0 14 80 f0 11 6e 04 71   aF...........n.q
                                                                                                                                                                                                                                                                                                                                               0410 - 07 5e af 45 2d 70 fe 02-b0 79 fd 80 af 5a 71 c4   .^.E-p...y...Zq.
                                                                                                                                                                                                                                                                                                                                               0420 - 93 c8 49 6e d4 a7 11 3d-48 d8 97 94 32 a0 26 90   ..In...=H...2.&.
                                                                                                                                                                                                                                                                                                                                               0430 - bb 23 12 3f fb 6c b8 cf-8d b9 cf ae a3 ee e5 76   .#.?.l.........v
                                                                                                                                                                                                                                                                                                                                               0440 - 59 3b 3b 99 11 de c3 08-91 d4 87 d6 f7 82 96 c9   Y;;.............
                                                                                                                                                                                                                                                                                                                                               0450 - e7 6a d6 ed 10 9a 48 8e-ec 3d 66 2d a8 9d 0d 76   .j....H..=f-...v
                                                                                                                                                                                                                                                                                                                                               0460 - d0 15 f2 b0 e9 bb 80 71-46 da 3e 4b ba 69 88 25   .......qF.>K.i.%
                                                                                                                                                                                                                                                                                                                                               0470 - 63 3a 11 72 39 92 7a 73-58 87 c9 26 69 f7 6a 14   c:.r9.zsX..&i.j.
                                                                                                                                                                                                                                                                                                                                               0480 - d8 59 7e 3d 73 bf 5a c7-56 78 c5 26 e2 e3 4b 50   .Y~=s.Z.Vx.&..KP
                                                                                                                                                                                                                                                                                                                                               0490 - 3d e0 bf e7 b8 f6 25 da-32 35 ab c4 a8 f6 fe 42   =.....%.25.....B
                                                                                                                                                                                                                                                                                                                                               04a0 - 51 06 74 2e 68 43 8c 62-d5 ae c6 1f 04 4c 1d ec   Q.t.hC.b.....L..
                                                                                                                                                                                                                                                                                                                                               04b0 - df 83 9a 09 91 b6 bb 86-07 03 35 fb 38 32 d3 0b   ..........5.82..
                                                                                                                                                                                                                                                                                                                                               04c0 - 0d 59 4b 54 a6 50 62 33-80 97 85 34 9b 16 cd 9a   .YKT.Pb3...4....
                                                                                                                                                                                                                                                                                                                                               04d0 - ec be 5f 47 96 f3 d5 a5-eb e1 83 3b de 2b f7 58   .._G.......;.+.X
                                                                                                                                                                                                                                                                                                                                               04e0 - 16 38 0b 9b e2 a2 76 aa-8b 4d e6 94 54 6a a5 c2   .8....v..M..Tj..
                                                                                                                                                                                                                                                                                                                                               04f0 - d6 c2 af 85 ca 7a 5e f0-91 f0 a5 2f c1 06 5a ba   .....z^..../..Z.
                                                                                                                                                                                                                                                                                                                                               0500 - af a3 07 dc 70 3f 12 45-59 dd ef 6c e9 c5 1b 7f   ....p?.EY..l....
                                                                                                                                                                                                                                                                                                                                               0510 - 6b 82 68 a2 4c c2 a9 58-1e d0 41 eb fe b2 7f b7   k.h.L..X..A.....
                                                                                                                                                                                                                                                                                                                                               0520 - 52 a5 5b 96 3e 08 2e 22-d0 a6 31 e6 d3 57 74 26   R.[.>.."..1..Wt&
                                                                                                                                                                                                                                                                                                                                                                                                           0530 - 6c d9 40 8a b0 f1 ca 08-8f dc da 7d 0c ae 6d 0d   l.@........}..m.
                                                                                                                                                                                                                                                                                                                                                                                                           0540 - a3 4d 3c 49 ed 12 c2 87-df 9d 58 47 dd d8 75 f3   .M<I......XG..u.
                                                                                                                                                                                                                                                                                                                                                                                                           0550 - 27 24 3b 5c d7 12 ca e7-d2 e2 e3 28 25 f6 59 57   '$;\.......(%.YW
                                                                                                                                                                                                                                                                                                                                                                                                           0560 - 82 d0 6a 2a 55 a3 85 3a-1a a6 ef 5d 2e f9 a4 63   ..j*U..:...]...c
                                                                                                                                                                                                                                                                                                                                               0570 - 9a a4 eb b7 9e c4 ee 98-46 8f fe cc e7 b0 68 21   ........F.....h!
                                                                                                                                                                                                                                                                                                                                               0580 - 91 a0 31 97 8f 4e e1 3f-ad 22 9c 5c 19 3e 67 d7   ..1..N.?.".\.>g.
                                                                                                                                                                                                                                                                                                                                               0590 - 34 d7 b9 46 90 52 73 d5-f3 49 37 20 7b b2 c5 3d   4..F.Rs..I7 {..=
                                                                                                                                                                                                                                                                                                                                                   05a0 - a9 64 15 5c d3 3f 2e 03-fa 25 f8 66 0c b8 7a ab   .d.\.?...%.f..z.
                                                                                                                                                                                                                                                                                                                                                   05b0 - fb bb bb f1 79 d0 f0 52-7b 5d 9d df 90 d2 d2 a5   ....y..R{]......
                                                                                                                                                                                                                                                                                                                                                       05c0 - e2 46 1c 55 70 cf 71 0f-b5 67 d6 60 f2 5b 2f 28   .F.Up.q..g.`.[/(
                                                                                                                                                                                                                                                                                                                                                                                                                                05d0 - 79 f9 c7 1c da 54 19 b7-cb 68 af a5 10 8d 41 3b   y....T...h....A;
                                                                                                                                                                                                                                                                                                                                                                                                                                05e0 - 15 34 58 4b 23 12 54 5e-4a e3 e2 ba 79 3f cf a5   .4XK#.T^J...y?..
                                                                                                                                                                                                                                                                                                                                                                                                                                05f0 - d7 f9 0e 8a 38 7e 33 50-b1 56 b8 ea 27 41 f1 20   ....8~3P.V..'A. 
                                                                                                                                                                                                                                                                                                                                                                                                                                0600 - d3 77 4d e7 70 5a ff f0-17 4a 4c ea df dd 6e d6   .wM.pZ...JL...n.
                                                                                                                                                                                                                                                                                                                                                                                                                                0610 - 0c d9 2a d5 6f c2 f6 83-e2 67 b1 04 df ce 40 a4   ..*.o....g....@.
                                                                                                                                                                                                                                                                                                                                                                                                                                0620 - 84 ed 3c e5 39 af eb eb-79 0c 6c 26 ab 82 23 92   ..<.9...y.l&..#.
                                                                                                                                                                                                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                                                                                                                                                                                                Start Time: 1433726856
                                                                                                                                                                                                                                                                                                                                                                                                                                Timeout   : 300 (sec)
                                                                                                                                                                                                                                                                                                                                                                                                                                Verify return code: 20 (unable to get local issuer certificate)
                                                                                                                                                                                                                                                                                                                                                                                                                                ---
