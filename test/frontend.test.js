const {start}=require('./helpers');
const fs=require('node:fs'),vm=require('node:vm'),crypto=require('node:crypto'),assert=require('node:assert/strict');
(async()=>{
  const {base,close}=await start();
  try {
    async function browser(opts = {}) {
      let cookie='',drop=false; const toasts=[];
      const storage={getItem:()=>null,setItem:()=>{throw new Error('Customer data must not be written to browser storage');},removeItem:()=>{}};
      const cryptoMock = opts.noCrypto ? undefined : (opts.noCryptoRandomUUID ? {} : crypto.webcrypto);
      const context=vm.createContext({console,crypto:cryptoMock,location:{protocol:'http:'},localStorage:storage,sessionStorage:storage,document:{},setTimeout,clearTimeout,
        fetch:async (url,options={})=>{
          const response=await fetch(base+url,{...options,headers:{...options.headers,Cookie:cookie}});
          const set=response.headers.get('set-cookie');if(set)cookie=set.split(';')[0];
          if(drop&&url==='/api/changes'){drop=false;await response.text();throw new Error('Lost response');}
          return response;
        }});
      context.window=context;
      for(const file of ['js/core.js','js/remote.js']) vm.runInContext(fs.readFileSync(file,'utf8'),context,{filename:file});
      const SC=context.SC;SC.toast=(text)=>toasts.push(text);SC.refresh=()=>{};SC.boot=()=>{};
      const login=await SC.api('/api/auth/login',{method:'POST',body:JSON.stringify({login:'admin',password:'permanent-test-password'})});
      SC.csrf=login.csrf;SC.user=login.user;await SC.load();
      return {SC,toasts,drop:()=>{drop=true;}};
    }
    const a=await browser(),b=await browser();
    a.SC.db.clientes.push({id:'client',nome:'Cliente'});
    a.SC.db.produtos.push({id:'product',codigo:'',nome:'Tela',preco:100,custo:30,estoque:10,estoqueMin:1,controla:true,ativo:true});
    a.SC.db.os.push({id:'order',clienteId:'client',status:'Concluído',pecas:[{produtoId:'product',qtd:2,valor:100}],maoDeObra:50,aparelho:{senha:'4321'}});
    assert.equal(await a.SC.save(),true);
    assert.equal(a.SC.db.os[0].total,250);assert.equal(a.SC.db.produtos[0].estoque,8);assert.equal(a.SC.db.os[0].numero,1);
    b.SC.db.config.nomeFantasia='Outra loja';
    assert.equal(await b.SC.save(),true);
    assert.equal(b.SC.db.clientes.length,1);assert.equal(b.SC.db.produtos[0].estoque,8);
    await a.SC.load();
    const client=a.SC.db.clientes[0];client.nome='Primeiro';assert.equal(await a.SC.save(),true);
    b.SC.db.clientes[0].nome='Conflito';assert.equal(await b.SC.save(),false);assert.ok(b.toasts.some(t=>t.includes('alterado')));
    a.SC.db.vendas.push({id:'sale',itens:[{produtoId:'product',qtd:1,preco:100}],data:'2026-11-06T12:00:00'});
    a.drop();assert.equal(await a.SC.save(),false);assert.equal(await a.SC.save(),true);
    assert.equal(a.SC.db.produtos[0].estoque,7);assert.equal(a.SC.db.vendas.length,1);
    // Restoring and deleting preserve server audit, not browser-authored log messages.
    assert.ok(a.SC.db.log.length>0);
    a.SC.loadDemo();assert.equal(await a.SC.save(),true);
    assert.equal(new Set(a.SC.db.produtos.map(p=>p.codigo)).size,a.SC.db.produtos.length);

    // Teste de resiliência: navegador em HTTP na rede local (sem window.crypto.randomUUID)
    const httpBrowser = await browser({ noCryptoRandomUUID: true });
    const c1 = httpBrowser.SC.upsertClient({ c_nome: 'Cliente HTTP Local', c_doc: '123.456.789-01', c_tel: '(11) 98888-7777', c_end: 'Rua Local' });
    assert.ok(c1);
    assert.equal(c1.nome, 'Cliente HTTP Local');
    assert.equal(await httpBrowser.SC.save(), true, 'Deveria salvar cliente sem crypto.randomUUID');

    // Teste de resiliência: navegador sem objeto crypto global
    const noCryptoBrowser = await browser({ noCrypto: true });
    await noCryptoBrowser.SC.load();
    const loadedC1 = noCryptoBrowser.SC.db.clientes.find(c => c.nome === 'Cliente HTTP Local');
    assert.ok(loadedC1, 'Cliente salvo via HTTP deve estar presente no banco');
    assert.equal(loadedC1.telefone, '(11) 98888-7777');

    const c1Atualizado = noCryptoBrowser.SC.upsertClient({ clienteId: loadedC1.id, c_nome: 'Cliente HTTP Atualizado', c_doc: loadedC1.doc, c_tel: '(11) 99999-0000' });
    assert.equal(c1Atualizado.nome, 'Cliente HTTP Atualizado');
    assert.equal(await noCryptoBrowser.SC.save(), true, 'Deveria atualizar cliente sem objeto crypto');

    await a.SC.load();
    assert.equal(a.SC.db.clientes.find(c => c.id === loadedC1.id).nome, 'Cliente HTTP Atualizado');

    // Teste de fluxo completo de OS em navegador HTTP (baixa de estoque atômica)
    const prodRef = httpBrowser.SC.db.produtos.find(p => p.controla && p.estoque > 0);
    assert.ok(prodRef, 'Deve haver produto com estoque controlado');
    const estoqueAntes = prodRef.estoque;
    httpBrowser.SC.db.os.push({
      id: httpBrowser.SC.uid(),
      clienteId: loadedC1.id,
      status: 'Concluído',
      pecas: [{ produtoId: prodRef.id, qtd: 1, valor: prodRef.preco }],
      maoDeObra: 80,
      aparelho: { tipo: 'Celular', marca: 'Apple', modelo: 'iPhone 13', senha: '123' }
    });
    assert.equal(await httpBrowser.SC.save(), true, 'Deveria salvar OS em navegador HTTP');
    assert.equal(httpBrowser.SC.db.produtos.find(p => p.id === prodRef.id).estoque, estoqueAntes - 1, 'Deveria baixar estoque da OS');

    // Teste de fluxo de Venda e estorno por cancelamento em navegador sem crypto
    await noCryptoBrowser.SC.load();
    const estoqueProd = noCryptoBrowser.SC.db.produtos.find(p => p.id === prodRef.id).estoque;
    const vendaId = noCryptoBrowser.SC.uid();
    noCryptoBrowser.SC.db.vendas.push({
      id: vendaId,
      clienteId: loadedC1.id,
      data: '2026-11-09T10:00:00',
      status: 'Concluída',
      itens: [{ produtoId: prodRef.id, qtd: 1, preco: 100 }],
      descontoTipo: 'valor',
      descontoValor: 10,
      desconto: 10,
      subtotal: 100,
      total: 90
    });
    assert.equal(await noCryptoBrowser.SC.save(), true, 'Deveria salvar venda sem crypto');
    assert.equal(noCryptoBrowser.SC.db.produtos.find(p => p.id === prodRef.id).estoque, estoqueProd - 1, 'Estoque deve ser baixado pela venda');

    // Cancelamento da venda com devolução de estoque
    const vendaCadastrada = noCryptoBrowser.SC.db.vendas.find(v => v.id === vendaId);
    vendaCadastrada.status = 'Cancelada';
    assert.equal(await noCryptoBrowser.SC.save(), true, 'Deveria cancelar venda');
    assert.equal(noCryptoBrowser.SC.db.produtos.find(p => p.id === prodRef.id).estoque, estoqueProd, 'Estoque deve ser estornado');

    console.log('OK: persistência da interface sem localStorage, cliente/produto/OS atômicos, dois navegadores, conflitos, resposta perdida, repetição e demonstração.');
  } finally {await close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
