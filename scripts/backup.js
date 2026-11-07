const fs = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const { DB_PATH } = require('../server/config');
if (!fs.existsSync(DB_PATH)) throw new Error('Banco não encontrado.');
const directory = path.resolve(process.argv[2] || path.join(path.dirname(DB_PATH), 'backups'));
fs.mkdirSync(directory, { recursive: true });
const target = path.join(directory, `smartcenter-${new Date().toISOString().replace(/[:.]/g, '-')}.db`);
const db = new DatabaseSync(DB_PATH, { readOnly: true });
try {
  db.exec('PRAGMA busy_timeout=5000');
  db.exec(`VACUUM INTO '${target.replace(/'/g, "''")}'`);
  if (fs.existsSync(DB_PATH + '.key')) fs.copyFileSync(DB_PATH + '.key', target + '.key', fs.constants.COPYFILE_EXCL);
  console.log('Backup consistente criado:', target);
} finally { db.close(); }
