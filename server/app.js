const http = require('node:http');
const { initSchema } = require('./db/schema');
const { handleApiRequest } = require('./routes/api');
const { handleStaticRequest } = require('./routes/static');
initSchema();
require('./security/auth').initialize();
const app = http.createServer(async (req, res) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'same-origin');
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (pathname === '/api' || pathname.startsWith('/api/')) await handleApiRequest(req, res, pathname);
    else handleStaticRequest(req, res, pathname);
  } catch (error) {
    if (!res.headersSent) {
      res.writeHead(error.status || (error instanceof URIError ? 400 : 500), { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ ok: false, error: error.status || error instanceof URIError ? error.message : 'Falha interna do servidor.' }));
    } else res.end();
  }
});
app.requestTimeout = 30000;
app.headersTimeout = 15000;
module.exports = app;
﻿
