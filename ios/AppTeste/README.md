# Smartcenter iOS — login

Cliente SwiftUI da API existente. Envia `POST /api/auth/login` com `login` e `password`, usa o cookie de sessão e envia `X-CSRF-Token` no logout. A sessão fica apenas na memória; fechar o processo exige novo login. A senha nunca é salva.

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

O menu lateral inclui Painel, Ordens de serviço, Clientes, Orçamentos, Vendas e Produtos, conforme as permissões da conta. As listas consultam `GET /api/mobile/records/:entity?page=1&pageSize=30&q=...&status=...` e carregam mais ao rolar. Busca e filtro são executados no servidor antes do `LIMIT/OFFSET`; o limite máximo é 100 por página. O retorno inclui `items`, `page`, `pageSize`, `total` e `hasMore`. Os detalhes usam os campos da página já carregada, sem baixar o banco inteiro. Não há fallback silencioso para `/api/db` caso o endpoint não esteja publicado. A consulta do painel ainda usa o snapshot `/api/db`.

As telas oferecem consulta, busca e detalhes; OS também têm filtro por status. Puxe as listas para atualizar. Se houver erro no próximo lote, a lista atual permanece disponível com opção de tentar novamente. Não há cadastro/edição, gráficos ou navegação pelos cartões do painel nesta etapa. Paginação por offset pode refletir inserções/exclusões concorrentes: puxe para atualizar a listagem.

Para verificar no aparelho: login, números comparados com a web para o mesmo usuário, abrir/fechar menu, buscar registros, filtrar OS, abrir detalhes e voltar, atualizar, erro de conexão, saída e perfil com acesso restrito.
