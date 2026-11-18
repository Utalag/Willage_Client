#!/usr/bin/env python3
"""Vygeneruje data/poradi_hornin.json, data/mineraly_hostitele.json a ../sdilene/horniny_voda.json
z Gemini pořadí hornin 0–63 (inspirace/gemini-kura-64.md) – jednorázový nástroj, výstup se ručně ladí v JSON."""
import json, colorsys, os
D = os.path.dirname(os.path.abspath(__file__)) + "/.."
# idx, klíč, název, druh, aktivní, výskyt, existující id (nebo None)
# druh: layer | pipe | vein | contact | dome | seam | soil | mountain | snow | air
R = [
 (0,"peridotite","Peridotit / dunit","layer",1,1.0,None),
 (1,"kimberlite","Kimberlit (komíny)","pipe",1,0.35,None),
 (2,"lherzolite","Lherzolit, olivín","layer",0,0.5,None),
 (3,"eclogite","Eklogit","layer",0,0.3,None),
 (4,"pyroxenite","Pyroxenit","layer",0,0.4,None),
 (5,"serpentinite","Serpentinit (hadec)","layer",0,0.4,None),
 (6,"gabbro","Gabro","layer",1,0.6,None),
 (7,"norite","Norit / anortozit","layer",0,0.4,None),
 (8,"fe_ti_zone","Fe-Ti rudní zóna (magnetit)","layer",1,0.3,None),
 (9,"diabase","Diabaz (= čedič gen-v3)","layer",1,0.7,7),
 (10,"granulite","Granulit","layer",0,0.5,None),
 (11,"amphibolite","Amfibolit","layer",1,0.6,None),
 (12,"lower_gneiss","Spodní přechodová břidlice / rula","layer",0,0.6,None),
 (13,"migmatite","Migmatit","layer",0,0.5,None),
 (14,"orthogneiss","Ortorula","layer",1,0.8,None),
 (15,"biotite_gneiss","Biotitická rula","layer",0,0.6,None),
 (16,"two_mica_gneiss","Dvojslídná rula","layer",0,0.5,None),
 (17,"granodiorite","Granodiorit","layer",1,0.5,None),
 (18,"granite","Masivní žula (= žula gen-v3)","layer",1,0.8,6),
 (19,"leucogranite","Světlá granitoidní žula","layer",0,0.4,None),
 (20,"pegmatite","Pegmatitové žíly","vein",1,0.5,None),
 (21,"quartzite","Krystalický kvarcit","layer",0,0.4,None),
 (22,"mica_schist","Svor (granáty, slídy)","layer",1,0.5,None),
 (23,"phyllite","Fylit","layer",0,0.5,None),
 (24,"skarn","Skarn (kontakt)","contact",1,1.0,None),
 (25,"crystalline_transition","Přechodová zóna krystalinika","layer",0,0.5,None),
 (26,"deep_limestone","Hlubinný vápenec / křída","layer",1,0.5,None),
 (27,"siltstone","Prachovec","layer",0,0.5,None),
 (28,"conglomerate","Slepenec","layer",0,0.4,None),
 (29,"rock_salt","Kamenná sůl (dómy)","dome",1,0.3,None),
 (30,"gypsum","Sádrovec, anhydrit","layer",0,0.3,None),
 (31,"dolomite","Dolomit","layer",1,0.4,None),
 (32,"cave_limestone","Masivní jeskynní vápenec (= vápenec gen-v3)","layer",1,0.6,5),
 (33,"black_coal","Černé uhlí (sloj)","seam",1,0.5,None),
 (34,"shale","Jílová břidlice","layer",1,0.7,None),
 (35,"quartz_sandstone","Křemenný pískovec","layer",1,0.6,None),
 (36,"lignite","Hnědé uhlí / lignit","seam",1,0.5,None),
 (37,"weathered_clay","Zvětralá břidlice a jíly (= jíl gen-v3)","layer",1,0.7,4),
 (38,"gravel_sand","Štěrk, hlinitopísčité sedimenty (= písek gen-v3)","layer",1,0.5,3),
 (39,"loess","Spraš a zvětraliny","layer",1,0.6,None),
 (40,"topsoil","Ornice, humus (= hlína gen-v3, tráva navrchu)","soil",1,1.0,2),
 (41,"hill_sand","Písčité podloží pahorků","mountain",1,1.0,None),
 (42,"limestone_outcrop","Vápencové výchozy","mountain",1,0.6,None),
 (43,"weathered_volcanic","Zvětralé vyvřeliny","mountain",1,1.0,None),
 (44,"flysch","Lesní půdy, flyš","mountain",1,1.0,None),
 (45,"sandstone_towers","Pískovcové věže a stěny","mountain",0,0.5,None),
 (46,"weathered_granite","Zvětralá žula vysočin","mountain",1,1.0,None),
 (47,"mountain_ridge","Horské hřebeny (Šumava/Krkonoše)","mountain",0,0.6,None),
 (48,"slope_schist","Krystalické břidlice svahů","mountain",0,0.6,None),
 (49,"granite_massif","Žulové masivy hřbetů","mountain",1,1.0,None),
 (50,"rock_wall","Strmé skalní stěny","mountain",1,1.0,None),
 (51,"alpine_crystalline","Vysokohorské krystalinikum","mountain",0,0.6,None),
 (52,"subalpine_scree","Subalpínské pásmo (skály, sutě)","mountain",1,1.0,None),
 (53,"alpine_belt","Alpínský stupeň","mountain",0,0.6,None),
 (54,"alpine_granite","Vysokohorský granit","mountain",1,1.0,None),
 (55,"alpine_quartzite","Vysokohorské kvarcity a břidlice","mountain",0,0.6,None),
 (56,"extreme_ridge","Extrémní hřebeny","mountain",1,1.0,None),
 (57,"eternal_snow","Věčný sníh a led (= sníh gen-v3)","snow",1,1.0,10),
 (58,"high_massif","Velehorský masiv","mountain",0,0.6,None),
 (59,"rock_spire","Skalní věže","mountain",0,0.5,None),
 (60,"summit_pyramid","Vrcholové pyramidy","mountain",0,0.5,None),
 (61,"highest_point","Nejvyšší bod (skála, led)","mountain",0,0.5,None),
 (62,"cloud_line","Hranice mraků (vzduch)","air",1,1.0,0),
 (63,"map_ceiling","Strop mapy, vzduch","air",1,1.0,0),
]
# MIMO pořadí 0–63 (Janova skica tvarů vrstev, 16:34): sopouch sopky = svislý kanál vulkanické horniny od dna ke kráteru
EXTRA = [(64,"volcanic_conduit","Sopouch (vulkanický kanál)","vent",1,1.0,None)]
def zone(i):
    if i >= 64: return "telesa"
    return "plast" if i<=12 else "krystalinikum" if i<=25 else "sedimenty" if i<=39 else "povrch" if i==40 else "hory" if i<=61 else "vzduch"
