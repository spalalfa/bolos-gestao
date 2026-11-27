# Bolos & Gestão V14 — Operação

## Alterações
- Fornecedores: Razão Social (campo existente `name`) e Nome Fantasia (`trade_name`).
- Produtos: Fabricante.
- Compras: código de barras bipável, data padrão de hoje, NF/Cupom, taxa de entrega.
- Últimas compras: produto, quantidade, data, fornecedor, NF/Cupom, código, taxa, editar e excluir.
- Produção: editar data/observações e excluir com reversão segura de estoque.
- PDV: Cortesia e Doação, com total cobrado zero e sem lançamento de entrada de dinheiro; o estoque continua baixado.
- Corrigido bug em que o clique de Editar receita disparava ao renderizar a lista, abrindo a edição de receita inesperadamente.

## Atualização de banco
Execute `supabase/upgrade-v14-operacao.sql` uma vez no Supabase SQL Editor, após backup. Não apaga tabelas ou registros.

## Segurança operacional
A edição de compra recalcula custo médio e taxa de entrega, mas bloqueia se o produto teve movimentações posteriores. A exclusão de compra bloqueia movimentações posteriores ou estoque insuficiente. A exclusão de produção só funciona se o produto final ainda estiver em estoque suficiente e nenhum ingrediente/produto envolvido teve movimentações posteriores. Edição de produção é limitada a data e observações para preservar os registros de consumo/custo.

## Cortesia e Doação
Esses tipos registram venda de itens e baixa de estoque, mas o total fica zerado, sem movimentação de caixa/recebimento. Isso preserva o controle de quantidades, sem contar como faturamento ou recebimento.
