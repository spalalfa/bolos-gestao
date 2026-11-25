# Bolos & Gestão v2.0

## Instalação
1. Crie um projeto novo no Supabase.
2. Execute `supabase/schema.sql` inteiro no SQL Editor.
3. Em Authentication → Users, crie o usuário administrador.
4. Preencha `js/config.js` com Project URL e chave publishable/anon.
5. Publique a pasta em hospedagem HTTPS (GitHub Pages/Hostinger) e entre com o usuário criado.

**Nunca use service_role/secret key no frontend.** O banco usa RLS por `owner_id=auth.uid()`.

## Funcionalidades
- Login Supabase Auth.
- Cadastros e edição de produtos, fornecedores e clientes.
- Busca e leitura de código de barras via leitor USB/Bluetooth que funcione como teclado e envie Enter.
- Compras com RPC transacional: entrada no estoque, custo médio ponderado, histórico de preços e conta a pagar quando pendente.
- Receitas com rendimento e lista de ingredientes.
- Produção por receita ou custo manual, baixa de ingredientes e entrada de produto pronto.
- Venda direta com carrinho, desconto, formas de pagamento, validação/baixa de estoque, snapshots de custo e registro de recebimento/conta a receber.
- Despesas, abertura e fechamento básico de caixa, metas, relatório de vendas e simulador de preço.

## Atenção antes de operar
- Teste primeiro com dados fictícios.
- A ficha técnica exige a mesma unidade no cadastro do ingrediente e na receita. A conversão automática kg/g e L/ml ainda não está implementada.
- A abertura/fechamento do caixa está disponível, mas a associação automática de cada venda a uma sessão de caixa ainda precisa ser concluída; não use o fechamento como conciliação oficial até essa melhoria.
- O lucro do dashboard ainda não soma custos dos itens; o relatório detalhado de vendas calcula lucro bruto por snapshots de custo.
- O módulo de metas cadastra objetivos; o acompanhamento automático de progresso é uma próxima melhoria.
- Preço sugerido usa margem sobre venda: custo ÷ (1 - margem). Inclua mão de obra, gás, energia, embalagem, perdas, impostos e taxas para chegar ao custo real.
- O SQL pressupõe projeto novo. Não rode sobre banco já existente sem revisar migrações.
