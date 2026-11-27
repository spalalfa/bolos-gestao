# Bolos & Gestão — atualização V15

Esta atualização parte do projeto V14 incluído no pacote e preserva os dados existentes.

## O que mudou

- Cadastro de clientes e fornecedores com endereço completo e consulta de CEP via ViaCEP.
- No PDV, o endereço padrão do cliente é carregado automaticamente e pode ser editado para aquela venda.
- Histórico de vendas com edição e exclusão por operação SQL transacional; ao excluir, o estoque é devolvido e os movimentos financeiros vinculados são removidos/revertidos.
- Botão de impressão em formato estreito (80 mm) para impressora térmica. O documento é um **comprovante não fiscal**, não uma NF-e/NFC-e.
- Contas bancárias/caixa com saldo, instituição, tipo e movimentações.
- Compras com Pix, dinheiro, débito, crédito ou a prazo. Quando uma conta é escolhida e a compra está paga, o valor é debitado no mesmo RPC que registra a compra e atualiza o estoque.
- Vendas podem ser vinculadas a uma conta; recebimentos pagos creditam o saldo da conta escolhida.
- Produtos/estoque com filtros de categoria, situação do estoque e ordenação por nome, estoque ou preço.
- Melhorias de fonte, responsividade e cache de recursos; índices SQL para consultas comuns.
- Edição de despesas/contas a pagar e tradução de status/categorias comuns.

## Instalação no Supabase

1. Faça backup do projeto Supabase antes de alterar o banco.
2. Abra Supabase → SQL Editor.
3. Execute **`supabase/upgrade-v15-addresses-accounts-sales.sql`** no projeto que já está na V14.
4. Publique os arquivos atualizados do site. A configuração atual em `js/config.js` foi preservada; use somente a chave publicável/anon no navegador, nunca `service_role`.
5. Entre no sistema e cadastre as contas bancárias/caixa antes de registrar compras ou vendas que queira vincular a elas.

Não execute este upgrade sobre um projeto antigo que ainda não tenha aplicado os scripts V13/V14 correspondentes. O script é uma migração incremental, não substitui o schema base.

## Leitor de código de barras

O leitor USB/Bluetooth deve estar configurado como teclado e enviar Enter ao final. Na aba Compras, ao bipar um código cadastrado, o produto é selecionado automaticamente e o foco vai para quantidade. Se o código não estiver cadastrado, o sistema avisa e permite selecionar o produto manualmente. O campo de código começa vazio.

## Impressão fiscal

A impressão térmica disponível é um comprovante de venda não fiscal. Para emitir NF-e/NFC-e legal, é necessário integrar um emissor fiscal (certificado digital, credenciamento, regras tributárias e autorização SEFAZ); essa emissão não é feita por este pacote.

## Validação

Os arquivos JavaScript passaram pela verificação de sintaxe `node --check`. Não foi possível testar as RPCs contra o banco Supabase real deste usuário. Execute o SQL V15 antes de publicar a versão; sem a migração, as chamadas `register_sale_v15`, `update_sale_v15`, `delete_sale_v15` e `register_purchase_v15` não existem.
