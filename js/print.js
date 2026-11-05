/* print.js – documentos A4: Ordem de Serviço + Termo de Garantia, Orçamento e Comprovante de Venda */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon;
  const slug = s => SC.norm(s).replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 30);

  function head(title, num, data, customCfg) {
    const c = customCfg || SC.db.config;
    const ini = (c.nomeFantasia || 'SC').split(/\s+/).map(w => w[0]).join('').slice(0, 1).toUpperCase();
    const contato = [c.telefone ? 'Tel: ' + esc(c.telefone) : '', c.whatsapp ? 'WhatsApp: ' + esc(c.whatsapp) : '', c.email ? esc(c.email) : ''].filter(Boolean).join(' · ');
    const end = [c.endereco, c.cidade, c.cep ? 'CEP ' + c.cep : ''].filter(Boolean).map(esc).join(' – ');
    const info = [c.cnpj ? 'CNPJ ' + esc(c.cnpj) : '', contato, end].filter(Boolean).join(' · ');
    return `<div class="doc-head">
      <div class="dh-brand">
        <div class="dh-logo">${c.logo ? `<img src="${c.logo}" alt="Logotipo">` : `<div class="dh-mark">${esc(ini)}</div>`}</div>
        <div class="dh-store">
          <h1>${esc(c.nomeFantasia || 'SmartCenter')}</h1>
          ${info ? `<div class="dh-meta">${info}</div>` : ''}
        </div>
      </div>
      <div class="dh-doc">
        <div class="dh-title">${title}</div>
        <div class="dh-num">${num}</div>
        <div class="dh-date">${data}</div>
      </div>
    </div>`;
  }
  const k = (l, v, c = '') => `<div class="k ${c}"><span>${l}</span><b>${esc(v || '—')}</b></div>`;
  const box = (t, inner) => `<div class="box"><div class="box-t">${t}</div>${inner}</div>`;
  const grid = inner => `<div class="box-b">${inner}</div>`;
  const txt = v => `<div class="box-text">${esc(v || '—')}</div>`;
  const foot = () => `<div class="doc-foot">Documento emitido em ${SC.fmtDT(SC.nowISO())} · ${esc(SC.db.config.nomeFantasia)}${SC.db.config.cnpj ? ' · CNPJ ' + esc(SC.db.config.cnpj) : ''}</div>`;
  const linesTable = (l, vazio) => `<table class="doc-tbl"><thead><tr><th>Descrição</th><th class="r" style="width:12mm">Qtd</th><th class="r" style="width:26mm">Valor unit.</th><th class="r" style="width:26mm">Subtotal</th></tr></thead><tbody>${(l && l.length) ? l.map(i => `<tr><td>${esc(i.descricao)}</td><td class="r">${i.qtd}</td><td class="r">${SC.money(i.valor != null ? i.valor : i.preco)}</td><td class="r">${SC.money(i.qtd * (i.valor != null ? i.valor : i.preco))}</td></tr>`).join('') : `<tr><td colspan="4">${vazio}</td></tr>`}</tbody></table>`;
  const cliBox = c => box('Dados do cliente', grid(k('Nome', c.nome, 'c6') + k('Telefone', c.telefone, 'c3') + k('CPF / CNPJ', c.doc, 'c3') + k('Endereço', SC.enderecoCli(c), 'c12')));
  const garantiaTxt = d => (Number(d) > 0 ? d + ' dias' : 'sem garantia');

  /* Termo editável: "# título", "## seção", "- item", linha em branco separa parágrafos */
  function termoHTML(texto, vars) {
    const sub = s => esc(s).replace(/\{\{(\w+)\}\}/g, (m, key) => (key in vars ? esc(vars[key]) : m));
    let out = '', ul = false;
    const close = () => { if (ul) { out += '</ul>'; ul = false; } };
    String(texto || '').split('\n').forEach(raw => {
      const line = raw.trim();
      if (!line) { close(); return; }
      if (line.startsWith('## ')) { close(); out += `<h3 class="t-sec">${sub(line.slice(3))}</h3>`; }
      else if (line.startsWith('# ')) { close(); out += `<h2 class="t-main">${sub(line.slice(2))}</h2>`; }
      else if (line.startsWith('- ')) { if (!ul) { out += '<ul>'; ul = true; } out += `<li>${sub(line.slice(2))}</li>`; }
      else { close(); out += `<p>${sub(line)}</p>`; }
    });
    close();
    return `<div class="termo">${out}</div>`;
  }

  SC.print.show = (html, fileName) => {
    const old = document.getElementById('printRoot'); if (old) old.remove();
    const root = document.createElement('div');
    root.id = 'printRoot';
    root.innerHTML = `<div class="print-bar no-print"><div class="pb-title">Visualização de impressão · A4</div><div class="pb-actions"><button type="button" class="btn" data-pdf>${icon('download', 16)} Salvar em PDF</button><button type="button" class="btn primary" data-print>${icon('print', 16)} Imprimir</button><button type="button" class="btn ghost" data-x>${icon('x', 16)} Fechar</button></div></div><div class="print-stage">${html}</div>`;
    document.body.appendChild(root);
    document.body.classList.add('printing-open');
    const close = () => { root.remove(); document.body.classList.remove('printing-open'); document.removeEventListener('keydown', esc_); };
    const esc_ = e => { if (e.key === 'Escape') close(); };
    document.addEventListener('keydown', esc_);
    root.querySelector('[data-x]').onclick = close;
    root.querySelector('[data-print]').onclick = () => window.print();
    root.querySelector('[data-pdf]').onclick = () => {
      const prev = document.title; document.title = fileName || 'documento';
      SC.toast('Na janela de impressão, escolha "Salvar como PDF" em Destino.', 'ok');
      setTimeout(() => { window.print(); setTimeout(() => { document.title = prev; }, 1500); }, 250);
    };
    window.addEventListener('afterprint', () => { /* mantém a visualização aberta */ }, { once: true });
  };

  /* ---------- Ordem de Serviço (+ termo) ---------- */
  SC.print.os = id => {
    const o = SC.byId('os', id); if (!o) return;
    const c = SC.cliOf(o), ap = o.aparelho || {}, cfg = SC.db.config;
    const pg1 = `<section class="paper">${head('ORDEM DE SERVIÇO', 'Nº ' + SC.pad(o.numero), 'Entrada: ' + SC.fmtDate(o.dataEntrada))}
      ${cliBox(c)}
      ${box('Dados do aparelho', grid(k('Tipo', ap.tipo, 'c3') + k('Marca', ap.marca, 'c3') + k('Modelo', ap.modelo, 'c3') + k('IMEI / nº de série', ap.imei, 'c3') + k('Cor', ap.cor, 'c3') + k('Acessórios recebidos', ap.acessorios, 'c9') + k('Estado de conservação', ap.estado, 'c12')))}
      ${box('Defeito relatado pelo cliente', txt(ap.defeito))}
      ${box('Diagnóstico técnico', txt(o.diagnostico))}
      ${box('Serviços realizados', txt(o.servico))}
      ${box('Peças utilizadas', linesTable(o.pecas, '—'))}
      <div class="totals"><div><span>Mão de obra</span><b>${SC.money(o.maoDeObra)}</b></div><div><span>Peças</span><b>${SC.money(o.valorPecas)}</b></div><div class="tt"><span>TOTAL</span><span>${SC.money(o.total)}</span></div></div>
      ${box('Entrega, garantia e pagamento', grid(k('Prazo de entrega', SC.fmtDate(o.prazo), 'c3') + k('Garantia', garantiaTxt(o.garantiaDias), 'c3') + k('Status', o.status, 'c3') + k('Forma de pagamento', o.formaPagamento, 'c3') + k('Condições de pagamento', cfg.condicoesPagamento || 'Pagamento à vista (Pix, dinheiro ou débito) ou em até 12x no cartão de crédito, conforme taxas da operadora.\nO aparelho só é entregue mediante pagamento integral do serviço.', 'c12')))}
      ${o.observacoes ? box('Observações', txt(o.observacoes)) : ''}
      <p class="decl">Declaro que deixei o aparelho acima descrito, nas condições registradas, para análise/reparo, que as informações prestadas são verdadeiras e que li e concordo com o Termo de Garantia da página seguinte.</p>
      <div class="sigs"><div class="sig"><b>${esc(c.nome || 'Cliente')}</b>Assinatura do cliente</div><div class="sig"><b>${esc(cfg.responsavel || cfg.nomeFantasia)}</b>Responsável técnico</div></div>
      ${foot()}</section>`;
    const vars = { loja: cfg.nomeFantasia || 'SmartCenter', garantia: garantiaTxt(o.garantiaDias), os: SC.pad(o.numero), cliente: c.nome || '', aparelho: [ap.marca, ap.modelo].filter(Boolean).join(' '), data: SC.fmtDate(o.dataEntrada), telefone: cfg.telefone || cfg.whatsapp || '', endereco: [cfg.endereco, cfg.cidade].filter(Boolean).join(', '), cnpj: cfg.cnpj || '' };
    const pg2 = `<section class="paper">${head('TERMO DE GARANTIA', 'OS ' + SC.pad(o.numero), SC.fmtDate(o.dataEntrada))}
      <div class="t-ref"><b>Cliente:</b> ${esc(c.nome || '—')} &nbsp;·&nbsp; <b>Aparelho:</b> ${esc(vars.aparelho || '—')} ${ap.imei ? '&nbsp;·&nbsp; <b>IMEI/Série:</b> ' + esc(ap.imei) : ''} &nbsp;·&nbsp; <b>Garantia:</b> ${esc(vars.garantia)}</div>
      ${termoHTML(cfg.termoGarantia, vars)}
      <p class="termo-decl">Declaro ter lido e concordado com todas as condições deste Termo de Garantia.</p>
      <div class="sigs"><div class="sig"><b>${esc(c.nome || 'Cliente')}</b>Assinatura do cliente · Data ____/____/______</div><div class="sig"><b>${esc(cfg.responsavel || cfg.nomeFantasia)}</b>Responsável técnico</div></div>
      ${foot()}</section>`;
    SC.print.show(pg1 + pg2, `OS-${SC.pad(o.numero)}-${slug(c.nome)}`);
  };

  /* Pré-visualização do termo com dados dinâmicos ou de exemplo (usada nas configurações) */
  SC.print.termo = (texto, vals, customLogo) => {
    const cfg = Object.assign({}, SC.db.config, vals || {});
    if (customLogo !== undefined) cfg.logo = customLogo;
    const vars = {
      loja: cfg.nomeFantasia || 'SmartCenter',
      garantia: (cfg.garantiaPadraoDias || 0) + ' dias',
      os: '000000',
      cliente: 'Nome do Cliente',
      aparelho: 'Marca Modelo',
      data: SC.fmtDate(SC.today()),
      telefone: cfg.telefone || cfg.whatsapp || '',
      endereco: [cfg.endereco, cfg.cidade].filter(Boolean).join(', '),
      cnpj: cfg.cnpj || ''
    };
    SC.print.show(`<section class="paper">${head('TERMO DE GARANTIA', 'Pré-visualização', SC.fmtDate(SC.today()), cfg)}${termoHTML(texto, vars)}<div class="sigs"><div class="sig"><b>Nome do Cliente</b>Assinatura do cliente</div><div class="sig"><b>${esc(cfg.responsavel || cfg.nomeFantasia || 'Responsável técnico')}</b>Responsável técnico</div></div>${foot()}</section>`, 'Termo-de-garantia');
  };

  /* ---------- Orçamento ---------- */
  SC.print.orc = id => {
    const q = SC.byId('orcamentos', id); if (!q) return;
    const c = SC.cliOf(q), ap = q.aparelho || {}, cfg = SC.db.config;
    const html = `<section class="paper">${head('ORÇAMENTO', 'Nº ' + SC.pad(q.numero), 'Emitido em ' + SC.fmtDate(q.data))}
      ${cliBox(c)}
      ${box('Aparelho', grid(k('Tipo', ap.tipo, 'c3') + k('Marca', ap.marca, 'c3') + k('Modelo', ap.modelo, 'c6')))}
      ${box('Descrição do defeito', txt(ap.defeito))}
      ${box('Diagnóstico', txt(q.diagnostico))}
      ${box('Peças necessárias', linesTable(q.pecas, 'Sem peças.'))}
      <div class="totals"><div><span>Mão de obra</span><b>${SC.money(q.maoDeObra)}</b></div><div><span>Peças</span><b>${SC.money(q.valorPecas)}</b></div><div class="tt"><span>TOTAL</span><span>${SC.money(q.total)}</span></div></div>
      ${box('Validade e condições', grid(k('Validade do orçamento', SC.fmtDate(q.validade), 'c4') + k('Situação', q.status, 'c4') + k('Condições de pagamento', cfg.condicoesPagamento, 'c12')))}
      ${q.observacoes ? box('Observações', txt(q.observacoes)) : ''}
      <p class="decl">Os valores acima são válidos até a data de validade informada. A execução do serviço depende da aprovação do cliente.</p>
      <div class="sigs"><div class="sig"><b>${esc(c.nome || 'Cliente')}</b>De acordo – assinatura do cliente</div><div class="sig"><b>${esc(cfg.responsavel || cfg.nomeFantasia)}</b>Responsável técnico</div></div>
      ${foot()}</section>`;
    SC.print.show(html, `Orcamento-${SC.pad(q.numero)}-${slug(c.nome)}`);
  };

  /* ---------- Comprovante de venda ---------- */
  SC.print.venda = id => {
    const v = SC.byId('vendas', id); if (!v) return;
    const c = SC.cliOf(v), cfg = SC.db.config;
    const html = `<section class="paper">${head('COMPROVANTE DE VENDA', 'Nº ' + SC.pad(v.numero), SC.fmtDT(v.data))}
      ${v.status === 'Cancelada' ? '<div class="box"><div class="box-t" style="background:#fde8e8;color:#bb2d2d">VENDA CANCELADA</div></div>' : ''}
      ${box('Cliente', grid(k('Nome', c.nome || 'Consumidor final', 'c6') + k('Telefone', c.telefone, 'c3') + k('CPF / CNPJ', c.doc, 'c3')))}
      ${box('Itens vendidos', linesTable(v.itens, 'Sem itens.'))}
      <div class="totals"><div><span>Subtotal</span><b>${SC.money(v.subtotal)}</b></div><div><span>Desconto</span><b>− ${SC.money(v.desconto)}</b></div><div class="tt"><span>TOTAL</span><span>${SC.money(v.total)}</span></div></div>
      ${box('Pagamento', grid(k('Forma de pagamento', v.formaPagamento + (v.parcelas > 1 ? ` em ${v.parcelas}x de ${SC.money(v.total / v.parcelas)}` : ''), 'c8') + k('Atendente', v.usuario, 'c4') + (v.obs ? k('Observações', v.obs, 'c12') : '')))}
      <div class="sigs"><div class="sig"><b>${esc(c.nome || 'Cliente')}</b>Assinatura do cliente</div><div class="sig"><b>${esc(cfg.nomeFantasia)}</b>Vendedor</div></div>
      <div class="nofiscal">Este comprovante não possui valor fiscal. Troca ou garantia mediante apresentação deste documento.</div>
      ${foot()}</section>`;
    SC.print.show(html, `Venda-${SC.pad(v.numero)}-${slug(c.nome || 'consumidor')}`);
  };
})();
