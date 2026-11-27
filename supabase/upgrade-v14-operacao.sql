-- Bolos & Gestão V14: campos de cadastros, compras detalhadas e pagamentos especiais.
-- Execute no Supabase SQL Editor uma única vez. Não apaga registros existentes.

alter table public.suppliers add column if not exists trade_name text;
alter table public.products add column if not exists manufacturer text;
alter table public.products add column if not exists package_content numeric(14,3);
alter table public.products add column if not exists package_name text;
alter table public.purchases add column if not exists barcode text;
alter table public.purchases add column if not exists invoice_coupon text;
alter table public.purchases add column if not exists delivery_fee numeric(14,2) not null default 0;
alter table public.purchases add column if not exists payable_id uuid references public.accounts_payable(id) on delete set null;
alter table public.productions add column if not exists created_at timestamptz not null default now();

-- RPC de compra detalhada: quantity é enviada já convertida para unidade-base do estoque.
create or replace function public.register_purchase_v14(
 p_supplier_id uuid,p_product_id uuid,p_quantity numeric,p_unit_cost numeric,
 p_payment_status text,p_notes text,p_purchase_date date,p_barcode text,
 p_invoice_coupon text,p_delivery_fee numeric
) returns uuid language plpgsql security invoker as $$
declare o uuid:=auth.uid(); pid uuid; q numeric; c numeric; total numeric; effective_cost numeric; payable uuid;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 if p_quantity<=0 or p_unit_cost<0 or coalesce(p_delivery_fee,0)<0 then raise exception 'Quantidade, custo ou taxa inválidos'; end if;
 select stock_quantity,average_cost into q,c from public.products where id=p_product_id and owner_id=o for update;
 if not found then raise exception 'Produto não encontrado'; end if;
 total:=round(p_quantity*p_unit_cost+coalesce(p_delivery_fee,0),2);
 effective_cost:=p_unit_cost+coalesce(p_delivery_fee,0)/p_quantity;
 insert into public.purchases(owner_id,supplier_id,purchase_date,total_amount,payment_status,notes,barcode,invoice_coupon,delivery_fee)
 values(o,p_supplier_id,coalesce(p_purchase_date,current_date),total,p_payment_status,p_notes,nullif(trim(p_barcode),''),nullif(trim(p_invoice_coupon),''),coalesce(p_delivery_fee,0)) returning id into pid;
 insert into public.purchase_items(owner_id,purchase_id,product_id,quantity,unit_cost,line_total)
 values(o,pid,p_product_id,p_quantity,effective_cost,total);
 update public.products set stock_quantity=q+p_quantity,average_cost=case when q+p_quantity>0 then ((q*c)+(p_quantity*effective_cost))/(q+p_quantity) else effective_cost end where id=p_product_id and owner_id=o;
 insert into public.stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id,notes)
 values(o,p_product_id,'purchase',p_quantity,effective_cost,'purchase',pid,p_notes);
 insert into public.price_history(owner_id,product_id,supplier_id,purchase_unit_cost) values(o,p_product_id,p_supplier_id,effective_cost);
 if p_payment_status<>'paid' then
  insert into public.accounts_payable(owner_id,description,supplier_id,due_date,amount,status)
  values(o,'Compra de estoque'||case when nullif(trim(p_invoice_coupon),'') is not null then ' · Doc. '||trim(p_invoice_coupon) else '' end,p_supplier_id,coalesce(p_purchase_date,current_date),total,'pending') returning id into payable;
  update public.purchases set payable_id=payable where id=pid and owner_id=o;
 end if;
 return pid;
end $$;