ZONE_HUE = {"plast":(0.20,0.45),"krystalinikum":(0.78,1.02),"sedimenty":(0.06,0.17),"povrch":(0.08,0.09),"telesa":(0.99,1.0),"hory":(0.06,0.14),"vzduch":(0.55,0.56)}
# hory: typy blueprintu a relativní výška (z − 40) / 21
MOUNT = {"hill_sand":(["kopec","svah"],[0.0,0.25]),"limestone_outcrop":(["kopec","svah"],[0.25,0.45]),"weathered_volcanic":(["sopka"],[-1.0,2.0]),
 "flysch":(["kopec","svah"],[0.45,0.7]),"sandstone_towers":(["kopec"],[0.5,0.8]),"weathered_granite":(["kopec","svah","hora"],[0.7,1.0]),
 "mountain_ridge":(["hora"],[0.3,0.45]),"slope_schist":(["hora"],[0.0,0.3]),"granite_massif":(["hora"],[0.0,0.35]),"rock_wall":(["hora"],[0.35,0.55]),
 "alpine_crystalline":(["hora"],[0.45,0.6]),"subalpine_scree":(["hora"],[0.55,0.7]),"alpine_belt":(["hora"],[0.6,0.7]),"alpine_granite":(["hora"],[0.7,0.82]),
 "alpine_quartzite":(["hora"],[0.75,0.85]),"extreme_ridge":(["hora"],[0.82,1.01]),"high_massif":(["hora"],[0.85,0.95]),"rock_spire":(["hora"],[0.9,1.0]),
 "summit_pyramid":(["hora"],[0.93,1.0]),"highest_point":(["hora"],[0.97,1.01])}
