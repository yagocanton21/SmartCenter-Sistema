/* notas.js – Nota de Serviço: emitida quando a manutenção é concluída, com o mesmo número da OS.
   É aqui (e só aqui) que o Termo de Garantia é impresso. */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon;
  const st = { q: '', status: '', garantia: '', page: 1 };
  const FIM = ['Concluído', 'Entregue'];

  SC.pages.notas = {
    title: 'Nota de serviços',
    state: st,
    render(el) {
      const edit = SC.can('os');
      const pend = SC.db.os.filter(o => !FIM.includes(o.status)).length;
      el.innerHTML = `<div class="page-head"><div><h1>Nota de serviços</h1><p>Emitida quando a manutenção é concluída, com o <b>mesmo número da OS</b>. Esta nota imprime o Termo de Garantia.</p></div></div>
        <div class="card"><div class="toolbar"><div class="search">${icon('search', 16)}<input type="search" id="nq" placeholder="Buscar por nº, cliente, aparelho ou IMEI…" value="${esc(st.q)}"></div>
        <select id="ns" aria-label="Filtrar por status"><option value="">Concluídas e entregues</option>${FIM.map(s => `<option${s === st.status ? ' selected' : ''}>${s}</option>`).join('')}</select>
        <select id="ng" aria-label="Filtrar por garantia"><option value="">Toda garantia</option><option value="vig"${st.garantia === 'vig' ? ' selected' : ''}>Garantia vigente</option><option value="venc"${st.garantia === 'venc' ? ' selected' : ''}>Garantia vencida</option><option value="sem"${st.garantia === 'sem' ? ' selected' : ''}>Sem garantia</option></select></div>
        <div class="table-wrap" id="nlist"></div><div class="pager" id="npager"></div></div>
        <p class="hint" style="margin-top:10px">${pend ? `${pend} OS ainda em andamento. A nota fica disponível assim que o status chegar em <b>Concluído</b>.` : 'Não há OS em andamento.'}</p>`;
      const list = el.querySelector('#nlist');
      const draw = () => {
        const q = SC.norm(st.q).trim(), qd = SC.digits(st.q);
        const rows = SC.db.os.filter(o => {
          if (!FIM.includes(o.status)) return false;
          if (st.status && o.status !== st.status) return false;
          const g = SC.notaInfo(o);
          if (st.garantia === 'vig' && !g.vigente) return false;
          if (st.garantia === 'venc' && !(g.dias > 0 && !g.vigente)) return false;
          if (st.garantia === 'sem' && g.dias > 0) return false;
          if (!q) return true;
          const c = SC.cliOf(o), a = o.aparelho || {};
          return SC.norm([SC.pad(o.numero), o.numero, c.nome, a.marca, a.modelo, a.imei].join(' ')).includes(q) || (qd && SC.digits(c.telefone).includes(qd));
        }).sort((a, b) => b.numero - a.numero);
        const off = SC.pager(el.querySelector('#npager'), rows.length, st, 25, draw);
        list.innerHTML = rows.length ? `<table class="tbl"><thead><tr><th>Nota / OS</th><th>Conclusão</th><th>Cliente</th><th>Aparelho</th><th>Status</th><th>Garantia</th><th class="num">Total</th><th></th></tr></thead><tbody>${rows.slice(off, off + 25).map(o => {
          const c = SC.cliOf(o), a = o.aparelho || {}, g = SC.notaInfo(o);
          const gar = g.dias > 0 ? `${SC.badge(g.vigente ? 'Vigente' : 'Vencida', g.vigente ? 'b-ok' : 'b-bad')}<small>${g.dias} dias · até ${g.ate ? SC.fmtDate(g.ate) : '—'}</small>` : '<small>Sem garantia</small>';
          return `<tr data-id="${o.id}"><td><b>#${SC.pad(o.numero)}</b></td><td>${SC.fmtDate(String(o.dataConclusao || '').slice(0, 10))}</td><td>${esc(c.nome)}<small>${esc(c.telefone || '')}</small></td><td>${esc([a.marca, a.modelo].filter(Boolean).join(' '))}<small>${esc(a.tipo || '')}${a.imei ? ' · ' + esc(a.imei) : ''}</small></td>
            <td>${SC.badge(o.status, o.status === 'Entregue' ? 'b-ok' : 'b-info')}</td><td>${gar}</td><td class="num">${SC.money(o.total)}</td>
            <td class="actions"><button class="btn ghost sm" data-act="print" title="Imprimir nota com termo de garantia">${icon('print', 16)} Imprimir</button><button class="btn ghost sm wa-ic" data-act="wa" title="Enviar nota por WhatsApp">${icon('whats', 16)} WhatsApp</button>${edit && o.status === 'Concluído' ? `<button class="btn ghost sm" data-act="entregar" title="Registrar a entrega do aparelho">${icon('check', 16)} Entregue</button>` : ''}<button class="btn ghost icon sm" data-act="os" title="Abrir a OS" aria-label="Abrir OS">${icon('eye', 16)}</button></td></tr>`;
        }).join('')}</tbody></table>` : SC.empty('Nenhuma nota de serviço. As notas aparecem quando uma OS é marcada como Concluída.', 'file');
      };
      draw();
      el.querySelector('#nq').addEventListener('input', SC.debounce(e => { st.q = e.target.value; st.page = 1; draw(); }, 150));
      el.querySelector('#ns').addEventListener('change', e => { st.status = e.target.value; st.page = 1; draw(); });
      el.querySelector('#ng').addEventListener('change', e => { st.garantia = e.target.value; st.page = 1; draw(); });
      list.addEventListener('click', async e => {
        const b = e.target.closest('[data-act]'); if (!b) return;
        const id = b.closest('tr').dataset.id, o = SC.byId('os', id);
        if (b.dataset.act === 'print') SC.print.nota(id);
        else if (b.dataset.act === 'wa') SC.whats.nota(id);
        else if (b.dataset.act === 'os') SC.pages.os.open(id);
        else if (b.dataset.act === 'entregar') {
          const old = o.status; o.status = 'Entregue'; SC.osApplyStatus(o, old);
          SC.log('os', `OS #${SC.pad(o.numero)}: ${old} → ${o.status} (via nota de serviço)`);
          if (!await SC.save()) return;
          SC.toast(`OS #${SC.pad(o.numero)} registrada como entregue.`); SC.refresh();
        }
      });
    }
  };
})();
