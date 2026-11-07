/* server/models/Cliente.js – Gestão de clientes com validação única de documento */
const { getDatabase } = require('../db/connection');

class Cliente {
  static getAll() {
    const db = getDatabase();
    return db.prepare('SELECT data FROM clientes ORDER BY nome ASC').all().map(r => JSON.parse(r.data));
  }

  static getById(id) {
    const db = getDatabase();
    const row = db.prepare('SELECT data FROM clientes WHERE id = ?').get(id);
    return row ? JSON.parse(row.data) : null;
  }

  static getByDoc(doc) {
    if (!doc) return null;
    const db = getDatabase();
    const row = db.prepare('SELECT data FROM clientes WHERE trim(doc) = trim(?)').get(doc);
    return row ? JSON.parse(row.data) : null;
  }

  static salvarCliente(cliente) {
    const db = getDatabase();
    if (!cliente.id || !String(cliente.nome || '').trim()) throw new Error('Nome e ID do cliente obrigatórios.');
    require('./validation').id(cliente.id);
    cliente.doc = String(cliente.doc || '').replace(/\D/g, '');
    try {
      const stmt = db.prepare(`
        INSERT INTO clientes (id, nome, doc, telefone, data) 
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          nome = excluded.nome,
          doc = excluded.doc,
          telefone = excluded.telefone,
          data = excluded.data;
      `);
      stmt.run(cliente.id, cliente.nome || '', cliente.doc || null, cliente.telefone || '', JSON.stringify(cliente));
      return cliente;
    } catch (err) {
      if (err.message.includes('UNIQUE constraint failed: clientes.doc')) {
        throw new Error(`Já existe um cliente cadastrado com o CPF/CNPJ informado.`);
      }
      throw err;
    }
  }

  static saveAll(clientes) {
    if (!Array.isArray(clientes)) return;
    const db = getDatabase();
    db.exec('DELETE FROM clientes;');
    const stmt = db.prepare('INSERT INTO clientes (id, nome, doc, telefone, data) VALUES (?, ?, ?, ?, ?);');
    for (const c of clientes) {
      c.doc = String(c.doc || '').replace(/\D/g, '');
      stmt.run(c.id, c.nome || '', c.doc || null, c.telefone || '', JSON.stringify(c));
    }
  }
}

module.exports = Cliente;
