/* server/models/Produto.js – Gestão de produtos e controle atômico de estoque */
const { getDatabase } = require('../db/connection');

class Produto {
  static getAll() {
    const db = getDatabase();
    return db.prepare('SELECT data FROM produtos ORDER BY nome ASC').all().map(r => JSON.parse(r.data));
  }

  static getById(id) {
    const db = getDatabase();
    const row = db.prepare('SELECT data, estoque, controla, ativo FROM produtos WHERE id = ?').get(id);
    if (!row) return null;
    const obj = JSON.parse(row.data);
    obj.estoque = row.estoque;
    obj.controla = !!row.controla;
    obj.ativo = !!row.ativo;
    return obj;
  }

  /* Baixa atômica de estoque com verificação direta no banco */
  static baixarEstoqueAtomico(dbInstance, produtoId, qtd) {
    const db = dbInstance || getDatabase();
    require('./validation').number(qtd, 'Quantidade', 0.000001, 1e6);
    const product = Produto.getById(produtoId);
    if (!product || !product.ativo) throw new Error('Produto inexistente ou inativo.');
    if (!product.controla) return false;
    const stmt = db.prepare(`
      UPDATE produtos 
      SET estoque = estoque - ? 
      WHERE id = ? AND (controla = 0 OR estoque >= ?);
    `);
    const res = stmt.run(qtd, produtoId, qtd);
    if (res.changes === 0) {
      const p = Produto.getById(produtoId);
      const disponivel = p ? p.estoque : 0;
      const nome = p ? p.nome : produtoId;
      throw new Error(`Estoque insuficiente de "${nome}": disponível ${disponivel}, solicitado ${qtd}.`);
    }

    // Atualiza espelho JSON
    const atual = db.prepare('SELECT estoque, data FROM produtos WHERE id = ?').get(produtoId);
    if (atual) {
      try {
        const obj = JSON.parse(atual.data);
        obj.estoque = atual.estoque;
        db.prepare('UPDATE produtos SET data = ? WHERE id = ?').run(JSON.stringify(obj), produtoId);
      } catch {}
    }
    return true;
  }

  /* Estorno atômico de estoque */
  static estornarEstoqueAtomico(dbInstance, produtoId, qtd) {
    const db = dbInstance || getDatabase();
    require('./validation').number(qtd, 'Quantidade', 0.000001, 1e6);
    const product = Produto.getById(produtoId);
    if (!product) throw new Error('Produto do estorno não encontrado.');
    if (!product.controla) return false;
    const stmt = db.prepare(`
      UPDATE produtos 
      SET estoque = estoque + ? 
      WHERE id = ?;
    `);
    stmt.run(qtd, produtoId);

    // Atualiza espelho JSON
    const atual = db.prepare('SELECT estoque, data FROM produtos WHERE id = ?').get(produtoId);
    if (atual) {
      try {
        const obj = JSON.parse(atual.data);
        obj.estoque = atual.estoque;
        db.prepare('UPDATE produtos SET data = ? WHERE id = ?').run(JSON.stringify(obj), produtoId);
      } catch {}
    }
    return true;
  }

  static saveAll(produtos) {
    if (!Array.isArray(produtos)) return;
    const db = getDatabase();
    db.exec('DELETE FROM produtos;');
    const stmt = db.prepare(`
      INSERT INTO produtos (id, codigo, nome, categoria, custo, preco, controla, estoque, estoqueMin, ativo, data) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    `);
    for (const p of produtos) {
      stmt.run(
        p.id,
        p.codigo || '',
        p.nome || '',
        p.categoria || '',
        Number(p.custo) || 0,
        Number(p.preco) || 0,
        p.controla === false ? 0 : 1,
        Number(p.estoque) || 0,
        Number(p.estoqueMin) || 0,
        p.ativo === false ? 0 : 1,
        JSON.stringify(p)
      );
    }
  }

  static upsert(produto) {
    const db = getDatabase();
    const { number } = require('./validation');
    require('./validation').id(produto.id);
    if (!produto.id || !String(produto.nome || '').trim()) throw new Error('Nome e ID do produto obrigatórios.');
    for (const key of ['preco', 'custo', 'estoqueMin']) number(produto[key] ?? 0, key);
    number(produto.estoque ?? 0, 'Estoque');
    if (!produto.codigo) produto.codigo = 'P' + String(require('./StoreConfig').nextSequence('produto')).padStart(4, '0');
    const stmt = db.prepare(`
      INSERT INTO produtos (id, codigo, nome, categoria, custo, preco, controla, estoque, estoqueMin, ativo, data)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        codigo = excluded.codigo,
        nome = excluded.nome,
        categoria = excluded.categoria,
        custo = excluded.custo,
        preco = excluded.preco,
        controla = excluded.controla,
        estoque = excluded.estoque,
        estoqueMin = excluded.estoqueMin,
        ativo = excluded.ativo,
        data = excluded.data;
    `);
    stmt.run(
      produto.id,
      produto.codigo || '',
      produto.nome || '',
      produto.categoria || '',
      Number(produto.custo) || 0,
      Number(produto.preco) || 0,
      produto.controla === false ? 0 : 1,
      Number(produto.estoque) || 0,
      Number(produto.estoqueMin) || 0,
      produto.ativo === false ? 0 : 1,
      JSON.stringify(produto)
    );
  }
}

module.exports = Produto;
