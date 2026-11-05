/* server.js – Servidor local e de rede para SmartCenter com banco SQLite nativo.
   Requer Node.js 22+ (usa node:sqlite sem dependências externas). */
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { DatabaseSync } = require('node:sqlite');

const PORT = parseInt(process.env.PORT, 10) || 3000;
const DB_PATH = path.join(__dirname, 'smartcenter.db');

/* ---------- Inicialização do Banco SQLite ---------- */
console.log('📦 Inicializando banco de dados SQLite em:', DB_PATH);
const db = new DatabaseSync(DB_PATH);

// Configuração de alta performance e segurança de concorrência
db.exec('PRAGMA journal_mode = WAL;');
db.exec('PRAGMA synchronous = NORMAL;');
db.exec('PRAGMA foreign_keys = ON;');

// Criação de tabelas
db.exec(`
  CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT
  );

  CREATE TABLE IF NOT EXISTS seq (
    name TEXT PRIMARY KEY,
    val INTEGER
  );

  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    login TEXT UNIQUE,
    data TEXT
  );

  CREATE TABLE IF NOT EXISTS clientes (
    id TEXT PRIMARY KEY,
    nome TEXT,
    doc TEXT,
    telefone TEXT,
    data TEXT
  );

  CREATE TABLE IF NOT EXISTS produtos (
    id TEXT PRIMARY KEY,
    codigo TEXT,
    nome TEXT,
    ativo INTEGER DEFAULT 1,
    data TEXT
  );

  CREATE TABLE IF NOT EXISTS os (
    id TEXT PRIMARY KEY,
    numero INTEGER UNIQUE,
    data TEXT
  );

  CREATE TABLE IF NOT EXISTS orcamentos (
    id TEXT PRIMARY KEY,
    numero INTEGER UNIQUE,
    data TEXT
  );

  CREATE TABLE IF NOT EXISTS vendas (
    id TEXT PRIMARY KEY,
    numero INTEGER UNIQUE,
    data TEXT
  );

  CREATE TABLE IF NOT EXISTS logs (
    id TEXT PRIMARY KEY,
    data TEXT
  );
`);

/* ---------- Operações no SQLite ---------- */
function getDatabaseSnapshot() {
  const cfgRows = db.prepare('SELECT key, value FROM config').all();
  const config = {};
  for (const r of cfgRows) {
    try { config[r.key] = JSON.parse(r.value); } catch { config[r.key] = r.value; }
  }

  const seqRows = db.prepare('SELECT name, val FROM seq').all();
  const seq = { os: 0, orcamento: 0, venda: 0, produto: 0 };
  for (const r of seqRows) seq[r.name] = r.val;

  const users = db.prepare('SELECT data FROM users').all().map(r => JSON.parse(r.data));
  const clientes = db.prepare('SELECT data FROM clientes').all().map(r => JSON.parse(r.data));
  const produtos = db.prepare('SELECT data FROM produtos').all().map(r => JSON.parse(r.data));
  const osList = db.prepare('SELECT data FROM os ORDER BY numero DESC').all().map(r => JSON.parse(r.data));
  const orcamentos = db.prepare('SELECT data FROM orcamentos ORDER BY numero DESC').all().map(r => JSON.parse(r.data));
  const vendas = db.prepare('SELECT data FROM vendas ORDER BY numero DESC').all().map(r => JSON.parse(r.data));
  const logs = db.prepare('SELECT data FROM logs').all().map(r => JSON.parse(r.data));

  const hasData = users.length > 0 || clientes.length > 0 || osList.length > 0 || Object.keys(config).length > 0;

  return {
    hasData,
    db: {
      versao: 1,
      criadoEm: config._criadoEm || new Date().toISOString(),
      config,
      users,
      clientes,
      produtos,
      os: osList,
      orcamentos,
      vendas,
      log: logs,
      seq
    }
  };
}

