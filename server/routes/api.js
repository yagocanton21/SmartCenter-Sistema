const crypto = require('node:crypto');
const { getDatabase } = require('../db/connection');
const models = require('../models');
const auth = require('../security/auth');
const changesService = require('../services/changes');
function sendJSON(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(data));
}
async function readBody(req) {
  const chunks = []; let bytes = 0;
  for await (const chunk of req) {
    bytes += chunk.length;
    if (bytes > 8 * 1024 * 1024) auth.fail('Requisição excede 8 MB.', 413);
    chunks.push(chunk);
  }
  const rawBody = Buffer.concat(chunks).toString('utf8');
  let body;
  try { body = JSON.parse(rawBody || '{}'); } catch { auth.fail('JSON inválido.'); }
  if (!body || typeof body !== 'object' || Array.isArray(body)) auth.fail('Objeto JSON obrigatório.');
  return { body, rawBody };
}
function transaction(fn) {
  const db = getDatabase(); db.exec('BEGIN IMMEDIATE;');
  try { const result = fn(); db.exec('COMMIT;'); return result; }
  catch (error) { db.exec('ROLLBACK;'); throw error; }
}
function idempotent(req, user, endpoint, raw, fn) {
  const supplied = req.headers['idempotency-key'];
  if (typeof supplied !== 'string' || !supplied || supplied.length > 150) auth.fail('Idempotency-Key obrigatório (até 150 caracteres).');
  const key = crypto.createHash('sha256').update(user.id + ':' + endpoint + ':' + supplied).digest('hex');
  const hash = models.Idempotency.hashPayload(raw);
  return transaction(() => {
    const cached = models.Idempotency.get(key, endpoint);
    if (cached) {
      if (cached.request_hash !== hash) auth.fail('Chave já utilizada com outros parâmetros.', 422);
      return { status: cached.response_status, data: JSON.parse(cached.response_body), replay: true };
    }
    const response = fn();
    models.Idempotency.save(getDatabase(), key, endpoint, hash, response.status, JSON.stringify(response.data));
    return response;
  });
}
function webhook(body, rawBody, signature) {
  if (!process.env.WEBHOOK_SECRET) auth.fail('Webhook não configurado.', 503);
  if (!models.Idempotency.verifyWebhookSignature(rawBody, signature, process.env.WEBHOOK_SECRET)) auth.fail('Assinatura inválida.', 401);
  if (typeof body.id !== 'string' || !body.id || body.id.length > 150 || typeof body.gateway !== 'string' || !body.gateway || body.gateway.length > 64) auth.fail('Evento e gateway obrigatórios.');
  return transaction(() => {
    const db = getDatabase(), eventId = crypto.createHash('sha256').update(body.gateway + ':' + body.id).digest('hex');
    const prior = db.prepare('SELECT payload FROM processed_webhook_events WHERE event_id=?').get(eventId);
    if (prior) {
      if (prior.payload !== models.Idempotency.hashPayload(rawBody)) auth.fail('Evento repetido com conteúdo diferente.', 409);
      return { ok: true, duplicate: true };
    }
    // Only confirmations tied to a known, independently registered charge are accepted.
    if (body.status !== 'pago') auth.fail('Tipo de evento não suportado.');
    const charge = db.prepare('SELECT * FROM payment_charges WHERE id=? AND gateway=?').get(body.chargeId, body.gateway);
    if (!charge || charge.os_id !== body.osId || body.currency !== 'BRL' || !Number.isSafeInteger(body.amountCents) || body.amountCents !== charge.amount_cents) auth.fail('Pagamento não corresponde à cobrança registrada.');
    const os = models.OS.getById(charge.os_id);
    if (!os || Math.round(os.total * 100) !== charge.amount_cents) auth.fail('OS ou valor da cobrança alterado.', 409);
    if (charge.status !== 'pago') {
      // A payment does not imply that a repair has been completed or delivered.
      os.pagamentoStatus = 'pago'; os.pagamentoId = charge.id;
      os.formaPagamento = charge.method;
      db.prepare('UPDATE os SET data=? WHERE id=?').run(require('../security/secrets').encode(os), os.id);
      db.prepare("UPDATE payment_charges SET status='pago' WHERE id=?").run(charge.id);
      changesService.audit({ nome: 'Webhook ' + body.gateway }, 'pagamento', 'Pagamento confirmado: ' + charge.id);
    }
    models.Idempotency.registerWebhookEvent(eventId, body.gateway, 'payment.received', models.Idempotency.hashPayload(rawBody));
    return { ok: true };
  });
}
async function handleApiRequest(req, res, pathname) {
  try {
    if (req.method === 'GET' && pathname === '/api/status') return sendJSON(res, 200, { ok: true, driver: 'sqlite', version: '2.0.0' });
    if (req.method === 'OPTIONS') return sendJSON(res, 405, { ok: false });
    const mutating = !['GET','HEAD'].includes(req.method);
    if (mutating && req.headers.origin && req.headers.origin !== (process.env.PUBLIC_ORIGIN || `http://${req.headers.host}`)) auth.fail('Origem não permitida.', 403);
    if (req.method === 'POST' && pathname === '/api/webhooks/pagamentos') {
      const { body, rawBody } = await readBody(req);
      return sendJSON(res, 200, webhook(body, rawBody, req.headers['x-signature']));
    }
    if (req.method === 'POST' && pathname === '/api/auth/login') return sendJSON(res, 200, auth.login(req, res, (await readBody(req)).body));
    const session = auth.current(req);
    if (!session) auth.fail('Entre novamente para continuar.', 401);
    if (mutating && req.headers['x-csrf-token'] !== session.csrf) auth.fail('Sessão de segurança inválida.', 403);
    if (pathname === '/api/auth/session' && req.method === 'GET') return sendJSON(res, 200, { user: auth.publicUser(session.user), csrf: session.csrf });
    if (pathname === '/api/auth/logout' && req.method === 'POST') { auth.logout(req, res); return sendJSON(res, 200, { ok: true }); }
    if (pathname === '/api/auth/password' && req.method === 'POST') {
      auth.changePassword(session, (await readBody(req)).body);
      changesService.audit(session.user, 'usuario', 'Senha alterada');
      return sendJSON(res, 200, { ok: true, user: auth.publicUser(session.user) });
    }
    const user = session.user, db = getDatabase();
    if (pathname === '/api/db' && req.method === 'GET') return sendJSON(res, 200, changesService.snapshot(user));
    if (pathname === '/api/changes' && req.method === 'POST') {
      const { body, rawBody } = await readBody(req);
      const result = idempotent(req, user, pathname, rawBody, () => {
        changesService.apply(user, body.changes);
        return { status: 200, data: { ok: true } };
      });
      if (!result.replay) for (const change of body.changes) if (change.entity === 'users' && change.id !== user.id && (change.after?.password || !change.after)) auth.invalidate(change.id);
      if (result.replay) res.setHeader('X-Idempotent-Replay', 'true');
      return sendJSON(res, 200, { ...changesService.snapshot(user), ok: true });
    }
    if (pathname === '/api/backup' && req.method === 'GET') {
      auth.requirePermission(user, 'backup');
      if (user.perfil !== 'admin') auth.fail('Backup completo reservado ao administrador.', 403);
      const backup = models.getFullDatabase().db;
      // Backups retain password derivations, but never device unlock secrets.
      for (const os of backup.os) if (os.aparelho) { os.aparelho.senha = ''; os.aparelho.senhaPadrao = ''; }
      changesService.audit(user, 'backup', 'Backup completo exportado');
      return sendJSON(res, 200, backup);
    }
    if (pathname === '/api/restore' && req.method === 'POST') {
      if (user.perfil !== 'admin') auth.fail('Restauração reservada ao administrador.', 403);
      const { body } = await readBody(req);
      if (!body.config || !body.seq || !['users','clientes','produtos','os','orcamentos','vendas'].every(k => Array.isArray(body[k]))) auth.fail('Backup incompleto.');
      if (!body.users.some(u => u.perfil === 'admin' && u.ativo && typeof u.senha === 'string')) auth.fail('Backup sem administrador ativo.');
      changesService.validateConfig(body.config);
      for (const p of body.produtos) { for (const key of ['estoque','preco','custo','estoqueMin']) require('../models/validation').number(p[key] ?? 0, key); }
      for (const os of body.os) if (os.aparelho) { os.aparelho.senha = ''; os.aparelho.senhaPadrao = ''; }
      transaction(() => {
        db.exec('DELETE FROM config; DELETE FROM seq; DELETE FROM payment_charges; DELETE FROM idempotency_keys; DELETE FROM processed_webhook_events;');
        models.StoreConfig.saveConfig(body.config); models.StoreConfig.saveSequences(body.seq);
        models.Usuario.saveAll(body.users); models.Cliente.saveAll(body.clientes); models.Produto.saveAll(body.produtos);
        models.OS.saveAll(body.os); models.Orcamento.saveAll(body.orcamentos); models.Venda.saveAll(body.vendas);
        for (const [name, table] of [['os','os'], ['venda','vendas'], ['orcamento','orcamentos']]) {
          const max = db.prepare(`SELECT coalesce(max(numero),0) n FROM ${table}`).get().n;
          db.prepare('INSERT INTO seq(name,val) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET val=max(val,excluded.val)').run(name,max);
        }
        changesService.assertRelations(); changesService.audit(user, 'backup', 'Backup restaurado');
      });
      auth.invalidate(); auth.logout(req, res); return sendJSON(res, 200, { ok: true });
    }
    if (pathname === '/api/payment-charges' && req.method === 'POST') {
      auth.requirePermission(user, 'config');
      const { body } = await readBody(req), os = models.OS.getById(body.osId);
      if (!os || typeof body.id !== 'string' || !body.id || typeof body.gateway !== 'string' || !body.gateway || os.total <= 0) auth.fail('Cobrança inválida.');
      db.prepare("INSERT INTO payment_charges(id,gateway,os_id,amount_cents,method,status) VALUES(?,?,?,?,?,'pendente')").run(body.id,body.gateway,os.id,Math.round(os.total * 100),body.method || 'Pix');
      return sendJSON(res, 201, { ok: true });
    }
    const entity = pathname.split('/')[2];
    if (['clientes','produtos','os','orcamentos','vendas'].includes(entity) && pathname === '/api/' + entity && req.method === 'GET') {
      auth.requirePermission(user, entity);
      const url = new URL(req.url, 'http://localhost'), offset = Math.max(0, parseInt(url.searchParams.get('offset')) || 0), limit = Math.min(200, Math.max(1, parseInt(url.searchParams.get('limit')) || 50));
      const order = ['os','vendas','orcamentos'].includes(entity) ? 'numero DESC' : 'rowid DESC';
      const items = db.prepare(`SELECT data FROM ${entity} ORDER BY ${order} LIMIT ? OFFSET ?`).all(limit,offset).map(r => entity === 'os' ? require('../security/secrets').decode(r.data) : JSON.parse(r.data));
      const total = db.prepare(`SELECT count(*) n FROM ${entity}`).get().n;
      return sendJSON(res, 200, { items, total });
    }
    if (['/api/vendas','/api/os'].includes(pathname) && req.method === 'POST') {
      auth.requirePermission(user, entity);
      const { body, rawBody } = await readBody(req);
      const result = idempotent(req, user, pathname, rawBody, () => {
        // Explicit optimistic comparison is required for updates.
        if (entity === 'os' && models.OS.getById(body.id)) {
          if (!body.before || changesService.stable(body.before) !== changesService.stable(models.OS.getById(body.id))) auth.fail('OS alterada; recarregue.',409);
        }
        if (body.cliente) { auth.requirePermission(user,'clientes'); models.Cliente.salvarCliente(body.cliente); body.clienteId = body.cliente.id; delete body.cliente; }
        delete body.before;
        const value = entity === 'vendas' ? models.Venda.criarVendaTransacional(body) : models.OS.salvarOSTransacional({ ...body, _actor: user.nome });
        changesService.assertRelations(); changesService.audit(user, entity, 'Gravação: ' + body.id);
        return { status: entity === 'vendas' ? 201 : 200, data: { ok: true, [entity === 'vendas' ? 'venda' : 'os']: value } };
      });
      if (result.replay) res.setHeader('X-Idempotent-Replay','true');
      return sendJSON(res, result.status, result.data);
    }
    if (/^\/api\/vendas\/[^/]+\/cancelar$/.test(pathname) && req.method === 'POST') {
      auth.requirePermission(user,'vendas');
      const venda = transaction(() => {
        const value = models.Venda.cancelarVendaTransacional(pathname.split('/')[3]);
        changesService.audit(user,'vendas','Cancelamento: ' + value.id);
        return value;
      });
      return sendJSON(res,200,{ok:true,venda});
    }
    return sendJSON(res, 404, { ok: false, error: 'Endpoint não encontrado.' });
  } catch (error) {
    const conflict = /Estoque insuficiente|UNIQUE constraint|Já existe um cliente/.test(error.message);
    const status = error.status || (conflict ? 409 : 400);
    return sendJSON(res, status, { ok: false, error: error.message });
  }
}
module.exports = { handleApiRequest };
