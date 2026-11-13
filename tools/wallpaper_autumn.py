# SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0
# Генератор картинок для SnowDesk. Нужны: pip install numpy pillow opencv-python
# Запуск: python3 wallpaper_autumn.py <папка_вывода> land  →  пейзажи для живых обоев
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

def mountain_autumn(top,P,seed,depth_amp=1.0,snowline=0,forest=0.0):
    # осенние горы: камень и бурые склоны, снег только на самых вершинах
    yy=np.arange(H)[:,None].astype(np.float32)
    below=np.clip(yy-top[None,:],0,None)
    slope=np.gradient(cv2.GaussianBlur(top.reshape(1,-1).astype(np.float32),(0,0),25).ravel())
    side=cv2.GaussianBlur(np.tanh(-slope*1.2).reshape(1,-1).astype(np.float32),(0,0),40).ravel()
    n=fbm(H,W,14,40,4,seed); dn=np.gradient(n,axis=1)*W/40
    fall=np.exp(-below/(380*depth_amp)); fall2=np.exp(-below/(700*depth_amp))
    light=np.clip(0.5+0.45*side[None,:]*fall2+0.35*dn*fall,0,1)[...,None]
    rl=np.array(P['rlit'],float); rs=np.array(P['rshade'],float)
    col=rs*(1-light)+rl*light
    if forest>0:
        # пёстрые осенние леса на склонах
        fn=fbm(H,W,30,90,4,seed+7)
        pal=np.array(P['fcols'],float)
        idx=np.clip((fbm(H,W,20,70,3,seed+9)*len(pal)*1.6-0.3*len(pal)).astype(int),0,len(pal)-1)
        fc=pal[idx]*(0.55+0.55*light)
        amt=np.clip((fn-0.42)*5,0,1)[...,None]*np.clip(below/90,0,1)[...,None]*forest
        col=col*(1-amt)+fc*amt
    if snowline>0:
        sn=fbm(H,W,16,50,4,seed+3)
        cap=np.clip((snowline*(0.6+0.8*sn)-below)/25,0,1)[...,None]
        cap*=np.clip(0.4+light*0.9,0,1)
        snow=np.array(P['slit'],float)*light+np.array(P['sshade'],float)*(1-light)
        col=col*(1-cap)+snow*cap
    hz=(np.clip(below/(520*depth_amp),0,1)**1.3*0.7)[...,None]
    col=col*(1-hz)+np.array(P['haze'],float)*hz
    return rgba(col,mask_below(top)*255)
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
def deciduous(top,n,hmin,hmax,seed,dark=1.0,xr=(0,W),sink=0.02):
    r=np.random.default_rng(seed); lay=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(lay)
    cols=[(222,120,30),(240,170,40),(196,64,30),(230,140,50),(170,90,30),(214,190,70)]
    for x in np.sort(r.uniform(xr[0],xr[1],n)):
        xi=int(np.clip(x,0,W-1)); h=r.uniform(hmin,hmax); base=top[xi]+h*sink+r.uniform(0,6)
        tw=h*0.05; d.polygon([(x-tw,base),(x+tw,base),(x+tw*0.5,base-h*0.55),(x-tw*0.5,base-h*0.55)],fill=tuple(int(v*dark) for v in (60,40,28))+(255,))
        c=cols[int(r.integers(0,len(cols)))]
        cy=base-h*0.62; rw=h*r.uniform(0.28,0.36); rh=h*0.32
        for k in range(int(r.integers(7,12))):
            a=r.uniform(0,2*math.pi); dd=math.sqrt(r.uniform(0,1))
            px=x+math.cos(a)*rw*0.7*dd; py=cy+math.sin(a)*rh*0.7*dd; rr=h*r.uniform(0.13,0.2)
            shade=0.78+0.3*(1-(py-(cy-rh))/(2*rh))
            tint=(1,1,1) if dark>=1 else (0.6,0.66,0.95)
            cc=tuple(int(np.clip(v*shade*dark*tt+r.integers(-6,6)*dark,0,255)) for v,tt in zip(c,tint))+(255,)
            d.ellipse([px-rr,py-rr*0.9,px+rr,py+rr*0.9],fill=cc)
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
 'night':dict(rlit=(78,80,104),rshade=(38,42,64),fcols=[(80,56,50),(70,62,48),(52,58,52),(84,50,40)],lit=(118,124,160),shade=(52,58,96),rock=(36,38,58),haze=(80,82,118),
   lit2=(62,64,84),shade2=(34,38,58),rock2=(30,32,50),haze2=(62,64,96),
   far=(26,30,40),farsnow=(30,34,46),mid=(18,22,30),midsnow=(22,26,36),near=(10,12,18),nearsnow=(14,16,24),
   field=[(0,(62,58,66)),(0.85,(70,64,70)),(1,(56,50,58))],fshade=(32,30,44),fog=(96,100,130)),
 'day':dict(rlit=(168,150,132),rshade=(92,92,104),fcols=[(196,110,40),(214,160,52),(150,70,34),(98,110,58),(176,132,60)],lit=(236,238,244),shade=(140,150,172),rock=(92,90,96),haze=(200,204,212),
   lit2=(150,128,92),shade2=(84,82,74),rock2=(78,74,72),haze2=(188,190,192),
   far=(58,72,44),farsnow=(70,86,52),mid=(34,52,32),midsnow=(44,64,38),near=(22,36,22),nearsnow=(30,46,28),
   field=[(0,(176,146,78)),(0.85,(190,158,86)),(1,(150,118,62))],fshade=(104,82,44),fog=(226,220,208)),
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
    if False:
     # снега на крыше осенью нет
      pass
    # черепица крыши
    for k,yy in enumerate(range(int(T-140),int(T+8),16)):
        f=(yy-(T-150))/158; half=200*f
        d.line([cx-half,yy,cx+half,yy],fill=(36,22,16,255),width=2)
    d.rounded_rectangle([cx+54,cb-338,cx+110,cb-326],radius=4,fill=(70,62,58,255))
    # окна (тёмные) и дверь
    for (a,b,c,e) in WIN: d.rectangle([a-8,b-8,c+8,e+8],fill=(90,60,40,255)); d.rectangle([a,b,c,e],fill=(30,34,52,255))
    d.rectangle([cx-30,cb-125,cx+28,cb],fill=(58,36,24,255)); d.rectangle([cx-24,cb-118,cx+22,cb],fill=(70,44,30,255))
    for (a,b,c,e) in WIN:
        d.line([(a+c)/2,b,(a+c)/2,e],fill=(90,60,40,255),width=6); d.line([a,(b+e)/2,c,(b+e)/2],fill=(90,60,40,255),width=6)
        d.rectangle([a-10,e+6,c+10,e+16],fill=(110,74,46,255))  # деревянный подоконник
        for q in range(4): d.ellipse([a-6+q*((c-a+12)/4),e-6,a+10+q*((c-a+12)/4),e+8],fill=((200,60,40,255),(230,160,40,255))[q%2])  # цветы в ящике
    # фонарь у двери
    d.rectangle([cx+36,cb-112,cx+46,cb-92],fill=(40,30,22,255))
    # поленница
    for row in range(3):
        for k in range(6):
            px=cx-250+k*14+(row%2)*7; py=cb-14-row*13; d.ellipse([px,py,px+14,py+13],fill=(140,95,60,255)); d.ellipse([px+4,py+4,px+10,py+9],fill=(110,72,44,255))
    # тыквы у крыльца
    for (px,pr) in ((cx-120,24),(cx-82,17),(cx+70,20)):
        for k in (-1,0,1): d.ellipse([px-pr*0.55+k*pr*0.42,cb-pr*1.7,px+pr*0.55+k*pr*0.42,cb],fill=((214,110,20,255),(236,130,28,255),(200,96,16,255))[k+1])
        d.rectangle([px-3,cb-pr*1.9,px+3,cb-pr*1.6],fill=(70,80,30,255))
