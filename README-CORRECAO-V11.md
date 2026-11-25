# Correção V11 — alertas de Auth e consulta de metas

- Os módulos `app.js`, `advanced.js`, `finance-enhancements.js` e `config.js` agora têm guardas de execução para impedir inicialização duplicada na mesma página.
- O cliente Supabase permanece centralizado em `window.BOLOS_DB`.
- A inicialização Auth foi ajustada para não chamar a tela principal/carregamento duas vezes para a mesma sessão, incluindo o evento `INITIAL_SESSION`.
- A consulta de metas usa a coluna `starts_on` (existente no schema), não `created_at`.
- Os scripts e CSS receberam versão `?v=11` para forçar a atualização do cache do navegador/GitHub Pages.
- Supabase JS CDN está fixado na versão 2.119.2 para reduzir alterações inesperadas.

## Aplicação
Substitua os arquivos, publique e abra o site com Ctrl+F5. Se o navegador mantiver recursos antigos, limpe os dados/cache do site e carregue novamente.
Nenhuma migration SQL é necessária.
