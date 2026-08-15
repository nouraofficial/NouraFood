-- NOURA production integrity migration (idempotent)
-- Run in Supabase SQL Editor. This is designed to repair the existing project,
-- not delete existing data.

create extension if not exists pgcrypto;

create table if not exists public.profiles (id uuid primary key references auth.users(id) on delete cascade, email text, name text default '', username text default '', role text not null default 'user', avatar_url text, status text not null default 'active', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.vendors (id uuid primary key default gen_random_uuid(), auth_user_id uuid unique references auth.users(id) on delete cascade, business_name text not null default '', owner_name text default '', email text, category text default '', slug text, status text not null default 'pending', setup_done boolean not null default false, phone text, whatsapp text, website text, instagram text, facebook text, description text, country text, state text, city text, address text, emoji text, price_range text, hours text, restaurant_id uuid, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.restaurants (id uuid primary key default gen_random_uuid(), vendor_id uuid references public.vendors(id) on delete set null, slug text, name text not null default '', cuisine text default '', area text default '', emoji text default '🍽️', rating numeric, review_count integer not null default 0, verified boolean not null default false, open boolean not null default true, price_range text default '', tags text[] default '{}', phone text, whatsapp text, website text, hours text, description text, logo_url text, cover_url text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
do $$ begin if not exists (select 1 from pg_constraint where conname='vendors_restaurant_fk') then alter table public.vendors add constraint vendors_restaurant_fk foreign key (restaurant_id) references public.restaurants(id) on delete set null; end if; end $$;
create table if not exists public.menu_items (id uuid primary key default gen_random_uuid(), restaurant_id uuid not null references public.restaurants(id) on delete cascade, name text not null, price text default '', category text default '', description text default '', emoji text default '🍽️', prep_time text, available boolean not null default true, image_url text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.reviews (id uuid primary key default gen_random_uuid(), restaurant_id uuid not null references public.restaurants(id) on delete cascade, user_id uuid references auth.users(id) on delete set null, author text default 'Anonymous', stars integer not null default 5, text text default '', reply text, replied boolean not null default false, created_at timestamptz not null default now());

alter table if exists public.profiles add column if not exists role text not null default 'user';
alter table if exists public.profiles add column if not exists avatar_url text;
alter table if exists public.profiles add column if not exists status text not null default 'active';
alter table if exists public.profiles add column if not exists created_at timestamptz not null default now();
alter table if exists public.profiles add column if not exists updated_at timestamptz not null default now();
alter table if exists public.profiles add column if not exists bio text default '';
alter table if exists public.profiles add column if not exists country text default '';
alter table if exists public.profiles add column if not exists cuisines text[] default '{}';
alter table if exists public.profiles add column if not exists diet text default '';
alter table if exists public.profiles add column if not exists allergies text[] default '{}';
alter table if exists public.profiles add column if not exists onboarding_complete boolean not null default false;

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  budget text default '',
  mealtimes text[] default '{}',
  goal text default '',
  fav_foods text[] default '{}',
  avoid text[] default '{}',
  skill text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table if exists public.user_preferences enable row level security;
drop policy if exists user_preferences_owner_all on public.user_preferences;
create policy user_preferences_owner_all on public.user_preferences for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);


alter table if exists public.vendors add column if not exists auth_user_id uuid;
alter table if exists public.vendors add column if not exists slug text;
alter table if exists public.vendors add column if not exists restaurant_id uuid;
alter table if exists public.vendors add column if not exists business_name text;
alter table if exists public.vendors add column if not exists owner_name text;
alter table if exists public.vendors add column if not exists email text;
alter table if exists public.vendors add column if not exists category text;
alter table if exists public.vendors add column if not exists status text not null default 'pending';
alter table if exists public.vendors add column if not exists setup_done boolean not null default false;
alter table if exists public.vendors add column if not exists phone text;
alter table if exists public.vendors add column if not exists whatsapp text;
alter table if exists public.vendors add column if not exists website text;
alter table if exists public.vendors add column if not exists instagram text;
alter table if exists public.vendors add column if not exists facebook text;
alter table if exists public.vendors add column if not exists description text;
alter table if exists public.vendors add column if not exists country text;
alter table if exists public.vendors add column if not exists state text;
alter table if exists public.vendors add column if not exists city text;
alter table if exists public.vendors add column if not exists address text;
alter table if exists public.vendors add column if not exists emoji text;
alter table if exists public.vendors add column if not exists price_range text;
alter table if exists public.vendors add column if not exists hours text;
alter table if exists public.vendors add column if not exists created_at timestamptz not null default now();
alter table if exists public.vendors add column if not exists updated_at timestamptz not null default now();

alter table if exists public.restaurants add column if not exists vendor_id uuid;
alter table if exists public.restaurants add column if not exists slug text;
alter table if exists public.restaurants add column if not exists description text;
alter table if exists public.restaurants add column if not exists logo_url text;
alter table if exists public.restaurants add column if not exists cover_url text;
alter table if exists public.restaurants add column if not exists website text;
alter table if exists public.restaurants add column if not exists whatsapp text;
alter table if exists public.restaurants add column if not exists phone text;
alter table if exists public.restaurants add column if not exists created_at timestamptz not null default now();
alter table if exists public.restaurants add column if not exists updated_at timestamptz not null default now();

create unique index if not exists vendors_auth_user_uidx on public.vendors(auth_user_id) where auth_user_id is not null;

-- A partial unique index cannot be inferred by ON CONFLICT(auth_user_id).
-- Keep the old index if present, but add a real table-level UNIQUE constraint
-- so Auth -> Vendor upserts work reliably.
do $$
begin
  if exists (
    select 1
    from public.vendors
    where auth_user_id is not null
    group by auth_user_id
    having count(*) > 1
  ) then
    raise exception 'Noura migration stopped: duplicate vendors.auth_user_id values exist. Resolve them before rerunning.';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.vendors'::regclass
      and conname = 'vendors_auth_user_id_key'
  ) then
    alter table public.vendors
      add constraint vendors_auth_user_id_key unique (auth_user_id);
  end if;
end $$;
create unique index if not exists vendors_slug_uidx on public.vendors(lower(slug)) where slug is not null;
create unique index if not exists restaurants_slug_uidx on public.restaurants(lower(slug)) where slug is not null;
create unique index if not exists restaurants_vendor_uidx on public.restaurants(vendor_id) where vendor_id is not null;
create index if not exists restaurants_created_idx on public.restaurants(created_at desc);
create index if not exists menu_items_restaurant_idx on public.menu_items(restaurant_id);
create index if not exists reviews_restaurant_idx on public.reviews(restaurant_id);

create or replace function public.noura_slugify(input text) returns text language plpgsql immutable as $$
declare s text;
begin
  s := lower(trim(coalesce(input,'')));
  s := regexp_replace(s,'[^a-z0-9]+','-','g');
  s := regexp_replace(s,'^-+|-+$','','g');
  if s='' then s:='vendor'; end if;
  return left(s,70);
end; $$;

create or replace function public.noura_unique_slug(input text, exclude_vendor uuid default null) returns text language plpgsql as $$
declare base text:=public.noura_slugify(input); candidate text:=base; n int:=1;
begin
  while exists(select 1 from public.vendors where lower(slug)=lower(candidate) and (exclude_vendor is null or id<>exclude_vendor))
     or exists(select 1 from public.restaurants where lower(slug)=lower(candidate) and (exclude_vendor is null or vendor_id<>exclude_vendor)) loop
    n:=n+1; candidate:=left(base,60)||'-'||n;
  end loop;
  return candidate;
end; $$;

-- Create/sync a profile whenever a Supabase Auth account is created.
create or replace function public.noura_handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,email,name,username,role)
  values(new.id,new.email,coalesce(new.raw_user_meta_data->>'name',''),coalesce(new.raw_user_meta_data->>'username',''),'user')
  on conflict(id) do update set email=excluded.email;

  if coalesce(new.raw_user_meta_data->>'business_name','')<>'' then
    insert into public.vendors(auth_user_id,business_name,owner_name,email,category,slug,status,setup_done)
    values(new.id,new.raw_user_meta_data->>'business_name',coalesce(new.raw_user_meta_data->>'owner_name',''),new.email,coalesce(new.raw_user_meta_data->>'category',''),public.noura_unique_slug(new.raw_user_meta_data->>'business_name'), 'pending', false)
    on conflict(auth_user_id) do update set email=excluded.email;
  end if;
  return new;
end; $$;

drop trigger if exists noura_on_auth_user_created on auth.users;
create trigger noura_on_auth_user_created after insert on auth.users for each row execute function public.noura_handle_new_user();

-- Backfill missing profiles/vendors for older accounts.
insert into public.profiles(id,email,name,username)
select id,email,coalesce(raw_user_meta_data->>'name',''),coalesce(raw_user_meta_data->>'username','') from auth.users
on conflict(id) do update set email=excluded.email;

insert into public.vendors(auth_user_id,business_name,owner_name,email,category,slug,status,setup_done)
select u.id,coalesce(u.raw_user_meta_data->>'business_name',''),coalesce(u.raw_user_meta_data->>'owner_name',''),u.email,coalesce(u.raw_user_meta_data->>'category',''),public.noura_unique_slug(coalesce(u.raw_user_meta_data->>'business_name','vendor'),null),'pending',false
from auth.users u
where coalesce(u.raw_user_meta_data->>'business_name','')<>''
on conflict(auth_user_id) do nothing;

-- Every vendor gets one durable public restaurant record.
create or replace function public.noura_set_vendor_slug() returns trigger language plpgsql security definer set search_path=public as $$
begin
  new.slug:=public.noura_unique_slug(coalesce(nullif(new.slug,''),new.business_name),new.id);
  return new;
end; $$;
drop trigger if exists noura_vendor_slug_before on public.vendors;
create trigger noura_vendor_slug_before before insert or update of business_name,slug on public.vendors for each row execute function public.noura_set_vendor_slug();

create or replace function public.noura_sync_vendor_restaurant() returns trigger language plpgsql security definer set search_path=public as $$
declare rid uuid;
begin
  select id into rid from public.restaurants where vendor_id=new.id limit 1;
  if rid is null then
    insert into public.restaurants(vendor_id,slug,name,cuisine,description,phone,whatsapp,website,verified,open,price_range,tags,hours)
    values(new.id,new.slug,new.business_name,coalesce(new.category,''),coalesce(new.description,''),coalesce(new.phone,''),coalesce(new.whatsapp,''),coalesce(new.website,''),new.status='approved',true,coalesce(new.price_range,''),case when coalesce(new.category,'')='' then '{}'::text[] else array[new.category] end,coalesce(new.hours,''))
    on conflict do update set slug=excluded.slug,name=excluded.name
    returning id into rid;
  else
    update public.restaurants set slug=new.slug,name=new.business_name,cuisine=coalesce(new.category,''),description=coalesce(new.description,''),phone=coalesce(new.phone,''),whatsapp=coalesce(new.whatsapp,''),website=coalesce(new.website,''),verified=new.status='approved',price_range=coalesce(new.price_range,''),hours=coalesce(new.hours,'') where id=rid;
  end if;
  if new.restaurant_id is distinct from rid then update public.vendors set restaurant_id=rid where id=new.id; end if;
  return new;
end; $$;
drop trigger if exists noura_vendor_restaurant_sync on public.vendors;
create trigger noura_vendor_restaurant_sync after insert or update of business_name,category,status,phone,whatsapp,website,price_range,hours,slug,description on public.vendors for each row execute function public.noura_sync_vendor_restaurant();

-- Backfill one restaurant per existing vendor.
insert into public.restaurants(vendor_id,slug,name,cuisine,description,phone,whatsapp,website,verified,open,price_range,tags,hours)
select v.id,v.slug,v.business_name,coalesce(v.category,''),coalesce(v.description,''),v.phone,v.whatsapp,v.website,v.status='approved',true,coalesce(v.price_range,''),case when coalesce(v.category,'')='' then '{}'::text[] else array[v.category] end,coalesce(v.hours,'') from public.vendors v
where not exists(select 1 from public.restaurants r where r.vendor_id=v.id)
on conflict do nothing;
update public.vendors v set restaurant_id=r.id from public.restaurants r where r.vendor_id=v.id and v.restaurant_id is distinct from r.id;

-- Storage buckets. Public read is intentional for storefront images.
insert into storage.buckets(id,name,public) values('vendor-photos','vendor-photos',true) on conflict(id) do update set public=true;
insert into storage.buckets(id,name,public) values('meal-photos','meal-photos',true) on conflict(id) do update set public=true;

-- RLS: profiles are private to owners; admin RPCs below run as security definer.
alter table if exists public.profiles enable row level security;
alter table if exists public.vendors enable row level security;
alter table if exists public.restaurants enable row level security;
alter table if exists public.menu_items enable row level security;
alter table if exists public.reviews enable row level security;

-- Avoid recursive RLS checks on profiles by using a SECURITY DEFINER helper.
create or replace function public.noura_is_admin()
returns boolean
language sql
security definer
set search_path=public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('admin','super_admin')
  );
