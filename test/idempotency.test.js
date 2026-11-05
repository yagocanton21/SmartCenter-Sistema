/* test/idempotency.test.js – Testes Automatizados de Idempotência e Webhooks */
const http = require('node:http');
const assert = require('node:assert');
const crypto = require('node:crypto');
const app = require('../server/app');
const { getDatabase } = require('../server/db/connection');
const { initSchema } = require('../server/db/schema');

const TEST_PORT = 3998;
let serverInstance;

function request(method, path, body, customHeaders = {}) {
  return new Promise((resolve, reject) => {
    const payload = body ? (typeof body === 'string' ? body : JSON.stringify(body)) : null;
    const req = http.request({
      hostname: '127.0.0.1',
      port: TEST_PORT,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        ...customHeaders
      }
    }, res => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        let parsed = null;
        try { parsed = JSON.parse(data); } catch {}
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: parsed,
          raw: data
        });
      });
    });

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function runTests() {
  console.log('\n========================================================');
  console.log('🛡️  INICIANDO TESTES DE IDEMPOTÊNCIA E WEBHOOKS');
  console.log('========================================================\n');

  await new Promise(res => {
    serverInstance = app.listen(TEST_PORT, '127.0.0.1', res);
  });

  const db = getDatabase();
  initSchema();

  try {
    /* --------------------------------------------------------
       TESTE 1: RETENTATIVA SEQUENCIAL COM A MESMA IDEMPOTENCY-KEY
       Cenário: Cliente finaliza venda de 2 unidades de película.
       A conexão oscila e o cliente retransmite a mesma requisição.
       Prova: Ambas retornam HTTP 201 com os mesmos dados, mas o estoque
       diminui apenas 2 unidades (saldo final = 8, NUNCA 6).
    -------------------------------------------------------- */
    console.log('▶ Teste 1: Retentativa Sequencial com Idempotency-Key...');
    const prodId1 = 'prod_idemp_1_' + Date.now();
    const codProd1 = 'PID1_' + Date.now();
    db.prepare(`
      INSERT INTO produtos (id, codigo, nome, preco, custo, controla, estoque, ativo, data)
      VALUES (?, ?, 'Película de Vidro 3D', 25, 5, 1, 10, 1, '{}')
    `).run(prodId1, codProd1);

    const idempotencyKey1 = crypto.randomUUID();
    const vendaPayload1 = {
      id: 'v_idemp_' + Date.now(),
      itens: [{ produtoId: prodId1, descricao: 'Película 3D', qtd: 2, preco: 25, custo: 5 }],
      total: 50,
      formaPagamento: 'Pix'
    };

    // 1ª Chamada
    const res1A = await request('POST', '/api/vendas', vendaPayload1, {
      'Idempotency-Key': idempotencyKey1
    });
    assert.strictEqual(res1A.status, 201, `Primeira chamada deveria retornar 201, retornou ${res1A.status}`);
    const numeroVenda = res1A.body.venda.numero;

    // 2ª Chamada (Mesma chave e mesmo payload)
    const res1B = await request('POST', '/api/vendas', vendaPayload1, {
      'Idempotency-Key': idempotencyKey1
    });
    assert.strictEqual(res1B.status, 201, `Segunda chamada deveria retornar 201 via cache de idempotência, retornou ${res1B.status}`);
    assert.strictEqual(res1B.headers['x-idempotent-replay'], 'true', 'Deveria conter header X-Idempotent-Replay');
    assert.strictEqual(res1B.body.venda.numero, numeroVenda, 'O número da venda deve ser rigorosamente o mesmo');

    // Validação de saldo no banco de dados
    const p1 = db.prepare('SELECT estoque FROM produtos WHERE id = ?').get(prodId1);
    assert.strictEqual(p1.estoque, 8, `O estoque deveria ser 8 (10 - 2). Obtido: ${p1.estoque}`);

    // Validação de que existe apenas UMA venda no banco
    const totalVendas = db.prepare('SELECT COUNT(*) as c FROM vendas WHERE numero = ?').get(numeroVenda).c;
    assert.strictEqual(totalVendas, 1, `Deveria existir exatamente 1 venda gravada. Encontradas: ${totalVendas}`);

    console.log(`   ✅ PASSOU: Venda #${numeroVenda} reutilizada transparentemente (Header X-Idempotent-Replay: true).`);
    console.log(`   📦 Saldo no SQLite permaneceu em 8 unidades (baixa aplicada exatamente 1 vez).\n`);

    /* --------------------------------------------------------
       TESTE 2: REQUISIÇÕES CONCORRENTES SIMULTÂNEAS COM MESMA IDEMPOTENCY-KEY
       Cenário: Cliente dispara 2 requisições no exato mesmo milissegundo com a mesma chave.
       Prova: Ambas têm sucesso com a mesma resposta e o estoque baixa uma só vez.
    -------------------------------------------------------- */
    console.log('▶ Teste 2: Concorrência Simultânea com a Mesma Idempotency-Key...');
    const prodId2 = 'prod_idemp_2_' + Date.now();
    const codProd2 = 'PID2_' + Date.now();
    db.prepare(`
      INSERT INTO produtos (id, codigo, nome, preco, custo, controla, estoque, ativo, data)
      VALUES (?, ?, 'Cabo USB-C Original', 40, 15, 1, 5, 1, '{}')
    `).run(prodId2, codProd2);

    const idempotencyKey2 = crypto.randomUUID();
    const vendaPayload2 = {
      id: 'v_idemp_simult_' + Date.now(),
      itens: [{ produtoId: prodId2, descricao: 'Cabo USB-C', qtd: 1, preco: 40, custo: 15 }],
      total: 40,
      formaPagamento: 'Dinheiro'
    };

    const [resSimultA, resSimultB] = await Promise.all([
      request('POST', '/api/vendas', vendaPayload2, { 'Idempotency-Key': idempotencyKey2 }),
      request('POST', '/api/vendas', vendaPayload2, { 'Idempotency-Key': idempotencyKey2 })
    ]);

    assert.strictEqual(resSimultA.status, 201);
    assert.strictEqual(resSimultB.status, 201);
    assert.strictEqual(resSimultA.body.venda.numero, resSimultB.body.venda.numero);

    const p2 = db.prepare('SELECT estoque FROM produtos WHERE id = ?').get(prodId2);
    assert.strictEqual(p2.estoque, 4, `O estoque deveria ser 4 (5 - 1). Obtido: ${p2.estoque}`);
    console.log('   ✅ PASSOU: Disparo duplo simultâneo resultou em apenas 1 baixa real de estoque.\n');

    /* --------------------------------------------------------
       TESTE 3: CONFLITO DE IDEMPOTÊNCIA (MESMA CHAVE, PAYLOAD DIFERENTE)
       Cenário: Cliente tenta reaproveitar a mesma Idempotency-Key para uma venda diferente.
       Prova: O servidor DEVE rejeitar com HTTP 422 Unprocessable Entity.
    -------------------------------------------------------- */
    console.log('▶ Teste 3: Reuso da Mesma Chave com Payload Diferente (Conflito 422)...');
    const idempotencyKey3 = crypto.randomUUID();
    const payloadOriginal = { id: 'orig_' + Date.now(), total: 100, itens: [] };
    const payloadAdulterado = { id: 'orig_' + Date.now(), total: 999, itens: [] };

    const res3A = await request('POST', '/api/vendas', payloadOriginal, {
      'Idempotency-Key': idempotencyKey3
    });
    const res3B = await request('POST', '/api/vendas', payloadAdulterado, {
      'Idempotency-Key': idempotencyKey3
    });

    assert.strictEqual(res3B.status, 422, `Esperava HTTP 422 para payload diferente com a mesma chave. Obtido: ${res3B.status}`);
    console.log('   ✅ PASSOU: Rejeitado com HTTP 422 (impossibilita colisão de parâmetros com mesma chave).\n');

    /* --------------------------------------------------------
       TESTE 4: WEBHOOK IDEMPOTENTE (RECEBIMENTO DUPLICADO DE EVENTO)
       Cenário: Gateway de pagamento reenvia o webhook de confirmação de pagamento.
       Prova: 1ª chamada grava o evento; 2ª chamada reconhece a chave única,
       responde HTTP 200 { duplicate: true } imediatamente e não repete processamento.
    -------------------------------------------------------- */
    console.log('▶ Teste 4: Webhook de Pagamento com Event ID Duplicado...');
    const eventIdPix = 'evt_pix_' + Date.now();
    const webhookPayload = {
      id: eventIdPix,
      type: 'payment.received',
      gateway: 'pix_banco',
      status: 'pago',
      valor: 150.00
    };

    // 1º Envio do Webhook
    const resWh1 = await request('POST', '/api/webhooks/pagamentos', webhookPayload);
    assert.strictEqual(resWh1.status, 200);
    assert.strictEqual(resWh1.body.ok, true);

    // 2º Envio do Mesmo Webhook
    const resWh2 = await request('POST', '/api/webhooks/pagamentos', webhookPayload);
    assert.strictEqual(resWh2.status, 200);
    assert.strictEqual(resWh2.body.duplicate, true, 'Deveria sinalizar duplicate: true na segunda entrega');

    // Validação de que existe apenas 1 evento gravado no SQLite
    const totalEventos = db.prepare('SELECT COUNT(*) as c FROM processed_webhook_events WHERE event_id = ?').get(eventIdPix).c;
    assert.strictEqual(totalEventos, 1, 'Deve existir exatamente 1 registro do evento na tabela de webhooks');
    console.log('   ✅ PASSOU: Webhook duplicado reconhecido e respondido com 200 OK sem reprocessamento.\n');

    console.log('========================================================');
    console.log('🎉 TODOS OS TESTES DE IDEMPOTÊNCIA PASSARAM COM SUCESSO!');
    console.log('========================================================\n');
  } finally {
    serverInstance.close();
  }
}

runTests().catch(err => {
  console.error('\n❌ FALHA NOS TESTES DE IDEMPOTÊNCIA:\n', err);
  if (serverInstance) serverInstance.close();
  process.exit(1);
});

