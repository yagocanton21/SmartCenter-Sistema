/* clientes.js – cadastro centralizado de clientes com histórico */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon, f = SC.f;
  const st = { q: '', page: 1 };
  const hist = id => ({
    os: SC.db.os.filter(o => o.clienteId === id).sort((a, b) => b.numero - a.numero),
    vendas: SC.db.vendas.filter(v => v.clienteId === id).sort((a, b) => b.numero - a.numero),
    orc: SC.db.orcamentos.filter(o => o.clienteId === id).sort((a, b) => b.numero - a.numero)
  });

  const C = (SC.pages.clientes = {
    title: 'Clientes',
    state: st,
    render(el) {
      const edit = SC.can('clientes');
      el.innerHTML = `<div class="page-head"><div><h1>Clientes</h1><p>Cadastro único com histórico de ordens de serviço, compras e orçamentos.</p></div>${edit ? `<button class="btn primary" data-new>${icon('plus')} Novo cliente</button>` : ''}</div>
        <div class="card"><div class="toolbar"><div class="search">${icon('search', 16)}<input type="search" id="cq" placeholder="Buscar por nome, telefone, CPF/CNPJ ou e-mail…" value="${esc(st.q)}"></div></div><div class="table-wrap" id="clist"></div><div class="pager" id="cpager"></div></div>`;
      const list = el.querySelector('#clist');
      const draw = () => {
        const q = SC.norm(st.q).trim(), qd = SC.digits(st.q);
        const rows = SC.db.clientes.filter(c => !q || SC.norm([c.nome, c.email, c.cidade].join(' ')).includes(q) || (qd && (SC.digits(c.telefone).includes(qd) || SC.digits(c.whatsapp).includes(qd) || SC.digits(c.doc).includes(qd)))).sort((a, b) => a.nome.localeCompare(b.nome));
        const off = SC.pager(el.querySelector('#cpager'), rows.length, st, 25, draw);
        list.innerHTML = rows.length ? `<table class="tbl"><thead><tr><th>Cliente</th><th>Telefone</th><th>CPF / CNPJ</th><th>Cidade</th><th class="num">OS</th><th class="num">Compras</th><th></th></tr></thead><tbody>${rows.slice(off, off + 25).map(c => {
          const h = hist(c.id), gasto = h.vendas.filter(v => v.status !== 'Cancelada').reduce((a, v) => a + v.total, 0);
          return `<tr data-id="${c.id}"><td><b>${esc(c.nome)}</b><small>${esc(c.email || '')}</small></td><td>${esc(c.telefone || '—')}</td><td>${esc(c.doc || '—')}</td><td>${esc(c.cidade || '—')}</td><td class="num">${h.os.length}</td><td class="num">${SC.money(gasto)}</td>
          <td class="actions"><button class="btn ghost icon sm" data-act="view" title="Ver ficha" aria-label="Ver ficha do cliente">${icon('eye', 16)}</button>${edit ? `<button class="btn ghost icon sm" data-act="edit" title="Editar" aria-label="Editar cliente">${icon('edit', 16)}</button>` : ''}${SC.can('excluir') ? `<button class="btn ghost icon sm" data-act="del" title="Excluir" aria-label="Excluir cliente">${icon('trash', 16)}</button>` : ''}</td></tr>`;
        }).join('')}</tbody></table>` : SC.empty('Nenhum cliente encontrado.', 'users');
      };
      draw();
      el.querySelector('#cq').addEventListener('input', SC.debounce(e => { st.q = e.target.value; st.page = 1; draw(); }, 150));
      const nb = el.querySelector('[data-new]'); if (nb) nb.onclick = () => C.form();
      list.addEventListener('click', async e => {
        const b = e.target.closest('[data-act]'); if (!b) return;
        const id = b.closest('tr').dataset.id, c = SC.byId('clientes', id);
        if (b.dataset.act === 'view') C.view(c);
        else if (b.dataset.act === 'edit') C.form(c);
        else if (b.dataset.act === 'del') {
          const h = hist(id);
          if (h.os.length + h.vendas.length + h.orc.length) return SC.toast('Este cliente possui histórico (OS, vendas ou orçamentos) e não pode ser excluído.', 'err');
          if (await SC.confirm(`Excluir o cliente <b>${esc(c.nome)}</b>?`, { danger: true, ok: 'Excluir' })) { SC.db.clientes = SC.db.clientes.filter(x => x.id !== id); SC.log('cliente', `Cliente excluído: ${c.nome}`); if (!await SC.save()) return; SC.toast('Cliente excluído.'); SC.refresh(); }
        }
      });
    },
    open(id) { const c = SC.byId('clientes', id); if (c) C.view(c); },

    view(c) {
      const h = hist(c.id), wa = SC.wa(c.whatsapp || c.telefone);
      const tbl = (head, rows, empty) => rows.length ? `<div class="table-wrap"><table class="tbl"><thead><tr>${head.map(x => `<th>${x}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>` : SC.empty(empty);
      const m = SC.modal({
        title: esc(c.nome), size: 'lg',
        body: `<div class="tabs"><button class="on" data-tab="d">Dados</button><button data-tab="o">Ordens de serviço (${h.os.length})</button><button data-tab="v">Compras (${h.vendas.length})</button><button data-tab="q">Orçamentos (${h.orc.length})</button></div>
        <div data-p="d"><div class="kv"><div><span>Telefone</span><b>${esc(c.telefone || '—')}</b></div><div><span>WhatsApp</span><b>${esc(c.whatsapp || '—')}</b></div><div><span>E-mail</span><b>${esc(c.email || '—')}</b></div><div><span>CPF / CNPJ</span><b>${esc(c.doc || '—')}</b></div><div><span>CEP</span><b>${esc(c.cep || '—')}</b></div><div><span>Cidade</span><b>${esc(c.cidade || '—')}</b></div><div class="wide"><span>Endereço</span><b>${esc(c.endereco || '—')}</b></div><div class="wide"><span>Observações</span><b>${esc(c.obs || '—')}</b></div><div><span>Cliente desde</span><b>${SC.fmtDate(c.criadoEm)}</b></div></div></div>
        <div data-p="o" hidden>${tbl(['Nº', 'Entrada', 'Aparelho', 'Status', 'Total'], h.os.map(o => `<tr class="row-click" data-open="os:${o.id}"><td><b>#${SC.pad(o.numero)}</b></td><td>${SC.fmtDate(o.dataEntrada)}</td><td>${esc((o.aparelho.marca || '') + ' ' + (o.aparelho.modelo || ''))}</td><td>${SC.badge(o.status)}</td><td class="num">${SC.money(o.total)}</td></tr>`), 'Nenhuma ordem de serviço.')}</div>
        <div data-p="v" hidden>${tbl(['Nº', 'Data', 'Itens', 'Pagamento', 'Total'], h.vendas.map(v => `<tr class="row-click" data-open="venda:${v.id}"><td><b>#${SC.pad(v.numero)}</b></td><td>${SC.fmtDT(v.data)}</td><td>${esc(v.itens.map(i => i.descricao).join(', '))}</td><td>${esc(v.formaPagamento)}</td><td class="num">${SC.money(v.total)}${v.status === 'Cancelada' ? ' ' + SC.badge('Cancelada', 'b-bad') : ''}</td></tr>`), 'Nenhuma compra registrada.')}</div>
        <div data-p="q" hidden>${tbl(['Nº', 'Data', 'Aparelho', 'Status', 'Total'], h.orc.map(o => `<tr class="row-click" data-open="orc:${o.id}"><td><b>#${SC.pad(o.numero)}</b></td><td>${SC.fmtDate(o.data)}</td><td>${esc((o.aparelho.marca || '') + ' ' + (o.aparelho.modelo || ''))}</td><td>${SC.badge(o.status)}</td><td class="num">${SC.money(o.total)}</td></tr>`), 'Nenhum orçamento.')}</div>`,
        footer: `<button type="button" class="btn" data-close>Fechar</button>${wa ? `<a class="btn" href="${wa}" target="_blank" rel="noopener">${icon('chat', 16)} WhatsApp</a>` : ''}${SC.can('os') ? `<button type="button" class="btn" data-newos>${icon('wrench', 16)} Nova OS</button>` : ''}${SC.can('clientes') ? `<button type="button" class="btn primary" data-edit>${icon('edit', 16)} Editar</button>` : ''}`
      });
      m.el.addEventListener('click', e => {
        const t = e.target.closest('[data-tab]');
        if (t) { m.el.querySelectorAll('[data-tab]').forEach(x => x.classList.toggle('on', x === t)); m.el.querySelectorAll('[data-p]').forEach(p => { p.hidden = p.dataset.p !== t.dataset.tab; }); return; }
        const r = e.target.closest('[data-open]');
        if (r) { const [type, id] = r.dataset.open.split(':'); m.close(); SC.openRecord(type, id); return; }
        if (e.target.closest('[data-edit]')) { m.close(); C.form(c); }
        else if (e.target.closest('[data-newos]')) { m.close(); SC.pages.os.form(null, { clienteId: c.id, cliSnap: SC.snap(c) }); }
      });
    },

    form(c) {
      const isNew = !c, o = c || {};
      const m = SC.modal({
        title: isNew ? 'Novo cliente' : 'Editar cliente', size: 'md',
        body: `<form class="grid" autocomplete="off">
          ${f.in('Nome completo / Razão social', 'nome', o.nome || '', { s: 12, req: 1 })}
          ${f.in('Telefone', 'telefone', o.telefone || '', { s: 4, attrs: 'data-mask="tel" inputmode="tel"' })}${f.in('WhatsApp', 'whatsapp', o.whatsapp || '', { s: 4, attrs: 'data-mask="tel" inputmode="tel"' })}${f.in('CPF / CNPJ', 'doc', o.doc || '', { s: 4, attrs: 'data-mask="doc" inputmode="numeric"' })}
          ${f.in('E-mail', 'email', o.email || '', { s: 6, type: 'email' })}${f.in('CEP', 'cep', o.cep || '', { s: 3, attrs: 'data-mask="cep" inputmode="numeric"' })}${f.in('Cidade', 'cidade', o.cidade || '', { s: 3 })}
          ${f.in('Endereço (rua, número, bairro)', 'endereco', o.endereco || '', { s: 12 })}
          ${f.area('Observações', 'obs', o.obs || '', { s: 12, rows: 2 })}
        </form>`,
        footer: `<button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn primary" data-save>Salvar cliente</button>`
      });
      m.body.querySelector('form').addEventListener('submit', e => e.preventDefault());
      m.el.querySelector('[data-save]').onclick = async () => {
        const v = SC.vals(m.body);
        if (!v.nome.trim()) return SC.toast('Informe o nome do cliente.', 'err');
        if (!SC.validDoc(v.doc)) return SC.toast('CPF/CNPJ inválido. Confira os números.', 'err');
        const dup = v.doc && SC.db.clientes.find(x => x.id !== (c && c.id) && SC.digits(x.doc) === SC.digits(v.doc));
        if (dup) return SC.toast(`Já existe um cliente com este CPF/CNPJ: ${dup.nome}.`, 'err');
        const base = c || { id: SC.uid(), criadoEm: SC.nowISO() };
        Object.assign(base, { nome: v.nome.trim(), telefone: v.telefone, whatsapp: v.whatsapp || v.telefone, doc: v.doc, email: v.email.trim(), cep: v.cep, cidade: v.cidade.trim(), endereco: v.endereco.trim(), obs: v.obs.trim() });
        if (isNew) SC.db.clientes.push(base);
        SC.log('cliente', `Cliente ${isNew ? 'cadastrado' : 'atualizado'}: ${base.nome}`); if (!await SC.save()) return; m.close(); SC.refresh(); SC.toast('Cliente salvo.');
      };
    }
  });
})();
