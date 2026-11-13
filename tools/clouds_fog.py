# SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0
# Генератор картинок для SnowDesk. Нужны: pip install numpy pillow opencv-python
# Запуск: python3 clouds_fog.py  →  cloud_0..3.png, fog_band.png
import numpy as np, cv2
from PIL import Image
rng=np.random.default_rng(11)
def cloud(seed,W=1400,H=560,flat=False):
    r=np.random.default_rng(seed)
    a=np.zeros((H,W),np.float32)
    base=H*0.74
    L,R=W*0.14,W*0.86
    # основная масса: перекрывающиеся купола, к краям ниже
    for i in range(int(r.integers(14,22))):
        u=r.uniform(0,1); cx=L+(R-L)*u
        env=np.sin(np.pi*u)**0.8
        rad=(r.uniform(60,120)+150*env*r.uniform(0.6,1.0))*(0.45 if flat else 1)
        cy=base-rad*r.uniform(0.25,0.6)
        cv2.circle(a,(int(cx),int(cy)),int(rad),1.0,-1)
    # мелкие «кочки» по верхнему краю
    edge=cv2.Canny((a*255).astype(np.uint8),50,150)
    ys,xs=np.nonzero(edge[:int(base)-8])
    for k in r.choice(len(xs),min(60,len(xs)),replace=False):
        cv2.circle(a,(int(xs[k]),int(ys[k])),int(r.uniform(18,40)),1.0,-1)
    # мягкое ровное дно
    yy=np.arange(H)[:,None]
    a*=np.clip((base+10-yy)/40,0,1)
    a=cv2.GaussianBlur(a,(0,0),9)
    nz=np.zeros((H,W),np.float32)
    for (cy,cx,amp) in [(8,20,0.6),(20,50,0.4)]:
        g=r.random((cy,cx)).astype(np.float32); nz+=cv2.resize(g,(W,H),interpolation=cv2.INTER_CUBIC)*amp
    nz/=1.0
    a=np.clip(a*(0.85+0.3*nz),0,1)
    a=cv2.GaussianBlur(a,(0,0),2.5)
    # объём: верх освещён, низ и глубина — серо-голубые
    depth=cv2.GaussianBlur(a,(0,0),40)
    vert=np.clip((yy/H-0.2)/0.6,0,1)
    lightv=np.clip(1.05-vert*0.6-depth*0.25+(nz-0.5)*0.12,0,1)
    top=np.array([255,255,255],float); bot=np.array([158,170,192],float)
    col=bot*(1-lightv[...,None])+top*lightv[...,None]
    img=np.dstack([col,a[...,None]*250]).clip(0,255).astype(np.uint8)
    return Image.fromarray(img,'RGBA')
for i in range(4): cloud(200+i,flat=(i==3)).save(f'cloud_{i}.png',optimize=True)
# туман: горизонтальная полоса, бесшовная по X
W,H=1920,520
yy=np.linspace(-1,1,H)[:,None]
band=np.exp(-(yy/0.55)**2)
x=np.linspace(0,2*np.pi,W,endpoint=False)[None,:]
y=np.linspace(0,1,H)[:,None]
n=np.zeros((H,W),np.float32)
for k in range(1,14):
    ph=rng.uniform(0,2*np.pi); fy=rng.uniform(1,6); py=rng.uniform(0,6)
    n+=np.sin(k*x+ph+np.sin(fy*y*np.pi*2+py)*1.2)/k**0.8
n=(n-n.min())/(n.max()-n.min())
a=band*np.clip(n*1.5-0.25,0,1)
p=np.pad(a.astype(np.float32),((0,0),(80,80)),mode='wrap'); a=cv2.GaussianBlur(p,(0,0),12)[:,80:-80]
img=np.dstack([np.full((H,W,3),246),a[...,None]*235]).astype(np.uint8)
Image.fromarray(img,'RGBA').save('fog_band.png',optimize=True)
print('ok')