$$;

revoke all on function public.noura_is_admin() from public;
grant execute on function public.noura_is_admin() to authenticated;

drop policy if exists profiles_owner_select on public.profiles;
create policy profiles_owner_select
on public.profiles for select to authenticated
using (auth.uid() = id or public.noura_is_admin());

drop policy if exists profiles_owner_insert on public.profiles;
create policy profiles_owner_insert
on public.profiles for insert to authenticated
with check (auth.uid() = id);

drop policy if exists profiles_owner_update on public.profiles;
create policy profiles_owner_update
on public.profiles for update to authenticated
using (auth.uid() = id or public.noura_is_admin())
with check (auth.uid() = id or public.noura_is_admin());

drop policy if exists vendors_public_select on public.vendors;
create policy vendors_public_select on public.vendors for select to anon,authenticated using(status<>'deleted');
drop policy if exists vendors_owner_insert on public.vendors;
create policy vendors_owner_insert on public.vendors for insert to authenticated with check(auth.uid()=auth_user_id or public.noura_is_admin());
drop policy if exists vendors_owner_update on public.vendors;
create policy vendors_owner_update on public.vendors for update to authenticated using(auth.uid()=auth_user_id or public.noura_is_admin()) with check(auth.uid()=auth_user_id or public.noura_is_admin());

