# -*- coding: utf-8 -*-
import wx
import os
import threading
import time
import urllib2
import wx.grid
import wx.lib.buttons as buttons
import urllib,cStringIO,Image
import CSinterface_v004 as CS
import base64
import re


'''
sizer1最大容器，sizer2设置区，sizer3帐号区，sizer4统计区
sizer2和sizer3被sizer5包含=垂直，sizer5和sizer4被sizer1包含-水平

'''

FROZEN_REASON_ILL_LOAD = u'QQ被非法登录'
FROZEN_REASON_RECYCLE = u'已被冻结'
FROZEN_REASON_MOD_PASS = u'改密立即恢复登录'
FROZEN_REASON_COMPLAIN = u'申诉成功立即恢复登录'
VERIFY_CODE = ''  #保存验证码，传入线程
CLIDATA = ''     #保存clidata 传入线程
LOAD_RESPONSE_DICT= {'uuid':'','balance':'','deadline':'','acc':''}  #保存登录界面登录之后的信息字典，包括uuid,余额，使用期限
TODAY = str(time.localtime()[0])+'-'+str(time.localtime()[1])+'-'+str(time.localtime()[2])
GRIDROWS = 20
QUERY_FAIL_NUM = 0
PAUSE_TIME = 0

def set_balance(bal):
    LOAD_RESPONSE_DICT['balance']=bal
class WorkerThread(threading.Thread):
    def __init__(self,uuid,dict_qno,window,arg=0):
        threading.Thread.__init__(self)
        self.window = window
        self.timeToQuit = threading.Event()
        self.timeToQuit.clear()
        self.uuid = uuid
        self.dict_qno = dict_qno
        self.rows = len(dict_qno)
        self.arg = arg
        #self.trend = u'' #为5173监控价格趋势添加
        #self.setName(name)#设置线程名为name
        #self.link = NAMELINK[SERVERNAME2[name]]
        
    def stop(self):
        self.timeToQuit.set()

    def run(self):
        if self.arg==0:
            self.Query_auto()                 
        elif self.arg==1:
            self.Qyery_manual()
        elif self.arg==2:
            self.getimage2(LOAD_RESPONSE_DICT['uuid'])
        #elif self.arg==3:
            #self.Add_grid(self.rows)
        #elif self.arg==4:
            #self.Delete_grid(self.rows)

    def connect_band(self,account,password):
        cmd_str = "rasdial %s %s %s" % (self.name, self.username, self.password)

    def getimage2(self,uuid):
        response_dict = CS.upload_qno_manual(LOAD_RESPONSE_DICT['uuid'])
        img_temp = response_dict['jpg']
        img = base64.b64decode(img_temp)
        stream = cStringIO.StringIO(img)
        self.img_out = Image.open(stream)
        self.img_out.save('pic/test.jpg')
        img1 = wx.Image('pic/test.jpg', wx.BITMAP_TYPE_ANY)
        wx.CallAfter(self.window.Change_image,img1)
        clidata = response_dict['clidata']
        global CLIDATA
        CLIDATA = clidata

    def update_response(self,i,response):
        global QUERY_FAIL_NUM,PAUSE_TIME,LOAD_RESPONSE_DICT
        if response['status'] == "failed":
            if response["reason"]=="no_money":  # 4-27yj添加，增加no_money的判断
                wx.CallAfter(self.window.ThreadFinished,self)# 4-27yj添加
                LOAD_RESPONSE_DICT['currentstate'] = u'账户余额不足，请充值...'# 4-27yj添加
                wx.CallAfter(self.window.Updatestatic)# 4-27yj添加
                return False
            #break# 4-27yj添加
            if response["reason"]=="network_exception":  # 4-27yj添加，增加network_exception的判断
                wx.CallAfter(self.window.ThreadFinished,self)# 4-27yj添加
                LOAD_RESPONSE_DICT['currentstate'] = u'网络异常，本次查询失败...'# 4-27yj添加
                wx.CallAfter(self.window.Updatestatic)# 4-27yj添加
            QUERY_FAIL_NUM = QUERY_FAIL_NUM +1
            if QUERY_FAIL_NUM == 5:
                LOAD_RESPONSE_DICT['currentstate'] = u'IP被禁止，%d秒后继续查询..'%PAUSE_TIME
                wx.CallAfter(self.window.Updatestatic)
                QUERY_FAIL_NUM = 0
                time.sleep(PAUSE_TIME)
        if response['status'] == "ok":
            QUERY_FAIL_NUM = 0
            LOAD_RESPONSE_DICT['currentstate'] = u'正常查询中...'
            print response
