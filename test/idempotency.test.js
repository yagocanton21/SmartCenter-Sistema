const { start } = require('./helpers');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { Produto, OS, Idempotency } = require('../server/models');
const { getDatabase } = require('../server/db/connection');
(async()=>{
  const {request,close}=await start();
  try {
    Produto.upsert({id:'p',codigo:'P',nome:'Cabo',preco:25,custo:5,estoque:10,controla:true});
    const sale={id:'v',itens:[{produtoId:'p',qtd:2,preco:25}],total:999};
    const headers={'Idempotency-Key':'repeat'};
    const first=await request('POST','/api/vendas',sale,headers);
    assert.equal(first.status,201); assert.equal(first.body.venda.total,50);
    const second=await request('POST','/api/vendas',sale,headers);
    assert.deepEqual(second.body,first.body); assert.equal(second.headers.get('x-idempotent-replay'),'true');
    assert.equal(Produto.getById('p').estoque,8);
    const changed=await request('POST','/api/vendas',{...sale,total:10},headers);
    assert.equal(changed.status,422);
    const simultaneous=await Promise.all([request('POST','/api/vendas',{...sale,id:'simultaneous'},{'Idempotency-Key':'parallel'}),request('POST','/api/vendas',{...sale,id:'simultaneous'},{'Idempotency-Key':'parallel'})]);
    assert.deepEqual(simultaneous.map(r=>r.status),[201,201]); assert.equal(Produto.getById('p').estoque,6);
    assert.equal((await request('POST','/api/vendas',{id:'bad',itens:[{produtoId:'p',qtd:-2,preco:25}]})).status,400);
    assert.equal(Produto.getById('p').estoque,6);
    // Same client key in another endpoint is isolated.
    assert.equal((await request('POST','/api/os',{id:'o',status:'Recebido',maoDeObra:50},headers)).status,200);
    assert.equal((await request('POST','/api/payment-charges',{id:'charge',gateway:'pix',osId:'o'})).status,201);
    const event={id:'evt',gateway:'pix',status:'pago',chargeId:'charge',osId:'o',amountCents:5000,currency:'BRL'};
    const signed=body=>({'X-Signature':crypto.createHmac('sha256',process.env.WEBHOOK_SECRET).update(JSON.stringify(body)).digest('hex')});
    assert.equal((await request('POST','/api/webhooks/pagamentos',event)).status,401);
    const wrong={...event,amountCents:1};
    assert.equal((await request('POST','/api/webhooks/pagamentos',wrong,signed(wrong))).status,400);
    assert.equal(getDatabase().prepare('SELECT count(*) n FROM processed_webhook_events').get().n,0);
    const wh=await request('POST','/api/webhooks/pagamentos',event,signed(event));
    assert.equal(wh.status,200);
    const retry=await request('POST','/api/webhooks/pagamentos',event,signed(event));
    assert.equal(retry.body.duplicate,true); assert.equal(OS.getById('o').pagamentoStatus,'pago');
    assert.equal(OS.getById('o').status,'Recebido');
    assert.equal(Idempotency.verifyWebhookSignature('{}',undefined,undefined),false);
    await request('POST','/api/vendas/v/cancelar',{}); await request('POST','/api/vendas/v/cancelar',{});
    assert.equal(Produto.getById('p').estoque,8);
    console.log('OK: repetição sequencial e concorrente, conflitos, isolamento de chaves, validação financeira, webhook assinado e cancelamento repetido.');
  } finally { await close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
