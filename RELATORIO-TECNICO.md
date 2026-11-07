# Relatório técnico — SmartCenter

Data: 06/11/2026. Análise do código presente no diretório do projeto.

## Atualização após as correções — 06/11/2026

O restante deste documento registra o diagnóstico original. As correções agora estão implementadas no código:

- Servidor único para execução, testes e Docker; `DB_PATH` respeitado.
- Migração com backup prévio, rollback e preservação de sequências.
- Sessões HttpOnly, CSRF, permissões no backend, senhas scrypt com salt e troca inicial obrigatória.
- Publicação restrita aos arquivos de interface; banco e backend não são servidos.
- Alterações por registro, conflitos explícitos e confirmação de gravação pela interface.
- Cadastros vinculados à operação, numeração no servidor, cálculo de totais, validação e reconciliação de estoque.
- Webhook desabilitado sem segredo, cobrança validada e processamento transacional.
- Segredos de aparelhos cifrados, sem réplica no localStorage, removidos na entrega e omitidos do backup JSON.
- Auditoria no servidor, listagens REST com paginação SQL e healthcheck sem snapshot completo.
- Backup físico consistente, documentação e implantação com transferência do banco legado e verificações de saúde.

Validação local: cinco grupos de testes automatizados aprovados, incluindo inicialização pelo ponto de entrada de produção, migração/rollback, reinício, backup/restauração, segurança e persistência da interface em contextos de navegador simulados. Os testes não abrem o banco real do projeto.

Limites da validação: o build Docker não pôde ser executado porque o Docker Desktop/daemon Linux não está iniciado neste computador. As verificações da imagem e da recriação com volume foram incluídas no pipeline, mas ainda precisam executar nesse ambiente. Não houve implantação na VPS nem inspeção visual em navegador real. A interface continua mantendo os registros autorizados em memória; consultas de tela sob demanda ficam como evolução de escala, sem substituir o banco ou framework.

Consulte `README.md` para o novo primeiro acesso e para a migração de um container antigo antes de substituí-lo.

## Parecer

O SmartCenter possui um conjunto funcional abrangente para uma assistência técnica pequena, mas apresenta falhas críticas de integração, proteção dos dados e persistência. A versão analisada precisa dessas correções antes de ser disponibilizada diretamente na internet ou usada como fonte confiável por vários atendentes.

O problema estrutural mais importante é a existência de dois servidores: a inicialização e o Docker usam `server.js`, enquanto os testes usam `server/app.js`. Recursos transacionais e de idempotência implementados no segundo não estão ligados ao primeiro.

## Escopo e limitações

- Inspeção de frontend, ambos os servidores, modelos, esquema SQLite, testes, Docker, configuração e pipeline.
- Execução dos sete cenários existentes com `DB_PATH=:memory:`, usando Node v24.22.0 e `npm.cmd test`.
- Verificações adicionais dos modelos com banco em memória para quantidades negativas e edição de peças em OS concluída.
- Não foi iniciado o servidor legado, pois ele ignora `DB_PATH` e abriria o banco real do projeto.
- Não foram inspecionados os registros do banco existente, nem acessada a VPS. Não houve validação visual em navegador ou execução de Docker.
- Os riscos da implantação foram inferidos dos arquivos locais; não representam uma auditoria da infraestrutura externa.

## Produto e arquitetura

O sistema inclui painel, clientes, produtos e estoque, vendas, orçamentos, ordens de serviço, checklist de entrada, registro de desbloqueio do aparelho, impressão, configurações da loja, usuários e backup/restauração.

| Camada | Implementação |
|---|---|
| Interface | HTML, CSS e JavaScript sem framework, namespace global `SC` |
| Estado do navegador | Objetos em memória, localStorage e sessionStorage |
| Backend iniciado | `server.js`, HTTP nativo, API de snapshots |
| Backend modular | `server/app.js`, rotas e modelos por entidade |
| Banco | SQLite nativo de Node, WAL, parte dos campos em JSON |
| Distribuição | Inicializador Windows, Docker Compose e GitHub Actions |
| Dependências | Nenhuma dependência npm declarada |

O backend modular é uma direção útil de organização. Hoje, porém, existem regras duplicadas entre navegador, servidor legado e modelos novos, com comportamentos diferentes.

## Achados prioritários

### 1. Crítico — servidor implantado diferente do servidor testado

Evidências: `package.json` executa `node server.js`; `iniciar.bat` e o `Dockerfile` também. Os dois arquivos de teste importam `../server/app`.

O servidor legado atende `/api/status`, `/api/db` e `/api/save`, mas não implementa `/api/vendas` e `/api/os`. A interface detecta SQLite e tenta usar essas rotas ao salvar vendas e OS. No caminho padrão de inicialização, essas requisições caem no servidor estático e retornam 404 quando o arquivo correspondente não existe. Portanto, esses fluxos ficam quebrados apesar dos testes aprovados.

