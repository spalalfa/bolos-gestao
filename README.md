# Bolos & Gestão — V7

Sistema web para confeitaria/bolos com Supabase Auth e banco protegido por RLS.

## Publicação
1. Publique o conteúdo da pasta em um host HTTPS (ex.: GitHub Pages).
2. A configuração do projeto Supabase já está incluída em `js/config.js`.
3. Entre com um usuário criado em Supabase Authentication → Users.
4. **Não compartilhe nem adicione chaves secret/service-role no frontend.** A chave `sb_publishable` é a chave publicável; as tabelas devem manter RLS habilitado.

## Atualização do banco
Se já está usando as versões anteriores do Bolos & Gestão, execute no SQL Editor do mesmo projeto, nesta ordem e apenas uma vez cada:
- `supabase/upgrade-v5.sql` (lotes, validade e perdas, se ainda não aplicado)
- `supabase/upgrade-v7.sql` (custos operacionais e rotinas seguras de ficha técnica/produção)

Não execute `schema.sql` sobre um banco em uso: ele é para instalação nova. Faça backup antes de migrations.

## Fluxo recomendado
1. **Produtos:** cadastre ingredientes/embalagens e produtos finais; defina unidades, estoque mínimo, custo e preço.
2. **Compras:** registra entrada de ingrediente/embalagem e custo médio ponderado. Não contabilize a mesma entrada também em Lotes.
3. **Receitas:** escolha produto final, rendimento e ingredientes; informe quantidade de cada ingrediente na mesma unidade usada no cadastro do ingrediente. A prévia mostra custo estimado com base nos custos médios cadastrados.
4. **Produção:** ao registrar uma quantidade produzida, o sistema escala as quantidades da receita pelo rendimento, verifica o estoque, desconta os ingredientes e adiciona o produto final. Se qualquer ingrediente estiver insuficiente, a operação é rejeitada.
5. **PDV:** selecione ou bip um bolo pronto, confira pedido, cliente, desconto e pagamento. Venda desconta o estoque do produto final.
6. **Financeiro:** registre despesas e contas. Use o módulo de custos operacionais para custos mensais (fixos ou variáveis) e evite registrar o mesmo custo duas vezes.
7. **Relatórios:** filtre datas para analisar faturamento, CMV estimado, custos fixos/variáveis, despesas pagas, resultado gerencial, produtos e formas de pagamento. Exporte CSV ou imprima/salve em PDF pelo navegador.

## Custos fixos/variáveis
O novo cadastro permite custos mensais (ex.: aluguel, gás, energia, água, internet, manutenção, embalagens). A vigência é por mês; os valores são rateados proporcionalmente aos dias do período selecionado. Despesas pagas registradas em Financeiro também são consideradas na visão avançada. Evite lançar o mesmo gasto nos dois lugares, para não duplicar custos.

## Receita e custo de produção
- O custo da ficha é a soma de quantidade de ingrediente × custo médio atual.
- A produção usa `quantidade produzida ÷ rendimento da receita` como fator para escalar os ingredientes.
- O estoque baixa exatamente a quantidade calculada, usando a unidade do ingrediente. **Conversão automática de kg↔g e L↔ml não está incluída**; cadastre e use uma unidade consistente na ficha técnica.
- A produção guarda snapshots dos custos e registra movimentos de entrada/consumo.

## Temas e responsividade
Temas: Claro, Escuro, Rosa, Menta, Oceano, Lavanda, Pôr do sol e Grafite. A preferência fica salva localmente no navegador. Interface adaptável a desktop, tablet e celular.

## Limitações importantes
- Não foi possível executar transações reais contra o Supabase conectado nem testes de navegador em todos os dispositivos nesta entrega. Faça uma venda, compra e produção com registros de teste antes do uso operacional.
- O relatório é gerencial e não substitui contabilidade/fiscal.
- Custos fixos/variáveis precisam ser informados pelo usuário e atualizados quando houver mudança.
- Controle de lote/validade não consome lotes automaticamente por FEFO/FIFO nas vendas.
- Caixa ainda não tem conciliação completa automática de vendas por sessão; confirme manualmente antes de tratar o fechamento como oficial.

## PDV
Atalhos: F2 (buscar), F8 (finalizar). O leitor USB/Bluetooth precisa funcionar como teclado e enviar Enter. O carrinho pode ser recuperado durante a mesma sessão do navegador.

## Corrigir problemas de salvamento (V8 patch)

Esta versão corrigida trata campos de código de barras vazios (salvos como `NULL` para permitir vários produtos sem código), reforça o tratamento de erros ao salvar cadastros/despesas e corrige o salvamento de receitas que referenciava uma variável inexistente. Também inicializa os módulos financeiros mesmo quando o evento de autenticação ocorre antes de sua instalação.

**Para atualizar um banco já existente:** confirme que as migrações `supabase/upgrade-v5.sql` e `supabase/upgrade-v7.sql` foram executadas no SQL Editor. A V7 cria a tabela de custos operacionais e RPCs de ficha técnica/produção; se elas estiverem ausentes, esses recursos falharão. Depois do SQL, recarregue a página com Ctrl+F5.

Se um formulário ainda falhar, agora o aviso exibe o erro devolvido pelo Supabase. Os casos comuns são `relation does not exist` (migration não executada), `permission denied`/`violates row-level security` (política/usuário), ou erro de conexão (URL/chave/rede).
