/* server/app.js – Inicializador da aplicação e roteamento central */
const http = require('node:http');
const { initSchema } = require('./db/schema');
const { handleApiRequest } = require('./routes/api');
const { handleStaticRequest } = require('./routes/static');

// Inicializa tabelas e índices no SQLite
initSchema();

const app = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = decodeURIComponent(url.pathname);

  // Roteamento: requisições /api/* vão para o router de API
  if (pathname.startsWith('/api')) {
    return handleApiRequest(req, res, pathname);
  }

  // Demais requisições são tratadas pelo router de arquivos estáticos
  return handleStaticRequest(req, res, pathname);
});

module.exports = app;

