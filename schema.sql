-- =====================================================================
-- आज की धार - Supabase डेटाबेस (टेबल + सुरक्षा + सर्वर फ़ंक्शन)
-- ---------------------------------------------------------------------
-- चलाने से पहले नीचे की इस लाइन में PUT_YOUR_PIN_HERE को अपने
-- एडमिन पिन (4 से 8 अंक, सिर्फ़ नंबर) से बदलें:
--      crypt('PUT_YOUR_PIN_HERE', ...)
-- फिर Supabase > SQL Editor में पूरी फाइल पेस्ट करके Run दबाएं।
-- (दोबारा चलाना सुरक्षित है, डेटा नहीं मिटता)
-- =====================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- टेबल
-- ---------------------------------------------------------------------
create table if not exists public.catalog (
  id text primary key,
  cat text not null,
  name text not null,
  tag text,
  unit text,
  descr text,
  mrp int not null,
  price int not null check (price > 0),
  img text,
  out_of_stock boolean not null default false,
  sort int not null default 0
);

create table if not exists public.settings (
  key text primary key,
  value jsonb not null
);

create table if not exists public.admin_secret (
  id int primary key default 1 check (id = 1),
  pin_hash text not null,
  fails int not null default 0,
  locked_until timestamptz
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  phone text not null,
  email text,
  address text not null,
  wallet int not null default 0 check (wallet >= 0),
  subscription jsonb,
  pause_for date,
  vac_active boolean not null default false,
  vac_start date,
  vac_end date,
  created_at timestamptz not null default now()
);
create unique index if not exists profiles_phone_key on public.profiles(phone);
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists middle_name text;
alter table public.profiles add column if not exists last_name text;
alter table public.profiles add column if not exists alt_phone text;
alter table public.profiles add column if not exists addr1 text;
alter table public.profiles add column if not exists addr2 text;
alter table public.profiles add column if not exists addr3 text;
alter table public.profiles add column if not exists pincode text;
alter table public.profiles add column if not exists area text;
alter table public.profiles add column if not exists city text;
alter table public.profiles add column if not exists state text;
alter table public.profiles add column if not exists landmark text;
alter table public.profiles add column if not exists lat numeric;
alter table public.profiles add column if not exists lng numeric;
alter table public.profiles add column if not exists blocked boolean not null default false;
alter table public.profiles add column if not exists block_reason text;
alter table public.profiles add column if not exists blocked_at timestamptz;

alter table public.catalog add column if not exists imgs jsonb not null default '[]'::jsonb;

-- v4.3: रेफ़र, कूपन, रिव्यू
alter table public.profiles add column if not exists ref_code text;
alter table public.profiles add column if not exists referred_by uuid references public.profiles(id) on delete set null;
alter table public.profiles add column if not exists ref_paid boolean not null default false;
update public.profiles set ref_code = 'AKD' || upper(substr(md5(id::text), 1, 5)) where ref_code is null;
create unique index if not exists profiles_ref_code_key on public.profiles(ref_code);
alter table public.orders add column if not exists discount int not null default 0;
alter table public.orders add column if not exists coupon text;
alter table public.profiles add column if not exists delivery_instructions text;
alter table public.orders add column if not exists delivery_note text;
alter table public.orders add column if not exists out_for_delivery boolean not null default false;
alter table public.profiles add column if not exists paused_dates jsonb not null default '[]'::jsonb;
alter table public.profiles add column if not exists default_slot text default '5:30 AM - 7:00 AM';
alter table public.profiles add column if not exists slot_shifts jsonb not null default '{}'::jsonb;

create table if not exists public.coupons (
  code text primary key,
  kind text not null check (kind in ('percent','flat')),
  value int not null check (value > 0),
  min_order int not null default 0,
  max_discount int,
  first_order_only boolean not null default false,
  once_per_user boolean not null default true,
  expires_on date,
  note text,
  active boolean not null default true,
  listed boolean not null default true,
  used_count int not null default 0,
  created_at timestamptz not null default now()
);
alter table public.coupons add column if not exists listed boolean not null default true;
alter table public.coupons enable row level security;

create table if not exists public.reviews (
  id bigserial primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id text not null,
  customer_name text,
  rating int not null check (rating between 1 and 5),
  text text,
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, item_id)
);
alter table public.reviews enable row level security;

create table if not exists public.feedback (
  id bigserial primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  customer_name text,
  phone text,
  rating int check (rating between 1 and 5),
  text text,
  created_at timestamptz not null default now()
);
alter table public.feedback enable row level security;

