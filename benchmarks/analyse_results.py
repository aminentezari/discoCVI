# analyse_results.py - summary table and figures from results_final.csv
# Run from benchmarks/:  python3 analyse_results.py
import csv, statistics as st, math
from collections import defaultdict
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
r=list(csv.DictReader(open('results_final.csv')))
g=defaultdict(list)
for x in r: g[(x['version'],int(float(x['n'])))].append(x)
med=st.median
base={n:med([float(x['energy_Wh']) for x in g[('baseline',n)]]) for (v,n) in g if v=='baseline'}
basemem={n:med([float(x['peak_rss_MB']) for x in g[('baseline',n)]]) for (v,n) in g if v=='baseline'}
rows=[]
for (v,n),xs in sorted(g.items(), key=lambda k:(k[0][0],k[0][1])):
    if v=='baseline': continue
    t=[float(x['disco_time_s']) for x in xs]; m=[float(x['peak_rss_MB']) for x in xs]; e=[float(x['energy_Wh']) for x in xs]
    rows.append(dict(version=v,n=n,reps=len(xs),time_med=med(t),time_min=min(t),time_max=max(t),
        rss_med=med(m),rss_extra=med(m)-basemem[n],energy_med=med(e),energy_net=med(e)-base[n],
        energy_net_mWh=(med(e)-base[n])*1000))
with open('results_summary.csv','w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
R={(x['version'],x['n']):x for x in rows}
print("baseline energy mWh:",{n:round(v*1000,3) for n,v in sorted(base.items())})
print("baseline RSS:",{n:round(v) for n,v in sorted(basemem.items())})
print(f"{'n':>7} {'old t':>8} {'new t':>8} {'speedup':>8} | {'old MB':>7} {'new MB':>7} {'oldx':>6} {'newx':>6} | {'old mWh':>8} {'new mWh':>8} {'E ratio':>7}")
for n in [500,1000,2000,4000,8000,16000,32000,64000,100000]:
    nw=R[('new',n)]; o=R.get(('old',n))
    if o: print(f"{n:>7} {o['time_med']:8.3f} {nw['time_med']:8.3f} {o['time_med']/nw['time_med']:8.0f} | {o['rss_med']:7.0f} {nw['rss_med']:7.0f} {o['rss_extra']:6.0f} {nw['rss_extra']:6.0f} | {o['energy_net_mWh']:8.3f} {nw['energy_net_mWh']:8.3f} {o['energy_net']/nw['energy_net'] if nw['energy_net']>0 else float('nan'):7.1f}")
    else: print(f"{n:>7} {'-':>8} {nw['time_med']:8.3f} {'':>8} | {'-':>7} {nw['rss_med']:7.0f} {'':>6} {nw['rss_extra']:6.0f} | {'-':>8} {nw['energy_net_mWh']:8.3f}")
def slope(v,ns,key='time_med'):
    xs=[math.log(n) for n in ns]; ys=[math.log(R[(v,n)][key]) for n in ns]
    mx,my=st.mean(xs),st.mean(ys); return sum((a-mx)*(b-my) for a,b in zip(xs,ys))/sum((a-mx)**2 for a in xs)
print("time exponent old (500-4000):",round(slope('old',[500,1000,2000,4000]),2))
print("time exponent new (8000-100000):",round(slope('new',[8000,16000,32000,64000,100000]),2))
print("extra-mem exponent old:",round(slope('old',[500,1000,2000,4000],'rss_extra'),2))
plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False})
col={'old':'#d95f02','new':'#1b9e77'}; lab={'old':'discoCVI 0.1.1','new':'discoCVI 0.2.0'}
for key,ylab,fn in [('time_med','DISCO computation time (s)','fig_time'),
                    ('rss_med','Peak memory of the R process (MB)','fig_memory'),
                    ('energy_net_mWh','Energy above baseline (mWh)','fig_energy')]:
    fig,ax=plt.subplots(figsize=(5.2,3.6))
    for v in ['old','new']:
        pts=[(x['n'],x[key]) for x in rows if x['version']==v and x[key]>0]
        ax.plot([p[0] for p in pts],[p[1] for p in pts],'o-',color=col[v],label=lab[v],lw=1.8,ms=4)
    ax.set_xscale('log'); ax.set_yscale('log')
    ax.set_xlabel('Number of points n'); ax.set_ylabel(ylab); ax.legend(frameon=False); ax.grid(alpha=.3,which='both')
    fig.tight_layout(); fig.savefig(f'figures/{fn}.pdf'); fig.savefig(f'figures/{fn}.png',dpi=110); plt.close(fig)
