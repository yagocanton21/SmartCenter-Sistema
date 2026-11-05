/* server/db/schema.js – Definição e migração das tabelas, índices e idempotência no SQLite */
const { getDatabase } = require('./connection');

function initSchema() {
  const db = getDatabase();

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

  db.exec(`
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
  `);

  ensureColumn('vendas', 'status', 'TEXT');
  ensureColumn('os', 'status', 'TEXT');
  ensureColumn('orcamentos', 'status', 'TEXT');
}

module.exports = {
  initSchema
};