create table if not exists public.orders (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  customer_name text,
  phone text,
  address text,
  item_id text,
  item text,
  qty int not null check (qty between 1 and 20),
  unit_price int,
  total int,
  slot text,
  bell boolean not null default false,
  pay_mode text not null check (pay_mode in ('wallet','upi','qr','cod')),
  utr text,
  status text not null default 'pending',
  pay_status text,
  delivered boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index if not exists orders_utr_key on public.orders(utr)
  where pay_mode in ('upi','qr') and status <> 'rejected';

create table if not exists public.recharges (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  customer_name text,
  phone text,
  amount int not null check (amount between 10 and 50000),
  utr text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);
create unique index if not exists recharges_utr_key on public.recharges(utr) where status <> 'rejected';

create table if not exists public.wallet_txns (
  id bigserial primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  amount int not null,
  status text,
  created_at timestamptz not null default now()
);

create table if not exists public.pauses (
  id text primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  type text not null,
  customer text,
  phone text,
  date_text text,
  for_date date,
  end_date date,
  detail text,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists public.activity (
  id bigserial primary key,
  type text not null,
  text text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- सुरक्षा (RLS): ग्राहक सिर्फ़ अपना डेटा पढ़ सकता है, बदलाव सिर्फ़ फ़ंक्शन से
-- ---------------------------------------------------------------------
alter table public.catalog enable row level security;
alter table public.settings enable row level security;
alter table public.admin_secret enable row level security;
alter table public.profiles enable row level security;
alter table public.orders enable row level security;
alter table public.recharges enable row level security;
alter table public.wallet_txns enable row level security;
alter table public.pauses enable row level security;
alter table public.activity enable row level security;

drop policy if exists catalog_read on public.catalog;
create policy catalog_read on public.catalog for select to anon, authenticated using (true);
drop policy if exists settings_read on public.settings;
create policy settings_read on public.settings for select to anon, authenticated using (true);
drop policy if exists profiles_own on public.profiles;
create policy profiles_own on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists orders_own on public.orders;
create policy orders_own on public.orders for select to authenticated using (user_id = auth.uid());
drop policy if exists recharges_own on public.recharges;
create policy recharges_own on public.recharges for select to authenticated using (user_id = auth.uid());
drop policy if exists txns_own on public.wallet_txns;
create policy txns_own on public.wallet_txns for select to authenticated using (user_id = auth.uid());

revoke all on all tables in schema public from anon, authenticated;
grant usage on schema public to anon, authenticated;
grant select on public.catalog, public.settings to anon, authenticated;
grant select on public.profiles, public.orders, public.recharges, public.wallet_txns to authenticated;

-- ---------------------------------------------------------------------
-- अंदरूनी सहायक फ़ंक्शन (बाहर से कॉल नहीं हो सकते)
-- ---------------------------------------------------------------------
create or replace function public._ok(p_msg text default null, p_extra jsonb default '{}'::jsonb)
returns jsonb language sql immutable as $$
  select jsonb_build_object('ok', true, 'message', p_msg) || coalesce(p_extra, '{}'::jsonb)
$$;

create or replace function public._fail(p_msg text)
returns jsonb language sql immutable as $$
  select jsonb_build_object('ok', false, 'message', p_msg)
$$;

create or replace function public._ist_today()
returns date language sql stable as $$
  select (now() at time zone 'Asia/Kolkata')::date
$$;

create or replace function public._log(p_type text, p_text text)
returns void language sql security definer set search_path = public as $$
  insert into public.activity(type, text) values (p_type, p_text);
$$;

create or replace function public._txn(p_uid uuid, p_title text, p_amount int, p_status text)
returns void language sql security definer set search_path = public as $$
  insert into public.wallet_txns(user_id, title, amount, status) values (p_uid, p_title, p_amount, p_status);
$$;

create or replace function public._pay_enabled(p_mode text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select (value ->> p_mode)::boolean from public.settings where key = 'pay_methods'), false)
$$;

create or replace function public._utr_used(p_utr text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.orders where utr = p_utr and status <> 'rejected')
      or exists (select 1 from public.recharges where utr = p_utr and status <> 'rejected')
$$;

create or replace function public._admin_ok(p_pin text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare s public.admin_secret%rowtype;
begin
  select * into s from public.admin_secret where id = 1 for update;
  if not found then return false; end if;
  if s.locked_until is not null and s.locked_until > now() then return false; end if;
  if p_pin is not null and s.pin_hash = extensions.crypt(p_pin, s.pin_hash) then
    if s.fails > 0 then update public.admin_secret set fails = 0 where id = 1; end if;
    return true;
  end if;
  update public.admin_secret
     set fails = case when s.fails + 1 >= 5 then 0 else s.fails + 1 end,
         locked_until = case when s.fails + 1 >= 5 then now() + interval '10 minutes' else s.locked_until end
   where id = 1;
  return false;
end $$;

revoke all on function public._ok(text, jsonb) from public, anon, authenticated;
revoke all on function public._fail(text) from public, anon, authenticated;
revoke all on function public._ist_today() from public, anon, authenticated;
revoke all on function public._log(text, text) from public, anon, authenticated;
revoke all on function public._txn(uuid, text, int, text) from public, anon, authenticated;
revoke all on function public._pay_enabled(text) from public, anon, authenticated;
revoke all on function public._utr_used(text) from public, anon, authenticated;
revoke all on function public._admin_ok(text) from public, anon, authenticated;

drop function if exists public.ensure_profile_v2(text,text,text,text,text,text,text,text,text,text);
drop function if exists public.update_profile_v2(text,text,text,text,text,text,text,text,text,text);
drop function if exists public.set_subscription_range(jsonb,date,date);
drop function if exists public.cancel_subscription_range();
drop function if exists public.admin_set_block(text,uuid,boolean);
drop function if exists public.admin_undeliver(text,text);
drop function if exists public.admin_users_ext(text);
drop function if exists public.ensure_profile(text, text, text);
drop function if exists public.update_profile(text, text, text);
drop function if exists public.set_subscription(jsonb);

-- ---------------------------------------------------------------------
-- ग्राहक के फ़ंक्शन (लॉगिन ज़रूरी)
-- ---------------------------------------------------------------------
create or replace function public._blocked(p_uid uuid)
returns boolean language sql security definer set search_path = public as $$
  select coalesce((select blocked from public.profiles where id = p_uid), false)
$$;
revoke all on function public._blocked(uuid) from public, anon, authenticated;

create or replace function public._profile_error(p jsonb)
returns text language plpgsql immutable as $$
declare
  fn text := trim(coalesce(p ->> 'first_name', ''));
  ln text := trim(coalesce(p ->> 'last_name', ''));
  mn text := trim(coalesce(p ->> 'middle_name', ''));
  ph text := trim(coalesce(p ->> 'phone', ''));
  ap text := trim(coalesce(p ->> 'alt_phone', ''));
  a1 text := trim(coalesce(p ->> 'addr1', ''));
  a2 text := trim(coalesce(p ->> 'addr2', ''));
  a3 text := trim(coalesce(p ->> 'addr3', ''));
  pc text := trim(coalesce(p ->> 'pincode', ''));
  ar text := trim(coalesce(p ->> 'area', ''));
  ct text := trim(coalesce(p ->> 'city', ''));
  stt text := trim(coalesce(p ->> 'state', ''));
  lm text := trim(coalesce(p ->> 'landmark', ''));
  di text := trim(coalesce(p ->> 'delivery_instructions', ''));
begin
  if length(fn) < 1 or length(fn) > 30 then return 'पहला नाम (First name) ज़रूरी है।'; end if;
  if length(mn) > 30 then return 'मध्य नाम बहुत लंबा है।'; end if;
  if length(ln) < 1 or length(ln) > 30 then return 'अंतिम नाम (Last name) ज़रूरी है।'; end if;
  if ph !~ '^[6-9][0-9]{9}$' then return 'कृपया सही 10-अंकों का प्राइमरी मोबाइल नंबर दर्ज करें।'; end if;
  if ap <> '' and ap !~ '^[6-9][0-9]{9}$' then return 'वैकल्पिक मोबाइल नंबर सही 10 अंकों का हो।'; end if;
  if length(a1) < 3 or length(a1) > 100 then return 'पता लाइन 1 ज़रूरी है।'; end if;
  if length(a2) < 3 or length(a2) > 100 then return 'पता लाइन 2 ज़रूरी है।'; end if;
  if length(a3) > 100 then return 'पता लाइन 3 बहुत लंबी है।'; end if;
  if pc !~ '^[1-9][0-9]{5}$' then return 'सही 6-अंकों का पिनकोड दर्ज करें।'; end if;
  if length(ar) < 2 or length(ar) > 60 then return 'एरिया / मोहल्ला ज़रूरी है।'; end if;
  if length(ct) < 2 or length(ct) > 50 then return 'शहर ज़रूरी है।'; end if;
  if length(stt) < 2 or length(stt) > 50 then return 'राज्य ज़रूरी है।'; end if;
  if length(lm) > 80 then return 'लैंडमार्क बहुत लंबा है।'; end if;
  if length(di) > 120 then return 'डिलीवरी निर्देश 120 अक्षरों से कम रखें।'; end if;
  return null;
end $$;
revoke all on function public._profile_error(jsonb) from public, anon, authenticated;

create or replace function public._save_profile_fields(p_uid uuid, p jsonb, p_new boolean, p_bonus int)
returns void language plpgsql security definer set search_path = public as $$
declare
  fn text := trim(p ->> 'first_name');
  mn text := nullif(trim(coalesce(p ->> 'middle_name', '')), '');
  ln text := trim(p ->> 'last_name');
  di text := nullif(trim(coalesce(p ->> 'delivery_instructions', '')), '');
  full_name text;
  full_addr text;
  la numeric; lo numeric;
  em text;
begin
  full_name := fn || coalesce(' ' || mn, '') || ' ' || ln;
  full_addr := trim(p ->> 'addr1') || ', ' || trim(p ->> 'addr2')
    || coalesce(', ' || nullif(trim(coalesce(p ->> 'addr3', '')), ''), '')
    || ', ' || trim(p ->> 'area')
    || coalesce(' (' || nullif(trim(coalesce(p ->> 'landmark', '')), '') || ')', '')
    || coalesce(' [निर्देश: ' || di || ']', '')
    || ', ' || trim(p ->> 'city') || ', ' || trim(p ->> 'state') || ' - ' || trim(p ->> 'pincode');
  begin la := (p ->> 'lat')::numeric; lo := (p ->> 'lng')::numeric; exception when others then la := null; lo := null; end;
  if la is not null and (la < -90 or la > 90) then la := null; end if;
  if lo is not null and (lo < -180 or lo > 180) then lo := null; end if;
  if p_new then
    select email into em from auth.users where id = p_uid;
    insert into public.profiles(id, name, phone, email, address, wallet, first_name, middle_name, last_name, alt_phone, addr1, addr2, addr3, pincode, area, city, state, landmark, delivery_instructions, lat, lng)
    values (p_uid, full_name, trim(p ->> 'phone'), em, full_addr, p_bonus, fn, mn, ln, nullif(trim(coalesce(p ->> 'alt_phone', '')), ''),
      trim(p ->> 'addr1'), trim(p ->> 'addr2'), nullif(trim(coalesce(p ->> 'addr3', '')), ''), trim(p ->> 'pincode'), trim(p ->> 'area'),
      trim(p ->> 'city'), trim(p ->> 'state'), nullif(trim(coalesce(p ->> 'landmark', '')), ''), di, la, lo);
  else
    update public.profiles set name = full_name, phone = trim(p ->> 'phone'), address = full_addr, first_name = fn, middle_name = mn, last_name = ln,
      alt_phone = nullif(trim(coalesce(p ->> 'alt_phone', '')), ''), addr1 = trim(p ->> 'addr1'), addr2 = trim(p ->> 'addr2'),
      addr3 = nullif(trim(coalesce(p ->> 'addr3', '')), ''), pincode = trim(p ->> 'pincode'), area = trim(p ->> 'area'),
      city = trim(p ->> 'city'), state = trim(p ->> 'state'), landmark = nullif(trim(coalesce(p ->> 'landmark', '')), ''),
      delivery_instructions = di, lat = coalesce(la, lat), lng = coalesce(lo, lng)
    where id = p_uid;
  end if;
end $$;
revoke all on function public._save_profile_fields(uuid, jsonb, boolean, int) from public, anon, authenticated;

create or replace function public.auth_precheck(p_email text)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  em text := lower(trim(coalesce(p_email, '')));
  u uuid;
  has_profile boolean := false;
  is_blocked boolean := false;
begin
  if em !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' or length(em) > 200 then
    return jsonb_build_object('ok', false, 'message', 'कृपया सही ईमेल दर्ज करें।');
  end if;
  select id into u from auth.users where lower(email) = em limit 1;
  if u is not null then
    select true, blocked into has_profile, is_blocked from public.profiles where id = u;
    has_profile := coalesce(has_profile, false);
    is_blocked := coalesce(is_blocked, false);
  end if;
  return jsonb_build_object('ok', true, 'registered', has_profile, 'blocked', is_blocked);
end $$;

create or replace function public.ensure_profile(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  err text;
  bonus int := 0;
  nm text;
  rc text;
  rid uuid;
  ref_ok boolean := false;
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if exists (select 1 from public.profiles where id = uid) then return public._ok('खाता पहले से मौजूद है।', jsonb_build_object('existing', true)); end if;
  err := public._profile_error(p);
  if err is not null then return public._fail(err); end if;
  if exists (select 1 from public.profiles where phone = trim(p ->> 'phone')) then return public._fail('इस मोबाइल नंबर से खाता पहले से बना हुआ है।'); end if;
  select coalesce((value #>> '{}')::int, 0) into bonus from public.settings where key = 'welcome_bonus';
  bonus := coalesce(bonus, 0);
  perform public._save_profile_fields(uid, p, true, bonus);
  select name into nm from public.profiles where id = uid;
  update public.profiles set ref_code = 'AKD' || upper(substr(md5(uid::text), 1, 5)) where id = uid;
  rc := upper(trim(coalesce(p ->> 'ref', '')));
  if rc <> '' then
    select id into rid from public.profiles where ref_code = rc and id <> uid;
    if rid is not null then update public.profiles set referred_by = rid where id = uid; ref_ok := true; end if;
  end if;
  if bonus > 0 then perform public._txn(uid, 'वेलकम बोनस', bonus, 'क्रेडिट'); end if;
  perform public._log('signup', '✨ नया ग्राहक जुड़ा: ' || nm || ' (' || trim(p ->> 'phone') || ') • ' || trim(p ->> 'city') || ' - ' || trim(p ->> 'pincode'));
  return public._ok('खाता बन गया।', jsonb_build_object('existing', false, 'bonus', bonus, 'ref_ok', ref_ok));
end $$;

create or replace function public.update_profile(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  err text;
  nm text;
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है। अनब्लॉक के लिए सपोर्ट से संपर्क करें।'); end if;
  if not exists (select 1 from public.profiles where id = uid) then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  err := public._profile_error(p);
  if err is not null then return public._fail(err); end if;
  if exists (select 1 from public.profiles where phone = trim(p ->> 'phone') and id <> uid) then return public._fail('यह मोबाइल नंबर किसी और खाते में है।'); end if;
  perform public._save_profile_fields(uid, p, false, 0);
  select name into nm from public.profiles where id = uid;
  perform public._log('profile', '✏️ प्रोफ़ाइल अपडेट: ' || nm || ' (' || trim(p ->> 'phone') || ')');
  return public._ok('प्रोफ़ाइल सुरक्षित हुआ।');
end $$;

create or replace function public._coupon_calc(p_uid uuid, p_code text, p_amount int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  c public.coupons%rowtype;
  d int;
  cd text := upper(trim(coalesce(p_code, '')));
begin
  if cd = '' then return jsonb_build_object('ok', false, 'message', 'कूपन कोड लिखें।'); end if;
  select * into c from public.coupons where code = cd;
  if not found or not c.active then return jsonb_build_object('ok', false, 'message', 'यह कूपन सही नहीं है।'); end if;
  if c.expires_on is not null and c.expires_on < (now() at time zone 'Asia/Kolkata')::date then return jsonb_build_object('ok', false, 'message', 'यह कूपन समाप्त हो चुका है।'); end if;
  if p_amount < c.min_order then return jsonb_build_object('ok', false, 'message', 'यह कूपन ₹' || c.min_order || ' या ज़्यादा के ऑर्डर पर चलेगा।'); end if;
  if c.first_order_only and exists (select 1 from public.orders where user_id = p_uid and status <> 'rejected') then
    return jsonb_build_object('ok', false, 'message', 'यह कूपन सिर्फ़ पहले ऑर्डर पर चलता है।');
  end if;
  if c.once_per_user and exists (select 1 from public.orders where user_id = p_uid and coupon = c.code and status <> 'rejected') then
    return jsonb_build_object('ok', false, 'message', 'आप यह कूपन पहले इस्तेमाल कर चुके हैं।');
  end if;
  if c.kind = 'percent' then d := (p_amount * c.value) / 100; else d := c.value; end if;
  if c.max_discount is not null then d := least(d, c.max_discount); end if;
  d := least(d, p_amount - 1);
  if d < 1 then return jsonb_build_object('ok', false, 'message', 'इस ऑर्डर पर यह कूपन लागू नहीं होता।'); end if;
  return jsonb_build_object('ok', true, 'discount', d, 'code', c.code, 'message', '🎉 कूपन ' || c.code || ' लगा — ₹' || d || ' की बचत!');
end $$;

create or replace function public.validate_coupon(p_code text, p_item_id text, p_qty int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  it public.catalog%rowtype;
  amt int;
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  select * into it from public.catalog where id = p_item_id;
  if not found then return public._fail('यह आइटम उपलब्ध नहीं है।'); end if;
  if p_qty is null or p_qty < 1 or p_qty > 20 then return public._fail('मात्रा 1 से 20 के बीच रखें।'); end if;
  amt := it.price * p_qty;
  return public._coupon_calc(uid, p_code, amt) || jsonb_build_object('amount', amt);
end $$;

drop function if exists public.place_order(text, int, text, boolean, text, text);
drop function if exists public.place_order(text, int, text, boolean, text, text, text);
drop function if exists public.place_order(text, int, text, boolean, text, text, text, text);
create or replace function public.place_order(p_item_id text, p_qty int, p_slot text, p_bell boolean, p_mode text, p_utr text default null, p_coupon text default null, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  it public.catalog%rowtype;
  total int;
  oid text;
  st text;
  ps text;
  slot text;
  utr text := nullif(trim(coalesce(p_utr, '')), '');
  disc int := 0;
  cc text := null;
  cr jsonb;
  note text := nullif(trim(coalesce(p_note, p.delivery_instructions, '')), '');
  ord_addr text;
begin
  if uid is null then return public._fail('ऑर्डर के लिए पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है। अनब्लॉक के लिए सपोर्ट से संपर्क करें।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  select * into it from public.catalog where id = p_item_id;
  if not found then return public._fail('यह आइटम उपलब्ध नहीं है।'); end if;
  if it.out_of_stock then return public._fail('यह आइटम अभी आउट-ऑफ-स्टॉक है!'); end if;
  if extract(hour from (now() at time zone 'Asia/Kolkata')) >= 21 then return public._fail('रात 9:00 बजे के बाद ऑर्डर बंद है। कृपया सुबह 12 बजे के बाद ऑर्डर करें।'); end if;
  if p_qty is null or p_qty < 1 or p_qty > 20 then return public._fail('मात्रा 1 से 20 के बीच रखें।'); end if;
  if p_mode is null or p_mode not in ('wallet','upi','qr','cod') then return public._fail('भुगतान का तरीका सही नहीं है।'); end if;
  if not public._pay_enabled(p_mode) then return public._fail('यह भुगतान तरीका अभी बंद है।'); end if;
  slot := case when p_slot in ('5:30 AM - 7:00 AM', '7:00 AM - 8:30 AM', '5:00 PM - 7:30 PM') then p_slot else coalesce(p.default_slot, '5:30 AM - 7:00 AM') end;
  total := it.price * p_qty;
  if nullif(trim(coalesce(p_coupon, '')), '') is not null then
    cr := public._coupon_calc(uid, p_coupon, total);
    if not (cr ->> 'ok')::boolean then return public._fail(cr ->> 'message'); end if;
    disc := (cr ->> 'discount')::int; cc := cr ->> 'code'; total := total - disc;
    update public.coupons set used_count = used_count + 1 where code = cc;
  end if;

  if p_mode in ('upi','qr') then
    if utr is null or utr !~ '^[0-9]{12}$' then return public._fail('कृपया बैंक ऐप से 12 अंकों का वैध UTR नंबर दर्ज करें!'); end if;
    if public._utr_used(utr) then return public._fail('यह UTR पहले से दर्ज है!'); end if;
  else
    utr := case when p_mode = 'wallet' then 'WALLET_PAID' else 'COD' end;
  end if;

  if p_mode = 'wallet' then
    if p.wallet < total then return public._fail('वॉलेट बैलेंस कम है, पहले रिचार्ज करें।'); end if;
    update public.profiles set wallet = wallet - total where id = uid;
    perform public._txn(uid, it.name || ' ×' || p_qty || ' का ऑर्डर', -total, 'सफल');
  end if;

  oid := 'ORD-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
  st := case when p_mode in ('upi','qr') then 'pending' else 'approved' end;
  ps := case p_mode when 'wallet' then 'paid' when 'cod' then 'cod_due' else 'verifying' end;
  ord_addr := p.address || case when note is not null and p.address not like '%' || note || '%' then ' [निर्देश: ' || note || ']' else '' end;

  insert into public.orders(id, user_id, customer_name, phone, address, item_id, item, qty, unit_price, total, slot, bell, pay_mode, utr, status, pay_status, discount, coupon, delivery_note)
  values (oid, uid, p.name, p.phone, ord_addr, it.id, it.name, p_qty, it.price, total, slot, coalesce(p_bell, false), p_mode, utr, st, ps, disc, cc, note);

  perform public._log('order', '🛒 नया ऑर्डर: ' || p.name || ' (' || p.phone || ') • ' || it.name || ' ×' || p_qty || ' = ₹' || total || case when disc > 0 then ' (कूपन ' || cc || ' −₹' || disc || ')' else '' end ||
    ' • ' || case p_mode when 'wallet' then 'वॉलेट' when 'upi' then 'UPI ऐप' when 'qr' then 'QR स्कैन' else 'कैश ऑन डिलीवरी' end || ' • स्लॉट ' || slot || case when note is not null then ' • [नोट: ' || note || ']' else '' end);

  return public._ok('ऑर्डर दर्ज हुआ।', jsonb_build_object('order_id', oid, 'total', total, 'mode', p_mode, 'discount', disc, 'delivery_note', note));
end $$;

create or replace function public.submit_recharge(p_amount int, p_utr text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  utr text := trim(coalesce(p_utr, ''));
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है। अनब्लॉक के लिए सपोर्ट से संपर्क करें।'); end if;
  select * into p from public.profiles where id = uid;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  if not (public._pay_enabled('upi') or public._pay_enabled('qr')) then return public._fail('ऑनलाइन रिचार्ज अभी बंद है।'); end if;
  if p_amount is null or p_amount < 10 or p_amount > 50000 then return public._fail('राशि ₹10 से ₹50,000 के बीच दर्ज करें!'); end if;
  if utr !~ '^[0-9]{12}$' then return public._fail('कृपया बैंक ऐप से 12 अंकों का वैध UTR नंबर दर्ज करें!'); end if;
  if public._utr_used(utr) then return public._fail('यह UTR पहले से दर्ज है!'); end if;
  insert into public.recharges(id, user_id, customer_name, phone, amount, utr)
  values ('REC-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)), uid, p.name, p.phone, p_amount, utr);
  perform public._log('recharge', '💰 रिचार्ज अनुरोध: ' || p.name || ' (' || p.phone || ') • ₹' || p_amount || ' • UTR ' || utr);
  return public._ok('UTR दर्ज हुआ।');
end $$;

create or replace function public.set_subscription(p_items jsonb, p_start date, p_end date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  it public.catalog%rowtype;
  k text;
  q int;
  daily int := 0;
  days int;
  buf int;
  refund int := 0;
  earliest date;
  clean jsonb := '{}'::jsonb;
  summary text := '';
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  if p_items is null or jsonb_typeof(p_items) <> 'object' then return public._fail('कृपया आइटम चुनें।'); end if;
  if p_start is null or p_end is null then return public._fail('कृपया शुरू और अंतिम तारीख चुनें।'); end if;
  earliest := public._ist_today() + case when extract(hour from (now() at time zone 'Asia/Kolkata')) >= 21 then 2 else 1 end;
  if p_start < earliest then return public._fail('शुरू की तारीख ' || to_char(earliest, 'DD/MM/YYYY') || ' या उसके बाद की चुनें (रात 9 बजे के बाद ऑर्डर बंद रहता है)।'); end if;
  if p_end < p_start then return public._fail('अंतिम तारीख शुरू की तारीख से पहले नहीं हो सकती।'); end if;
  days := (p_end - p_start) + 1;
  if days > 92 then return public._fail('एक बार में अधिकतम 92 दिन का प्लान लें।'); end if;

  for k in select jsonb_object_keys(p_items) loop
    begin q := (p_items ->> k)::int; exception when others then q := 0; end;
    q := least(greatest(coalesce(q, 0), 0), 20);
    if q > 0 then
      select * into it from public.catalog where id = k;
      if found and not it.out_of_stock then
        daily := daily + it.price * q;
        clean := clean || jsonb_build_object(k, q);
        summary := summary || it.name || ' ×' || q || ', ';
      end if;
    end if;
  end loop;
  if daily = 0 then return public._fail('कृपया कम से कम 1 उपलब्ध आइटम चुनें।'); end if;
  buf := daily * days;

  -- पुराने प्लान के बचे हुए दिनों की राशि वापस
  if p.subscription is not null then
    if p.subscription ? 'endDate' then
      refund := coalesce((p.subscription ->> 'dailyCost')::int, 0) *
        greatest(0, ((p.subscription ->> 'endDate')::date) - greatest(((p.subscription ->> 'startDate')::date), public._ist_today() + 1) + 1);
      refund := least(refund, coalesce((p.subscription ->> 'advance')::int, refund));
    else
      refund := coalesce((p.subscription ->> 'buffer3Day')::int, 0);
    end if;
  end if;
  if p.wallet + refund < buf then return public._fail('वॉलेट में ₹' || (buf - p.wallet - refund) || ' कम हैं, पहले रिचार्ज करें।'); end if;

  if refund > 0 then perform public._txn(uid, 'पुराने प्लान के बचे दिनों की राशि वापस', refund, 'वापसी'); end if;
  perform public._txn(uid, 'एडवांस सब्सक्रिप्शन (' || to_char(p_start, 'DD/MM') || ' से ' || to_char(p_end, 'DD/MM') || ', ' || days || ' दिन)', -buf, 'कटौती');
  update public.profiles
     set wallet = wallet + refund - buf,
         subscription = jsonb_build_object('dailyCost', daily, 'advance', buf, 'days', days, 'items', clean,
           'startDate', to_char(p_start, 'YYYY-MM-DD'), 'endDate', to_char(p_end, 'YYYY-MM-DD'), 'status', 'Active')
   where id = uid;
  perform public._log('subscription', '📅 ' || p.name || ' (' || p.phone || ') का सब्सक्रिप्शन ' ||
    to_char(p_start, 'DD/MM/YYYY') || ' से ' || to_char(p_end, 'DD/MM/YYYY') || ' (' || days || ' दिन): ' || rtrim(summary, ', ') || ' • ₹' || daily || '/दिन • एडवांस ₹' || buf);
  return public._ok('सब्सक्रिप्शन सक्रिय हुआ।', jsonb_build_object('advance', buf, 'days', days));
end $$;

create or replace function public.cancel_subscription()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  old int;
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found or p.subscription is null then return public._fail('कोई सक्रिय सब्सक्रिप्शन नहीं है।'); end if;
  if p.subscription ? 'endDate' then
    old := coalesce((p.subscription ->> 'dailyCost')::int, 0) *
      greatest(0, ((p.subscription ->> 'endDate')::date) - greatest(((p.subscription ->> 'startDate')::date), public._ist_today() + 1) + 1);
    old := least(old, coalesce((p.subscription ->> 'advance')::int, old));
  else
    old := coalesce((p.subscription ->> 'buffer3Day')::int, 0);
  end if;
  update public.profiles set wallet = wallet + old, subscription = null where id = uid;
  if old > 0 then perform public._txn(uid, 'सब्सक्रिप्शन बंद - बचे दिनों की राशि वापस', old, 'वापसी'); end if;
  perform public._log('subscription', '🛑 ' || p.name || ' (' || p.phone || ') ने सब्सक्रिप्शन बंद किया');
  return public._ok('सब्सक्रिप्शन बंद हुआ।', jsonb_build_object('refund', old));
end $$;

create or replace function public.set_pause(p_pause boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  tmr date := public._ist_today() + 1;
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है। अनब्लॉक के लिए सपोर्ट से संपर्क करें।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  if p_pause then
    if extract(hour from (now() at time zone 'Asia/Kolkata')) >= 21 then
      return public._fail('रात 9:00 बजे के बाद कल की डिलीवरी रोकी नहीं जा सकती।');
    end if;
    update public.profiles set pause_for = tmr where id = uid;
    insert into public.pauses(id, user_id, type, customer, phone, date_text, for_date, detail)
    values ('PAUSE-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)), uid, 'कल का पॉज', p.name, p.phone, 'कल सुबह', tmr, 'दैनिक डिलीवरी रोकी गई');
    perform public._log('pause', '⏸ ' || p.name || ' (' || p.phone || ') ने कल की डिलीवरी रोकी');
  else
    update public.profiles set pause_for = null where id = uid;
    update public.pauses set status = 'ended' where user_id = uid and type = 'कल का पॉज' and for_date = tmr and status = 'active';
    perform public._log('pause', '▶ ' || p.name || ' (' || p.phone || ') ने कल की डिलीवरी फिर शुरू की');
  end if;
  return public._ok('ठीक है।');
end $$;

create or replace function public.set_vacation(p_start date, p_end date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है। अनब्लॉक के लिए सपोर्ट से संपर्क करें।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  if p_start is null or p_end is null then return public._fail('कृपया दोनों तिथियां चुनें!'); end if;
  if p_start < public._ist_today() then return public._fail('शुरू की तारीख आज या उसके बाद की हो।'); end if;
  if p_end < p_start then return public._fail('समाप्ति की तारीख शुरू की तारीख से पहले नहीं हो सकती।'); end if;
  update public.profiles set vac_active = true, vac_start = p_start, vac_end = p_end where id = uid;
  insert into public.pauses(id, user_id, type, customer, phone, date_text, end_date, detail)
  values ('VAC-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)), uid, 'लंबी छुट्टी', p.name, p.phone,
          to_char(p_start, 'DD/MM/YYYY') || ' से ' || to_char(p_end, 'DD/MM/YYYY'), p_end, 'सभी प्रोडक्ट्स बंद');
  perform public._log('vacation', '🏖 ' || p.name || ' (' || p.phone || ') की छुट्टी: ' || to_char(p_start, 'DD/MM/YYYY') || ' से ' || to_char(p_end, 'DD/MM/YYYY'));
  return public._ok('छुट्टी दर्ज हुई।');
end $$;

create or replace function public.extend_vacation(p_days int default 2)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  new_end date;
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  if not p.vac_active or p.vac_end is null then
    return public._fail('कोई सक्रिय छुट्टी नहीं है जिसे बढ़ाया जा सके।');
  end if;
  if p_days is null or p_days < 1 or p_days > 60 then
    return public._fail('दिन 1 से 60 के बीच होने चाहिए।');
  end if;
  new_end := p.vac_end + p_days;
  update public.profiles set vac_end = new_end where id = uid;
  insert into public.pauses(id, user_id, type, customer, phone, date_text, end_date, detail, status)
  values ('EXT-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)), uid, 'छुट्टी बढ़ाई', p.name, p.phone,
          to_char(p.vac_end, 'DD/MM/YYYY') || ' से +' || p_days || ' दिन (' || to_char(new_end, 'DD/MM/YYYY') || ')', new_end, 'छुट्टी +' || p_days || ' दिन बढ़ाई गई', 'active');
  perform public._log('vacation', '🏖 ' || p.name || ' (' || p.phone || ') ने छुट्टी +' || p_days || ' दिन बढ़ाई: ' || to_char(new_end, 'DD/MM/YYYY') || ' तक');
  return public._ok('छुट्टी ' || p_days || ' दिन और बढ़ा दी गई है (' || to_char(new_end, 'DD/MM/YYYY') || ' तक)।', jsonb_build_object('vac_end', to_char(new_end, 'YYYY-MM-DD')));
end $$;

create or replace function public.toggle_date_pause(p_date date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  tmr date := public._ist_today() + 1;
  arr jsonb;
  d_str text;
  is_paused boolean;
  is_cut boolean := (extract(hour from (now() at time zone 'Asia/Kolkata')) >= 21);
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  if p_date is null or p_date <= public._ist_today() then return public._fail('तारीख कल या उसके बाद की होनी चाहिए।'); end if;
  if p_date = tmr and is_cut and (p.pause_for is null or p.pause_for <> tmr) then
    return public._fail('⏰ रात 9:00 बजे के बाद कल की डिलीवरी नहीं रोकी जा सकती।');
  end if;

  arr := coalesce(p.paused_dates, '[]'::jsonb);
  d_str := to_char(p_date, 'YYYY-MM-DD');
  is_paused := (p.pause_for = p_date) or (arr @> to_jsonb(d_str)) or (p.vac_active and p_date between p.vac_start and p.vac_end);

  if is_paused then
    if p.pause_for = p_date then update public.profiles set pause_for = null where id = uid; end if;
    select coalesce(jsonb_agg(elem), '[]'::jsonb) into arr from jsonb_array_elements_text(arr) elem where elem <> d_str;
    update public.profiles set paused_dates = arr where id = uid;
    insert into public.pauses(id, user_id, type, customer, phone, date_text, for_date, detail, status)
    values ('RESUME-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)), uid, 'डिलीवरी शुरू', p.name, p.phone, to_char(p_date, 'DD/MM/YYYY'), p_date, 'डिलीवरी फिर शुरू की गई', 'ended');
    perform public._log('pause', '▶ ' || p.name || ' (' || p.phone || ') ने ' || to_char(p_date, 'DD/MM/YYYY') || ' की डिलीवरी फिर शुरू की');
    return public._ok(to_char(p_date, 'DD/MM/YYYY') || ' की डिलीवरी फिर से शुरू कर दी गई है!', jsonb_build_object('paused', false, 'date', d_str));
  else
    if not (arr @> to_jsonb(d_str)) then
      arr := arr || to_jsonb(d_str);
    end if;
    if p_date = tmr then
      update public.profiles set pause_for = tmr, paused_dates = arr where id = uid;
    else
      update public.profiles set paused_dates = arr where id = uid;
    end if;
    insert into public.pauses(id, user_id, type, customer, phone, date_text, for_date, detail, status)
    values ('PAUSE-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)), uid, 'तारीख पॉज', p.name, p.phone, to_char(p_date, 'DD/MM/YYYY'), p_date, 'कैलेंडर से डिलीवरी रोकी गई', 'active');
    perform public._log('pause', '⏸ ' || p.name || ' (' || p.phone || ') ने ' || to_char(p_date, 'DD/MM/YYYY') || ' की डिलीवरी रोकी');
    return public._ok(to_char(p_date, 'DD/MM/YYYY') || ' के लिए डिलीवरी रोक दी गई है (पॉज)।', jsonb_build_object('paused', true, 'date', d_str));
  end if;
end $$;

create or replace function public.resume_delivery()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है। अनब्लॉक के लिए सपोर्ट से संपर्क करें।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  update public.profiles set vac_active = false, pause_for = null, paused_dates = '[]'::jsonb where id = uid;
  update public.pauses set status = 'ended' where user_id = uid and status = 'active';
  perform public._log('vacation', '🚀 ' || p.name || ' (' || p.phone || ') ने डिलीवरी तत्काल फिर शुरू की');
  return public._ok('डिलीवरी फिर से शुरू।');
end $$;

create or replace function public.shift_delivery_slot(p_slot text, p_date date default null, p_permanent boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  tmr date := public._ist_today() + 1;
  d_str text;
  shifts jsonb;
  is_cut boolean := (extract(hour from (now() at time zone 'Asia/Kolkata')) >= 21);
begin
  if uid is null then return public._fail('पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है।'); end if;
  select * into p from public.profiles where id = uid for update;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;

  if p_slot not in ('5:30 AM - 7:00 AM', '7:00 AM - 8:30 AM', '5:00 PM - 7:30 PM') then
    return public._fail('अमान्य डिलीवरी स्लॉट।');
  end if;

  if p_permanent then
    update public.profiles set default_slot = p_slot where id = uid;
    perform public._log('slot_shift', '⏰ ' || p.name || ' (' || p.phone || ') ने स्थायी डिलीवरी स्लॉट बदला: ' || p_slot);
    return public._ok('स्थायी डिलीवरी स्लॉट ' || p_slot || ' सेट कर दिया गया है!', jsonb_build_object('slot', p_slot, 'permanent', true));
  end if;

  if p_date is null or p_date <= public._ist_today() then
    return public._fail('तारीख कल या उसके बाद की होनी चाहिए।');
  end if;

  if p_date = tmr and is_cut then
    return public._fail('⏰ रात 9:00 बजे के बाद कल की डिलीवरी का स्लॉट नहीं बदला जा सकता।');
  end if;

  d_str := to_char(p_date, 'YYYY-MM-DD');
  shifts := coalesce(p.slot_shifts, '{}'::jsonb) || jsonb_build_object(d_str, p_slot);
  update public.profiles set slot_shifts = shifts where id = uid;

  perform public._log('slot_shift', '⏰ ' || p.name || ' (' || p.phone || ') ने ' || to_char(p_date, 'DD/MM/YYYY') || ' का स्लॉट ' || p_slot || ' किया');
  return public._ok(to_char(p_date, 'DD/MM/YYYY') || ' के लिए स्लॉट ' || p_slot || ' सेट हो गया है!', jsonb_build_object('slot', p_slot, 'date', d_str, 'permanent', false));
end $$;

grant execute on function public.shift_delivery_slot(text, date, boolean) to anon, authenticated;

create or replace function public.log_chat(p_type text, p_text text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  t text := left(trim(coalesce(p_text, '')), 200);
begin
  if uid is null then return public._fail('लॉगिन नहीं है।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है। अनब्लॉक के लिए सपोर्ट से संपर्क करें।'); end if;
  if p_type not in ('complaint', 'chat') or t = '' then return public._fail('अमान्य।'); end if;
  select * into p from public.profiles where id = uid;
  if not found then return public._fail('प्रोफ़ाइल नहीं मिली।'); end if;
  perform public._log(p_type, case p_type when 'complaint' then '⚠️ ग्राहक समस्या — ' else '💬 चैट में अनुत्तरित सवाल — ' end
    || p.name || ' (' || p.phone || '): "' || t || '"');
  return public._ok();
end $$;

create or replace function public.log_auth(p_event text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
begin
  if uid is null then return public._fail('लॉगिन नहीं है।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है। अनब्लॉक के लिए सपोर्ट से संपर्क करें।'); end if;
  if p_event not in ('login', 'logout') then return public._fail('अमान्य।'); end if;
  select * into p from public.profiles where id = uid;
  if not found then return public._fail('प्रोफ़ाइल नहीं मिली।'); end if;
  perform public._log(p_event, case p_event when 'login' then '🔐 ' else '🚪 ' end || p.name || ' (' || p.phone || ') ने ' ||
    case p_event when 'login' then 'ईमेल OTP से लॉगिन किया' else 'लॉग आउट किया' end);
  return public._ok();
end $$;

create or replace function public.submit_feedback(p_rating int, p_text text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  t text := left(trim(coalesce(p_text, '')), 500);
begin
  if uid is null then return public._fail('फीडबैक देने के लिए पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है।'); end if;
  select * into p from public.profiles where id = uid;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then return public._fail('कृपया 1 से 5 स्टार चुनें।'); end if;
  if (select count(*) from public.feedback where user_id = uid and created_at > now() - interval '1 day') >= 5 then
    return public._fail('आज के लिए फीडबैक की सीमा पूरी हो गई, कल फिर लिखें।');
  end if;
  insert into public.feedback(user_id, customer_name, phone, rating, text) values (uid, p.name, p.phone, p_rating, nullif(t, ''));
  perform public._log('feedback', '⭐ फीडबैक ' || p_rating || '/5 — ' || p.name || ' (' || p.phone || ')' || case when t <> '' then ': "' || t || '"' else '' end);
  return public._ok('धन्यवाद! आपका फीडबैक मिल गया।');
end $$;

-- ---------------------------------------------------------------------
-- एडमिन के फ़ंक्शन (हर कॉल में पिन जाँचा जाता है; 5 गलत पिन पर 10 मिनट लॉक)
-- ---------------------------------------------------------------------
create or replace function public.admin_login(p_pin text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare s public.admin_secret%rowtype;
begin
  select * into s from public.admin_secret where id = 1;
  if found and s.locked_until is not null and s.locked_until > now() then
    return jsonb_build_object('ok', false, 'locked', true, 'message', 'कई बार गलत पिन। कुछ देर बाद कोशिश करें।');
  end if;
  if public._admin_ok(p_pin) then return public._ok(); end if;
  select * into s from public.admin_secret where id = 1;
  if found and s.locked_until is not null and s.locked_until > now() then
    return jsonb_build_object('ok', false, 'locked', true, 'message', 'कई बार गलत पिन। 10 मिनट बाद कोशिश करें।');
  end if;
  return public._fail('गलत पिन');
end $$;

create or replace function public.admin_dashboard(p_pin text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public._admin_ok(p_pin) then return public._fail('गलत पिन'); end if;
  return jsonb_build_object(
    'ok', true,
    'orders', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select id, user_id, customer_name, phone, address, item, qty, total, discount, coupon, slot, bell, pay_mode, utr, status, pay_status, delivered, delivery_note, out_for_delivery, created_at
        from public.orders order by created_at desc limit 150) x), '[]'::jsonb),
    'recharges', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select id, user_id, customer_name, phone, amount, utr, status, created_at
        from public.recharges order by created_at desc limit 150) x), '[]'::jsonb),
    'users', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select id, name, first_name, middle_name, last_name, phone, alt_phone, email, address, addr1, addr2, addr3, pincode, area, city, state, landmark, delivery_instructions, paused_dates, lat, lng, default_slot, slot_shifts, wallet, subscription, blocked, block_reason, created_at
        from public.profiles order by created_at desc limit 500) x), '[]'::jsonb),
    'pauses', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select id, type, customer, phone, date_text, for_date, end_date, detail, status, created_at
        from public.pauses order by created_at desc limit 100) x), '[]'::jsonb),
    'coupons', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select code, kind, value, min_order, max_discount, first_order_only, once_per_user, expires_on, note, active, listed, used_count
        from public.coupons order by created_at desc limit 100) x), '[]'::jsonb),
    'reviews', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select id, item_id, customer_name, rating, text, hidden, created_at
        from public.reviews order by id desc limit 100) x), '[]'::jsonb),
    'feedback', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select id, customer_name, phone, rating, text, created_at
        from public.feedback order by id desc limit 100) x), '[]'::jsonb),
    'activity', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select id, type, text, read, created_at
        from public.activity order by id desc limit 100) x), '[]'::jsonb)
  );
end $$;

create or replace function public.admin_do(p_pin text, p_action text, p_args jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  r public.recharges%rowtype;
  o public.orders%rowtype;
  p public.profiles%rowtype;
  v_id text := p_args ->> 'id';
  uid uuid;
  d int;
  nw int;
  k text;
  val jsonb;
  txt text;
  newpin text;
  allowed text[] := array['upi_id','payee_name','owner_wa','fssai','cow_fat','cow_snf','buf_fat','buf_snf','st1','st2','st3','st4','welcome_bonus','support_email','ref_bonus','ref_referrer_bonus','ref_new_customer_bonus','trust_lines'];
  m jsonb;
begin
  if not public._admin_ok(p_pin) then return public._fail('गलत पिन'); end if;

  if p_action = 'approve_recharge' then
    select * into r from public.recharges where id = v_id for update;
    if not found or r.status <> 'pending' then return public._fail('यह अनुरोध अब उपलब्ध नहीं है।'); end if;
    update public.recharges set status = 'approved' where id = v_id;
    update public.profiles set wallet = wallet + r.amount where id = r.user_id;
    perform public._txn(r.user_id, 'वॉलेट रिचार्ज स्वीकृत (UTR: ' || r.utr || ')', r.amount, 'स्वीकृत');
    return public._ok('✅ ₹' || r.amount || ' ग्राहक के वॉलेट में क्रेडिट हो गए!');

  elsif p_action = 'reject_recharge' then
    update public.recharges set status = 'rejected' where id = v_id and status = 'pending';
    if not found then return public._fail('यह अनुरोध अब उपलब्ध नहीं है।'); end if;
    return public._ok('❌ वॉलेट रिचार्ज अनुरोध अस्वीकृत किया गया।');

  elsif p_action = 'approve_order' then
    update public.orders set status = 'approved', pay_status = 'paid' where id = v_id and status = 'pending';
    if not found then return public._fail('यह ऑर्डर अब उपलब्ध नहीं है।'); end if;
    return public._ok('✅ ऑर्डर स्वीकृत किया गया!');

  elsif p_action = 'reject_order' then
    update public.orders set status = 'rejected' where id = v_id and status = 'pending';
    if not found then return public._fail('यह ऑर्डर अब उपलब्ध नहीं है।'); end if;
    return public._ok('❌ ऑर्डर अस्वीकृत किया गया।');

  elsif p_action = 'cod_paid' then
    update public.orders set pay_status = 'paid' where id = v_id and pay_mode = 'cod';
    if not found then return public._fail('ऑर्डर नहीं मिला।'); end if;
    return public._ok('💵 कैश प्राप्त दर्ज हुआ।');

  elsif p_action = 'out_for_delivery' then
    update public.orders set out_for_delivery = true where id = v_id and status = 'approved' and not delivered;
    if not found then return public._fail('ऑर्डर नहीं मिला या पहले से डिलीवर हो चुका है।'); end if;
    return public._ok('🚚 ऑर्डर डिलीवरी के लिए रवाना दर्ज हुआ।');

  elsif p_action = 'un_out_for_delivery' then
    update public.orders set out_for_delivery = false where id = v_id and status = 'approved';
    if not found then return public._fail('ऑर्डर नहीं मिला।'); end if;
    return public._ok('↩️ ऑर्डर वापस पैकिंग में दर्ज हुआ।');

  elsif p_action = 'delivered' then
    update public.orders set delivered = true, out_for_delivery = false where id = v_id and status = 'approved' returning user_id into uid;
    if not found then return public._fail('ऑर्डर नहीं मिला।'); end if;
    select * into p from public.profiles where id = uid for update;
    if found and p.referred_by is not null and not p.ref_paid then
      declare
        d_referrer int := 50;
        d_new_cust int := 50;
      begin
        select coalesce((value #>> '{}')::int, 50) into d_referrer from public.settings where key = 'ref_referrer_bonus';
        if d_referrer is null then
          select coalesce((value #>> '{}')::int, 50) into d_referrer from public.settings where key = 'ref_bonus';
        end if;
        select coalesce((value #>> '{}')::int, 50) into d_new_cust from public.settings where key = 'ref_new_customer_bonus';
        if d_new_cust is null then
          select coalesce((value #>> '{}')::int, 50) into d_new_cust from public.settings where key = 'ref_bonus';
        end if;
        d_referrer := coalesce(d_referrer, 0);
        d_new_cust := coalesce(d_new_cust, 0);
        update public.profiles set ref_paid = true where id = uid;
        if d_new_cust > 0 then
          update public.profiles set wallet = wallet + d_new_cust where id = uid;
          perform public._txn(uid, 'रेफ़र बोनस (पहला ऑर्डर)', d_new_cust, 'क्रेडिट');
        end if;
        if d_referrer > 0 then
          update public.profiles set wallet = wallet + d_referrer where id = p.referred_by;
          perform public._txn(p.referred_by, 'रेफ़र बोनस (मित्र ' || coalesce(p.name, 'मित्र') || ' का पहला ऑर्डर)', d_referrer, 'क्रेडिट');
        end if;
      end;
    end if;
    return public._ok('✅ ऑर्डर डिलीवर दर्ज हुआ।');

  elsif p_action = 'save_coupon' then
    declare cd text := upper(trim(coalesce(p_args ->> 'code', ''))); kd text := p_args ->> 'kind'; vl int; mo int; mx int; ex date;
    begin
      if cd !~ '^[A-Z0-9]{3,15}$' then return public._fail('कूपन कोड 3-15 अक्षर/अंक का हो (जैसे WELCOME50)'); end if;
      if kd not in ('percent','flat') then return public._fail('प्रकार चुनें: % या ₹'); end if;
      begin vl := (p_args ->> 'value')::int; exception when others then return public._fail('मान सही नहीं है।'); end;
      if vl is null or vl < 1 or (kd = 'percent' and vl > 90) or vl > 10000 then return public._fail('मान सही नहीं है (% में 1-90)।'); end if;
      begin mo := coalesce(nullif(p_args ->> 'min_order', '')::int, 0); mx := nullif(p_args ->> 'max_discount', '')::int; ex := nullif(p_args ->> 'expires_on', '')::date;
      exception when others then return public._fail('न्यूनतम/अधिकतम/तारीख सही नहीं है।'); end;
      insert into public.coupons(code, kind, value, min_order, max_discount, first_order_only, once_per_user, expires_on, note, active, listed)
      values (cd, kd, vl, greatest(mo, 0), mx, coalesce((p_args ->> 'first_order_only')::boolean, false), coalesce((p_args ->> 'once_per_user')::boolean, true), ex, left(coalesce(p_args ->> 'note', ''), 120), coalesce((p_args ->> 'active')::boolean, true), coalesce((p_args ->> 'listed')::boolean, true))
      on conflict (code) do update set kind = excluded.kind, value = excluded.value, min_order = excluded.min_order, max_discount = excluded.max_discount,
        first_order_only = excluded.first_order_only, once_per_user = excluded.once_per_user, expires_on = excluded.expires_on, note = excluded.note, active = excluded.active, listed = excluded.listed;
      return public._ok('✅ कूपन ' || cd || ' सुरक्षित हुआ।');
    end;

  elsif p_action = 'delete_coupon' then
    delete from public.coupons where code = upper(trim(coalesce(p_args ->> 'code', '')));
    return public._ok('कूपन हटा दिया।');

  elsif p_action = 'hide_review' then
    update public.reviews set hidden = coalesce((p_args ->> 'hidden')::boolean, true) where id = (p_args ->> 'id')::bigint;
    return public._ok('रिव्यू अपडेट हुआ।');

  elsif p_action = 'adjust_wallet' then
    begin uid := (p_args ->> 'uid')::uuid; exception when others then return public._fail('ग्राहक नहीं मिला।'); end;
    begin d := (p_args ->> 'delta')::int; exception when others then return public._fail('राशि सही नहीं है।'); end;
    if d is null or d = 0 or abs(d) > 100000 then return public._fail('राशि सही नहीं है।'); end if;
    select * into p from public.profiles where id = uid for update;
    if not found then return public._fail('ग्राहक नहीं मिला।'); end if;
    nw := greatest(0, p.wallet + d);
    update public.profiles set wallet = nw where id = uid;
    perform public._txn(uid, 'एडमिन द्वारा वॉलेट समायोजन', nw - p.wallet, 'समायोजित');
    return public._ok('वॉलेट में ' || case when d > 0 then '+' else '-' end || '₹' || abs(nw - p.wallet) || ' समायोजित हुआ!');

  elsif p_action = 'set_price' then
    begin
      d := (p_args ->> 'price')::int;
      nw := coalesce((p_args ->> 'mrp')::int, (select mrp from public.catalog where id = v_id));
    exception when others then return public._fail('सही मूल्य डालें'); end;
    if d is null or d <= 0 or d > 100000 then return public._fail('सही बिक्री भाव डालें'); end if;
    if nw is null or nw <= 0 or nw > 100000 then return public._fail('सही MRP डालें'); end if;
    if nw < d then return public._fail('MRP (कटा हुआ भाव) बिक्री भाव से कम नहीं हो सकता।'); end if;
    update public.catalog set price = d, mrp = nw where id = v_id;
    if not found then return public._fail('प्रोडक्ट नहीं मिला।'); end if;
    return public._ok('भाव अपडेट हुआ! MRP ₹' || nw || ', बिक्री ₹' || d);

  elsif p_action = 'set_image' then
    if coalesce(p_args ->> 'img', '') !~ '^(https://[^[:space:]<>"'']+|photos/[A-Za-z0-9._/-]+)$' or length(p_args ->> 'img') > 500 then return public._fail('सही फोटो लिंक डालें (https:// से शुरू, या photos/नाम.jpg)'); end if;
    update public.catalog set img = p_args ->> 'img' where id = v_id;
    if not found then return public._fail('प्रोडक्ट नहीं मिला।'); end if;
    return public._ok('फोटो अपडेट हुई!');

  elsif p_action = 'set_images' then
    if jsonb_typeof(p_args -> 'imgs') <> 'array' or jsonb_array_length(p_args -> 'imgs') < 1 or jsonb_array_length(p_args -> 'imgs') > 6 then
      return public._fail('1 से 6 फोटो लिंक डालें।');
    end if;
    for val in select value from jsonb_array_elements(p_args -> 'imgs') loop
      txt := val #>> '{}';
      if txt is null or length(txt) > 500 or txt !~ '^(https://[^[:space:]<>"'']+|photos/[A-Za-z0-9._/-]+)$' then
        return public._fail('हर लिंक https:// से शुरू हो (या photos/नाम.jpg): ' || left(coalesce(txt, ''), 40));
      end if;
    end loop;
    update public.catalog set img = (p_args -> 'imgs') ->> 0,
      imgs = coalesce((select jsonb_agg(v) from (select value v from jsonb_array_elements(p_args -> 'imgs') with ordinality t(value, n) where n > 1 order by n) z), '[]'::jsonb)
     where id = v_id;
    if not found then return public._fail('प्रोडक्ट नहीं मिला।'); end if;
    return public._ok('फोटो अपडेट हुईं!');

  elsif p_action = 'toggle_stock' then
    update public.catalog set out_of_stock = not out_of_stock where id = v_id;
    if not found then return public._fail('प्रोडक्ट नहीं मिला।'); end if;
    return public._ok('स्टॉक स्थिति अपडेट हुई!');

  elsif p_action = 'save_settings' then
    if jsonb_typeof(p_args -> 'settings') <> 'object' then return public._fail('सेटिंग सही नहीं है।'); end if;
    for k, val in select key, value from jsonb_each(p_args -> 'settings') loop
      if not (k = any (allowed)) then continue; end if;
      txt := trim(val #>> '{}');
      if k = 'upi_id' and txt !~ '^[A-Za-z0-9._-]{2,}@[A-Za-z]{2,}$' then return public._fail('सही UPI ID डालें (जैसे name@bank)'); end if;
      if k = 'owner_wa' and txt !~ '^[0-9]{11,13}$' then return public._fail('सही WhatsApp नंबर डालें'); end if;
      if k in ('cow_fat','cow_snf','buf_fat','buf_snf') and (txt !~ '^[0-9]{1,2}(\.[0-9]{1,2})?$' or txt::numeric > 20) then return public._fail('फैट/SNF 0 से 20 के बीच हो'); end if;
      if k in ('st1','st2','st3','st4') and txt !~* '^[0-9]{1,2}:[0-9]{2} ?(AM|PM)$' then return public._fail('समय ऐसे लिखें: 04:15 AM'); end if;
      if k = 'welcome_bonus' and (txt !~ '^[0-9]{1,4}$' or txt::int > 1000) then return public._fail('वेलकम बोनस 0 से 1000 के बीच हो'); end if;
      if k in ('ref_bonus','ref_referrer_bonus','ref_new_customer_bonus') and (txt !~ '^[0-9]{1,4}$' or txt::int > 2000) then return public._fail('रेफ़र बोनस 0 से 2000 के बीच हो'); end if;
      if k = 'trust_lines' and length(txt) > 600 then return public._fail('भरोसे वाली लाइनें 600 अक्षर से छोटी रखें'); end if;
      if k = 'support_email' and (txt !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' or length(txt) > 100) then return public._fail('सही सपोर्ट ईमेल डालें'); end if;
      if k in ('welcome_bonus','ref_bonus','ref_referrer_bonus','ref_new_customer_bonus') then
        insert into public.settings(key, value) values (k, to_jsonb(txt::int)) on conflict (key) do update set value = excluded.value;
      else
        insert into public.settings(key, value) values (k, to_jsonb(txt)) on conflict (key) do update set value = excluded.value;
      end if;
    end loop;
    return public._ok('✅ सेटिंग सुरक्षित हुई!');

  elsif p_action = 'set_pay_methods' then
    m := p_args -> 'methods';
    if jsonb_typeof(m) <> 'object' then return public._fail('सेटिंग सही नहीं है।'); end if;
    m := jsonb_build_object(
      'wallet', coalesce((m ->> 'wallet')::boolean, false),
      'upi', coalesce((m ->> 'upi')::boolean, false),
      'qr', coalesce((m ->> 'qr')::boolean, false),
      'cod', coalesce((m ->> 'cod')::boolean, false));
    if not (m @> '{"wallet":true}' or m @> '{"upi":true}' or m @> '{"qr":true}' or m @> '{"cod":true}') then
      return public._fail('❌ कम से कम एक भुगतान तरीका चालू रखें।');
    end if;
    insert into public.settings(key, value) values ('pay_methods', m) on conflict (key) do update set value = excluded.value;
    return public._ok('✅ भुगतान तरीके अपडेट हुए।');

  elsif p_action = 'change_pin' then
    newpin := p_args ->> 'new_pin';
    if newpin is null or newpin !~ '^[0-9]{4,8}$' then return public._fail('❌ नया पिन 4 से 8 अंकों का हो'); end if;
    update public.admin_secret set pin_hash = extensions.crypt(newpin, extensions.gen_salt('bf')), fails = 0, locked_until = null where id = 1;
    return public._ok('✅ एडमिन पिन बदल गया');

  elsif p_action = 'mark_read' then
    update public.activity set read = true where not read;
    return public._ok();

  elsif p_action = 'undeliver' then
    update public.orders set delivered = false where id = v_id and delivered;
    if not found then return public._fail('यह ऑर्डर डिलीवर दर्ज नहीं है।'); end if;
    return public._ok('↩️ डिलीवरी वापस "बाकी" की गई।');

  elsif p_action = 'uncollect' then
    update public.orders set pay_status = 'cod_due' where id = v_id and pay_mode = 'cod' and pay_status = 'paid';
    if not found then return public._fail('यह ऑर्डर नकद-प्राप्त दर्ज नहीं है।'); end if;
    return public._ok('↩️ नकद प्राप्ति वापस "बाकी" की गई।');

  elsif p_action = 'revert_order' then
    update public.orders set status = 'pending', pay_status = 'verifying', delivered = false
      where id = v_id and pay_mode in ('upi','qr') and status in ('approved','rejected');
    if not found then return public._fail('यह ऑर्डर वापस जांच में नहीं लाया जा सकता।'); end if;
    return public._ok('↩️ ऑर्डर फिर से जांच (pending) में गया।');

  elsif p_action = 'edit_order' then
    select * into o from public.orders where id = v_id for update;
    if not found then return public._fail('ऑर्डर नहीं मिला।'); end if;
    begin d := (p_args ->> 'qty')::int; nw := (p_args ->> 'total')::int; exception when others then return public._fail('मात्रा/राशि सही नहीं है।'); end;
    if d is null or d < 1 or d > 20 or nw is null or nw < 0 or nw > 100000 then return public._fail('मात्रा 1-20 और राशि 0-1,00,000 के बीच हो।'); end if;
    if o.pay_mode = 'wallet' and nw <> o.total then
      select * into p from public.profiles where id = o.user_id for update;
      if not found then return public._fail('ग्राहक नहीं मिला।'); end if;
      if p.wallet - (nw - o.total) < 0 then return public._fail('ग्राहक के वॉलेट में इतनी राशि नहीं है।'); end if;
      update public.profiles set wallet = wallet - (nw - o.total) where id = o.user_id;
      perform public._txn(o.user_id, 'एडमिन द्वारा ऑर्डर ' || o.id || ' सुधारा (₹' || o.total || ' → ₹' || nw || ')', o.total - nw, 'समायोजित');
    end if;
    update public.orders set qty = d, total = nw, unit_price = case when d > 0 then round(nw::numeric / d)::int else unit_price end where id = v_id;
    perform public._log('admin_edit', '✏️ एडमिन ने ऑर्डर ' || v_id || ' सुधारा: ×' || d || ' = ₹' || nw);
    return public._ok('✅ ऑर्डर सुधारा गया।');

  elsif p_action = 'revert_recharge' then
    select * into r from public.recharges where id = v_id for update;
    if not found or r.status not in ('approved','rejected') then return public._fail('यह रिचार्ज वापस जांच में नहीं लाया जा सकता।'); end if;
    if r.status = 'approved' then
      select * into p from public.profiles where id = r.user_id for update;
      if not found or p.wallet < r.amount then return public._fail('ग्राहक के वॉलेट में ₹' || r.amount || ' नहीं हैं, इसलिए वापस नहीं किया जा सकता।'); end if;
      update public.profiles set wallet = wallet - r.amount where id = r.user_id;
      perform public._txn(r.user_id, 'रिचार्ज वापस जांच में (UTR: ' || r.utr || ')', -r.amount, 'वापसी');
    end if;
    update public.recharges set status = 'pending' where id = v_id;
    return public._ok('↩️ रिचार्ज फिर से जांच (pending) में गया।');

  elsif p_action = 'edit_recharge' then
    select * into r from public.recharges where id = v_id for update;
    if not found then return public._fail('रिचार्ज नहीं मिला।'); end if;
    begin d := (p_args ->> 'amount')::int; exception when others then return public._fail('राशि सही नहीं है।'); end;
    if d is null or d < 10 or d > 50000 then return public._fail('राशि ₹10 से ₹50,000 के बीच हो।'); end if;
    if r.status = 'approved' and d <> r.amount then
      select * into p from public.profiles where id = r.user_id for update;
      if not found or p.wallet + (d - r.amount) < 0 then return public._fail('ग्राहक के वॉलेट में इतनी राशि नहीं है।'); end if;
      update public.profiles set wallet = wallet + (d - r.amount) where id = r.user_id;
      perform public._txn(r.user_id, 'एडमिन द्वारा रिचार्ज सुधारा (₹' || r.amount || ' → ₹' || d || ')', d - r.amount, 'समायोजित');
    end if;
    update public.recharges set amount = d where id = v_id;
    perform public._log('admin_edit', '✏️ एडमिन ने रिचार्ज ' || v_id || ' सुधारा: ₹' || d);
    return public._ok('✅ रिचार्ज राशि सुधारी गई।');

  elsif p_action = 'set_tracker' then
    begin d := (p_args ->> 'stage')::int; exception when others then return public._fail('स्टेप सही नहीं है।'); end;
    if d is null or d < 0 or d > 5 then return public._fail('स्टेप सही नहीं है।'); end if;
    if d = 0 then
      delete from public.settings where key = 'track_live';
      return public._ok('🔄 ट्रैकर अब घड़ी के समय से अपने-आप चलेगा।');
    end if;
    insert into public.settings(key, value) values ('track_live', jsonb_build_object('stage', d, 'date', public._ist_today()::text))
      on conflict (key) do update set value = excluded.value;
    txt := trim(coalesce(p_args ->> 'time', ''));
    if d between 1 and 4 and txt ~* '^[0-9]{1,2}:[0-9]{2} ?(AM|PM)$' then
      insert into public.settings(key, value) values ('st' || d, to_jsonb(upper(txt))) on conflict (key) do update set value = excluded.value;
    end if;
    return public._ok('✅ लाइव ट्रैकर अपडेट हुआ।');

  elsif p_action = 'block_user' then
    begin uid := (p_args ->> 'uid')::uuid; exception when others then return public._fail('ग्राहक नहीं मिला।'); end;
    select * into p from public.profiles where id = uid;
    if not found then return public._fail('ग्राहक नहीं मिला।'); end if;
    perform set_config('app.admin_action', 'on', true);
    if coalesce((p_args ->> 'blocked')::boolean, true) then
      update public.profiles set blocked = true, block_reason = left(nullif(trim(coalesce(p_args ->> 'reason', '')), ''), 200), blocked_at = now() where id = uid;
      perform public._log('admin_edit', '🚫 एडमिन ने ग्राहक ब्लॉक किया: ' || p.name || ' (' || p.phone || ')');
      return public._ok('🚫 ' || p.name || ' ब्लॉक हो गया।');
    else
      update public.profiles set blocked = false, block_reason = null, blocked_at = null where id = uid;
      perform public._log('admin_edit', '✅ एडमिन ने ग्राहक अनब्लॉक किया: ' || p.name || ' (' || p.phone || ')');
      return public._ok('✅ ' || p.name || ' अनब्लॉक हो गया।');
    end if;
  end if;

  return public._fail('अमान्य कार्रवाई।');
end $$;

-- ---------------------------------------------------------------------
-- शुरुआती डेटा (दोबारा चलाने पर बदलता नहीं)
-- ---------------------------------------------------------------------
insert into public.admin_secret(id, pin_hash)
values (1, extensions.crypt('PUT_YOUR_PIN_HERE', extensions.gen_salt('bf')))
on conflict (id) do nothing;

insert into public.settings(key, value) values
  ('pay_methods', '{"wallet":true,"upi":true,"qr":true,"cod":true}'),
  ('upi_id', '"7357911954-2@ybl"'),
  ('payee_name', '"Aaj Ki Dhaar"'),
  ('owner_wa', '"917357911954"'),
  ('fssai', '"12226026000189"'),
  ('cow_fat', '"4.4"'), ('cow_snf', '"8.7"'), ('buf_fat', '"8.2"'), ('buf_snf', '"9.3"'),
  ('st1', '"04:15 AM"'), ('st2', '"05:05 AM"'), ('st3', '"05:40 AM"'), ('st4', '"06:15 AM"'),
  ('welcome_bonus', '0'),
  ('ref_bonus', '50'),
  ('support_email', '"aajkidhaar.support@gmail.com"')
on conflict (key) do nothing;

update public.settings set value = '"Aaj Ki Dhaar"' where key = 'payee_name' and value = '"Aaj Ki Dhar"';

insert into public.catalog(id, cat, name, tag, unit, descr, mrp, price, img, imgs, sort) values
  ('cow_milk','milk','A2 गिर गाय का कच्चा दूध','देसी गिर गाय • 4 AM','1 लीटर','कांच बोतल, अनपाश्चुरीकृत प्राकृतिक धार',85,78,'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1517438322307-e67111335449?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1546445317-29f4545e9d53?auto=format&fit=crop&w=800&q=80"]'::jsonb,1),
  ('buffalo_milk','milk','देसी मुर्राह भैंस का गाढ़ा दूध','मुर्राह नस्ल • 8.2% फैट','1 लीटर','गाढ़ी मलाईदार धार, चाय व खीर स्पेशल',90,82,'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1517438322307-e67111335449?auto=format&fit=crop&w=800&q=80"]'::jsonb,2),
  ('paneer_fresh_white','paneer','ताजा शुद्ध सफेद पनीर (कच्चा ब्लॉक)','नींबू से फाड़ा • नो स्टार्च','250 ग्राम ब्लॉक','स्पंजी, मखमली सफेद कच्चा पनीर',130,115,'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1589881133595-a3c085cb731d?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=800&q=80"]'::jsonb,3),
  ('paneer_gir','paneer','A2 गिर गाय का ताजा सफेद पनीर','A2 गिर दूध','250 ग्राम','पचने में बेहद हल्का, प्रोटीन युक्त कच्चा पनीर',145,130,'https://images.unsplash.com/photo-1589881133595-a3c085cb731d?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1589881133595-a3c085cb731d?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=800&q=80"]'::jsonb,4),
  ('paneer_diet','paneer','डाइट लो-फैट ताजा सफेद पनीर','हाई प्रोटीन • लो कार्ब','250 ग्राम','जिम डाइट व सलाद के लिए कच्चा पनीर',120,105,'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1589881133595-a3c085cb731d?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=800&q=80"]'::jsonb,5),
  ('gir_ghee','ghee','A2 गिर गाय वैदिक बिलोना घी','लकड़ी की मथानी • स्वर्ण घी','500 ml कांच जार','मिट्टी की मटकी में दही बिलोकर निकाला घी',950,850,'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1608797178974-15b35a6119b6?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1546445317-29f4545e9d53?auto=format&fit=crop&w=800&q=80"]'::jsonb,6),
  ('buf_ghee','ghee','देसी मुर्राह भैंस का दानेदार घी','सफेद ताजा मक्खन से निर्मित','1 लीटर टिन','पारंपरिक दानेदार खुशबूदार भैंस का घी',800,720,'https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1608797178974-15b35a6119b6?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?auto=format&fit=crop&w=800&q=80"]'::jsonb,7),
  ('spinach','veggies','सीजनल ताजा पालक व मेथी बंच','रात की ताजी कटाई','500 ग्राम','ओस की बूंदों के साथ खेत से सीधे तोड़ी पत्तियां',45,35,'https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1546470427-227c7369a9b7?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1588252303782-cb80119abd6d?auto=format&fit=crop&w=800&q=80"]'::jsonb,8),
  ('desi_tomatoes','veggies','खेत के देसी लाल टमाटर','बिना केमिकल पके','1 किग्रा','खट्टा-मीठा स्वाद, पौधों से सीधे तोड़े गए',50,38,'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1546470427-227c7369a9b7?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1588252303782-cb80119abd6d?auto=format&fit=crop&w=800&q=80"]'::jsonb,9),
  ('chili_coriander','veggies','खेत की ताजी हरी मिर्च व हरा धनिया','दैनिक तड़का स्पेशल','250 ग्राम कॉम्बो','तीखी ताजी मिर्च और खुशबूदार देसी धनिया',28,20,'https://images.unsplash.com/photo-1588252303782-cb80119abd6d?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1588252303782-cb80119abd6d?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1546470427-227c7369a9b7?auto=format&fit=crop&w=800&q=80"]'::jsonb,10),
  ('seasonal_basket','veggies','दैनिक सीजनल ग्रीन वेजी बास्केट','4 मिक्स हरी सब्जियां','2 किग्रा कॉम्बो','ताजा तोरई, लौकी, शिमला मिर्च व हरी मिर्च',135,110,'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80','["https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1588252303782-cb80119abd6d?auto=format&fit=crop&w=800&q=80","https://images.unsplash.com/photo-1546470427-227c7369a9b7?auto=format&fit=crop&w=800&q=80"]'::jsonb,11)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- कौन सा फ़ंक्शन कौन कॉल कर सकता है
-- ---------------------------------------------------------------------
revoke all on function public.ensure_profile(jsonb) from public, anon;
revoke all on function public.update_profile(jsonb) from public, anon;
revoke all on function public.submit_recharge(int, text) from public, anon;
revoke all on function public.set_subscription(jsonb, date, date) from public, anon;
revoke all on function public.cancel_subscription() from public, anon;
revoke all on function public.set_pause(boolean) from public, anon;
revoke all on function public.toggle_date_pause(date) from public, anon;
revoke all on function public.set_vacation(date, date) from public, anon;
revoke all on function public.extend_vacation(int) from public, anon;
revoke all on function public.resume_delivery() from public, anon;
revoke all on function public.log_chat(text, text) from public, anon;
revoke all on function public.log_auth(text) from public, anon;
revoke all on function public.submit_feedback(int, text) from public, anon;
grant execute on function public.ensure_profile(jsonb) to authenticated;
grant execute on function public.update_profile(jsonb) to authenticated;
grant execute on function public.submit_recharge(int, text) to authenticated;
grant execute on function public.set_subscription(jsonb, date, date) to authenticated;
grant execute on function public.cancel_subscription() to authenticated;
grant execute on function public.set_pause(boolean) to authenticated;
grant execute on function public.toggle_date_pause(date) to authenticated;
grant execute on function public.set_vacation(date, date) to authenticated;
grant execute on function public.extend_vacation(int) to authenticated;
grant execute on function public.resume_delivery() to authenticated;
grant execute on function public.log_chat(text, text) to authenticated;
grant execute on function public.log_auth(text) to authenticated;
grant execute on function public.submit_feedback(int, text) to authenticated;

revoke all on function public.auth_precheck(text) from public;
grant execute on function public.auth_precheck(text) to anon, authenticated;

-- एडमिन फ़ंक्शन बिना लॉगिन के चलते हैं (पिन से सुरक्षित)
grant execute on function public.admin_login(text) to anon, authenticated;
grant execute on function public.admin_dashboard(text) to anon, authenticated;
grant execute on function public.admin_do(text, text, jsonb) to anon, authenticated;

-- ==== v4.3: रिव्यू, रेटिंग, भरोसे की लाइनें ====
insert into public.settings(key, value) values
  ('trust_lines', to_jsonb('🐄 जयपुर के हमारे फार्म से सीधे आपके घर
🥛 A2 गिर गाय व मुर्राह भैंस का देसी दूध
🔔 डिलीवरी पसंद: शांत, घंटी या कॉल — आप चुनें
💬 हर ऑर्डर पर सहायता: aajkidhaar.support@gmail.com'::text))
on conflict (key) do nothing;

create or replace function public.submit_review(p_item_id text, p_rating int, p_text text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.profiles%rowtype;
  t text := left(trim(coalesce(p_text, '')), 300);
  nm text;
  it public.catalog%rowtype;
begin
  if uid is null then return public._fail('रिव्यू देने के लिए पहले लॉगिन करें।'); end if;
  if public._blocked(uid) then return jsonb_build_object('ok', false, 'blocked', true, 'message', 'आपका खाता ब्लॉक है।'); end if;
  select * into p from public.profiles where id = uid;
  if not found then return public._fail('पहले प्रोफ़ाइल पूरी करें।'); end if;
  select * into it from public.catalog where id = p_item_id;
  if not found then return public._fail('यह आइटम नहीं मिला।'); end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then return public._fail('1 से 5 स्टार चुनें।'); end if;
  if not exists (select 1 from public.orders where user_id = uid and item_id = p_item_id and delivered = true and status = 'approved') then
    return public._fail('रिव्यू वही दे सकते हैं जिनका यह प्रोडक्ट डिलीवर हो चुका है।');
  end if;
  nm := coalesce(nullif(p.first_name, ''), split_part(p.name, ' ', 1)) || coalesce(' ' || left(nullif(p.last_name, ''), 1) || '.', '');
  insert into public.reviews(user_id, item_id, customer_name, rating, text) values (uid, p_item_id, nm, p_rating, nullif(t, ''))
  on conflict (user_id, item_id) do update set rating = excluded.rating, text = excluded.text, customer_name = excluded.customer_name, created_at = now(), hidden = false;
  perform public._log('review', '⭐ रिव्यू ' || p_rating || '/5 — ' || nm || ' • ' || it.name || case when t <> '' then ': "' || t || '"' else '' end);
  return public._ok('धन्यवाद! आपका रिव्यू जुड़ गया।');
end $$;

create or replace function public.product_reviews(p_item_id text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('ok', true,
    'avg', coalesce((select round(avg(rating)::numeric, 1) from public.reviews where item_id = p_item_id and not hidden), 0),
    'count', (select count(*) from public.reviews where item_id = p_item_id and not hidden),
    'reviews', coalesce((select jsonb_agg(to_jsonb(x)) from (
        select customer_name as name, rating, text, created_at from public.reviews
        where item_id = p_item_id and not hidden order by created_at desc limit 10) x), '[]'::jsonb))
$$;

create or replace function public.rating_summary()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(item_id, jsonb_build_object('avg', a, 'count', c)), '{}'::jsonb)
  from (select item_id, round(avg(rating)::numeric, 1) a, count(*) c from public.reviews where not hidden group by item_id) x
$$;

revoke all on function public._coupon_calc(uuid, text, int) from public, anon, authenticated;
revoke all on function public.validate_coupon(text, text, int) from public, anon;
revoke all on function public.submit_review(text, int, text) from public, anon;
revoke all on function public.place_order(text, int, text, boolean, text, text, text, text) from public, anon;
grant execute on function public.validate_coupon(text, text, int) to authenticated;
grant execute on function public.submit_review(text, int, text) to authenticated;
grant execute on function public.place_order(text, int, text, boolean, text, text, text, text) to authenticated;
grant execute on function public.product_reviews(text) to anon, authenticated;
grant execute on function public.rating_summary() to anon, authenticated;

create or replace function public.public_offers()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from (
    select code, kind, value, min_order, max_discount, first_order_only, note from public.coupons
    where active and listed and (expires_on is null or expires_on >= (now() at time zone 'Asia/Kolkata')::date)
    order by created_at desc limit 6) x
$$;
grant execute on function public.public_offers() to anon, authenticated;
