-- Bolos & Gestão V15: endereços, contas bancárias e operações de venda auditáveis.
-- Execute no Supabase SQL Editor depois da V14. Faça backup antes.
alter table public.customers add column if not exists cep text;
alter table public.customers add column if not exists street text;
alter table public.customers add column if not exists number text;
alter table public.customers add column if not exists complement text;
alter table public.customers add column if not exists neighborhood text;
alter table public.customers add column if not exists city text;
alter table public.customers add column if not exists state text;
alter table public.suppliers add column if not exists cep text;
alter table public.suppliers add column if not exists street text;
alter table public.suppliers add column if not exists number text;
alter table public.suppliers add column if not exists complement text;
alter table public.suppliers add column if not exists neighborhood text;
alter table public.suppliers add column if not exists city text;
alter table public.suppliers add column if not exists state text;
alter table public.sales add column if not exists delivery_address text;
alter table public.sales add column if not exists bank_account_id uuid;
alter table public.purchases add column if not exists payment_method text default 'cash';
alter table public.purchases add column if not exists bank_account_id uuid;
create table if not exists public.bank_accounts(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, institution text, account_type text not null default 'checking', opening_balance numeric(14,2) not null default 0,
 current_balance numeric(14,2) not null default 0, active boolean not null default true, created_at timestamptz default now()
);
create table if not exists public.bank_transactions(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 bank_account_id uuid not null references public.bank_accounts(id) on delete restrict,
 transaction_type text not null check(transaction_type in('in','out','adjustment')), amount numeric(14,2) not null check(amount>=0),
 description text not null, reference_type text, reference_id uuid, created_at timestamptz default now()
);
alter table public.bank_accounts enable row level security;
alter table public.bank_transactions enable row level security;
drop policy if exists owner_all on public.bank_accounts;
create policy owner_all on public.bank_accounts for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy if exists owner_all on public.bank_transactions;
create policy owner_all on public.bank_transactions for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
alter table public.sales drop constraint if exists sales_bank_account_id_fkey;
alter table public.sales add constraint sales_bank_account_id_fkey foreign key(bank_account_id) references public.bank_accounts(id) on delete set null;
alter table public.purchases drop constraint if exists purchases_bank_account_id_fkey;
alter table public.purchases add constraint purchases_bank_account_id_fkey foreign key(bank_account_id) references public.bank_accounts(id) on delete set null;

create or replace function public.register_sale_v15(p_customer_id uuid,p_payment_method text,p_discount numeric,p_items jsonb,p_notes text,p_delivery_address text,p_bank_account_id uuid)
returns uuid language plpgsql security invoker set search_path=public as $$
declare o uuid:=auth.uid(); sid uuid; it jsonb; p public.products%rowtype; q numeric; price numeric; sub numeric:=0; tot numeric; stat text; acct public.bank_accounts%rowtype;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 if p_customer_id is not null and not exists(select 1 from public.customers where id=p_customer_id and owner_id=o) then raise exception 'Cliente não pertence ao usuário'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Carrinho vazio'; end if;
 if p_payment_method not in('cash','pix','debit','credit','on_account','courtesy','donation') then raise exception 'Forma de pagamento inválida'; end if;
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
 if p_bank_account_id is not null and stat='paid' and p_payment_method not in('courtesy','donation') then
  select * into acct from public.bank_accounts where id=p_bank_account_id and owner_id=o and active for update;
  if not found then raise exception 'Conta bancária inválida/inativa'; end if;
 end if;
 insert into public.sales(owner_id,customer_id,subtotal,discount,total,payment_method,payment_status,notes,delivery_address,bank_account_id)
 values(o,p_customer_id,sub,case when p_payment_method in('courtesy','donation') then sub else p_discount end,tot,p_payment_method,stat,p_notes,nullif(trim(p_delivery_address),''),p_bank_account_id) returning id into sid;
 for it in select * from jsonb_array_elements(p_items) loop
  q:=(it->>'quantity')::numeric; price:=(it->>'unit_price')::numeric;
  select * into p from public.products where id=(it->>'product_id')::uuid and owner_id=o for update;
  update public.products set stock_quantity=stock_quantity-q where id=p.id;
  insert into public.sale_items(owner_id,sale_id,product_id,product_name_snapshot,quantity,unit_price,unit_cost_snapshot,line_total) values(o,sid,p.id,p.name,q,price,p.average_cost,q*price);
  insert into public.stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id) values(o,p.id,'sale',-q,p.average_cost,'sale',sid);
 end loop;
 if stat='pending' then insert into public.accounts_receivable(owner_id,description,customer_id,sale_id,amount,status) values(o,'Venda a prazo',p_customer_id,sid,tot,'pending');
 else
  if p_payment_method not in('courtesy','donation') then
   insert into public.cash_movements(owner_id,movement_type,amount,description,reference_type,reference_id) values(o,'sale',tot,'Recebimento de venda','sale',sid);
   if p_bank_account_id is not null then update public.bank_accounts set current_balance=current_balance+tot where id=p_bank_account_id and owner_id=o;
    insert into public.bank_transactions(owner_id,bank_account_id,transaction_type,amount,description,reference_type,reference_id) values(o,p_bank_account_id,'in',tot,'Recebimento da venda','sale',sid);
   end if;
  end if;
 end if;
 return sid;