# voda (perm, por, res, ret) – nové materiály; existující (id < 16) jsou ve sdilene/materialy_voda.json beze změny
W = {"quartz_sandstone":(0.5,0.2,0.2,0.05),"conglomerate":(0.4,0.2,0.2,0.03),"siltstone":(0.1,0.15,0.15,0.05),"loess":(0.35,0.4,0.35,0.15),
 "hill_sand":(0.7,0.33,0.25,0.05),"flysch":(0.15,0.15,0.3,0.05),"weathered_granite":(0.2,0.15,0.2,0.03),"weathered_volcanic":(0.15,0.12,0.2,0.03),
 "sandstone_towers":(0.5,0.2,0.15,0.03),"subalpine_scree":(0.7,0.3,0.2,0.02),"black_coal":(0.02,0.05,0.1,0.0),"lignite":(0.06,0.2,0.15,0.0)}
rocks=[]; water={}
nid=20
for (i,k,n,kind,act,fr,eid) in R + EXTRA:
    z=zone(i)
    if eid is None:
        mid=nid; nid+=1
    else:
        mid=eid
    lo,hi=ZONE_HUE[z]
    zr=[j for j in R+EXTRA if zone(j[0])==z]; pos=[j[1] for j in zr].index(k)
    h=(lo+(hi-lo)*pos/max(len(zr)-1,1))%1.0
    v=0.55+0.4*((pos*37)%5)/4.0; s=0.35+0.4*((pos*3)%4)/3.0
    if z=="plast": v=0.35+0.45*((pos*3)%5)/4.0
    if z=="hory": s=0.08+0.22*((pos*3)%4)/3.0; v=0.42+0.45*((pos*7)%6)/5.0
    r,g,b=colorsys.hsv_to_rgb(h,s,v)
    zlo,zhi={"plast":(0,12),"krystalinikum":(13,25),"sedimenty":(26,39),"povrch":(40,40),"hory":(41,61),"vzduch":(62,63),"telesa":(0,63)}[z]
    e={"idx":i,"key":k,"name":n,"zone":z,"kind":kind,"id":mid,"active":bool(act),"freq":fr,
       "depth":[max(zlo,i-2),min(zhi,i+2)],"thick":[2,5] if z=="plast" else [1,2] if kind=="seam" else [1,4],
       "color":"#%02x%02x%02x"%(int(r*255),int(g*255),int(b*255))}
    SPECIAL_COL={"kimberlite":"#1f6f5c","pegmatite":"#ff8fd0","skarn":"#7d3fa0","rock_salt":"#f7f2ee","eternal_snow":"#f4f8ff","topsoil":"#a8805f","weathered_volcanic":"#5b4744"}
    if k in SPECIAL_COL: e["color"]=SPECIAL_COL[k]
    if k in MOUNT: e["types"],e["rel"]=MOUNT[k]
    if kind=="pipe": e["body"]={"grid":40,"r0":1.4,"r1":2.8,"top_above_crystalline":7}
    if kind=="dome": e["body"]={"grid":48,"r_stem":2.0,"r_cap":4.5,"top":37}
    if kind=="vein": e["body"]={"grid":24,"planes":2,"half":0.55,"extent":9.0}
    if kind=="vent": e["body"]={"r":1.6,"r_top":2.4}; e["color"]="#d8401c"
    if kind=="contact": e["body"]={"width":2,"around":["granodiorite","granite","leucogranite"],"in":["deep_limestone","dolomite","cave_limestone","limestone_outcrop"]}
    rocks.append(e)
    if eid is None and kind not in ("air",):
        p=W.get(k,(0.0,0.0,0.1 if z!="hory" else 0.15,0.0))
        water[k]={"id":mid,"perm":p[0],"por":p[1],"res":p[2],"ret":p[3]}
