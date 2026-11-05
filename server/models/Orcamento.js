/* server/models/Orcamento.js – Gestão de orçamentos */
const { getDatabase } = require('../db/connection');

class Orcamento {
  static getAll() {
    const db = getDatabase();
    return db.prepare('SELECT data FROM orcamentos ORDER BY numero DESC').all().map(r => JSON.parse(r.data));
  }

  static getById(id) {
    const db = getDatabase();
    const row = db.prepare('SELECT data FROM orcamentos WHERE id = ?').get(id);
    return row ? JSON.parse(row.data) : null;
  }

  static saveAll(orcamentos) {
    if (!Array.isArray(orcamentos)) return;
    const db = getDatabase();
    db.exec('DELETE FROM orcamentos;');
    const stmt = db.prepare('INSERT INTO orcamentos (id, numero, status, data) VALUES (?, ?, ?, ?);');
    for (const o of orcamentos) {
      stmt.run(o.id, Number(o.numero) || 0, o.status || '', JSON.stringify(o));
    }
  }
}

module.exports = Orcamento;

