# -*- coding: utf-8 -*-
import wx
import wx.lib.buttons as buttons
import CSinterface as CS
import mainframe as MAIN
import q
import json

def write_data(filename='data',dictdata={}):#4-28
    dictdata0 = open_data(filename)
    dictdata0.update(dictdata)
    data_json=json.dumps(dictdata0)
    bin=q.encrypt(data_json)
    with open(filename,"wb") as fd:
        fd.write(bin)

def open_data(filename='data',dictdata={'acc':'','pwd':'','band_acc':'','band_pwd':''}):#4-28
    try:
        with open(filename,"rb") as fd:
            enc=fd.read()
            if enc:
                bin=q.decrypt(enc)
                dictdata=json.loads(bin)
    except:
        pass
    return dictdata
    
class loadframe(wx.Panel):
    def __init__(self,parent,mainFrame):
        wx.Panel.__init__(self, parent)
        self.panle=panel = wx.Panel(self)
        colour = [(160,255,204),(153,204,255),(151,253,225),]
        self.SetBackgroundColour(colour[0])

        #增加部件

        statictext1 = wx.StaticText(self, -1,u"         会员帐号  ",style=wx.ALIGN_CENTER)
        statictext2 = wx.StaticText(self, -1,u"         会员密码  ",style=wx.ALIGN_CENTER)
        self.text1 = wx.TextCtrl(self, -1, u"%s"%open_data()['acc'],size=(125, 20),style=wx.ALIGN_CENTER_HORIZONTAL)#4-28
        self.text2 = wx.TextCtrl(self, -1, u"%s"%open_data()['pwd'],size=(125, 20),style=wx.ALIGN_CENTER_HORIZONTAL|wx.TE_PASSWORD)#4-28
        self.result_statictext = wx.StaticText(self, -1,u"",style=wx.ALIGN_CENTER_HORIZONTAL)
        self.result_statictext.SetForegroundColour('red')


        #布局处理
        load_sizer1=wx.BoxSizer(wx.HORIZONTAL)
        load_sizer2=wx.BoxSizer(wx.HORIZONTAL)
        load_sizer1.Add(statictext1,0,wx.ALL,5)
        load_sizer1.Add(self.text1,0,wx.ALL,5)
        load_sizer2.Add(statictext2,0,wx.ALL,5)
        load_sizer2.Add(self.text2,0,wx.ALL,5)

        self.load_button = buttons.GenButton(self, -1, u'登 录',size=(75,30))
        self.Bind(wx.EVT_BUTTON,self.load,self.load_button)
        
        #load_field=wx.StaticBox(self,-1,u"")              
        #sizer2=wx.StaticBoxSizer(load_field,wx.VERTICAL)
        sizer2=wx.BoxSizer(wx.VERTICAL)
        sizer2.Add(load_sizer1,0,wx.TOP,25)
        sizer2.Add(load_sizer2,0,wx.BOTTOM,10)
        sizer2.Add(self.load_button,0,wx.ALIGN_CENTER)
        sizer2.Add(self.result_statictext,0,wx.TOP,10)
        self.SetSizer(sizer2)
        self.mainFrame=mainFrame

    def load(self,event):
        acc = self.text1.GetValue()
        pwd = self.text2.GetValue()
        response_dict = CS.load_server(acc,pwd)
        response_dict['acc'] = acc
        
        if response_dict['status']=='ok':
            #self.write_data(dictdata={'acc':acc,'pwd':pwd})#4-28
            write_data(dictdata={'acc':acc,'pwd':pwd})#5-4
            self.mainFrame.Destroy()
            MAIN.start(response_dict)
        elif response_dict['reason']=='account_not_existed':
            self.result_statictext.SetLabel(u"登录失败，该账户不存在！")
        elif response_dict['reason']=='pwd_not_match':
            self.result_statictext.SetLabel(u"登录失败，密码输入错误！")
        else:
            self.result_statictext.SetLabel(response_dict['reason'])
            
    '''
    def write_data(self,filename='data',dictdata={}):#4-28
        dictdata0 = self.open_data(filename)
        dictdata0.update(dictdata)
        data_json=json.dumps(dictdata0)
        bin=q.encrypt(data_json)
        with open(filename,"wb") as fd:
            fd.write(bin)
        


    def open_data(self,filename='data',dictdata={'acc':'','pwd':''}):#4-28
        try:
            with open(filename,"rb") as fd:
                enc=fd.read()
                if enc:
                    bin=q.decrypt(enc)
                    dictdata=json.loads(bin)
        except:
            pass
        return dictdata                
    '''