# pevnost (Jan 16:58): load = kolik buněk (0,5 m) nad sebou unese jako STROP, cantilever = kolik buněk převisne bez podpory
STRENGTH={"air":(0,0),"topsoil":(4,0),"gravel_sand":(3,0),"loess":(6,0),"weathered_clay":(12,1),"siltstone":(40,2),"conglomerate":(40,2),
 "shale":(30,1),"quartz_sandstone":(60,3),"gypsum":(40,2),"rock_salt":(60,2),"dolomite":(120,5),"deep_limestone":(100,5),"cave_limestone":(80,4),
 "kimberlite":(80,2),"skarn":(120,4),"pegmatite":(150,5),"mica_schist":(120,4),"phyllite":(80,3),"serpentinite":(100,3),"eternal_snow":(4,0),
 "hill_sand":(6,0),"subalpine_scree":(4,0),"weathered_volcanic":(20,1),"flysch":(40,2),"sandstone_towers":(60,3),"weathered_granite":(40,2),
 "limestone_outcrop":(80,4),"volcanic_conduit":(100,4),"coal":(30,1),"lignite":(15,1),"gold":(100,4),"garnet":(120,4)}
def strength(k,z):
    if k in STRENGTH: return STRENGTH[k]
    if z in ("plast","krystalinikum"): return (200,8)
    if z=="hory": return (150,6)
    return (150,5)
for r in rocks:
    r["load"],r["cantilever"]=strength(r["key"],r["zone"])
for k in water:
    z=next((r["zone"] for r in rocks if r["key"]==k),"telesa")
    water[k]["load"],water[k]["cantilever"]=strength(k,z)
# minerály (MaterialId 100+ pro nové, staré beze změny)
M={
 "copper":{"id":8,"shape":"vein","hosts":["granite","granodiorite","skarn"],"maxHeap":8,"lz":[4,50],"inertia_permille":700,"branch_permille":80,"score":40},
 "iron":{"id":9,"shape":"pocket","hosts":["diabase","cave_limestone","skarn"],"maxHeap":4,"lz":[1,40],"score":25},
 "clay_deposit":{"id":12,"shape":"layer","hosts":["weathered_clay"],"maxHeap":120,"lz":[1,60],"pH_u16":52428,"pV_u16":6553,"score":2},
 "diamond":{"id":100,"shape":"pocket","hosts":["kimberlite"],"maxHeap":2,"lz":[0,40],"score":400},
 "gem":{"id":101,"shape":"pocket","hosts":["pegmatite"],"maxHeap":3,"lz":[0,50],"score":150},
 "rare_metal":{"id":102,"shape":"vein","hosts":["pegmatite"],"maxHeap":5,"lz":[0,50],"inertia_permille":800,"branch_permille":50,"score":90},
 "fe_ti":{"id":103,"shape":"pocket","hosts":["gabbro","fe_ti_zone","norite"],"maxHeap":6,"lz":[0,20],"score":30},
 "coal":{"id":104,"shape":"layer","hosts":["shale","siltstone","quartz_sandstone"],"maxHeap":80,"lz":[24,40],"pH_u16":60000,"pV_u16":2000,"score":12},
 "lignite":{"id":105,"shape":"layer","hosts":["weathered_clay","shale","loess"],"maxHeap":60,"lz":[28,45],"pH_u16":60000,"pV_u16":2000,"score":6},
 "garnet":{"id":106,"shape":"pocket","hosts":["mica_schist","eclogite","skarn"],"maxHeap":3,"lz":[0,50],"score":60},
 "gold":{"id":107,"shape":"vein","hosts":["quartzite","pegmatite","mica_schist"],"maxHeap":3,"lz":[0,50],"inertia_permille":800,"branch_permille":40,"score":250},
}
names={"copper":"měděná ruda","iron":"železná ruda","clay_deposit":"ložiskový jíl","diamond":"diamanty","gem":"drahokamy","rare_metal":"vzácné kovy (Li, Sn, Ta)",
 "fe_ti":"titanomagnetit (Fe-Ti)","coal":"černé uhlí","lignite":"hnědé uhlí","garnet":"granáty","gold":"zlato"}