WIN=[(cx-120,cb-135,cx-50,cb-65),(cx+50,cb-135,cx+120,cb-65)]

def landscape(P,name):
    img=Image.new('RGBA',(W,H),(0,0,0,0))
    img.alpha_composite(mountain_autumn(m1,dict(rlit=P['rlit'],rshade=P['rshade'],slit=P['lit'],sshade=P['shade'],haze=P['haze'],fcols=P['fcols']),3,1.2,snowline=120,forest=0.35))
    img.alpha_composite(fog(H*0.60,H*0.70,P,7,0.55))
    img.alpha_composite(mountain_autumn(m2,dict(rlit=P['lit2'],rshade=P['shade2'],slit=P['lit2'],sshade=P['shade2'],haze=P['haze2'],fcols=P['fcols']),8,0.8,forest=0.85))
    img.alpha_composite(fog(H*0.68,H*0.76,P,9,0.5))
    dk=1.0 if name=='day' else 0.26
    img.alpha_composite(forest(hill1,380,40,95,P['far'],P['farsnow'],5,var=8))
    img.alpha_composite(deciduous(hill1,300,35,80,105,dk))
    img.alpha_composite(snowfield(hill1,P,21))
    img.alpha_composite(fog(H*0.74,H*0.80,P,11,0.35))
    img.alpha_composite(forest(hill2,90,150,330,P['mid'],P['midsnow'],9,xr=(0,1080)))
    img.alpha_composite(forest(hill2,80,150,310,P['mid'],P['midsnow'],10,xr=(1880,W)))
    img.alpha_composite(deciduous(hill2,26,130,260,110,dk,xr=(0,1100)))
    img.alpha_composite(deciduous(hill2,24,130,250,111,dk,xr=(1860,W)))
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
    img.alpha_composite(deciduous(fg,3,520,700,120,dk,xr=(380,640),sink=0.05))
    img.alpha_composite(deciduous(fg,3,500,680,121,dk,xr=(3200,3460),sink=0.05))
    img.alpha_composite(snowfield(fg,P,51,light_dir=1))
    rng=np.random.default_rng(4); sp=Image.new('RGBA',(W,H),(0,0,0,0)); spd=ImageDraw.Draw(sp)
    for _ in range(9000):
        x=int(rng.integers(0,W)); top=hill2[x] if rng.random()<0.4 else fg[x]
        y=rng.uniform(top+6,H); c=((214,96,26),(232,150,40),(176,52,24),(150,92,40))[int(rng.integers(0,4))]
        c=tuple(int(v*dk) for v in c)
        s=rng.uniform(2,6) if top is fg else rng.uniform(1,3)
        spd.ellipse([x-s,y-s*0.6,x+s,y+s*0.6],fill=c+(int(rng.uniform(150,255)),))
    img.alpha_composite(sp)
    return img

if ONLY in (None,'land'):
    for name in ('night','day'):
        landscape(PAL[name],name).save(f'{OUT}/landscape_{name}_autumn.png',optimize=True); print(name)

if ONLY == 'glow':
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
if ONLY == 'glow': json.dump({'chimney':[(cx+82)/W,(cb-345)/H],'horizon':0.62},open(f'{OUT}/scene.json','w'))
print('ok')
