import os
import shutil

def	run():
	rc = []
	cf = open('C:\Users\caspar\Desktop\caspar\cf','a+')
	hf = open('C:\Users\caspar\Desktop\caspar\hf','a+')
	cn = doWork('C:\\Users\\caspar\\Desktop\\caspar\\test',hf)
	cn = sorted(cn)
	for i in range(len(cn)):
		cf.write(cn[i])
	cf.close()
	hf.close()
	for i in range(len(cn)):
		if i != len(cn) - 1 and cn[i] == cn[i + 1]:
			rc = rc + [cn[i]]
	return rc
	
def	doWork(Directory,hf):
	cn = []
	list = os.listdir(Directory)
	num	 = len(list)
	if (0 != num):
		for i in range(num):
			filePath = os.path.join(Directory,list[i])
			if(os.path.isdir(filePath) == True):
				cn = cn + doWork(filePath,hf)
			else:
				if(os.path.isfile(filePath) == True):
					ext = os.path.splitext(filePath)[1]
					if (ext == '.h'):
						shutil.copy(filePath,'C:\Users\caspar\Desktop\caspar\h')
						hf.write("'" + os.path.basename(filePath) + "'," + "\n")
					elif ((ext == '.c') or (ext == '.cpp')):
						shutil.copy(filePath,'C:\Users\caspar\Desktop\caspar\c')
						cn = cn + ["'" + os.path.basename(filePath) + "'," + "\n"]
	return cn