Correção: consolidar a inicialização em um único backend e testar exatamente o comando usado no Docker e no Windows.

### 2. Crítico — volume Docker não recebe o banco efetivamente usado

O Compose monta `./data:/app/data` e define `DB_PATH=/app/data/smartcenter.db`. Entretanto, `server.js:10` fixa o banco em `path.join(__dirname, 'smartcenter.db')`, isto é, `/app/smartcenter.db` no container.

Os dados ficam na camada gravável do container, fora do volume previsto. Recriar o container pode perder os dados, e copiar `./data/smartcenter.db` não protege o banco efetivamente usado por esse servidor.

Correção: respeitar a configuração central de caminho, verificar a persistência após recriação e definir procedimento de backup/restauração.

### 3. Crítico — API sem autenticação e autorização

Ambos os servidores permitem ler `/api/db` e gravar `/api/save` sem validar sessão, usuário ou permissão. Login e perfis são controlados em `js/app.js` e `js/core.js`, no navegador. O snapshot inclui usuários com seus hashes e dados de clientes e aparelhos.

Qualquer cliente com acesso de rede ao serviço pode consultar ou substituir informações sem passar pela tela de login. O CORS permissivo amplia a superfície de acesso pelo navegador.

Correção: autenticação no servidor, sessões seguras e autorização por operação. Retirar hashes das respostas comuns e restringir importação/restauração a administradores autenticados.

### 4. Crítico — arquivos privados publicados como arquivos estáticos

`server.js` e `server/routes/static.js` servem arquivos a partir da raiz do projeto, verificando apenas se o caminho corresponde a um arquivo interno. Não há lista explícita de diretórios públicos.

Isso permite baixar arquivos internos conhecidos, incluindo código do servidor. No backend legado, `/smartcenter.db` aponta para o banco real. No backend modular em Docker, o caminho configurado também fica sob a raiz, em `/data/smartcenter.db`. Outros arquivos presentes nessa raiz, como `.env`, podem igualmente ficar acessíveis.

Correção: publicar exclusivamente os arquivos de interface necessários e manter banco, configurações e código de backend fora da raiz pública.

### 5. Alto — snapshots podem apagar alterações de outro atendente

`SC.storage.write()` dispara `saveSQLite()` com todo o estado local. Os métodos `saveAll()` removem e recriam registros; o servidor legado usa o mesmo padrão. Não existe controle de versão do snapshot.

Exemplo: dois atendentes carregam os dados; um cadastra um cliente; o segundo salva uma configuração usando sua cópia antiga. A gravação posterior pode excluir o cliente recém-criado e restaurar saldos ou sequências antigos. A transação SQLite torna a gravação indivisível, mas não resolve esse conflito lógico.

Correção: usar operações por entidade, controle de versão para edições concorrentes e reservar snapshots para restauração explícita.

### 6. Alto — confirmação de salvamento não garante persistência

`SC.storage.write()` não aguarda a gravação remota. Seu retorno pode indicar sucesso porque o navegador conseguiu salvar localmente ou porque o modo SQLite está ativo, mesmo quando `/api/save` falha. A interface pode anunciar sucesso sem que os dados tenham chegado ao servidor.

Correção: aguardar a confirmação da API e apresentar estados de salvamento, falha e sincronização pendente.

### 7. Alto — integração parcial entre cadastros, numeração e API modular

A interface cria números com `SC.nextNum()` antes de chamar a API. Os modelos só geram a sequência quando o número não vem informado. Assim, o uso real pode colidir entre navegadores, embora os testes de sequência passem ao enviar objetos sem número.

Além disso, vendas e OS criam/alteram clientes localmente com `SC.upsertClient()`, enviam somente a venda/OS e depois executam `SC.load()`. Essas alterações de cliente ainda não persistidas podem ser descartadas pelo recarregamento. Há também vínculos de orçamento e logs tratados apenas no estado local nesses fluxos.

Correção: números gerados pelo servidor e operações transacionais que incluam os cadastros e vínculos necessários.

### 8. Alto — validação insuficiente de estoque e valores no servidor modular

`Produto.baixarEstoqueAtomico()` aceita quantidade negativa. Em verificação isolada, uma venda com `qtd=-2` alterou estoque de 10 para 12 e foi registrada. Totais, preços e custos são aceitos do cliente sem recomposição central. Produtos sem controle também têm o saldo alterado pelo SQL atual.

Correção: validar tipos, quantidades positivas, existência/atividade de produtos e limites de valores; calcular totais no servidor e tratar produtos sem controle explicitamente.

### 9. Alto — edição de OS concluída não reconcilia peças

`OS.salvarOSTransacional()` considera a marca `estoqueBaixado`, mas não calcula diferenças quando uma OS continua concluída e suas peças mudam.

Reprodução em memória: estoque inicial 10; conclusão usando uma peça resulta em 9; alteração da mesma OS para três peças mantém 9 e a baixa registrada continua em uma peça. O saldo esperado seria 7.

