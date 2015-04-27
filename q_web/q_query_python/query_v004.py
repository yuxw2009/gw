# -*- coding: utf-8 -*-
import wx
import os
import threading
import Parserlinks25173tianchifujiangB1 as jk
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



header_getimage = {
        "Accept":"*/*",
        "Referer": "http://aq.qq.com/cn2/login_limit/login_limit_index",
        "Accept-Language": "zh-cn",
        "User-Agent": "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)",
        "Accept-Encoding": "gzip, deflate",
        "Host": "captcha.qq.com",
        "Connection": "Keep-Alive"

        }
header_getcheckverify = {
        "X-Requested-With":"XMLHttpRequest",
        "Accept":"image/gif, image/jpeg, image/pjpeg, */*",
        "Referer": "http://aq.qq.com/cn2/login_limit/login_limit_index",
        "Accept-Language": "zh-cn",
        "User-Agent": "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727)",
        "Accept-Encoding": "gzip, deflate",
        "Host": "aq.qq.com",
        "Connection": "Keep-Alive",
        "Content-Type":"application/x-www-form-urlencoded"
        }

header_getcheckstate = {
        "X-Requested-With":"XMLHttpRequest",
        "Accept":"image/gif, image/jpeg, image/pjpeg, */*",
        "Referer": "http://aq.qq.com/cn2/login_limit/login_limit_index",
        "Accept-Language": "zh-cn",
        "User-Agent": "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727)",
        "Accept-Encoding": "gzip, deflate",
        "Host": "aq.qq.com",
        "Connection": "Keep-Alive",
        "Content-Type":"application/x-www-form-urlencoded"
        }



class WorkerThread(threading.Thread):
    def __init__(self,uuid,dict_qno,rows,window,arg=0):
        threading.Thread.__init__(self)
        self.window = window
        self.timeToQuit = threading.Event()
        self.timeToQuit.clear()
        self.uuid = uuid
        self.dict_qno = dict_qno
        self.rows = rows
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

    def getimage2(self,uuid):
        response_dict = CS.upload_qno_manual(LOAD_RESPONSE_DICT['uuid'])
        img_temp = response_dict['jpg']
        img = base64.b64decode(img_temp)
        stream = cStringIO.StringIO(img)
        self.img_out = Image.open(stream)
        self.img_out.save('pic/test.jpg')
        img1 = wx.Image('pic/test.jpg', wx.BITMAP_TYPE_ANY)
        wx.CallAfter(self.window.Change_image,img1)
        #self.Change_image(img1)
        clidata = response_dict['clidata']
        #clidata = 'verifysession=h01ebcc20325a4466bd25d674f4bd1515558a62e3b677013922130c5a65b0b692732ce29d7a7777c714; PATH=/; DOMAIN=qq.com;'
        global CLIDATA
        CLIDATA = clidata

    def Query_auto(self):
        for i in range(self.rows+1):
            if self.timeToQuit.isSet():
                wx.CallAfter(self.window.ThreadFinished,self)
                break
            elif i>= (self.rows):
                wx.CallAfter(self.window.ThreadFinished,self)
                break
            elif not self.window.grid.GetCellValue(i,1):
                response = CS.query_state(self.uuid,self.dict_qno[i])
                wx.CallAfter(self.window.Analyse_result,i,response)


    def Qyery_manual(self):
        for i in range(self.rows+1):
            if not self.window.grid.GetCellValue(i,1):
                break
        #vercode = wx.CallAfter(self.window.Get_verifycode)
        clidata = CLIDATA
        vercode = VERIFY_CODE
        response = CS.query_state_manual(self.uuid,self.dict_qno[i],vercode,clidata)
        wx.CallAfter(self.window.Analyse_result,i,response)
        #wx.CallAfter(self.window.getimage2,LOAD_RESPONSE_DICT['uuid'])
        self.getimage2(LOAD_RESPONSE_DICT['uuid'])
        wx.CallAfter(self.window.ThreadFinished,self)



