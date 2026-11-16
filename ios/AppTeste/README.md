# Smartcenter iOS — login

Cliente SwiftUI da API existente. Envia `POST /api/auth/login` com `login` e `password`, usa o cookie de sessão e envia `X-CSRF-Token` no logout. Com Manter-me conectado desativado, a sessão fica apenas na memória. Quando ativado, apenas o cookie e seu prazo são guardados no Keychain (acessível com o aparelho desbloqueado, sem migração para outro aparelho). A senha nunca é salva. Ao abrir o app, GET /api/auth/session valida a sessão e obtém o token CSRF. Sair ou receber HTTP 401 remove a sessão salva. A validade continua sendo a definida pela API (atualmente oito horas; reiniciar o servidor também invalida as sessões).

Servidor inicial: `http://163.176.205.54:8093`. Pode ser alterado em **Servidor** na tela de login. HTTP está habilitado no Info.plist apenas para este teste; antes de distribuir, configurar HTTPS e remover `NSAllowsArbitraryLoads`.

No Ubuntu WSL, copie esta pasta para um diretório Linux e execute:

```bash
cd ~/Projetos/AppTeste
xtool dev build
export USBMUXD_SOCKET_ADDRESS=192.168.128.1:27015
xtool dev run --usb
```

O endereço acima é a interface virtual atual do Windows e pode mudar após reiniciar. O serviço Apple Mobile Device e o encaminhamento de porta devem estar ativos. Instalações de desenvolvimento exigem confiança no certificado e Modo de Desenvolvimento no iPhone.

Após autenticar, o app busca `GET /api/db` com o mesmo cookie e mostra o painel: indicadores, ordens por status e alertas de prazo/estoque. O cálculo de faturamento segue a web (OS entregues + vendas não canceladas), com datas locais do aparelho. As permissões controlam os indicadores disponíveis; uma sessão expirada retorna ao login. Puxe para atualizar ou use **Tentar novamente** após uma falha. Dados anteriores permanecem visíveis com o horário da última atualização.

O menu lateral inclui Painel, Ordens de serviço, Clientes, Orçamentos, Vendas e Produtos, conforme as permissões da conta. As listas consultam `GET /api/mobile/records/:entity?page=1&pageSize=10&q=...&status=...` com 10 registros por página, usando os botões fixos Anterior e Próxima. Busca e filtro são executados no servidor antes do `LIMIT/OFFSET`; o limite máximo é 100 por página. O retorno inclui `items`, `page`, `pageSize`, `total` e `hasMore`. Os detalhes usam os campos da página já carregada, sem baixar o banco inteiro. Não há fallback silencioso para `/api/db` caso o endpoint não esteja publicado. A consulta do painel ainda usa o snapshot `/api/db`.

As telas oferecem consulta, busca e detalhes; OS também têm filtro por status. Puxe as listas para atualizar. Se houver erro ao trocar de página, a página atual permanece disponível com opção de tentar novamente. Ordens de serviço têm criação pelo botão + e edição nos detalhes, com cliente existente, aparelho, diagnóstico, peças, mão de obra, prazo, garantia, pagamento e status. Os seletores de cliente e produto usam busca/paginação. Salvar usa POST /api/os, com cookie/CSRF, chave de idempotência reutilizada para o mesmo envio e comparação before para impedir sobrescritas concorrentes. Edição carrega GET /api/os/:id e preserva os campos não apresentados, incluindo checklist. A API calcula totais, histórico, estoque e datas de conclusão/entrega. Concluir/entregar exige confirmação. Senhas do aparelho não são exibidas nem editadas aqui. Ainda não há criação/edição das demais coleções, PDF ou gráficos. Paginação por offset pode refletir inserções/exclusões concorrentes: puxe para atualizar a listagem.

Para verificar no aparelho: login, números comparados com a web para o mesmo usuário, abrir/fechar menu, buscar registros, filtrar OS, abrir detalhes e voltar, atualizar, erro de conexão, saída e perfil com acesso restrito.

## Clientes

O botão + da lista cria clientes e Editar nos detalhes altera o cadastro. O formulário inclui nome, telefone, WhatsApp, CPF/CNPJ opcional, e-mail, CEP, cidade, endereço e observações. A edição carrega GET /api/clientes/:id, preserva campos desconhecidos e grava por POST /api/changes com comparação before e chave de idempotência. Documentos são validados no app e duplicidade é verificada pela API. O seletor de cliente da OS oferece Novo; ao salvar, o novo cliente fica selecionado. As permissões continuam sendo aplicadas no servidor. Não há exclusão nem histórico do cliente nesta etapa.
