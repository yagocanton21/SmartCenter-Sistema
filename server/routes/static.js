/* server/routes/static.js – Servidor de arquivos estáticos com suporte a MIME Types */
const fs = require('node:fs');
const path = require('node:path');
const { ROOT_DIR } = require('../config');

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

function handleStaticRequest(req, res, pathname) {
  let filePath = path.join(ROOT_DIR, pathname === '/' ? 'index.html' : pathname);
  filePath = path.normalize(filePath);

  // Prevenção contra Directory Traversal (ex: /../../etc/passwd)
  if (!filePath.startsWith(ROOT_DIR)) {
    res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
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
}

module.exports = {
  handleStaticRequest
};