function saveDatabaseSnapshot(fullDb) {
  if (!fullDb || typeof fullDb !== 'object') throw new Error('Dados inválidos recebidos para salvamento');

  db.exec('BEGIN TRANSACTION;');
  try {
    // Configurações
    if (fullDb.config) {
      const stmtCfg = db.prepare('INSERT OR REPLACE INTO config (key, value) VALUES (?, ?);');
      for (const k in fullDb.config) {
        stmtCfg.run(k, JSON.stringify(fullDb.config[k]));
      }
    }

    // Sequenciadores
    if (fullDb.seq) {
      const stmtSeq = db.prepare('INSERT OR REPLACE INTO seq (name, val) VALUES (?, ?);');
      for (const k in fullDb.seq) {
        stmtSeq.run(k, Number(fullDb.seq[k]) || 0);
      }
    }

    // Usuários
    if (Array.isArray(fullDb.users)) {
      db.exec('DELETE FROM users;');
      const stmtU = db.prepare('INSERT INTO users (id, login, data) VALUES (?, ?, ?);');
      for (const u of fullDb.users) {
        stmtU.run(u.id, u.login || '', JSON.stringify(u));
      }
    }

    // Clientes
    if (Array.isArray(fullDb.clientes)) {
      db.exec('DELETE FROM clientes;');
      const stmtC = db.prepare('INSERT INTO clientes (id, nome, doc, telefone, data) VALUES (?, ?, ?, ?, ?);');
      for (const c of fullDb.clientes) {
        stmtC.run(c.id, c.nome || '', c.doc || '', c.telefone || '', JSON.stringify(c));
      }
    }

    // Produtos
    if (Array.isArray(fullDb.produtos)) {
      db.exec('DELETE FROM produtos;');
      const stmtP = db.prepare('INSERT INTO produtos (id, codigo, nome, ativo, data) VALUES (?, ?, ?, ?, ?);');
      for (const p of fullDb.produtos) {
        stmtP.run(p.id, p.codigo || '', p.nome || '', p.ativo === false ? 0 : 1, JSON.stringify(p));
      }
    }

    // OS
    if (Array.isArray(fullDb.os)) {
      db.exec('DELETE FROM os;');
      const stmtOS = db.prepare('INSERT INTO os (id, numero, data) VALUES (?, ?, ?);');
      for (const o of fullDb.os) {
        stmtOS.run(o.id, Number(o.numero) || 0, JSON.stringify(o));
      }
    }

    // Orçamentos
    if (Array.isArray(fullDb.orcamentos)) {
      db.exec('DELETE FROM orcamentos;');
      const stmtOrc = db.prepare('INSERT INTO orcamentos (id, numero, data) VALUES (?, ?, ?);');
      for (const o of fullDb.orcamentos) {
        stmtOrc.run(o.id, Number(o.numero) || 0, JSON.stringify(o));
      }
    }

    // Vendas
    if (Array.isArray(fullDb.vendas)) {
      db.exec('DELETE FROM vendas;');
      const stmtV = db.prepare('INSERT INTO vendas (id, numero, data) VALUES (?, ?, ?);');
      for (const v of fullDb.vendas) {
        stmtV.run(v.id, Number(v.numero) || 0, JSON.stringify(v));
      }
    }

    // Logs
    if (Array.isArray(fullDb.log)) {
      db.exec('DELETE FROM logs;');
      const stmtL = db.prepare('INSERT INTO logs (id, data) VALUES (?, ?);');
      for (const l of fullDb.log) {
        stmtL.run(l.id || String(Math.random()), JSON.stringify(l));
      }
    }

    db.exec('COMMIT;');
    return true;
  } catch (err) {
    db.exec('ROLLBACK;');
    throw err;
  }
}

/* ---------- Servidor HTTP e MIME Types ---------- */
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8'
};

function sendJSON(res, status, data) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  });
  res.end(JSON.stringify(data));
}

const server = http.createServer((req, res) => {
  // CORS pre-flight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    return res.end();
  }

  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = decodeURIComponent(url.pathname);

  /* Endpoints de API */
  if (pathname === '/api/status') {
    const snap = getDatabaseSnapshot();
    return sendJSON(res, 200, {
      ok: true,
      driver: 'sqlite',
      version: '1.0',
      hasData: snap.hasData,
      counts: {
        clientes: snap.db.clientes.length,
        os: snap.db.os.length,
        orcamentos: snap.db.orcamentos.length,
        vendas: snap.db.vendas.length,
        produtos: snap.db.produtos.length,
        usuarios: snap.db.users.length
      }
    });
  }

  if (pathname === '/api/db' && req.method === 'GET') {
    try {
      const snap = getDatabaseSnapshot();
      return sendJSON(res, 200, snap);
    } catch (e) {
      return sendJSON(res, 500, { ok: false, error: e.message });
    }
  }

  if (pathname === '/api/save' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; if (body.length > 50 * 1024 * 1024) req.destroy(); });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        saveDatabaseSnapshot(payload);
        return sendJSON(res, 200, { ok: true, message: 'Salvo com sucesso no SQLite' });
      } catch (e) {
        console.error('Erro ao salvar no SQLite:', e);
        return sendJSON(res, 500, { ok: false, error: e.message });
      }
    });
    return;
  }

  /* Arquivos Estáticos */
  let filePath = path.join(__dirname, pathname === '/' ? 'index.html' : pathname);
  filePath = path.normalize(filePath);

  if (!filePath.startsWith(__dirname)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    return res.end('403 Proibido');
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
      return res.end('<h3>404 Arquivo não encontrado</h3>');
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME[ext] || 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': contentType });
    fs.createReadStream(filePath).pipe(res);
  });
});

/* ---------- Identificação dos IPs da Rede Local ---------- */
function getLocalIPs() {
  const nets = os.networkInterfaces();
  const results = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        results.push(net.address);
      }
    }
  }
  return results;
}

server.listen(PORT, '0.0.0.0', () => {
  const ips = getLocalIPs();
  console.log('\n======================================================');
  console.log('🚀 SMARTCENTER - SISTEMA COM BANCO DE DADOS SQLITE');
  console.log('======================================================');
  console.log(`📡 Servidor Local:    http://localhost:${PORT}`);
  if (ips.length) {
    ips.forEach(ip => {
      console.log(`🌐 Acesso na Rede:    http://${ip}:${PORT}`);
    });
  }
  console.log('📁 Arquivo SQLite:   smartcenter.db');
  console.log('Pressione Ctrl + C para encerrar o servidor.');
  console.log('======================================================\n');
});