Correção: reconciliar a baixa anterior com a lista atual dentro da mesma transação e centralizar as transições de status no servidor.

### 10. Alto — webhook pode aceitar eventos sem assinatura e perder retentativas

`Idempotency.verifyWebhookSignature()` aceita qualquer assinatura quando `WEBHOOK_SECRET` está ausente. O Compose e o exemplo de ambiente não configuram esse segredo.

A rota registra o evento antes de aplicar sua alteração à OS, em operações separadas. Se o processamento falhar depois do registro, a retentativa é respondida como duplicada e não reaplica o efeito. A confirmação também não valida valor ou moeda contra uma cobrança registrada.

Este achado se aplica ao backend modular; a rota de webhook não está ligada ao servidor legado iniciado atualmente.

Correção: exigir segredo configurado, validar a cobrança e tornar registro e efeito uma unidade transacional ou usar estados de processamento com retentativas.

### 11. Médio — proteção de credenciais e informações sensíveis insuficiente

`SC.hash()` é um hash próprio, rápido e sem salt individual; a conta padrão é `admin/admin`. A sessão depende de um identificador em sessionStorage. PINs e padrões de desbloqueio são armazenados no objeto do aparelho e replicados com os snapshots.

Correção: derivação de senha no servidor com algoritmo apropriado, troca inicial obrigatória, sessões controladas pelo backend e acesso/retenção específicos para segredos de aparelhos.

### 12. Médio — robustez operacional e manutenção

- O parsing de URL usa `decodeURIComponent()` fora de tratamento de erro. URLs malformadas podem gerar exceção não tratada.
- O esquema modular não inclui uma migração completa das tabelas legadas. Por exemplo, produtos antigos não recebem automaticamente todas as novas colunas de estoque e preço.
- Healthchecks carregam o snapshot inteiro, aumentando trabalho com o crescimento dos dados.
- Listagens e inicialização transferem coleções inteiras; a paginação visual não limita consultas e tráfego.
- Campos de negócio duplicados em colunas e JSON exigem cuidado para evitar divergência.
- Logs são manipuláveis pelo cliente e não constituem trilha de auditoria confiável.
- O pipeline inicia a implantação após testes de outro backend e não exige confirmação de saúde funcional ou restauração de backup.
- A documentação informa acesso pela porta 3000, enquanto o Compose publica 8093 por padrão.
- Copiar apenas o arquivo principal de um SQLite ativo em WAL não é um procedimento de backup validado; é necessário um snapshot consistente ou parada controlada.

## Pontos positivos

- Escopo funcional alinhado à operação de assistência técnica.
- Organização da interface por módulos e funções compartilhadas.
- Backend modular separa configuração, banco, rotas e modelos.
- Uso de parâmetros SQL nos modelos analisados.
- Transações para venda, cancelamento e OS no backend modular.
- Restrições de unicidade e de estoque no esquema novo.
- Idempotência de venda/OS registrada na mesma transação da operação.
- Baixa quantidade de dependências facilita distribuição e manutenção.
- Há testes automatizados, pipeline, healthcheck e configuração de volume, embora a integração precise ser corrigida.

## Validação executada

Os sete cenários existentes passaram: disputa pela última unidade, sequência de OS, documento duplicado, repetição de venda com mesma chave, chamadas simultâneas com mesma chave, conflito de payload e evento de webhook repetido.

Esses resultados se restringem ao backend modular em um único processo e banco em memória. Não comprovam funcionamento do servidor iniciado por `npm start`, integração da interface, persistência Docker, autenticação ou recuperação após falhas de pagamento. Os testes atuais também não isolam o banco automaticamente: sem definir `DB_PATH`, abrem o caminho padrão e inserem registros nele.

As duas verificações adicionais confirmaram os defeitos de quantidade negativa e edição de peças de OS concluída. Não foram executados testes contra dados reais.

## Ordem recomendada de trabalho

1. **Corrigir a execução e preservar dados:** unificar servidores, respeitar `DB_PATH`, preparar migração do esquema antigo e comprovar restauração/persistência Docker.
2. **Fechar a exposição:** autenticação e autorização no servidor, raiz estática restrita, credenciais protegidas e tratamento específico de informações sensíveis.
3. **Eliminar gravações concorrentes por snapshot:** operações por entidade, controle de versão e confirmações reais de persistência.
4. **Corrigir os fluxos de negócio:** numeração central, cadastro de cliente vinculado à operação, validação financeira, estoque e transições de OS.
5. **Completar pagamentos e testes:** webhook transacional, falhas/reenvios, fluxos reais de navegador e testes do mesmo ponto de entrada usado em produção.

Não é necessário trocar de framework ou banco para resolver os problemas centrais. A prioridade é consolidar a implementação existente e garantir que execução, interface e testes usem as mesmas regras.
