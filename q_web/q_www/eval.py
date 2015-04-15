import os
import sys
import xlrd

def isFileFormatMatch(sheet):
	fileformat = ["工号","名字","额度","回拨电话","网络电话","电话会议","手机短信","视频会议"]
	for i in range(0,sheet.ncols):
		if (not ((sheet.cell_type(0,i) == xlrd.XL_CELL_TEXT) and (getCellValue(sheet,0,i) == fileformat[i]))):
			return False
	return True

def getCellValue(sheet,row,col):
	return sheet.cell_value(row,col).encode("utf-8").strip()

def analyse(filename):
	array = []
	sheet = xlrd.open_workbook(filename).sheet_by_index(0)
	if (not (isFileFormatMatch(sheet))):
		return ("not_match",[])
	else:
		try:
			for i in range(1,sheet.nrows):
				item = []
				for j in range(0,sheet.ncols):
					item.append(getCellValue(sheet,i,j))
				array.append(item)
			return ("ok",array)
		except:
			return ("not_match",[])

def writeFile(filename,dataList):
	f = open(filename,'w')
	for i in range(len(dataList)):
		f.write(":".join(dataList[i]) + "\n")
	f.close()

def run(filename):
	result = analyse(filename)
	if (result[0] == 'ok'):
		writeFile(os.path.splitext(filename)[0],result[1])
		sys.stdout.write('ok')
	else:
		sys.stdout.write('fail')

if __name__ == "__main__":
	fileName = sys.argv[1]
	run(fileName)