/* dashboard.js – painel principal */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon;
  const FIM = ['Concluído', 'Entregue'];
  const TIPO_IC = { os: 'wrench', orcamento: 'file', venda: 'cart', cliente: 'user', produto: 'box', sistema: 'settings', usuario: 'shield', backup: 'database' };

  SC.pages.dashboard = {
    title: 'Painel',
    render(el) {
      const db = SC.db, t = SC.today(), mes = t.slice(0, 7);
      const n = lst => db.os.filter(o => lst.includes(o.status)).length;
      const rev = SC.revenue(), sum = a => a.reduce((s, r) => s + (typeof r === 'number' ? r : (r && r.valor != null ? r.valor : (r && r.total != null ? r.total : 0))), 0);
      const hoje = sum(rev.filter(r => r.date === t)), mensal = sum(rev.filter(r => r.date.slice(0, 7) === mes));
      const vOk = db.vendas.filter(v => v.status !== 'Cancelada');
      const pend = db.orcamentos.filter(o => o.status === 'Pendente');
      const card = (ic, label, val, sub, go, filt, tone = '') => `<button class="stat ${tone}" data-go="${go}" data-filter="${esc(filt || '')}"><span class="stat-ic">${icon(ic, 22)}</span><div><small>${label}</small><b>${val}</b><em>${sub}</em></div></button>`;

      // faturamento últimos 14 dias
      const dias = []; for (let i = 13; i >= 0; i--) dias.push(SC.addDays(t, -i));
      const porDia = dias.map(d => sum(rev.filter(r => r.date === d))), max = Math.max(...porDia, 1);
      const bars = dias.map((d, i) => `<div class="bar${d === t ? ' today' : ''}" title="${SC.fmtDate(d)}: ${SC.money(porDia[i])}"><i style="height:${Math.max(1, (porDia[i] / max) * 100)}%"></i><small>${d.slice(8)}</small></div>`).join('');
      const totalOS = db.os.length || 1;
      const hb = SC.STATUS_OS.map(s => { const c = db.os.filter(o => o.status === s).length; return `<div class="hbar"><span>${s}</span><div><i style="width:${(c / totalOS) * 100}%"></i></div><b>${c}</b></div>`; }).join('');

      // alertas
      const al = [];
      const atras = db.os.filter(o => o.prazo && o.prazo < t && !FIM.includes(o.status)).length;
      if (atras) al.push(`<div class="alert">${icon('clock', 18)}<span>${atras} OS com prazo vencido.</span><button class="btn sm" data-go="os" data-filter="atrasadas">Ver OS</button></div>`);
      const bx = db.produtos.filter(p => p.controla && p.estoque <= (p.estoqueMin || 0)).length;
      if (bx) al.push(`<div class="alert">${icon('box', 18)}<span>${bx} produto(s) com estoque baixo ou zerado.</span><button class="btn sm" data-go="produtos" data-filter="baixo">Ver</button></div>`);
      const dias7 = SC.db.config.ultimoBackup ? (new Date(t) - new Date(SC.db.config.ultimoBackup.slice(0, 10))) / 864e5 : 999;
      if ((db.os.length + db.clientes.length + db.vendas.length) && dias7 > 7 && SC.can('backup')) al.push(`<div class="alert">${icon('database', 18)}<span>${SC.db.config.ultimoBackup ? 'O último backup tem mais de 7 dias.' : 'Você ainda não fez nenhum backup.'}</span><button class="btn sm" data-go="backup" data-filter="">Fazer backup</button></div>`);
      if (SC.user.senha === SC.hash('admin')) al.push(`<div class="alert">${icon('key', 18)}<span>Você ainda usa a senha padrão. Troque-a no menu do usuário.</span><button class="btn sm" data-pass>Trocar senha</button></div>`);
      if (!SC.db.config.cnpj && !SC.db.config.endereco && SC.can('config')) al.push(`<div class="alert">${icon('settings', 18)}<span>Cadastre os dados da loja para que apareçam nos documentos impressos.</span><button class="btn sm" data-go="config" data-filter="">Configurar</button></div>`);
      if (!al.length) al.push(`<div class="alert ok">${icon('check', 18)}<span>Tudo em ordem. Nenhum alerta no momento.</span></div>`);

      el.innerHTML = `<div class="page-head"><div><h1>Painel</h1><p>Visão geral da assistência técnica em ${SC.fmtDate(t)}.</p></div>
        <div class="head-actions">${SC.can('os') ? `<button class="btn primary" data-q="os">${icon('plus')} Nova OS</button>` : ''}${SC.can('orcamentos') ? `<button class="btn" data-q="orc">${icon('plus')} Orçamento</button>` : ''}${SC.can('vendas') ? `<button class="btn" data-q="venda">${icon('plus')} Venda</button>` : ''}</div></div>
        <div class="stats">
          ${card('wrench', 'Total de ordens de serviço', db.os.length, `${db.os.filter(o => o.dataEntrada.slice(0, 7) === mes).length} abertas neste mês`, 'os', '')}
          ${card('clock', 'Aguardando aprovação', n(['Aguardando aprovação']), 'serviços com o cliente decidir', 'os', 'Aguardando aprovação', 't-warn')}
          ${card('phone2', 'Aparelhos em manutenção', n(['Em análise', 'Aguardando peças', 'Em reparo']), 'em análise, peças ou reparo', 'os', 'Em reparo')}
          ${card('check', 'Serviços concluídos', n(FIM), `${n(['Concluído'])} aguardando retirada`, 'os', 'Concluído', 't-ok')}
          ${card('cart', 'Total de vendas', vOk.length, SC.money(sum(vOk)) + ' vendidos', 'vendas', '')}
          ${card('dollar', 'Faturamento de hoje', SC.money(hoje), 'vendas + OS entregues', 'vendas', '', 't-navy')}
          ${card('chart', 'Faturamento do mês', SC.money(mensal), 'vendas + OS entregues', 'vendas', '', 't-navy')}
          ${card('file', 'Orçamentos pendentes', pend.length, SC.money(sum(pend)) + ' em aberto', 'orcamentos', 'Pendente', 't-warn')}
        </div>
        <div class="dash-grid"><div class="card"><div class="card-h"><h3>Faturamento dos últimos 14 dias</h3><small>Total no período: ${SC.money(sum(porDia))}</small></div><div class="card-b"><div class="bars">${bars}</div></div></div>
          <div class="card"><div class="card-h"><h3>Ordens de serviço por status</h3></div><div class="card-b">${hb}</div></div></div>
        <div class="card"><div class="card-h"><h3>Alertas</h3></div><div class="alerts">${al.join('')}</div></div>`;

      el.onclick = e => {
        const g = e.target.closest('[data-go]');
        if (g) {
          const pg = g.dataset.go, fl = g.dataset.filter;
          if (pg === 'os') { SC.pages.os.state.status = fl; SC.pages.os.state.q = ''; SC.pages.os.state.page = 1; }
          if (pg === 'orcamentos') { SC.pages.orcamentos.state.status = fl; SC.pages.orcamentos.state.q = ''; SC.pages.orcamentos.state.page = 1; }
          if (pg === 'produtos') SC.pages.produtos.state.baixo = fl === 'baixo';
          SC.go(pg); return;
        }
        const q = e.target.closest('[data-q]');
        if (q) { SC.go({ os: 'os', orc: 'orcamentos', venda: 'vendas' }[q.dataset.q]); ({ os: () => SC.pages.os.form(), orc: () => SC.pages.orcamentos.form(), venda: () => SC.pages.vendas.form() })[q.dataset.q](); return; }
        if (e.target.closest('[data-pass]')) SC.changePassword();
      };
    }
  };
})();
