/* server/models/Venda.js – Gestão de vendas e transações atômicas de venda */
const { getDatabase } = require('../db/connection');
const Produto = require('./Produto');
const StoreConfig = require('./StoreConfig');

class Venda {
  static getAll() {
    const db = getDatabase();
    return db.prepare('SELECT data FROM vendas ORDER BY numero DESC').all().map(r => JSON.parse(r.data));
  }

  static getById(id) {
    const db = getDatabase();
    const row = db.prepare('SELECT data FROM vendas WHERE id = ?').get(id);
    return row ? JSON.parse(row.data) : null;
  }

  /* Criação de venda 100% transacional e atômica: numeração sequencial + baixa de estoque + chave de idempotência */
  static criarVendaTransacional(venda, idempotencyKey, requestHash) {
    const db = getDatabase();
    const nested = db.isTransaction;
    if (!nested) db.exec('BEGIN IMMEDIATE;');
    try {
      const { lines, number, round } = require('./validation');
      require('./validation').id(venda.id);
      venda.data ||= new Date().toISOString();
      require('./validation').dates(venda, ['data']);
      if (!venda.id || !Array.isArray(venda.itens) || !venda.itens.length) throw new Error('Venda sem ID ou sem itens.');
      venda.subtotal = lines(venda.itens, 'preco');
      let custo = 0;
      for (const item of venda.itens) {
        const p = item.produtoId && Produto.getById(item.produtoId);
        if (item.produtoId && (!p || !p.ativo)) throw new Error('Produto inexistente ou inativo.');
        item.custo = p ? Number(p.custo || 0) : 0;
        custo += item.qtd * item.custo;
      }
      const discountValue = number(venda.descontoValor ?? 0, 'Desconto');
      if (venda.descontoTipo === 'percent' && discountValue > 100) throw new Error('Desconto percentual inválido.');
      venda.desconto = round(venda.descontoTipo === 'percent' ? venda.subtotal * discountValue / 100 : discountValue);
      if (venda.desconto > venda.subtotal) throw new Error('Desconto maior que o subtotal.');
      venda.total = round(venda.subtotal - venda.desconto);
      venda.lucro = round(venda.total - custo);
      delete venda.numero;
      // 1. Gera número sequencial atômico pelo banco se não foi definido
      if (!venda.numero) {
        venda.numero = StoreConfig.nextSequence('venda');
      }

      // 2. Aplica baixa de estoque atômica para cada produto controlado
      const itens = venda.itens || [];
      const baixas = [];
      for (const item of itens) {
        if (item.produtoId) {
          if (Produto.baixarEstoqueAtomico(db, item.produtoId, item.qtd)) baixas.push({ produtoId: item.produtoId, qtd: item.qtd });
        }
      }
      venda.baixa = baixas;
      venda.status = 'Concluída';

      // 3. Grava o registro da venda
      const stmt = db.prepare('INSERT INTO vendas (id, numero, status, data) VALUES (?, ?, ?, ?);');
      stmt.run(venda.id, Number(venda.numero), venda.status, JSON.stringify(venda));

      // 4. Salva a chave de idempotência dentro da mesma transação atômica
      if (idempotencyKey) {
        const respBody = JSON.stringify({ ok: true, venda });
        require('./Idempotency').save(db, idempotencyKey, '/api/vendas', requestHash || '', 201, respBody);
      }

      if (!nested) db.exec('COMMIT;');
      return venda;
    } catch (err) {
      if (!nested) db.exec('ROLLBACK;');
      throw err;
    }
  }

  /* Cancelamento transacional da venda com devolução de estoque */
  static cancelarVendaTransacional(vendaId) {
    const db = getDatabase();
    const nested = db.isTransaction;
    if (!nested) db.exec('BEGIN IMMEDIATE;');
    try {
      const venda = Venda.getById(vendaId);
      if (!venda) throw new Error('Venda não encontrada');
      if (venda.status === 'Cancelada') { if (!nested) db.exec('COMMIT;'); return venda; }

      // Estorna estoque dos itens
      if (Array.isArray(venda.baixa)) {
        for (const b of venda.baixa) {
          Produto.estornarEstoqueAtomico(db, b.produtoId, b.qtd);
        }
      }

      venda.status = 'Cancelada';
      venda.baixa = [];
      db.prepare('UPDATE vendas SET status = ?, data = ? WHERE id = ?').run(
        'Cancelada',
        JSON.stringify(venda),
        vendaId
      );

      if (!nested) db.exec('COMMIT;');
      return venda;
    } catch (err) {
      if (!nested) db.exec('ROLLBACK;');
      throw err;
    }
  }

  static saveAll(vendas) {
    if (!Array.isArray(vendas)) return;
    const db = getDatabase();
    db.exec('DELETE FROM vendas;');
    const stmt = db.prepare('INSERT INTO vendas (id, numero, status, data) VALUES (?, ?, ?, ?);');
    for (const v of vendas) {
      stmt.run(v.id, Number(v.numero) || 0, v.status || '', JSON.stringify(v));
    }
  }
}

module.exports = Venda;
