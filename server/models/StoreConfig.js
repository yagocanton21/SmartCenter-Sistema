/* server/models/StoreConfig.js – Gestão de configurações da loja e sequenciadores atômicos */
const { getDatabase } = require('../db/connection');

class StoreConfig {
  static getConfig() {
    const db = getDatabase();
    const rows = db.prepare('SELECT key, value FROM config').all();
    const config = {};
    for (const r of rows) {
      try {
        config[r.key] = JSON.parse(r.value);
      } catch {
        config[r.key] = r.value;
      }
    }
    return config;
  }

  static getSequences() {
    const db = getDatabase();
    const rows = db.prepare('SELECT name, val FROM seq').all();
    const seq = { os: 0, orcamento: 0, venda: 0, produto: 0 };
    for (const r of rows) {
      seq[r.name] = r.val;
    }
    return seq;
  }

  /* Incremento atômico de numeração: impede números duplicados de OS, venda ou orçamento */
  static nextSequence(name) {
    const db = getDatabase();
    db.prepare('INSERT OR IGNORE INTO seq (name, val) VALUES (?, 0);').run(name);
    const row = db.prepare('UPDATE seq SET val = val + 1 WHERE name = ? RETURNING val;').get(name);
    return row.val;
  }

  static saveConfig(config) {
    if (!config || typeof config !== 'object') return;
    const db = getDatabase();
    const stmt = db.prepare('INSERT OR REPLACE INTO config (key, value) VALUES (?, ?);');
    for (const k in config) {
      stmt.run(k, JSON.stringify(config[k]));
    }
  }

  static saveSequences(seq) {
    if (!seq || typeof seq !== 'object') return;
    const db = getDatabase();
    const stmt = db.prepare('INSERT OR REPLACE INTO seq (name, val) VALUES (?, ?);');
    for (const k in seq) {
      stmt.run(k, Number(seq[k]) || 0);
    }
  }
}

module.exports = StoreConfig;
