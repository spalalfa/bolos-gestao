# Bolos & Gestão — Correção de salvamento V8

## Correções
- Campo de código de barras vazio é gravado como `NULL`, evitando conflito com índice UNIQUE para produtos sem código.
- Corrigida a variável usada no salvamento de ingredientes da ficha técnica, evitando `ReferenceError` antes da RPC.
- Tratamento de erro de cadastros e despesas: falhas de rede e Supabase aparecem ao usuário e ficam no console.
- Inicialização dos módulos financeiros é resiliente a corrida com evento de login e também consulta a sessão já ativa.
- Verificação defensiva da biblioteca Supabase no carregamento, com mensagem clara quando a CDN não carrega.

## Migrações exigidas
Para um banco existente, execute na ordem e somente se ainda não executadas:
1. `supabase/upgrade-v5.sql` (lotes/validade/perdas).
2. `supabase/upgrade-v7.sql` (custos operacionais, ficha técnica e produção transacional).

Não execute `schema.sql` sobre um banco em uso: ele é para criação de projeto novo. Faça backup antes de aplicar migrations.

## Teste mínimo pós-publicação
1. Cadastre dois produtos sem código de barras (ingrediente e bolo).
2. Cadastre fornecedor e cliente.
3. Salve uma ficha técnica com ao menos um ingrediente.
4. Registre compra e confira aumento de estoque.
5. Produza lote e confira consumo proporcional e entrada de bolo pronto.
6. Faça uma venda teste e confira baixa.
7. Registre despesa e custo fixo/variável.
8. Confira relatório e exportação.

## Limitação de validação
Os arquivos foram verificados por sintaxe/estrutura nesta execução. Não foi possível autenticar em seu Supabase ou executar gravações reais, portanto esses testes precisam ser feitos no banco do usuário.
