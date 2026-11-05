/* server/models/Usuario.js – Gestão de usuários e permissões */
const { getDatabase } = require('../db/connection');

class Usuario {
  static getAll() {
    const db = getDatabase();
    return db.prepare('SELECT data FROM users').all().map(r => JSON.parse(r.data));
  }

  static getById(id) {
    const db = getDatabase();
    const row = db.prepare('SELECT data FROM users WHERE id = ?').get(id);
    return row ? JSON.parse(row.data) : null;
  }

  static getByLogin(login) {
    const db = getDatabase();
    const row = db.prepare('SELECT data FROM users WHERE login = ?').get(login);
    return row ? JSON.parse(row.data) : null;
  }

  static saveAll(users) {
    if (!Array.isArray(users)) return;
    const db = getDatabase();
    db.exec('DELETE FROM users;');
    const stmt = db.prepare('INSERT INTO users (id, login, data) VALUES (?, ?, ?);');
    for (const u of users) {
      stmt.run(u.id, u.login || '', JSON.stringify(u));
    }
  }
}

module.exports = Usuario;