end $$;

create or replace function public.delete_sale_v15(p_sale_id uuid) returns void language plpgsql security invoker set search_path=public as $$
declare o uuid:=auth.uid(); s public.sales%rowtype; it record;
begin
 select * into s from public.sales where id=p_sale_id and owner_id=o for update;
 if not found then raise exception 'Venda não encontrada'; end if;
 for it in select * from public.sale_items where sale_id=s.id and owner_id=o loop
  update public.products set stock_quantity=stock_quantity+it.quantity where id=it.product_id and owner_id=o;
 end loop;
 if s.bank_account_id is not null then
  update public.bank_accounts set current_balance=current_balance-coalesce((select sum(amount) from public.bank_transactions where owner_id=o and reference_type='sale' and reference_id=s.id and transaction_type='in'),0)
   +coalesce((select sum(amount) from public.bank_transactions where owner_id=o and reference_type='sale' and reference_id=s.id and transaction_type='out'),0) where id=s.bank_account_id and owner_id=o;
 end if;
 delete from public.bank_transactions where owner_id=o and reference_type='sale' and reference_id=s.id;
 delete from public.cash_movements where owner_id=o and reference_type='sale' and reference_id=s.id;
 delete from public.accounts_receivable where owner_id=o and sale_id=s.id;
 delete from public.stock_movements where owner_id=o and reference_type='sale' and reference_id=s.id;
 delete from public.sales where id=s.id and owner_id=o;
end $$;

