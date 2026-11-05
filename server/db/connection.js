/* server/db/connection.js – Conexão SQLite com DatabaseSync (Node 22+) */
const { DatabaseSync } = require('node:sqlite');
const { DB_PATH } = require('../config');

let dbInstance = null;

function getDatabase() {
  if (!dbInstance) {
    dbInstance = new DatabaseSync(DB_PATH);
    
    // Otimizações de concorrência e integridade
    dbInstance.exec('PRAGMA journal_mode = WAL;');
    dbInstance.exec('PRAGMA synchronous = NORMAL;');
    dbInstance.exec('PRAGMA foreign_keys = ON;');
  }
  return dbInstance;
}

module.exports = {
  getDatabase
};

