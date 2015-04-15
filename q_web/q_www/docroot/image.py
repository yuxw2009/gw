import	os
import	sys
import	Image

def process(ImageName):
	(Root,Ext)   = os.path.splitext(ImageName)
	IM = Image.open(ImageName)
	OriginalSize = IM.size
	(SmallPicSize,BigPicSize) = calc_zoom_size(OriginalSize,100,500)
	SmallPic = IM.resize(SmallPicSize)
	BigPic   = IM.resize(BigPicSize,Image.ANTIALIAS)
	SmallPic.save(Root + 'S' + Ext)
	BigPic.save(Root + 'B' + Ext,quality = 95)
	sys.stdout.write('ok')
	return

def calc_zoom_size(OriginalSize,Small,Big):
	(Width,Heigth) = OriginalSize
	(SmallRatio,BigRatio) = calc_zoom_ratio(OriginalSize,Small,Big)
	SmallPicSize = (int(Width * SmallRatio),int(Heigth * SmallRatio))
	BigPicSize   = (int(Width * BigRatio),int(Heigth * BigRatio))
	return (SmallPicSize,BigPicSize)

def calc_zoom_ratio(OriginalSize,Small,Big):
	Max = max(OriginalSize)
	if (Max <= Small):
		return (1,1)
	elif ((Max > Small) and (Max <= Big)):
		return (Small*1.0/Max,1)
	else:
		return (Small*1.0/Max,Big*1.0/Max)