create or replace function public.update_sale_v15(p_sale_id uuid,p_customer_id uuid,p_payment_method text,p_discount numeric,p_items jsonb,p_notes text,p_delivery_address text,p_bank_account_id uuid)
returns void language plpgsql security invoker set search_path=public as $$
declare o uuid:=auth.uid(); s public.sales%rowtype; it jsonb; oldit record; p public.products%rowtype; q numeric; price numeric; sub numeric:=0; tot numeric; stat text; acct public.bank_accounts%rowtype;
begin
 select * into s from public.sales where id=p_sale_id and owner_id=o for update;
 if not found then raise exception 'Venda não encontrada'; end if;
 if p_customer_id is not null and not exists(select 1 from public.customers where id=p_customer_id and owner_id=o) then raise exception 'Cliente não pertence ao usuário'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Carrinho vazio'; end if;
 if p_payment_method not in('cash','pix','debit','credit','on_account','courtesy','donation') then raise exception 'Forma de pagamento inválida'; end if;
 for oldit in select * from public.sale_items where sale_id=s.id and owner_id=o loop update public.products set stock_quantity=stock_quantity+oldit.quantity where id=oldit.product_id and owner_id=o; end loop;
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
 if p_bank_account_id is not null and stat='paid' and p_payment_method not in('courtesy','donation') then select * into acct from public.bank_accounts where id=p_bank_account_id and owner_id=o and active for update; if not found then raise exception 'Conta bancária inválida/inativa'; end if; end if;
 if s.bank_account_id is not null then update public.bank_accounts set current_balance=current_balance-coalesce((select sum(amount) from public.bank_transactions where owner_id=o and reference_type='sale' and reference_id=s.id and transaction_type='in'),0)+coalesce((select sum(amount) from public.bank_transactions where owner_id=o and reference_type='sale' and reference_id=s.id and transaction_type='out'),0) where id=s.bank_account_id and owner_id=o; end if;
 delete from public.bank_transactions where owner_id=o and reference_type='sale' and reference_id=s.id;
 delete from public.cash_movements where owner_id=o and reference_type='sale' and reference_id=s.id;
 delete from public.accounts_receivable where owner_id=o and sale_id=s.id;
 delete from public.stock_movements where owner_id=o and reference_type='sale' and reference_id=s.id;
 delete from public.sale_items where owner_id=o and sale_id=s.id;
 update public.sales set customer_id=p_customer_id,subtotal=sub,discount=case when p_payment_method in('courtesy','donation') then sub else p_discount end,total=tot,payment_method=p_payment_method,payment_status=stat,notes=p_notes,delivery_address=nullif(trim(p_delivery_address),''),bank_account_id=p_bank_account_id where id=s.id and owner_id=o;
 for it in select * from jsonb_array_elements(p_items) loop
  q:=(it->>'quantity')::numeric; price:=(it->>'unit_price')::numeric; select * into p from public.products where id=(it->>'product_id')::uuid and owner_id=o for update;
  update public.products set stock_quantity=stock_quantity-q where id=p.id;
  insert into public.sale_items(owner_id,sale_id,product_id,product_name_snapshot,quantity,unit_price,unit_cost_snapshot,line_total) values(o,s.id,p.id,p.name,q,price,p.average_cost,q*price);
  insert into public.stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id) values(o,p.id,'sale',-q,p.average_cost,'sale',s.id);
 end loop;
 if stat='pending' then insert into public.accounts_receivable(owner_id,description,customer_id,sale_id,amount,status) values(o,'Venda a prazo',p_customer_id,s.id,tot,'pending');
 elsif p_payment_method not in('courtesy','donation') then
  insert into public.cash_movements(owner_id,movement_type,amount,description,reference_type,reference_id) values(o,'sale',tot,'Recebimento de venda','sale',s.id);
  if p_bank_account_id is not null then update public.bank_accounts set current_balance=current_balance+tot where id=p_bank_account_id and owner_id=o; insert into public.bank_transactions(owner_id,bank_account_id,transaction_type,amount,description,reference_type,reference_id) values(o,p_bank_account_id,'in',tot,'Recebimento da venda','sale',s.id); end if;
 end if;
