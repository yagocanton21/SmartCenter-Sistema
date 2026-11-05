/* app.js – login, estrutura da tela, navegação, busca global */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon;
  const NAV = [
    { k: 'dashboard', n: 'Painel', i: 'home' }, { k: 'os', n: 'Ordens de serviço', i: 'wrench' }, { k: 'orcamentos', n: 'Orçamentos', i: 'file' },
    { k: 'vendas', n: 'Vendas', i: 'cart' }, { k: 'produtos', n: 'Produtos e estoque', i: 'box' }, { k: 'clientes', n: 'Clientes', i: 'users' },
    { g: 'Administração' },
    { k: 'config', n: 'Configurações', i: 'settings' }, { k: 'usuarios', n: 'Usuários', i: 'shield' }, { k: 'backup', n: 'Backup', i: 'database' }
  ];
  let current = null, internal = false;
  const root = () => document.getElementById('root');

  /* ---------- Login ---------- */
  SC.boot = () => {
    const uid = SC.session.get();
    const u = uid && SC.db.users.find(x => x.id === uid && x.ativo);
    if (u) { SC.user = u; SC.renderShell(); route(); } else showLogin();
  };
  function showLogin(msg) {
    const c = SC.db.config;
    root().innerHTML = `<div class="login"><div class="login-card"><div class="brand"><div class="brand-mark">${c.logo ? `<img src="${c.logo}" alt="">` : 'SC'}</div><div><b>${esc(c.nomeFantasia)}</b><small>Sistema de gestão · Assistência técnica</small></div></div>
      <form id="lf" autocomplete="on">${msg ? `<div class="login-err" role="alert">${esc(msg)}</div>` : ''}
      <label class="f"><span>Usuário</span><input name="login" autocomplete="username" autocapitalize="none" autofocus></label>
      <label class="f"><span>Senha</span><input name="senha" type="password" autocomplete="current-password"></label>
      <button class="btn primary" type="submit" style="padding:11px">Entrar</button></form></div></div>`;
    root().querySelector('#lf').addEventListener('submit', e => {
      e.preventDefault();
      const v = SC.vals(e.target), u = SC.db.users.find(x => x.login === v.login.trim().toLowerCase() && x.senha === SC.hash(v.senha));
      if (!u) return showLogin('Usuário ou senha incorretos.');
      if (!u.ativo) return showLogin('Este usuário está inativo. Fale com o administrador.');
      SC.session.set(u.id); SC.user = u; SC.log('sistema', 'Login realizado'); SC.save(); SC.renderShell(); route();
    });
  }
  SC.logout = () => { SC.session.set(null); SC.user = null; current = null; showLogin(); };

  SC.changePassword = () => {
    const m = SC.modal({
      title: 'Alterar senha', size: 'sm',
      body: `<div class="grid"><label class="f s12"><span>Senha atual</span><input type="password" name="a" autocomplete="current-password"></label><label class="f s12"><span>Nova senha</span><input type="password" name="n" autocomplete="new-password"></label><label class="f s12"><span>Repita a nova senha</span><input type="password" name="r" autocomplete="new-password"></label></div>`,
      footer: `<button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn primary" data-ok>Salvar senha</button>`
    });
    m.el.querySelector('[data-ok]').onclick = () => {
      const v = SC.vals(m.body);
      if (SC.hash(v.a) !== SC.user.senha) return SC.toast('A senha atual está incorreta.', 'err');
      if (v.n.length < 4) return SC.toast('A nova senha deve ter ao menos 4 caracteres.', 'err');
      if (v.n !== v.r) return SC.toast('As senhas digitadas não conferem.', 'err');
      SC.user.senha = SC.hash(v.n); SC.log('usuario', 'Senha alterada'); SC.save(); m.close(); SC.toast('Senha alterada.'); SC.refresh();
    };
  };

  /* ---------- Estrutura ---------- */
  SC.renderShell = () => {
    const c = SC.db.config, u = SC.user;
    const ini = u.nome.split(/\s+/).map(w => w[0]).join('').slice(0, 2).toUpperCase();
    root().innerHTML = `<div class="app">
      <aside class="side" id="side"><div class="brand"><div class="brand-mark">${c.logo ? `<img src="${c.logo}" alt="">` : 'SC'}</div><div><b>${esc(c.nomeFantasia)}</b><small>Assistência técnica</small></div></div>
        <nav class="nav" aria-label="Menu principal">${NAV.map(n => n.g ? (NAV.slice(NAV.indexOf(n) + 1).some(x => SC.can(x.k)) ? `<h6>${n.g}</h6>` : '') : (SC.can(n.k) ? `<a data-nav="${n.k}" tabindex="0" role="link">${icon(n.i)} ${n.n}</a>` : '')).join('')}</nav>
        <div class="side-foot"><div>SmartCenter · v1.0</div><small class="db-pill ${SC.storage.isSQLite ? 'pill-sqlite' : 'pill-local'}" title="${SC.storage.isSQLite ? 'Conectado ao arquivo smartcenter.db' : 'Dados salvos no navegador'}">${SC.storage.isSQLite ? '🟢 SQLite Ativo' : '💾 Banco Local'}</small></div></aside><div class="scrim" id="scrim"></div>
      <div class="main"><header class="top"><button class="btn ghost icon menu-btn" id="menu" aria-label="Abrir menu">${icon('menu')}</button>
        <div class="gsearch">${icon('search', 16)}<input type="search" id="gs" placeholder="Pesquisa rápida: OS, cliente, IMEI, produto… (tecla /)" autocomplete="off"><div class="gs-list" id="gsl" hidden></div></div><div class="spacer"></div>
        <div class="usermenu"><button class="ubtn" id="ubtn" aria-haspopup="true"><span class="avatar">${esc(ini)}</span><span><b>${esc(u.nome)}</b><small>${esc((SC.PERFIS[u.perfil] || {}).nome || '')}</small></span></button>
          <div class="umenu" id="umenu" hidden><button data-pass>${icon('key', 16)} Alterar senha</button><button data-out>${icon('logout', 16)} Sair</button></div></div></header>
        ${SC.storage.ok ? '' : '<div class="banner" role="alert">O navegador não está permitindo salvar dados (modo privado ou armazenamento bloqueado). Faça backup antes de fechar esta aba.</div>'}
        <main id="view"></main></div></div>`;
    const r = root();
    r.querySelectorAll('[data-nav]').forEach(a => { a.onclick = () => SC.go(a.dataset.nav); a.onkeydown = e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); SC.go(a.dataset.nav); } }; });
    const side = r.querySelector('#side'), scrim = r.querySelector('#scrim');
    const tog = open => { side.classList.toggle('open', open); scrim.classList.toggle('show', open); };
    r.querySelector('#menu').onclick = () => tog(!side.classList.contains('open'));
    scrim.onclick = () => tog(false);
    side.addEventListener('click', e => { if (e.target.closest('[data-nav]')) tog(false); });
    const um = r.querySelector('#umenu');
    r.querySelector('#ubtn').onclick = e => { e.stopPropagation(); um.hidden = !um.hidden; };
    um.addEventListener('click', e => { um.hidden = true; if (e.target.closest('[data-out]')) SC.logout(); if (e.target.closest('[data-pass]')) SC.changePassword(); });
    document.addEventListener('click', () => { const x = document.getElementById('umenu'); if (x) x.hidden = true; });
    bindSearch(r);
    if (current) mark();
  };

  /* ---------- Rotas ---------- */
  const mark = () => root().querySelectorAll('[data-nav]').forEach(a => a.classList.toggle('on', a.dataset.nav === current));
  function route(name) {
    if (!SC.user) return;
    let k = name || (location.hash || '').slice(1);
    if (!SC.pages[k] || !SC.can(k)) k = 'dashboard';
    current = k;
    const view = document.getElementById('view'); if (!view) return;
    view.onclick = null; view.innerHTML = '';
    SC.pages[k].render(view);
    mark(); window.scrollTo(0, 0);
    if (location.hash !== '#' + k) { internal = true; location.hash = k; }
    document.title = SC.pages[k].title + ' · ' + SC.db.config.nomeFantasia;
  }
  SC.go = k => route(k);
  SC.refresh = () => { const sy = window.scrollY; route(current); window.scrollTo(0, sy); };
  window.addEventListener('hashchange', () => { if (internal) { internal = false; return; } route(); });

  const MAP = { os: 'os', orc: 'orcamentos', orcamento: 'orcamentos', venda: 'vendas', cliente: 'clientes', produto: 'produtos' };
  SC.openRecord = (type, id) => {
    const page = MAP[type];
    if (!page || !SC.can(page)) return SC.toast('Você não tem permissão para abrir este registro.', 'err');
    SC.go(page); SC.pages[page].open(id);
  };

  /* ---------- Busca global ---------- */
  function bindSearch(r) {
    const inp = r.querySelector('#gs'), box = r.querySelector('#gsl');
    const run = () => {
      const q = SC.norm(inp.value).trim(), qd = SC.digits(inp.value);
      if (q.length < 2) { box.hidden = true; return; }
      const grp = [];
      const add = (t, items) => { if (items.length) grp.push(`<h6>${t}</h6>${items.join('')}`); };
      const it = (type, id, a, b) => `<button type="button" data-t="${type}" data-id="${id}"><b>${esc(a)}</b><small>${esc(b)}</small></button>`;
      if (SC.can('os')) add('Ordens de serviço', SC.db.os.filter(o => { const c = SC.cliOf(o), a = o.aparelho || {}; return SC.norm([SC.pad(o.numero), o.numero, c.nome, a.marca, a.modelo, a.imei].join(' ')).includes(q) || (qd.length > 2 && SC.digits(c.telefone).includes(qd)); }).slice(0, 5).map(o => it('os', o.id, `OS #${SC.pad(o.numero)} · ${SC.cliOf(o).nome}`, `${o.aparelho.marca} ${o.aparelho.modelo} · ${o.status}`)));
      if (SC.can('clientes')) add('Clientes', SC.db.clientes.filter(c => SC.norm(c.nome).includes(q) || (qd.length > 2 && (SC.digits(c.telefone).includes(qd) || SC.digits(c.doc).includes(qd)))).slice(0, 5).map(c => it('cliente', c.id, c.nome, [c.telefone, c.doc].filter(Boolean).join(' · '))));
      if (SC.can('orcamentos')) add('Orçamentos', SC.db.orcamentos.filter(o => SC.norm([SC.pad(o.numero), SC.cliOf(o).nome, o.aparelho.modelo].join(' ')).includes(q)).slice(0, 4).map(o => it('orc', o.id, `Orçamento #${SC.pad(o.numero)} · ${SC.cliOf(o).nome}`, `${o.status} · ${SC.money(o.total)}`)));
      if (SC.can('vendas')) add('Vendas', SC.db.vendas.filter(v => SC.norm([SC.pad(v.numero), SC.cliOf(v).nome, v.itens.map(i => i.descricao).join(' ')].join(' ')).includes(q)).slice(0, 4).map(v => it('venda', v.id, `Venda #${SC.pad(v.numero)} · ${SC.cliOf(v).nome}`, `${SC.fmtDate(v.data)} · ${SC.money(v.total)}`)));
      if (SC.can('produtos')) add('Produtos', SC.db.produtos.filter(p => p.ativo !== false && SC.norm(p.nome + ' ' + p.codigo).includes(q)).slice(0, 5).map(p => it('produto', p.id, p.nome, `${SC.money(p.preco)}${p.controla ? ' · estoque ' + p.estoque : ''}`)));
      box.innerHTML = grp.join('') || '<div class="gs-empty">Nada encontrado.</div>'; box.hidden = false;
    };
    inp.addEventListener('input', SC.debounce(run, 120));
    box.addEventListener('click', e => { const b = e.target.closest('[data-t]'); if (!b) return; box.hidden = true; inp.value = ''; SC.openRecord(b.dataset.t, b.dataset.id); });
    document.addEventListener('click', e => { if (!e.target.closest('.gsearch')) box.hidden = true; });
    document.addEventListener('keydown', e => {
      if (e.key === '/' && !document.body.classList.contains('modal-open') && !document.body.classList.contains('printing-open') && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName) && document.getElementById('gs')) { e.preventDefault(); document.getElementById('gs').focus(); }
    });
  }

  document.addEventListener('DOMContentLoaded', async () => { await SC.load(); SC.boot(); });
})();
