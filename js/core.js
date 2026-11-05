/* core.js – dados, armazenamento, formatação e regras de negócio compartilhadas.
   Para integrar com um banco de dados no futuro, substitua apenas SC.storage (read/write/clear). */
(function () {
  'use strict';
  const SC = (window.SC = { pages: {}, print: {} });
  const KEY = 'smartcenter.db.v1';
  const SKEY = 'smartcenter.session';

  /* ---------- Constantes ---------- */
  SC.STATUS_OS = ['Recebido', 'Em análise', 'Aguardando aprovação', 'Aguardando peças', 'Em reparo', 'Concluído', 'Entregue'];
  SC.STATUS_ORC = ['Pendente', 'Aprovado', 'Recusado'];
  SC.CATEGORIAS = ['Celular', 'Acessório', 'Peça', 'Serviço', 'Outro'];
  SC.PAGAMENTOS = ['Dinheiro', 'Pix', 'Cartão de débito', 'Cartão de crédito', 'Crédito parcelado', 'Transferência', 'Boleto', 'Outro'];
  SC.APARELHOS = ['Celular', 'Tablet', 'Notebook', 'Computador', 'Console / Videogame', 'Smartwatch', 'Outro'];
  SC.MODULOS = [
    { k: 'dashboard', n: 'Painel' }, { k: 'os', n: 'Ordens de serviço' }, { k: 'orcamentos', n: 'Orçamentos' },
    { k: 'vendas', n: 'Vendas' }, { k: 'produtos', n: 'Produtos e estoque' }, { k: 'clientes', n: 'Clientes' },
    { k: 'config', n: 'Configurações da loja' }, { k: 'usuarios', n: 'Usuários e permissões' },
    { k: 'backup', n: 'Backup e restauração' }, { k: 'excluir', n: 'Excluir registros' }
  ];
  SC.PERFIS = {
    admin: { nome: 'Administrador', perms: SC.MODULOS.map(m => m.k) },
    atendente: { nome: 'Atendente', perms: ['dashboard', 'os', 'orcamentos', 'vendas', 'produtos', 'clientes'] },
    tecnico: { nome: 'Técnico', perms: ['dashboard', 'os', 'orcamentos', 'clientes'] },
    vendedor: { nome: 'Vendedor', perms: ['dashboard', 'vendas', 'produtos', 'clientes'] }
  };
  SC.statusClass = s => ({
    'Recebido': 's-recebido', 'Em análise': 's-analise', 'Aguardando aprovação': 's-aprovacao', 'Aguardando peças': 's-pecas',
    'Em reparo': 's-reparo', 'Concluído': 's-concluido', 'Entregue': 's-entregue',
    'Pendente': 's-pendente', 'Aprovado': 's-aprovado', 'Recusado': 's-recusado'
  })[s] || 's-recebido';

  /* ---------- Utilidades ---------- */
  const p2 = n => String(n).padStart(2, '0');
  SC.esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  SC.uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  SC.pad = (n, l = 6) => String(n).padStart(l, '0');
  SC.r2 = n => Math.round((Number(n) || 0) * 100) / 100;
  const nf = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
  SC.money = n => nf.format(Number(n) || 0);
  SC.fmtNum = n => (Number(n) || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  SC.parseMoney = v => {
    if (typeof v === 'number') return v;
    let s = String(v || '').replace(/[^\d,.-]/g, '');
    if (!s) return 0;
    if (s.includes(',')) s = s.replace(/\./g, '').replace(',', '.');
    return parseFloat(s) || 0;
  };
  SC.nowISO = () => { const d = new Date(); return `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}T${p2(d.getHours())}:${p2(d.getMinutes())}:${p2(d.getSeconds())}`; };
  SC.today = () => SC.nowISO().slice(0, 10);
  SC.addDays = (iso, n) => { const [y, m, d] = iso.slice(0, 10).split('-').map(Number); const dt = new Date(y, m - 1, d + n); return `${dt.getFullYear()}-${p2(dt.getMonth() + 1)}-${p2(dt.getDate())}`; };
  SC.fmtDate = iso => { if (!iso) return '—'; const [y, m, d] = iso.slice(0, 10).split('-'); return `${d}/${m}/${y}`; };
  SC.fmtDT = iso => (!iso ? '—' : `${SC.fmtDate(iso)} ${iso.slice(11, 16)}`);
  SC.norm = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  SC.digits = s => String(s || '').replace(/\D/g, '');
  SC.maskDoc = v => {
    const d = SC.digits(v).slice(0, 14);
    if (d.length <= 11) return d.replace(/(\d{3})(\d)/, '$1.$2').replace(/(\d{3})(\d)/, '$1.$2').replace(/(\d{3})(\d{1,2})$/, '$1-$2');
    return d.replace(/^(\d{2})(\d)/, '$1.$2').replace(/^(\d{2})\.(\d{3})(\d)/, '$1.$2.$3').replace(/\.(\d{3})(\d)/, '.$1/$2').replace(/(\d{4})(\d)/, '$1-$2');
  };
  SC.maskPhone = v => {
    const d = SC.digits(v).slice(0, 11);
    if (d.length <= 2) return d.length ? `(${d}` : '';
    if (d.length <= 6) return `(${d.slice(0, 2)}) ${d.slice(2)}`;
    if (d.length <= 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`;
    return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`;
  };
  SC.maskCep = v => { const d = SC.digits(v).slice(0, 8); return d.length > 5 ? d.slice(0, 5) + '-' + d.slice(5) : d; };
  SC.validDoc = v => {
    const d = SC.digits(v);
    if (!d) return true;
    if (/^(\d)\1+$/.test(d)) return false;
    if (d.length === 11) {
      let s = 0;
      for (let i = 0; i < 9; i++) s += d[i] * (10 - i);
      let c = ((s * 10) % 11) % 10;
      if (c != d[9]) return false;
      s = 0;
      for (let i = 0; i < 10; i++) s += d[i] * (11 - i);
      c = ((s * 10) % 11) % 10;
      return c == d[10];
    }
    if (d.length === 14) {
      const calc = n => { let s = 0, pos = n - 7; for (let i = n; i >= 1; i--) { s += d[n - i] * pos--; if (pos < 2) pos = 9; } const r = s % 11; return r < 2 ? 0 : 11 - r; };
      return calc(12) == d[12] && calc(13) == d[13];
    }
    return false;
  };
  SC.hash = s => {
    let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
    const str = 'sc|' + s;
    for (let i = 0; i < str.length; i++) { const ch = str.charCodeAt(i); h1 = Math.imul(h1 ^ ch, 2654435761); h2 = Math.imul(h2 ^ ch, 1597334677); }
    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
    return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(16);
  };
  SC.debounce = (fn, ms = 200) => { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; };

  /* ---------- Armazenamento (adaptador SQLite + fallback LocalStorage) ---------- */
  SC.storage = {
    mem: null, ok: true, isSQLite: false,
    read() {
      try {
        const t = localStorage.getItem(KEY);
        this.ok = true;
        return t ? JSON.parse(t) : this.mem;
      } catch (e) {
        this.ok = false;
        return this.mem;
      }
    },
    write(d) {
      this.mem = d;
      try {
        localStorage.setItem(KEY, JSON.stringify(d));
        this.ok = true;
      } catch (e) {
        this.ok = false;
      }
      if (this.isSQLite) {
        SC.storage.saveSQLite(d);
      }
      return this.ok || this.isSQLite;
    },
    clear() {
      this.mem = null;
      try { localStorage.removeItem(KEY); } catch (e) { /* ignore */ }
      if (this.isSQLite) {
        fetch('/api/save', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(SC.defaults()) }).catch(() => {});
      }
    },
    async saveSQLite(d) {
      try {
        const res = await fetch('/api/save', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(d)
        });
        if (res.ok) {
          this.isSQLite = true;
          return true;
        }
      } catch (e) {
        console.warn('Sincronização com SQLite offline:', e);
      }
      return false;
    },
    async checkSQLite() {
      if (location.protocol !== 'http:' && location.protocol !== 'https:') return false;
      try {
        const res = await fetch('/api/status', { cache: 'no-store' });
        if (res.ok) {
          const data = await res.json();
          if (data && data.driver === 'sqlite') {
            this.isSQLite = true;
            return data;
          }
        }
      } catch (e) {
        this.isSQLite = false;
      }
      return false;
    }
  };
  SC.session = {
    get() { try { return sessionStorage.getItem(SKEY); } catch (e) { return SC._sess || null; } },
    set(v) { SC._sess = v; try { v ? sessionStorage.setItem(SKEY, v) : sessionStorage.removeItem(SKEY); } catch (e) { /* ignore */ } }
  };

  SC.TERMO_PADRAO = [
    '# TERMO DE GARANTIA',
    '',
    'A {{loja}} garante, pelo prazo de {{garantia}}, contado a partir da data de entrega do aparelho ao cliente, os serviços executados e as peças substituídas na Ordem de Serviço nº {{os}}, nos termos abaixo.',
    '',
    '## 1. PRAZO DE GARANTIA',
    '- A garantia é de {{garantia}}, contada da data de entrega do aparelho, e cobre exclusivamente o serviço executado e as peças substituídas descritos na Ordem de Serviço.',
    '- A garantia contratual é complementar à garantia legal prevista no Código de Defesa do Consumidor (Lei nº 8.078/1990).',
    '- Peças e serviços não descritos na Ordem de Serviço não estão cobertos por este termo.',
    '',
    '## 2. CONDIÇÕES DE COBERTURA',
    '- Defeito de funcionamento diretamente relacionado ao serviço executado ou à peça substituída.',
    '- Para acionar a garantia, o cliente deve apresentar este termo, a Ordem de Serviço e documento de identificação.',
    '- Constatado o defeito coberto, a peça será reparada ou substituída por outra equivalente, sem custo ao cliente, no prazo legal.',
    '- A peça substituída em garantia passa a ter, como prazo, o restante da garantia original.',
    '',
    '## 3. EXCLUSÕES DE GARANTIA',
    '- Danos causados por queda, impacto, pressão, trincas ou tela quebrada após a entrega do aparelho.',
    '- Contato com líquidos, umidade, oxidação ou corrosão.',
    '- Mau uso, uso de carregadores e acessórios fora de especificação, oscilações ou sobrecarga de energia.',
    '- Problemas de software: vírus, atualizações, aplicativos, senhas, bloqueios de conta e desbloqueios.',
    '- Defeitos diferentes do reparo executado ou que não constavam no defeito relatado na Ordem de Serviço.',
    '- Desgaste natural de peças, como baterias, botões, alto-falantes e conectores.',
    '- Perda de dados e arquivos. O cliente deve manter cópia de segurança (backup) antes de entregar o aparelho.',
    '',
    '## 4. SITUAÇÕES DE CANCELAMENTO DA GARANTIA',
    '- Rompimento, violação ou remoção dos lacres e etiquetas de garantia.',
    '- Abertura, reparo ou manipulação do aparelho por terceiros não autorizados.',
    '- Danos físicos, marcas de impacto ou contato com líquidos após a entrega.',
    '- Instalação de sistemas ou programas não oficiais (root, jailbreak e similares).',
    '- Não apresentação da Ordem de Serviço e deste termo, ou documentos com rasuras.',
    '',
    '## 5. ORIENTAÇÕES AO CONSUMIDOR',
    '- Confira o funcionamento do aparelho no ato da retirada. Reclamações posteriores sobre acessórios ou condições não registrados na Ordem de Serviço não serão aceitas.',
    '- O aparelho deve ser retirado em até 90 dias após o aviso de conclusão. Após esse prazo, poderá ser cobrada taxa de armazenamento e aplicadas as medidas previstas em lei.',
    '- A retirada do aparelho exige a apresentação da Ordem de Serviço e de documento com foto.',
    '- Faça backup dos seus dados com frequência.',
    '- Para acionar a garantia ou tirar dúvidas, procure a {{loja}}: {{telefone}} – {{endereco}}.',
    '',
    'Declaro ter lido e concordado com todas as condições deste Termo de Garantia.'
  ].join('\n');

  SC.defaults = () => ({
    versao: 1, criadoEm: SC.nowISO(),
    config: {
      nomeFantasia: 'SmartCenter', razaoSocial: '', cnpj: '', endereco: '', cep: '', cidade: '', telefone: '', whatsapp: '', email: '',
      responsavel: '', logo: '', garantiaPadraoDias: 90,
      condicoesPagamento: 'Pagamento à vista (Pix, dinheiro ou débito) ou em até 12x no cartão de crédito, conforme taxas da operadora. O aparelho só é entregue mediante pagamento integral do serviço.',
      termoGarantia: SC.TERMO_PADRAO, ultimoBackup: null
    },
    users: [{ id: SC.uid(), nome: 'Administrador', login: 'admin', senha: SC.hash('admin'), perfil: 'admin', perms: SC.PERFIS.admin.perms.slice(), ativo: true }],
    clientes: [], os: [], orcamentos: [], produtos: [], vendas: [], log: [],
    seq: { os: 0, orcamento: 0, venda: 0, produto: 0 }
  });

  SC.load = async () => {
    const def = SC.defaults();
    let d = null;

    const sqliteStatus = await SC.storage.checkSQLite();
    if (sqliteStatus) {
      try {
        const res = await fetch('/api/db', { cache: 'no-store' });
        if (res.ok) {
          const snap = await res.json();
          if (snap.hasData) {
            d = snap.db;
          } else {
            const localData = SC.storage.read();
            if (localData && (localData.clientes?.length || localData.os?.length || localData.produtos?.length)) {
              d = Object.assign(def, localData);
              await SC.storage.saveSQLite(d);
            }
          }
        }
      } catch (e) {
        console.warn('Erro ao carregar do SQLite, usando fallback:', e);
      }
    }

    if (!d) d = SC.storage.read();
    if (!d) { SC.db = def; SC.save(); return; }
    SC.db = Object.assign(def, d);
    SC.db.config = Object.assign(SC.defaults().config, d.config || {});
    SC.db.seq = Object.assign({ os: 0, orcamento: 0, venda: 0, produto: 0 }, d.seq || {});
    if (!SC.db.users || !SC.db.users.length) SC.db.users = SC.defaults().users;
    try { localStorage.setItem(KEY, JSON.stringify(SC.db)); } catch {}
  };
  let warned = false;
  SC.save = () => {
    const ok = SC.storage.write(SC.db);
    if (!ok && !warned && !SC.storage.isSQLite && SC.toast) {
      warned = true;
      SC.toast('Não foi possível gravar no navegador (armazenamento cheio ou bloqueado). Faça um backup agora.', 'warn');
    }
    return ok;
  };

  /* ---------- Acesso e regras ---------- */
  SC.byId = (list, id) => SC.db[list].find(x => x.id === id);
  SC.nextNum = k => { SC.db.seq[k] = (SC.db.seq[k] || 0) + 1; return SC.db.seq[k]; };
  SC.can = k => !!SC.user && (SC.user.perfil === 'admin' || (SC.user.perms || []).includes(k));
  SC.log = (tipo, texto) => {
    SC.db.log.unshift({ id: SC.uid(), data: SC.nowISO(), usuario: SC.user ? SC.user.nome : '—', tipo, texto });
    if (SC.db.log.length > 500) SC.db.log.length = 500;
  };
  SC.cliOf = o => SC.byId('clientes', o.clienteId) || o.cliSnap || { nome: o.clienteNome || 'Consumidor final' };
  SC.enderecoCli = c => [c.endereco, c.cidade, c.cep].filter(Boolean).join(' – ');
  SC.sumLines = l => SC.r2((l || []).reduce((a, x) => a + (x.qtd || 0) * (x.valor || 0), 0));
  SC.upsertClient = v => {
    const nome = (v.c_nome || '').trim();
    if (!nome) return null;
    let c = v.clienteId ? SC.byId('clientes', v.clienteId) : null;
    const doc = SC.digits(v.c_doc);
    if (!c && doc) c = SC.db.clientes.find(x => SC.digits(x.doc) === doc);
    if (c) {
      c.nome = nome; c.telefone = v.c_tel || ''; c.doc = v.c_doc || ''; c.endereco = v.c_end || '';
      if (!c.whatsapp) c.whatsapp = c.telefone;
    } else {
      c = { id: SC.uid(), nome, telefone: v.c_tel || '', whatsapp: v.c_tel || '', email: '', doc: v.c_doc || '', cep: '', endereco: v.c_end || '', cidade: '', obs: '', criadoEm: SC.nowISO() };
      SC.db.clientes.push(c);
      SC.log('cliente', 'Cliente cadastrado: ' + nome);
    }
    return c;
  };
  SC.snap = c => ({ nome: c.nome, telefone: c.telefone, doc: c.doc, endereco: c.endereco, cidade: c.cidade, cep: c.cep });

  /* Estoque */
  SC.baixaEstoque = itens => {
    const feito = [];
    (itens || []).forEach(i => {
      const p = i.produtoId && SC.byId('produtos', i.produtoId);
      if (p && p.controla) { p.estoque = (Number(p.estoque) || 0) - i.qtd; feito.push({ produtoId: p.id, qtd: i.qtd }); }
    });
    return feito;
  };
  SC.estornaEstoque = baixas => (baixas || []).forEach(b => { const p = SC.byId('produtos', b.produtoId); if (p) p.estoque = (Number(p.estoque) || 0) + b.qtd; });

  /* Faturamento: OS entregues (data de entrega) + vendas concluídas */
  SC.revenue = () => {
    const r = [];
    SC.db.os.forEach(o => { if (o.status === 'Entregue') r.push({ date: (o.dataEntrega || o.dataEntrada).slice(0, 10), valor: o.total || 0, tipo: 'OS' }); });
    SC.db.vendas.forEach(v => { if (v.status !== 'Cancelada') r.push({ date: v.data.slice(0, 10), valor: v.total || 0, tipo: 'Venda' }); });
    return r;
  };

  /* Dados de demonstração (apenas adiciona) */
  SC.loadDemo = () => {
    const d = SC.db, t = SC.today();
    const cli = [
      ['Marcos Oliveira', '(11) 98877-1020', '529.982.247-25', 'Rua das Flores, 120 - Centro', 'São Paulo'],
      ['Fernanda Lima', '(11) 97766-3344', '', 'Av. Brasil, 455 - Jardim América', 'São Paulo'],
      ['Carlos Mendes', '(11) 3344-5566', '11.222.333/0001-81', 'Rua Augusta, 900 - Consolação', 'São Paulo']
    ].map(x => { const c = { id: SC.uid(), nome: x[0], telefone: x[1], whatsapp: x[1], email: '', doc: x[2], cep: '', endereco: x[3], cidade: x[4], obs: '', criadoEm: SC.nowISO() }; d.clientes.push(c); return c; });
    const prod = [
      ['Tela iPhone 11 (OEM)', 'Peça', 120, 289.9, 6, 2], ['Bateria Samsung A30', 'Peça', 38, 99.9, 9, 3], ['Película 3D', 'Acessório', 2.5, 19.9, 40, 10],
      ['Capinha Silicone', 'Acessório', 6, 29.9, 25, 8], ['Carregador Turbo 25W', 'Acessório', 22, 69.9, 2, 4], ['Formatação / Backup', 'Serviço', 0, 80, 0, 0]
    ].map(x => { const p = { id: SC.uid(), codigo: 'P' + SC.pad(SC.nextNum('produto'), 4), nome: x[0], categoria: x[1], custo: x[2], preco: x[3], estoque: x[4], estoqueMin: x[5], controla: x[1] !== 'Serviço' }; d.produtos.push(p); return p; });
    const mk = (c, ap, st, dias, pecas, mo, prazoOff) => {
      const o = { id: SC.uid(), numero: SC.nextNum('os'), dataEntrada: SC.addDays(t, -dias) + 'T10:00:00', clienteId: c.id, cliSnap: SC.snap(c), aparelho: ap, diagnostico: ap.diag || '', servico: '', pecas, maoDeObra: mo, valorPecas: SC.sumLines(pecas), total: SC.r2(SC.sumLines(pecas) + mo), prazo: SC.addDays(t, prazoOff), garantiaDias: 90, formaPagamento: 'Pix', observacoes: '', status: 'Recebido', historico: [], baixaEstoque: [], estoqueBaixado: false };
      d.os.unshift(o);
      o.status = st; o.historico.push({ status: st, data: o.dataEntrada, usuario: 'Demonstração' });
      if (['Concluído', 'Entregue'].includes(st)) { o.dataConclusao = o.dataEntrada; o.estoqueBaixado = true; }
      if (st === 'Entregue') o.dataEntrega = SC.addDays(t, -Math.max(0, dias - 1)) + 'T16:00:00';
    };
    mk(cli[0], { tipo: 'Celular', marca: 'Apple', modelo: 'iPhone 11', imei: '356789012345678', cor: 'Preto', acessorios: 'Capa', estado: 'Tela trincada', defeito: 'Tela quebrada', diag: 'Display danificado' }, 'Em reparo', 2, [{ produtoId: prod[0].id, descricao: prod[0].nome, qtd: 1, valor: 289.9 }], 80, 1);
    mk(cli[1], { tipo: 'Celular', marca: 'Samsung', modelo: 'Galaxy A30', imei: '359876543210987', cor: 'Azul', acessorios: 'Nenhum', estado: 'Bom estado', defeito: 'Bateria não segura carga', diag: '' }, 'Aguardando aprovação', 1, [{ produtoId: prod[1].id, descricao: prod[1].nome, qtd: 1, valor: 99.9 }], 50, 3);
    mk(cli[2], { tipo: 'Notebook', marca: 'Dell', modelo: 'Inspiron 15', imei: 'SN-DL5521', cor: 'Prata', acessorios: 'Carregador', estado: 'Riscos na tampa', defeito: 'Lento, não inicia o Windows', diag: '' }, 'Entregue', 5, [], 150, -3);
    mk(cli[0], { tipo: 'Celular', marca: 'Motorola', modelo: 'Moto G22', imei: '', cor: '', acessorios: '', estado: '', defeito: 'Não liga', diag: '' }, 'Recebido', 0, [], 0, -1);
    const vi = (p, q) => ({ produtoId: p.id, descricao: p.nome, qtd: q, preco: p.preco, custo: p.custo });
    [[cli[1], [vi(prod[2], 1), vi(prod[3], 1)], 0, 'Pix', 1], [null, [vi(prod[4], 1)], 5, 'Dinheiro', 0]].forEach(([c, itens, desc, pg, dias]) => {
      const sub = SC.r2(itens.reduce((a, i) => a + i.qtd * i.preco, 0));
      itens.forEach(i => { const p = SC.byId('produtos', i.produtoId); p.estoque -= i.qtd; });
      d.vendas.unshift({ id: SC.uid(), numero: SC.nextNum('venda'), data: SC.addDays(t, -dias) + 'T15:30:00', clienteId: c ? c.id : null, clienteNome: c ? c.nome : 'Consumidor final', itens, subtotal: sub, descontoTipo: 'valor', descontoValor: desc, desconto: desc, total: SC.r2(sub - desc), lucro: SC.r2(sub - desc - itens.reduce((a, i) => a + i.qtd * i.custo, 0)), formaPagamento: pg, parcelas: 1, obs: '', status: 'Concluída', usuario: 'Demonstração', baixa: itens.map(i => ({ produtoId: i.produtoId, qtd: i.qtd })) });
    });
    d.orcamentos.unshift({ id: SC.uid(), numero: SC.nextNum('orcamento'), data: t + 'T09:00:00', clienteId: cli[2].id, cliSnap: SC.snap(cli[2]), aparelho: { tipo: 'Celular', marca: 'Xiaomi', modelo: 'Redmi Note 10', defeito: 'Conector de carga com mau contato' }, diagnostico: 'Troca do conector de carga', pecas: [{ produtoId: null, descricao: 'Conector de carga', qtd: 1, valor: 35 }], maoDeObra: 70, valorPecas: 35, total: 105, validade: SC.addDays(t, 7), observacoes: '', status: 'Pendente', osId: null });
    SC.log('sistema', 'Dados de demonstração carregados');
  };
})();
