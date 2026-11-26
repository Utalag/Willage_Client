# DOČASNÝ NÁHLED – arch dlaždic Gemini a variací (PIL, offline příprava obrázku do reportu)
from PIL import Image, ImageDraw, ImageFont
F=lambda s: ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', s)
Z='/workspace/willage-ideas/mat-t2/godot-prototyp/data/vpmg/zaklady'; G='/workspace/willage-ideas/gemini'; V='/workspace/willage-ideas/snimky-t2c'
mats=[(1,'grass','Tráva'),(2,'topsoil','Ornice'),(3,'gravel_sand','Štěrk/písek'),(5,'cave_limestone','Vápenec'),(6,'granite','Žula')]
seeds=[3238005999,3238013918,3238021837,3238029756]
C=512; pad=24; lab=300; top=250
cols=['originál Gemini\n1024 → zmenšeno','dlaždice 128 (bez švů)\n2×2, 2× nejbližší']+[f'variace seed {s}\nv2 bez palette_map' for s in seeds]+['v2 Dev beze změny\n(palette_map přemaže)','procedurální v1\n(Dev 42e7475, bez dlaždice)']
W=lab+len(cols)*(C+pad)+pad; H=top+len(mats)*(C+pad)+30
im=Image.new('RGB',(W,H),(30,30,36)); d=ImageDraw.Draw(im)
d.text((pad,20),'DOČASNÝ NÁHLED – není operace klienta ani schválený výstup Dev: dlaždice Gemini → tools/priprava_dlazdic.py → Dev 04ed4d9 base_texture + modifikátory',font=F(34),fill=(255,210,120))
d.text((pad,68),'baseTile vloženy jen do dočasné kopie katalogu (v katalogu Dev zatím nejsou); klient zůstává na pinu 42e7475. Variace: receptury v2 bez kroku palette_map (base_texture + smooth_noise [+ grass_tufts]), 128 px.',font=F(28),fill=(220,220,220))
def x2(p):
    t=Image.open(p).convert('RGB'); n=t.size[0]; two=Image.new('RGB',(2*n,2*n))
    for a in (0,n):
        for b in (0,n): two.paste(t,(a,b))
    return two.resize((C,C),Image.NEAREST)
for i,c in enumerate(cols): d.multiline_text((lab+i*(C+pad),130),c,font=F(26),fill=(180,200,255))
for r,(mid,key,naz) in enumerate(mats):
    y=top+r*(C+pad)
    d.multiline_text((pad,y+C//2-40),f'{mid} {key}\n{naz}',font=F(32),fill=(230,230,230))
    cells=[Image.open(f'{G}/zaklad-{mid}-{key}.jpg').convert('RGB').resize((C,C),Image.LANCZOS), x2(f'{Z}/{mid}-{key}-v1.png')]
    cells+=[x2(f'out-bez-pm/{mid}-{key}-s{i}.png') for i in range(1,5)]+[x2(f'out/{mid}-{key}-s1.png')]
    v=Image.open(f'{V}/textura-v1-{mid}-{key}.png').convert('RGB'); cells.append(v.resize((C,C),Image.NEAREST))
    for i,c in enumerate(cells): im.paste(c,(lab+i*(C+pad),y))
im.save(f'{V}/20-zaklady-variace.png',optimize=True); print(im.size)
im.resize((W//4,H//4)).save('/tmp/a20.png')
