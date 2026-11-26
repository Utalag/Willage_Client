import re, numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
R='/workspace/willage-ideas/gen-v1-wt/godot-prototyp/shots/prusak-pobrezi/'
rows=[]
for l in open(R+'sirky_pasu.md'):
    c=[x.strip() for x in l.strip().strip('|').split('|')]
    if len(c)>=9 and re.match(r'\d+ ',c[0]): rows.append(c)
jm=[r[0].split(' ',1)[1]+f' ({r[1]})' for r in rows]
f=lambda i:[float(r[i]) for r in rows]
fig,ax=plt.subplots(figsize=(12,6)); x=np.arange(len(rows)); w=.2
ax.bar(x-1.5*w,f(3),w,label='30 dnů, spád 10 ‰ (plochý břeh)')
ax.bar(x-.5*w,f(4),w,label='30 dnů, spád 50 ‰')
ax.bar(x+.5*w,f(5),w,label='30 dnů, spád 200 ‰ (voda z kopce)')
ax.bar(x+1.5*w,f(8),w,label='30 dnů, 50 ‰, bez koeficientu (jen Darcy)',color='#bbbbbb',hatch='//')
ax.axhline(5,color='r',ls='--',lw=1); ax.text(len(rows)-0.5,5.2,'stávající konstanta 5 m',color='r',ha='right')
ax.axhline(16,color='k',ls=':',lw=1); ax.text(len(rows)-0.5,16.2,'strop PobrezMaxM 16 m',ha='right')
ax.set_yscale('symlog',linthresh=0.1); ax.set_ylim(0,25)
ax.set_xticks(x); ax.set_xticklabels(jm,rotation=40,ha='right',fontsize=8)
ax.set_ylabel('šířka pobřežního pásu (m, symlog)'); ax.set_title('Šířka pásu mořské hladiny do vnitrozemí: dosah průsaku za 30 dnů podle materiálu, tlaku a koeficientu')
ax.legend(fontsize=8,loc='center right',bbox_to_anchor=(1,0.55)); ax.grid(alpha=.3,axis='y',which='both')
fig.tight_layout(); fig.savefig(R+'sirka_pasu_podle_materialu.png',dpi=120); print('ok')
