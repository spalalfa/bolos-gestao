# Bolos & Gestão V5 — Atualizações

- Gráfico de faturamento mensal (últimos 6 meses).
- DRE gerencial simplificada (receita, custo vendido, lucro bruto, despesas pagas, resultado estimado).
- Fluxo de caixa resumido e visão de contas abertas a pagar/receber.
- Gestão de lotes com data de validade, alertas de vencimento e saldo de lote.
- Registro de perdas por lote com ajuste do estoque e trilha de movimentação.
- Entrada de lote atualiza estoque e custo médio ponderado.
- PDV: carrinho salvo em sessionStorage, sinal sonoro no bip e retorno automático ao campo de scanner.
- Tema escuro/claro, tipografia Manrope e layout adaptado.

## Requer instalação
Execute `supabase/upgrade-v5.sql` no SQL Editor. Leia o README para a regra de entrada de lotes: lote cadastrado é uma nova entrada de estoque.

## V6 — Usabilidade, temas e guia (2026-11-25)
- Novos temas Claro, Escuro, Rosa, Menta e Oceano, com preferência salva.
- Página de guia explicando os fluxos entre cadastros, compras, lotes, receitas, produção, PDV, caixa e relatórios.
- Dados-base sugeridos e rotinas de conferência apresentados como referência (não são inseridos no banco automaticamente para evitar duplicidade).
- Campos numéricos de cadastro e abertura de caixa começam vazios, com orientação em placeholder, evitando zeros confusos. Valores vazios de campos numéricos são enviados como zero quando o banco exige número.
- Layout responsivo reforçado para celulares, tablets e telas estreitas; tabelas passam a rolar horizontalmente sem esmagar colunas.
- Fontes e carregamento de fontes ajustados para evitar declaração duplicada.
