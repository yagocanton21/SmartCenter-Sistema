/* aparelho.js – senha do aparelho (padrão ou alfanumérica) e checklist de entrada */
(function () {
  'use strict';
  const SC = window.SC, esc = SC.esc;

  /* ---------- Checklist ---------- */
  SC.CHECK_TIPOS = ['Celular', 'Tablet'];           // tipos de aparelho que usam checklist
  SC.CHECKLIST = [
    ['liga', 'Liga'], ['tela', 'Tela / display'], ['touch', 'Touch'], ['cam_t', 'Câmera traseira'],
    ['cam_f', 'Câmera frontal'], ['alto', 'Alto-falante'], ['auric', 'Áudio de chamada'], ['mic', 'Microfone'],
    ['wifi', 'Wi-Fi'], ['bt', 'Bluetooth'], ['sinal', 'Sinal / chip'], ['bio', 'Biometria / Face ID'],
    ['botoes', 'Botões'], ['carga', 'Carregamento'], ['vibra', 'Vibração'], ['sensor', 'Sensores'],
    ['carcaca', 'Carcaça / tampa'], ['fone', 'Entrada de fone']
  ];
  const ST = [['ok', 'OK'], ['def', 'Defeito'], ['nt', 'N/T']];
  SC.usaChecklist = tipo => SC.CHECK_TIPOS.includes(tipo);

  SC.checklistHTML = (vals, obs) => {
    vals = vals || {};
    const rows = SC.CHECKLIST.map(([k, l]) => {
      const cur = vals[k] || 'nt';
      return `<div class="ck-row"><span class="ck-l">${l}</span><div class="ck-opts" role="radiogroup" aria-label="${l}">${ST.map(([v, t]) =>
        `<label class="ck-o ck-${v}"><input type="radio" name="ck_${k}" value="${v}"${cur === v ? ' checked' : ''}><span>${t}</span></label>`).join('')}</div></div>`;
    }).join('');
    return `<div class="ckbox"><div class="ck-tools"><button type="button" class="btn sm" data-ckall="ok">Marcar todos como OK</button><button type="button" class="btn sm" data-ckall="nt">Limpar (N/T)</button><span class="hint">OK = funcionando · Defeito = com problema · N/T = não testado (ex.: aparelho não liga)</span></div><div class="ck-grid">${rows}</div>
      <label class="f" style="margin-top:10px"><span>Observações do checklist</span><input name="ckObs" type="text" value="${esc(obs || '')}" placeholder="Ex.: face ID não configurado, botão volume duro"></label></div>`;
  };
  SC.bindChecklist = root => {
    root.addEventListener('click', e => {
      const b = e.target.closest('[data-ckall]'); if (!b) return;
      root.querySelectorAll(`.ck-row input[value="${b.dataset.ckall}"]`).forEach(i => { i.checked = true; });
    });
  };
  SC.readChecklist = root => {
    const o = {};
    SC.CHECKLIST.forEach(([k]) => { const c = root.querySelector(`input[name=ck_${k}]:checked`); o[k] = c ? c.value : 'nt'; });
    return o;
  };

  /* ---------- Senha do aparelho ---------- */
  const POS = n => [((n - 1) % 3) * 40 + 20, Math.floor((n - 1) / 3) * 40 + 20];   // centro de cada ponto (grade 3x3 em 120x120)
  SC.patternSVG = (seq, size, live) => {
    const pts = (seq || '').split('-').map(Number).filter(n => n >= 1 && n <= 9);
    let s = `<svg class="pat-svg" viewBox="0 0 120 120" width="${size}" height="${size}" role="img" aria-label="Padrão de desbloqueio: ${pts.join(' - ') || 'vazio'}">`;
    if (pts.length > 1) s += `<polyline points="${pts.map(n => POS(n).join(',')).join(' ')}" fill="none" stroke="#1d6fe8" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round" opacity=".85"/>`;
    for (let n = 1; n <= 9; n++) {
      const [x, y] = POS(n), i = pts.indexOf(n);
      s += `<circle cx="${x}" cy="${y}" r="${i >= 0 ? 9 : 5}" fill="${i >= 0 ? '#0b2a4a' : '#fff'}" stroke="#0b2a4a" stroke-width="1.6"/>`;
      if (i >= 0) s += `<text x="${x}" y="${y + 3.6}" text-anchor="middle" font-size="10" font-weight="700" fill="#fff" font-family="Arial,sans-serif">${i + 1}</text>`;
    }
    return s + (live ? '<rect x="0" y="0" width="120" height="120" fill="transparent"/>' : '') + '</svg>';
  };

  SC.senhaHTML = ap => {
    ap = ap || {};
    const tipo = ap.senhaTipo || (ap.senha ? 'alfa' : 'nenhuma');
    return `<div class="s9 passbox">
      <label class="f"><span>Senha do aparelho</span><select name="senhaTipo"><option value="nenhuma"${tipo === 'nenhuma' ? ' selected' : ''}>Sem senha</option><option value="padrao"${tipo === 'padrao' ? ' selected' : ''}>Padrão (desenho)</option><option value="alfa"${tipo === 'alfa' ? ' selected' : ''}>Alfanumérica (PIN / senha)</option></select></label>
      <label class="f pass-alfa" ${tipo === 'alfa' ? '' : 'hidden'}><span>PIN ou senha</span><input name="senha" type="text" value="${esc(ap.senha || '')}" autocomplete="off" placeholder="Ex.: 1234 ou Abc@2024"></label>
      <div class="pass-pad" ${tipo === 'padrao' ? '' : 'hidden'}><span class="lbl">Desenhe o padrão (arraste ou toque nos pontos)</span>
        <div class="pat-wrap"><div class="pat" id="pat">${SC.patternSVG(ap.senhaPadrao, 150, true)}</div><div class="pat-info"><b id="patTxt">${ap.senhaPadrao ? 'Sequência: ' + ap.senhaPadrao.split('-').join(' → ') : 'Nenhum ponto marcado'}</b><small>Pontos numerados de 1 a 9, da esquerda para a direita, de cima para baixo.</small><button type="button" class="btn sm" data-patclr>Limpar padrão</button></div></div>
        <input type="hidden" name="senhaPadrao" value="${esc(ap.senhaPadrao || '')}"></div></div>`;
  };

  SC.bindSenha = root => {
    const sel = root.querySelector('[name=senhaTipo]'), alfa = root.querySelector('.pass-alfa'), pad = root.querySelector('.pass-pad');
    const hid = root.querySelector('[name=senhaPadrao]'), box = root.querySelector('#pat'), txt = root.querySelector('#patTxt');
    const sync = () => { alfa.hidden = sel.value !== 'alfa'; pad.hidden = sel.value !== 'padrao'; };
    sel.addEventListener('change', sync); sync();
    let seq = hid.value ? hid.value.split('-').map(Number) : [], drawing = false;
    const draw = () => {
      hid.value = seq.join('-'); box.innerHTML = SC.patternSVG(hid.value, 150, true);
      txt.textContent = seq.length ? 'Sequência: ' + seq.join(' → ') : 'Nenhum ponto marcado';
    };
    const hit = e => {
      const svg = box.querySelector('svg'); if (!svg) return 0;
      const r = svg.getBoundingClientRect(), x = (e.clientX - r.left) / r.width * 120, y = (e.clientY - r.top) / r.height * 120;
      for (let n = 1; n <= 9; n++) { const [px, py] = POS(n); if (Math.hypot(x - px, y - py) < 14) return n; }
      return 0;
    };
    const add = n => { if (n && !seq.includes(n)) { seq.push(n); draw(); } };
    box.style.touchAction = 'none';
    box.addEventListener('pointerdown', e => { e.preventDefault(); if (!drawing && seq.length && !hit(e)) return; drawing = true; try { box.setPointerCapture(e.pointerId); } catch (x) { /* ok */ } add(hit(e)); });
    box.addEventListener('pointermove', e => { if (drawing) add(hit(e)); });
    const end = () => { drawing = false; };
    box.addEventListener('pointerup', end); box.addEventListener('pointercancel', end);
    root.querySelector('[data-patclr]').addEventListener('click', () => { seq = []; draw(); });
  };

  /* texto resumido da senha (listas e impressão) */
  SC.senhaTexto = ap => {
    ap = ap || {};
    const tipo = ap.senhaTipo || (ap.senha ? 'alfa' : 'nenhuma');
    if (tipo === 'alfa') return ap.senha ? 'Senha: ' + ap.senha : 'Sem senha informada';
    if (tipo === 'padrao') return ap.senhaPadrao ? 'Padrão: ' + ap.senhaPadrao.split('-').join(' → ') : 'Padrão não informado';
    return 'Sem senha';
  };

  /* bloco de impressão: acesso ao aparelho + checklist (compacto, cabe na mesma página da OS) */
  SC.printAparelhoExtra = o => {
    const ap = o.aparelho || {}, tipo = ap.senhaTipo || (ap.senha ? 'alfa' : 'nenhuma');
    let acesso;
    if (tipo === 'padrao' && ap.senhaPadrao) acesso = `<span>Senha – padrão</span><div class="acc-pat">${SC.patternSVG(ap.senhaPadrao, 58)}<b>${esc(ap.senhaPadrao.split('-').join(' → '))}</b></div>`;
    else acesso = `<span>Senha do aparelho</span><b>${esc(tipo === 'alfa' ? (ap.senha || '—') : (tipo === 'padrao' ? '— (padrão não informado)' : 'Sem senha'))}</b>`;
    let ck = '';
    if (o.checklist) {
      const lab = { ok: 'OK', def: 'DEFEITO', nt: 'N/T' };
      ck = `<div class="ckp"><span>Checklist de entrada</span><div class="ckp-grid">${SC.CHECKLIST.map(([k, l]) => { const v = o.checklist[k] || 'nt'; return `<div class="ckp-i ckp-${v}"><i>${esc(l)}</i><b>${lab[v]}</b></div>`; }).join('')}</div>${o.checklistObs ? `<p class="ckp-obs"><b>Obs.:</b> ${esc(o.checklistObs)}</p>` : ''}</div>`;
    }
    return `<div class="box"><div class="box-t">Acesso ao aparelho${o.checklist ? ' e checklist de entrada' : ''}</div><div class="acc-row"><div class="acc">${acesso}</div>${ck}</div></div>`;
  };
})();
