/* server/models/Idempotency.js – Gestão de Idempotência e Eventos de Webhook */
const crypto = require('node:crypto');
const { getDatabase } = require('../db/connection');

class Idempotency {
  /* Gera hash SHA-256 consistente do payload para validar se a requisição repetida possui o mesmo corpo */
  static hashPayload(payload) {
    const jsonStr = typeof payload === 'string' ? payload : JSON.stringify(payload || {});
    return crypto.createHash('sha256').update(jsonStr).digest('hex');
  }

  /* Busca uma chave de idempotência existente */
  static get(key, endpoint) {
    if (!key) return null;
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM idempotency_keys WHERE key = ? AND endpoint = ?').get(key, endpoint);
    if (row) row.response_body = require('../security/secrets').open(row.response_body);
    return row;
  }

  /* Salva a resposta gerada para a chave de idempotência dentro da transação */
  static save(dbInstance, key, endpoint, requestHash, responseStatus, responseBody) {
    if (!key) return;
    const db = dbInstance || getDatabase();
    const bodyStr = typeof responseBody === 'string' ? responseBody : JSON.stringify(responseBody);
    const stmt = db.prepare(`
      INSERT INTO idempotency_keys (key, endpoint, request_hash, response_status, response_body, created_at)
      VALUES (?, ?, ?, ?, ?, ?);
    `);
    stmt.run(key, endpoint, requestHash, Number(responseStatus), require('../security/secrets').seal(bodyStr), new Date().toISOString());
  }

  /* Processamento de Webhooks: grava o ID do evento primeiro.
     Se já existir, retorna duplicate: true garantindo que o evento não seja reprocessado */
  static registerWebhookEvent(eventId, gateway, eventType, payload) {
    const db = getDatabase();
    try {
      const payloadStr = typeof payload === 'string' ? payload : JSON.stringify(payload || {});
      const stmt = db.prepare(`
        INSERT INTO processed_webhook_events (event_id, gateway, event_type, payload, processed_at)
        VALUES (?, ?, ?, ?, ?);
      `);
      stmt.run(eventId, gateway, eventType, payloadStr, new Date().toISOString());
      return { duplicate: false };
    } catch (err) {
      if (err.message.includes('UNIQUE constraint failed: processed_webhook_events.event_id')) {
        return { duplicate: true };
      }
      throw err;
    }
  }

  /* Validação de assinatura criptográfica de Webhooks usando o corpo bruto (Raw Body) */
  static verifyWebhookSignature(rawBody, signature, secret) {
    if (!secret) return false;
    if (!signature) return false;
    const expected = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
    try {
      return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
    } catch {
      return false;
    }
  }
}

module.exports = Idempotency;

