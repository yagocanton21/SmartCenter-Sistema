const {start}=require('./helpers');
const fs=require('node:fs'),vm=require('node:vm'),crypto=require('node:crypto'),assert=require('node:assert/strict');
(async()=>{
  const {base,close}=await start();
  try {
    async function browser() {
      let cookie='',drop=false; const toasts=[];
      const storage={getItem:()=>null,setItem:()=>{throw new Error('Customer data must not be written to browser storage');},removeItem:()=>{}};
      const context=vm.createContext({console,crypto:crypto.webcrypto,location:{protocol:'http:'},localStorage:storage,sessionStorage:storage,document:{},setTimeout,clearTimeout,
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
    console.log('OK: persistência da interface sem localStorage, cliente/produto/OS atômicos, dois navegadores, conflitos, resposta perdida, repetição e demonstração.');
  } finally {await close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
