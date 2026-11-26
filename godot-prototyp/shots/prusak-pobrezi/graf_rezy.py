import struct, json, numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm
R='/workspace/willage-ideas/gen-v1-wt/'
O='/workspace/eroze-pobrezi/'
OUT=R+'godot-prototyp/shots/prusak-pobrezi/'
kat=json.load(open(R+'godot-prototyp/data/v1/materials-catalog-v1.json'))
jm={m['id']:m['key'] for m in kat['materials']}
def nacti(f):
    b=open(f,'rb').read(); n,nz=struct.unpack('ii',b[:8]); krok=struct.unpack('d',b[8:16])[0]; o=16
    P,W,K=[],[],[]; M=np.zeros((nz,n),np.uint8)
    for i in range(n):
        p,w,k=struct.unpack('ddd',b[o:o+24]); o+=24; M[:,i]=np.frombuffer(b,np.uint8,nz,o); o+=nz
        P.append(p);W.append(w);K.append(k)
    return n,nz,krok,np.array(P),np.array(W),np.array(K),M
rezy=[('pozvolne','pozvolné pobřeží (seed 49, od x 21262,2 y 2085,4 m)'),
      ('strme','strmé pobřeží (seed 49, od x 22489,4 y 5322,3 m)'),
      ('pisekA','písčitý břeh A (gravel_sand, od x 29113,5 y 4576 m)'),
      ('pisekB','písčitý břeh B (gravel_sand, od x 8117 y 2400 m, směr −x)')]
fig,axs=plt.subplots(len(rezy),2,figsize=(18,5.2*len(rezy)),gridspec_kw={'width_ratios':[3,2]})
for r,(kod,tit) in enumerate(rezy):
    n,nz,krok,P,W0,K,M=nacti(O+'vyp_'+kod+'.bin'); _,_,_,_,W1,_,_=nacti(O+'zap_'+kod+'.bin')
    ids=sorted(set(np.unique(M))-{0}); lut=np.zeros(256,int)
    for t,i in enumerate(ids): lut[i]=t+1
    Mi=lut[M]; cols=['#ffffff']+[plt.cm.tab20(t%20) for t in range(len(ids))]
    cm=ListedColormap(cols); nm=BoundaryNorm(np.arange(-0.5,len(ids)+1.5),cm.N)
    s=np.arange(n)*krok; je=(P<60)&(K<0.5)
    sb=np.argmax(~je)*krok if np.any(~je) else 0
    for c,(a,xl) in enumerate(zip(axs[r],[(0,n*krok),(max(0,sb-4),sb+16)])):
        a.imshow(Mi,origin='lower',extent=[0,n*krok,0,nz*krok],cmap=cm,norm=nm,aspect='auto',interpolation='nearest')
        a.fill_between(s,np.minimum(P,60),60,where=P<60,color='#3070ff',alpha=.45,label='moře (60 m)')
        a.plot(s,P,'k',lw=1.2,label='povrch')
        a.plot(s,np.where(je,np.nan,W0),color='#ff8000',lw=2.0,ls='--',label='stávající: pás 5 m konstantně')
        a.plot(s,np.where(je,np.nan,W1),color='#00a0e0',lw=1.8,label='nově: pás z koeficientu průsaku (30 dnů)')
        a.axvline(sb,color='#008000',lw=1,ls='--',label='břeh')
        a.axvline(sb+5,color='#ff8000',lw=.8,ls=':',label='5 m od břehu')
        m=(s>=xl[0])&(s<=xl[1]); lo=min(P[m].min(),np.nanmin(np.where(m&~je,W1,np.inf)),np.nanmin(np.where(m&~je,W0,np.inf)))-3 if c else max(0,np.floor(min(P.min(),np.nanmin(np.where(je,np.nan,W1)))-12))
        hi=(max(P[m].max(),62)+3) if c else np.ceil(max(P.max(),62)+6)
        a.set_xlim(*xl); a.set_ylim(lo,hi)
        a.set_xlabel('vzdálenost podél řezu (m), moře vlevo → pevnina vpravo'); a.set_ylabel('výška z (m)')
        a.set_title(('řez 100 m: ' if c==0 else 'detail pásu u břehu: ')+tit,fontsize=10)
        if c==0:
            a.legend(loc='upper left',fontsize=7)
        else:
            h=[plt.Rectangle((0,0),1,1,color=cols[t+1]) for t in range(len(ids))]
            a.legend(h,[f'{i} {jm.get(i,"?")}' for i in ids],loc='lower right',fontsize=6,ncol=2,title='materiál',title_fontsize=7)
plt.tight_layout(); plt.savefig(OUT+'rezy_pobrezi_prusak.png',dpi=70); print('ok')
