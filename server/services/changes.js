const crypto = require('node:crypto');
const models = require('../models');
const { getDatabase } = require('../db/connection');
const auth = require('../security/auth');
const { lines, number, round } = require('../models/validation');
const tables = { clientes: 'clientes', produtos: 'produtos', os: 'os', orcamentos: 'orcamentos', vendas: 'vendas', users: 'users' };
const perms = { ...tables, users: 'usuarios' };
function stable(value) {
  if (Array.isArray(value)) return '[' + value.map(stable).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + stable(value[k])).join(',') + '}';
  return JSON.stringify(value);
}
function snapshot(user) {
  const snap = models.getFullDatabase(), data = snap.db;
  data.users = data.users.filter(u => auth.can(user, 'usuarios') || u.id === user.id).map(auth.publicUser);
  if (data.config.logo && !/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(data.config.logo)) data.config.logo = '';
  if (!auth.can(user, 'os') && !auth.can(user, 'notas')) data.os = [];
  if (!auth.can(user, 'vendas')) data.vendas = [];
  if (!auth.can(user, 'orcamentos')) data.orcamentos = [];
  if (!['clientes', 'os', 'notas', 'orcamentos', 'vendas'].some(p => auth.can(user, p))) data.clientes = [];
  if (!['produtos', 'os', 'notas', 'orcamentos', 'vendas'].some(p => auth.can(user, p))) data.produtos = [];
  if (user.perfil !== 'admin') data.log = [];
  return snap;
}
function audit(user, type, text) {
  const id = crypto.randomUUID(), data = { id, data: new Date().toISOString(), usuario: user.nome, tipo: type, texto: text };
  getDatabase().prepare('INSERT INTO logs(id,data) VALUES(?,?)').run(id, JSON.stringify(data));
  getDatabase().exec('DELETE FROM logs WHERE rowid NOT IN (SELECT rowid FROM logs ORDER BY rowid DESC LIMIT 500)');
}
function validateConfig(config) {
  for (const key of Object.keys(config)) if (['__proto__','prototype','constructor'].includes(key)) auth.fail('Configuração inválida.');
  if (config.logo && !/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(config.logo)) auth.fail('Use uma imagem PNG, JPEG ou WebP para o logotipo.');
  if (String(config.logo || '').length > 2 * 1024 * 1024) auth.fail('Logotipo muito grande.');
}
function userSave(value, before) {
  require('../models/validation').id(value.id);
  const user = { ...value, login: String(value.login || '').trim().toLowerCase() };
  if (!/^[a-z0-9._-]{1,64}$/.test(user.login) || !user.nome || !['admin','atendente','tecnico','vendedor'].includes(user.perfil)) auth.fail('Usuário inválido.');
  user.perms = (user.perms || []).filter(p => auth.permissions.includes(p));
  user.senha = value.password ? auth.hash(value.password) : before?.senha;
  if (!user.senha) auth.fail('Informe a senha do novo usuário.');
  user.mustChangePassword = false;
  delete user.password;
  auth.save(user);
}
function assertRelations() {
  const db = getDatabase();
  for (const table of ['os', 'vendas', 'orcamentos']) {
    for (const row of db.prepare(`SELECT data FROM ${table}`).all()) {
      const item = JSON.parse(row.data);
      if (item.clienteId && !models.Cliente.getById(item.clienteId)) auth.fail('O registro depende de um cliente que não existe.');
      for (const line of item.pecas || item.itens || []) if (line.produtoId && !models.Produto.getById(line.produtoId)) auth.fail('O registro depende de um produto que não existe.');
      if (item.osId && !models.OS.getById(item.osId)) auth.fail('A OS vinculada não existe.');
      if (item.orcamentoId && !models.Orcamento.getById(item.orcamentoId)) auth.fail('O orçamento vinculado não existe.');
    }
  }
}
function apply(user, changes) {
  if (!Array.isArray(changes) || changes.length > 2000) auth.fail('Alterações inválidas.');
  const db = getDatabase(), seen = new Set();
  const visible = snapshot(user).db;
  for (const change of changes) {
    const { entity, id, before, after } = change;
    if (!Object.hasOwn(tables, entity) && entity !== 'config') auth.fail('Entidade inválida.');
    if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(id)) auth.fail('ID inválido.');
    const key = entity + ':' + id;
    if (seen.has(key)) auth.fail('Alteração duplicada.'); seen.add(key);
    auth.requirePermission(user, entity === 'config' ? 'config' : perms[entity]);
    if (!after && entity !== 'config') auth.requirePermission(user, 'excluir');
    const current = entity === 'config' ? visible.config[id] ?? null : visible[entity].find(r => r.id === id) || null;
    if (stable(current) !== stable(before)) auth.fail('Este registro foi alterado por outra pessoa. Recarregue e tente novamente.', 409);
    if (after && entity !== 'config' && after.id !== id) auth.fail('ID inconsistente.');
  }
  // Children and financial effects are handled by the same transaction as their clients/products.
  const order = ['config', 'users', 'clientes', 'produtos', 'orcamentos', 'os', 'vendas'];
  for (const change of [...changes].sort((a,b) => order.indexOf(a.entity) - order.indexOf(b.entity))) {
    const { entity, id, after } = change;
    const value = after && structuredClone(after);
    if (entity === 'config') {
      if (['__proto__','prototype','constructor'].includes(id)) auth.fail('Configuração inválida.');
      validateConfig({ [id]: value });
      if (value === null) db.prepare('DELETE FROM config WHERE key=?').run(id);
      else models.StoreConfig.saveConfig({ [id]: value });
    } else if (!value) {
      if (entity === 'os') {
        const os = models.OS.getById(id);
        for (const b of os.baixaEstoque || []) models.Produto.estornarEstoqueAtomico(db, b.produtoId, b.qtd);
      }
      if (entity === 'vendas' && models.Venda.getById(id).status !== 'Cancelada') auth.fail('Cancele a venda antes de excluí-la.');
      db.prepare(`DELETE FROM ${tables[entity]} WHERE id=?`).run(id);
    } else if (entity === 'users') userSave(value, models.Usuario.getById(id));
    else if (entity === 'clientes') models.Cliente.salvarCliente(value);
    else if (entity === 'produtos') models.Produto.upsert(value);
    else if (entity === 'os') {
      value._actor = user.nome;
      models.OS.salvarOSTransacional(value);
      if (value.orcamentoId) {
        const q = models.Orcamento.getById(value.orcamentoId);
        if (!q || (q.osId && q.osId !== id)) auth.fail('Orçamento já convertido ou inexistente.', 409);
        q.osId = id; q.status = 'Aprovado';
        db.prepare('UPDATE orcamentos SET status=?,data=? WHERE id=?').run(q.status, JSON.stringify(q), q.id);
      }
    } else if (entity === 'vendas') {
      const old = models.Venda.getById(id);
      if (!old) { value.usuario = user.nome; models.Venda.criarVendaTransacional(value); }
      else if (value.status === 'Cancelada') models.Venda.cancelarVendaTransacional(id);
      else auth.fail('Vendas registradas não podem ser editadas.');
    } else if (entity === 'orcamentos') {
      const old = models.Orcamento.getById(id);
      value.numero = old?.numero || models.StoreConfig.nextSequence('orcamento');
      value.data ||= new Date().toISOString();
      require('../models/validation').dates(value, ['data','validade']);
      value.valorPecas = lines(value.pecas || [], 'valor');
      value.maoDeObra = number(value.maoDeObra ?? 0, 'Mão de obra');
      value.total = round(value.valorPecas + value.maoDeObra);
      if (!['Pendente','Aprovado','Recusado'].includes(value.status)) auth.fail('Status do orçamento inválido.');
      db.prepare('INSERT INTO orcamentos(id,numero,status,data) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET status=excluded.status,data=excluded.data').run(id,value.numero,value.status,JSON.stringify(value));
    }
    audit(user, entity, `${after ? 'Gravação' : 'Exclusão'}: ${id}`);
  }
  if (!models.Usuario.getAll().some(u => u.ativo && u.perfil === 'admin')) auth.fail('É necessário manter um administrador ativo.');
  assertRelations();
}
module.exports = { apply, snapshot, audit, stable, validateConfig, assertRelations };