cols={"diamond":"#f4fbff","gem":"#3fe0c8","rare_metal":"#c8d0ff","fe_ti":"#3b3b48","coal":"#141414","lignite":"#4a3a2a","garnet":"#b01c3c","gold":"#ffd23a"}
for k,m in M.items():
    m["name"]=names[k]
    if k in cols: m["color"]=cols[k]
    if m["id"]>=100:
        water[k]={"id":m["id"],"perm":0.0 if k!="lignite" else 0.06,"por":0.0 if k!="lignite" else 0.2,"res":0.1,"ret":0.0}
        water[k]["load"],water[k]["cantilever"]=strength(k,"telesa")
for r in rocks:
    r["hosts_minerals"]=[k for k,m in M.items() if r["key"] in m["hosts"]]
json.dump({"_popis":"Pořadí hornin 0–63 podle Gemini pro Jana (inspirace/gemini-kura-64.md, ZDROJE [10]). Je to POŘADÍ možných hornin, kdyby byly všechny; v daném místě se objeví jen podmnožina (freq = podíl plochy, kde horninu regionální pole zapne). idx = pořadí (≈ typická výška buňky), zone = zóna, kind: layer = vrstva (tloušťka thick je relativní váha uvnitř zóny), seam = sloj (vznikne vtisknutím minerálu), pipe/vein/dome/contact = zvláštní tělesa (body), mountain = horniny hor podle typu blueprintu (types) a relativní výšky rel = (z − 40) / 21, soil/snow/air. id = MaterialId (u8; existující gen-v3 materiály 0–12 znovu použité, nové 20+). Voda nových materiálů: ../sdilene/horniny_voda.json. Buňka = 0,5 m, takže velehory jsou jen symbolické.",
 "version":1,"zones":{"plast":[0,12],"krystalinikum":[13,25],"sedimenty":[26,39],"povrch":[40,40],"hory":[41,61],"vzduch":[62,63]},
 "rocks":rocks},open(D+"/data/poradi_hornin.json","w"),ensure_ascii=False,indent=1)
json.dump({"_popis":"blueprint-studie: kde smí který minerál nebo kov vzniknout (Jan 2026-11-18 16:02: každý minerál jen v určitých hostitelských horninách; 16:26 rozšířeno o horniny z data/poradi_hornin.json). Tvar a parametry růstu jako katalog gen-v3, hostitelé = klíče hornin z data/poradi_hornin.json (staré klíče gen-v3 granite/limestone/basalt/clay platí jako aliasy). Když blok nemá dost hostitele, zbytek je SCHODEK (nehledá se jinde). lz = absolutní výška buněk, score = body rarity za buňku.",
 "version":2,"minerals":M},open(D+"/data/mineraly_hostitele.json","w"),ensure_ascii=False,indent=1)
json.dump({"_popis":"ROZŠÍŘENÍ sdilene/materialy_voda.json (stejné schéma: id, perm, por, res, ret) pro nové horniny a minerály z blueprint-studie/data/poradi_hornin.json (MaterialId 20+ a 100+, u8). Původní tabulka se NEMĚNÍ (čte ji voda-studie, lozika-studie a prototyp, který porovnává svou kopii); kdo chce nové horniny, načte obě tabulky. Hodnoty jsou odhad (pískovec, štěrk, spraš, suť propustné; krystalinikum, karbonáty jako vápenec podle Jana nepropustné). Pevnost (Jan 16:58): load = kolik buněk (0,5 m) nad sebou unese jako strop, cantilever = kolik buněk převisne bez podpory; uvnitř se počítá v metrech (× 0,5).",
 "version":1,"extends":"materialy_voda.json","perm_leak":0.05,"materials":water},open(D+"/../sdilene/horniny_voda.json","w"),ensure_ascii=False,indent=1)
print(len(rocks),"hornin,",sum(1 for r in rocks if r["active"] and r["kind"]=="layer"),"aktivních vrstev,",len(M),"minerálů, max id",max(r["id"] for r in rocks))
