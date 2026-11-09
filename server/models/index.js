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
      versao: 2,
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
  getFullDatabase
};