-- Edição de dados de referência e taxa de entrega. Bloqueia se houver movimentações posteriores,
-- para não distorcer o custo médio de produtos que já foram consumidos ou vendidos.
create or replace function public.update_purchase_v14(
 p_purchase_id uuid,p_supplier_id uuid,p_purchase_date date,p_barcode text,
 p_invoice_coupon text,p_delivery_fee numeric,p_notes text
) returns void language plpgsql security invoker as $$
declare o uuid:=auth.uid(); pu public.purchases%rowtype; it public.purchase_items%rowtype; stock numeric; avgc numeric; oldfee numeric; oldeffective numeric; neweffective numeric; basecost numeric; newtotal numeric;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 select * into pu from public.purchases where id=p_purchase_id and owner_id=o for update;
 if not found then raise exception 'Compra não encontrada'; end if;
 select * into it from public.purchase_items where purchase_id=pu.id and owner_id=o limit 1;
 if not found then raise exception 'Item da compra não encontrado'; end if;
 select stock_quantity,average_cost into stock,avgc from public.products where id=it.product_id and owner_id=o for update;
 if coalesce(p_delivery_fee,0)<>coalesce(pu.delivery_fee,0) and exists(select 1 from public.stock_movements where owner_id=o and product_id=it.product_id and created_at>pu.created_at and not (reference_type='purchase' and reference_id=pu.id)) then
  raise exception 'Não é possível alterar a taxa de entrega: o produto teve movimentações posteriores e o custo médio seria afetado.';
 end if;
 if it.quantity<=0 then raise exception 'Quantidade inválida'; end if;
 oldfee:=coalesce(pu.delivery_fee,0); oldeffective:=it.unit_cost; basecost:=oldeffective-oldfee/it.quantity;
 neweffective:=basecost+coalesce(p_delivery_fee,0)/it.quantity;
 newtotal:=round(it.quantity*basecost+coalesce(p_delivery_fee,0),2);
 if stock>0 then update public.products set average_cost=greatest(0,avgc+(neweffective-oldeffective)*it.quantity/stock) where id=it.product_id and owner_id=o; end if;
 update public.purchase_items set unit_cost=neweffective,line_total=newtotal where id=it.id and owner_id=o;
 update public.stock_movements set unit_cost=neweffective,notes=p_notes where owner_id=o and reference_type='purchase' and reference_id=pu.id;
 update public.purchases set supplier_id=p_supplier_id,purchase_date=coalesce(p_purchase_date,current_date),barcode=nullif(trim(p_barcode),''),invoice_coupon=nullif(trim(p_invoice_coupon),''),delivery_fee=coalesce(p_delivery_fee,0),notes=p_notes,total_amount=newtotal where id=pu.id and owner_id=o;
 if pu.payable_id is not null then update public.accounts_payable set supplier_id=p_supplier_id,due_date=coalesce(p_purchase_date,current_date),amount=newtotal,description='Compra de estoque'||case when nullif(trim(p_invoice_coupon),'') is not null then ' · Doc. '||trim(p_invoice_coupon) else '' end where id=pu.payable_id and owner_id=o; end if;
 insert into public.price_history(owner_id,product_id,supplier_id,purchase_unit_cost) values(o,it.product_id,p_supplier_id,neweffective);
end $$;

create or replace function public.delete_purchase_v14(p_purchase_id uuid) returns void language plpgsql security invoker as $$
declare o uuid:=auth.uid(); pu public.purchases%rowtype; it public.purchase_items%rowtype; stock numeric; avgc numeric; remaining numeric;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 select * into pu from public.purchases where id=p_purchase_id and owner_id=o for update;
 if not found then raise exception 'Compra não encontrada'; end if;
 select * into it from public.purchase_items where purchase_id=pu.id and owner_id=o limit 1;
 if not found then raise exception 'Item da compra não encontrado'; end if;
 select stock_quantity,average_cost into stock,avgc from public.products where id=it.product_id and owner_id=o for update;
 if exists(select 1 from public.stock_movements where owner_id=o and product_id=it.product_id and created_at>pu.created_at and not (reference_type='purchase' and reference_id=pu.id)) then raise exception 'Exclusão bloqueada: existem movimentações posteriores desse produto.'; end if;
 if stock<it.quantity then raise exception 'Estoque atual menor que a quantidade comprada; exclusão não é segura.'; end if;
 remaining:=stock-it.quantity;
 update public.products set stock_quantity=remaining,average_cost=case when remaining>0 then greatest(0,(stock*avgc-it.quantity*it.unit_cost)/remaining) else 0 end where id=it.product_id and owner_id=o;
 delete from public.stock_movements where owner_id=o and reference_type='purchase' and reference_id=pu.id;
 if pu.payable_id is not null then delete from public.accounts_payable where owner_id=o and id=pu.payable_id; end if;
 delete from public.purchases where owner_id=o and id=pu.id;
