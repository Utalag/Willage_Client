import csv, collections
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
D='/workspace/willage-ideas/gen-v1-wt/godot-prototyp/shots/prusak/'
plt.rcParams['font.family']='DejaVu Sans'
# 1 útlum
u=collections.defaultdict(list)
for r in csv.DictReader(open(D+'utlum.csv'),delimiter=';'): u[r['material']].append((int(r['bloku']),float(r['T'])))
kof={'štěrk':255,'písek':178,'spraš':38,'zvětralá žula':77,'jíl':13,'žula':0}
fig,ax=plt.subplots(figsize=(9,5.5))
for m,v in u.items():
    xs=[a for a,b in v]; ys=[max(b,1e-9) for a,b in v]
    ax.plot(xs,ys,marker='o',ms=3,label=f'{m} (koef. {kof[m]}/255)')
ax.axhline(0.03,color='k',ls='--',lw=1); ax.text(15.5,0.034,'3 % (těsné)',fontsize=9)
ax.set_yscale('log'); ax.set_ylim(1e-6,1.5); ax.set_xlim(0,20)
ax.set_xlabel('počet projitých bloků stěny (1 blok = 0,25 m)'); ax.set_ylabel('podíl vody, který projde (log)')
ax.set_title('Útlum průsaku podle tloušťky stěny a materiálu\n(koeficient 0–255, celočíselně, Q24)')
ax.grid(alpha=.3,which='both'); ax.legend(fontsize=8)
fig.tight_layout(); fig.savefig(D+'utlum_podle_tloustky.png',dpi=140); plt.close(fig)
# 2 plnění
p=collections.defaultdict(list)
for r in csv.DictReader(open(D+'plneni.csv'),delimiter=';'): p[(r['scenar'],r['rezim'])].append((int(r['cas_s'])/3600,float(r['hladina_m'])))
fig,ax=plt.subplots(figsize=(10,6))
sel=[('písek 1 blok','C0'),('písek 5 bloků','C1'),('písek 10 bloků','C2'),('spraš 1 blok','C3'),('zvětralá žula 5 bloků','C4'),('žula 1 blok + 1 díra','C5')]
for n,c in sel:
    for rez,ls in (('stavajici','--'),('koeficient','-')):
        v=[(t,h) for t,h in p[(n,rez)] if t>0]
        if rez=='stavajici' and n in('písek 5 bloků','písek 10 bloků','spraš 5 bloků'): continue
        ax.plot([t for t,h in v],[h for t,h in v],ls=ls,color=c,label=f"{n} – {'koeficient zapnut' if rez=='koeficient' else 'stávající pravidlo'}")
ax.axhline(60,color='b',lw=.8); ax.text(0.2,60.1,'hladina venku 60 m',color='b',fontsize=9)
ax.axhline(56,color='gray',lw=.8); ax.text(0.2,56.1,'dno dutiny 56 m',color='gray',fontsize=9)
ax.set_xscale('log'); ax.set_xlabel('herní čas (hodiny, log)'); ax.set_ylabel('hladina vody v dutině (m)')
ax.set_title('Plnění dutiny 2 × 2 m pod hladinou 60 m podle stěny\n(plná čára = koeficient zapnut, přerušovaná = stávající pravidlo)')
ax.set_ylim(55.8,60.4); ax.grid(alpha=.3,which='both'); ax.legend(fontsize=7,loc='lower right')
fig.tight_layout(); fig.savefig(D+'plneni_dutiny.png',dpi=140); plt.close(fig)
