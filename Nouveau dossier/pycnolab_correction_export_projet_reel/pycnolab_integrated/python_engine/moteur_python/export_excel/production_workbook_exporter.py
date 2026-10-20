from __future__ import annotations
from pathlib import Path
import math, re
from openpyxl import load_workbook
from openpyxl.chart import ScatterChart, BarChart, Reference, Series
from openpyxl.utils import get_column_letter
try:
    from ..import_excel.reader import read_workbook
except ImportError:
    # Exécution directe facultative depuis l’espace de test.
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        from reader import read_workbook
    except ImportError:
        from classeur_entree_reader import read_workbook

BASE_SHEETS = {'DIAMETRE (CR,CS)', 'RECCAPITULATIF'}


def _num(v):
    try: return float(v)
    except (TypeError, ValueError): return None


def _blocks(ws):
    out=[]
    for c in range(1, ws.max_column+1):
        h=str(ws.cell(1,c).value or '')
        m=re.search(r'ELONG.*ECH\s*(\d+)',h,re.I)
        if not m: continue
        force=next((j for j in range(c+1,min(ws.max_column,c+8)+1) if 'FORCE' in str(ws.cell(1,j).value or '').upper()),None)
        if force: out.append((int(m.group(1)),c,force))
    return {n:(c,f) for n,c,f in out}


def _ensure_group_sheet(wb, name, template_name='COROUI'):
    if name in wb.sheetnames: return wb[name]
    if template_name not in wb.sheetnames: return wb.create_sheet(name)
    ws=wb.copy_worksheet(wb[template_name]); ws.title=name; return ws


def _ensure_block(ws, index):
    blocks=_blocks(ws)
    if index in blocks: return blocks[index]
    start=1 + (index-1)*8
    for c in range(start,start+8):
        if c > ws.max_column: ws.cell(1,c).value=None
    source=blocks.get(1)
    if source:
        src_start,src_force=source
        for off in range(8):
            sc=src_start+off; dc=start+off
            ws.cell(1,dc)._style=ws.cell(1,sc)._style
            ws.cell(1,dc).number_format=ws.cell(1,sc).number_format
    ws.cell(1,start).value=f'Elong.(mm) - Ech {index}'
    ws.cell(1,start+1).value=f'Force(N) - Ech {index}'
    for off,label in enumerate(['Def','Cont','Cont(max)','Def rupt','E(mpa)'],2): ws.cell(1,start+off).value=label
    return start,start+1


def _ensure_diameter_group(ws, group_index, name):
    starts=[]
    for c in range(1,ws.max_column-2):
        labels=' '.join(str(ws.cell(2,c+i).value or '').upper() for i in range(3))
        if ('D_1' in labels or 'D1' in labels) and ('D_2' in labels or 'D2' in labels) and ('D_3' in labels or 'D3' in labels): starts.append(c)
    if group_index <= len(starts): return starts[group_index-1]
    start=max(ws.max_column+2, 2+(group_index-1)*8)
    ws.cell(1,start).value=f'DIAMETRE {name}'
    for off,label in enumerate(['D_1(mm)','D_2(mm)','D_3(mm)','D_Moy(mm)','S_(mm2)','D_Moy Global(mm)']): ws.cell(2,start+off).value=label
    ws.cell(2,start-1).value='ID Échantillon'
    return start


def _young(strains, stresses):
    peak=max(stresses); pts=[(x,y) for x,y in zip(strains,stresses) if y<=peak*.5]
    if len(pts)<2:return None
    mx=sum(x for x,y in pts)/len(pts); my=sum(y for x,y in pts)/len(pts); den=sum((x-mx)**2 for x,y in pts)
    return None if den==0 else sum((x-mx)*(y-my) for x,y in pts)/den


def _set_chart(chart, group, xcol, ycol, n):
    chart.series=[]
    xref=Reference(chart._parent if False else None,1,1,1,1) if False else None
    from openpyxl.chart.data_source import NumDataSource, NumRef
    s=Series(NumDataSource(numRef=NumRef(f=f'{group}!${get_column_letter(xcol)}$2:${get_column_letter(xcol)}${n+1}')), title='')
    s.yVal=NumDataSource(numRef=NumRef(f=f'{group}!${get_column_letter(ycol)}$2:${get_column_letter(ycol)}${n+1}'))
    chart.series.append(s)


