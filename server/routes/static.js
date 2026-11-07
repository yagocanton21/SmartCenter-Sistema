const fs = require('node:fs');
const path = require('node:path');
const { ROOT_DIR } = require('../config');
const MIME = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8' };
const assets = new Set(['/index.html']);
for (const dir of ['js', 'css']) for (const file of fs.readdirSync(path.join(ROOT_DIR, dir))) {
  if (['.js', '.css'].includes(path.extname(file))) assets.add(`/${dir}/${file}`);
}
function handleStaticRequest(req, res, pathname) {
  if (pathname === '/') pathname = '/index.html';
  if (!['GET', 'HEAD'].includes(req.method) || !assets.has(pathname)) { res.writeHead(404); return res.end('Arquivo não encontrado'); }
  fs.readFile(path.join(ROOT_DIR, pathname), (err, data) => {
    if (err) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(pathname)], 'Cache-Control': 'no-cache' });
    res.end(req.method === 'HEAD' ? undefined : data);
  });
}
module.exports = { handleStaticRequest };
﻿
