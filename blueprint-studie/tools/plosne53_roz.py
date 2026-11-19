import numpy as np, math
DX=[1,1,0,-1,-1,-1,0,1]; DY=[0,1,1,1,0,-1,-1,-1]
def shift(a,d):  # b[i] = a[i - D] (posun ve směru d)
    W,H=a.shape[:2]; b=np.zeros_like(a); dx,dy=DX[d],DY[d]
    xs=slice(max(dx,0),W+min(dx,0)); xd=slice(max(-dx,0),W+min(-dx,0))
    ys=slice(max(dy,0),H+min(dy,0)); yd=slice(max(-dy,0),H+min(-dy,0))
    b[xs,ys]=a[xd,yd]; return b
def nb(a,d,fill):  # hodnota souseda ve směru d
    W,H=a.shape; P=np.pad(a,1,constant_values=fill); return P[1+DX[d]:1+DX[d]+W,1+DY[d]:1+DY[d]+H]
def run(z,k,src,wall,alpha=0.5,passes=2000,vcell=50.0,ero=None,verbose=False):
    W,H=z.shape; lvl=np.zeros((W,H)); V=np.zeros((W,H)); car=np.zeros((W,H))
    fin=np.zeros((W,H)); lat=np.zeros((8,W,H))   # lat[s] = paket přicházející pohybem ve směru s
    for it in range(passes):
        S=z+lvl; cap=k*(1+alpha*(lvl+car)); cap[wall==1]=0
        best=np.zeros((W,H)); dirn=-np.ones((W,H),int)
        for d in range(8):
            Sj=nb(S,d,-1e9); Sj=np.where(nb(wall,d,0)==1,1e9,Sj)
            g=(S-Sj)/(1.4142 if d%2 else 1.0); m=g>best+1e-12; best[m]=g[m]; dirn[m]=d
        lin=lat.sum(0); tot=fin+lin
        fwd=np.minimum(tot,cap); left=tot-fwd
        fresh=np.minimum(left,np.maximum(fin-cap,0)); latl=left-fresh
        frac=np.where(lin>1e-12,latl/np.maximum(lin,1e-12),0)
        nfin=src.copy(); nlat=np.zeros((8,W,H)); acc=np.zeros((W,H))
        dd=np.where(dirn<0,0,dirn)
        for d in range(8):   # dopředu
            m=(dirn==d); nfin+=shift(np.where(m,fwd,0),d)
        acc+=np.where(dirn<0,fwd,0)
        def ok(s):  # lze poslat do strany s?
            return (nb(wall,s,1)==0)&(nb(z,s,1e9)<=S+1e-9)
        for s in range(8):   # pokračující pakety
            o=ok(s); p=lat[s]*frac
            nlat[s]+=shift(np.where(o,p,0),s); acc+=np.where(o,0,p)
        # čerstvý přebytek: polovina (celé násobky k) na každou stranu
        u=np.round(fresh/np.maximum(k,1e-9)); h1=np.minimum(np.ceil(u/2)*k,fresh); h2=fresh-h1
        for d in range(8):
            m=dd==d; sp=(d+2)%8; sm=(d+6)%8
            op=ok(sp); om=ok(sm)
            a1=np.where(m,h1,0); a2=np.where(m,h2,0)
            # zablokovaná strana → celé na druhou, obě → hromadit
            to_p=np.where(op,a1+np.where(om,0,a2),0); to_m=np.where(om,a2+np.where(op,0,a1),0)
            nlat[sp]+=shift(to_p,sp); nlat[sm]+=shift(to_m,sm)
            acc+=np.where(m&~op&~om,a1+a2,0)
        V+=acc; lvl=np.floor(V/vcell)
        ch=max(np.abs(nfin-fin).max(),np.abs(nlat-lat).max()); fin,lat=nfin,nlat
        if verbose and it%50==0: print(it,round(ch,4),round(acc.sum(),3))
        if ch<1e-9 and acc.sum()<1e-9: return fin+lat.sum(0),lvl,it
    return fin+lat.sum(0),lvl,passes
if __name__=="__main__":
    W,H=50,41
    x=np.arange(W)[:,None]*np.ones((1,H)); z=10-0.3*x
    k=np.where(x<25,0.5,0.25); src=np.zeros((W,H)); src[2,20]=4.0; wall=np.zeros((W,H),int)
    q,l,it=run(z,k,src,wall,verbose=True)
    def wid(q,xx): return (np.minimum(q[xx],1)>1e-9).sum()
    for xx in (5,15,24,30,40,48): print(xx,wid(q,xx), np.round(q[xx][q[xx]>1e-9],3))
    print("passes",it)
