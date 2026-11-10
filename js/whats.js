/* whats.js – compartilhamento por WhatsApp da Ordem de Serviço e da Nota de Serviço.
   Abre o WhatsApp (app ou web) com a conversa do cliente e a mensagem pronta para revisar. */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc, icon = SC.icon;
  const FIM = ['Concluído', 'Entregue'];

  const loja = () => SC.db.config;
  const rodape = () => {
    const c = loja(), tel = c.whatsapp || c.telefone;
    return `\n\n*${c.nomeFantasia}*${tel ? '\nTel/WhatsApp: ' + tel : ''}${c.endereco ? '\n' + [c.endereco, c.cidade].filter(Boolean).join(' – ') : ''}`;
  };
  const aparelhoTxt = o => { const a = o.aparelho || {}; return [a.tipo, a.marca, a.modelo].filter(Boolean).join(' ') || 'aparelho'; };
  const primeiroNome = c => String(c.nome || '').trim().split(/\s+/)[0] || 'cliente';
  const linhasPecas = o => (o.pecas || []).filter(p => p.descricao).map(p => `• ${p.descricao}${Number(p.qtd) > 1 ? ' (x' + p.qtd + ')' : ''}`).join('\n');

  /* ---- modelos de mensagem da OS ---- */
  const MODELOS_OS = {
    abertura: ['Recebimento do aparelho (abertura da OS)', o => {
      const a = o.aparelho || {};
      return `Olá, ${primeiroNome(SC.cliOf(o))}! Recebemos seu aparelho na *${loja().nomeFantasia}*.\n\n*Ordem de Serviço nº ${SC.pad(o.numero)}*\nData de entrada: ${SC.fmtDate(o.dataEntrada)}\nAparelho: ${aparelhoTxt(o)}${a.imei ? '\nIMEI/Série: ' + a.imei : ''}\nDefeito relatado: ${a.defeito || '—'}${o.prazo ? '\nPrazo previsto: ' + SC.fmtDate(o.prazo) : ''}\n\nAssim que tivermos o diagnóstico, avisaremos por aqui. Guarde o número da OS para acompanhar seu atendimento.`;
    }],
    status: ['Atualização de status', o => `Olá, ${primeiroNome(SC.cliOf(o))}! Atualização do seu atendimento na *${loja().nomeFantasia}*:\n\n*OS nº ${SC.pad(o.numero)}* – ${aparelhoTxt(o)}\nStatus atual: *${o.status}*${o.prazo && !FIM.includes(o.status) ? '\nPrazo previsto: ' + SC.fmtDate(o.prazo) : ''}${o.diagnostico ? '\nDiagnóstico: ' + o.diagnostico : ''}\n\nQualquer dúvida, é só responder esta mensagem.`],
    aprovacao: ['Orçamento para aprovação', o => `Olá, ${primeiroNome(SC.cliOf(o))}! Concluímos a análise do seu ${aparelhoTxt(o)} (*OS nº ${SC.pad(o.numero)}*).\n\nDiagnóstico: ${o.diagnostico || '—'}${linhasPecas(o) ? '\n\nPeças:\n' + linhasPecas(o) : ''}\n\nMão de obra: ${SC.money(o.maoDeObra)}\nPeças: ${SC.money(o.valorPecas)}\n*Total: ${SC.money(o.total)}*${o.prazo ? '\nPrazo de entrega: ' + SC.fmtDate(o.prazo) : ''}\n\nPodemos aprovar o serviço? Responda *SIM* para autorizar o reparo.`],
    pronto: ['Aparelho pronto para retirada', o => `Olá, ${primeiroNome(SC.cliOf(o))}! Boa notícia: seu ${aparelhoTxt(o)} está *pronto para retirada* (OS nº ${SC.pad(o.numero)}).\n\nValor total: *${SC.money(o.total)}*${o.formaPagamento ? '\nForma de pagamento: ' + o.formaPagamento : ''}\n\nPara retirar, leve um documento com foto.`]
  };
  const modeloInicial = o => o.status === 'Aguardando aprovação' ? 'aprovacao' : (o.status === 'Concluído' ? 'pronto' : (o.status === 'Recebido' ? 'abertura' : 'status'));

  /* ---- mensagem da Nota de Serviço ---- */
  const msgNota = o => {
    const g = SC.notaInfo(o), c = SC.cliOf(o);
    return `Olá, ${primeiroNome(c)}! Segue o resumo da sua *Nota de Serviço nº ${SC.pad(o.numero)}* (ref. OS ${SC.pad(o.numero)}) – *${loja().nomeFantasia}*.\n\nAparelho: ${aparelhoTxt(o)}${(o.servico || o.diagnostico) ? '\nServiço realizado: ' + (o.servico || o.diagnostico) : ''}${linhasPecas(o) ? '\nPeças utilizadas:\n' + linhasPecas(o) : ''}\n\nMão de obra: ${SC.money(o.maoDeObra)}\nPeças: ${SC.money(o.valorPecas)}\n*Total: ${SC.money(o.total)}*${o.formaPagamento ? '\nPagamento: ' + o.formaPagamento : ''}\n\n*Garantia:* ${g.dias > 0 ? g.dias + ' dias' + (g.ate ? ', válida até ' + SC.fmtDate(g.ate) : '') : 'sem garantia'}\nO Termo de Garantia acompanha a nota impressa. Guarde-o para acionar a garantia.\n\nObrigado pela confiança!`;
  };

  /* ---- janela de compartilhamento ---- */
  function abrir({ titulo, o, modelos, nota }) {
    const c = SC.cliOf(o), fone = (SC.byId('clientes', o.clienteId) || {}).whatsapp || c.whatsapp || c.telefone || '';
    const first = nota ? null : modeloInicial(o);
    const m = SC.modal({
      title: `${icon('whats', 18)} ${titulo}`, size: 'md',
      body: `<form class="grid" onsubmit="return false">
        <label class="f s12"><span>WhatsApp do cliente</span><input name="fone" type="tel" inputmode="tel" data-mask="tel" value="${esc(fone)}" placeholder="(11) 90000-0000"></label>
        ${nota ? '' : `<label class="f s12"><span>Modelo da mensagem</span><select name="modelo">${Object.entries(MODELOS_OS).map(([k, v]) => `<option value="${k}"${k === first ? ' selected' : ''}>${v[0]}</option>`).join('')}</select></label>`}
        <label class="f s12"><span>Mensagem (você pode editar antes de enviar)</span><textarea name="msg" rows="13"></textarea></label>
        <p class="hint s12">O WhatsApp não anexa arquivos por link. Para enviar o documento em PDF, use <b>${nota ? 'Imprimir nota / PDF' : 'Imprimir OS / PDF'}</b>, escolha “Salvar como PDF” e anexe o arquivo na conversa.</p>
      </form>`,
      footer: `<button type="button" class="btn" data-close>Fechar</button><button type="button" class="btn" data-doc>${icon('print', 16)} ${nota ? 'Imprimir nota / PDF' : 'Imprimir OS / PDF'}</button><button type="button" class="btn" data-copy>Copiar mensagem</button><button type="button" class="btn primary wa-btn" data-send>${icon('whats', 16)} Abrir WhatsApp</button>`
    });
    const b = m.body, ta = b.querySelector('[name=msg]'), sel = b.querySelector('[name=modelo]');
    const fill = () => { ta.value = (nota ? msgNota(o) : MODELOS_OS[sel.value][1](o)) + rodape(); };
    fill(); if (sel) sel.addEventListener('change', fill);
    const root = m.el;
    root.addEventListener('click', async e => {
      if (e.target.closest('[data-doc]')) { nota ? SC.print.nota(o.id) : SC.print.os(o.id); return; }
      if (e.target.closest('[data-copy]')) {
        try { await navigator.clipboard.writeText(ta.value); SC.toast('Mensagem copiada.'); }
        catch (x) { ta.select(); document.execCommand('copy'); SC.toast('Mensagem copiada.'); }
        return;
      }
      if (e.target.closest('[data-send]')) {
        const base = SC.wa(b.querySelector('[name=fone]').value) || 'https://wa.me/';
        const w = window.open(base + '?text=' + encodeURIComponent(ta.value), '_blank', 'noopener');
        if (!w) SC.toast('O navegador bloqueou a nova janela. Permita pop-ups ou use “Copiar mensagem”.', 'warn');
        else if (base === 'https://wa.me/') SC.toast('Sem número cadastrado: escolha o contato no WhatsApp.', 'warn');
        SC.log('os', `${nota ? 'Nota' : 'OS'} #${SC.pad(o.numero)} compartilhada por WhatsApp`);
      }
    });
  }

  SC.whats = {
    os(id) { const o = SC.byId('os', id); if (o) abrir({ titulo: `Enviar OS nº ${SC.pad(o.numero)} por WhatsApp`, o }); },
    nota(id) {
      const o = SC.byId('os', id); if (!o) return;
      if (!FIM.includes(o.status)) return SC.toast('A Nota de Serviço só pode ser enviada depois que a manutenção estiver Concluída.', 'warn');
      abrir({ titulo: `Enviar Nota de Serviço nº ${SC.pad(o.numero)} por WhatsApp`, o, nota: true });
    }
  };
})();