#            LOAD_RESPONSE_DICT['balance'] = response['balance'] #5-1增加，实时增加余额显示
            wx.CallAfter(self.window.Updatestatic)
        #j = j+1
        wx.CallAfter(self.window.Analyse_result,i,response)
        return True

    def Query_auto_bak(self):
        print 'self.dict_qno=%s----%s\n'%(self.dict_qno,self.getName())
        for i in self.dict_qno.keys():
            if self.timeToQuit.isSet():
                wx.CallAfter(self.window.ThreadFinished,self)
                print 'self.timeToQuit.isSet----%s\n'%self.getName()
                break
            elif not self.window.grid.GetCellValue(i,1):
                print 'xuliehao=%d------%s\n'%(i,self.getName())
                response = CS.query_state(self.uuid,self.dict_qno[i])
                if not self.update_response(i,response):
                    break
        wx.CallAfter(self.window.ThreadFinished,self)
            
    def Query_auto(self):
        print 'self.dict_qno=%s----%s\n'%(self.dict_qno,self.getName())
        input=[]
        for i,qno in self.dict_qno.items():
            print "Query_auto_2",i,qno
            if self.timeToQuit.isSet():
                wx.CallAfter(self.window.ThreadFinished,self)
                print 'self.timeToQuit.isSet----%s\n'%self.getName()
                break
            elif not self.window.grid.GetCellValue(i,1):
                print 'xuliehao=%d------%s\n'%(i,self.getName()),2, input
                input.append((i,qno))
                if len(input)>=2:
                    [(i1,qno1),(i2,qno2)]=input
                    (response1,response2) = CS.query_state_2(self.uuid,(qno1,qno2))
                    self.update_response(i1,response1)
                    self.update_response(i2,response2)
                    print '***************************',input
                    del input[:]
        for i,qno in input:
            response = CS.query_state(self.uuid,qno)
            self.update_response(i,response)
        wx.CallAfter(self.window.ThreadFinished,self)          


    def Qyery_manual(self):
        global QUERY_FAIL_NUM,PAUSE_TIME,LOAD_RESPONSE_DICT
        for i in range(self.rows+1):
            if not self.window.grid.GetCellValue(i,1):
                break
        #vercode = wx.CallAfter(self.window.Get_verifycode)
        clidata = CLIDATA
        vercode = VERIFY_CODE
        response = CS.query_state_manual(self.uuid,self.dict_qno[i],vercode,clidata)
        '''
        if response['status'] == "failed":
            QUERY_FAIL_NUM = QUERY_FAIL_NUM +1
            if QUERY_FAIL_NUM == 5:
                LOAD_RESPONSE_DICT['currentstate'] = u'IP被禁止，%d秒后继续查询..'%PAUSE_TIME
                wx.CallAfter(self.window.Updatestatic)
                QUERY_FAIL_NUM = 0
                time.sleep(PAUSE_TIME)
        if response['status'] == "ok":
            QUERY_FAIL_NUM = 0
            LOAD_RESPONSE_DICT['currentstate'] = u'正常查询中...'
            wx.CallAfter(self.window.Updatestatic)
        '''
        wx.CallAfter(self.window.Analyse_result,i,response)
        #wx.CallAfter(self.window.getimage2,LOAD_RESPONSE_DICT['uuid'])
        self.getimage2(LOAD_RESPONSE_DICT['uuid'])
        wx.CallAfter(self.window.ThreadFinished,self)
'''
    def Add_grid(self,rows):
        while rows>GRIDROWS:
            self.window.grid.AppendRows()
            rows = rows-1
        while rows<GRIDROWS:
            self.window.grid.DeleteRows()
            rows = rows+1
        #wx.CallAfter(self.window.ThreadFinished,self)
        #self.stop()
    def Delete_grid(self,rows):

        while rows > GRIDROWS:
            self.window.grid.DeleteRows()
            rows = rows-1
        #wx.CallAfter(self.window.ThreadFinished,self)
        #self.stop()
'''