drop policy if exists restaurants_public_select on public.restaurants;
create policy restaurants_public_select on public.restaurants for select to anon,authenticated using(coalesce(verified,false)=true or exists(select 1 from public.vendors v where v.id=vendor_id and v.auth_user_id=auth.uid()) or public.noura_is_admin());
drop policy if exists restaurants_owner_update on public.restaurants;
create policy restaurants_owner_update on public.restaurants for update to authenticated using(exists(select 1 from public.vendors v where v.id=vendor_id and v.auth_user_id=auth.uid()) or public.noura_is_admin()) with check(true);

drop policy if exists menu_public_select on public.menu_items;
create policy menu_public_select on public.menu_items for select to anon,authenticated using(exists(select 1 from public.restaurants r where r.id=restaurant_id and (r.verified=true or exists(select 1 from public.vendors v where v.id=r.vendor_id and v.auth_user_id=auth.uid()) or public.noura_is_admin())));
drop policy if exists menu_owner_write on public.menu_items;
create policy menu_owner_write on public.menu_items for all to authenticated using(exists(select 1 from public.restaurants r join public.vendors v on v.id=r.vendor_id where r.id=restaurant_id and (v.auth_user_id=auth.uid() or public.noura_is_admin()))) with check(exists(select 1 from public.restaurants r join public.vendors v on v.id=r.vendor_id where r.id=restaurant_id and (v.auth_user_id=auth.uid() or public.noura_is_admin())));

