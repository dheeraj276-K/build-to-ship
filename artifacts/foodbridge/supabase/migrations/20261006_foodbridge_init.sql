-- FoodBridge application schema for Supabase PostgreSQL.
-- Run once in the Supabase SQL editor or with the Supabase CLI.

create extension if not exists pgcrypto;

do $$ begin
  create type public.foodbridge_role as enum ('DONOR', 'NGO', 'VOLUNTEER', 'ADMIN');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.donation_status as enum (
    'AVAILABLE', 'CLAIMED', 'PICKUP_ASSIGNED', 'PICKED_UP',
    'DELIVERED', 'COMPLETED', 'EXPIRED', 'CANCELLED'
  );
exception when duplicate_object then null;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'FoodBridge member',
  email text unique,
  phone text,
  role public.foodbridge_role not null default 'DONOR',
  avatar_url text,
  organization_name text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.donations (
  id uuid primary key default gen_random_uuid(),
  donor_id uuid references public.profiles(id) on delete set null,
  food_name text not null check (length(trim(food_name)) between 1 and 120),
  food_category text not null,
  description text,
  quantity numeric(12, 2) not null check (quantity > 0),
  quantity_unit text not null,
  prepared_at timestamptz not null,
  expiry_at timestamptz not null check (expiry_at > prepared_at),
  pickup_address text not null,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  food_condition text not null,
  image_url text,
  status public.donation_status not null default 'AVAILABLE',
  claimed_by uuid references public.profiles(id) on delete set null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  name text not null,
  description text,
  phone text,
  email text,
  address text not null,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  capacity numeric(12, 2) not null default 0 check (capacity >= 0),
  accepted_food_types text[] not null default '{}',
  verified boolean not null default false,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);

create unique index if not exists organizations_owner_id_unique
  on public.organizations(owner_id) where owner_id is not null;

