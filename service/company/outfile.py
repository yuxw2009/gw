import	os
import	string
import	xlwt
import	sys
from decimal	import *

def	get_stat(Dir):
	value = []
	FileName   = Dir + 'stat'
	FileHandle = open(FileName)
	for line in FileHandle.readlines():
		value = value + [line.strip("\n").split(",")]
	FileHandle.close()
	os.remove(FileName)
	return value

def outfile(Y,M):
	Dir = "/home/ayu/www/zte/tmp/"
	#Dir = "D:\\livecom\\livecom work\\lwork\\www\\lwork\\tmp\\"
	FileName = Dir + 'zte-ltalk-' + str(Y) + '-' + str(M) + '.xls'
	if os.path.isfile(FileName) == True:
		os.remove(FileName)
	stats = get_stat(Dir)
	wbk   = xlwt.Workbook(encoding='utf-8')
	sheet = wbk.add_sheet('统计')
	sheet.write(0,0,"部门名称")
	sheet.write(0,1,"工号")
	sheet.write(0,2,"姓名")
	sheet.write(0,3,"呼叫类型")
	sheet.write(0,4,"金额")
	sheet.write(0,5,"呼叫时长")
	sheet.write(0,6,"起始日期")
	sheet.write(0,7,"终止日期")
	for i in range(len(stats)):
		stat = stats[i]
		for j in range(len(stat)):
			if j == 4:
				sheet.write(i + 1,j,str(round(Decimal(stat[j]),2)))
			else:
				sheet.write(i + 1,j,stat[j])
	wbk.save(FileName)
	sys.stdout.write('ok')
	return
	
