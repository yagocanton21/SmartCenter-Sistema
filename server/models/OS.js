/* server/models/OS.js – Gestão de ordens de serviço e operações atômicas */
const { getDatabase } = require('../db/connection');
const Produto = require('./Produto');
const StoreConfig = require('./StoreConfig');
const secrets = require('../security/secrets');

const FIM = ['Concluído', 'Entregue'];

class OS {
  static getAll() {
    const db = getDatabase();
    return db.prepare('SELECT data FROM os ORDER BY numero DESC').all().map(r => secrets.decode(r.data));
  }

  static getById(id) {
    const db = getDatabase();
    const row = db.prepare('SELECT data FROM os WHERE id = ?').get(id);
    return row ? secrets.decode(row.data) : null;
  }

  /* Criação ou atualização atômica de OS com controle de estoque no banco e idempotência */
  static salvarOSTransacional(osData, idempotencyKey, requestHash) {
    const db = getDatabase();
    const nested = db.isTransaction;
    if (!nested) db.exec('BEGIN IMMEDIATE;');
    try {
      if (!osData.id) throw new Error('ID da OS obrigatório.');
      require('./validation').id(osData.id);
      osData.dataEntrada ||= new Date().toISOString();
      require('./validation').dates(osData, ['dataEntrada','prazo','dataEntrega','dataConclusao']);
      const { lines, number, round } = require('./validation');
      osData.valorPecas = lines(osData.pecas || [], 'valor');
      osData.maoDeObra = number(osData.maoDeObra ?? 0, 'Mão de obra');
      osData.total = round(osData.valorPecas + osData.maoDeObra);
      const anterior = OS.getById(osData.id);
      const isNew = !anterior;
      if (isNew) {
        osData.numero = StoreConfig.nextSequence('os');
      } else osData.numero = anterior.numero;
      const oldStatus = anterior ? anterior.status : null;
      const newStatus = osData.status || 'Recebido';
      if (!['Recebido', 'Em análise', 'Aguardando aprovação', 'Aguardando peças', 'Em reparo', ...FIM].includes(newStatus)) throw new Error('Status da OS inválido.');
      osData.status = newStatus;
      // Reverse the authoritative prior allocation, then apply the current list.
      for (const b of anterior?.baixaEstoque || []) Produto.estornarEstoqueAtomico(db, b.produtoId, b.qtd);
      osData.baixaEstoque = []; osData.estoqueBaixado = false;

      // Se passou para status concluído/entregue e o estoque ainda não estava baixado
      if (FIM.includes(newStatus)) {
        const pecas = osData.pecas || [];
        const baixas = [];
        for (const p of pecas) {
          if (p.produtoId) {
            if (Produto.baixarEstoqueAtomico(db, p.produtoId, p.qtd)) baixas.push({ produtoId: p.produtoId, qtd: p.qtd });
          }
        }
        osData.baixaEstoque = baixas;
        osData.estoqueBaixado = true;
        if (!osData.dataConclusao) osData.dataConclusao = new Date().toISOString();
      } 
      // Se saiu de concluído/entregue para um status anterior, estorna o estoque
      else if (!FIM.includes(newStatus)) {
        osData.baixaEstoque = [];
        osData.estoqueBaixado = false;
        osData.dataConclusao = null;
      }

      if (newStatus === 'Entregue' && !osData.dataEntrega) {
        osData.dataEntrega = new Date().toISOString();
      }
      if (newStatus !== 'Entregue') osData.dataEntrega = null;
      if (newStatus === 'Entregue' && osData.aparelho) { osData.aparelho.senha = ''; osData.aparelho.senhaPadrao = ''; }
      osData.historico = anterior?.historico || [];
      if (oldStatus !== newStatus) osData.historico.push({ status: newStatus, data: new Date().toISOString(), usuario: osData._actor || 'Sistema' });
      delete osData._actor;

      const stmt = db.prepare(`
        INSERT INTO os (id, numero, status, data) 
        VALUES (?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          numero = excluded.numero,
          status = excluded.status,
          data = excluded.data;
      `);
      stmt.run(osData.id, Number(osData.numero), newStatus, secrets.encode(osData));

      if (idempotencyKey) {
        const respBody = JSON.stringify({ ok: true, os: osData });
        require('./Idempotency').save(db, idempotencyKey, '/api/os', requestHash || '', 200, respBody);
      }

      if (!nested) db.exec('COMMIT;');
      return osData;
    } catch (err) {
      if (!nested) db.exec('ROLLBACK;');
      throw err;
    }
  }

  static saveAll(osList) {
    if (!Array.isArray(osList)) return;
    const db = getDatabase();
    db.exec('DELETE FROM os;');
    const stmt = db.prepare('INSERT INTO os (id, numero, status, data) VALUES (?, ?, ?, ?);');
    for (const o of osList) {
      stmt.run(o.id, Number(o.numero) || 0, o.status || '', secrets.encode(o));
    }
  }
}

module.exports = OS;
