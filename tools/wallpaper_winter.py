# SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0
# Генератор картинок для SnowDesk. Нужны: pip install numpy pillow opencv-python
# Запуск: python3 wallpaper_winter.py <папка_вывода> land  →  пейзажи для живых обоев
import numpy as np, math, json, sys, cv2
from PIL import Image, ImageDraw, ImageFilter
W,H=3840,2160
OUT=sys.argv[1]; ONLY=sys.argv[2] if len(sys.argv)>2 else None

def noise2(h,w,cy,cx,seed):
    r=np.random.default_rng(seed); g=r.random((cy+3,cx+3)).astype(np.float32)
    big=cv2.resize(g,(int(w*(cx+3)/cx),int(h*(cy+3)/cy)),interpolation=cv2.INTER_CUBIC)
    return big[:h,:w]
def fbm(h,w,cy,cx,octs,seed,pers=0.5):
    out=np.zeros((h,w),np.float32); a=1; tot=0
    for o in range(octs):
        out+=noise2(h,w,cy*2**o,cx*2**o,seed+o)*a; tot+=a; a*=pers
    return out/tot
def ridge1d(base,amp,seed,cells=6,octs=7,ridged=True):
    r=np.random.default_rng(seed); y=np.zeros(W); a=1
    for o in range(octs):
        n=cells*2**o; pts=r.random(n+3); xs=np.linspace(0,n,W)
        v=np.interp(xs,np.arange(n+3),pts)
        v=cv2.GaussianBlur(v.reshape(1,-1).astype(np.float32),(0,0),max(1,W/n/3)).ravel()
        if ridged and o<3: v=1-np.abs(v*2-1)
        y+=v*a; a*=0.5
    y=(y-y.min())/(y.max()-y.min()); return base-amp*y
def vg(stops,h=H):
    ys=np.linspace(0,1,h); pos=[p for p,_ in stops]; cols=np.array([c for _,c in stops],float)
    return np.stack([np.interp(ys,pos,cols[:,k]) for k in range(3)],1)
def rgba(rgb,alpha): return Image.fromarray(np.dstack([np.clip(rgb,0,255),np.clip(alpha,0,255)]).astype(np.uint8),'RGBA')
def mask_below(top,feather=1.5):
    yy=np.arange(H)[:,None].astype(np.float32); return np.clip((yy-top[None,:])/feather+0.5,0,1)

def mountain(top,P,seed,haze,depth_amp=1.0):
    yy=np.arange(H)[:,None].astype(np.float32)
    below=np.clip(yy-top[None,:],0,None)
    # склоны: наклон гребня определяет освещённую/теневую сторону
    slope=np.gradient(cv2.GaussianBlur(top.reshape(1,-1).astype(np.float32),(0,0),25).ravel())
    side=np.tanh(-slope*1.2)  # >0: склон смотрит влево (к свету)
    side2=cv2.GaussianBlur(side.reshape(1,-1).astype(np.float32),(0,0),40).ravel()
    n=fbm(H,W,14,40,4,seed)              # кулуары и гребни
    dn=np.gradient(n,axis=1)*W/40
    fall=np.exp(-below/(380*depth_amp))
    fall2=np.exp(-below/(700*depth_amp))
    light=0.52+0.48*side2[None,:]*fall2+0.32*dn*fall
    light=np.clip(light,0,1)
    rockn=fbm(H,W,18,60,4,seed+50)
    rock=np.clip((rockn-0.64)*9,0,1)*0.85*np.clip(below/60,0,1)*np.clip(1-light*1.1,0,1)*fall
    lit=np.array(P['lit']); sh=np.array(P['shade']); rk=np.array(P['rock'])
    col=sh[None,None,:]*(1-light[...,None])+lit[None,None,:]*light[...,None]
    col=col*(1-rock[...,None])+rk[None,None,:]*rock[...,None]
    # дымка к низу
    hz=np.clip(below/(520*depth_amp),0,1)**1.3*haze
    col=col*(1-hz[...,None])+np.array(P['haze'])[None,None,:]*hz[...,None]
    a=mask_below(top)*255
    return rgba(col,a)

