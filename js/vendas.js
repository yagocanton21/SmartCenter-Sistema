/* vendas.js – Vendas (PDV, histórico) e Produtos / estoque */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon, f = SC.f;
  const sv = { q: '', de: '', ate: '', status: '', page: 1 };
  const sp = { q: '', cat: '', baixo: false, page: 1 };

  /* ================= VENDAS ================= */
  const V = (SC.pages.vendas = {
    title: 'Vendas',
    state: sv,
    render(el) {
      const edit = SC.can('vendas');
      el.innerHTML = `<div class="page-head"><div><h1>Vendas</h1><p>Celulares, acessórios, peças e serviços com baixa automática de estoque.</p></div>${edit ? `<button class="btn primary" data-new>${icon('plus')} Nova venda</button>` : ''}</div>
        <div class="card"><div class="toolbar"><div class="search">${icon('search', 16)}<input type="search" id="vq" placeholder="Buscar por nº, cliente ou item…" value="${esc(sv.q)}"></div>
        <label class="hint">De <input type="date" id="vde" value="${sv.de}"></label><label class="hint">Até <input type="date" id="vate" value="${sv.ate}"></label>
        <select id="vst" aria-label="Filtrar por situação"><option value="">Todas</option><option${sv.status === 'Concluída' ? ' selected' : ''}>Concluída</option><option${sv.status === 'Cancelada' ? ' selected' : ''}>Cancelada</option></select></div>
        <div class="summary" id="vsum"></div><div class="table-wrap" id="vlist"></div><div class="pager" id="vpager"></div></div>`;
      const list = el.querySelector('#vlist');
      const draw = () => {
        const q = SC.norm(sv.q).trim();
        const rows = SC.db.vendas.filter(v => {
          const d = v.data.slice(0, 10);
          if (sv.de && d < sv.de) return false;
          if (sv.ate && d > sv.ate) return false;
          if (sv.status && v.status !== sv.status) return false;
          if (!q) return true;
          return SC.norm([SC.pad(v.numero), v.numero, SC.cliOf(v).nome, v.itens.map(i => i.descricao).join(' ')].join(' ')).includes(q);
        }).sort((a, b) => b.numero - a.numero);
        const ok = rows.filter(v => v.status !== 'Cancelada'), tot = ok.reduce((a, v) => a + v.total, 0), luc = ok.reduce((a, v) => a + (v.lucro || 0), 0);
        el.querySelector('#vsum').innerHTML = `<div><span>Vendas no período</span><b>${ok.length}</b></div><div><span>Total vendido</span><b>${SC.money(tot)}</b></div><div><span>Lucro estimado</span><b>${SC.money(luc)}</b></div><div><span>Ticket médio</span><b>${SC.money(ok.length ? tot / ok.length : 0)}</b></div>`;
        const off = SC.pager(el.querySelector('#vpager'), rows.length, sv, 25, draw);
        list.innerHTML = rows.length ? `<table class="tbl"><thead><tr><th>Nº</th><th>Data</th><th>Cliente</th><th>Itens</th><th>Pagamento</th><th class="num">Total</th><th>Situação</th><th></th></tr></thead><tbody>${rows.slice(off, off + 25).map(v => `<tr data-id="${v.id}"><td><b>#${SC.pad(v.numero)}</b></td><td>${SC.fmtDT(v.data)}</td><td>${esc(SC.cliOf(v).nome)}</td>
          <td>${esc(v.itens.slice(0, 2).map(i => i.qtd + '× ' + i.descricao).join(', '))}${v.itens.length > 2 ? ` <small>+${v.itens.length - 2} item(ns)</small>` : ''}</td><td>${esc(v.formaPagamento)}${v.parcelas > 1 ? ` <small>${v.parcelas}x</small>` : ''}</td><td class="num">${SC.money(v.total)}</td>
          <td>${SC.badge(v.status, v.status === 'Cancelada' ? 'b-bad' : 'b-ok')}</td><td class="actions"><button class="btn ghost icon sm" data-act="view" title="Ver detalhes" aria-label="Ver venda">${icon('eye', 16)}</button><button class="btn ghost icon sm" data-act="print" title="Imprimir comprovante" aria-label="Imprimir comprovante">${icon('print', 16)}</button>${v.status === 'Cancelada' && SC.can('excluir') ? `<button class="btn ghost icon sm" data-act="del" title="Excluir" aria-label="Excluir venda">${icon('trash', 16)}</button>` : ''}</td></tr>`).join('')}</tbody></table>` : SC.empty('Nenhuma venda encontrada.', 'cart');
      };
      draw();
      el.querySelector('#vq').addEventListener('input', SC.debounce(e => { sv.q = e.target.value; sv.page = 1; draw(); }, 150));
      el.querySelector('#vde').addEventListener('change', async e => { sv.de = e.target.value; sv.page = 1; draw(); });
      el.querySelector('#vate').addEventListener('change', async e => { sv.ate = e.target.value; sv.page = 1; draw(); });
      el.querySelector('#vst').addEventListener('change', async e => { sv.status = e.target.value; sv.page = 1; draw(); });
      const nb = el.querySelector('[data-new]'); if (nb) nb.onclick = () => V.form();
      list.addEventListener('click', async e => {
        const b = e.target.closest('[data-act]'); if (!b) return;
        const id = b.closest('tr').dataset.id, v = SC.byId('vendas', id);
        if (b.dataset.act === 'view') V.view(v);
        else if (b.dataset.act === 'print') SC.print.venda(id);
        else if (b.dataset.act === 'del' && await SC.confirm(`Excluir a venda <b>#${SC.pad(v.numero)}</b> cancelada?`, { danger: true, ok: 'Excluir' })) {
          SC.db.vendas = SC.db.vendas.filter(x => x.id !== id); SC.log('venda', `Venda #${SC.pad(v.numero)} excluída`); if (!await SC.save()) return; SC.toast('Venda excluída.'); SC.refresh();
        }
      });
    },
    open(id) { const v = SC.byId('vendas', id); if (v) V.view(v); },

    view(v) {
      const c = SC.cliOf(v), canCancel = v.status !== 'Cancelada' && SC.can('vendas');
      const m = SC.modal({
        title: `Venda #${SC.pad(v.numero)} ${SC.badge(v.status, v.status === 'Cancelada' ? 'b-bad' : 'b-ok')}`, size: 'md',
        body: `<div class="kv" style="margin-bottom:14px"><div><span>Data</span><b>${SC.fmtDT(v.data)}</b></div><div><span>Cliente</span><b>${esc(c.nome || 'Consumidor final')}</b></div><div><span>Pagamento</span><b>${esc(v.formaPagamento)}${v.parcelas > 1 ? ' em ' + v.parcelas + 'x' : ''}</b></div><div><span>Atendente</span><b>${esc(v.usuario || '—')}</b></div></div>
          <div class="table-wrap"><table class="tbl"><thead><tr><th>Item</th><th class="num">Qtd</th><th class="num">Unitário</th><th class="num">Subtotal</th></tr></thead><tbody>${v.itens.map(i => `<tr><td>${esc(i.descricao)}</td><td class="num">${i.qtd}</td><td class="num">${SC.money(i.preco)}</td><td class="num">${SC.money(i.qtd * i.preco)}</td></tr>`).join('')}</tbody></table></div>
          <div class="summary"><div><span>Subtotal</span><b>${SC.money(v.subtotal)}</b></div><div><span>Desconto</span><b>${SC.money(v.desconto)}</b></div><div><span>Total</span><b>${SC.money(v.total)}</b></div><div><span>Lucro estimado</span><b>${SC.money(v.lucro)}</b></div></div>${v.obs ? `<p><b>Obs.:</b> ${esc(v.obs)}</p>` : ''}`,
        footer: `<button type="button" class="btn" data-close>Fechar</button>${canCancel ? '<button type="button" class="btn danger" data-cancel>Cancelar venda</button>' : ''}<button type="button" class="btn primary" data-pr>${icon('print', 16)} Comprovante</button>`
      });
      m.el.addEventListener('click', async e => {
        if (e.target.closest('[data-pr]')) SC.print.venda(v.id);
        else if (e.target.closest('[data-cancel]') && await SC.confirm(`Cancelar a venda <b>#${SC.pad(v.numero)}</b>? Os itens voltam para o estoque.`, { danger: true, ok: 'Cancelar venda' })) {
          SC.estornaEstoque(v.baixa); v.baixa = []; v.status = 'Cancelada';
          SC.log('venda', `Venda #${SC.pad(v.numero)} cancelada (${SC.money(v.total)})`); if (!await SC.save()) return; m.close(); SC.refresh(); SC.toast('Venda cancelada e estoque devolvido.');
        }
      });
    },

    form() {
      const idempotencyKey = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : ('idemp_v_' + Date.now() + '_' + Math.random().toString(36).slice(2, 9));
      const m = SC.modal({
        title: 'Nova venda', size: 'xl',
        body: `<form class="grid" autocomplete="off">
          <div class="s12"><span class="lbl">Itens da venda</span>${SC.linesHTML([], { label: 'Produto ou serviço', noun: 'item' })}<p class="hint">Digite para buscar um produto cadastrado (o preço é preenchido) ou escreva um item avulso e informe o valor.</p></div>
          ${f.sel('Desconto em', 'descTipo', [['valor', 'R$ (valor)'], ['percent', '% (percentual)']], 'valor', { s: 3 })}${f.in('Desconto', 'descVal', '0,00', { s: 3, attrs: 'inputmode="decimal"' })}
          ${f.sel('Forma de pagamento', 'pagamento', SC.PAGAMENTOS, 'Pix', { s: 3 })}${f.in('Parcelas', 'parcelas', 1, { s: 3, type: 'number', attrs: 'min="1" max="24" step="1"' })}
          <div class="f s3"><span>Subtotal</span><output class="out" id="vsub">R$ 0,00</output></div><div class="f s3"><span>Desconto</span><output class="out" id="vdesc">R$ 0,00</output></div><div class="f s3"><span>Lucro estimado</span><output class="out" id="vluc">R$ 0,00</output></div><div class="f s3"><span>Total a pagar</span><output class="out big" id="vtot">R$ 0,00</output></div>
          ${f.area('Observações', 'obs', '', { s: 12, rows: 2 })}
          <details class="s12"><summary class="lbl" style="cursor:pointer">Cliente (opcional)</summary><div class="grid" style="margin-top:12px">${SC.clientFields({}, { optional: true })}</div></details>
        </form>`,
        footer: `<button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn" data-save>Finalizar venda</button><button type="button" class="btn primary" data-savepr>${icon('print', 16)} Finalizar e imprimir</button>`
      });
      const body = m.body;
      SC.bindClientPicker(body); SC.bindLines(body);
      const calc = () => {
        const itens = SC.readLines(body), sub = SC.sumLines(itens), dv = SC.parseMoney(body.querySelector('[name=descVal]').value), tipo = body.querySelector('[name=descTipo]').value;
        const desc = Math.min(sub, SC.r2(tipo === 'percent' ? sub * Math.min(dv, 100) / 100 : dv)), total = SC.r2(sub - desc);
        const custo = itens.reduce((a, i) => { const p = i.produtoId && SC.byId('produtos', i.produtoId); return a + (p ? p.custo * i.qtd : 0); }, 0);
        body.querySelector('#vsub').textContent = SC.money(sub); body.querySelector('#vdesc').textContent = SC.money(desc);
        body.querySelector('#vtot').textContent = SC.money(total); body.querySelector('#vluc').textContent = SC.money(total - custo);
        return { itens, sub, desc, total, custo };
      };
      body.addEventListener('input', calc); body.addEventListener('change', calc); body.addEventListener('focusout', calc); calc();
      body.querySelector('form').addEventListener('submit', e => e.preventDefault());
      const save = async print => {
        const btns = m.el.querySelectorAll('[data-save], [data-savepr]');
        const unlock = () => btns.forEach(b => { b.disabled = false; if (b.dataset.oldTxt) b.textContent = b.dataset.oldTxt; });
        btns.forEach(b => { b.disabled = true; b.dataset.oldTxt = b.textContent; b.textContent = 'Processando...'; });

        const v = SC.vals(body), r = calc(), err = msg => { unlock(); SC.toast(msg, 'err'); return false; };
        if (!r.itens.length) return err('Adicione pelo menos um item à venda.');
        if (r.itens.some(i => i.valor <= 0)) return err('Todos os itens precisam ter valor maior que zero.');
        const need = {};
        r.itens.forEach(i => { if (i.produtoId) need[i.produtoId] = (need[i.produtoId] || 0) + i.qtd; });
        for (const pid in need) { const p = SC.byId('produtos', pid); if (p && p.controla && p.estoque < need[pid]) return err(`Estoque insuficiente de "${p.nome}": disponível ${p.estoque}, pedido ${need[pid]}.`); }
        if (!SC.validDoc(v.c_doc)) return err('CPF/CNPJ inválido.');
        const c = v.c_nome.trim() ? SC.upsertClient(v) : null;
        const itens = r.itens.map(i => { const p = i.produtoId && SC.byId('produtos', i.produtoId); return { produtoId: i.produtoId, descricao: i.descricao, qtd: i.qtd, preco: i.valor, custo: p ? p.custo : 0 }; });
        const venda = {
          id: SC.uid(), numero: SC.nextNum('venda'), data: SC.nowISO(), clienteId: c ? c.id : null, cliSnap: c ? SC.snap(c) : null, clienteNome: c ? c.nome : 'Consumidor final',
          itens, subtotal: r.sub, descontoTipo: v.descTipo, descontoValor: SC.parseMoney(v.descVal), desconto: r.desc, total: r.total, lucro: SC.r2(r.total - r.custo),
          formaPagamento: v.pagamento, parcelas: Math.max(1, parseInt(v.parcelas) || 1), obs: v.obs.trim(), status: 'Concluída', usuario: SC.user.nome
        };

        SC.db.vendas.unshift(venda);
        if (!await SC.save()) { unlock(); return false; }

        SC.log('venda', `Venda #${SC.pad(venda.numero)} – ${SC.money(venda.total)} (${venda.formaPagamento})`);
        m.close(); SC.refresh(); SC.toast(`Venda #${SC.pad(venda.numero)} registrada.`);
        if (print) SC.print.venda(venda.id);
        return true;
      };
      m.el.addEventListener('click', e => { if (e.target.closest('[data-save]')) save(false); else if (e.target.closest('[data-savepr]')) save(true); });
    }
  });

  /* ================= PRODUTOS ================= */
  const margem = (c, p) => (p > 0 ? ((p - c) / p) * 100 : 0);
  const fmtPct = n => n.toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%';
  const baixo = p => p.controla && p.estoque <= (p.estoqueMin || 0);

  const PR = (SC.pages.produtos = {
    title: 'Produtos e estoque',
    state: sp,
    render(el) {
      const edit = SC.can('produtos');
      el.innerHTML = `<div class="page-head"><div><h1>Produtos e estoque</h1><p>Cadastro de produtos, preços, margem de lucro e controle de estoque.</p></div>${edit ? `<button class="btn primary" data-new>${icon('plus')} Novo produto</button>` : ''}</div>
        <div class="card"><div class="toolbar"><div class="search">${icon('search', 16)}<input type="search" id="pq" placeholder="Buscar por nome ou código…" value="${esc(sp.q)}"></div>
        <select id="pcat" aria-label="Categoria"><option value="">Todas as categorias</option>${SC.CATEGORIAS.map(c => `<option${c === sp.cat ? ' selected' : ''}>${c}</option>`).join('')}</select>
        <label class="chk"><input type="checkbox" id="pbx"${sp.baixo ? ' checked' : ''}> Só estoque baixo</label></div>
        <div class="summary" id="psum"></div><div class="table-wrap" id="plist"></div><div class="pager" id="ppager"></div></div>`;
      const list = el.querySelector('#plist');
      const draw = () => {
        const q = SC.norm(sp.q).trim();
        const ativos = SC.db.produtos.filter(p => p.ativo !== false);
        const rows = ativos.filter(p => (!sp.cat || p.categoria === sp.cat) && (!sp.baixo || baixo(p)) && (!q || SC.norm(p.nome + ' ' + p.codigo).includes(q))).sort((a, b) => a.nome.localeCompare(b.nome));
        const vc = ativos.reduce((a, p) => a + (p.controla ? p.estoque * p.custo : 0), 0), vv = ativos.reduce((a, p) => a + (p.controla ? p.estoque * p.preco : 0), 0);
        el.querySelector('#psum').innerHTML = `<div><span>Produtos cadastrados</span><b>${ativos.length}</b></div><div><span>Estoque baixo</span><b>${ativos.filter(baixo).length}</b></div><div><span>Estoque a preço de custo</span><b>${SC.money(vc)}</b></div><div><span>Estoque a preço de venda</span><b>${SC.money(vv)}</b></div>`;
        const off = SC.pager(el.querySelector('#ppager'), rows.length, sp, 30, draw);
        list.innerHTML = rows.length ? `<table class="tbl"><thead><tr><th>Código</th><th>Produto</th><th>Categoria</th><th class="num">Custo</th><th class="num">Venda</th><th class="num">Margem</th><th class="num">Estoque</th><th></th></tr></thead><tbody>${rows.slice(off, off + 30).map(p => `<tr data-id="${p.id}"><td>${esc(p.codigo)}</td><td><b>${esc(p.nome)}</b></td><td>${esc(p.categoria)}</td><td class="num">${SC.money(p.custo)}</td><td class="num">${SC.money(p.preco)}</td><td class="num">${fmtPct(margem(p.custo, p.preco))}</td>
          <td class="num">${p.controla ? `${p.estoque} ${baixo(p) ? SC.badge(p.estoque <= 0 ? 'Sem estoque' : 'Baixo', 'b-bad') : ''}` : '<small>não controla</small>'}</td>
          <td class="actions">${edit ? `<button class="btn ghost icon sm" data-act="edit" title="Editar" aria-label="Editar produto">${icon('edit', 16)}</button>` : ''}${SC.can('excluir') ? `<button class="btn ghost icon sm" data-act="del" title="Excluir" aria-label="Excluir produto">${icon('trash', 16)}</button>` : ''}</td></tr>`).join('')}</tbody></table>` : SC.empty('Nenhum produto encontrado.', 'box');
      };
      draw();
      el.querySelector('#pq').addEventListener('input', SC.debounce(e => { sp.q = e.target.value; sp.page = 1; draw(); }, 150));
      el.querySelector('#pcat').addEventListener('change', async e => { sp.cat = e.target.value; sp.page = 1; draw(); });
      el.querySelector('#pbx').addEventListener('change', async e => { sp.baixo = e.target.checked; sp.page = 1; draw(); });
      const nb = el.querySelector('[data-new]'); if (nb) nb.onclick = () => PR.form();
      list.addEventListener('click', async e => {
        const b = e.target.closest('[data-act]'); if (!b) return;
        const id = b.closest('tr').dataset.id, p = SC.byId('produtos', id);
        if (b.dataset.act === 'edit') PR.form(p);
        else if (b.dataset.act === 'del' && await SC.confirm(`Excluir o produto <b>${esc(p.nome)}</b>? Vendas e OS já registradas continuam no histórico.`, { danger: true, ok: 'Excluir' })) {
          p.ativo = false; SC.log('produto', `Produto inativado: ${p.nome}`); if (!await SC.save()) return; SC.toast('Produto excluído.'); SC.refresh();
        }
      });
    },
    open(id) { const p = SC.byId('produtos', id); if (p) PR.form(p); },
    form(p) {
      const isNew = !p, o = p || { categoria: 'Peça', custo: 0, preco: 0, estoque: 0, estoqueMin: 2, controla: true, ativo: true };
      const m = SC.modal({
        title: isNew ? 'Novo produto' : 'Editar produto', size: 'md',
        body: `<form class="grid" autocomplete="off">
          ${f.in('Nome do produto', 'nome', o.nome || '', { s: 8, req: 1 })}${f.in('Código', 'codigo', o.codigo || '', { s: 4, ph: 'Automático' })}
          ${f.sel('Categoria', 'categoria', SC.CATEGORIAS, o.categoria, { s: 4 })}${f.money('Preço de custo', 'custo', o.custo, { s: 4 })}${f.money('Preço de venda', 'preco', o.preco, { s: 4 })}
          <div class="f s6"><span>Margem de lucro</span><output class="out" id="pm">—</output></div><div class="f s6"><span>Lucro por unidade</span><output class="out" id="pl">—</output></div>
          <label class="chk s12"><input type="checkbox" name="controla"${o.controla ? ' checked' : ''}> Controlar estoque deste item (desmarque para serviços)</label>
          ${f.in('Quantidade em estoque', 'estoque', o.estoque, { s: 6, type: 'number', attrs: 'step="1"' })}${f.in('Estoque mínimo (alerta)', 'estoqueMin', o.estoqueMin, { s: 6, type: 'number', attrs: 'min="0" step="1"' })}
        </form>`,
        footer: `<button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn primary" data-save>Salvar produto</button>`
      });
      const body = m.body, g = n => body.querySelector(`[name=${n}]`);
      const upd = () => { const c = SC.parseMoney(g('custo').value), v = SC.parseMoney(g('preco').value); body.querySelector('#pm').textContent = v > 0 ? fmtPct(margem(c, v)) + ' (sobre a venda)' : '—'; body.querySelector('#pl').textContent = SC.money(v - c); };
      body.addEventListener('input', upd); body.addEventListener('focusout', upd); upd();
      g('categoria').addEventListener('change', () => { if (isNew) g('controla').checked = g('categoria').value !== 'Serviço'; });
      body.querySelector('form').addEventListener('submit', e => e.preventDefault());
      m.el.querySelector('[data-save]').onclick = async () => {
        const v = SC.vals(body);
        if (!v.nome.trim()) return SC.toast('Informe o nome do produto.', 'err');
        const preco = SC.parseMoney(v.preco), custo = SC.parseMoney(v.custo);
        if (preco <= 0) return SC.toast('Informe o preço de venda.', 'err');
        const base = p || { id: SC.uid(), ativo: true };
        Object.assign(base, { nome: v.nome.trim(), categoria: v.categoria, custo, preco, controla: v.controla, estoque: parseInt(v.estoque) || 0, estoqueMin: parseInt(v.estoqueMin) || 0, ativo: true });
        base.codigo = v.codigo.trim() || base.codigo || '';
        if (isNew) SC.db.produtos.push(base);
        SC.log('produto', `Produto ${isNew ? 'cadastrado' : 'atualizado'}: ${base.nome}`); if (!await SC.save()) return; m.close(); SC.refresh(); SC.toast('Produto salvo.');
      };
    }
  });
})();
