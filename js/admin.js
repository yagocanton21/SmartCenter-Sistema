/* admin.js – configurações da loja, usuários e permissões, backup e restauração */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon, f = SC.f;

  /* ================= CONFIGURAÇÕES ================= */
  SC.pages.config = {
    title: 'Configurações',
    render(el) {
      const c = SC.db.config;
      let logo = c.logo || '';
      el.innerHTML = `<div class="page-head"><div><h1>Configurações da loja</h1><p>Estes dados aparecem automaticamente em todos os documentos impressos.</p></div><button class="btn primary" data-save>${icon('check')} Salvar configurações</button></div>
        <div class="card"><div class="card-b"><div class="tabs"><button class="on" data-tab="l">Dados da loja</button><button data-tab="t">Termo de garantia</button></div>
        <form id="cfg" autocomplete="off">
        <div data-p="l" class="grid">
          ${f.in('Nome fantasia', 'nomeFantasia', c.nomeFantasia, { s: 6, req: 1 })}${f.in('Razão social', 'razaoSocial', c.razaoSocial, { s: 6 })}
          ${f.in('CNPJ', 'cnpj', c.cnpj, { s: 4, attrs: 'data-mask="doc" inputmode="numeric"' })}${f.in('Telefone', 'telefone', c.telefone, { s: 4, attrs: 'data-mask="tel" inputmode="tel"' })}${f.in('WhatsApp', 'whatsapp', c.whatsapp, { s: 4, attrs: 'data-mask="tel" inputmode="tel"' })}
          ${f.in('CEP', 'cep', c.cep, { s: 3, attrs: 'data-mask="cep" inputmode="numeric"' })}${f.in('Endereço', 'endereco', c.endereco, { s: 6 })}${f.in('Cidade', 'cidade', c.cidade, { s: 3 })}
          ${f.in('E-mail', 'email', c.email, { s: 6, type: 'email' })}${f.in('Nome do responsável técnico', 'responsavel', c.responsavel, { s: 6 })}
          ${f.in('Garantia padrão das OS (dias)', 'garantiaPadraoDias', c.garantiaPadraoDias, { s: 4, type: 'number', attrs: 'min="0" step="1"' })}
          <div class="f s8"><span>Logotipo</span><div class="logo-box"><div class="logo-prev" id="lprev">${logo ? `<img src="${logo}" alt="Logotipo">` : 'Sem logotipo'}</div><div><input type="file" id="lfile" accept="image/*" style="display:none"><button type="button" class="btn sm" id="lbtn">${icon('upload', 16)} Enviar imagem</button> <button type="button" class="btn sm ghost" id="lrm">Remover</button><p class="hint" style="margin:6px 0 0">PNG ou JPG. A imagem é reduzida automaticamente.</p></div></div></div>
          ${f.area('Condições de pagamento', 'condicoesPagamento', c.condicoesPagamento, { s: 12, rows: 3 })}
        </div>
        <div data-p="t" hidden>
          <p class="hint">Este termo é impresso na <b>Nota de Serviço</b>, quando a manutenção é concluída. Edite o texto abaixo. Use <b># Título</b>, <b>## Seção</b> e <b>- item</b> para formatar. Variáveis disponíveis: <code>{{loja}}</code> <code>{{garantia}}</code> <code>{{os}}</code> <code>{{cliente}}</code> <code>{{aparelho}}</code> <code>{{data}}</code> <code>{{telefone}}</code> <code>{{endereco}}</code> <code>{{cnpj}}</code>.</p>
          <textarea name="termoGarantia" rows="24" style="font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px;line-height:1.5">${esc(c.termoGarantia)}</textarea>
          <div class="head-actions" style="margin-top:10px"><button type="button" class="btn" id="tprev">${icon('eye', 16)} Pré-visualizar</button><button type="button" class="btn" id="treset">Restaurar modelo padrão</button></div>
        </div></form></div></div>`;
      SC.bindInputs(el);
      el.querySelector('form').addEventListener('submit', e => e.preventDefault());
      el.addEventListener('click', async e => {
        const t = e.target.closest('[data-tab]');
        if (t) { el.querySelectorAll('[data-tab]').forEach(x => x.classList.toggle('on', x === t)); el.querySelectorAll('[data-p]').forEach(p => { p.hidden = p.dataset.p !== t.dataset.tab; }); }
        if (e.target.closest('#lbtn')) el.querySelector('#lfile').click();
        if (e.target.closest('#lrm')) { logo = ''; el.querySelector('#lprev').innerHTML = 'Sem logotipo'; }
        if (e.target.closest('#treset') && await SC.confirm('Substituir o texto atual pelo modelo padrão do termo de garantia?', { ok: 'Restaurar' })) el.querySelector('[name=termoGarantia]').value = SC.TERMO_PADRAO;
        if (e.target.closest('#tprev')) SC.print.termo(el.querySelector('[name=termoGarantia]').value, SC.vals(el.querySelector('form')), logo);
        if (e.target.closest('[data-save]')) {
          const v = SC.vals(el.querySelector('form'));
          if (!v.nomeFantasia.trim()) return SC.toast('Informe o nome fantasia.', 'err');
          if (v.cnpj && !SC.validDoc(v.cnpj)) return SC.toast('CNPJ inválido. Confira os números.', 'err');
          Object.assign(SC.db.config, { nomeFantasia: v.nomeFantasia.trim(), razaoSocial: v.razaoSocial.trim(), cnpj: v.cnpj, telefone: v.telefone, whatsapp: v.whatsapp, cep: v.cep, endereco: v.endereco.trim(), cidade: v.cidade.trim(), email: v.email.trim(), responsavel: v.responsavel.trim(), garantiaPadraoDias: Math.max(0, parseInt(v.garantiaPadraoDias) || 0), condicoesPagamento: v.condicoesPagamento.trim(), termoGarantia: v.termoGarantia.trim() ? v.termoGarantia : SC.TERMO_PADRAO, logo });
          SC.log('sistema', 'Configurações da loja atualizadas'); if (!await SC.save()) return; SC.toast('Configurações salvas.'); SC.renderShell();
        }
      });
      el.querySelector('#lfile').addEventListener('change', async e => {
        const file = e.target.files[0]; if (!file) return;
        const rd = new FileReader();
        rd.onload = () => {
          const img = new Image();
          img.onload = () => {
            const s = Math.min(1, 420 / Math.max(img.width, img.height)), cv = document.createElement('canvas');
            cv.width = Math.round(img.width * s); cv.height = Math.round(img.height * s);
            cv.getContext('2d').drawImage(img, 0, 0, cv.width, cv.height);
            logo = cv.toDataURL(file.type === 'image/jpeg' ? 'image/jpeg' : 'image/png', 0.9);
            el.querySelector('#lprev').innerHTML = `<img src="${logo}" alt="Logotipo">`;
          };
          img.onerror = () => SC.toast('Não foi possível ler esta imagem.', 'err');
          img.src = rd.result;
        };
        rd.readAsDataURL(file);
      });
    }
  };

  /* ================= USUÁRIOS ================= */
  const U = (SC.pages.usuarios = {
    title: 'Usuários',
    render(el) {
      el.innerHTML = `<div class="page-head"><div><h1>Usuários e permissões</h1><p>Defina quem acessa cada módulo do sistema.</p></div><button class="btn primary" data-new>${icon('plus')} Novo usuário</button></div>
        <div class="card"><div class="table-wrap"><table class="tbl"><thead><tr><th>Nome</th><th>Login</th><th>Perfil</th><th>Acessos</th><th>Situação</th><th></th></tr></thead><tbody>${SC.db.users.map(u => `<tr data-id="${u.id}"><td><b>${esc(u.nome)}</b>${u.id === SC.user.id ? ' <small>(você)</small>' : ''}</td><td>${esc(u.login)}</td><td>${esc((SC.PERFIS[u.perfil] || {}).nome || u.perfil)}</td><td><small>${u.perfil === 'admin' ? 'Acesso total' : (u.perms || []).map(k => (SC.MODULOS.find(m => m.k === k) || {}).n).filter(Boolean).join(', ')}</small></td><td>${SC.badge(u.ativo ? 'Ativo' : 'Inativo', u.ativo ? 'b-ok' : 'b-mut')}</td>
        <td class="actions"><button class="btn ghost icon sm" data-act="edit" aria-label="Editar usuário" title="Editar">${icon('edit', 16)}</button><button class="btn ghost icon sm" data-act="del" aria-label="Excluir usuário" title="Excluir">${icon('trash', 16)}</button></td></tr>`).join('')}</tbody></table></div></div>`;
      el.querySelector('[data-new]').onclick = () => U.form();
      el.addEventListener('click', async e => {
        const b = e.target.closest('[data-act]'); if (!b) return;
        const u = SC.byId('users', b.closest('tr').dataset.id);
        if (b.dataset.act === 'edit') U.form(u);
        else {
          if (u.id === SC.user.id) return SC.toast('Você não pode excluir o próprio usuário.', 'err');
          if (u.perfil === 'admin' && SC.db.users.filter(x => x.perfil === 'admin' && x.ativo).length <= 1) return SC.toast('É necessário manter ao menos um administrador ativo.', 'err');
          if (await SC.confirm(`Excluir o usuário <b>${esc(u.nome)}</b>?`, { danger: true, ok: 'Excluir' })) { SC.db.users = SC.db.users.filter(x => x.id !== u.id); SC.log('usuario', `Usuário excluído: ${u.nome}`); if (!await SC.save()) return; SC.toast('Usuário excluído.'); SC.refresh(); }
        }
      });
    },
    form(u) {
      const isNew = !u, o = u || { perfil: 'atendente', ativo: true, perms: SC.PERFIS.atendente.perms.slice() };
      const m = SC.modal({
        title: isNew ? 'Novo usuário' : 'Editar usuário', size: 'md',
        body: `<form class="grid" autocomplete="off">
          ${f.in('Nome', 'nome', o.nome || '', { s: 6, req: 1 })}${f.in('Login', 'login', o.login || '', { s: 6, req: 1, attrs: 'autocapitalize="none"' })}
          ${f.in(isNew ? 'Senha' : 'Nova senha (deixe em branco para manter)', 'senha', '', { s: 6, type: 'password', attrs: 'autocomplete="new-password"' })}${f.sel('Perfil', 'perfil', Object.keys(SC.PERFIS).map(k => [k, SC.PERFIS[k].nome]), o.perfil, { s: 6 })}
          <div class="s12"><span class="lbl">Permissões de acesso</span><div class="perm-grid" style="margin-top:6px">${SC.MODULOS.map(mo => `<label class="chk"><input type="checkbox" data-perm="${mo.k}"${(o.perms || []).includes(mo.k) || o.perfil === 'admin' ? ' checked' : ''}> ${mo.n}</label>`).join('')}</div><p class="hint">Administradores têm acesso a tudo. Ao trocar o perfil, as permissões padrão dele são marcadas.</p></div>
          <label class="chk s12"><input type="checkbox" name="ativo"${o.ativo ? ' checked' : ''}> Usuário ativo (pode entrar no sistema)</label>
        </form>`,
        footer: `<button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn primary" data-save>Salvar usuário</button>`
      });
      const body = m.body;
      body.querySelector('[name=perfil]').addEventListener('change', async e => { const p = SC.PERFIS[e.target.value].perms; body.querySelectorAll('[data-perm]').forEach(c => { c.checked = p.includes(c.dataset.perm); }); });
      body.querySelector('form').addEventListener('submit', e => e.preventDefault());
      m.el.querySelector('[data-save]').onclick = async () => {
        const v = SC.vals(body), login = v.login.trim().toLowerCase();
        if (!v.nome.trim() || !login) return SC.toast('Informe o nome e o login.', 'err');
        if (SC.db.users.some(x => x.id !== (u && u.id) && x.login === login)) return SC.toast('Este login já está em uso.', 'err');
        if (isNew && !v.senha) return SC.toast('Informe a senha do usuário.', 'err');
        const perms = [...body.querySelectorAll('[data-perm]')].filter(c => c.checked).map(c => c.dataset.perm);
        if (u && u.id === SC.user.id && (!v.ativo || v.perfil !== 'admin') && SC.db.users.filter(x => x.perfil === 'admin' && x.ativo).length <= 1) return SC.toast('Você é o único administrador ativo. Mantenha seu perfil e acesso.', 'err');
        const base = u || { id: SC.uid() };
        Object.assign(base, { nome: v.nome.trim(), login, perfil: v.perfil, perms, ativo: v.ativo });
        if (v.senha) base.password = v.senha;
        if (isNew) SC.db.users.push(base);
        if (SC.user.id === base.id) SC.user = base;
        SC.log('usuario', `Usuário ${isNew ? 'criado' : 'atualizado'}: ${base.nome}`); if (!await SC.save()) return; m.close(); SC.refresh(); SC.renderShell(); SC.toast('Usuário salvo.');
      };
    }
  });

  /* ================= BACKUP ================= */
  const toCSV = (head, rows) => '﻿' + [head].concat(rows).map(r => r.map(x => { const s = String(x == null ? '' : x).replace(/"/g, '""'); return /[";\n]/.test(s) ? `"${s}"` : s; }).join(';')).join('\n');

  SC.pages.backup = {
    title: 'Backup',
    render(el) {
      const db = SC.db, kb = Math.round(JSON.stringify(db).length / 1024), ub = db.config.ultimoBackup;
      el.innerHTML = `<div class="page-head"><div><h1>Backup e restauração</h1><p>Os dados ficam salvos no servidor. Guarde cópias de segurança em outro lugar.</p></div></div>
        <div class="cols2">
        <div class="card"><div class="card-h"><h3>Fazer backup</h3></div><div class="card-b"><p>Baixa um arquivo <b>.json</b> com todos os dados: clientes, OS, orçamentos, vendas, produtos, usuários e configurações.</p>
          <p class="hint">Último backup: <b>${ub ? SC.fmtDT(ub) : 'nunca'}</b> · Tamanho dos dados: ${kb} KB · ${db.clientes.length} clientes, ${db.os.length} OS, ${db.orcamentos.length} orçamentos, ${db.vendas.length} vendas, ${db.produtos.length} produtos.</p>
          <button class="btn primary" id="bk">${icon('download', 16)} Baixar backup</button></div></div>
        <div class="card"><div class="card-h"><h3>Restaurar backup</h3></div><div class="card-b"><p>Seleciona um arquivo de backup e <b>substitui todos os dados atuais</b> por ele.</p><input type="file" id="rfile" accept=".json,application/json" style="display:none"><button class="btn" id="rb">${icon('upload', 16)} Escolher arquivo de backup</button></div></div>
        <div class="card"><div class="card-h"><h3>Exportar planilhas (CSV)</h3></div><div class="card-b"><p class="hint">Abre no Excel e no Google Planilhas.</p><div class="head-actions"><button class="btn" data-csv="clientes">Clientes</button><button class="btn" data-csv="os">Ordens de serviço</button><button class="btn" data-csv="vendas">Vendas</button><button class="btn" data-csv="produtos">Produtos</button></div></div></div>
        <div class="card"><div class="card-h"><h3>Dados de teste e limpeza</h3></div><div class="card-b"><p class="hint">Carregue exemplos para conhecer o sistema ou apague tudo para começar a usar de verdade.</p><div class="head-actions"><button class="btn" id="demo">Carregar dados de demonstração</button><button class="btn danger" id="reset">${icon('trash', 16)} Apagar todos os dados</button></div></div></div>
        </div>
        <p class="hint" style="margin-top:14px">Armazenamento do navegador: <b>${SC.storage.ok ? 'funcionando' : 'indisponível (modo privado ou bloqueado)'}</b>. Todos os computadores devem acessar o mesmo servidor.</p>`;
      el.querySelector('#bk').onclick = async () => {
        SC.db.config.ultimoBackup = SC.nowISO(); SC.log('backup', 'Backup completo gerado'); if (!await SC.save()) return;
        SC.download(`backup-smartcenter-${SC.today()}.json`, JSON.stringify(await SC.api('/api/backup'))); SC.toast('Backup gerado. Guarde o arquivo em local seguro.'); SC.refresh();
      };
      el.querySelector('#rb').onclick = () => el.querySelector('#rfile').click();
      el.querySelector('#rfile').addEventListener('change', async e => {
        const file = e.target.files[0]; if (!file) return;
        const rd = new FileReader();
        rd.onload = async () => {
          let d; try { d = JSON.parse(rd.result); } catch (x) { return SC.toast('Arquivo inválido: não é um backup do SmartCenter.', 'err'); }
          if (!d || !d.config || !Array.isArray(d.clientes) || !Array.isArray(d.os) || !Array.isArray(d.users)) return SC.toast('Arquivo inválido: não é um backup do SmartCenter.', 'err');
          if (await SC.confirm(`Restaurar o backup <b>${esc(file.name)}</b> (${d.clientes.length} clientes, ${d.os.length} OS, ${(d.vendas || []).length} vendas)? Todos os dados atuais serão substituídos.`, { danger: true, ok: 'Restaurar' })) {
            try { await SC.restore(d); SC.toast('Backup restaurado. Entre novamente.'); } catch (error) { SC.toast(error.message, 'err'); }
          }
        };
        rd.readAsText(file);
      });
      el.querySelectorAll('[data-csv]').forEach(b => b.onclick = async () => {
        const k = b.dataset.csv; let head, rows;
        if (k === 'clientes') { head = ['Nome', 'Telefone', 'WhatsApp', 'E-mail', 'CPF/CNPJ', 'CEP', 'Endereço', 'Cidade']; rows = db.clientes.map(c => [c.nome, c.telefone, c.whatsapp, c.email, c.doc, c.cep, c.endereco, c.cidade]); }
        if (k === 'os') { head = ['Nº', 'Entrada', 'Cliente', 'Aparelho', 'IMEI/Série', 'Defeito', 'Status', 'Mão de obra', 'Peças', 'Total', 'Prazo', 'Entrega']; rows = db.os.map(o => [SC.pad(o.numero), SC.fmtDate(o.dataEntrada), SC.cliOf(o).nome, (o.aparelho.marca + ' ' + o.aparelho.modelo).trim(), o.aparelho.imei, o.aparelho.defeito, o.status, SC.fmtNum(o.maoDeObra), SC.fmtNum(o.valorPecas), SC.fmtNum(o.total), SC.fmtDate(o.prazo), o.dataEntrega ? SC.fmtDate(o.dataEntrega) : '']); }
        if (k === 'vendas') { head = ['Nº', 'Data', 'Cliente', 'Itens', 'Pagamento', 'Subtotal', 'Desconto', 'Total', 'Lucro', 'Situação']; rows = db.vendas.map(v => [SC.pad(v.numero), SC.fmtDT(v.data), SC.cliOf(v).nome, v.itens.map(i => i.qtd + 'x ' + i.descricao).join(' | '), v.formaPagamento, SC.fmtNum(v.subtotal), SC.fmtNum(v.desconto), SC.fmtNum(v.total), SC.fmtNum(v.lucro), v.status]); }
        if (k === 'produtos') { head = ['Código', 'Produto', 'Categoria', 'Custo', 'Venda', 'Estoque', 'Mínimo']; rows = db.produtos.map(p => [p.codigo, p.nome, p.categoria, SC.fmtNum(p.custo), SC.fmtNum(p.preco), p.controla ? p.estoque : '', p.estoqueMin]); }
        SC.download(`${k}-${SC.today()}.csv`, toCSV(head, rows), 'text/csv;charset=utf-8');
      });
      el.querySelector('#demo').onclick = async () => { if (await SC.confirm('Adicionar clientes, produtos, OS, vendas e um orçamento de exemplo aos dados atuais?', { ok: 'Adicionar exemplos' })) { SC.loadDemo(); if (!await SC.save()) return; SC.toast('Dados de demonstração adicionados.'); SC.go('dashboard'); } };
      el.querySelector('#reset').onclick = async () => {
        const m = SC.modal({
          title: 'Apagar todos os dados', size: 'sm',
          body: `<p class="confirm-msg">Isto apaga <b>clientes, OS, orçamentos, vendas, produtos, usuários e configurações</b> e não pode ser desfeito. Faça um backup antes.</p><label class="f" style="margin-top:12px"><span>Digite APAGAR para confirmar</span><input id="rtxt" autocomplete="off"></label>`,
          footer: `<button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn danger" data-ok>Apagar tudo</button>`
        });
        m.el.querySelector('[data-ok]').onclick = async () => {
          if (m.el.querySelector('#rtxt').value.trim().toUpperCase() !== 'APAGAR') return SC.toast('Digite APAGAR para confirmar.', 'err');
          try { const data = SC.defaults(); const backup = await SC.api('/api/backup'); data.users = backup.users.filter(u => u.id === SC.user.id); await SC.restore(data); m.close(); SC.toast('Dados operacionais apagados. Entre novamente.'); } catch (error) { SC.toast(error.message, 'err'); }
        };
      };
    }
  };
})();
