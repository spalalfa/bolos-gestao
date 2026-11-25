-- Bolos & Gestão V7: custos operacionais fixos e variáveis.
-- Execute no SQL Editor após o schema base e upgrade-v5.sql.
create table if not exists public.operating_costs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  description text not null,
  cost_type text not null check(cost_type in ('fixed','variable')),
  category text not null default 'Outros',
  monthly_amount numeric(14,2) not null check(monthly_amount>=0),
  start_month text not null check(start_month ~ '^[0-9]{4}-[0-9]{2}$'),
  end_month text check(end_month is null or end_month ~ '^[0-9]{4}-[0-9]{2}$'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint operating_costs_period_check check(end_month is null or end_month>=start_month)
);
create index if not exists operating_costs_owner_active_idx on public.operating_costs(owner_id,active,start_month);
alter table public.operating_costs enable row level security;
drop policy if exists owner_all on public.operating_costs;
create policy owner_all on public.operating_costs for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());

-- Atomic recipe save: prevents partial recipe updates if ingredient insertion fails.
create or replace function public.save_recipe_with_ingredients(
 p_recipe_id uuid,
 p_recipe_name text,
 p_finished_product_id uuid,
 p_yield_quantity numeric,
 p_ingredients jsonb
) returns uuid language plpgsql security invoker as $$
declare o uuid:=auth.uid(); rid uuid; ing jsonb; cnt integer; distinct_cnt integer;
begin
 if o is null then raise exception 'Faça login para salvar receitas'; end if;
 if nullif(trim(p_recipe_name),'') is null or p_yield_quantity<=0 then raise exception 'Nome e rendimento positivos são obrigatórios'; end if;
 if jsonb_typeof(p_ingredients)<>'array' or jsonb_array_length(p_ingredients)=0 then raise exception 'Receita precisa de ingredientes'; end if;
 select count(*),count(distinct value->>'product_id') into cnt,distinct_cnt from jsonb_array_elements(p_ingredients) as items(value);
 if cnt<>distinct_cnt then raise exception 'Não repita ingredientes na ficha'; end if;
 if exists(select 1 from jsonb_array_elements(p_ingredients) as items(value) where coalesce((value->>'quantity')::numeric,0)<=0 or nullif(value->>'product_id','') is null) then raise exception 'Quantidades de ingredientes devem ser positivas'; end if;
 if not exists(select 1 from products where id=p_finished_product_id and owner_id=o and product_type='cake') then raise exception 'Produto final inválido'; end if;
 if exists(select 1 from jsonb_array_elements(p_ingredients) as items(value) where (value->>'product_id')::uuid=p_finished_product_id) then raise exception 'O produto final não pode ser ingrediente da própria receita'; end if;
 if exists(select 1 from jsonb_array_elements(p_ingredients) as items(value) left join products p on p.id=(value->>'product_id')::uuid and p.owner_id=o where p.id is null or p.product_type='cake') then raise exception 'Ingrediente inválido ou não pertence à sua conta'; end if;
 if p_recipe_id is not null then
   update recipes set name=trim(p_recipe_name),finished_product_id=p_finished_product_id,yield_quantity=p_yield_quantity where id=p_recipe_id and owner_id=o;
   if not found then raise exception 'Receita não encontrada'; end if;
   rid:=p_recipe_id;
   delete from recipe_ingredients where recipe_id=rid and owner_id=o;
 else
   insert into recipes(owner_id,name,finished_product_id,yield_quantity) values(o,trim(p_recipe_name),p_finished_product_id,p_yield_quantity) returning id into rid;
 end if;
 for ing in select value from jsonb_array_elements(p_ingredients) as items(value) loop
   insert into recipe_ingredients(owner_id,recipe_id,ingredient_product_id,quantity,unit)
   values(o,rid,(ing->>'product_id')::uuid,(ing->>'quantity')::numeric,coalesce(nullif(ing->>'unit',''),'un'));
 end loop;
 return rid;
