const { start } = require('./helpers');
const assert = require('node:assert/strict');
const { Produto, OS } = require('../server/models');
const { getDatabase } = require('../server/db/connection');
(async () => {
  const { request, close } = await start();
  try {
    Produto.upsert({id:'p',codigo:'P',nome:'Tela',preco:50,custo:20,estoque:1,controla:true});
    const make = id => ({id,itens:[{produtoId:'p',qtd:1,preco:50}]});
    const sales = await Promise.all([request('POST','/api/vendas',make('v1')), request('POST','/api/vendas',make('v2'))]);
    assert.deepEqual(sales.map(x=>x.status).sort(),[201,409]);
    assert.equal(Produto.getById('p').estoque,0);
    const orders = await Promise.all([request('POST','/api/os',{id:'o1',numero:99,status:'Recebido'}),request('POST','/api/os',{id:'o2',numero:99,status:'Recebido'})]);
    assert.deepEqual(orders.map(x=>x.status),[200,200]);
    assert.equal(Math.abs(orders[0].body.os.numero-orders[1].body.os.numero),1);
    const db = (await request('GET','/api/db')).body.db;
    const change = (id,doc) => ({changes:[{entity:'clientes',id,before:null,after:{id,nome:'Cliente',doc}}]});
    const clients = await Promise.all([request('POST','/api/changes',change('c1','123.456.789-00')),request('POST','/api/changes',change('c2','12345678900'))]);
    assert.deepEqual(clients.map(x=>x.status).sort(),[200,409]);
    assert.equal(getDatabase().prepare('SELECT count(*) n FROM clientes').get().n,1);
    const before = db.config.test ?? null;
    const first = {changes:[{entity:'config',id:'test',before,after:'primeiro'}]};
    assert.equal((await request('POST','/api/changes',first)).status,200);
    const stale = {changes:[{entity:'config',id:'test',before,after:'segundo'}]};
    assert.equal((await request('POST','/api/changes',stale)).status,409);
    const other = {changes:[{entity:'config',id:'other',before:null,after:'independente'}]};
    assert.equal((await request('POST','/api/changes',other)).status,200);
    assert.equal((await request('GET','/api/db')).body.db.config.test,'primeiro');
    // A stale user cannot overwrite inventory changed by a concurrent sale.
    const product = (await request('GET','/api/db')).body.db.produtos[0];
    Produto.upsert({...Produto.getById('p'),estoque:10});
    const staleProduct = {changes:[{entity:'produtos',id:'p',before:product,after:{...product,nome:'Outro'}}]};
    assert.equal((await request('POST','/api/changes',staleProduct)).status,409);
    OS.salvarOSTransacional({id:'completed',status:'Concluído',pecas:[{produtoId:'p',qtd:1,valor:50}]});
    const order = OS.getById('completed'); order.pecas[0].qtd = 3;
    OS.salvarOSTransacional(order);
    assert.equal(Produto.getById('p').estoque,7);
    order.status='Recebido'; OS.salvarOSTransacional(order);
    assert.equal(Produto.getById('p').estoque,10);
    console.log('OK: estoque concorrente, sequências, documentos normalizados, conflitos por registro, reconciliação e estorno de OS.');
  } finally { await close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