class MainUi(wx.Frame):
    colLabels = [u"帐号", u"结果", u"冻结原因", u"冻结时间",u'密码']
    #GRIDROWS = 20
    staticText1_NUM = 0  #正常登录数量化初始化
    staticText2_NUM = 0  #短信
    staticText3_NUM = 0  #改密
    staticText4_NUM = 0  #申诉
    staticText5_NUM = 0  #冻结
    ALLQQNUM = 0
    FINISHEDQQNUM = 0
    COOKIE = ''
    dict_qno = {}#初始化grid的排数与number的对应关系，在开始批量查询激活后起作用
    
     

    def __init__(self):
        self.threads = []
        self.runser = []
        wx.Frame.__init__(self, None, -1, u"QQ查询冻结V002    By:下大雨",size=(595,583))
        self.icon = wx.Icon('pic/ic.ico', wx.BITMAP_TYPE_ICO)
        self.SetIcon(self.icon)  

        panel = wx.Panel(self, -1)
        sizer1=wx.BoxSizer(wx.HORIZONTAL)
        sizer5=wx.BoxSizer(wx.VERTICAL)
        self.Bind(wx.EVT_CLOSE,self.OnCloseWindow)
                        
        #设置区
        self.radio1 = radio1 = wx.RadioButton(panel, -1, u"批量增加",style=wx.RB_GROUP)
        self.radio2 = radio2 = wx.RadioButton(panel, -1, u"单个增加")
        radio_statictext1 = radio_statictext1 = wx.StaticText(panel, -1, u" 暂停时间")
        radio_statictext2 = wx.StaticText(panel, -1, u" 输入号码")
        self.text1 = text1 = wx.TextCtrl(panel, -1, u"600", size=(78, 16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.text2 = text2 = wx.TextCtrl(panel, -1, u"", size=(78, 16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.radio_button1 = radio_button1 = buttons.GenButton(panel, -1, u'导入文件',size=(75,17))
        self.Bind(wx.EVT_BUTTON,self.Openfile,radio_button1)
        
        
        self.radio_button2 = radio_button2 = buttons.GenButton(panel, -1, u'导入QQ',size=(75,17))
        radio_statictext3 = wx.StaticText(panel, -1, u"暂停时间指TX禁止此IP")
        radio_statictext4 = wx.StaticText(panel, -1, u"时XX秒后继续自动查询")
        radio_statictext3.SetForegroundColour('red')
        radio_statictext4.SetForegroundColour('red')
        #self.Bind(wx.EVT_BUTTON,self.Querysingle,radio_button2)
        self.Bind(wx.EVT_BUTTON,self.Querysingle,radio_button2)
    
        
        self.texts = {u"批量增加": text1, u"单个增加": text2}
        text2.Enable(False)
        for eachRadio in [radio1, radio2]:
            self.Bind(wx.EVT_RADIOBUTTON, self.OnRadio, eachRadio)
        self.selectedText = text1
        omm=wx.StaticBox(panel,-1,u"设置区")              
        sizer2=wx.StaticBoxSizer(omm,wx.VERTICAL)
        radio_sizer1=wx.BoxSizer(wx.HORIZONTAL)
        radio_sizer1.Add(radio1,0,wx.ALL,2)
        radio_sizer1.Add(radio_statictext1,0,wx.ALL,2)
        radio_sizer1.Add(text1,0,wx.ALL,2)
        radio_sizer1.Add(radio_button1,0,wx.ALL,2)
        radio_sizer1.Add(radio_statictext3,0,wx.ALL,2)

        radio_sizer2=wx.BoxSizer(wx.HORIZONTAL)
        radio_sizer2.Add(radio2,0,wx.ALL,2)
        radio_sizer2.Add(radio_statictext2,0,wx.ALL,2)
        radio_sizer2.Add(text2,0,wx.ALL,2)
        radio_sizer2.Add(radio_button2,0,wx.ALL,2)
        radio_sizer2.Add(radio_statictext4,0,wx.ALL,2)
        sizer2.Add(radio_sizer1)
        sizer2.Add(radio_sizer2)

        
        #账号区
        self.grid = wx.grid.Grid(panel,size=(420,400))
        self.grid.CreateGrid(GRIDROWS,5)
        
        
        self.submenu = wx.Menu()
        all_item = self.submenu.Append(-1,u'导出全部号码')
        self.grid.Bind(wx.EVT_MENU, self.Selecte_all_item, all_item)
        normal_item = self.submenu.Append(-1,u'导出正常登录')
        self.grid.Bind(wx.EVT_MENU, self.Selecte_normal_item, normal_item)
        message_item = self.submenu.Append(-1,u'导出短信解限')
        self.grid.Bind(wx.EVT_MENU, self.Selecte_message_item, message_item)
        modpassword_item = self.submenu.Append(-1,u'导出改密解限')
        self.grid.Bind(wx.EVT_MENU, self.Selecte_modpassword_item, modpassword_item)
        complain_item = self.submenu.Append(-1,u'导出申诉解限')
        self.grid.Bind(wx.EVT_MENU, self.Selecte_complain_item, complain_item)
        frozen_item = self.submenu.Append(-1,u'导出冻结回收')
        self.grid.Bind(wx.EVT_MENU, self.Selecte_frozen_item, frozen_item)
        illegal_load_item = self.submenu.Append(-1,u'导出非法登录')
        self.grid.Bind(wx.EVT_MENU, self.Selecte_illegal_load_item, illegal_load_item)
                
        self.popupmenu = wx.Menu()
        helpitem = self.popupmenu.Append(-1,u'帮助信息')
        self.grid.Bind(wx.EVT_MENU, self.HelpItemSelected, helpitem)
        clearitem = self.popupmenu.Append(-1,u'清空数据')
        self.grid.Bind(wx.EVT_MENU, self.ClearItemSelected, clearitem)
        exportitem = self.popupmenu.AppendMenu(-1,u'导出结果',self.submenu)
        startitem = self.popupmenu.Append(-1,u'开始批量查询')
        self.grid.Bind(wx.EVT_MENU, self.StartItemSelected, startitem)
        stopitem = self.popupmenu.Append(-1,u'结束批量查询')
        self.grid.Bind(wx.EVT_MENU, self.StopItemSelected, stopitem)



        self.grid.Bind(wx.grid.EVT_GRID_CELL_RIGHT_CLICK,self.OnShowPopup)
        for row in range(5):
            self.grid.SetColLabelValue(row, self.colLabels[row])

        self.grid.SetRowLabelSize(50)
        self.grid.SetColSize(0,90)
        self.grid.SetColSize(1,60)
        self.grid.SetColSize(2,80)
        self.grid.SetColSize(3,146)
        self.grid.SetRowSize(1, 1)
        omm2=wx.StaticBox(panel,-1,u"账号区")     
        sizer3=wx.StaticBoxSizer(omm2,wx.VERTICAL)          
        sizer3.Add(self.grid)
        #s='\xe5\x8f\x91\xe4\xb8\x8d\xe8\x89\xaf\xe4\xbf\xa1\xe6\x81\xaf'
        #self.grid.SetCellValue(0,3,s.decode('utf-8').encode('gb2312'))

        
        #统计区
        staticLab1=wx.StaticText(panel, -1, u"正常登录:")  
        staticLab2=wx.StaticText(panel, -1, u"短信解限:")
        staticLab3=wx.StaticText(panel, -1, u"改密解限:")
        staticLab4=wx.StaticText(panel, -1, u"申诉解限:")
        staticLab5=wx.StaticText(panel, -1, u"冻结回收:")
        
        self.staticText1 = wx.TextCtrl(panel, -1, '%d'%self.staticText2_NUM, size=(55, 16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.staticText1.SetForegroundColour('red')
        self.staticText2=wx.TextCtrl(panel,-1,'%d'%self.staticText2_NUM,size=(55,16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.staticText2.SetForegroundColour('red')
        self.staticText3=wx.TextCtrl(panel,-1,'%d'%self.staticText3_NUM,size=(55,16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.staticText3.SetForegroundColour('red')
        self.staticText4=wx.TextCtrl(panel,-1,'%d'%self.staticText4_NUM,size=(55,16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.staticText4.SetForegroundColour('red')
        self.staticText5=wx.TextCtrl(panel,-1,'%d'%self.staticText5_NUM,size=(55,16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.staticText5.SetForegroundColour('red')

            
        vnfm=wx.StaticBox(panel,-1,u"统计区")
        sizer4=wx.StaticBoxSizer(vnfm,wx.VERTICAL)
        
        statesizer1=wx.BoxSizer(wx.HORIZONTAL)
        statesizer1.Add(staticLab1,0,wx.ALL,2)
        statesizer1.Add(self.staticText1,0,wx.ALL,2)
        
        statesizer2=wx.BoxSizer(wx.HORIZONTAL)
        statesizer2.Add(staticLab2,0,wx.ALL,2)
        statesizer2.Add(self.staticText2,0,wx.ALL,2)

        statesizer3=wx.BoxSizer(wx.HORIZONTAL)
        statesizer3.Add(staticLab3,0,wx.ALL,2)
        statesizer3.Add(self.staticText3,0,wx.ALL,2)

        statesizer4=wx.BoxSizer(wx.HORIZONTAL)
        statesizer4.Add(staticLab4,0,wx.ALL,2)
        statesizer4.Add(self.staticText4,0,wx.ALL,2)

        statesizer5=wx.BoxSizer(wx.HORIZONTAL)
        statesizer5.Add(staticLab5,0,wx.ALL,2)
        statesizer5.Add(self.staticText5,0,wx.ALL,2)
        
        
        sizer4.Add(statesizer1)
        sizer4.Add(statesizer2)
        sizer4.Add(statesizer3)
        sizer4.Add(statesizer4)
        sizer4.Add(statesizer5)

        #手动查询区
        checkfield=wx.StaticBox(panel,-1,u"手动查询区")
        sizer7=wx.StaticBoxSizer(checkfield,wx.VERTICAL)

        self.notice_text2 = wx.StaticText(panel, -1, u"批量查询和导出功能\n需要取消勾选复选框")
        self.notice_text2.SetForegroundColour('red')
        
        self.manualcheck = wx.CheckBox(panel, -1, u"勾选开始手动查询") #手动模式勾选框
        self.Bind(wx.EVT_CHECKBOX,self.Querymanual,self.manualcheck)
        
        nullimg2 = wx.Image('pic/null.jpg', wx.BITMAP_TYPE_ANY)#初始化验证码图片
        self.nullimg = nullimg2.ConvertToBitmap()
        self.image_button = wx.StaticBitmap(panel, -1, self.nullimg)


        self.image_text = wx.StaticText(panel, -1, u"下方输入验证码",(110,35))
        self.image_text.SetForegroundColour('red')
        font = wx.Font(10, wx.DEFAULT,wx.SLANT, wx.LIGHT)# 设置字体
        self.image_text.SetFont(font)
        
        self.image_textctrl = wx.TextCtrl(panel, -1, '', size=(80, 35),style=wx.TE_RICH2)
        self.font2 = wx.Font(18, wx.DEFAULT,wx.NORMAL, wx.BOLD)# 设置字体
        self.image_textctrl.SetStyle(0, 0, wx.TextAttr("black", wx.NullColour, self.font2))
        self.Bind(wx.EVT_TEXT,self.Change_verifycode,self.image_textctrl)
        
        self.image_button.Disable()#手动模式默认不开启，相关部件默认不可用
        self.image_text.Disable()
        self.image_textctrl.Disable()

        sizer7.Add(self.notice_text2,0,wx.TOP,10)
        sizer7.Add(self.manualcheck,0,wx.TOP,10)
        sizer7.Add(self.image_button,0,wx.TOP,10)
        sizer7.Add(self.image_text,0,wx.ALL|wx.TOP,5)
        sizer7.Add(self.image_textctrl,0,wx.LEFT,12)


        #增加文字提示
        notice_text = wx.StaticText(panel, -1, u"在账号区点击鼠标右键\n就能进行导出帐号功能\n批量查询、停止等功能")
        notice_text.SetForegroundColour('blue')

        noticesizer=wx.BoxSizer(wx.VERTICAL)
        noticesizer.Add(notice_text,0,wx.TOP,17)

        #宽带设置区
        bandfield=wx.StaticBox(panel,-1,u"宽带设置区")
        bandfield_sizer=wx.StaticBoxSizer(bandfield,wx.VERTICAL)
        statictext1_band = wx.StaticText(panel, -1,u"帐号",style=wx.ALIGN_CENTER)
        statictext2_band = wx.StaticText(panel, -1,u"密码",style=wx.ALIGN_CENTER)        
        self.text1_band = wx.TextCtrl(panel, -1, u"",size=(80, 20),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.text2_band = wx.TextCtrl(panel, -1, u"",size=(80, 20),style=wx.ALIGN_CENTER_HORIZONTAL|wx.TE_PASSWORD)

        load_sizer1_band=wx.BoxSizer(wx.HORIZONTAL)
        load_sizer2_band=wx.BoxSizer(wx.HORIZONTAL)
        load_sizer1_band.Add(statictext1_band,0,wx.ALL,3)
        load_sizer1_band.Add(self.text1_band,0,wx.ALL,3)
        load_sizer2_band.Add(statictext2_band,0,wx.ALL,3)
        load_sizer2_band.Add(self.text2_band,0,wx.ALL,3)
        load_sizer3_band=wx.BoxSizer(wx.VERTICAL)
        #load_sizer3_band.Add(load_sizer1_band)
        #load_sizer3_band.Add(load_sizer2_band)
        bandfield_sizer.Add(load_sizer1_band)
        bandfield_sizer.Add(load_sizer2_band)
        
       

        #状态栏区
        self.statusbar=wx.StatusBar(panel,-1)
        self.statusbar.SetFieldsCount(4)
        self.statusbar.SetStatusWidths([-4,-4,-4,-6])
        self.statusbar.SetStatusText(u'查询进度：')
        self.statusbar.SetStatusText(u'到期时间：%s'%LOAD_RESPONSE_DICT['deadline'],1)
        self.statusbar.SetStatusText(u'余额：%s 元'%LOAD_RESPONSE_DICT['balance'],2)
        self.statusbar.SetStatusText(u'网络状态正常',3)



               
        #处理布局

        sizer6=wx.BoxSizer(wx.VERTICAL)
        sizer6.Add(noticesizer,0,wx.ALL,1)
        sizer6.Add(sizer4,0,wx.TOP,15)
        sizer6.Add(bandfield_sizer,0,wx.TOP,7)
        sizer6.Add(sizer7,0,wx.TOP,7)
        
        sizer5.Add(sizer2,0,wx.ALL,3)
        sizer5.Add(sizer3,0,wx.ALL,3)
        
        sizer1.Add(sizer5,0,wx.ALL,3) 
        sizer1.Add(sizer6,0,wx.ALL,3)
        
        topsizer=wx.BoxSizer(wx.VERTICAL)
        topsizer.Add(sizer1,0,wx.ALL,3)
        #topsizer.Add(load_sizer6_plat,0,wx.ALL,8)
        topsizer.Add(self.statusbar,0,wx.EXPAND|wx.TOP,15)
        panel.SetSizer(topsizer)
        self.Bind(wx.EVT_KEY_DOWN, self.OnKeyDown)
        panel.Bind(wx.EVT_KEY_DOWN, self.OnKeyDown)
        
    def split_dicts(self,Dict0,N):
        dicts=[dict() for i in range(N)]
        index=0
        for (k,v) in Dict0.items():
            dicts[index][k]=v
            index=(index+1)%N
        return dicts
     
    def OnRadio(self, event):
        if self.selectedText:
            self.selectedText.Enable(False)
        radioSelected = event.GetEventObject()
        text = self.texts[radioSelected.GetLabel()]
        text.Enable(True)
        self.selectedText = text
        
    def Openfile(self, event):
        pat = re.compile('(\d{4,16}).*')  #识别出QQ
        pat2 = re.compile('\d{4,16}(.*)') #识别出密码
        wildcard = u"文本文件 (*.txt)|*.txt"
        dialog = wx.FileDialog(None, u"打开", os.getcwd(),"", wildcard, wx.OPEN)
        if dialog.ShowModal() == wx.ID_OK:
            self.Reset_grid()
            path = dialog.GetPath()
            with open (path) as f:
                d = f.readlines()
                num = 0
                c = {}
                c2 = {} #装入密码
                for i in d:
                    if pat.search(i):
                        c[num] = pat.findall(i)[0]
                        try:
                            c2[num] = pat2.findall(i)[0]  #装入密码
                        except:
                            pass
                        num = num+1
                self.ALLQQNUM = rows = num
            if rows>GRIDROWS:
                self.Dy_add_grid(rows)
            for row in range(rows):
                try:
                    self.grid.SetCellValue(row, 0, "%s"%(c[row]))
                    self.grid.SetCellValue(row, 4, "%s"%(c2[row]))#装入密码
                except:
                    pass
        self.Updatestatic()
        dialog.Destroy()


    def Writefile(self,filename,string):
        if filename.startswith(' '):
            return
        with open(filename,'a')as f:
            f.write(string+'\n')
        

    def Savefile_dialog(self, event):
        filename = ''
        file_wildcard = u"文本文件 (*.txt)|*.txt"
        dialog = wx.FileDialog(None, u"另存为",
                               os.getcwd(),
                               style = wx.SAVE | wx.OVERWRITE_PROMPT,
                               wildcard=file_wildcard)
        if dialog.ShowModal() == wx.ID_OK:
            filename = dialog.GetPath()
            if not os.path.splitext(filename)[1]:
                filename = filename + '.txt'
            with open(filename,'w')as f:
                pass
        dialog.Destroy()
        return filename

    def Dy_add_grid(self,rows):
        '''
        thread = WorkerThread('',{},rows,self,arg=3)  
        self.threads.append(thread)
        thread.start()
        '''
        while rows>GRIDROWS:
            self.grid.AppendRows()
            rows = rows-1
        while rows<GRIDROWS:
            self.grid.DeleteRows()
            rows = rows+1
        

    def Reset_grid(self):
        '''
        self.grid.ClearGrid() #自带的方法，替代下面几句带#的,清除grid所有内容
        rows = self.grid.GetNumberRows()
        thread = WorkerThread('',{},rows,self,arg=4)
        self.threads.append(thread)
        thread.start()
        '''
        self.grid.ClearGrid() #自带的方法，替代下面几句带#的,清除grid所有内容
        rows = self.grid.GetNumberRows()
        while rows > GRIDROWS:
            self.grid.DeleteRows()
            rows = rows-1
        self.staticText1_NUM = 0  #清空数据时，初始化统计数据
        self.staticText2_NUM = 0  
        self.staticText3_NUM = 0  
        self.staticText4_NUM = 0  
        self.staticText5_NUM = 0
        self.ALLQQNUM = 0
        self.FINISHEDQQNUM = 0
        self.Updatestatic()


    def Reset_frame(self): #结束批量查询时恢复某些插件
        raise Exception("dfsafsafsaf888888888888888888888888888888888888888888888888888888888888888888888888")
        self.radio_button1.Enable()
        self.radio_button2.Enable()
        self.radio1.Enable()
        self.radio2.Enable()
        self.grid.EnableEditing(True)

    def Start_frame(self):   #开始批量查询时禁止某些插件
        self.radio_button2.Disable()   #批量查询过程中禁止单个查询
        self.grid.EnableEditing(False) #批量查询过程中禁止grid所有网格被编辑
        self.radio_button1.Disable()
        self.radio1.Disable()
        self.radio2.Disable()
        
    def OnShowPopup(self, event):
        if self.manualcheck.IsChecked():
            pass
        else:
            pos = event.GetPosition()
            self.grid.PopupMenu(self.popupmenu, pos)
        #pos = self.grid.ScreenToClient(pos)
            
    def HelpItemSelected(self, event):
        #item = self.popupmenu.FindItemById(event.GetId()) 
        #text = item.GetText()   获取部件的值，备用
        wx.MessageBox(u"1.本软件支持全自动查询、手动查询二种模式\n2.\
采用客户端服务器模式，无需用户更换IP\n\n收费:\n\
1)软件使用费(包月10元)\n\
2)自动查询模式打码费(由第三方打码超人平台收取0.6分一个)\n\
3)活动期间（6月1号之前）打码费优惠为0.5分一个\n\
4)内置超人打码平台，用户只需注册本软件，无需再去超人平台注册帐号，方便用户使用\n\
\n\
PS:\n\
1)软件万一界面死掉，不要慌张在软件目录result_save中自动缓存当天的查询记录，自动归类\n\
2)导出的冻结原因为非法登录的QQ，可以给我解，百以下0.25/个，百以上0.24/个，千以上0.22/个\n\
3)本软件终身维护，有任何问题请联系QQ7806840或者淘宝店主" )

    def ClearItemSelected(self, event):
        self.Reset_grid()
        
    #def ExportItemSelected(self, event):
        #pass

    def StartItemSelected(self, event):
        global PAUSE_TIME
        self.dict_qno={}
        PAUSE_TIME = int(self.text1.GetValue())
        self.Start_frame()
        rows = self.grid.GetNumberRows()
        for i in range(rows):
            if self.grid.GetCellValue(i,0).startswith('\n') or len(self.grid.GetCellValue(i,0))==0:
                break
            else:
                self.dict_qno[i] = self.grid.GetCellValue(i,0)  
        if not len(self.dict_qno) == 0:
            dicts_qno = self.split_dicts(self.dict_qno,2)
            for j in range(2):
                thread = WorkerThread(LOAD_RESPONSE_DICT['uuid'],dicts_qno[j],self)   #UUID由登录界面传入
                self.threads.append(thread)
                thread.start()
        else:
            return 

        
    
    def StopItemSelected(self, event):
        self.Reset_frame()
        self.Stop_threads()
        

    def Stop_threads(self):   #点击停滞批量查询后停止所有线程

        while self.threads:
            thread=self.threads[0]
            thread.stop()
            #while thread.isAlive():   #4-29修改，防止点击批量停止后界面卡住
                #time.sleep(1)         #4-29修改，防止点击批量停止后界面卡住
            self.threads.remove(thread)


    def ThreadFinished(self,thread):#本线程查询完毕后停止
        if thread in self.threads:
            self.threads.remove(thread)
        if not self.threads:
            self.Reset_frame()
            
        

    def Selecte_all_item(self, event):
        self.Choose_item(event,u'导出全部号码')

    def Choose_item(self,event,state_string): #避免重复，被子菜单绑定事件
        filename = self.Savefile_dialog(event)
        rows = self.grid.GetNumberRows()
        if state_string == u'导出全部号码':
            for i in range(rows):
                s = self.grid.GetCellValue(i,0)
                s2 = self.grid.GetCellValue(i,4) #获取密码
                self.Writefile(filename,s+s2)
        else:
            for i in range(rows):
                if self.grid.GetCellValue(i,1)==state_string:
                    s = self.grid.GetCellValue(i,0)
                    s2 = self.grid.GetCellValue(i,4) #获取密码
                    self.Writefile(filename,s+s2)

    def Selecte_normal_item(self, event):
        self.Choose_item(event,u'正常登录')

    def Selecte_message_item(self, event):
        self.Choose_item(event,u'短信解限')

    def Selecte_modpassword_item(self, event):
        self.Choose_item(event,u'改密解限')

    def Selecte_complain_item(self, event):
        self.Choose_item(event,u'申诉解限')

    def Selecte_frozen_item(self, event):
        self.Choose_item(event,u'冻结回收')

    def Selecte_illegal_load_item(self,event):
        filename = self.Savefile_dialog(event)
        rows = self.grid.GetNumberRows()
        for i in range(rows):
            if self.grid.GetCellValue(i,2) == FROZEN_REASON_ILL_LOAD:
                s = self.grid.GetCellValue(i,0)
                s2 = self.grid.GetCellValue(i,4) #获取密码
                self.Writefile(filename,s+s2)

    def Querysingle(self, event):
        number = self.text2.GetValue().strip()
        if number:
            self.grid.InsertRows()
            self.grid.SetCellValue(0, 0, "%s"%number)
            self.text2.SetValue('')
            self.ALLQQNUM = self.ALLQQNUM+1
            self.Updatestatic()

    def Updatestatic(self):
        self.staticText1.SetValue('%d'%self.staticText1_NUM)
        self.staticText2.SetValue('%d'%self.staticText2_NUM)
        self.staticText3.SetValue('%d'%self.staticText3_NUM)
        self.staticText4.SetValue('%d'%self.staticText4_NUM)
        self.staticText5.SetValue('%d'%self.staticText5_NUM)
        self.statusbar.SetStatusText(u'查询进度：%d/%d'%(self.FINISHEDQQNUM,self.ALLQQNUM))
        self.statusbar.SetStatusText(u'到期时间：%s'%LOAD_RESPONSE_DICT['deadline'],1)
        self.statusbar.SetStatusText(u'余额：%s元'%LOAD_RESPONSE_DICT['balance'],2)
        self.statusbar.SetStatusText(u'%s'%LOAD_RESPONSE_DICT['currentstate'],3)

    def Querymanual(self, event):  #由界面手动查询框框勾选或去勾选触发
        if self.manualcheck.IsChecked():
            self.image_button.Enable()
            self.image_text.Enable()
            self.image_textctrl.Enable()
            thread = WorkerThread(LOAD_RESPONSE_DICT['uuid'],{},self,arg=2) #4-28
            self.threads.append(thread)
            thread.start()
        else:

            self.image_button.SetBitmap(self.nullimg)
            self.image_text.Disable()
            self.image_textctrl.Disable()
            self.Stop_threads()

    def Start_manual_query(self):
        rows = self.grid.GetNumberRows()
        for i in range(rows):
            if self.grid.GetCellValue(i,0).startswith('\n') or len(self.grid.GetCellValue(i,0))==0:
                break
            else:
                self.dict_qno[i] = self.grid.GetCellValue(i,0)
        temp = 0
        count = len(self.dict_qno)
        if count > 0:
            for j in range(count):
                
                if not self.grid.GetCellValue(j,1):
                    temp = 1
                    break
        if temp == 1:
            thread = WorkerThread(LOAD_RESPONSE_DICT['uuid'],self.dict_qno,self,arg=1) #登录界面传入UUID  #4-28
            self.threads.append(thread)
            thread.start()
        else:
            return
        


    def Change_image(self,img1):
        w = img1.GetWidth()
        h = img1.GetHeight()
        img2 = img1.Scale(w*7/8, h)
        img3 = img2.ConvertToBitmap()
        self.image_button.SetBitmap(img3)

    def getimage2(self,uuid):
        response_dict = CS.upload_qno_manual(LOAD_RESPONSE_DICT['uuid'])
        img_temp = response_dict['jpg']
        img = base64.b64decode(img_temp)
        stream = cStringIO.StringIO(img)
        self.img_out = Image.open(stream)
        self.img_out.save('test.jpg')
        img1 = wx.Image('test.jpg', wx.BITMAP_TYPE_ANY)
        self.Change_image(img1)
        clidata = response_dict['clidata']
        global CLIDATA
        CLIDATA = clidata

    def Query_cache(self,row,result,response):
        self.grid.SetCellValue(row, 1, u"%s"%result)
        self.FINISHEDQQNUM = self.FINISHEDQQNUM + 1
        qno = self.grid.GetCellValue(row, 0)
        s2 = self.grid.GetCellValue(row,4) #获取密码
        string = u'查询缓存'
        if result==u'正常登录':
            filename = 'result_save/%s%s-%s.txt'%(TODAY,string,result)
            self.Writefile(filename,qno+s2)

        elif response["reason"]:
            filename = 'result_save/%s%s-%s-%s.txt'%(TODAY,string,result,response["reason"])#修复BUG
            self.Writefile(filename,qno+s2)



    def Analyse_result(self,row,response):
        if response['status'] == 'ok':
            if response["state"] == 'unlock':
                result = u'正常登录'
                self.staticText1_NUM = self.staticText1_NUM+1
                self.Query_cache(row,result,response)
                #self.grid.SetCellValue(row, 1, "%s"%result)
                #self.FINISHEDQQNUM = self.FINISHEDQQNUM + 1
                #qno = self.grid.GetCellValue(row, 0)
                #filename = 'result_save/%s-normal.txt'%TODAY
                #with open(filename,'a')as f:
                    #f.write(qno+'------normal')
                
            elif response["state"] == 'lock':
                self.grid.SetCellValue(row, 2, "%s"%(response["reason"]))#修复BUG
                self.grid.SetCellValue(row, 3, "%s"%response["time"].replace('&nbsp;',''))
                if response["addinfo"] == FROZEN_REASON_RECYCLE:
                    self.staticText5_NUM = self.staticText5_NUM +1
                    result = u"冻结回收"
                    self.Query_cache(row,result,response)
                elif response["addinfo"] == FROZEN_REASON_MOD_PASS:
                    self.staticText3_NUM = self.staticText3_NUM +1
                    result = u"改密解限"
                    self.Query_cache(row,result,response)
                elif response["addinfo"] == FROZEN_REASON_COMPLAIN:
                    self.staticText4_NUM = self.staticText4_NUM +1
                    result = u"申诉解限"
                    self.Query_cache(row,result,response)
                else:
                    self.staticText2_NUM = self.staticText2_NUM +1
                    result = u"短信解限"
                    self.Query_cache(row,result,response)
            else:
                pass
        else:
            pass
        self.Updatestatic()

    def Change_verifycode(self,event):
        if len(self.image_textctrl.GetValue()) == 4:
            self.Get_verifycode()
            self.image_textctrl.Clear()
            self.image_textctrl.SetStyle(0, 0, wx.TextAttr("black", wx.NullColour, self.font2))
            self.Start_manual_query()
            
        else:
            pass
    
    def Get_verifycode(self):
        code = self.image_textctrl.GetValue()
        global VERIFY_CODE
        VERIFY_CODE = code

    def OnCloseWindow(self,evt):
        dlg = wx.MessageDialog(None, u"是否关闭QQ查询冻结工具?",
                          u'QQ查询冻结工具',
                          wx.YES_NO | wx.ICON_QUESTION)
        retCode = dlg.ShowModal()
        if (retCode == wx.ID_YES):
            dlg.Destroy()
            self.Destroy()
        else:
            dlg.Destroy()
            pass
        CS.exit_server(LOAD_RESPONSE_DICT['uuid'])
    def OnKeyDown(self, event):  
        #按键时相应代码  
        kc=event.GetKeyCode()  
        print 'key down:',kc  
        

            
def start(load_response_dict):
    global LOAD_RESPONSE_DICT
    LOAD_RESPONSE_DICT = load_response_dict #登录之后跳转到start函数，保存传入的response
    LOAD_RESPONSE_DICT['currentstate'] = ''
    app = wx.PySimpleApp() 
    UiShow=MainUi()
    UiShow.Show(True)
    app.MainLoop() 



if __name__=='__main__':
    start(LOAD_RESPONSE_DICT)

