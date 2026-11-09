/* Server-backed persistence: per-record changes with optimistic conflict checks. */
(function () {
  'use strict';
  const SC = window.SC;
  const collections = ['clientes', 'produtos', 'orcamentos', 'os', 'vendas', 'users'];
  const clone = value => JSON.parse(JSON.stringify(value));
  let baseline, pending, saving = false, owner;
  SC.storage.isSQLite = true;
  SC.api = async (path, options = {}) => {
    const headers = { ...options.headers };
    if (options.body) headers['Content-Type'] = 'application/json';
    if (options.method && options.method !== 'GET') headers['X-CSRF-Token'] = SC.csrf || '';
    const response = await fetch(path, { ...options, headers, credentials: 'same-origin', cache: 'no-store' });
    const data = await response.json();
    if (!response.ok) throw Object.assign(new Error(data.error || 'Falha ao acessar o servidor.'), { status: response.status });
    return data;
  };
  function adopt(data) {
    const raw = clone(data);
    data.config = { ...SC.defaults().config, ...data.config };
    if (data.config.logo && !/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(data.config.logo)) data.config.logo = '';
    for (const key of collections) {
      const previous = SC.db?.[key] || [];
      data[key] = data[key].map(value => {
        const target = previous.find(item => item.id === value.id);
        if (!target) return value;
        for (const field of Object.keys(target)) delete target[field];
        return Object.assign(target, value);
      });
    }
    SC.db = data;
    baseline = raw;
    if (SC.user) SC.user = data.users.find(u => u.id === SC.user.id) || SC.user;
  }
  SC.load = async () => {
    if (!/^https?:$/.test(location.protocol)) throw new Error('Inicie o SmartCenter pelo arquivo iniciar.bat ou npm start.');
    SC.db ||= SC.defaults();
    // Remove old browser replicas containing credentials or customer/device data.
    try { localStorage.removeItem('smartcenter.db.v1'); sessionStorage.removeItem('smartcenter.session'); } catch {}
    try {
      const session = await SC.api('/api/auth/session');
      if (owner !== session.user.id) { pending = null; baseline = null; owner = session.user.id; }
      SC.csrf = session.csrf; SC.user = session.user;
      if (!session.user.mustChangePassword) adopt((await SC.api('/api/db')).db);
    } catch (error) {
      if (error.status !== 401) throw error;
      baseline = null; pending = null; owner = null;
      SC.user = null; SC.csrf = null; SC.db = SC.defaults(); SC.db.users = [];
    }
  };
  SC.save = async () => {
    if (saving) { SC.toast('Aguarde a gravação em andamento.', 'warn'); return false; }
    saving = true;
    try {
      if (!baseline) throw new Error('Entre no servidor antes de salvar.');
      const changedAfterFailure = pending && pending.local !== JSON.stringify(SC.db);
      if (!pending) {
        const changes = [];
        for (const entity of collections) {
          const before = baseline[entity], after = SC.db[entity];
          for (const id of new Set([...before, ...after].map(x => x.id))) {
            const old = before.find(x => x.id === id) || null, value = after.find(x => x.id === id) || null;
            if (JSON.stringify(old) !== JSON.stringify(value)) changes.push({ entity, id, before: old, after: value });
          }
        }
        for (const id of new Set([...Object.keys(baseline.config), ...Object.keys(SC.db.config)])) {
          const before = baseline.config[id] ?? null, after = SC.db.config[id] ?? null;
          const displayedBefore = Object.hasOwn(baseline.config, id) ? before : SC.defaults().config[id] ?? null;
          if (JSON.stringify(displayedBefore) !== JSON.stringify(after)) changes.push({ entity: 'config', id, before, after });
        }
        if (!changes.length) return true;
        const key = (SC.uuid ? SC.uuid() : ('key_' + Date.now() + '_' + Math.random().toString(36).slice(2)));
        pending = { body: JSON.stringify({ changes }), key, local: JSON.stringify(SC.db) };
      }
      const result = await SC.api('/api/changes', { method: 'POST', headers: { 'Idempotency-Key': pending.key }, body: pending.body });
      pending = null; adopt(result.db); SC.storage.ok = true;
      if (SC.user?.mustChangePassword) SC.boot();
      if (changedAfterFailure) { SC.toast('A gravação pendente foi recuperada. Confira os dados e salve novamente as alterações posteriores.', 'warn'); SC.refresh?.(); return false; }
      return true;
    } catch (error) {
      SC.storage.ok = false;
      // Preserve the exact request after transport failures: repeating it is safe.
      if (error.status) { pending = null; try { await SC.load(); if (!SC.user) SC.boot(); else SC.refresh?.(); } catch {} }
      SC.toast(error.status === 409 ? error.message : 'Não foi possível salvar: ' + error.message, 'err');
      return false;
    } finally { saving = false; }
  };
  SC.nextNum = () => undefined; // The server owns all sequences.
  SC.baixaEstoque = () => [];
  SC.estornaEstoque = () => {};
  SC.log = () => {}; // Audit entries are authored exclusively by the server.
  SC.restore = async data => {
    await SC.api('/api/restore', { method: 'POST', body: JSON.stringify(data) });
    baseline = null; pending = null; SC.user = null; SC.csrf = null; SC.db = SC.defaults();
    await SC.load(); SC.boot();
  };
})();
