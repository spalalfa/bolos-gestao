# Bolos & Gestão V9 — Correção de conexão e carregamento

## Corrigido nesta versão
- **Uma única instância Supabase** (`window.BOLOS_DB`) compartilhada entre app, módulos avançados e financeiro. Remove o alerta de `Multiple GoTrueClient instances` e evita disputa pelo mesmo token de autenticação.
- **Erro HTTP 400 ao carregar dados**: a tabela `goals` não possui `created_at` no schema do projeto; a consulta agora ordena metas por `starts_on`. Tabelas com datas próprias usam coluna de ordenação correspondente (`sales` por `sold_at`, caixa por `opened_at`, produção por `production_date`), e demais tabelas por `created_at`.
- Logs de consulta identificam a tabela, código, mensagem, detalhes e hint do Supabase para diagnosticar erros restantes.
- Wrapper de armazenamento tolerante a bloqueios de `localStorage`/`sessionStorage`, com fallback em memória para sessão do navegador (preferências/carrinho e storage de auth). Se armazenamento persistente for bloqueado, a persistência em memória não sobrevive a fechar/atualizar a página.

## Sobre mensagens Tracking Prevention
O aviso de Tracking Prevention para `cdn.jsdelivr.net` é gerado pela política de privacidade do navegador e, sozinho, não confirma que a chamada de API ao Supabase falhou. O SDK ainda é carregado via CDN porque não foi possível baixar e empacotar a biblioteca neste ambiente (sem resolução de internet). Se o SDK não carregar, o app exibirá aviso de conexão.

## Publicação
Substitua os arquivos da V8 por esta versão e publique normalmente no GitHub Pages. Não execute SQL nem apague tabelas; esta correção não altera schema do banco.
