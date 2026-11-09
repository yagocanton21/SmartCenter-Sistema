/* os.js – Ordens de Serviço */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon, f = SC.f;
  const st = { q: '', status: '', page: 1 };
  const FIM = ['Concluído', 'Entregue'];

  /* Efeitos de mudança de status: datas, histórico e baixa de estoque */
  SC.osApplyStatus = (o, old) => {
    o.historico = o.historico || [];
    if (o.status !== old) o.historico.push({ status: o.status, data: SC.nowISO(), usuario: SC.user ? SC.user.nome : '—' });
    if (FIM.includes(o.status)) {
      if (!o.dataConclusao) o.dataConclusao = SC.nowISO();
      if (!o.estoqueBaixado) { o.baixaEstoque = SC.baixaEstoque(o.pecas); o.estoqueBaixado = true; }
    } else {
      o.dataConclusao = null;
      if (o.estoqueBaixado) { SC.estornaEstoque(o.baixaEstoque); o.baixaEstoque = []; o.estoqueBaixado = false; }
    }
    o.dataEntrega = o.status === 'Entregue' ? (o.dataEntrega || SC.nowISO()) : null;
  };
  const estorna = o => { if (o.estoqueBaixado) { SC.estornaEstoque(o.baixaEstoque); o.baixaEstoque = []; o.estoqueBaixado = false; } };

  const P = (SC.pages.os = {
    title: 'Ordens de serviço',
    state: st,
    render(el) {
      const edit = SC.can('os');
      el.innerHTML = `<div class="page-head"><div><h1>Ordens de serviço</h1><p>Entrada, diagnóstico, reparo e entrega dos aparelhos.</p></div>${edit ? `<button class="btn primary" data-new>${icon('plus')} Nova OS</button>` : ''}</div>
        <div class="card"><div class="toolbar"><div class="search">${icon('search', 16)}<input type="search" id="osq" placeholder="Buscar por nº, cliente, modelo, IMEI ou telefone…" value="${esc(st.q)}"></div>
        <select id="oss" aria-label="Filtrar por status"><option value="">Todos os status</option><option value="atrasadas"${st.status === 'atrasadas' ? ' selected' : ''}>⚠️ Apenas atrasadas</option>${SC.STATUS_OS.map(s => `<option${s === st.status ? ' selected' : ''}>${s}</option>`).join('')}</select></div>
        <div class="table-wrap" id="oslist"></div><div class="pager" id="ospager"></div></div>`;
      const list = el.querySelector('#oslist');
      const draw = () => {
        const q = SC.norm(st.q).trim(), qd = SC.digits(st.q), t = SC.today();
        const rows = SC.db.os.filter(o => {
          if (st.status === 'atrasadas') {
            if (!(o.prazo && o.prazo < t && !FIM.includes(o.status))) return false;
          } else if (st.status && o.status !== st.status) {
            return false;
          }
          if (!q) return true;
          const c = SC.cliOf(o), a = o.aparelho || {};
          return SC.norm([SC.pad(o.numero), o.numero, c.nome, a.marca, a.modelo, a.imei, c.doc].join(' ')).includes(q) || (qd && SC.digits(c.telefone).includes(qd));
        }).sort((a, b) => b.numero - a.numero);
        const off = SC.pager(el.querySelector('#ospager'), rows.length, st, 25, draw);
        list.innerHTML = rows.length ? `<table class="tbl"><thead><tr><th>Nº</th><th>Entrada</th><th>Cliente</th><th>Aparelho</th><th>Status</th><th>Prazo</th><th class="num">Total</th><th></th></tr></thead><tbody>${rows.slice(off, off + 25).map(o => {
          const c = SC.cliOf(o), a = o.aparelho || {}, late = o.prazo && o.prazo < t && !FIM.includes(o.status);
          return `<tr data-id="${o.id}"><td><b>#${SC.pad(o.numero)}</b></td><td>${SC.fmtDate(o.dataEntrada)}</td><td>${esc(c.nome)}<small>${esc(c.telefone || '')}</small></td><td>${esc([a.marca, a.modelo].filter(Boolean).join(' '))}<small>${esc(a.tipo || '')}${a.imei ? ' · ' + esc(a.imei) : ''}</small></td>
          <td>${edit ? `<select class="status-sel ${SC.statusClass(o.status)}" data-status aria-label="Status da OS ${SC.pad(o.numero)}">${SC.STATUS_OS.map(s => `<option${s === o.status ? ' selected' : ''}>${s}</option>`).join('')}</select>` : SC.badge(o.status, 'b-info')}</td>
          <td>${o.prazo ? SC.fmtDate(o.prazo) : '—'}${late ? ' ' + SC.badge('Atrasada', 'b-bad') : ''}</td><td class="num">${SC.money(o.total)}</td>
          <td class="actions"><button class="btn ghost icon sm" data-act="edit" title="${edit ? 'Editar' : 'Consultar'}" aria-label="Abrir OS">${icon(edit ? 'edit' : 'eye', 16)}</button><button class="btn ghost icon sm" data-act="print" title="Imprimir" aria-label="Imprimir OS">${icon('print', 16)}</button>${SC.can('excluir') ? `<button class="btn ghost icon sm" data-act="del" title="Excluir" aria-label="Excluir OS">${icon('trash', 16)}</button>` : ''}</td></tr>`;
        }).join('')}</tbody></table>` : SC.empty('Nenhuma ordem de serviço encontrada.', 'wrench');
      };
      draw();
      el.querySelector('#osq').addEventListener('input', SC.debounce(e => { st.q = e.target.value; st.page = 1; draw(); }, 150));
      el.querySelector('#oss').addEventListener('change', async e => { st.status = e.target.value; st.page = 1; draw(); });
      const nb = el.querySelector('[data-new]'); if (nb) nb.onclick = () => P.form();
      list.addEventListener('click', async e => {
        const b = e.target.closest('[data-act]'); if (!b) return;
        const id = b.closest('tr').dataset.id, o = SC.byId('os', id);
        if (b.dataset.act === 'edit') P.form(o);
        else if (b.dataset.act === 'print') SC.print.os(id);
        else if (b.dataset.act === 'del' && await SC.confirm(`Excluir a OS <b>#${SC.pad(o.numero)}</b> de ${esc(SC.cliOf(o).nome)}? Esta ação não pode ser desfeita.`, { danger: true, ok: 'Excluir' })) {
          estorna(o);
          SC.db.orcamentos.forEach(q => { if (q.osId === o.id) q.osId = null; });
          SC.db.os = SC.db.os.filter(x => x.id !== id);
          SC.log('os', `OS #${SC.pad(o.numero)} excluída`); if (!await SC.save()) return; SC.toast('OS excluída.'); SC.refresh();
        }
      });
      list.addEventListener('change', async e => {
        const s = e.target.closest('[data-status]'); if (!s) return;
        const o = SC.byId('os', s.closest('tr').dataset.id), old = o.status, novoStatus = s.value;
        if (FIM.includes(novoStatus) && !FIM.includes(old)) {
          const need = {};
          (o.pecas || []).forEach(i => { if (i.produtoId) need[i.produtoId] = (need[i.produtoId] || 0) + i.qtd; });
          for (const pid in need) {
            const p = SC.byId('produtos', pid);
            if (p && p.controla && p.estoque < need[pid]) {
              s.value = old;
              return SC.toast(`Estoque insuficiente de "${p.nome}": disponível ${p.estoque}, necessário ${need[pid]}.`, 'err');
            }
          }
        }
        o.status = novoStatus; SC.osApplyStatus(o, old);
        SC.log('os', `OS #${SC.pad(o.numero)}: ${old} → ${o.status}`); if (!await SC.save()) return; SC.toast(`OS #${SC.pad(o.numero)} agora está "${o.status}".`); SC.refresh();
      });
    },
    open(id) { const o = SC.byId('os', id); if (o) P.form(o); },

    form(os, pre) {
      const idempotencyKey = SC.uuid ? SC.uuid() : ('idemp_os_' + Date.now() + '_' + Math.random().toString(36).slice(2, 9));
      const isNew = !os, o = os || pre || {}, ap = o.aparelho || {};
      const cli = o.clienteId ? (SC.byId('clientes', o.clienteId) || o.cliSnap || {}) : (o.cliSnap || {});
      const status = o.status || 'Recebido';
      const dEnt = (o.dataEntrada || SC.today()).slice(0, 10);
      const m = SC.modal({
        title: isNew ? 'Nova ordem de serviço' : `Ordem de serviço #${SC.pad(os.numero)}`, size: 'xl',
        body: `<form id="osf" class="grid" autocomplete="off">
          <datalist id="dl-estado"><option>Bom estado</option><option>Arranhões leves</option><option>Tela trincada</option><option>Carcaça amassada</option><option>Oxidado / molhado</option><option>Sem tampa traseira</option></datalist>
          <h4 class="sec s12">Cliente</h4>${SC.clientFields(Object.assign({}, cli, { id: o.clienteId || cli.id }))}
          <h4 class="sec s12">Aparelho</h4>
          ${f.sel('Tipo', 'tipo', SC.APARELHOS, ap.tipo || 'Celular', { s: 3 })}${f.in('Marca', 'marca', ap.marca, { s: 3, req: 1 })}${f.in('Modelo', 'modelo', ap.modelo, { s: 3, req: 1 })}${f.in('IMEI / nº de série', 'imei', ap.imei, { s: 3 })}
          ${f.in('Cor', 'cor', ap.cor, { s: 3 })}${SC.senhaHTML ? SC.senhaHTML(ap) : f.in('Senha / padrão de desbloqueio', 'senha', ap.senha, { s: 3 })}${f.in('Acessórios recebidos', 'acessorios', ap.acessorios, { s: 12, ph: 'Ex.: carregador, capa, chip, cartão de memória' })}
          ${f.in('Estado de conservação', 'estado', ap.estado, { s: 12, ph: 'Ex.: arranhões leves na carcaça, tela sem trincos', attrs: 'list="dl-estado"' })}
          ${f.area('Defeito relatado pelo cliente <b class="req">*</b>', 'defeito', ap.defeito, { rows: 2 })}
          <div class="s12 ckwrap" ${(SC.usaChecklist && SC.usaChecklist(ap.tipo || 'Celular')) ? '' : 'hidden'}><h4 class="sec">Checklist de entrada (celular / tablet)</h4>${SC.checklistHTML ? SC.checklistHTML(o.checklist, o.checklistObs) : ''}</div>
          <h4 class="sec s12">Laudo técnico</h4>
          ${f.area('Diagnóstico técnico', 'diagnostico', o.diagnostico, { s: 6, rows: 3 })}${f.area('Serviço realizado', 'servico', o.servico, { s: 6, rows: 3 })}
          <div class="s12"><span class="lbl">Peças utilizadas</span>${SC.linesHTML(o.pecas)}</div>
          ${f.money('Valor da mão de obra', 'maoDeObra', o.maoDeObra || 0, { s: 3 })}
          <div class="f s3"><span>Valor das peças</span><output class="out" id="vpecas">R$ 0,00</output></div>
          <div class="f s6"><span>Valor total</span><output class="out big" id="vtotal">R$ 0,00</output></div>
          <h4 class="sec s12">Entrega e garantia</h4>
          ${f.sel('Status', 'status', SC.STATUS_OS, status, { s: 3 })}${f.in('Data de entrada', 'dataEntrada', dEnt, { s: 3, type: 'date' })}${f.in('Prazo de entrega', 'prazo', o.prazo || '', { s: 3, type: 'date' })}${f.in('Garantia (dias)', 'garantiaDias', o.garantiaDias != null ? o.garantiaDias : SC.db.config.garantiaPadraoDias, { s: 3, type: 'number', attrs: 'min="0" step="1"' })}
          ${f.sel('Forma de pagamento', 'formaPagamento', [['', 'A definir']].concat(SC.PAGAMENTOS.map(p => [p, p])), o.formaPagamento || '', { s: 4 })}
          ${f.area('Observações', 'observacoes', o.observacoes, { s: 8, rows: 2 })}
        </form>`,
        footer: `<button type="button" class="btn" data-close>Cancelar</button>${isNew ? '' : `<button type="button" class="btn" data-pr>${icon('print', 16)} Imprimir</button>`}<button type="button" class="btn" data-save>Salvar</button><button type="button" class="btn primary" data-savepr>${icon('print', 16)} Salvar e imprimir</button>`
      });
      const body = m.body;
      SC.bindClientPicker(body); SC.bindLines(body);
      if (SC.bindSenha) SC.bindSenha(body);
      if (SC.bindChecklist) SC.bindChecklist(body);
      const ckw = body.querySelector('.ckwrap'), tipoSel = body.querySelector('[name=tipo]');
      if (ckw && tipoSel && SC.usaChecklist) {
        tipoSel.addEventListener('change', () => { ckw.hidden = !SC.usaChecklist(tipoSel.value); });
      }
      const upd = () => {
        const vp = SC.sumLines(SC.readLines(body)), mo = SC.parseMoney(body.querySelector('[name=maoDeObra]').value);
        body.querySelector('#vpecas').textContent = SC.money(vp); body.querySelector('#vtotal').textContent = SC.money(vp + mo);
      };
      body.addEventListener('input', upd); body.addEventListener('focusout', upd); upd();
      body.querySelector('#osf').addEventListener('submit', e => e.preventDefault());

      const save = async print => {
        const btns = body.closest('.modal').querySelectorAll('[data-save], [data-savepr]');
        const unlock = () => btns.forEach(b => { b.disabled = false; if (b.dataset.oldTxt) b.textContent = b.dataset.oldTxt; });
        btns.forEach(b => { b.disabled = true; b.dataset.oldTxt = b.textContent; b.textContent = 'Processando...'; });

        const v = SC.vals(body), err = msg => { unlock(); SC.toast(msg, 'err'); return false; };
        if (!v.c_nome.trim()) return err('Informe o nome do cliente.');
        if (!SC.validDoc(v.c_doc)) return err('CPF/CNPJ inválido. Confira os números ou deixe em branco.');
        if (!v.marca.trim() || !v.modelo.trim()) return err('Informe a marca e o modelo do aparelho.');
        if (!v.defeito.trim()) return err('Descreva o defeito relatado pelo cliente.');
        const c = SC.upsertClient(v);
        const pecas = SC.readLines(body), mo = SC.r2(SC.parseMoney(v.maoDeObra)), vp = SC.sumLines(pecas);
        let base = os, old = null;
        if (base) { old = base.status; estorna(base); }
        else base = { id: SC.uid(), numero: SC.nextNum('os'), historico: [], baixaEstoque: [], estoqueBaixado: false, orcamentoId: o.orcamentoId || null };

        Object.assign(base, {
          dataEntrada: v.dataEntrada + 'T' + ((os && os.dataEntrada ? os.dataEntrada.slice(11, 19) : SC.nowISO().slice(11, 19)) || '00:00:00'),
          clienteId: c.id, cliSnap: SC.snap(c),
          aparelho: {
            tipo: v.tipo,
            marca: v.marca.trim(),
            modelo: v.modelo.trim(),
            imei: v.imei.trim(),
            cor: v.cor.trim(),
            senhaTipo: v.senhaTipo,
            senha: v.senhaTipo === 'alfa' ? (v.senha || '').trim() : '',
            senhaPadrao: v.senhaTipo === 'padrao' ? v.senhaPadrao : '',
            acessorios: v.acessorios.trim(),
            estado: v.estado.trim(),
            defeito: v.defeito.trim()
          },
          diagnostico: v.diagnostico.trim(),
          servico: v.servico.trim(),
          pecas,
          maoDeObra: mo,
          valorPecas: vp,
          total: SC.r2(mo + vp),
          checklist: (SC.usaChecklist && SC.usaChecklist(v.tipo) && SC.readChecklist) ? SC.readChecklist(body) : null,
          checklistObs: (SC.usaChecklist && SC.usaChecklist(v.tipo)) ? (v.ckObs || '').trim() : '',
          prazo: v.prazo,
          garantiaDias: Math.max(0, parseInt(v.garantiaDias) || 0),
          formaPagamento: v.formaPagamento,
          observacoes: v.observacoes.trim(),
          status: v.status
        });
        SC.osApplyStatus(base, old);

        if (isNew) SC.db.os.unshift(base);
        if (!await SC.save()) { unlock(); return false; }

        if (isNew) {
          SC.log('os', `OS #${SC.pad(base.numero)} aberta para ${c.nome} (${base.aparelho.marca} ${base.aparelho.modelo})`);
        } else {
          SC.log('os', `OS #${SC.pad(base.numero)} atualizada`);
        }
        m.close(); SC.refresh();
        SC.toast(`OS #${SC.pad(base.numero)} salva.`);
        if (print) SC.print.os(base.id);
        return true;
      };
      body.closest('.modal').addEventListener('click', e => {
        if (e.target.closest('[data-save]')) save(false);
        else if (e.target.closest('[data-savepr]')) save(true);
        else if (e.target.closest('[data-pr]')) SC.print.os(os.id);
      });
    }
  });
})();
