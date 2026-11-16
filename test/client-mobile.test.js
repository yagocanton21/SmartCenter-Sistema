const assert = require('node:assert/strict');
const { start } = require('./helpers');
const auth = require('../server/security/auth');
const { Cliente, OS } = require('../server/models');
(async () => {
  const { request, close } = await start();
  const path = '/api/clientes/mobile-client';
  const change = (before, after) => ({ changes: [{ entity: 'clientes', id: 'mobile-client', before, after }] });
  try {
    assert.equal((await request('GET', path, undefined, {}, true)).status, 401);
    assert.equal((await request('GET', path)).status, 404);
    const client = { id: 'mobile-client', nome: 'Cliente Mobile', telefone: '11999999999', whatsapp: '11999999999', doc: '52998224725', email: 'cliente@example.com', cidade: 'São Paulo', endereco: 'Rua teste', obs: 'Primeiro atendimento', criadoEm: '2026-11-15T10:00:00Z', customField: { preserve: true } };
    const key = { 'Idempotency-Key': 'client-create' };
    assert.equal((await request('POST', '/api/changes', change(null, client), key)).status, 200);
    assert.equal((await request('POST', '/api/changes', change(null, client), key)).status, 200);
    assert.equal(Cliente.getAll().length, 1);
    const current = (await request('GET', path)).body.cliente;
    assert.deepEqual(current.customField, { preserve: true });
    OS.salvarOSTransacional({ id: 'client-order', clienteId: current.id, status: 'Recebido', aparelho: { marca: 'Apple', modelo: 'iPhone' } });
    const after = { ...current, nome: 'Nome atualizado', telefone: '11888888888' };
    assert.equal((await request('POST', '/api/changes', change(current, after))).status, 200);
    assert.equal((await request('GET', path)).body.cliente.nome, 'Nome atualizado');
    assert.equal(OS.getById('client-order').clienteId, current.id);
    assert.equal((await request('POST', '/api/changes', change(current, { ...after, nome: 'Antigo' }))).status, 409);
    const duplicate = { ...client, id: 'duplicate', doc: '529.982.247-25' };
    assert.equal((await request('POST', '/api/changes', { changes: [{ entity: 'clientes', id: duplicate.id, before: null, after: duplicate }] })).status, 409);
    assert.equal((await request('GET', '/api/mobile/records/clientes?q=Nome%20atualizado')).body.items[0].id, client.id);
    auth.save({ id: 'without-clients', login: 'without-clients', nome: 'Sem acesso', perfil: 'tecnico', perms: ['os'], ativo: true, senha: auth.hash('test-pass') });
    const login = await request('POST', '/api/auth/login', { login: 'without-clients', password: 'test-pass' }, {}, true);
    const headers = { Cookie: login.headers.get('set-cookie').split(';')[0], 'X-CSRF-Token': login.body.csrf };
    assert.equal((await request('GET', path, undefined, headers, true)).status, 403);
    assert.equal((await request('POST', '/api/changes', change(after, { ...after, nome: 'Negado' }), headers, true)).status, 403);
    console.log('Mobile client workflow passed');
  } finally { await close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
