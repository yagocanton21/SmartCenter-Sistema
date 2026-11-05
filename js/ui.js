/* ui.js – ícones, modais, formulários, seletor de cliente, editor de itens e paginação */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc;

  const IC = {
    home: 'M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
    wrench: 'M14.7 6.3a4 4 0 0 0-5.4 5.1L3 17.7 6.3 21l6.3-6.3a4 4 0 0 0 5.1-5.4l-2.6 2.6-2.4-.6-.6-2.4z',
    file: 'M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z M14 3v5h5 M9 13h6 M9 17h6',
    cart: 'M3 4h2l2.4 11.2a1 1 0 0 0 1 .8H18a1 1 0 0 0 1-.8L20.5 8H6 M9 20.5v.01 M17 20.5v.01',
    box: 'M21 8l-9-5-9 5v8l9 5 9-5z M3.3 7.5 12 12.5l8.7-5 M12 22V12.5',
    users: 'M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20 M10 12a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z M20 20v-1.5a3.5 3.5 0 0 0-2.5-3.3 M15.5 5.2a3.5 3.5 0 0 1 0 6.6',
    user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 21a8 8 0 0 1 16 0',
    settings: 'M4 6h10 M18 6h2 M4 12h4 M12 12h8 M4 18h12 M20 18h0 M16 4v4 M10 10v4 M18 16v4',
    shield: 'M12 3l8 3v6c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V6z',
    database: 'M12 3v12 M7 10l5 5 5-5 M4 20h16',
    upload: 'M12 16V4 M7 9l5-5 5 5 M4 20h16',
    download: 'M12 3v12 M7 10l5 5 5-5 M4 20h16',
    search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14z M21 21l-4.3-4.3',
    plus: 'M12 5v14 M5 12h14',
    edit: 'M4 20h4L19 9l-4-4L4 16z M13.5 6.5l4 4',
    trash: 'M4 7h16 M9 7V4h6v3 M6 7l1 13h10l1-13 M10 11v6 M14 11v6',
    print: 'M7 9V3h10v6 M7 17H5a1 1 0 0 1-1-1v-5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v5a1 1 0 0 1-1 1h-2 M7 14h10v7H7z',
    eye: 'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
    x: 'M6 6l12 12 M18 6 6 18',
    menu: 'M4 7h16 M4 12h16 M4 17h16',
    check: 'M5 12.5l4.5 4.5L19 7.5',
    logout: 'M9 4H5a1 1 0 0 0-1 1v14a1 1 0 0 0 1 1h4 M16 8l4 4-4 4 M20 12H9',
    clock: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 7v5l3 2',
    dollar: 'M12 3v18 M16.5 7.5C15.5 6.3 14 6 12 6c-2.5 0-4.5 1-4.5 3s2 2.8 4.5 3 4.5 1 4.5 3-2 3-4.5 3c-2 0-3.5-.4-4.5-1.5',
    phone2: 'M8 3h8a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z M11 18h2',
    chat: 'M4 5h16v11H9l-5 4z',
    arrow: 'M5 12h14 M13 6l6 6-6 6',
    chart: 'M4 20V10 M10 20V4 M16 20v-7 M22 20H2',
    key: 'M14 10a4 4 0 1 0-3.9 4L11 15l1 1 1 .2.2 1 1 .8h2.3l1.7-1.7V13.6L20 11z',
    sun: 'M12 3v1 M12 20v1 M4.22 4.22l.71.71 M18.36 18.36l.71.71 M1 12h1 M21 12h1 M4.22 19.78l.71-.71 M18.36 5.64l.71-.71 M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10z',
    moon: 'M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'
  };
  SC.icon = (n, s = 18) => `<svg class="ic" viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${IC[n] || ''}"/></svg>`;
  const icon = SC.icon;

  SC.toast = (msg, type = 'ok') => {
    let box = document.getElementById('toasts');
    if (!box) { box = document.createElement('div'); box.id = 'toasts'; box.setAttribute('role', 'status'); box.setAttribute('aria-live', 'polite'); document.body.appendChild(box); }
    const t = document.createElement('div');
    t.className = 'toast ' + type; t.textContent = msg; box.appendChild(t);
    setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 320); }, type === 'ok' ? 3000 : 5200);
  };

  /* ---------- Modal ---------- */
  const stack = [];
  SC.modal = o => {
    const back = document.createElement('div');
    back.className = 'modal-back';
    back.innerHTML = `<div class="modal m-${o.size || 'md'}" role="dialog" aria-modal="true"><header><h3>${o.title}</h3><button type="button" class="btn ghost icon" data-close aria-label="Fechar">${icon('x')}</button></header><div class="modal-body">${o.body || ''}</div>${o.footer ? `<footer>${o.footer}</footer>` : ''}</div>`;
    document.body.appendChild(back);
    document.body.classList.add('modal-open');
    const api = {
      el: back, body: back.querySelector('.modal-body'),
      close() {
        if (!back.isConnected) return;
        back.remove();
        const i = stack.indexOf(api); if (i >= 0) stack.splice(i, 1);
        if (!stack.length) document.body.classList.remove('modal-open');
        if (o.onClose) o.onClose();
      }
    };
    back.addEventListener('click', e => { if (e.target.closest('[data-close]')) api.close(); });
    SC.bindInputs(back);
    stack.push(api);
    setTimeout(() => { const f = api.body.querySelector('[autofocus],input:not([type=hidden]):not([type=search]),select,textarea'); if (f) f.focus(); }, 40);
    return api;
  };
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && stack.length && !document.getElementById('printRoot')) stack[stack.length - 1].close(); });

  SC.confirm = (msg, o = {}) => new Promise(res => {
    let done = false;
    const m = SC.modal({
      title: esc(o.title || 'Confirmação'), size: 'sm',
      body: `<p class="confirm-msg">${msg}</p>`,
      footer: `<button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn ${o.danger ? 'danger' : 'primary'}" data-ok>${o.ok || 'Confirmar'}</button>`,
      onClose: () => { if (!done) { done = true; res(false); } }
    });
    m.el.querySelector('[data-ok]').addEventListener('click', () => { done = true; res(true); m.close(); });
    m.el.querySelector('[data-ok]').focus();
  });

  /* ---------- Formulários ---------- */
  SC.f = {
    in: (label, name, val = '', o = {}) => `<label class="f s${o.s || 6}"><span>${label}${o.req ? ' <b class="req">*</b>' : ''}</span><input name="${name}" type="${o.type || 'text'}" value="${esc(val == null ? '' : val)}" ${o.ph ? `placeholder="${esc(o.ph)}"` : ''} ${o.attrs || ''}></label>`,
    money: (label, name, val = 0, o = {}) => SC.f.in(label, name, SC.fmtNum(val), Object.assign({}, o, { attrs: 'class="money" inputmode="decimal" ' + (o.attrs || '') })),
    sel: (label, name, opts, val, o = {}) => `<label class="f s${o.s || 6}"><span>${label}</span><select name="${name}" ${o.attrs || ''}>${opts.map(x => { const [v, t] = Array.isArray(x) ? x : [x, x]; return `<option value="${esc(v)}"${String(v) === String(val) ? ' selected' : ''}>${esc(t)}</option>`; }).join('')}</select></label>`,
    area: (label, name, val = '', o = {}) => `<label class="f s${o.s || 12}"><span>${label}</span><textarea name="${name}" rows="${o.rows || 3}" ${o.ph ? `placeholder="${esc(o.ph)}"` : ''}>${esc(val)}</textarea></label>`
  };
  SC.vals = root => { const o = {}; root.querySelectorAll('[name]').forEach(el => { o[el.name] = el.type === 'checkbox' ? el.checked : el.value; }); return o; };

  SC.bindInputs = root => {
    root.addEventListener('input', e => {
      const t = e.target, m = t.dataset && t.dataset.mask;
      if (m === 'doc') t.value = SC.maskDoc(t.value);
      else if (m === 'tel') t.value = SC.maskPhone(t.value);
      else if (m === 'cep') t.value = SC.maskCep(t.value);
    });
    root.addEventListener('focusin', e => { if (e.target.classList && e.target.classList.contains('money')) setTimeout(() => e.target.select(), 0); });
    root.addEventListener('focusout', e => {
      const t = e.target;
      if (t.classList && t.classList.contains('money')) t.value = SC.fmtNum(SC.parseMoney(t.value));
      if (t.dataset && t.dataset.mask === 'cep') {
        const d = SC.digits(t.value);
        if (d.length === 8 && typeof fetch === 'function') {
          const scope = t.closest('.modal-body') || document;
          fetch('https://viacep.com.br/ws/' + d + '/json/').then(r => r.json()).then(j => {
            if (j.erro) return;
            const end = scope.querySelector('[name=endereco]'), cid = scope.querySelector('[name=cidade]');
            const novoEnd = [j.logradouro, j.bairro].filter(Boolean).join(', ');
            const novaCid = j.localidade + (j.uf ? '/' + j.uf : '');
            if (end && (!end.value || t.dataset.lastCep !== d)) end.value = novoEnd;
            if (cid && (!cid.value || t.dataset.lastCep !== d)) cid.value = novaCid;
            t.dataset.lastCep = d;
          }).catch(() => { /* offline: segue sem preencher */ });
        }
      }
    });
  };

  /* ---------- Seletor de cliente ---------- */
  SC.clientFields = (c = {}, o = {}) => `
    <div class="f s12 picker"><span>Buscar cliente cadastrado</span><div class="picker-row"><input type="search" data-cs placeholder="Digite nome, telefone ou CPF/CNPJ…" autocomplete="off"><button type="button" class="btn sm" data-cclear>Novo cliente</button></div><div class="picker-list" hidden></div></div>
    <input type="hidden" name="clienteId" value="${esc(c.id || '')}">
    ${SC.f.in('Nome do cliente', 'c_nome', c.nome || '', { s: 6, req: !o.optional })}
    ${SC.f.in('Telefone / WhatsApp', 'c_tel', c.telefone || '', { s: 3, attrs: 'data-mask="tel" inputmode="tel"' })}
    ${SC.f.in('CPF / CNPJ', 'c_doc', c.doc || '', { s: 3, attrs: 'data-mask="doc" inputmode="numeric"' })}
    ${SC.f.in('Endereço', 'c_end', c.endereco || '', { s: 12 })}`;

  SC.bindClientPicker = root => {
    const inp = root.querySelector('[data-cs]'); if (!inp) return;
    const list = root.querySelector('.picker-list');
    const set = (n, v) => { const el = root.querySelector(`[name=${n}]`); if (el) el.value = v || ''; };
    inp.addEventListener('input', () => {
      const q = SC.norm(inp.value).trim();
      if (q.length < 2) { list.hidden = true; return; }
      const qd = SC.digits(inp.value);
      const rs = SC.db.clientes.filter(c => SC.norm(c.nome).includes(q) || (qd && (SC.digits(c.telefone).includes(qd) || SC.digits(c.doc).includes(qd)))).slice(0, 8);
      list.innerHTML = rs.length ? rs.map(c => `<button type="button" data-cid="${c.id}"><b>${esc(c.nome)}</b><small>${esc(c.telefone || '')} ${esc(c.doc || '')}</small></button>`).join('') : '<div class="picker-empty">Nenhum cliente encontrado. Preencha os campos abaixo para cadastrar.</div>';
      list.hidden = false;
    });
    list.addEventListener('click', e => {
      const b = e.target.closest('[data-cid]'); if (!b) return;
      const c = SC.byId('clientes', b.dataset.cid);
      set('clienteId', c.id); set('c_nome', c.nome); set('c_tel', c.telefone); set('c_doc', c.doc); set('c_end', c.endereco);
      inp.value = ''; list.hidden = true;
    });
    root.querySelector('[data-cclear]').addEventListener('click', () => { ['clienteId', 'c_nome', 'c_tel', 'c_doc', 'c_end'].forEach(n => set(n, '')); inp.value = ''; list.hidden = true; root.querySelector('[name=c_nome]').focus(); });
    root.addEventListener('click', e => { if (!e.target.closest('.picker')) list.hidden = true; });
  };

  /* ---------- Editor de itens (peças / produtos) ---------- */
  SC.ensureProdList = () => {
    let dl = document.getElementById('dl-prod');
    if (!dl) { dl = document.createElement('datalist'); dl.id = 'dl-prod'; document.body.appendChild(dl); }
    dl.innerHTML = SC.db.produtos.filter(p => p.ativo !== false).map(p => `<option value="${esc(p.nome)}">${esc(SC.money(p.preco))}${p.controla ? ' · estoque ' + p.estoque : ''}</option>`).join('');
  };
  const lineRow = (l = {}) => `<tr><td><input class="l-desc" list="dl-prod" value="${esc(l.descricao || '')}" placeholder="Descrição ou escolha um produto"><input type="hidden" class="l-pid" value="${esc(l.produtoId || '')}"></td><td><input class="l-qtd" type="number" min="1" step="1" value="${l.qtd || 1}"></td><td><input class="l-val money" inputmode="decimal" value="${SC.fmtNum(l.valor != null ? l.valor : (l.preco || 0))}"></td><td class="l-sub num">${SC.money((l.qtd || 1) * (l.valor != null ? l.valor : (l.preco || 0)))}</td><td><button type="button" class="btn ghost icon sm" data-rm aria-label="Remover item">${icon('x', 16)}</button></td></tr>`;
  SC.linesHTML = (lines, o = {}) => {
    SC.ensureProdList();
    const rows = lines && lines.length ? lines : [{}];
    return `<div class="lines"><div class="table-wrap"><table class="tbl lines-tbl"><thead><tr><th>${o.label || 'Peça / item'}</th><th>Qtd</th><th>Valor unit.</th><th class="num">Subtotal</th><th></th></tr></thead><tbody>${rows.map(lineRow).join('')}</tbody></table></div><button type="button" class="btn sm" data-addline>${icon('plus', 16)} Adicionar ${o.noun || 'peça'}</button></div>`;
  };
  SC.bindLines = (root, onChange) => {
    const tb = root.querySelector('.lines tbody');
    const sub = tr => { tr.querySelector('.l-sub').textContent = SC.money((parseInt(tr.querySelector('.l-qtd').value) || 0) * SC.parseMoney(tr.querySelector('.l-val').value)); };
    root.querySelector('[data-addline]').addEventListener('click', () => { tb.insertAdjacentHTML('beforeend', lineRow({})); tb.lastElementChild.querySelector('.l-desc').focus(); if (onChange) onChange(); });
    tb.addEventListener('click', e => {
      const b = e.target.closest('[data-rm]'); if (!b) return;
      if (tb.rows.length === 1) { const tr = tb.rows[0]; tr.querySelector('.l-desc').value = ''; tr.querySelector('.l-pid').value = ''; tr.querySelector('.l-qtd').value = 1; tr.querySelector('.l-val').value = '0,00'; sub(tr); } else b.closest('tr').remove();
      if (onChange) onChange();
    });
    tb.addEventListener('input', e => {
      const tr = e.target.closest('tr'); if (!tr) return;
      if (e.target.classList.contains('l-desc')) {
        const p = SC.db.produtos.find(x => x.nome === e.target.value);
        if (p) { tr.querySelector('.l-pid').value = p.id; tr.querySelector('.l-val').value = SC.fmtNum(p.preco); } else tr.querySelector('.l-pid').value = '';
      }
      sub(tr); if (onChange) onChange();
    });
  };
  SC.readLines = root => [...root.querySelectorAll('.lines tbody tr')].map(tr => ({
    produtoId: tr.querySelector('.l-pid').value || null,
    descricao: tr.querySelector('.l-desc').value.trim(),
    qtd: Math.max(1, parseInt(tr.querySelector('.l-qtd').value) || 1),
    valor: SC.parseMoney(tr.querySelector('.l-val').value)
  })).filter(l => l.descricao);

  /* ---------- Paginação e vazio ---------- */
  SC.pager = (host, total, st, per, cb) => {
    const pages = Math.max(1, Math.ceil(total / per));
    if (st.page > pages) st.page = pages;
    host.innerHTML = total > per
      ? `<span>${(st.page - 1) * per + 1}–${Math.min(total, st.page * per)} de ${total}</span><div><button type="button" class="btn sm" data-p="-1" ${st.page <= 1 ? 'disabled' : ''}>Anterior</button><span>${st.page}/${pages}</span><button type="button" class="btn sm" data-p="1" ${st.page >= pages ? 'disabled' : ''}>Próxima</button></div>`
      : `<span>${total} registro${total === 1 ? '' : 's'}</span>`;
    host.onclick = e => { const b = e.target.closest('[data-p]'); if (b) { st.page += +b.dataset.p; cb(); } };
    return (st.page - 1) * per;
  };
  SC.empty = (msg, ic = 'search') => `<div class="empty">${icon(ic, 34)}<p>${msg}</p></div>`;
  SC.badge = (txt, cls = 'b-info') => `<span class="badge ${cls}">${esc(txt)}</span>`;
  SC.wa = tel => { const d = SC.digits(tel); return d ? 'https://wa.me/' + (d.length <= 11 ? '55' + d : d) : ''; };
  SC.download = (name, text, type = 'application/json') => {
    const blob = new Blob([text], { type }), url = URL.createObjectURL(blob), a = document.createElement('a');
    a.href = url; a.download = name; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 2000);
  };
})();