class MainUi(wx.Frame):
    colLabels = [u"帐号", u"结果", u"冻结原因", u"冻结时间"]
    GRIDROWS = 20
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
                        
        #设置区
        self.radio1 = radio1 = wx.RadioButton(panel, -1, u"批量增加",style=wx.RB_GROUP)
        self.radio2 = radio2 = wx.RadioButton(panel, -1, u"单个增加")
        radio_statictext1 = radio_statictext1 = wx.StaticText(panel, -1, u" 延时毫秒")
        radio_statictext2 = wx.StaticText(panel, -1, u" 输入号码")
        text1 = wx.TextCtrl(panel, -1, u"1600", size=(78, 16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.text2 = text2 = wx.TextCtrl(panel, -1, u"", size=(78, 16),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.radio_button1 = radio_button1 = buttons.GenButton(panel, -1, u'导入文件',size=(75,17))
        self.Bind(wx.EVT_BUTTON,self.Openfile,radio_button1)
        
        
        self.radio_button2 = radio_button2 = buttons.GenButton(panel, -1, u'导入QQ',size=(75,17))
        radio_statictext3 = wx.StaticText(panel, -1, u"批量：点击导入QQ文件")
        radio_statictext4 = wx.StaticText(panel, -1, u"单个：输入QQ点击导入")
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
        self.grid.CreateGrid(self.GRIDROWS,4)
        
        
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
        for row in range(4):
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
        self.statusbar.SetFieldsCount(3)
        self.statusbar.SetStatusWidths([-2,-3,-3])
        self.statusbar.SetStatusText(u'查询进度：')
        self.statusbar.SetStatusText(u'到期时间：%s'%LOAD_RESPONSE_DICT['deadline'],1)
        self.statusbar.SetStatusText(u'账户名：%s'%LOAD_RESPONSE_DICT['acc'],2)
        #self.statusbar.SetStatusText(u'账户余额：%s 元'%LOAD_RESPONSE_DICT['balance'],3)



               
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
        

     
    def OnRadio(self, event):
        if self.selectedText:
            self.selectedText.Enable(False)
        radioSelected = event.GetEventObject()
        text = self.texts[radioSelected.GetLabel()]
        text.Enable(True)
        self.selectedText = text
        
    def Openfile(self, event):
        pat = re.compile('(\d{4,16}).*')  #识别出QQ
        wildcard = u"文本文件 (*.txt)|*.txt"
        dialog = wx.FileDialog(None, u"打开", os.getcwd(),"", wildcard, wx.OPEN)
        if dialog.ShowModal() == wx.ID_OK:
            self.Reset_grid()
            path = dialog.GetPath()
            with open (path) as f:
                d = f.readlines()
                num = 0
                c = {}
                for i in d:
                    if pat.search(i):
                        c[num] = pat.findall(i)[0]
                        num = num+1
                self.ALLQQNUM = rows = num
            if rows>self.GRIDROWS:
                self.Dy_add_grid(rows)
            for row in range(rows):
                self.grid.SetCellValue(row, 0, "%s"%(c[row]))
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
        while rows>self.GRIDROWS:
            self.grid.AppendRows()
            rows = rows-1
        while rows<self.GRIDROWS:
            self.grid.DeleteRows()
            rows = rows+1

    def Reset_grid(self):
        self.grid.ClearGrid() #自带的方法，替代下面几句带#的,清除grid所有内容
        rows = self.grid.GetNumberRows()
        while rows > self.GRIDROWS:
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
        self.Start_frame()
        rows = self.grid.GetNumberRows()
        for i in range(rows):
            if self.grid.GetCellValue(i,0).startswith('\n') or len(self.grid.GetCellValue(i,0))==0:
                break
            else:
                self.dict_qno[i] = self.grid.GetCellValue(i,0)
        if not len(self.dict_qno) == 0:
            thread = WorkerThread(LOAD_RESPONSE_DICT['uuid'],self.dict_qno,i,self)   #UUID由登录界面传入
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
            while thread.isAlive():
                time.sleep(1)
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
                self.Writefile(filename,s)
        else:
            for i in range(rows):
                if self.grid.GetCellValue(i,1)==state_string:
                    s = self.grid.GetCellValue(i,0)
                    self.Writefile(filename,s)

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
                self.Writefile(filename,s)

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
        self.statusbar.SetStatusText(u'账户名：%s'%LOAD_RESPONSE_DICT['acc'],2)
        #self.statusbar.SetStatusText(u'账户余额：%s元'%LOAD_RESPONSE_DICT['balance'],3)

    def Querymanual(self, event):  #由界面手动查询框框勾选或去勾选触发
        if self.manualcheck.IsChecked():
            self.image_button.Enable()
            self.image_text.Enable()
            self.image_textctrl.Enable()
            thread = WorkerThread(LOAD_RESPONSE_DICT['uuid'],{},0,self,arg=2)
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
            thread = WorkerThread(LOAD_RESPONSE_DICT['uuid'],self.dict_qno,i,self,arg=1) #登录界面传入UUID
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
        string = u'查询缓存'
        if result==u'正常登录':
            filename = 'result_save/%s%s-%s.txt'%(TODAY,string,result)
            with open(filename,'a')as f:
                f.write(qno+'\n')
        elif response["reason"]:
            filename = 'result_save/%s%s-%s-%s.txt'%(TODAY,string,result,response["reason"])
            with open(filename,'a')as f:
                f.write(qno+'\n')



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
                self.grid.SetCellValue(row, 2, "%s"%response["reason"])
                self.grid.SetCellValue(row, 3, "%s"%response["time"].replace('&nbsp;',''))
                if response["addinfo"] == FROZEN_REASON_RECYCLE:
                    self.staticText5_NUM = self.staticText5_NUM +1
                    result = u"冻结回收"
                    self.Query_cache(row,result,response)
                    #self.grid.SetCellValue(row, 1, u"冻结回收")
                    #self.FINISHEDQQNUM = self.FINISHEDQQNUM +1
                elif response["addinfo"] == FROZEN_REASON_MOD_PASS:
                    self.staticText3_NUM = self.staticText3_NUM +1
                    result = u"改密解限"
                    self.Query_cache(row,result,response)
                    #self.grid.SetCellValue(row, 1, u"改密解限")
                    #self.FINISHEDQQNUM = self.FINISHEDQQNUM +1
                elif response["addinfo"] == FROZEN_REASON_COMPLAIN:
                    self.staticText4_NUM = self.staticText4_NUM +1
                    result = u"申诉解限"
                    self.Query_cache(row,result,response)
                    #self.grid.SetCellValue(row, 1, u"申诉解限")
                    #self.FINISHEDQQNUM = self.FINISHEDQQNUM +1
                else:
                    self.staticText2_NUM = self.staticText2_NUM +1
                    result = u"短信解限"
                    self.Query_cache(row,result,response)
                    #self.grid.SetCellValue(row, 1, u"短信解限")
                    #self.FINISHEDQQNUM = self.FINISHEDQQNUM +1
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
            
def start(load_response_dict):
    global LOAD_RESPONSE_DICT
    LOAD_RESPONSE_DICT = load_response_dict #登录之后跳转到start函数，保存传入的response
    app = wx.PySimpleApp() 
    UiShow=MainUi()
    UiShow.Show(True)
    app.MainLoop() 



if __name__=='__main__':
    start(LOAD_RESPONSE_DICT)


    def checksession(self,url):
        number = self.text2.GetValue()
        checknumber = self.image_textctrl.GetValue()
        resultHtml=httplib.HTTPConnection(url, 80, False)
        header_getcheckverify["Referer"] = 'http://aq.qq.com/'+'/cn2/ajax/check_verifycode?verify_code=%s&account=%s&session_type=on_rand'%(checknumber,number)
        resultHtml.request('GET', '/cn2/ajax/check_verifycode?verify_code=%s&account=%s&session_type=on_rand'%(checknumber,number),
                       headers = header_getcheckverify)
        page=resultHtml.getresponse()
        L = page.getheaders()
        self.COOKIE = self.COOKIE+';'+self.get_aq_base_sid(L)
        header_getcheckstate["cookie"] = self.COOKIE
        times = str(time.time())
        timed = times[0:10]+times[11:]
        print timed
        resultHtml.request('GET', '/cn2/login_limit/checkstate?from=1&account=%s&verifycode=%s&_=%s2'%(number,checknumber,timed),
                       headers = header_getcheckstate)
        page2=resultHtml.getresponse(True)

    def get_aq_base_sid(self,L):
        for i in L:
            if 'set-cookie' in i:
                return i[1].split(';')[0]



    def checkstate(self,url):
        number = self.text2.GetValue()
        checknumber = self.image_textctrl.GetValue()
        resultHtml=httplib.HTTPConnection(url, 80, False)
        resultHtml.request('GET', '/cn2/login_limit/checkstate?from=1&account=%s&verifycode=%s'%(number,checknumber),
                       headers = header_getcheckverify)
        page=resultHtml.getresponse(True)

    def startmanualquery(self, event):
        
        self.checksession("aq.qq.com")
        #self.checkstate("aq.qq.com")