def tree_poly(x,base,h,r):
    tiers=int(r.integers(9,14)); w=h*r.uniform(0.34,0.42)
    left=[];right=[]
    for i in range(tiers+1):
        f=i/tiers; y=base-h*0.06-f*h*0.94
        ww=w*(1-f)**1.05*0.5
        jag=r.uniform(0.75,1.15)
        left.append((x-ww*jag,y)); left.append((x-ww*0.45,y-h*0.94/tiers*0.55))
        right.append((x+ww*r.uniform(0.75,1.15),y)); right.append((x+ww*0.45,y-h*0.94/tiers*0.55))
    return [(x,base-h)]+left[::-1][1:]+[(x-w*0.03,base),(x+w*0.03,base)]+right[1:]
def tree(d,x,base,h,col,snow,r):
    pts=tree_poly(x,base,h,r)
    d.polygon(pts,fill=col)
    # снежные шапки на концах ветвей
    tiers=len(pts)
    for (px,py) in pts:
        if py>=base-h*0.05: continue
        if r.random()<0.55:
            cw=h*r.uniform(0.018,0.034); chh=cw*0.32
            d.ellipse([px-cw*0.2,py-chh,px+cw*0.9*(1 if px>x else -1)+cw*0.2*(0 if px>x else 2),py+chh*0.3],fill=snow) if False else d.ellipse([min(px,x+(px-x)*0.55)-cw*0.2,py-chh*1.2,max(px,x+(px-x)*0.55)+cw*0.1,py+chh*0.2],fill=snow)
    d.polygon([(x,base-h),(x-h*0.03,base-h*0.9),(x+h*0.02,base-h*0.91)],fill=snow)
def forest(top,n,hmin,hmax,col,snow,seed,xr=(0,W),sink=0.02,var=12):
    r=np.random.default_rng(seed); lay=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(lay)
    for x in np.sort(r.uniform(xr[0],xr[1],n)):
        xi=int(np.clip(x,0,W-1)); h=r.uniform(hmin,hmax)
        c=tuple(int(np.clip(v+r.integers(-var,var),0,255)) for v in col)+(255,)
        tree(d,x,top[xi]+h*sink+r.uniform(0,8),h,c,snow+(255,),r)
    return lay
def snowfield(top,P,seed,light_dir=1):
    yy=np.arange(H)[:,None].astype(np.float32); below=np.clip(yy-top[None,:],0,None)
    n=fbm(H,W,5,9,3,seed,0.45); n=cv2.GaussianBlur(n,(0,0),6); dn=np.gradient(n,axis=1)*W/9*light_dir+np.gradient(n,axis=0)*H/5*0.5
    v=np.clip(0.6+dn*0.55,0,1)
    base=vg(P['field'])[:,None,:]
    sh=np.array(P['fshade'])
    col=base*(1-0.45*(1-v[...,None]))+sh*0.45*(1-v[...,None])
    a=mask_below(top)*255
    return rgba(col,a)
def fog(y0,y1,P,seed,strength):
    yy=np.arange(H)[:,None].astype(np.float32)
    band=np.exp(-((yy-(y0+y1)/2)/((y1-y0)/2))**2)
    n=fbm(H,W,4,18,4,seed)
    a=band*np.clip(n*1.6-0.3,0,1)*strength*255
    return rgba(np.broadcast_to(np.array(P['fog']),(H,W,3)),np.broadcast_to(a,(H,W)))

PAL={
 'night':dict(lit=(150,165,215),shade=(62,74,128),rock=(38,42,66),haze=(88,92,140),
   lit2=(132,146,200),shade2=(50,60,108),rock2=(30,34,56),haze2=(70,76,122),
   far=(26,36,64),farsnow=(120,135,180),mid=(16,26,46),midsnow=(160,175,215),near=(8,14,26),nearsnow=(190,202,236),
   field=[(0,(170,182,225)),(0.85,(186,198,238)),(1,(160,174,222))],fshade=(70,85,140),fog=(120,130,175)),
 'day':dict(lit=(250,252,255),shade=(150,172,212),rock=(84,90,104),haze=(205,218,238),
   lit2=(244,248,255),shade2=(132,156,200),rock2=(70,78,94),haze2=(190,205,230),
   far=(40,70,64),farsnow=(232,238,248),mid=(28,56,46),midsnow=(244,247,252),near=(18,40,32),nearsnow=(250,252,255),
   field=[(0,(236,242,252)),(0.85,(246,249,255)),(1,(222,232,248))],fshade=(150,172,215),fog=(235,240,250)),
}
m1=ridge1d(H*0.60,560,3); m2=ridge1d(H*0.69,330,8)
hill1=ridge1d(H*0.745,70,21,cells=4,octs=5,ridged=False); hill2=ridge1d(H*0.80,90,33,cells=3,octs=5,ridged=False)
fg=ridge1d(H*0.905,110,51,cells=2,octs=4,ridged=False)
cx=1480; cb=int(hill2[cx])+14

