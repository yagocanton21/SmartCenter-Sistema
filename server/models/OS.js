/* server/models/OS.js – Gestão de ordens de serviço e operações atômicas */
const { getDatabase } = require('../db/connection');
const Produto = require('./Produto');
const StoreConfig = require('./StoreConfig');

const FIM = ['Concluído', 'Entregue'];

class OS {
  static getAll() {
    const db = getDatabase();
    return db.prepare('SELECT data FROM os ORDER BY numero DESC').all().map(r => JSON.parse(r.data));
  }

  static getById(id) {
    const db = getDatabase();
    const row = db.prepare('SELECT data FROM os WHERE id = ?').get(id);
    return row ? JSON.parse(row.data) : null;
  }

  /* Criação ou atualização atômica de OS com controle de estoque no banco e idempotência */
  static salvarOSTransacional(osData, idempotencyKey, requestHash) {
    const db = getDatabase();
    db.exec('BEGIN IMMEDIATE;');
    try {
      const isNew = !osData.numero;
      if (isNew) {
        osData.numero = StoreConfig.nextSequence('os');
      }

      const anterior = !isNew && OS.getById(osData.id);
      const oldStatus = anterior ? anterior.status : null;
      const newStatus = osData.status || 'Recebido';

      // Se passou para status concluído/entregue e o estoque ainda não estava baixado
      if (FIM.includes(newStatus) && (!anterior || !anterior.estoqueBaixado)) {
        const pecas = osData.pecas || [];
        const baixas = [];
        for (const p of pecas) {
          if (p.produtoId) {
            Produto.baixarEstoqueAtomico(db, p.produtoId, p.qtd);
            baixas.push({ produtoId: p.produtoId, qtd: p.qtd });
          }
        }
        osData.baixaEstoque = baixas;
        osData.estoqueBaixado = true;
        if (!osData.dataConclusao) osData.dataConclusao = new Date().toISOString();
      } 
      // Se saiu de concluído/entregue para um status anterior, estorna o estoque
      else if (!FIM.includes(newStatus) && anterior && anterior.estoqueBaixado) {
        if (Array.isArray(anterior.baixaEstoque)) {
          for (const b of anterior.baixaEstoque) {
            Produto.estornarEstoqueAtomico(db, b.produtoId, b.qtd);
          }
        }
        osData.baixaEstoque = [];
        osData.estoqueBaixado = false;
        osData.dataConclusao = null;
      }

      if (newStatus === 'Entregue' && !osData.dataEntrega) {
        osData.dataEntrega = new Date().toISOString();
      }

      const stmt = db.prepare(`
        INSERT INTO os (id, numero, status, data) 
        VALUES (?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          numero = excluded.numero,
          status = excluded.status,
          data = excluded.data;
      `);
      stmt.run(osData.id, Number(osData.numero), newStatus, JSON.stringify(osData));

      if (idempotencyKey) {
        const respBody = JSON.stringify({ ok: true, os: osData });
        db.prepare(`
          INSERT INTO idempotency_keys (key, endpoint, request_hash, response_status, response_body, created_at)
          VALUES (?, '/api/os', ?, 200, ?, ?);
        `).run(idempotencyKey, requestHash || '', respBody, new Date().toISOString());
      }

      db.exec('COMMIT;');
      return osData;
    } catch (err) {
      db.exec('ROLLBACK;');
      throw err;
    }
  }

  static saveAll(osList) {
    if (!Array.isArray(osList)) return;
    const db = getDatabase();
    db.exec('DELETE FROM os;');
    const stmt = db.prepare('INSERT INTO os (id, numero, status, data) VALUES (?, ?, ?, ?);');
    for (const o of osList) {
      stmt.run(o.id, Number(o.numero) || 0, o.status || '', JSON.stringify(o));
    }
  }
}

module.exports = OS;