class registerframe(wx.Panel):
    def __init__(self,parent):
        wx.Panel.__init__(self, parent)
        notic_text = wx.StaticText(self,label=u'购买充值卡后 才可以注册帐号')
        notic_text.SetForegroundColour('blue')
        colour = [(160,255,204),(153,204,255),(151,253,225),]
        self.SetBackgroundColour(colour[1])
        font = wx.Font(14, wx.SWISS, wx.NORMAL, wx.BOLD)

        #增加部件
        statictext1 = wx.StaticText(self, -1,u"    会员帐号  ",style=wx.ALIGN_CENTER)
        statictext2 = wx.StaticText(self, -1,u"    会员密码  ",style=wx.ALIGN_CENTER)
        statictext3 = wx.StaticText(self, -1,u"     充值卡号  ",style=wx.ALIGN_CENTER)
        self.text1 = wx.TextCtrl(self, -1, u"",size=(125, 20),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.text2 = wx.TextCtrl(self, -1, u"",size=(125, 20),style=wx.ALIGN_CENTER_HORIZONTAL|wx.TE_PASSWORD)
        self.text3 = wx.TextCtrl(self, -1, u"",size=(200, 20),style=wx.ALIGN_CENTER_HORIZONTAL)
        
        self.reg_button = buttons.GenButton(self, -1, u'注 册',size=(75,30))
        self.Bind(wx.EVT_BUTTON,self.register,self.reg_button)

        self.result_statictext = wx.StaticText(self, -1,u"",style=wx.ALIGN_CENTER_HORIZONTAL)
        self.result_statictext.SetForegroundColour('red')

        #布局处理
        reg_sizer1=wx.BoxSizer(wx.HORIZONTAL)
        reg_sizer2=wx.BoxSizer(wx.HORIZONTAL)
        reg_sizer3=wx.BoxSizer(wx.HORIZONTAL)
        reg_sizer4=wx.BoxSizer(wx.VERTICAL)
        reg_sizer5=wx.BoxSizer(wx.HORIZONTAL)
        reg_sizer1.Add(statictext1,0,wx.ALL,3)
        reg_sizer1.Add(self.text1,0,wx.ALL,3)
        reg_sizer2.Add(statictext2,0,wx.ALL,3)
        reg_sizer2.Add(self.text2,0,wx.ALL,3)
        reg_sizer4.Add(reg_sizer1,0,wx.ALL,3)
        reg_sizer4.Add(reg_sizer2,0,wx.ALL,3)
        reg_sizer5.Add(reg_sizer4,0,wx.ALL,3)
        reg_sizer5.Add(self.reg_button,0,wx.TOP,22)
        reg_sizer3.Add(statictext3,0,wx.ALL,5)
        reg_sizer3.Add(self.text3,0,wx.ALL,1)

        #register_field=wx.StaticBox(self,-1,u"")              
        #sizer2=wx.StaticBoxSizer(register_field,wx.VERTICAL)
        sizer2=wx.BoxSizer(wx.VERTICAL)
        sizer2.Add(notic_text,0,wx.ALIGN_CENTER|wx.TOP,25)
        sizer2.Add(reg_sizer5,0,wx.ALL,0)
        sizer2.Add(reg_sizer3,0,wx.BOTTOM,0)
        sizer2.Add(self.result_statictext,0,wx.TOP,10)
        self.SetSizer(sizer2)

    def register(self,event):
        acc = self.text1.GetValue()
        pwd = self.text2.GetValue()
        auth_code = self.text3.GetValue()
        response_dict = CS.registerd_account(acc,pwd,auth_code)
        if response_dict['status']=='ok':
            self.result_statictext.SetLabel(u"恭喜您成功注册,账户名:%s 当前余额为:%s"%(self.text1.GetValue(),response_dict['balance']))
        elif response_dict['reason']=='username_already_existed':
            self.result_statictext.SetLabel(u"抱歉！该用户名已存在，请更换用户名注册")
        elif response_dict['reason']=='invalid_auth_code':
            self.result_statictext.SetLabel(u"抱歉！该充值卡无效")
        else:
            self.result_statictext.SetLabel(u"抱歉！注册失败,请检查充值卡号是否正确！\n如有疑问请联系店主淘宝或QQ7806840")

class rechargeframe(wx.Panel):
    def __init__(self,parent):
        wx.Panel.__init__(self, parent)
        notic_text = wx.StaticText(self,label=u'已经注册过帐号 才可以在这充值')
        notic_text.SetForegroundColour('blue')
        colour = [(160,255,204),(153,204,255),(151,253,225),]
        self.SetBackgroundColour(colour[2])
        font = wx.Font(14, wx.SWISS, wx.NORMAL, wx.BOLD)

        #增加部件
        statictext1 = wx.StaticText(self, -1,u" 会员帐号  ",style=wx.ALIGN_CENTER)
        statictext3 = wx.StaticText(self, -1,u"    充值卡号  ",style=wx.ALIGN_CENTER)
        self.text1 = wx.TextCtrl(self, -1, u"",size=(125, 20),style=wx.ALIGN_CENTER_HORIZONTAL)
        self.text3 = wx.TextCtrl(self, -1, u"",size=(200, 20),style=wx.ALIGN_CENTER_HORIZONTAL)
        
        self.chg_button = buttons.GenButton(self, -1, u'充 值',size=(75,30))
        self.Bind(wx.EVT_BUTTON,self.recharge,self.chg_button)

        self.result_statictext = wx.StaticText(self, -1,u"",style=wx.ALIGN_CENTER_HORIZONTAL)
        self.result_statictext.SetForegroundColour('red')

        #布局处理
        reg_sizer1=wx.BoxSizer(wx.HORIZONTAL)
        reg_sizer2=wx.BoxSizer(wx.HORIZONTAL)
        reg_sizer3=wx.BoxSizer(wx.HORIZONTAL)

        reg_sizer1.Add(statictext1,0,wx.ALL,3)
        reg_sizer1.Add(self.text1,0,wx.ALL,3)
        reg_sizer2.Add(reg_sizer1,0,wx.ALL,3)
        reg_sizer2.Add(self.chg_button,0,wx.ALL,3)
        reg_sizer3.Add(statictext3,0,wx.ALL,3)
        reg_sizer3.Add(self.text3,0,wx.ALL,3)

        #register_field=wx.StaticBox(self,-1,u"")              
        #sizer2=wx.StaticBoxSizer(register_field,wx.VERTICAL)
        sizer2=wx.BoxSizer(wx.VERTICAL)
        sizer2.Add(notic_text,0,wx.ALIGN_CENTER|wx.TOP,20)
        sizer2.Add(reg_sizer2,0,wx.ALL,8)
        sizer2.Add(reg_sizer3,0,wx.BOTTOM,0)
        sizer2.Add(self.result_statictext,0,wx.TOP,10)
        self.SetSizer(sizer2)

    def recharge(self,event):
        acc = self.text1.GetValue()
        auth_code = self.text3.GetValue()
        response_dict = CS.recharge(acc,auth_code)
        if response_dict['status']=='ok':
            self.result_statictext.SetLabel(u"恭喜您充值成功,账户名:%s 当前余额为:%s"%(self.text1.GetValue(),response_dict['balance']))
        elif response_dict['status']=='failed':
            self.result_statictext.SetLabel(u"抱歉！充值失败,请检查充值卡号和用户名是否正确！\n如有疑问请联系店主淘宝或QQ7806840")
        
class Frame(wx.Frame):
    def __init__(self):
        wx.Frame.__init__(self, None, -1, u"QQ查询冻结V002    ",size=(360,310))
        self.icon = wx.Icon('pic/ic.ico', wx.BITMAP_TYPE_ICO)
        self.SetIcon(self.icon)  

        panel = wx.Panel(self, -1)
        #中间功能取
        nb = wx.Notebook(panel,style=wx.NB_FIXEDWIDTH)
        nb.AddPage(loadframe(nb,self), u"会员登录")
        nb.AddPage(registerframe(nb), u"帐号注册")
        nb.AddPage(rechargeframe(nb), u"帐号充值")
        #界面顶部图片
        image_top_add = wx.Image('pic/top.jpg', wx.BITMAP_TYPE_ANY)
        image_top_bmp = image_top_add.ConvertToBitmap()
        self.image_top = wx.StaticBitmap(panel, -1, image_top_bmp)

        #状态栏区
        self.statusbar=wx.StatusBar(panel,-1)
        self.statusbar.SetFieldsCount(2)
        self.statusbar.SetStatusWidths([-2,-4])
        self.statusbar.SetStatusText(u'')
        self.statusbar.SetStatusText(u'',1)
        
        sizer = wx.BoxSizer(wx.VERTICAL)
        sizer.Add(self.image_top,0, wx.EXPAND,0)
        sizer.Add(nb, 1, wx.EXPAND,0)
        sizer.Add(self.statusbar, 0, wx.EXPAND,0)
        panel.SetSizer(sizer)
        #page1.SetFocus()

    def destroy(self):
        self.Destroy()
        wx.GetApp().ExitMainLoop()
        wx.Exit()






if __name__ == '__main__':
    app = wx.App(False) 
    uishow = Frame()
    uishow.Show(True)
    app.MainLoop()

