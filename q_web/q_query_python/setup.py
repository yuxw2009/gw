# -*- coding: utf-8 -*-

from distutils.core import setup
import py2exe

setup(windows=["QQ_query.py"],
      data_files = [('pic',['pic/null.jpg','pic/top.jpg','pic/test.jpg','pic/ic.ico']),
                     ('result_save',['result_save/read me.txt'])]
      )
