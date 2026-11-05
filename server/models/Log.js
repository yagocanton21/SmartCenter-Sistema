/* server/models/Log.js – Histórico de logs e auditoria */
const { getDatabase } = require('../db/connection');

class Log {
  static getAll() {
    const db = getDatabase();
    return db.prepare('SELECT data FROM logs ORDER BY rowid DESC LIMIT 500').all().map(r => JSON.parse(r.data));
  }

  static saveAll(logs) {
    if (!Array.isArray(logs)) return;
    const db = getDatabase();
    db.exec('DELETE FROM logs;');
    const stmt = db.prepare('INSERT INTO logs (id, data) VALUES (?, ?);');
    for (const l of logs) {
      stmt.run(l.id || String(Math.random()), JSON.stringify(l));
    }
  }
}

module.exports = Log;

