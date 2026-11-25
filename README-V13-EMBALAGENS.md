# V13 — Compra por embalagem e estoque por unidade-base

Esta versão permite cadastrar o conteúdo de cada embalagem comprada, separado da unidade usada no estoque e na ficha técnica.

## Exemplo: barra de chocolate 1,010 kg
- Unidade-base do estoque: `g`
- Conteúdo por embalagem: `1010`
- Nome da embalagem: `Barra`
- Compra: `1` embalagem
- Custo por embalagem: `R$ 35,90`
- Entrada calculada no estoque: `1010 g`
- Custo médio calculado por unidade-base: `R$ 35,90 / 1010 = R$ 0,035544... por g`

## Exemplo: leite condensado 395 g
- Unidade-base do estoque: `g`
- Conteúdo por embalagem: `395`
- Nome da embalagem: `Caixa` ou `Lata`
- Compra: `1` embalagem
- O estoque aumenta em `395 g` e o custo é distribuído por grama.

## Importante: atualizar banco
Execute `supabase/upgrade-v13-package-content.sql` no SQL Editor do Supabase antes de publicar esta versão. A migration só adiciona duas colunas opcionais e preserva os registros.

## Regras
- Cadastre ingredientes que serão pesados com unidade-base `g` ou medidos em `ml`.
- `package_content` deve estar na mesma unidade-base que o campo Unidade do produto.
- Para produtos sem conteúdo de embalagem, a compra mantém o comportamento anterior (quantidade e custo na unidade de estoque).
- O campo Estoque inicial do produto deve ser preenchido na unidade-base, não no número de embalagens.
- As quantidades das receitas devem ser cadastradas também na unidade-base do ingrediente, para permitir baixa correta.
