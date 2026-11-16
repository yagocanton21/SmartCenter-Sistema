const assert = require('node:assert/strict');
const { start } = require('./helpers');
const { Produto, Cliente } = require('../server/models');
const auth = require('../server/security/auth');

(async () => {
  const { request, close } = await start();
  try {
    Cliente.salvarCliente({ id: 'mobile-client', nome: 'Cliente teste' });
    Produto.upsert({ id: 'mobile-part', codigo: 'MP', nome: 'Tela teste', preco: 50, custo: 20, estoque: 3, controla: true });
    const order = { id: 'mobile-order', clienteId: 'mobile-client', cliSnap: { nome: 'Cliente teste' }, status: 'Recebido', aparelho: { marca: 'Apple', modelo: 'iPhone', defeito: 'Tela quebrada' }, checklist: { camera: true }, pecas: [{ produtoId: 'mobile-part', descricao: 'Tela', qtd: 1, valor: 50 }], maoDeObra: 30 };
    const key = { 'Idempotency-Key': 'mobile-create' };
    const created = await request('POST', '/api/os', order, key);
    assert.equal(created.status, 200);
    const replay = await request('POST', '/api/os', order, key);
    assert.equal(replay.body.os.numero, created.body.os.numero);
    assert.equal((await request('GET', '/api/os/mobile-order', undefined, {}, true)).status, 401);
    assert.equal((await request('GET', '/api/os/missing')).status, 404);
    const before = (await request('GET', '/api/os/mobile-order')).body.os;
    assert.equal(before.total, 80);
    const update = { ...before, before, status: 'Concluído', diagnostico: 'Tela danificada', servico: 'Tela substituída' };
    const saved = await request('POST', '/api/os', update, { 'Idempotency-Key': 'mobile-update' });
    assert.equal(saved.status, 200);
    assert.equal(Produto.getById('mobile-part').estoque, 2);
    assert.deepEqual(saved.body.os.checklist, { camera: true });
    assert.ok(saved.body.os.historico.some(x => x.status === 'Concluído'));
    assert.equal((await request('POST', '/api/os', update)).status, 409);
    assert.equal((await request('POST', '/api/os', update, { 'Idempotency-Key': 'mobile-update' })).status, 200);
    assert.equal(Produto.getById('mobile-part').estoque, 2);
    const current = (await request('GET', '/api/os/mobile-order')).body.os;
    assert.equal((await request('POST', '/api/os', { ...current, before: current, status: 'Em reparo' })).status, 200);
    assert.equal(Produto.getById('mobile-part').estoque, 3);
    auth.save({ id: 'mobile-limited', login: 'mobile-limited', nome: 'Sem OS', perfil: 'vendedor', perms: ['clientes'], ativo: true, senha: auth.hash('test-pass') });
    const login = await request('POST', '/api/auth/login', { login: 'mobile-limited', password: 'test-pass' }, {}, true);
    const headers = { Cookie: login.headers.get('set-cookie').split(';')[0] };
    assert.equal((await request('GET', '/api/os/mobile-order', undefined, headers, true)).status, 403);
    console.log('Mobile order workflow passed');
  } finally { await close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
