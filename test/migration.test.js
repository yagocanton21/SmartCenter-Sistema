const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { DatabaseSync } = require('node:sqlite');
const { execFileSync, spawn } = require('node:child_process');
const directory = fs.mkdtempSync(path.join(os.tmpdir(),'smartcenter-migration-'));
const database = path.join(directory,'smartcenter.db');
const env = {...process.env,DB_PATH:database,INITIAL_ADMIN_PASSWORD:'migration-test-password',PORT:'0'};
function createLegacy(file, duplicate = false) {
  const db = new DatabaseSync(file);
  db.exec(`CREATE TABLE config(key TEXT PRIMARY KEY,value TEXT); CREATE TABLE seq(name TEXT PRIMARY KEY,val INTEGER);
    CREATE TABLE users(id TEXT PRIMARY KEY,login TEXT UNIQUE,data TEXT);
    CREATE TABLE clientes(id TEXT PRIMARY KEY,nome TEXT,doc TEXT,telefone TEXT,data TEXT);
    CREATE TABLE produtos(id TEXT PRIMARY KEY,codigo TEXT,nome TEXT,ativo INTEGER,data TEXT);
    CREATE TABLE os(id TEXT PRIMARY KEY,numero INTEGER,data TEXT);
    CREATE TABLE orcamentos(id TEXT PRIMARY KEY,numero INTEGER,data TEXT);
    CREATE TABLE vendas(id TEXT PRIMARY KEY,numero INTEGER,data TEXT); CREATE TABLE logs(id TEXT PRIMARY KEY,data TEXT);`);
  const p={id:'legacy-product',codigo:'P001',nome:'Peça',preco:100,custo:20,estoque:7,controla:true,ativo:true};
  db.prepare('INSERT INTO produtos VALUES(?,?,?,?,?)').run(p.id,p.codigo,p.nome,1,JSON.stringify(p));
  const o={id:'legacy-order',numero:42,status:'Recebido',pecas:[],aparelho:{senha:'legacy-secret-pin'}};
  db.prepare('INSERT INTO os VALUES(?,?,?)').run(o.id,o.numero,JSON.stringify(o));
  if (duplicate) for (const [id,doc] of [['a','123.456.789-00'],['b','12345678900']]) db.prepare('INSERT INTO clientes VALUES(?,?,?,?,?)').run(id,id,doc,'',JSON.stringify({id,nome:id,doc}));
  db.close();
}
async function launch() {
  const child=spawn(process.execPath,['server.js'],{env,stdio:['ignore','pipe','pipe']});
  const address=await new Promise((resolve,reject)=>{
    let output=''; const timer=setTimeout(()=>{child.kill();reject(new Error('Servidor não iniciou: '+output));},10000);
    child.stdout.on('data',chunk=>{output+=chunk;const match=output.match(/http:\/\/localhost:(\d+)/);if(match){clearTimeout(timer);resolve('http://127.0.0.1:'+match[1]);}});
    child.stderr.on('data',chunk=>{output+=chunk;});
    child.on('exit',code=>{clearTimeout(timer);reject(new Error('Servidor saiu: '+code+' '+output));});
  });
  return {child,address,stop:()=>new Promise(resolve=>{child.once('exit',resolve);child.kill();})};
}
(async()=>{
  try {
    createLegacy(database);
    execFileSync(process.execPath,['-e',"require('./server/app')"],{env,stdio:'pipe'});
    assert.ok(fs.readdirSync(directory).some(f=>f.includes('.pre-v2-')));
    let db=new DatabaseSync(database);
    assert.equal(db.prepare('PRAGMA user_version').get().user_version,2);
    assert.equal(db.prepare('SELECT estoque FROM produtos').get().estoque,7);
    assert.equal(db.prepare("SELECT val FROM seq WHERE name='os'").get().val,42);
    assert.ok(!db.prepare('SELECT data FROM os').get().data.includes('legacy-secret-pin'));
    db.close();
    for(let i=0;i<2;i++) {
      const running=await launch();
      try { assert.equal((await fetch(running.address+'/api/status')).status,200); }
      finally {await running.stop();}
    }
    execFileSync(process.execPath,['scripts/backup.js',directory],{env,stdio:'pipe'});
    const backup=fs.readdirSync(directory).find(f=>/^smartcenter-\d/.test(f)&&f.endsWith('.db'));
    assert.ok(backup); assert.ok(fs.existsSync(path.join(directory,backup+'.key')));
    db=new DatabaseSync(path.join(directory,backup),{readOnly:true});
    assert.equal(db.prepare('PRAGMA integrity_check').get().integrity_check,'ok'); db.close();
    const broken=path.join(directory,'duplicates.db'); createLegacy(broken,true);
    assert.throws(()=>execFileSync(process.execPath,['-e',"require('./server/app')"],{env:{...env,DB_PATH:broken},stdio:'pipe'}));
    db=new DatabaseSync(broken);
    assert.equal(db.prepare('SELECT count(*) n FROM clientes').get().n,2);
    assert.ok(!db.prepare('PRAGMA table_info(produtos)').all().some(c=>c.name==='estoque')); db.close();
    console.log('OK: migração legada, backup prévio, rollback de migração, criptografia, sequência, inicialização real, reinício e backup consistente.');
  } finally {
    const resolved=path.resolve(directory), root=path.resolve(os.tmpdir())+path.sep;
    if (!resolved.startsWith(root) || !path.basename(resolved).startsWith('smartcenter-migration-')) throw new Error('Diretório temporário inesperado.');
    for(const file of fs.readdirSync(resolved)) fs.unlinkSync(path.join(resolved,file));
    fs.rmdirSync(resolved);
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