drop policy if exists reviews_public_select on public.reviews;
create policy reviews_public_select on public.reviews for select to anon,authenticated using(true);
drop policy if exists reviews_auth_insert on public.reviews;
create policy reviews_auth_insert on public.reviews for insert to authenticated with check(user_id=auth.uid() or user_id is null);

-- Storage: authenticated users can write only inside their own UID prefix.
drop policy if exists noura_vendor_photos_read on storage.objects;
create policy noura_vendor_photos_read on storage.objects for select to public using(bucket_id in ('vendor-photos','meal-photos'));
drop policy if exists noura_vendor_photos_insert on storage.objects;
create policy noura_vendor_photos_insert on storage.objects for insert to authenticated with check(bucket_id in ('vendor-photos','meal-photos') and (name like auth.uid()::text||'/%' or name like 'profile/'||auth.uid()::text||'/%'));
drop policy if exists noura_vendor_photos_update on storage.objects;
create policy noura_vendor_photos_update on storage.objects for update to authenticated using(bucket_id in ('vendor-photos','meal-photos') and (name like auth.uid()::text||'/%' or name like 'profile/'||auth.uid()::text||'/%'));
drop policy if exists noura_vendor_photos_delete on storage.objects;
create policy noura_vendor_photos_delete on storage.objects for delete to authenticated using(bucket_id in ('vendor-photos','meal-photos') and (name like auth.uid()::text||'/%' or name like 'profile/'||auth.uid()::text||'/%'));

