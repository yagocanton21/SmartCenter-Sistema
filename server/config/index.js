/* server/config/index.js – Configurações centralizadas do servidor */
const fs = require('node:fs');
const path = require('node:path');

const ROOT_DIR = path.resolve(__dirname, '../..');
const PORT = parseInt(process.env.PORT, 10) || 3000;
const DB_PATH = process.env.DB_PATH || path.join(ROOT_DIR, 'smartcenter.db');

// Garante que o diretório onde o arquivo SQLite será gravado existe
const dbDir = path.dirname(DB_PATH);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

module.exports = {
  PORT,
  ROOT_DIR,
  DB_PATH
};
