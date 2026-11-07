/* server/db/schema.js – Definição e migração das tabelas, índices e idempotência no SQLite */
const { getDatabase } = require('./connection');

function initSchema() {
  const db = getDatabase();
  const version = db.prepare('PRAGMA user_version').get().user_version;
  const existing = db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(r => r.name);
  const tables = ['config', 'seq', 'users', 'clientes', 'produtos', 'os', 'orcamentos', 'vendas', 'logs'];
  let legacy;
  if (version < 2 && existing.includes('produtos')) {
    const { DB_PATH } = require('../config');
    if (DB_PATH !== ':memory:') {
      const backup = DB_PATH + '.pre-v2-' + Date.now() + '.bak';
      db.exec(`VACUUM INTO '${backup.replace(/'/g, "''")}';`);
      console.log('Backup antes da migração:', backup);
    }
    legacy = Object.fromEntries(tables.map(t => [t, existing.includes(t) ? db.prepare(`SELECT * FROM ${t}`).all() : []]));
    db.exec('BEGIN IMMEDIATE;');
    for (const table of tables) if (existing.includes(table)) db.exec(`DROP TABLE ${table};`);
  }

  function ensureColumn(table, column, def) {
    const cols = db.prepare(`PRAGMA table_info(${table})`).all().map(c => c.name);
    if (!cols.includes(column)) {
      try {
        db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${def};`);
      } catch (e) {
        console.warn(`Aviso ao migrar coluna ${column} em ${table}:`, e.message);
      }
    }
  }

  try { db.exec(`
    CREATE TABLE IF NOT EXISTS config (
      key TEXT PRIMARY KEY,
      value TEXT
    );

    CREATE TABLE IF NOT EXISTS seq (
      name TEXT PRIMARY KEY,
      val INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      login TEXT UNIQUE NOT NULL,
      data TEXT
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_users_login_unique ON users(login);

    CREATE TABLE IF NOT EXISTS clientes (
      id TEXT PRIMARY KEY,
      nome TEXT NOT NULL,
      doc TEXT,
      telefone TEXT,
      data TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_clientes_nome ON clientes(nome);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_doc_unique 
      ON clientes(doc) 
      WHERE doc IS NOT NULL AND trim(doc) != '';

    CREATE TABLE IF NOT EXISTS produtos (
      id TEXT PRIMARY KEY,
      codigo TEXT UNIQUE,
      nome TEXT NOT NULL,
      categoria TEXT,
      custo REAL DEFAULT 0,
      preco REAL NOT NULL,
      controla INTEGER DEFAULT 1,
      estoque REAL DEFAULT 0 CHECK (controla = 0 OR estoque >= 0),
      estoqueMin REAL DEFAULT 0,
      ativo INTEGER DEFAULT 1,
      data TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_produtos_codigo ON produtos(codigo);
    CREATE INDEX IF NOT EXISTS idx_produtos_nome ON produtos(nome);

    CREATE TABLE IF NOT EXISTS os (
      id TEXT PRIMARY KEY,
      numero INTEGER UNIQUE NOT NULL,
      status TEXT,
      data TEXT
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_os_numero ON os(numero);

    CREATE TABLE IF NOT EXISTS orcamentos (
      id TEXT PRIMARY KEY,
      numero INTEGER UNIQUE NOT NULL,
      status TEXT,
      data TEXT
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_orcamentos_numero ON orcamentos(numero);

    CREATE TABLE IF NOT EXISTS vendas (
      id TEXT PRIMARY KEY,
      numero INTEGER UNIQUE NOT NULL,
      status TEXT,
      data TEXT
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_vendas_numero ON vendas(numero);

    CREATE TABLE IF NOT EXISTS logs (
      id TEXT PRIMARY KEY,
      data TEXT
    );

    /* ---------- Tabelas de Idempotência e Webhooks de Pagamento ---------- */
    CREATE TABLE IF NOT EXISTS idempotency_keys (
      key TEXT PRIMARY KEY,
      endpoint TEXT NOT NULL,
      request_hash TEXT NOT NULL,
      response_status INTEGER NOT NULL,
      response_body TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_idempotency_created ON idempotency_keys(created_at);

    CREATE TABLE IF NOT EXISTS processed_webhook_events (
      event_id TEXT PRIMARY KEY,
      gateway TEXT NOT NULL,
      event_type TEXT NOT NULL,
      payload TEXT,
      processed_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS payment_charges (
      id TEXT PRIMARY KEY,
      gateway TEXT NOT NULL,
      os_id TEXT NOT NULL,
      amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
      method TEXT NOT NULL,
      status TEXT NOT NULL
    );
  `);

  ensureColumn('vendas', 'status', 'TEXT');
  ensureColumn('os', 'status', 'TEXT');
  ensureColumn('orcamentos', 'status', 'TEXT');
  if (legacy) {
    const models = require('../models');
    const config = Object.fromEntries(legacy.config.map(r => [r.key, JSON.parse(r.value)]));
    models.StoreConfig.saveConfig(config);
    models.StoreConfig.saveSequences(Object.fromEntries(legacy.seq.map(r => [r.name, r.val])));
    models.Usuario.saveAll(legacy.users.map(r => JSON.parse(r.data)));
    models.Cliente.saveAll(legacy.clientes.map(r => JSON.parse(r.data)));
    models.Produto.saveAll(legacy.produtos.map(r => JSON.parse(r.data)));
    models.OS.saveAll(legacy.os.map(r => require('../security/secrets').decode(r.data)));
    models.Orcamento.saveAll(legacy.orcamentos.map(r => JSON.parse(r.data)));
    models.Venda.saveAll(legacy.vendas.map(r => JSON.parse(r.data)));
    models.Log.saveAll(legacy.logs.map(r => JSON.parse(r.data)));
  }
  for (const [name, table, column] of [['os','os','numero'], ['venda','vendas','numero'], ['orcamento','orcamentos','numero']]) {
    const max = db.prepare(`SELECT coalesce(max(${column}),0) AS n FROM ${table}`).get().n;
    db.prepare('INSERT INTO seq(name,val) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET val=max(val,excluded.val)').run(name, max);
  }
  // Encrypt device secrets left in JSON by older versions.
  const secrets = require('../security/secrets');
  for (const row of db.prepare('SELECT id,data FROM os').all()) {
    const value = secrets.decode(row.data);
    if (value.status === 'Entregue' && value.aparelho) { value.aparelho.senha = ''; value.aparelho.senhaPadrao = ''; }
    db.prepare('UPDATE os SET data=? WHERE id=?').run(secrets.encode(value), row.id);
  }
  if (version < 2) db.exec('DELETE FROM idempotency_keys;');
  db.exec('PRAGMA user_version = 2;');
  if (legacy) db.exec('COMMIT;');
  } catch (err) {
    if (legacy) db.exec('ROLLBACK;');
    throw new Error(`Não foi possível migrar o banco; dados anteriores preservados: ${err.message}`);
  }
}

module.exports = {
  initSchema
};
