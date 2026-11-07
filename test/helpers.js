process.env.DB_PATH = ':memory:';
process.env.INITIAL_ADMIN_PASSWORD = 'initial-test-password';
process.env.WEBHOOK_SECRET = 'webhook-test-secret';
const app = require('../server.js');
const crypto = require('node:crypto');
async function start() {
  const server = await new Promise(resolve => { const instance = app.listen(0, '127.0.0.1', () => resolve(instance)); });
  const base = `http://127.0.0.1:${server.address().port}`;
  let cookie = '', csrf = '';
  async function request(method, path, body, headers = {}, anonymous = false) {
    const raw = body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body);
    const response = await fetch(base + path, { method, headers: { ...(anonymous ? {} : { Cookie: cookie, 'X-CSRF-Token': csrf }), 'Content-Type': 'application/json', 'Idempotency-Key': crypto.randomUUID(), ...headers }, body: raw });
    const text = await response.text(); let data;
    try { data = JSON.parse(text); } catch { data = text; }
    return { status: response.status, body: data, headers: response.headers };
  }
  const session = await request('POST','/api/auth/login',{login:'admin',password:process.env.INITIAL_ADMIN_PASSWORD});
  cookie = session.headers.get('set-cookie').split(';')[0]; csrf = session.body.csrf;
  await request('POST','/api/auth/password',{currentPassword:process.env.INITIAL_ADMIN_PASSWORD,password:'permanent-test-password'});
  const close = () => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); });
  return { request, close, base };
}
module.exports = { start };
