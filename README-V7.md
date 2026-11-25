# V7 — melhorias de ficha técnica, custos e análise


- Ficha técnica salva de forma transacional por RPC: evita receita parcialmente atualizada se falhar ao salvar ingredientes.
- Validação para rendimento positivo, produto final tipo bolo, pelo menos um ingrediente, quantidade positiva, ingrediente válido e sem duplicidade.
- Prévia de custo por lote e por unidade de rendimento usando custo médio atual.
- Produção validada: bloqueia ficha vazia, produto final incompatível, quantidade inválida e estoque insuficiente; baixa ingrediente proporcional ao rendimento, registra snapshots e acrescenta produto pronto.
- Cadastro de custos fixos e variáveis mensais, vigência, categoria, ativação/desativação, remoção e exportação CSV.
- Relatório avançado com receita, CMV, custos fixos, custos variáveis, despesas pagas e resultado gerencial; barras, composição e tabela mensal.
- Relatório consulta registros em páginas para reduzir o risco de truncamento pelo limite padrão do Supabase.
- Temas adicionais: Lavanda, Pôr do sol e Grafite; seletor único com persistência.
- Remove mensagens de configuração interna do login.


## SQL
Execute `supabase/upgrade-v7.sql` após a migração V5 no banco que já existe.
