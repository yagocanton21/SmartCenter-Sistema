/* orcamentos.js – Orçamentos (aprovado pode virar OS) */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon, f = SC.f;
  const st = { q: '', status: '', page: 1 };

  const P = (SC.pages.orcamentos = {
    title: 'Orçamentos',
    state: st,
    render(el) {
      const edit = SC.can('orcamentos');
      el.innerHTML = `<div class="page-head"><div><h1>Orçamentos</h1><p>Proposta de serviço para aprovação do cliente. Orçamento aprovado vira OS sem redigitar.</p></div>${edit ? `<button class="btn primary" data-new>${icon('plus')} Novo orçamento</button>` : ''}</div>
        <div class="card"><div class="toolbar"><div class="search">${icon('search', 16)}<input type="search" id="oq" placeholder="Buscar por nº, cliente ou aparelho…" value="${esc(st.q)}"></div>
        <select id="os2" aria-label="Filtrar por status"><option value="">Todos os status</option>${SC.STATUS_ORC.map(s => `<option${s === st.status ? ' selected' : ''}>${s}</option>`).join('')}</select></div>
        <div class="table-wrap" id="olist"></div><div class="pager" id="opager"></div></div>`;
      const list = el.querySelector('#olist');
      const draw = () => {
        const q = SC.norm(st.q).trim(), t = SC.today();
        const rows = SC.db.orcamentos.filter(o => {
          if (st.status && o.status !== st.status) return false;
          if (!q) return true;
          const a = o.aparelho || {};
          return SC.norm([SC.pad(o.numero), o.numero, SC.cliOf(o).nome, a.marca, a.modelo].join(' ')).includes(q);
        }).sort((a, b) => b.numero - a.numero);
        const off = SC.pager(el.querySelector('#opager'), rows.length, st, 25, draw);
        list.innerHTML = rows.length ? `<table class="tbl"><thead><tr><th>Nº</th><th>Data</th><th>Cliente</th><th>Aparelho</th><th>Validade</th><th>Status</th><th class="num">Total</th><th></th></tr></thead><tbody>${rows.slice(off, off + 25).map(o => {
          const a = o.aparelho || {}, venc = o.status === 'Pendente' && o.validade && o.validade < t;
          return `<tr data-id="${o.id}"><td><b>#${SC.pad(o.numero)}</b></td><td>${SC.fmtDate(o.data)}</td><td>${esc(SC.cliOf(o).nome)}<small>${esc(SC.cliOf(o).telefone || '')}</small></td><td>${esc([a.marca, a.modelo].filter(Boolean).join(' '))}</td>
          <td>${SC.fmtDate(o.validade)}${venc ? ' ' + SC.badge('Vencido', 'b-bad') : ''}</td>
          <td>${edit ? `<select class="status-sel ${SC.statusClass(o.status)}" data-status aria-label="Status do orçamento">${SC.STATUS_ORC.map(s => `<option${s === o.status ? ' selected' : ''}>${s}</option>`).join('')}</select>` : SC.badge(o.status)}</td><td class="num">${SC.money(o.total)}</td>
          <td class="actions">${o.status === 'Aprovado' && SC.can('os') ? (o.osId && SC.byId('os', o.osId) ? `<button class="btn sm" data-act="vos">OS #${SC.pad(SC.byId('os', o.osId).numero)}</button>` : `<button class="btn sm primary" data-act="gos">${icon('arrow', 15)} Gerar OS</button>`) : ''}
          <button class="btn ghost icon sm" data-act="edit" title="${edit ? 'Editar' : 'Consultar'}" aria-label="Abrir orçamento">${icon(edit ? 'edit' : 'eye', 16)}</button><button class="btn ghost icon sm" data-act="print" title="Imprimir" aria-label="Imprimir orçamento">${icon('print', 16)}</button>${SC.can('excluir') ? `<button class="btn ghost icon sm" data-act="del" title="Excluir" aria-label="Excluir orçamento">${icon('trash', 16)}</button>` : ''}</td></tr>`;
        }).join('')}</tbody></table>` : SC.empty('Nenhum orçamento encontrado.', 'file');
      };
      draw();
      el.querySelector('#oq').addEventListener('input', SC.debounce(e => { st.q = e.target.value; st.page = 1; draw(); }, 150));
      el.querySelector('#os2').addEventListener('change', e => { st.status = e.target.value; st.page = 1; draw(); });
      const nb = el.querySelector('[data-new]'); if (nb) nb.onclick = () => P.form();
      list.addEventListener('click', async e => {
        const b = e.target.closest('[data-act]'); if (!b) return;
        const id = b.closest('tr').dataset.id, o = SC.byId('orcamentos', id), a = b.dataset.act;
        if (a === 'edit') P.form(o);
        else if (a === 'print') SC.print.orc(id);
        else if (a === 'gos') P.toOS(o);
        else if (a === 'vos') SC.pages.os.open(o.osId);
        else if (a === 'del' && await SC.confirm(`Excluir o orçamento <b>#${SC.pad(o.numero)}</b>? Esta ação não pode ser desfeita.`, { danger: true, ok: 'Excluir' })) {
          SC.db.orcamentos = SC.db.orcamentos.filter(x => x.id !== id);
          SC.log('orcamento', `Orçamento #${SC.pad(o.numero)} excluído`); SC.save(); SC.toast('Orçamento excluído.'); SC.refresh();
        }
      });
      list.addEventListener('change', e => {
        const s = e.target.closest('[data-status]'); if (!s) return;
        const o = SC.byId('orcamentos', s.closest('tr').dataset.id), old = o.status;
        o.status = s.value; SC.log('orcamento', `Orçamento #${SC.pad(o.numero)}: ${old} → ${o.status}`); SC.save(); SC.toast(`Orçamento #${SC.pad(o.numero)} ${o.status.toLowerCase()}.`); SC.refresh();
      });
    },
    open(id) { const o = SC.byId('orcamentos', id); if (o) P.form(o); },

    /* Orçamento aprovado → abre a OS já preenchida */
    toOS(q) {
      SC.pages.os.form(null, {
        orcamentoId: q.id, clienteId: q.clienteId, cliSnap: q.cliSnap,
        aparelho: Object.assign({}, q.aparelho), diagnostico: q.diagnostico, pecas: (q.pecas || []).map(x => Object.assign({}, x)),
        maoDeObra: q.maoDeObra, prazo: '', observacoes: q.observacoes
      });
    },

    form(q) {
      const isNew = !q, o = q || {}, ap = o.aparelho || {};
      const cli = o.clienteId ? (SC.byId('clientes', o.clienteId) || o.cliSnap || {}) : (o.cliSnap || {});
      const m = SC.modal({
        title: isNew ? 'Novo orçamento' : `Orçamento #${SC.pad(q.numero)}`, size: 'xl',
        body: `<form class="grid" autocomplete="off">
          <h4 class="sec s12">Cliente</h4>${SC.clientFields(Object.assign({}, cli, { id: o.clienteId || cli.id }))}
          <h4 class="sec s12">Aparelho e defeito</h4>
          ${f.sel('Tipo', 'tipo', SC.APARELHOS, ap.tipo || 'Celular', { s: 4 })}${f.in('Marca', 'marca', ap.marca, { s: 4, req: 1 })}${f.in('Modelo', 'modelo', ap.modelo, { s: 4, req: 1 })}
          ${f.area('Descrição do defeito <b class="req">*</b>', 'defeito', ap.defeito, { s: 6, rows: 2 })}${f.area('Diagnóstico', 'diagnostico', o.diagnostico, { s: 6, rows: 2 })}
          <h4 class="sec s12">Valores</h4>
          <div class="s12"><span class="lbl">Peças necessárias</span>${SC.linesHTML(o.pecas)}</div>
          ${f.money('Valor da mão de obra', 'maoDeObra', o.maoDeObra || 0, { s: 3 })}
          <div class="f s3"><span>Valor das peças</span><output class="out" id="vpecas">R$ 0,00</output></div>
          <div class="f s6"><span>Valor total</span><output class="out big" id="vtotal">R$ 0,00</output></div>
          ${f.in('Data', 'data', (o.data || SC.today()).slice(0, 10), { s: 3, type: 'date' })}${f.in('Validade do orçamento', 'validade', o.validade || SC.addDays(SC.today(), 7), { s: 3, type: 'date' })}${f.sel('Status', 'status', SC.STATUS_ORC, o.status || 'Pendente', { s: 3 })}
          ${f.area('Observações', 'observacoes', o.observacoes, { s: 12, rows: 2 })}
        </form>`,
        footer: `<button type="button" class="btn" data-close>Cancelar</button>${isNew ? '' : `<button type="button" class="btn" data-pr>${icon('print', 16)} Imprimir</button>`}${!isNew && o.status === 'Aprovado' && SC.can('os') && !o.osId ? `<button type="button" class="btn navy" data-gos>${icon('arrow', 16)} Gerar OS</button>` : ''}<button type="button" class="btn" data-save>Salvar</button><button type="button" class="btn primary" data-savepr>${icon('print', 16)} Salvar e imprimir</button>`
      });
      const body = m.body;
      SC.bindClientPicker(body); SC.bindLines(body);
      const upd = () => {
        const vp = SC.sumLines(SC.readLines(body)), mo = SC.parseMoney(body.querySelector('[name=maoDeObra]').value);
        body.querySelector('#vpecas').textContent = SC.money(vp); body.querySelector('#vtotal').textContent = SC.money(vp + mo);
      };
      body.addEventListener('input', upd); body.addEventListener('focusout', upd); upd();
      body.querySelector('form').addEventListener('submit', e => e.preventDefault());
      const save = print => {
        const v = SC.vals(body), err = msg => { SC.toast(msg, 'err'); return false; };
        if (!v.c_nome.trim()) return err('Informe o nome do cliente.');
        if (!SC.validDoc(v.c_doc)) return err('CPF/CNPJ inválido. Confira os números ou deixe em branco.');
        if (!v.marca.trim() || !v.modelo.trim()) return err('Informe a marca e o modelo do aparelho.');
        if (!v.defeito.trim()) return err('Descreva o defeito.');
        const c = SC.upsertClient(v), pecas = SC.readLines(body), mo = SC.r2(SC.parseMoney(v.maoDeObra)), vp = SC.sumLines(pecas);
        const base = q || { id: SC.uid(), numero: SC.nextNum('orcamento'), osId: null };
        Object.assign(base, {
          data: v.data + 'T' + ((q && q.data ? q.data.slice(11, 19) : SC.nowISO().slice(11, 19)) || '00:00:00'), clienteId: c.id, cliSnap: SC.snap(c),
          aparelho: { tipo: v.tipo, marca: v.marca.trim(), modelo: v.modelo.trim(), defeito: v.defeito.trim() },
          diagnostico: v.diagnostico.trim(), pecas, maoDeObra: mo, valorPecas: vp, total: SC.r2(mo + vp), validade: v.validade, observacoes: v.observacoes.trim(), status: v.status
        });
        if (isNew) SC.db.orcamentos.unshift(base);
        SC.log('orcamento', `Orçamento #${SC.pad(base.numero)} ${isNew ? 'criado' : 'atualizado'} – ${c.nome}`);
        SC.save(); m.close(); SC.refresh(); SC.toast(`Orçamento #${SC.pad(base.numero)} salvo.`);
        if (print) SC.print.orc(base.id);
        return true;
      };
      m.el.addEventListener('click', e => {
        if (e.target.closest('[data-save]')) save(false);
        else if (e.target.closest('[data-savepr]')) save(true);
        else if (e.target.closest('[data-pr]')) SC.print.orc(q.id);
        else if (e.target.closest('[data-gos]')) { m.close(); P.toOS(q); }
      });
    }
  });
})();