create table if not exists public.volunteers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references public.profiles(id) on delete cascade,
  vehicle_type text not null default 'Bicycle',
  availability boolean not null default false,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  rating numeric(3, 2) not null default 0 check (rating between 0 and 5),
  total_pickups integer not null default 0 check (total_pickups >= 0),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.pickup_tasks (
  id uuid primary key default gen_random_uuid(),
  donation_id uuid not null unique references public.donations(id) on delete cascade,
  volunteer_id uuid references public.volunteers(id) on delete set null,
  ngo_id uuid not null references public.organizations(id) on delete cascade,
  pickup_address text not null,
  delivery_address text not null,
  scheduled_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  status text not null default 'OPEN'
    check (status in ('OPEN', 'ASSIGNED', 'ON_THE_WAY', 'PICKED_UP', 'DELIVERED', 'CANCELLED')),
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  rating integer not null check (rating between 1 and 5),
  category text not null,
  message text not null check (length(trim(message)) between 1 and 2000),
  sentiment text check (sentiment in ('POSITIVE', 'NEUTRAL', 'NEGATIVE')),
  ai_summary text,
  possible_improvement text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.waste_logs (
  id uuid primary key default gen_random_uuid(),
  donor_id uuid references public.profiles(id) on delete set null,
  food_name text not null,
  meal_type text not null,
  quantity numeric(12, 2) not null check (quantity >= 0),
  quantity_unit text not null,
  reason text not null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.impact_metrics (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null unique references public.organizations(id) on delete cascade,
  meals_rescued integer not null default 0 check (meals_rescued >= 0),
  food_saved_kg numeric(12, 2) not null default 0 check (food_saved_kg >= 0),
  donations_completed integer not null default 0 check (donations_completed >= 0),
  co2_saved_kg numeric(12, 2) not null default 0 check (co2_saved_kg >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists donations_donor_id_idx on public.donations(donor_id);
create index if not exists donations_status_idx on public.donations(status);
create index if not exists donations_expiry_at_idx on public.donations(expiry_at);
create index if not exists donations_created_at_idx on public.donations(created_at desc);
create index if not exists donations_location_idx on public.donations(latitude, longitude);
create index if not exists organizations_location_idx on public.organizations(latitude, longitude);
create index if not exists organizations_verified_idx on public.organizations(verified);
create index if not exists pickup_tasks_volunteer_status_idx on public.pickup_tasks(volunteer_id, status);
create index if not exists pickup_tasks_created_at_idx on public.pickup_tasks(created_at desc);
create index if not exists feedback_created_at_idx on public.feedback(created_at desc);
create index if not exists waste_logs_donor_id_idx on public.waste_logs(donor_id);
create index if not exists waste_logs_created_at_idx on public.waste_logs(created_at desc);
create index if not exists notifications_user_unread_idx on public.notifications(user_id, read, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists donations_set_updated_at on public.donations;
create trigger donations_set_updated_at before update on public.donations
for each row execute function public.set_updated_at();
drop trigger if exists organizations_set_updated_at on public.organizations;
create trigger organizations_set_updated_at before update on public.organizations
for each row execute function public.set_updated_at();
drop trigger if exists pickup_tasks_set_updated_at on public.pickup_tasks;
create trigger pickup_tasks_set_updated_at before update on public.pickup_tasks
for each row execute function public.set_updated_at();

create or replace function public.current_foodbridge_role()
returns public.foodbridge_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role from public.profiles as p where p.id = (select auth.uid()) limit 1;
$$;

create or replace function public.is_foodbridge_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.current_foodbridge_role() = 'ADMIN'::public.foodbridge_role, false);
$$;

grant execute on function public.current_foodbridge_role() to anon, authenticated;
grant execute on function public.is_foodbridge_admin() to anon, authenticated;

create or replace function public.create_foodbridge_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text;
begin
  requested_role := upper(coalesce(new.raw_user_meta_data ->> 'role', 'DONOR'));
  if requested_role not in ('DONOR', 'NGO', 'VOLUNTEER') then
    requested_role := 'DONOR';
  end if;

  insert into public.profiles (id, full_name, email, phone, role, organization_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'FoodBridge member'),
    new.email,
    nullif(trim(new.raw_user_meta_data ->> 'phone'), ''),
    requested_role::public.foodbridge_role,
    nullif(trim(new.raw_user_meta_data ->> 'organization_name'), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists foodbridge_profile_after_signup on auth.users;
create trigger foodbridge_profile_after_signup
after insert on auth.users
for each row execute function public.create_foodbridge_profile();

create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not public.is_foodbridge_admin() then
    new.role := old.role;
    new.is_demo := old.is_demo;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role before update on public.profiles
for each row execute function public.protect_profile_role();

alter table public.profiles enable row level security;
alter table public.donations enable row level security;
alter table public.organizations enable row level security;
alter table public.volunteers enable row level security;
alter table public.pickup_tasks enable row level security;
alter table public.feedback enable row level security;
alter table public.waste_logs enable row level security;
alter table public.impact_metrics enable row level security;
alter table public.notifications enable row level security;

drop policy if exists profiles_read_self_or_admin on public.profiles;
create policy profiles_read_self_or_admin on public.profiles
for select to authenticated
using (id = (select auth.uid()) or public.is_foodbridge_admin());
drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles
for update to authenticated
using (id = (select auth.uid()) or public.is_foodbridge_admin())
with check (id = (select auth.uid()) or public.is_foodbridge_admin());
drop policy if exists profiles_admin_all on public.profiles;
create policy profiles_admin_all on public.profiles
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

drop policy if exists donations_read_authorized on public.donations;
create policy donations_read_authorized on public.donations
for select to anon, authenticated
using (
  (is_demo and status = 'AVAILABLE')
  or (status = 'AVAILABLE' and public.current_foodbridge_role() in ('NGO', 'ADMIN'))
  or donor_id = (select auth.uid())
  or claimed_by = (select auth.uid())
  or public.is_foodbridge_admin()
);
drop policy if exists donations_insert_as_donor on public.donations;
create policy donations_insert_as_donor on public.donations
for insert to authenticated
with check (
  donor_id = (select auth.uid())
  and public.current_foodbridge_role() = 'DONOR'
  and status = 'AVAILABLE'
  and claimed_by is null
  and not is_demo
);
drop policy if exists donations_update_own_available on public.donations;
create policy donations_update_own_available on public.donations
for update to authenticated
using (
  donor_id = (select auth.uid())
  and status = 'AVAILABLE'
  and not is_demo
)
with check (
  donor_id = (select auth.uid())
  and status in ('AVAILABLE', 'CANCELLED')
  and claimed_by is null
  and not is_demo
);
drop policy if exists donations_admin_all on public.donations;
create policy donations_admin_all on public.donations
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

drop policy if exists organizations_read_verified_or_owner on public.organizations;
create policy organizations_read_verified_or_owner on public.organizations
for select to anon, authenticated
using (verified or owner_id = (select auth.uid()) or public.is_foodbridge_admin());
drop policy if exists organizations_insert_as_ngo on public.organizations;
create policy organizations_insert_as_ngo on public.organizations
for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and public.current_foodbridge_role() = 'NGO'
  and not verified
  and not is_demo
);
drop policy if exists organizations_update_owner on public.organizations;
create policy organizations_update_owner on public.organizations
for update to authenticated
using (owner_id = (select auth.uid()) and not is_demo)
with check (owner_id = (select auth.uid()) and not verified and not is_demo);
drop policy if exists organizations_admin_all on public.organizations;
create policy organizations_admin_all on public.organizations
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

drop policy if exists volunteers_read_self_or_admin on public.volunteers;
create policy volunteers_read_self_or_admin on public.volunteers
for select to authenticated
using (user_id = (select auth.uid()) or public.is_foodbridge_admin());
drop policy if exists volunteers_insert_self on public.volunteers;
create policy volunteers_insert_self on public.volunteers
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and public.current_foodbridge_role() = 'VOLUNTEER'
  and total_pickups = 0
  and rating = 0
  and not is_demo
);
drop policy if exists volunteers_update_self on public.volunteers;
create policy volunteers_update_self on public.volunteers
for update to authenticated
using (user_id = (select auth.uid()) and not is_demo)
with check (
  user_id = (select auth.uid())
  and not is_demo
  and total_pickups = (select v.total_pickups from public.volunteers v where v.id = volunteers.id)
  and rating = (select v.rating from public.volunteers v where v.id = volunteers.id)
);
drop policy if exists volunteers_admin_all on public.volunteers;
create policy volunteers_admin_all on public.volunteers
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

drop policy if exists pickup_tasks_read_participants on public.pickup_tasks;
create policy pickup_tasks_read_participants on public.pickup_tasks
for select to authenticated
using (
  public.is_foodbridge_admin()
  or (status = 'OPEN' and public.current_foodbridge_role() = 'VOLUNTEER')
  or exists (
    select 1 from public.organizations o
    where o.id = pickup_tasks.ngo_id and o.owner_id = (select auth.uid())
  )
  or exists (
    select 1 from public.donations d
    where d.id = pickup_tasks.donation_id and d.donor_id = (select auth.uid())
  )
  or exists (
    select 1 from public.volunteers v
    where v.id = pickup_tasks.volunteer_id and v.user_id = (select auth.uid())
  )
);
drop policy if exists pickup_tasks_admin_all on public.pickup_tasks;
create policy pickup_tasks_admin_all on public.pickup_tasks
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

drop policy if exists feedback_read_self_or_admin on public.feedback;
create policy feedback_read_self_or_admin on public.feedback
for select to authenticated
using (user_id = (select auth.uid()) or public.is_foodbridge_admin());
drop policy if exists feedback_insert_self on public.feedback;
create policy feedback_insert_self on public.feedback
for insert to authenticated
with check (user_id = (select auth.uid()) and not is_demo);
drop policy if exists feedback_admin_all on public.feedback;
create policy feedback_admin_all on public.feedback
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

drop policy if exists waste_logs_read_self_or_admin on public.waste_logs;
create policy waste_logs_read_self_or_admin on public.waste_logs
for select to authenticated
using (donor_id = (select auth.uid()) or public.is_foodbridge_admin());
drop policy if exists waste_logs_insert_self on public.waste_logs;
create policy waste_logs_insert_self on public.waste_logs
for insert to authenticated
with check (
  donor_id = (select auth.uid())
  and public.current_foodbridge_role() = 'DONOR'
  and not is_demo
);
drop policy if exists waste_logs_admin_all on public.waste_logs;
create policy waste_logs_admin_all on public.waste_logs
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

drop policy if exists impact_metrics_read_owner_or_admin on public.impact_metrics;
create policy impact_metrics_read_owner_or_admin on public.impact_metrics
for select to authenticated
using (
  public.is_foodbridge_admin()
  or exists (
    select 1 from public.organizations o
    where o.id = impact_metrics.organization_id and o.owner_id = (select auth.uid())
  )
);
drop policy if exists impact_metrics_admin_all on public.impact_metrics;
create policy impact_metrics_admin_all on public.impact_metrics
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

drop policy if exists notifications_read_self_or_admin on public.notifications;
create policy notifications_read_self_or_admin on public.notifications
for select to authenticated
using (user_id = (select auth.uid()) or public.is_foodbridge_admin());
drop policy if exists notifications_update_read_self on public.notifications;
create policy notifications_update_read_self on public.notifications
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
drop policy if exists notifications_admin_all on public.notifications;
create policy notifications_admin_all on public.notifications
for all to authenticated
using (public.is_foodbridge_admin())
with check (public.is_foodbridge_admin());

create or replace function public.create_donation_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  notice text;
begin
  if new.status is not distinct from old.status then return new; end if;
  notice := case new.status
    when 'CLAIMED' then 'Your donation has been claimed by an organization.'
    when 'PICKUP_ASSIGNED' then 'A volunteer has accepted the pickup.'
    when 'PICKED_UP' then 'Your donation has been picked up.'
    when 'DELIVERED' then 'Your donation has reached its destination.'
    when 'COMPLETED' then 'Your donation has been redistributed.'
    when 'CANCELLED' then 'Your donation was cancelled.'
    when 'EXPIRED' then 'Your donation has expired.'
    else null
  end;
  if notice is not null and new.donor_id is not null then
    insert into public.notifications (user_id, title, message, type)
    values (new.donor_id, 'Donation update', notice, 'DONATION_STATUS');
  end if;
  if new.status in ('PICKUP_ASSIGNED', 'PICKED_UP', 'DELIVERED', 'COMPLETED')
     and new.claimed_by is not null then
    insert into public.notifications (user_id, title, message, type)
    values (new.claimed_by, 'Pickup update', notice, 'PICKUP_STATUS');
  end if;
  return new;
end;
$$;

drop trigger if exists donation_status_notification on public.donations;
create trigger donation_status_notification
after update of status on public.donations
for each row execute function public.create_donation_notification();

create or replace function public.apply_completed_donation_impact()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient_org uuid;
  meal_count integer := 0;
  saved_kg numeric(12, 2) := 0;
begin
  if new.status <> 'COMPLETED' or old.status = 'COMPLETED' then return new; end if;

  select pt.ngo_id into recipient_org
  from public.pickup_tasks pt
  where pt.donation_id = new.id
  limit 1;
  if recipient_org is null then return new; end if;

  if lower(new.quantity_unit) in ('meal', 'meals', 'serving', 'servings', 'portion', 'portions') then
    meal_count := greatest(round(new.quantity)::integer, 0);
  end if;
  saved_kg := case lower(new.quantity_unit)
    when 'kg' then new.quantity
    when 'kgs' then new.quantity
    when 'kilogram' then new.quantity
    when 'kilograms' then new.quantity
    when 'g' then new.quantity / 1000
    when 'gram' then new.quantity / 1000
    when 'grams' then new.quantity / 1000
    when 'lb' then new.quantity * 0.453592
    when 'lbs' then new.quantity * 0.453592
    else 0
  end;

  insert into public.impact_metrics (
    organization_id, meals_rescued, food_saved_kg, donations_completed, co2_saved_kg
  ) values (
    recipient_org, meal_count, saved_kg, 1, round(saved_kg * 2.5, 2)
  )
  on conflict (organization_id) do update set
    meals_rescued = public.impact_metrics.meals_rescued + excluded.meals_rescued,
    food_saved_kg = public.impact_metrics.food_saved_kg + excluded.food_saved_kg,
    donations_completed = public.impact_metrics.donations_completed + 1,
    co2_saved_kg = public.impact_metrics.co2_saved_kg + excluded.co2_saved_kg,
    updated_at = now();

  update public.volunteers v
  set total_pickups = total_pickups + 1,
      availability = true
  from public.pickup_tasks pt
  where pt.donation_id = new.id and pt.volunteer_id = v.id;
  return new;
end;
$$;

drop trigger if exists donation_completion_impact on public.donations;
create trigger donation_completion_impact
after update of status on public.donations
for each row execute function public.apply_completed_donation_impact();

create or replace function public.claim_donation(p_donation_id uuid)
returns public.pickup_tasks
language plpgsql
security definer
set search_path = ''
as $$
declare
  claimed public.donations;
  recipient public.organizations;
  task public.pickup_tasks;
begin
  if (select auth.uid()) is null or public.current_foodbridge_role() <> 'NGO' then
    raise exception 'Only an authenticated NGO can claim donations.' using errcode = '42501';
  end if;

  select * into recipient
  from public.organizations
  where owner_id = (select auth.uid()) and verified = true
  limit 1;
  if recipient.id is null then
    raise exception 'A verified organization is required to claim donations.' using errcode = '42501';
  end if;

  update public.donations
  set status = 'CLAIMED', claimed_by = (select auth.uid())
  where id = p_donation_id and status = 'AVAILABLE'
    and expiry_at > now() and not is_demo
  returning * into claimed;
  if claimed.id is null then
    raise exception 'This donation is no longer available.' using errcode = 'P0001';
  end if;

  insert into public.pickup_tasks (
    donation_id, ngo_id, pickup_address, delivery_address, status
  ) values (
    claimed.id, recipient.id, claimed.pickup_address, recipient.address, 'OPEN'
  )
  returning * into task;
  return task;
end;
$$;

create or replace function public.accept_pickup(p_pickup_task_id uuid)
returns public.pickup_tasks
language plpgsql
security definer
set search_path = ''
as $$
declare
  courier public.volunteers;
  task public.pickup_tasks;
begin
  if (select auth.uid()) is null or public.current_foodbridge_role() <> 'VOLUNTEER' then
    raise exception 'Only an authenticated volunteer can accept pickups.' using errcode = '42501';
  end if;
  select * into courier from public.volunteers
  where user_id = (select auth.uid()) and availability = true and not is_demo
  limit 1;
  if courier.id is null then
    raise exception 'Set up an available volunteer profile first.' using errcode = '42501';
  end if;

  update public.pickup_tasks
  set volunteer_id = courier.id, status = 'ASSIGNED', scheduled_at = now()
  where id = p_pickup_task_id and status = 'OPEN' and not is_demo
  returning * into task;
  if task.id is null then
    raise exception 'This pickup is no longer available.' using errcode = 'P0001';
  end if;

  update public.volunteers set availability = false where id = courier.id;
  update public.donations set status = 'PICKUP_ASSIGNED'
  where id = task.donation_id and status = 'CLAIMED';
  return task;
end;
$$;

create or replace function public.update_pickup_status(
  p_pickup_task_id uuid,
  p_status text
)
returns public.pickup_tasks
language plpgsql
security definer
set search_path = ''
as $$
declare
  task public.pickup_tasks;
  expected_next text;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in to update a pickup.' using errcode = '42501';
  end if;

  select pt.* into task
  from public.pickup_tasks pt
  join public.volunteers v on v.id = pt.volunteer_id
  where pt.id = p_pickup_task_id
    and v.user_id = (select auth.uid())
    and not pt.is_demo
  for update of pt;
  if task.id is null then
    raise exception 'Pickup not found or not assigned to you.' using errcode = '42501';
  end if;

  expected_next := case task.status
    when 'ASSIGNED' then 'ON_THE_WAY'
    when 'ON_THE_WAY' then 'PICKED_UP'
    when 'PICKED_UP' then 'DELIVERED'
    else null
  end;
  if p_status is distinct from expected_next then
    raise exception 'Invalid pickup status transition.' using errcode = '22023';
  end if;

  update public.pickup_tasks
  set status = p_status,
      picked_up_at = case when p_status = 'PICKED_UP' then now() else picked_up_at end,
      delivered_at = case when p_status = 'DELIVERED' then now() else delivered_at end
  where id = p_pickup_task_id
  returning * into task;

  if p_status = 'PICKED_UP' then
    update public.donations set status = 'PICKED_UP'
    where id = task.donation_id and status = 'PICKUP_ASSIGNED';
  elsif p_status = 'DELIVERED' then
    update public.donations set status = 'COMPLETED'
    where id = task.donation_id and status = 'PICKED_UP';
  end if;

  return task;
end;
$$;

grant execute on function public.claim_donation(uuid) to authenticated;
grant execute on function public.accept_pickup(uuid) to authenticated;
grant execute on function public.update_pickup_status(uuid, text) to authenticated;

create or replace function public.get_public_impact()
returns table (
  meals_rescued bigint,
  food_saved_kg numeric,
  donations_completed bigint,
  co2_saved_kg numeric,
  organizations_helped bigint,
  volunteers_involved bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce(sum(im.meals_rescued), 0)::bigint,
    coalesce(sum(im.food_saved_kg), 0)::numeric,
    coalesce(sum(im.donations_completed), 0)::bigint,
    coalesce(sum(im.co2_saved_kg), 0)::numeric,
    (select count(distinct pt.ngo_id)
     from public.pickup_tasks pt
     join public.donations d on d.id = pt.donation_id
     where pt.status = 'DELIVERED' and d.status = 'COMPLETED' and not d.is_demo)::bigint,
    (select count(distinct pt.volunteer_id)
     from public.pickup_tasks pt
     join public.donations d on d.id = pt.donation_id
     where pt.status = 'DELIVERED' and d.status = 'COMPLETED'
       and pt.volunteer_id is not null and not d.is_demo)::bigint
  from public.impact_metrics im;
$$;

grant execute on function public.get_public_impact() to anon, authenticated;

create or replace function public.protect_notification_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not public.is_foodbridge_admin()
     and (
       new.user_id is distinct from old.user_id
       or new.title is distinct from old.title
       or new.message is distinct from old.message
       or new.type is distinct from old.type
       or new.created_at is distinct from old.created_at
     ) then
    raise exception 'Only the read state can be changed.' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists notifications_protect_fields on public.notifications;
create trigger notifications_protect_fields before update on public.notifications
for each row execute function public.protect_notification_update();

-- Supabase Storage: public food photos and avatars; private verification documents.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('food-images', 'food-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('organization-documents', 'organization-documents', false, 10485760, array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists foodbridge_public_images_read on storage.objects;
create policy foodbridge_public_images_read on storage.objects
for select to anon, authenticated
using (bucket_id in ('food-images', 'avatars'));
drop policy if exists foodbridge_owner_images_insert on storage.objects;
create policy foodbridge_owner_images_insert on storage.objects
for insert to authenticated
with check (
  bucket_id in ('food-images', 'avatars')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists foodbridge_owner_images_update on storage.objects;
create policy foodbridge_owner_images_update on storage.objects
for update to authenticated
using (
  bucket_id in ('food-images', 'avatars')
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id in ('food-images', 'avatars')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists foodbridge_owner_images_delete on storage.objects;
create policy foodbridge_owner_images_delete on storage.objects
for delete to authenticated
using (
  bucket_id in ('food-images', 'avatars')
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists foodbridge_org_documents_read on storage.objects;
create policy foodbridge_org_documents_read on storage.objects
for select to authenticated
using (
  bucket_id = 'organization-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_foodbridge_admin()
  )
);
drop policy if exists foodbridge_org_documents_insert on storage.objects;
create policy foodbridge_org_documents_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'organization-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.current_foodbridge_role() = 'NGO'
);
drop policy if exists foodbridge_org_documents_delete on storage.objects;
create policy foodbridge_org_documents_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'organization-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_foodbridge_admin()
  )
);

-- Realtime broadcasts are filtered by RLS for each signed-in participant.
do $$ begin
  alter publication supabase_realtime add table public.donations;
exception when duplicate_object then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.pickup_tasks;
exception when duplicate_object then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null;
end $$;