end $$;
grant execute on function public.save_recipe_with_ingredients(uuid,text,uuid,numeric,jsonb) to authenticated;

-- Guarded production transaction: validates nonempty recipe, locks ingredients,
-- deducts exactly scaled quantities, snapshots ingredient cost, and adds finished stock.
create or replace function public.register_production(
 p_recipe_id uuid,p_product_id uuid,p_quantity numeric,p_manual_total_cost numeric default null,p_notes text default null
) returns uuid language plpgsql security invoker as $$
declare o uuid:=auth.uid(); pid uuid; rec record; ing record; total numeric:=0; used numeric; line numeric; q_before numeric; cost_before numeric; n integer;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'Quantidade produzida deve ser maior que zero'; end if;
 select product_type into rec from products where id=p_product_id and owner_id=o for update;
 if not found or rec.product_type<>'cake' then raise exception 'Produto final precisa ser cadastrado como bolo pronto'; end if;
 if p_recipe_id is not null then
   select yield_quantity,finished_product_id into rec from recipes where id=p_recipe_id and owner_id=o for update;
   if not found or rec.finished_product_id<>p_product_id then raise exception 'Receita não corresponde ao produto final'; end if;
   select count(*) into n from recipe_ingredients where recipe_id=p_recipe_id and owner_id=o;
   if n=0 then raise exception 'Ficha técnica sem ingredientes'; end if;
   for ing in select ri.ingredient_product_id,ri.quantity,p.name from recipe_ingredients ri join products p on p.id=ri.ingredient_product_id and p.owner_id=o where ri.recipe_id=p_recipe_id and ri.owner_id=o order by ri.ingredient_product_id loop
     used:=ing.quantity*(p_quantity/rec.yield_quantity);
     select stock_quantity,average_cost into q_before,cost_before from products where id=ing.ingredient_product_id and owner_id=o for update;
     if q_before<used then raise exception 'Estoque insuficiente de %: necessário %, disponível %',ing.name,used,q_before; end if;
     line:=used*cost_before; total:=total+line;
     update products set stock_quantity=stock_quantity-used,updated_at=now() where id=ing.ingredient_product_id and owner_id=o;
   end loop;
 else
   if p_manual_total_cost is null or p_manual_total_cost<0 then raise exception 'Informe custo manual válido'; end if;
   total:=p_manual_total_cost;
 end if;
 insert into productions(owner_id,recipe_id,produced_product_id,produced_quantity,total_cost,unit_cost,notes)
 values(o,p_recipe_id,p_product_id,p_quantity,total,total/p_quantity,p_notes) returning id into pid;
 if p_recipe_id is not null then
   for ing in select ri.ingredient_product_id,ri.quantity,p.average_cost from recipe_ingredients ri join products p on p.id=ri.ingredient_product_id and p.owner_id=o where ri.recipe_id=p_recipe_id and ri.owner_id=o loop
     used:=ing.quantity*(p_quantity/rec.yield_quantity);line:=used*ing.average_cost;
     insert into production_items(owner_id,production_id,ingredient_product_id,quantity_used,unit_cost_snapshot,line_cost) values(o,pid,ing.ingredient_product_id,used,ing.average_cost,line);
     insert into stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id,notes) values(o,ing.ingredient_product_id,'production_input',-used,ing.average_cost,'production',pid,'Consumo pela ficha técnica');
   end loop;
 end if;
 update products set stock_quantity=stock_quantity+p_quantity,average_cost=case when stock_quantity+p_quantity>0 then ((stock_quantity*average_cost)+total)/(stock_quantity+p_quantity) else average_cost end,updated_at=now() where id=p_product_id and owner_id=o;
 insert into stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id,notes) values(o,p_product_id,'production_output',p_quantity,total/p_quantity,'production',pid,'Entrada de produto produzido');
 return pid;
end $$;
grant execute on function public.register_production(uuid,uuid,numeric,numeric,text) to authenticated;
