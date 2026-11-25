-- Bolos & Gestão V5: lotes, validade e perdas de estoque
-- Execute no SQL Editor do Supabase depois de confirmar que o schema base V2 foi aplicado.

create table if not exists public.inventory_lots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  lot_code text,
  expiry_date date not null,
  quantity_received numeric(14,3) not null check(quantity_received > 0),
  quantity_remaining numeric(14,3) not null check(quantity_remaining >= 0),
  unit_cost numeric(14,4) not null default 0 check(unit_cost >= 0),
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists inventory_lots_owner_expiry_idx on public.inventory_lots(owner_id,expiry_date);
alter table public.inventory_lots enable row level security;
drop policy if exists owner_all on public.inventory_lots;
create policy owner_all on public.inventory_lots for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());

create or replace function public.register_inventory_lot(
  p_product_id uuid,p_quantity numeric,p_expiry_date date,p_unit_cost numeric default 0,p_lot_code text default null
) returns uuid language plpgsql security invoker as $$
declare o uuid:=auth.uid(); lid uuid; old_qty numeric; old_cost numeric;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 if p_quantity<=0 or p_unit_cost<0 or p_expiry_date is null then raise exception 'Quantidade, custo ou validade inválidos'; end if;
 select stock_quantity,average_cost into old_qty,old_cost from public.products where id=p_product_id and owner_id=o for update;
 if not found then raise exception 'Produto não encontrado'; end if;
 insert into public.inventory_lots(owner_id,product_id,lot_code,expiry_date,quantity_received,quantity_remaining,unit_cost)
 values(o,p_product_id,nullif(trim(p_lot_code),''),p_expiry_date,p_quantity,p_quantity,p_unit_cost) returning id into lid;
 update public.products set stock_quantity=old_qty+p_quantity,average_cost=case when old_qty+p_quantity>0 then ((old_qty*old_cost)+(p_quantity*p_unit_cost))/(old_qty+p_quantity) else old_cost end,updated_at=now() where id=p_product_id and owner_id=o;
 insert into public.stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id,notes) values(o,p_product_id,'lot_entry',p_quantity,p_unit_cost,'inventory_lot',lid,'Entrada por lote com validade');
 return lid;
end $$;

create or replace function public.writeoff_inventory_lot(p_lot_id uuid,p_quantity numeric,p_reason text default 'Perda/Desperdício')
returns void language plpgsql security invoker as $$
declare o uuid:=auth.uid(); l public.inventory_lots%rowtype; p public.products%rowtype;
begin
 if o is null then raise exception 'Autenticação necessária'; end if;
 if p_quantity<=0 then raise exception 'Quantidade deve ser maior que zero'; end if;
 select * into l from public.inventory_lots where id=p_lot_id and owner_id=o for update;
 if not found then raise exception 'Lote não encontrado'; end if;
 if l.quantity_remaining<p_quantity then raise exception 'Quantidade maior que saldo do lote'; end if;
 select * into p from public.products where id=l.product_id and owner_id=o for update;
 if not found then raise exception 'Produto não encontrado'; end if;
 if p.stock_quantity<p_quantity then raise exception 'Quantidade maior que estoque total atual'; end if;
 update public.inventory_lots set quantity_remaining=quantity_remaining-p_quantity where id=p_lot_id;
 update public.products set stock_quantity=stock_quantity-p_quantity,updated_at=now() where id=l.product_id;
 insert into public.stock_movements(owner_id,product_id,movement_type,quantity_delta,unit_cost,reference_type,reference_id,notes)
 values(o,l.product_id,'waste',-p_quantity,l.unit_cost,'inventory_lot',p_lot_id,coalesce(nullif(trim(p_reason),''),'Perda/Desperdício'));
end $$;

-- V7 additions are kept in a separate migration file for easier upgrade.
