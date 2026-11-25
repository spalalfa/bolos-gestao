-- V13: conteúdo por embalagem para compras convertidas em unidade base de estoque
-- Execute uma única vez no Supabase SQL Editor. Mantém dados existentes.
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS package_content numeric(14,3),
  ADD COLUMN IF NOT EXISTS package_name text;

COMMENT ON COLUMN public.products.package_content IS
  'Quantidade de unidade base do estoque contida em uma embalagem de compra (ex.: 1010 g por barra).';
COMMENT ON COLUMN public.products.package_name IS
  'Nome comercial da embalagem de compra (barra, caixa, lata, pacote etc.).';