end $$;

-- Exclusão segura de produção: só desfaz quando o estoque produzido ainda está disponível
-- e nenhum dos produtos envolvidos teve movimentação posterior àquele lote.
create or replace function public.delete_production_v14(p_production_id uuid) returns void language plpgsql security invoker as $$
declare o uuid:=auth.uid(); pr public.productions%rowtype; stock numeric; avgc numeric; remaining numeric; it record;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 select * into pr from public.productions where id=p_production_id and owner_id=o for update;
 if not found then raise exception 'Produção não encontrada'; end if;
 select stock_quantity,average_cost into stock,avgc from public.products where id=pr.produced_product_id and owner_id=o for update;
 if stock<pr.produced_quantity then raise exception 'Exclusão bloqueada: parte da produção já foi consumida/vendida.'; end if;
 if exists(select 1 from public.stock_movements m where m.owner_id=o and m.created_at>pr.created_at and m.reference_id is distinct from pr.id and m.product_id=pr.produced_product_id) then raise exception 'Exclusão bloqueada: o produto final teve movimentação depois da produção.'; end if;
 for it in select * from public.production_items where owner_id=o and production_id=pr.id loop
  if exists(select 1 from public.stock_movements m where m.owner_id=o and m.product_id=it.ingredient_product_id and m.created_at>pr.created_at and m.reference_id is distinct from pr.id) then raise exception 'Exclusão bloqueada: um ingrediente teve movimentação posterior.'; end if;
  update public.products set stock_quantity=stock_quantity+it.quantity_used where id=it.ingredient_product_id and owner_id=o;
 end loop;
 remaining:=stock-pr.produced_quantity;
 update public.products set stock_quantity=remaining,average_cost=case when remaining>0 then greatest(0,(stock*avgc-pr.total_cost)/remaining) else 0 end where id=pr.produced_product_id and owner_id=o;
 delete from public.stock_movements where owner_id=o and reference_type='production' and reference_id=pr.id;
 delete from public.productions where owner_id=o and id=pr.id;
end $$;

-- Courtesy/Donation sales are recorded as inventory-out sales with zero cash revenue.
alter table public.sales drop constraint if exists sales_payment_method_check;
alter table public.sales add constraint sales_payment_method_check check(payment_method in('cash','pix','debit','credit','on_account','courtesy','donation'));
create or replace function public.register_sale(p_customer_id uuid,p_payment_method text,p_discount numeric,p_items jsonb,p_notes text default null) returns uuid language plpgsql security invoker as $$
declare o uuid:=auth.uid(); sid uuid; it jsonb; p public.products%rowtype; q numeric; price numeric; sub numeric:=0; tot numeric; stat text;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Carrinho vazio'; end if;
 if p_payment_method not in('cash','pix','debit','credit','on_account','courtesy','donation') then raise exception 'Pagamento inválido'; end if;
 for it in select * from jsonb_array_elements(p_items) loop
  q:=(it->>'quantity')::numeric; price:=(it->>'unit_price')::numeric;
  select * into p from public.products where id=(it->>'product_id')::uuid and owner_id=o and product_type='cake' for update;
  if not found or q<=0 or price<0 then raise exception 'Item inválido'; end if;
  if p.stock_quantity<q then raise exception 'Estoque insuficiente: %',p.name; end if;
  sub:=sub+q*price;
 end loop;
 if p_discount<0 or p_discount>sub then raise exception 'Desconto inválido'; end if;
 tot:=case when p_payment_method in('courtesy','donation') then 0 else round(sub-p_discount,2) end;
 stat:=case when p_payment_method='on_account' then 'pending' else 'paid' end;
 insert into public.sales(owner_id,customer_id,subtotal,discount,total,payment_method,payment_status,notes)
 values(o,p_customer_id,sub,case when p_payment_method in('courtesy','donation') then sub else p_discount end,tot, p_payment_method,stat,p_notes) returning id into sid;
 for it in select * from jsonb_array_elements(p_items) loop
  q:=(it->>'quantity')::numeric; price:=(it->>'unit_price')::numeric;
  select * into p from public.products where id=(it->>'product_id')::uuid and owner_id=o for update;
  update public.products set stock_quantity=stock_quantity-q where id=p.id;
  insert into public.sale_items(owner_id,sale_id,product_id,product_name_snapshot,quantity,unit_price,unit_cost_snapshot,line_total) values(o,sid,p.id,p.name,q,price,p.average_cost,q*price);
  insert into public.stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id) values(o,p.id,'sale',-q,p.average_cost,'sale',sid);
 end loop;
 if stat='pending' then
  insert into public.accounts_receivable(owner_id,description,customer_id,sale_id,amount,status) values(o,'Venda a prazo',p_customer_id,sid,tot,'pending');
 elsif p_payment_method not in('courtesy','donation') then
  insert into public.cash_movements(owner_id,movement_type,amount,description,reference_type,reference_id) values(o,'sale',tot,'Recebimento de venda','sale',sid);
 end if;
 return sid;
