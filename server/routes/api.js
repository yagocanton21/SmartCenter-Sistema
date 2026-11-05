/* server/routes/api.js – Rotas de API REST com Idempotência (Idempotency-Key) e Webhooks */
const {
  getFullDatabase,
  saveFullDatabase,
  Cliente,
  Produto,
  OS,
  Orcamento,
  Venda,
  Usuario,
  StoreConfig,
  Idempotency
} = require('../models');

function sendJSON(res, status, data, headers = {}) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Idempotency-Key, X-Signature, Webhook-Signature',
    ...headers
  });
  res.end(typeof data === 'string' ? data : JSON.stringify(data));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let rawBody = '';
    req.on('data', chunk => {
      rawBody += chunk;
      if (rawBody.length > 50 * 1024 * 1024) req.destroy();
    });
    req.on('end', () => {
      try {
        const parsed = rawBody ? JSON.parse(rawBody) : {};
        resolve({ body: parsed, rawBody });
      } catch (err) {
        reject(new Error('JSON inválido no corpo da requisição.'));
      }
    });
    req.on('error', reject);
  });
}

async function handleApiRequest(req, res, pathname) {
  // CORS Pre-flight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Idempotency-Key, X-Signature, Webhook-Signature'
    });
    return res.end();
  }

  // GET /api/status
  if (pathname === '/api/status' && req.method === 'GET') {
    const snap = getFullDatabase();
    return sendJSON(res, 200, {
      ok: true,
      driver: 'sqlite',
      version: '1.3-idempotent',
      hasData: snap.hasData,
      counts: {
        clientes: snap.db.clientes.length,
        os: snap.db.os.length,
        orcamentos: snap.db.orcamentos.length,
        vendas: snap.db.vendas.length,
        produtos: snap.db.produtos.length,
        usuarios: snap.db.users.length
      }
    });
  }

  // GET /api/db
  if (pathname === '/api/db' && req.method === 'GET') {
    try {
      const snap = getFullDatabase();
      return sendJSON(res, 200, snap);
    } catch (e) {
      return sendJSON(res, 500, { ok: false, error: e.message });
    }
  }

  // POST /api/save (Sincronização / Backup)
  if (pathname === '/api/save' && req.method === 'POST') {
    try {
      const { body } = await readBody(req);
      saveFullDatabase(body);
      return sendJSON(res, 200, { ok: true, message: 'Gravado com sucesso no SQLite' });
    } catch (e) {
      console.error('Erro ao salvar snapshot no SQLite:', e);
      return sendJSON(res, 500, { ok: false, error: e.message });
    }
  }

  /* ---------- Endpoints de Vendas com Idempotência ---------- */

  // POST /api/vendas – Criação de venda atômica e idempotente
  if (pathname === '/api/vendas' && req.method === 'POST') {
    try {
      const { body, rawBody } = await readBody(req);
      const idempotencyKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'];
      const requestHash = Idempotency.hashPayload(rawBody);

      // Verificação de Idempotência
      if (idempotencyKey) {
        const cached = Idempotency.get(idempotencyKey);
        if (cached) {
          // Se a chave já foi usada mas com outro corpo de requisição, retorna 422
          if (cached.request_hash !== requestHash) {
            return sendJSON(res, 422, {
              ok: false,
              error: 'Chave de idempotência já utilizada para outra operação com parâmetros diferentes.'
            });
          }
          // Retorna a mesma resposta anterior salva no banco
          return sendJSON(res, cached.response_status, cached.response_body, {
            'X-Idempotent-Replay': 'true'
          });
        }
      }

      const venda = Venda.criarVendaTransacional(body, idempotencyKey, requestHash);
      return sendJSON(res, 201, { ok: true, venda });
    } catch (e) {
      const isConflict = e.message.includes('Estoque insuficiente');
      return sendJSON(res, isConflict ? 409 : 400, { ok: false, error: e.message });
    }
  }

  // POST /api/vendas/:id/cancelar
  if (pathname.startsWith('/api/vendas/') && pathname.endsWith('/cancelar') && req.method === 'POST') {
    try {
      const parts = pathname.split('/');
      const vendaId = parts[3];
      const venda = Venda.cancelarVendaTransacional(vendaId);
      return sendJSON(res, 200, { ok: true, venda });
    } catch (e) {
      return sendJSON(res, 400, { ok: false, error: e.message });
    }
  }

  /* ---------- Endpoints de OS com Idempotência ---------- */

  // POST /api/os – Criação ou atualização atômica e idempotente de OS
  if (pathname === '/api/os' && req.method === 'POST') {
    try {
      const { body, rawBody } = await readBody(req);
      const idempotencyKey = req.headers['idempotency-key'] || req.headers['x-idempotency-key'];
      const requestHash = Idempotency.hashPayload(rawBody);

      if (idempotencyKey) {
        const cached = Idempotency.get(idempotencyKey);
        if (cached) {
          if (cached.request_hash !== requestHash) {
            return sendJSON(res, 422, {
              ok: false,
              error: 'Chave de idempotência já utilizada para outra operação com parâmetros diferentes.'
            });
          }
          return sendJSON(res, cached.response_status, cached.response_body, {
            'X-Idempotent-Replay': 'true'
          });
        }
      }

      const os = OS.salvarOSTransacional(body, idempotencyKey, requestHash);
      return sendJSON(res, 200, { ok: true, os });
    } catch (e) {
      const isConflict = e.message.includes('Estoque insuficiente');
      return sendJSON(res, isConflict ? 409 : 400, { ok: false, error: e.message });
    }
  }

  /* ---------- Webhook de Pagamentos (Idempotente) ---------- */
  // POST /api/webhooks/pagamentos – Recebe notificações de pagamentos de gateways externos (Pix, Stripe, etc.)
  if (pathname === '/api/webhooks/pagamentos' && req.method === 'POST') {
    try {
      const { body, rawBody } = await readBody(req);
      const signature = req.headers['x-signature'] || req.headers['webhook-signature'];
      const secret = process.env.WEBHOOK_SECRET;

      // 1. Confirma assinatura com o corpo bruto
      if (!Idempotency.verifyWebhookSignature(rawBody, signature, secret)) {
        return sendJSON(res, 401, { ok: false, error: 'Assinatura inválida do webhook' });
      }

      const eventId = body.id || body.event_id || req.headers['x-event-id'];
      if (!eventId) {
        return sendJSON(res, 400, { ok: false, error: 'Identificador do evento (id/event_id) ausente' });
      }

      const gateway = body.gateway || 'gateway_padrao';
      const eventType = body.type || body.event || 'payment.updated';

      // 2. Grava o ID primeiro; se já existir, responde 200 e não faz mais nada (Idempotência Estrita)
      const reg = Idempotency.registerWebhookEvent(eventId, gateway, eventType, rawBody);
      if (reg.duplicate) {
        return sendJSON(res, 200, {
          ok: true,
          duplicate: true,
          message: 'Evento já processado anteriormente (Idempotente).'
        });
      }

      // 3. Processa o efeito colateral do evento
      // Exemplo: se for pagamento aprovado de uma OS
      if (body.osId && body.status === 'pago') {
        const os = OS.getById(body.osId);
        if (os) {
          os.formaPagamento = body.formaPagamento || 'Pix';
          os.status = 'Concluído';
          OS.salvarOSTransacional(os);
        }
      }

      return sendJSON(res, 200, { ok: true, message: 'Evento processado com sucesso' });
    } catch (e) {
      console.error('Erro no processamento do webhook:', e);
      return sendJSON(res, 500, { ok: false, error: e.message });
    }
  }

  /* ---------- Cadastros e Consultas ---------- */

  // POST /api/clientes
  if (pathname === '/api/clientes' && req.method === 'POST') {
    try {
      const { body } = await readBody(req);
      const cliente = Cliente.salvarCliente(body);
      return sendJSON(res, 200, { ok: true, cliente });
    } catch (e) {
      const isConflict = e.message.includes('Já existe um cliente');
      return sendJSON(res, isConflict ? 409 : 400, { ok: false, error: e.message });
    }
  }

  // POST /api/produtos
  if (pathname === '/api/produtos' && req.method === 'POST') {
    try {
      const { body } = await readBody(req);
      Produto.upsert(body);
      return sendJSON(res, 200, { ok: true, produto: body });
    } catch (e) {
      return sendJSON(res, 400, { ok: false, error: e.message });
    }
  }

  // GET /api/next-num/:tipo
  if (pathname.startsWith('/api/next-num/') && req.method === 'GET') {
    const tipo = pathname.split('/')[3];
    if (!['os', 'venda', 'orcamento', 'produto'].includes(tipo)) {
      return sendJSON(res, 400, { ok: false, error: 'Tipo de sequenciador inválido' });
    }
    const num = StoreConfig.nextSequence(tipo);
    return sendJSON(res, 200, { ok: true, tipo, numero: num });
  }

  // Listagens REST
  if (pathname === '/api/clientes' && req.method === 'GET') return sendJSON(res, 200, Cliente.getAll());
  if (pathname === '/api/produtos' && req.method === 'GET') return sendJSON(res, 200, Produto.getAll());
  if (pathname === '/api/os' && req.method === 'GET') return sendJSON(res, 200, OS.getAll());
  if (pathname === '/api/orcamentos' && req.method === 'GET') return sendJSON(res, 200, Orcamento.getAll());
  if (pathname === '/api/vendas' && req.method === 'GET') return sendJSON(res, 200, Venda.getAll());

  return sendJSON(res, 404, { ok: false, error: 'Endpoint não encontrado' });
}

module.exports = {
  handleApiRequest
};
