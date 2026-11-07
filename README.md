# SmartCenter 2.0

Gestão de assistência técnica com Node.js 24+, SQLite nativo e interface em português. Não requer instalação de dependências npm.

## Windows / execução local

Execute `iniciar.bat` ou:

```powershell
npm.cmd start
```

Acesse `http://localhost:3000`. Outros computadores devem acessar o IP desse servidor e usar o mesmo banco central. Abrir `index.html` diretamente não é mais um modo de operação: ele foi removido para evitar cópias divergentes e dados sensíveis no navegador.

Em uma instalação nova, o terminal exibe a senha inicial aleatória do usuário `admin`. A troca é obrigatória antes de acessar os dados. Contas existentes mantêm seu login e senha para o primeiro acesso, também com troca obrigatória se ainda usavam o hash antigo. Senhas novas precisam ter ao menos 10 caracteres.

Para definir uma senha inicial, antes do primeiro início:

```powershell
$env:INITIAL_ADMIN_PASSWORD='uma-senha-inicial-forte'
npm.cmd start
```

Essa variável não redefine contas existentes. `DB_PATH` seleciona o arquivo SQLite; por padrão é `smartcenter.db` na raiz do projeto. `PORT` altera a porta. Sessões expiram em oito horas e são encerradas quando o servidor reinicia.

## Dados existentes e migração

Na primeira abertura de um banco anterior à versão 2, o servidor cria um backup consistente `smartcenter.db.pre-v2-<timestamp>.bak` antes de reconstruir o esquema. A migração preserva os registros e ajusta as sequências. Se houver dados incompatíveis, como documentos duplicados após remover pontuação, a migração falha e a transação preserva o esquema anterior. Corrija esses registros em uma cópia antes de tentar novamente.

Segredos de desbloqueio dos aparelhos são cifrados com AES-256-GCM. O arquivo `smartcenter.db.key` é criado ao lado do banco quando necessário. Preserve banco e chave juntos. Ao marcar a OS como entregue, PIN e padrão de desbloqueio são removidos. O navegador não mantém uma cópia persistente dos dados operacionais.

## Docker e atualização de instalação existente

Copie `.env.example` para `.env` e ajuste a URL pública e os segredos necessários. O arquivo de exemplo destina-se ao Docker Compose; na execução local, configure variáveis no terminal.

Em uma instalação nova:

```sh
docker compose up -d --build --wait --wait-timeout 90
docker compose logs smartcenter
```

A porta pública padrão é **8093**: `http://IP_DO_SERVIDOR:8093`. O serviço usa a porta 3000 dentro do container. O banco e sua chave ficam no volume nomeado **smartcenter-data**, montado em `/app/data`, e permanecem após recriar o container. O processo da aplicação roda como o usuário `node`.

**Para atualizar uma instalação antiga, use o script de implantação:**

```sh
sh scripts/deploy.sh
```

Ele constrói a imagem antes de parar o serviço, copia o banco anterior e seus arquivos WAL/chave para `backups/deploy-...`, importa os arquivos somente se o volume novo estiver vazio e exige healthcheck e verificações de acesso após iniciar. Isso cobre a versão antiga que gravava em `/app/smartcenter.db`, fora do volume configurado. Não execute somente `compose up` para migrar esse container antigo, pois isso não transfere o banco da camada do container.

O script espera o nome de container `smartcenter-app`. Para uma instalação com nome ou caminhos personalizados, faça a transferência equivalente antes de substituir o container. Não use `docker compose down -v`, pois essa opção remove o volume de dados.

Para acesso público HTTPS, configure um proxy reverso com TLS e defina `PUBLIC_ORIGIN=https://seu-dominio` e `COOKIE_SECURE=true`. Sem proxy, o sistema continua utilizável por HTTP na rede local. Não há CORS aberto; alterações exigem sessão e token CSRF.

## Backup e recuperação

Pela tela de backup, administradores podem exportar JSON e restaurar dados. O JSON inclui os hashes das contas para permitir recuperação, mas exclui PINs e padrões de aparelhos. A restauração valida relações, preserva a auditoria do servidor e encerra todas as sessões. Guarde os arquivos em local com acesso restrito.

Para um backup físico consistente, inclusive com SQLite em WAL:

```powershell
npm.cmd run backup
```

No Docker:

```sh
docker compose exec -T smartcenter node scripts/backup.js /app/data/backups
docker cp smartcenter-app:/app/data/backups ./backups-exportados
```

O comando usa `VACUUM INTO` e copia a chave quando existente. Não substitua esse procedimento pela cópia isolada de um SQLite ativo.

Para recuperar um backup físico, pare o serviço, preserve o banco atual e os arquivos `-wal`, `-shm` e `.key` em outro local e coloque o backup em `DB_PATH`. Se existir a chave correspondente ao backup, copie-a para `DB_PATH.key`. Não misture WAL de outro banco com o backup. Reinicie o serviço e valide os dados antes de liberar o acesso. Backups criados antes da migração podem precisar da versão anterior do aplicativo para investigação; a versão nova tentará migrá-los novamente.

## Pagamentos

Sem `WEBHOOK_SECRET`, o webhook responde 503 e não processa eventos. A integração é uma API genérica; nenhum gateway externo é configurado automaticamente.

1. Um usuário com permissão de configuração registra uma cobrança em `POST /api/payment-charges`, informando `id`, `gateway`, `osId` e opcionalmente `method`. O servidor fixa o valor da OS em centavos.
2. O gateway envia `POST /api/webhooks/pagamentos` com `id`, `gateway`, `chargeId`, `osId`, `status: "pago"`, `amountCents` e `currency: "BRL"`.
3. `X-Signature` deve ser o HMAC-SHA256 hexadecimal do corpo bruto, usando `WEBHOOK_SECRET`.

Evento e confirmação são gravados na mesma transação. A confirmação de pagamento não conclui o reparo nem entrega o aparelho. Erros antes do commit permitem retentativa; eventos repetidos não repetem o efeito.

## Desenvolvimento e validação

```powershell
npm.cmd test
```

Os testes usam bancos em memória ou arquivos temporários próprios. Cobrem produção pelo mesmo `server.js`, autenticação, permissões, CSRF, arquivos privados, migração e rollback, backup/restauração, concorrência, idempotência, pagamentos e persistência da interface com dois contextos de navegador simulados. Não leem o banco real do projeto.

O pipeline usa Node 24, executa essa suíte, constrói a imagem e verifica dados após recriar um container com o mesmo volume. O deploy só é informado como concluído após as verificações. Em caso de falha da migração ou do healthcheck, os backups permanecem disponíveis; recuperação de uma implantação com falha exige conferir o backup e a versão da imagem antes de reabrir o serviço.

Listagens REST suportam `limit` (até 200) e `offset` com paginação SQL. A interface atual mantém os registros permitidos em memória para busca e relatórios locais; instalações com grandes volumes podem exigir uma evolução para consultas de tela sob demanda. Alterações são enviadas por registro, com comparação da versão anterior, e nunca como substituição silenciosa de todas as tabelas.
