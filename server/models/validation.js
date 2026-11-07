function number(value, name, min = 0, max = 1e9) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) throw new Error(`${name} inválido.`);
  return value;
}
const round = n => Math.round((n + Number.EPSILON) * 100) / 100;
function lines(items, priceField) {
  if (!Array.isArray(items) || items.length > 500) throw new Error('Itens inválidos.');
  let sum = 0;
  for (const item of items) { number(item.qtd, 'Quantidade', 0.000001, 1e6); number(item[priceField], 'Preço', 0); sum += item.qtd * item[priceField]; }
  return number(round(sum), 'Total');
}
function id(value) { if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(value)) throw new Error('ID inválido.'); return value; }
function dates(value, fields) {
  for (const field of fields) if (value[field] != null && value[field] !== '' && (typeof value[field] !== 'string' || !/^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d{3})?)?(Z|[+-]\d{2}:\d{2})?)?$/.test(value[field]) || Number.isNaN(Date.parse(value[field])))) throw new Error(`Data inválida: ${field}.`);
}
module.exports = { number, round, lines, id, dates };