-- Admin RPCs: require a real Supabase-authenticated admin profile.
create or replace function public.admin_list_users() returns jsonb language sql security definer set search_path=public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'email',p.email,'username',p.username,'status',p.status,'role',p.role,'joinedAt',p.created_at) order by p.created_at desc),'[]'::jsonb) from profiles p where exists(select 1 from profiles me where me.id=auth.uid() and me.role in ('admin','super_admin'));
$$;
create or replace function public.admin_list_vendors() returns jsonb language sql security definer set search_path=public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',v.id,'businessName',v.business_name,'owner',v.owner_name,'email',v.email,'category',v.category,'status',v.status,'slug',v.slug,'restaurantId',v.restaurant_id,'setupDone',v.setup_done) order by v.created_at desc),'[]'::jsonb) from vendors v where exists(select 1 from profiles me where me.id=auth.uid() and me.role in ('admin','super_admin'));
$$;
revoke all on function public.admin_list_users() from public;
revoke all on function public.admin_list_vendors() from public;
grant execute on function public.admin_list_users() to authenticated;
grant execute on function public.admin_list_vendors() to authenticated;

-- FINAL QUICK DIAGNOSTIC
select 'profiles' table_name, to_regclass('public.profiles') is not null exists, (select count(*) from public.profiles) row_count
union all select 'vendors',to_regclass('public.vendors') is not null,(select count(*) from public.vendors)
union all select 'restaurants',to_regclass('public.restaurants') is not null,(select count(*) from public.restaurants)
union all select 'menu_items',to_regclass('public.menu_items') is not null,(select count(*) from public.menu_items)
union all select 'reviews',to_regclass('public.reviews') is not null,(select count(*) from public.reviews);

select id,name,public from storage.buckets where id in ('vendor-photos','meal-photos');