def cabin(lay):
    d=ImageDraw.Draw(lay)
    L,R,T=cx-160,cx+160,cb-175
    # брёвна с объёмом
    for k,yb in enumerate(range(T,cb,20)):
        for j in range(20):
            sh=int(70+45*math.sin(math.pi*j/20)); d.line([L,yb+j,R,yb+j],fill=(sh,int(sh*0.58),int(sh*0.38),255))
        d.ellipse([L-10,yb,L+8,yb+19],fill=(150,105,70,255)); d.ellipse([L-6,yb+4,L+4,yb+15],fill=(120,80,50,255))
        d.ellipse([R-8,yb,R+10,yb+19],fill=(150,105,70,255)); d.ellipse([R-4,yb+4,R+6,yb+15],fill=(120,80,50,255))
    # каменная труба
    for yy in range(cb-330,cb-180,14):
        for xx in range(cx+58,cx+106,16):
            g=int(np.random.default_rng(xx*7+yy).integers(80,120)); d.rounded_rectangle([xx,yy,xx+15,yy+13],radius=3,fill=(g,g-6,g-12,255))
    # крыша
    d.polygon([(cx-200,T+8),(cx+200,T+8),(cx,T-150)],fill=(52,34,26,255))
    # толстый снег на крыше
    d.polygon([(cx-215,T+6),(cx-200,T-8),(cx,T-170),(cx+200,T-8),(cx+215,T+6),(cx+200,T+14),(cx,T-140),(cx-200,T+14)],fill=(240,244,255,255))
    for k in range(-210,215,30): d.ellipse([cx+k-16,T+2,cx+k+16,T+20],fill=(236,241,254,255))
    d.rounded_rectangle([cx+54,cb-345,cx+110,cb-326],radius=8,fill=(240,244,255,255))
    # сосульки
    r=np.random.default_rng(9)
    for k in range(-195,200,14):
        ln=r.uniform(8,34); d.polygon([(cx+k-3,T+16),(cx+k+3,T+16),(cx+k,T+16+ln)],fill=(215,232,250,255))
    # окна (тёмные) и дверь
    for (a,b,c,e) in WIN: d.rectangle([a-8,b-8,c+8,e+8],fill=(90,60,40,255)); d.rectangle([a,b,c,e],fill=(30,34,52,255))
    d.rectangle([cx-30,cb-125,cx+28,cb],fill=(58,36,24,255)); d.rectangle([cx-24,cb-118,cx+22,cb],fill=(70,44,30,255))
    for (a,b,c,e) in WIN:
        d.line([(a+c)/2,b,(a+c)/2,e],fill=(90,60,40,255),width=6); d.line([a,(b+e)/2,c,(b+e)/2],fill=(90,60,40,255),width=6)
        d.rectangle([a-10,e+6,c+10,e+16],fill=(240,244,255,255))  # снег на подоконнике
    # фонарь у двери
    d.rectangle([cx+36,cb-112,cx+46,cb-92],fill=(40,30,22,255))
    # поленница
    for row in range(3):
        for k in range(6):
            px=cx-250+k*14+(row%2)*7; py=cb-14-row*13; d.ellipse([px,py,px+14,py+13],fill=(140,95,60,255)); d.ellipse([px+4,py+4,px+10,py+9],fill=(110,72,44,255))
    d.rounded_rectangle([cx-256,cb-56,cx-160,cb-42],radius=6,fill=(240,244,255,255))
WIN=[(cx-120,cb-135,cx-50,cb-65),(cx+50,cb-135,cx+120,cb-65)]

