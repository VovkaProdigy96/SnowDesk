# SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0
# Генератор картинок для SnowDesk. Нужны: pip install numpy pillow opencv-python
# Запуск: python3 app_icon.py  →  AppIcon.icns, icon_1024.png
from PIL import Image, ImageDraw, ImageFilter
import math
S=1024
img=Image.new('RGBA',(S,S),(0,0,0,0))
# фон: скруглённый квадрат с градиентом
bg=Image.new('RGBA',(S,S))
for y in range(S):
    t=y/S; c=(int(24+30*t),int(34+40*t),int(78+60*t),255)
    ImageDraw.Draw(bg).line([(0,y),(S,y)],fill=c)
mask=Image.new('L',(S,S),0); ImageDraw.Draw(mask).rounded_rectangle([40,40,S-40,S-40],radius=200,fill=255)
img.paste(bg,(0,0),mask)
d=ImageDraw.Draw(img)
cx,cy,R=S//2,S//2-20,330
cols=[(120,180,255),(255,170,200),(255,205,70),(240,130,40)]  # зима, весна, лето, осень
starts=[180,270,0,90]
for c,st in zip(cols,starts):
    d.pieslice([cx-R,cy-R,cx+R,cy+R],st,st+90,fill=c+(255,))
d.ellipse([cx-R,cy-R,cx+R,cy+R],outline=(255,255,255,255),width=14)
d.line([cx-R,cy,cx+R,cy],fill=(255,255,255,255),width=10); d.line([cx,cy-R,cx,cy+R],fill=(255,255,255,255),width=10)
q=R*0.5
# зима (лево-верх): снежинка
wx,wy=cx-q,cy-q
for k in range(6):
    a=k*math.pi/3; x2,y2=wx+math.cos(a)*90,wy+math.sin(a)*90
    d.line([wx,wy,x2,y2],fill=(255,255,255,255),width=16)
    for s in (0.55,):
        bx,by=wx+math.cos(a)*90*s,wy+math.sin(a)*90*s
        for da in (-0.6,0.6):
            d.line([bx,by,bx+math.cos(a+da)*34,by+math.sin(a+da)*34],fill=(255,255,255,255),width=12)
# весна (право-верх): цветок
sx,sy=cx+q,cy-q
for k in range(5):
    a=k*2*math.pi/5-math.pi/2; px,py=sx+math.cos(a)*48,sy+math.sin(a)*48
    d.ellipse([px-42,py-42,px+42,py+42],fill=(255,240,246,255))
d.ellipse([sx-26,sy-26,sx+26,sy+26],fill=(240,90,140,255))
# лето (право-низ): солнце
ux,uy=cx+q,cy+q
for k in range(12):
    a=k*math.pi/6; d.line([ux+math.cos(a)*62,uy+math.sin(a)*62,ux+math.cos(a)*100,uy+math.sin(a)*100],fill=(255,255,255,255),width=14)
d.ellipse([ux-52,uy-52,ux+52,uy+52],fill=(255,255,255,255))
# осень (лево-низ): кленовый лист
ax,ay=cx-q,cy+q
pts=[]
for i in range(20):
    a=-math.pi/2+i*math.pi/10; lobe=i%2==0; r=95 if lobe else 42
    if lobe and i in (8,12): r=62
    if not lobe and i in (9,11): r=30
    pts.append((ax+math.cos(a)*r, ay+math.sin(a)*r*0.95-8))
d.polygon(pts,fill=(255,255,255,255))
d.line([ax,ay+40,ax+8,ay+110],fill=(255,255,255,255),width=12)
# снежный сугроб внизу
hill=Image.new('RGBA',(S,S),(0,0,0,0)); hd=ImageDraw.Draw(hill)
hd.ellipse([-200,S-250,S+200,S+400],fill=(245,248,255,255))
hm=Image.new('L',(S,S),0); ImageDraw.Draw(hm).rounded_rectangle([40,40,S-40,S-40],radius=200,fill=255)
hill.putalpha(Image.composite(hill.getchannel('A'),Image.new('L',(S,S),0),hm))
img.alpha_composite(hill)
# лёгкая тень
sh=Image.new('RGBA',(S,S),(0,0,0,0)); ImageDraw.Draw(sh).rounded_rectangle([40,52,S-40,S-28],radius=200,fill=(0,0,0,90))
sh=sh.filter(ImageFilter.GaussianBlur(14))
out=Image.new('RGBA',(S,S),(0,0,0,0)); out.alpha_composite(sh); out.alpha_composite(img)
out.save('icon_1024.png')
out.save('AppIcon.icns',sizes=[(16,16),(32,32),(64,64),(128,128),(256,256),(512,512),(1024,1024)])
out.resize((256,256)).save('icon_256.png')
print('ok')