def process_workbook(input_path: str|Path, template_path: str|Path, output_path: str|Path, l0_mm: float=20.0) -> Path:
    data=read_workbook(input_path)
    wb=load_workbook(template_path, data_only=False)
    groups=data['gammes']
    needed=BASE_SHEETS | {g['nom_gamme'] for g in groups}
    for name in list(wb.sheetnames):
        if name not in needed: wb.remove(wb[name])
    for g in groups: _ensure_group_sheet(wb,g['nom_gamme'])
    diam=wb['DIAMETRE (CR,CS)']; summaries=[]
    for gi,g in enumerate(groups,1):
        name=g['nom_gamme']; dstart=_ensure_diameter_group(diam,gi,name); ws=wb[name]
        dmeans=[]
        for i,s in enumerate(g['echantillons'],1):
            row=3+i-1; ident=s['identifiant']; dm=s['diametre_moyen_mm']; sec=s['section_mm2']; dmeans.append(dm)
            diam.cell(row,dstart-1).value=ident
            for j,v in enumerate(s['diametres_mm'][:3]): diam.cell(row,dstart+j).value=v
            diam.cell(row,dstart+3).value=dm; diam.cell(row,dstart+4).value=sec
            ec,fc=_ensure_block(ws,i); strains=[]; stresses=[]
            for rr,p in enumerate(s['points_courbe'],2):
                x=p['deplacement_mm']; force=p['force_newton']; strain=x/l0_mm; stress=force/sec
                ws.cell(rr,ec).value=x; ws.cell(rr,fc).value=force; ws.cell(rr,fc+2).value=strain; ws.cell(rr,fc+3).value=stress
                strains.append(strain); stresses.append(stress)
            if stresses:
                ix=max(range(len(stresses)),key=stresses.__getitem__); peak=stresses[ix]; rupture=strains[ix]*100; young=_young(strains,stresses)
                ws.cell(2,fc+4).value=peak; ws.cell(2,fc+5).value=rupture; ws.cell(2,fc+6).value=young
                if i-1<len(ws._charts):
                    ch=ws._charts[i-1]; ch.series=[]; ch.x_axis.title='Déformation'; ch.y_axis.title='Contrainte (MPa)'
                    from openpyxl.chart import Series
                    xref=Reference(ws,fc+2,2,len(strains)+1); yref=Reference(ws,fc+3,2,len(stresses)+1)
                    ch.series.append(Series(yref,xref,title=ident))
                else:
                    ch=ScatterChart(); ch.title=ident; ch.x_axis.title='Déformation'; ch.y_axis.title='Contrainte (MPa)'; ch.series.append(Series(Reference(ws,fc+3,2,len(stresses)+1),Reference(ws,fc+2,2,len(strains)+1),title=ident)); ch.anchor=f'A{30+(i-1)*16}'; ws.add_chart(ch)
                summaries.append({'gamme':name,'identifiant':ident,'cont_max_mpa':peak,'def_rupt_pourcent':rupture,'young_mpa':young})
        if dmeans: diam.cell(3,dstart+5).value=sum(dmeans)/len(dmeans)
        # Un rapport ne doit contenir aucun graphique pour un échantillon absent.
        if len(ws._charts) > len(g['echantillons']):
            del ws._charts[len(g['echantillons']):]
    # Le récapitulatif est une sortie : on reconstruit ses données sans exiger sa présence dans l’entrée.
    rec=wb['RECCAPITULATIF']; rec.delete_rows(1,rec.max_row); rec['A1']='RECCAPITULATIF'; rec['A2']='Gamme'; rec['B2']='Échantillon'; rec['C2']='Cont(max) MPa'; rec['D2']='Def rupt %'; rec['E2']='E(mpa)'
    r=3
    for g in groups:
        items=[s for s in summaries if s['gamme']==g['nom_gamme']]
        for s in items:
            rec.cell(r,1).value=g['nom_gamme']; rec.cell(r,2).value=s['identifiant']; rec.cell(r,3).value=s['cont_max_mpa']; rec.cell(r,4).value=s['def_rupt_pourcent']; rec.cell(r,5).value=s['young_mpa']; r+=1
        vals=lambda k:[s[k] for s in items if s[k] is not None]
        rec.cell(r,1).value=g['nom_gamme']; rec.cell(r,2).value='MOYENNE'
        for c,k in ((3,'cont_max_mpa'),(4,'def_rupt_pourcent'),(5,'young_mpa')):
            v=vals(k); rec.cell(r,c).value=sum(v)/len(v) if v else None
        r+=1
    chart=BarChart(); chart.title='Comparaison des gammes - contrainte maximale'; chart.y_axis.title='MPa'; chart.x_axis.title='Gamme'
    # Moyennes par gamme dans les lignes marquées MOYENNE.
    mean_rows=[rr for rr in range(3,r) if rec.cell(rr,2).value=='MOYENNE']
    if mean_rows:
        data_ref=Reference(rec,min_col=3,min_row=mean_rows[0],max_row=mean_rows[-1]); cats=Reference(rec,min_col=1,min_row=mean_rows[0],max_row=mean_rows[-1]); chart.add_data(data_ref); chart.set_categories(cats); chart.anchor='G2'; rec.add_chart(chart)
    try: wb.calculation.fullCalcOnLoad=True; wb.calculation.forceFullCalc=True; wb.calculation.calcMode='auto'
    except AttributeError: pass
    out=Path(output_path); wb.save(out); return out
