const crypto = require('node:crypto');
const { getDatabase } = require('../db/connection');
const Usuario = require('../models/Usuario');
const sessions = new Map(), attempts = new Map();
const MAX_AGE = 8 * 60 * 60 * 1000;
const permissions = ['dashboard', 'os', 'notas', 'orcamentos', 'vendas', 'produtos', 'clientes', 'config', 'usuarios', 'backup', 'excluir'];
function fail(message, status = 400) { throw Object.assign(new Error(message), { status }); }
function hash(password) {
  if (typeof password !== 'string' || password.length < 10 || password.length > 256) fail('A senha deve ter entre 10 e 256 caracteres.');
  const salt = crypto.randomBytes(16).toString('hex');
  return `scrypt:${salt}:${crypto.scryptSync(password, salt, 64).toString('hex')}`;
}
function legacyHash(s) {
  let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
  const str = 'sc|' + s;
  for (let i = 0; i < str.length; i++) { const ch = str.charCodeAt(i); h1 = Math.imul(h1 ^ ch, 2654435761); h2 = Math.imul(h2 ^ ch, 1597334677); }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(16);
}
function verify(password, stored) {
  if (typeof password !== 'string' || password.length > 256 || typeof stored !== 'string') return false;
  if (!stored.startsWith('scrypt:')) return stored === legacyHash(password);
  const [, salt, value] = stored.split(':');
  try { return crypto.timingSafeEqual(crypto.scryptSync(password, salt, 64), Buffer.from(value, 'hex')); } catch { return false; }
}
function publicUser(user) { const { senha, password, ...safe } = user; return safe; }
function save(user) {
  getDatabase().prepare('INSERT INTO users(id,login,data) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET login=excluded.login,data=excluded.data').run(user.id, user.login, JSON.stringify(user));
}
function initialize() {
  if (!Usuario.getAll().length) {
    const password = process.env.INITIAL_ADMIN_PASSWORD || crypto.randomBytes(18).toString('base64url');
    save({ id: crypto.randomUUID(), login: 'admin', nome: 'Administrador', perfil: 'admin', perms: permissions, ativo: true, senha: hash(password), mustChangePassword: true });
    if (!process.env.INITIAL_ADMIN_PASSWORD) console.log(`Primeiro acesso — admin / ${password} (troca obrigatória).`);
  }
}
function can(user, permission) { return user && (user.perfil === 'admin' || (user.perms || []).includes(permission)); }
function requirePermission(user, permission) { if (!can(user, permission)) fail('Você não tem permissão para esta operação.', 403); }
function cookie(req) { return (req.headers.cookie || '').split(';').map(x => x.trim()).find(x => x.startsWith('sc_session='))?.slice(11); }
function current(req) {
  const token = cookie(req), session = sessions.get(token);
  if (!session) return null;
  if (session.expires < Date.now()) { sessions.delete(token); return null; }
  const user = Usuario.getById(session.userId);
  if (!user || !user.ativo) { sessions.delete(token); return null; }
  return { user, csrf: session.csrf, token };
}
function login(req, res, body) {
  const ip = req.socket.remoteAddress, attempt = attempts.get(ip);
  if (attempt && attempt.until > Date.now() && attempt.count >= 10) fail('Muitas tentativas. Aguarde 15 minutos.', 429);
  if (!attempt || attempt.until <= Date.now()) attempts.set(ip, { count: 0, until: Date.now() + 900000 });
  if (attempts.size > 10000) for (const [key, value] of attempts) if (value.until <= Date.now()) attempts.delete(key);
  const user = Usuario.getByLogin(String(body.login || '').trim().toLowerCase());
  if (!user || !user.ativo || !verify(body.password, user.senha)) { attempts.get(ip).count++; fail('Usuário ou senha incorretos.', 401); }
  attempts.delete(ip);
  if (!user.senha.startsWith('scrypt:')) {
    user.mustChangePassword = true;
    // Derive immediately even for legacy short passwords; replacement remains mandatory.
    const salt = crypto.randomBytes(16).toString('hex');
    user.senha = `scrypt:${salt}:${crypto.scryptSync(body.password,salt,64).toString('hex')}`;
    save(user);
  }
  for (const [key, session] of sessions) if (session.expires < Date.now()) sessions.delete(key);
  if (sessions.size >= 5000) fail('Limite de sessões atingido.', 503);
  const old = cookie(req); if (old) sessions.delete(old);
  const token = crypto.randomBytes(32).toString('hex'), csrf = crypto.randomBytes(32).toString('hex');
  sessions.set(token, { userId: user.id, csrf, expires: Date.now() + MAX_AGE });
  res.setHeader('Set-Cookie', `sc_session=${token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${MAX_AGE / 1000}${process.env.COOKIE_SECURE === 'true' ? '; Secure' : ''}`);
  return { user: publicUser(user), csrf };
}
function logout(req, res) { sessions.delete(cookie(req)); res.setHeader('Set-Cookie', 'sc_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0'); }
function invalidate(userId) { for (const [token, session] of sessions) if (!userId || session.userId === userId) sessions.delete(token); }
function changePassword(session, body) {
  if (!verify(body.currentPassword, session.user.senha)) fail('Senha atual incorreta.', 403);
  session.user.senha = hash(body.password); session.user.mustChangePassword = false; save(session.user);
  for (const [token, value] of sessions) if (value.userId === session.user.id && token !== session.token) sessions.delete(token);
}
module.exports = { initialize, hash, verify, publicUser, save, can, requirePermission, current, login, logout, changePassword, fail, permissions, invalidate };
