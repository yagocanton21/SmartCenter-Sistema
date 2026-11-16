const { getDatabase } = require('../db/connection');
const auth = require('../security/auth');
const entities = new Set(['os', 'clientes', 'orcamentos', 'vendas', 'produtos']);
const money = value => Number(value || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
const date = value => /^\d{4}-\d{2}-\d{2}/.test(value || '') ? value.slice(0, 10).split('-').reverse().join('/') : 'Não informado';
function integer(params, name, fallback, max) {
  const value = params.get(name);
  if (value === null) return fallback;
  if (!/^\d+$/.test(value) || !Number.isSafeInteger(Number(value)) || Number(value) < 1 || Number(value) > max) auth.fail(`${name} inválido.`);
  return Number(value);
}
function list(user, entity, params) {
  if (!entities.has(entity)) auth.fail('Coleção não encontrada.', 404);
  auth.requirePermission(user, entity);
  const page = integer(params, 'page', 1, 1000000), pageSize = integer(params, 'pageSize', 30, 100);
  const q = (params.get('q') || '').trim(), status = (params.get('status') || '').trim();
  if (q.length > 200 || status.length > 64) auth.fail('Filtro muito longo.');
  const numbered = ['os', 'orcamentos', 'vendas'].includes(entity);
  const join = numbered ? " LEFT JOIN clientes c ON c.id=json_extract(r.data,'$.clienteId')" : '';
  const client = numbered ? "coalesce(json_extract(c.data,'$.nome'),json_extract(r.data,'$.cliSnap.nome'),'Cliente não informado')" : "''";
  const search = numbered
    ? `cast(r.numero as text)||' '||${client}||' '||coalesce(json_extract(r.data,'$.aparelho.marca'),'')||' '||coalesce(json_extract(r.data,'$.aparelho.modelo'),'')`
    : entity === 'clientes'
      ? "r.nome||' '||coalesce(r.telefone,'')||' '||coalesce(r.doc,'')||' '||coalesce(json_extract(r.data,'$.email'),'')"
      : "r.nome||' '||coalesce(r.codigo,'')";
  const clauses = [], args = [];
  // instr treats %, _ and quotes literally; values never become SQL syntax.
  if (q) { clauses.push(`instr(lower(${search}),lower(?))>0`); args.push(q); }
  if (status) {
    if (!numbered) auth.fail('Filtro de status indisponível para esta coleção.');
    clauses.push('r.status=?'); args.push(status);
  }
  const from = `FROM ${entity} r${join}${clauses.length ? ' WHERE ' + clauses.join(' AND ') : ''}`;
  const order = numbered ? 'r.numero DESC,r.id ASC' : 'r.nome COLLATE NOCASE ASC,r.id ASC';
  const db = getDatabase();
  const total = db.prepare(`SELECT count(*) AS total ${from}`).get(...args).total;
  const records = db.prepare(`SELECT r.id,r.data,${client} AS clientName ${from} ORDER BY ${order} LIMIT ? OFFSET ?`).all(...args, pageSize, (page - 1) * pageSize);
  const items = records.map(row => {
    const r = JSON.parse(row.data), fields = [];
    const add = (label, value) => fields.push({ label, value: String(value ?? '') });
    let title, subtitle, badge = '';
    if (numbered) {
      title = `${{ os: 'OS', orcamentos: 'Orçamento', vendas: 'Venda' }[entity]} #${r.numero}`;
      subtitle = row.clientName; badge = r.status || '';
      add('Cliente', subtitle); add('Status', badge);
      add('Data', date(r.dataEntrada || r.data));
      if (entity !== 'vendas') {
        const device = [r.aparelho?.marca, r.aparelho?.modelo].filter(Boolean).join(' ');
        if (device) subtitle += ' · ' + device;
        add('Aparelho', device); add('Defeito relatado', r.aparelho?.defeito);
      }
      if (entity === 'os') { add('Prazo', date(r.prazo)); add('Diagnóstico', r.diagnostico); add('Serviço realizado', r.servico); add('Observações', r.observacoes); }
      add('Total', money(r.total));
    } else if (entity === 'clientes') {
      title = r.nome; subtitle = r.telefone || '';
      add('Nome', r.nome); add('Telefone', r.telefone); add('E-mail', r.email);
    } else {
      title = r.nome; subtitle = r.codigo || ''; badge = money(r.preco);
      add('Nome', r.nome); add('Código', r.codigo); add('Preço', badge);
      add('Estoque', r.controla ? r.estoque ?? 0 : 'Não controlado'); add('Estoque mínimo', r.estoqueMin ?? 0);
    }
    // Curated DTO: no device unlock secrets, user hashes or entire DB snapshot.
    return { id: row.id, title, subtitle, badge, fields };
  });
  return { items, page, pageSize, total, hasMore: page * pageSize < total };
}
module.exports = { list };
