const assert = require('node:assert/strict');
const { start } = require('./helpers');
const { getDatabase } = require('../server/db/connection');
const auth = require('../server/security/auth');

(async () => {
  const { request, close } = await start();
  try {
    const db = getDatabase();
    for (let i = 0; i < 65; i++) {
      const value = { id: `client-${i}`, nome: `Cliente ${String(i).padStart(3, '0')}`, telefone: '11999999999' };
      db.prepare('INSERT INTO clientes(id,nome,data) VALUES(?,?,?)').run(value.id, value.nome, JSON.stringify(value));
    }
    assert.equal((await request('GET', '/api/mobile/records/clientes', undefined, {}, true)).status, 401);
    const pages = [];
    for (let page = 1; page <= 3; page++) {
      const result = await request('GET', `/api/mobile/records/clientes?page=${page}&pageSize=30`);
      assert.equal(result.status, 200);
      assert.equal(result.body.total, 65);
      assert.equal(result.body.items.length, page === 3 ? 5 : 30);
      assert.equal(result.body.hasMore, page < 3);
      pages.push(...result.body.items);
    }
    assert.equal(new Set(pages.map(x => x.id)).size, 65);
    const search = await request('GET', '/api/mobile/records/clientes?q=Cliente%20064');
    assert.equal(search.body.items[0].id, 'client-64');
    assert.equal(search.body.total, 1);
    assert.equal((await request('GET', '/api/mobile/records/clientes?q=%25')).body.total, 0);
    assert.equal((await request('GET', '/api/mobile/records/clientes?page=99')).body.items.length, 0);
    for (const filter of ['page=0', 'page=-1', 'page=1.5', 'pageSize=101', 'pageSize=0', 'page=nope']) {
      assert.equal((await request('GET', '/api/mobile/records/clientes?' + filter)).status, 400);
    }
    assert.equal((await request('GET', '/api/mobile/records/users')).status, 404);
    const order = { id: 'order', numero: 1, status: 'Em reparo', clienteId: 'client-64', aparelho: { marca: 'Apple', modelo: 'iPhone', senha: 'PRIVATE-PIN' }, total: 100 };
    db.prepare('INSERT INTO os(id,numero,status,data) VALUES(?,?,?,?)').run(order.id, order.numero, order.status, JSON.stringify(order));
    const found = await request('GET', '/api/mobile/records/os?status=Em%20reparo&q=Cliente%20064');
    assert.equal(found.body.total, 1);
    assert.ok(!JSON.stringify(found.body).includes('PRIVATE-PIN'));
    assert.equal((await request('GET', '/api/mobile/records/os?status=Entregue')).body.total, 0);
    auth.save({ id: 'limited-page', login: 'limited-page', nome: 'Limitado', perfil: 'tecnico', perms: ['clientes'], ativo: true, senha: auth.hash('test-password') });
    const login = await request('POST', '/api/auth/login', { login: 'limited-page', password: 'test-password' }, {}, true);
    const headers = { Cookie: login.headers.get('set-cookie').split(';')[0] };
    assert.equal((await request('GET', '/api/mobile/records/os', undefined, headers, true)).status, 403);
    assert.equal((await request('GET', '/api/mobile/records/clientes', undefined, headers, true)).status, 200);
    console.log('Pagination checks passed');
  } finally { await close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
