/* server/models/index.js – Exportação centralizada dos Models e operações atômicas */
const { getDatabase } = require('../db/connection');
const StoreConfig = require('./StoreConfig');
const Usuario = require('./Usuario');
const Cliente = require('./Cliente');
const Produto = require('./Produto');
const OS = require('./OS');
const Orcamento = require('./Orcamento');
const Venda = require('./Venda');
const Log = require('./Log');
const Idempotency = require('./Idempotency');

function getFullDatabase() {
  const config = StoreConfig.getConfig();
  const seq = StoreConfig.getSequences();
  const users = Usuario.getAll();
  const clientes = Cliente.getAll();
  const produtos = Produto.getAll();
  const osList = OS.getAll();
  const orcamentos = Orcamento.getAll();
  const vendas = Venda.getAll();
  const log = Log.getAll();

  const hasData = users.length > 0 || clientes.length > 0 || osList.length > 0 || Object.keys(config).length > 0;

  return {
    hasData,
    db: {
      versao: 1,
      criadoEm: config._criadoEm || new Date().toISOString(),
      config,
      seq,
      users,
      clientes,
      produtos,
      os: osList,
      orcamentos,
      vendas,
      log
    }
  };
}

function saveFullDatabase(fullDb) {
  if (!fullDb || typeof fullDb !== 'object') throw new Error('Dados inválidos para persistência.');
  const db = getDatabase();

  db.exec('BEGIN TRANSACTION;');
  try {
    if (fullDb.config) StoreConfig.saveConfig(fullDb.config);
    if (fullDb.seq) StoreConfig.saveSequences(fullDb.seq);
    if (fullDb.users) Usuario.saveAll(fullDb.users);
    if (fullDb.clientes) Cliente.saveAll(fullDb.clientes);
    if (fullDb.produtos) Produto.saveAll(fullDb.produtos);
    if (fullDb.os) OS.saveAll(fullDb.os);
    if (fullDb.orcamentos) Orcamento.saveAll(fullDb.orcamentos);
    if (fullDb.vendas) Venda.saveAll(fullDb.vendas);
    if (fullDb.log) Log.saveAll(fullDb.log);

    db.exec('COMMIT;');
    return true;
  } catch (err) {
    db.exec('ROLLBACK;');
    throw err;
  }
}

module.exports = {
  StoreConfig,
  Usuario,
  Cliente,
  Produto,
  OS,
  Orcamento,
  Venda,
  Log,
  Idempotency,
  getFullDatabase,
  saveFullDatabase
};

