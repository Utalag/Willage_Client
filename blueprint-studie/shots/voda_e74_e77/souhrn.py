import json, re, sys, os
S=sys.argv[1]; D='/tmp/vt/'+S
def J(n):
    p=f'{D}/{n}.json'
    return json.load(open(p)) if os.path.exists(p) else None
def T(n):
    p=f'{D}/{n}.txt'
    return open(p).read() if os.path.exists(p) else ''
out={}
for n in ['e66_vychozi','e66_obracene','e66_e67','e66_e67_obr']:
    j=J(n)
    if not j: continue
    out[n]={'otisk_po':j['hydro68_po']['otisk'],'otisk_pred':j['hydro68_pred'].get('otisk'),'neshod':j['neshod_celkem'],'chyba_pred':j['hydro68_pred']['bilance']['chyba_svet'],'chyba_po':j['hydro68_po']['bilance']['chyba_svet'],
      'vyver_ven':j['hydro68_po']['bilance'].get('podzemi_vyver74_ven'),'vystupy':j['podzemi_vystupy'],'souhrn_po':j['souhrn_po'],'plny_ms':j['voda_ms'].get('povrch + podzemí: plný výpočet'),
      'vykop_ms_prumer':round(sum(v.get('ms',0) for v in j['vykopy'])/max(1,len(j['vykopy'])),1) if j['vykopy'] and isinstance(j['vykopy'][0],dict) else None}
for n in ['e68_auto','e68_pretok','e68_auto05','e68_pretok05','e68_vyzv']:
    t=T(n); m=re.findall(r'ustaleni\s+skoky\s+(\d+) kola\s+(\d+).*?okraj ([0-9.]+) průsak ([0-9.]+) stěna ([0-9.]+).*?prameny ([0-9.]+).*?chyba svět (-?[0-9.]+)',t)
    o=re.findall(r'otisk při opakování stejný: (\w+)',t)
    if m: out[n]={'kola':m[0][1],'okraj':m[0][2],'prusak':m[0][3],'stena':m[0][4],'prameny':m[0][5],'chyba':m[0][6],'opakovani':o}
t=T('e69'); out['e69']={'radku':len(re.findall('bilance chyba',t)),'nenulova_chyba':len([x for x in re.findall(r'bilance chyba (-?[0-9.]+)',t) if float(x)!=0]),'sym_tok_nenul':len([x for x in re.findall(r'tok ([0-9.]+) \(',t) if float(x)!=0]),
  'vystupy':re.findall(r'^(\w+)\s+(pretok\+O(?: bez slucovani)?)\s.*?výstupů (\d+)',t,re.M)}
j=J('e72_ostrov')
if j: out['e72']={'varianty':[(v.get('varianta'),v.get('vystupy'),v.get('slouceno72'),round(v.get('slouceno72_d',0),2),v.get('ponechano72'),v.get('vystupy_otisk'),v.get('vystupy_q_lps')) for v in j['varianty']],'vykopy':{k:(v.get('neshod'),v.get('otisk')) for k,v in j['vykopy'].items() if isinstance(v,dict)},'poradi':j['vykopy'].get('poradi_stejny_otisk')}
for n in ['e74','e74_e67','e74_vyzv','e74_vyzv_obr']:
    t=T(n); m=re.search(r'E74 po výkopech: otisk plochy (\w+) \| hydro (\w+) \| neshod (\d+) otisk ≠ plný (\d+) plocha ≠ plná (\d+) \| vyver74 (\d+) obsazeno (\d+)',t)
    b=re.search(r'E74 bilance po (-?[0-9.e-]+)',t)
    if m: out[n]={'plocha':m[1],'hydro':m[2],'neshod':m[3],'otisk_ne':m[4],'plocha_ne':m[5],'vyver74':m[6],'obsazeno':m[7],'chyba':b[1] if b else None}
t=T('e75_syn'); out['e75_syn']={'krasy':re.findall(r'otisk krasu (\w+), výkopy obě pořadí stejné: (\w+)',t),'neshod':re.findall(r'neshod přesně (\d+), nad 1e-12 (\d+)',t),'prvni':re.findall(r'první dutina den ([0-9.]+) \(([0-9]+) min reálně\)',t),'chyby_nenul':len([x for x in re.findall(r'chyba (-?[0-9.e-]+),',t) if float(x)!=0])}
t=T('e75_ostrov'); m=re.search(r'E75 konec: .*',t); out['e75_ostrov']=m[0] if m else t[-300:]
for n in ['e76','e76_p76']:
    t=T(n); out[n]={'A':re.findall(r'^A: .*',t,re.M),'B':[re.sub(r'\(podzemí.*?\)','',x) for x in re.findall(r'^B slot.*',t,re.M)]}
t=T('e77'); out['e77']=re.findall(r'^E77 .*',t,re.M)
print(json.dumps(out,ensure_ascii=False,indent=1))
