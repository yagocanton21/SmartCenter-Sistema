const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { DB_PATH } = require('../config');
let key;
function getKey() {
  if (key) return key;
  if (DB_PATH === ':memory:') return (key = crypto.randomBytes(32));
  const file = path.resolve(DB_PATH) + '.key';
  try { fs.writeFileSync(file, crypto.randomBytes(32), { flag: 'wx', mode: 0o600 }); } catch (err) { if (err.code !== 'EEXIST') throw err; }
  key = fs.readFileSync(file);
  if (key.length !== 32) throw new Error('Chave de proteção do banco inválida.');
  return key;
}
function encode(os) {
  const data = structuredClone(os);
  delete data._deviceSecret;
  if (data.aparelho) {
    const secret = { senha: data.aparelho.senha || '', senhaPadrao: data.aparelho.senhaPadrao || '' };
    delete data.aparelho.senha; delete data.aparelho.senhaPadrao;
    if (secret.senha || secret.senhaPadrao) {
      const iv = crypto.randomBytes(12), cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
      const encrypted = Buffer.concat([cipher.update(JSON.stringify(secret), 'utf8'), cipher.final()]);
      data._deviceSecret = [iv.toString('hex'), cipher.getAuthTag().toString('hex'), encrypted.toString('hex')].join(':');
    }
  }
  return JSON.stringify(data);
}
function decode(raw) {
  const data = JSON.parse(raw);
  if (data.aparelho) { data.aparelho.senha ??= ''; data.aparelho.senhaPadrao ??= ''; }
  if (data._deviceSecret) {
    const [iv, tag, content] = data._deviceSecret.split(':');
    const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), Buffer.from(iv, 'hex'));
    decipher.setAuthTag(Buffer.from(tag, 'hex'));
    Object.assign(data.aparelho ||= {}, JSON.parse(Buffer.concat([decipher.update(Buffer.from(content, 'hex')), decipher.final()]).toString('utf8')));
    delete data._deviceSecret;
  }
  return data;
}
function seal(text) {
  const iv = crypto.randomBytes(12), cipher = crypto.createCipheriv('aes-256-gcm',getKey(),iv);
  const content = Buffer.concat([cipher.update(text,'utf8'),cipher.final()]);
  return 'enc:' + [iv.toString('hex'),cipher.getAuthTag().toString('hex'),content.toString('hex')].join(':');
}
function open(text) {
  if (!text.startsWith('enc:')) return text;
  const [,iv,tag,content] = text.split(':');
  const decipher = crypto.createDecipheriv('aes-256-gcm',getKey(),Buffer.from(iv,'hex'));
  decipher.setAuthTag(Buffer.from(tag,'hex'));
  return Buffer.concat([decipher.update(Buffer.from(content,'hex')),decipher.final()]).toString('utf8');
}
module.exports = { encode, decode, seal, open };
