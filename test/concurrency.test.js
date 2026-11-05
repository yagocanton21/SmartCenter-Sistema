/* test/concurrency.test.js – Testes de Concorrência e Race Conditions no SQLite */
const http = require('node:http');
const assert = require('node:assert');
const app = require('../server/app');
const { getDatabase } = require('../server/db/connection');
const { initSchema } = require('../server/db/schema');

const TEST_PORT = 3999;
let serverInstance;

function request(method, path, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request({
      hostname: '127.0.0.1',
      port: TEST_PORT,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
      }
    }, res => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: data ? JSON.parse(data) : {} });
        } catch {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function runTests() {
  console.log('\n========================================================');
  console.log('🧪 INICIANDO TESTES DE RACE CONDITIONS (CONCORRÊNCIA)');
  console.log('========================================================\n');

  // Inicializa servidor de teste
  await new Promise(res => {
    serverInstance = app.listen(TEST_PORT, '127.0.0.1', res);
  });

  const db = getDatabase();
  initSchema();

  try {
    /* --------------------------------------------------------
       TESTE 1: BAIXA DE ESTOQUE CONCORRENTE
       Cenário: Produto possui apenas 1 unidade em estoque.
       Duas requisições de venda chegam no mesmo milissegundo pedindo 1 unidade cada.
       Prova: Apenas UMA venda pode ter sucesso; a outra DEVE ser rejeitada com HTTP 409.
       O estoque final DEVE ser 0, nunca negativo.
    -------------------------------------------------------- */
    console.log('▶ Teste 1: Baixa de Estoque Concorrente (1 item restante)...');
    const prodId = 'prod_test_' + Date.now();
    const prodCodigo = 'PTEST_' + Date.now();
    db.prepare(`
      INSERT INTO produtos (id, codigo, nome, preco, custo, controla, estoque, ativo, data)
      VALUES (?, ?, 'Tela iPhone 13 Pro (Última Unidade)', 500, 200, 1, 1, 1, '{}')
    `).run(prodId, prodCodigo);

    const venda1 = {
      id: 'v1_' + Date.now(),
      itens: [{ produtoId: prodId, descricao: 'Tela iPhone 13 Pro', qtd: 1, preco: 500, custo: 200 }],
      total: 500,
      formaPagamento: 'Pix'
    };
    const venda2 = {
      id: 'v2_' + Date.now(),
      itens: [{ produtoId: prodId, descricao: 'Tela iPhone 13 Pro', qtd: 1, preco: 500, custo: 200 }],
      total: 500,
      formaPagamento: 'Cartão'
    };

    // Dispara as duas vendas no mesmo milissegundo com Promise.all
    const [resVendaA, resVendaB] = await Promise.all([
      request('POST', '/api/vendas', venda1),
      request('POST', '/api/vendas', venda2)
    ]);

    const statusCodes = [resVendaA.status, resVendaB.status].sort();
    assert.deepStrictEqual(
      statusCodes,
      [201, 409],
      `Esperava que uma requisição retornasse 201 e a outra 409. Obtido: ${resVendaA.status} e ${resVendaB.status}`
    );

    const pFinal = db.prepare('SELECT estoque FROM produtos WHERE id = ?').get(prodId);
    assert.strictEqual(pFinal.estoque, 0, `O estoque final deveria ser 0, mas foi ${pFinal.estoque}`);
    console.log('   ✅ PASSOU: Apenas 1 venda foi concluída (HTTP 201). A concorrente foi bloqueada (HTTP 409).');
    console.log(`   📦 Estoque final verificado no SQLite: ${pFinal.estoque} unidade(s).\n`);

    /* --------------------------------------------------------
       TESTE 2: GERAÇÃO DE NÚMERO SEQUENCIAL CONCORRENTE
       Cenário: Dois atendentes clicam para abrir OS no mesmo milissegundo.
       Prova: Ambas as OSs recebem números estritamente diferentes e consecutivos.
    -------------------------------------------------------- */
    console.log('▶ Teste 2: Geração Atômica de Números Consecutivos de OS...');
    const os1 = {
      id: 'os1_' + Date.now(),
      clienteId: 'c1',
      aparelho: { tipo: 'Celular', marca: 'Apple', modelo: 'iPhone 12' },
      status: 'Recebido'
    };
    const os2 = {
      id: 'os2_' + Date.now(),
      clienteId: 'c2',
      aparelho: { tipo: 'Celular', marca: 'Samsung', modelo: 'S22' },
      status: 'Recebido'
    };

    const [resOs1, resOs2] = await Promise.all([
      request('POST', '/api/os', os1),
      request('POST', '/api/os', os2)
    ]);

    assert.strictEqual(resOs1.status, 200);
    assert.strictEqual(resOs2.status, 200);

    const num1 = resOs1.body.os.numero;
    const num2 = resOs2.body.os.numero;
    assert.notStrictEqual(num1, num2, `Colisão detectada! Ambas as OSs receberam o número ${num1}`);
    assert.strictEqual(Math.abs(num1 - num2), 1, `Os números deveriam ser consecutivos. Obtido: ${num1} e ${num2}`);
    console.log(`   ✅ PASSOU: OS #${num1} e OS #${num2} geradas sem colisão (números estritamente consecutivos).\n`);

    /* --------------------------------------------------------
       TESTE 3: CONSTRAINT ÚNICA CONCORRENTE (CPF/CNPJ DUPLICADO)
       Cenário: Dois atendentes tentam cadastrar o mesmo CPF no mesmo instante.
       Prova: Apenas um cliente é registrado; o segundo é rejeitado com HTTP 409 (UNIQUE constraint).
    -------------------------------------------------------- */
    console.log('▶ Teste 3: Cadastro Concorrente de Cliente com mesmo CPF...');
    const docDuplicado = '123.' + String(Date.now()).slice(-6) + '-00';
    const cli1 = { id: 'c_dup_1_' + Date.now(), nome: 'Cliente A', doc: docDuplicado };
    const cli2 = { id: 'c_dup_2_' + Date.now(), nome: 'Cliente B', doc: docDuplicado };

    const [resCli1, resCli2] = await Promise.all([
      request('POST', '/api/clientes', cli1),
      request('POST', '/api/clientes', cli2)
    ]);

    const cliStatuses = [resCli1.status, resCli2.status].sort();
    assert.deepStrictEqual(
      cliStatuses,
      [200, 409],
      `Esperava status 200 e 409. Obtido: ${resCli1.status} e ${resCli2.status}`
    );

    const totalComDoc = db.prepare('SELECT COUNT(*) as c FROM clientes WHERE doc = ?').get(docDuplicado).c;
    assert.strictEqual(totalComDoc, 1, `Esperava exatamente 1 cliente com o documento, encontrado: ${totalComDoc}`);
    console.log('   ✅ PASSOU: Apenas 1 cliente cadastrado (HTTP 200). A requisição concorrente duplicada foi rejeitada (HTTP 409).\n');

    console.log('========================================================');
    console.log('🎉 TODOS OS TESTES DE CONCORRÊNCIA PASSARAM COM SUCESSO!');
    console.log('========================================================\n');
  } finally {
    serverInstance.close();
  }
}

runTests().catch(err => {
  console.error('\n❌ FALHA NOS TESTES DE CONCORRÊNCIA:\n', err);
  if (serverInstance) serverInstance.close();
  process.exit(1);
});