end $$;
grant execute on function public.register_sale_v15(uuid,text,numeric,jsonb,text,text,uuid) to authenticated;
grant execute on function public.update_sale_v15(uuid,uuid,text,numeric,jsonb,text,text,uuid) to authenticated;
grant execute on function public.delete_sale_v15(uuid) to authenticated;
-- Compra V15 atômica: estoque, custo médio, contas a pagar e débito da conta no mesmo commit.
create or replace function public.register_purchase_v15(
 p_supplier_id uuid,p_product_id uuid,p_quantity numeric,p_unit_cost numeric,p_payment_status text,p_notes text,
 p_purchase_date date,p_barcode text,p_invoice_coupon text,p_delivery_fee numeric,p_payment_method text,p_bank_account_id uuid
) returns uuid language plpgsql security invoker set search_path=public as $$
declare o uuid:=auth.uid(); pid uuid; q numeric; c numeric; total numeric; effective_cost numeric; payable uuid; acct public.bank_accounts%rowtype; stat text;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 if p_quantity<=0 or p_unit_cost<0 or coalesce(p_delivery_fee,0)<0 then raise exception 'Quantidade, custo ou taxa inválidos'; end if;
 if p_payment_method not in('cash','pix','debit','credit','on_account') then raise exception 'Forma de pagamento inválida'; end if;
 if p_supplier_id is not null and not exists(select 1 from public.suppliers where id=p_supplier_id and owner_id=o) then raise exception 'Fornecedor não pertence ao usuário'; end if;
 if p_payment_status not in('paid','pending','partial') then raise exception 'Status de pagamento inválido'; end if;
 stat:=case when p_payment_method='on_account' then 'pending' else p_payment_status end;
 select stock_quantity,average_cost into q,c from public.products where id=p_product_id and owner_id=o for update;
 if not found then raise exception 'Produto não encontrado'; end if;
 total:=round(p_quantity*p_unit_cost+coalesce(p_delivery_fee,0),2);
 effective_cost:=p_unit_cost+coalesce(p_delivery_fee,0)/p_quantity;
 if stat='paid' and p_bank_account_id is not null then select * into acct from public.bank_accounts where id=p_bank_account_id and owner_id=o and active for update; if not found then raise exception 'Conta bancária inválida/inativa'; end if; end if;
 insert into public.purchases(owner_id,supplier_id,purchase_date,total_amount,payment_status,notes,barcode,invoice_coupon,delivery_fee,payment_method,bank_account_id)
 values(o,p_supplier_id,coalesce(p_purchase_date,current_date),total,stat,p_notes,nullif(trim(p_barcode),''),nullif(trim(p_invoice_coupon),''),coalesce(p_delivery_fee,0),p_payment_method,case when stat='paid' then p_bank_account_id else null end) returning id into pid;
 insert into public.purchase_items(owner_id,purchase_id,product_id,quantity,unit_cost,line_total) values(o,pid,p_product_id,p_quantity,effective_cost,total);
 update public.products set stock_quantity=q+p_quantity,average_cost=case when q+p_quantity>0 then ((q*c)+(p_quantity*effective_cost))/(q+p_quantity) else effective_cost end where id=p_product_id and owner_id=o;
 insert into public.stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id,notes) values(o,p_product_id,'purchase',p_quantity,effective_cost,'purchase',pid,p_notes);
 insert into public.price_history(owner_id,product_id,supplier_id,purchase_unit_cost) values(o,p_product_id,p_supplier_id,effective_cost);
 if stat<>'paid' then insert into public.accounts_payable(owner_id,description,supplier_id,due_date,amount,status) values(o,'Compra de estoque'||case when nullif(trim(p_invoice_coupon),'') is not null then ' · Doc. '||trim(p_invoice_coupon) else '' end,p_supplier_id,coalesce(p_purchase_date,current_date),total,'pending') returning id into payable; update public.purchases set payable_id=payable where id=pid and owner_id=o;
 elsif p_bank_account_id is not null then update public.bank_accounts set current_balance=current_balance-total where id=p_bank_account_id and owner_id=o; insert into public.bank_transactions(owner_id,bank_account_id,transaction_type,amount,description,reference_type,reference_id) values(o,p_bank_account_id,'out',total,'Pagamento de compra','purchase',pid); end if;
 return pid;
end $$;
grant execute on function public.register_purchase_v15(uuid,uuid,numeric,numeric,text,text,date,text,text,numeric,text,uuid) to authenticated;
-- Índices de apoio para filtros e pesquisas mais frequentes.
create index if not exists idx_products_owner_barcode on public.products(owner_id,barcode);
create index if not exists idx_products_owner_type_name on public.products(owner_id,product_type,name);
create index if not exists idx_sales_owner_sold_at on public.sales(owner_id,sold_at desc);
create index if not exists idx_sale_items_owner_sale on public.sale_items(owner_id,sale_id);
create index if not exists idx_bank_transactions_owner_date on public.bank_transactions(owner_id,created_at desc);
create index if not exists idx_bank_transactions_reference on public.bank_transactions(owner_id,reference_type,reference_id);
-- Impede que uma movimentação seja vinculada à conta de outro usuário.
create or replace function public.check_bank_transaction_owner_v15() returns trigger language plpgsql security invoker set search_path=public as $$
begin
 if not exists(select 1 from public.bank_accounts a where a.id=new.bank_account_id and a.owner_id=coalesce(new.owner_id,auth.uid())) then raise exception 'Conta bancária não pertence ao usuário autenticado'; end if;
 return new;
end $$;
drop trigger if exists trg_bank_transaction_owner_v15 on public.bank_transactions;
create trigger trg_bank_transaction_owner_v15 before insert or update on public.bank_transactions for each row execute function public.check_bank_transaction_owner_v15();
