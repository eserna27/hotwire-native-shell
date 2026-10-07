# Builds panoramas per language/format, a contact sheet, and verifies every size.
import sys, glob, os
from PIL import Image, ImageDraw, ImageFont
R=sys.argv[1]; BG='#0b0f1c'
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
EXPECT={'appstore-6.9_1320x2868':(1320,2868),'appstore-ipad-13_2064x2752':(2064,2752),'googleplay_1080x1920':(1080,1920)}
def rounded(im,r):
    m=Image.new('L',im.size,0); ImageDraw.Draw(m).rounded_rectangle((0,0,im.width-1,im.height-1),radius=r,fill=255); return m
def panorama(files,out,sw,gap=18,margin=36):
    ims=[Image.open(f).convert('RGB') for f in files]; sh=round(sw*ims[0].height/ims[0].width)
    p=Image.new('RGB',(2*margin+len(ims)*sw+(len(ims)-1)*gap,2*margin+sh),BG)
    for i,im in enumerate(ims):
        t=im.resize((sw,sh),Image.LANCZOS); p.paste(t,(margin+i*(sw+gap),margin),rounded(t,int(sw*.07)))
    p.save(out); return p.size
ok=True
for lang in ('es','en'):
    for sub,size in EXPECT.items():
        fs=sorted(glob.glob(f'{R}/{lang}/{sub}/*.png'))
        for f in fs:
            s=Image.open(f).size
            if s!=size: ok=False; print('SIZE MISMATCH',f,s)
        print(f'{lang}/{sub}: {len(fs)} files, all {size[0]}x{size[1]}' if all(Image.open(f).size==size for f in fs) else '')
    fg=f'{R}/{lang}/googleplay_feature-graphic_1024x500.png'; print(lang,'feature',Image.open(fg).size); ok&=Image.open(fg).size==(1024,500)
    print(lang,'panorama appstore',panorama(sorted(glob.glob(f'{R}/{lang}/appstore-6.9_1320x2868/*.png')),f'{R}/{lang}/panorama_appstore.png',380))
    print(lang,'panorama ipad',panorama(sorted(glob.glob(f'{R}/{lang}/appstore-ipad-13_2064x2752/*.png')),f'{R}/{lang}/panorama_appstore-ipad.png',380))
    print(lang,'panorama play',panorama(sorted(glob.glob(f'{R}/{lang}/googleplay_1080x1920/*.png')),f'{R}/{lang}/panorama_googleplay.png',380))
# contact sheet: for each language a row of App Store slides, a row of Play slides + feature graphic
f=ImageFont.truetype(FONT,26); fs=ImageFont.truetype(FONT,18)
tw=200; th=round(tw*2868/1320); pw=200; phh=round(pw*1920/1080); iw=200; ih=round(iw*2752/2064); pad=30; lab=44
W=pad+6*(tw+pad)+(520+pad)
H=pad
rows=[]
for lang in ('es','en'):
    rows.append(('label',f'{lang.upper()} · App Store 6.9" (1320x2868)')); rows.append(('ios',lang))
    rows.append(('label',f'{lang.upper()} · App Store iPad 13" (2064x2752)')); rows.append(('ipad',lang))
    rows.append(('label',f'{lang.upper()} · Google Play (1080x1920) + feature graphic (1024x500)')); rows.append(('play',lang))
DIM={'ios':(tw,th,'appstore-6.9_1320x2868'),'ipad':(iw,ih,'appstore-ipad-13_2064x2752'),'play':(pw,phh,'googleplay_1080x1920')}
for k,_ in rows: H+= lab if k=='label' else DIM[k][1]+pad
sheet=Image.new('RGB',(W,H),'#e9e6df'); d=ImageDraw.Draw(sheet); y=pad
for k,v in rows:
    if k=='label': d.text((pad,y+8),v,fill='#0F172A',font=f); y+=lab; continue
    w,h,sub=DIM[k]
    for i,fn in enumerate(sorted(glob.glob(f'{R}/{v}/{sub}/*.png'))):
        im=Image.open(fn).convert('RGB').resize((w,h),Image.LANCZOS); x=pad+i*(w+pad); sheet.paste(im,(x,y))
        d.text((x,y+h+2),os.path.basename(fn),fill='#334155',font=fs)
    if k=='play':
        fg=Image.open(f'{R}/{v}/googleplay_feature-graphic_1024x500.png').convert('RGB').resize((520,254),Image.LANCZOS)
        sheet.paste(fg,(pad+6*(pw+pad),y))
    y+=h+pad
sheet.save(f'{R}/contact-sheet.png'); print('contact sheet',sheet.size); print('ALL SIZES OK' if ok else 'SIZE PROBLEMS')