def landscape(P,name):
    img=Image.new('RGBA',(W,H),(0,0,0,0))
    img.alpha_composite(mountain(m1,dict(lit=P['lit'],shade=P['shade'],rock=P['rock'],haze=P['haze']),3,0.85,1.2))
    img.alpha_composite(fog(H*0.60,H*0.70,P,7,0.55))
    img.alpha_composite(mountain(m2,dict(lit=P['lit2'],shade=P['shade2'],rock=P['rock2'],haze=P['haze2']),8,0.6,0.8))
    img.alpha_composite(fog(H*0.68,H*0.76,P,9,0.5))
    img.alpha_composite(forest(hill1,520,40,95,P['far'],P['farsnow'],5,var=8))
    img.alpha_composite(snowfield(hill1,P,21))
    img.alpha_composite(fog(H*0.74,H*0.80,P,11,0.35))
    img.alpha_composite(forest(hill2,90,150,330,P['mid'],P['midsnow'],9,xr=(0,1080)))
    img.alpha_composite(forest(hill2,80,150,310,P['mid'],P['midsnow'],10,xr=(1880,W)))
    cl=Image.new('RGBA',(W,H),(0,0,0,0)); cabin(cl)
    if name=='day': pass
    else:
        a=np.asarray(cl).astype(np.float32); a[...,:3]*=np.array([0.55,0.6,0.85]); cl=Image.fromarray(a.astype(np.uint8),'RGBA')
    img.alpha_composite(cl)
    img.alpha_composite(snowfield(hill2,P,33))
    # тропинка к дому
    tp=Image.new('RGBA',(W,H),(0,0,0,0)); td=ImageDraw.Draw(tp)
    pts=[(cx+5+math.sin(i/9)*60+i*6, cb+i*3.2) for i in range(0,130)]
    for i,(px,py) in enumerate(pts):
        w=10+i*0.55; td.ellipse([px-w,py-w*0.25,px+w,py+w*0.25],fill=P['fshade']+(45,))
    img.alpha_composite(tp.filter(ImageFilter.GaussianBlur(6)))
    img.alpha_composite(forest(fg,7,720,1050,P['near'],P['nearsnow'],77,xr=(-160,520),sink=0.05))
    img.alpha_composite(forest(fg,6,680,1000,P['near'],P['nearsnow'],78,xr=(3380,W+160),sink=0.05))
    img.alpha_composite(snowfield(fg,P,51,light_dir=1))
    rng=np.random.default_rng(4); sp=Image.new('RGBA',(W,H),(0,0,0,0)); spd=ImageDraw.Draw(sp)
    for _ in range(3500):
        x=int(rng.integers(0,W)); top=hill2[x] if rng.random()<0.4 else fg[x]
        y=rng.uniform(top+6,H); spd.point((x,y),fill=(255,255,255,int(rng.uniform(90,255))))
    img.alpha_composite(sp)
    return img

if ONLY in (None,'land'):
    for name in ('night','day'):
        landscape(PAL[name],name).save(f'{OUT}/landscape_{name}.png',optimize=True); print(name)

if ONLY in (None,'glow'):
    gl=Image.new('RGBA',(W,H),(0,0,0,0)); gd=ImageDraw.Draw(gl)
    for (a,b_,c,d_) in WIN: gd.ellipse([a-130,b_-100,c+130,d_+110],fill=(255,170,70,140))
    gd.ellipse([cx-460,cb-30,cx+460,cb+140],fill=(255,170,80,75))
    gd.ellipse([cx-10,cb-150,cx+90,cb-50],fill=(255,190,100,170))
    gl=gl.filter(ImageFilter.GaussianBlur(55))
    wd=ImageDraw.Draw(gl)
    for (a,b_,c,d_) in WIN:
        for yy in range(b_,d_):
            f=(yy-b_)/(d_-b_); wd.line([a,yy,c,yy],fill=(255,int(205-40*f),int(120-40*f),255))
        wd.line([(a+c)/2,b_,(a+c)/2,d_],fill=(90,60,40,255),width=6); wd.line([a,(b_+d_)/2,c,(b_+d_)/2],fill=(90,60,40,255),width=6)
        wd.rectangle([a+8,b_+6,a+22,d_-6],fill=(150,40,30,255)); wd.rectangle([c-22,b_+6,c-8,d_-6],fill=(150,40,30,255))  # шторки
    wd.rectangle([cx+37,cb-110,cx+45,cb-95],fill=(255,220,140,255))
    gl.save(f'{OUT}/windows_glow.png',optimize=True)
json.dump({'chimney':[(cx+82)/W,(cb-345)/H],'horizon':0.62},open(f'{OUT}/scene.json','w'))
print('ok')