end $$;

grant execute on function public.register_purchase_v14(uuid,uuid,numeric,numeric,text,text,date,text,text,numeric) to authenticated;
grant execute on function public.update_purchase_v14(uuid,uuid,date,text,text,numeric,text) to authenticated;
grant execute on function public.delete_purchase_v14(uuid) to authenticated;
grant execute on function public.delete_production_v14(uuid) to authenticated;
grant execute on function public.register_sale(uuid,text,numeric,jsonb,text) to authenticated;

-- Edição de produção com reversão e reaplicação transacional da ficha técnica.
-- Bloqueia registros que tiveram movimentação posterior; todo o processo é revertido em caso de falha.
create or replace function public.edit_production_v14(
 p_production_id uuid,p_recipe_id uuid,p_product_id uuid,p_quantity numeric,
 p_manual_total_cost numeric,p_notes text,p_production_date timestamptz
) returns uuid language plpgsql security invoker as $$
declare o uuid:=auth.uid(); pr public.productions%rowtype; stock numeric; avgc numeric; remaining numeric; it record; new_id uuid;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 if p_quantity<=0 then raise exception 'Quantidade produzida inválida'; end if;
 select * into pr from public.productions where id=p_production_id and owner_id=o for update;
 if not found then raise exception 'Produção não encontrada'; end if;
 select stock_quantity,average_cost into stock,avgc from public.products where id=pr.produced_product_id and owner_id=o for update;
 if stock<pr.produced_quantity then raise exception 'Edição bloqueada: parte do produto final já foi consumida/vendida.'; end if;
 if exists(select 1 from public.stock_movements m where m.owner_id=o and m.product_id=pr.produced_product_id and m.created_at>pr.created_at and m.reference_id is distinct from pr.id) then raise exception 'Edição bloqueada: o produto final teve movimentações posteriores.'; end if;
 for it in select * from public.production_items where owner_id=o and production_id=pr.id loop
  if exists(select 1 from public.stock_movements m where m.owner_id=o and m.product_id=it.ingredient_product_id and m.created_at>pr.created_at and m.reference_id is distinct from pr.id) then raise exception 'Edição bloqueada: um ingrediente teve movimentações posteriores.'; end if;
  update public.products set stock_quantity=stock_quantity+it.quantity_used where id=it.ingredient_product_id and owner_id=o;
 end loop;
 remaining:=stock-pr.produced_quantity;
 update public.products set stock_quantity=remaining,average_cost=case when remaining>0 then greatest(0,(stock*avgc-pr.total_cost)/remaining) else 0 end where id=pr.produced_product_id and owner_id=o;
 delete from public.stock_movements where owner_id=o and reference_type='production' and reference_id=pr.id;
 delete from public.productions where owner_id=o and id=pr.id;
 new_id:=public.register_production(p_recipe_id,p_product_id,p_quantity,p_manual_total_cost,p_notes);
 update public.productions set production_date=coalesce(p_production_date,now()) where id=new_id and owner_id=o;
 return new_id;
end $$;
grant execute on function public.edit_production_v14(uuid,uuid,uuid,numeric,numeric,text,timestamptz) to authenticated;
