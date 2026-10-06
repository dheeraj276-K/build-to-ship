-- Synthetic demonstration records only. These are not real organizations,
-- people, donations, or impact claims. Safe to run more than once.

with reference as (
  select
    array['Hyderabad', 'Bengaluru', 'Chennai', 'Mumbai', 'Delhi', 'Pune']::text[] as cities,
    array[17.3850, 12.9716, 13.0827, 19.0760, 28.6139, 18.5204]::numeric[] as lats,
    array[78.4867, 77.5946, 80.2707, 72.8777, 77.2090, 73.8567]::numeric[] as lngs,
    array[
      'Community Table', 'Open Arms Kitchen', 'Good Neighbour Food Bank',
      'Harbour Community Meals', 'City Share Pantry', 'Second Serving Kitchen',
      'The Welcome Table', 'Harvest Circle', 'Bright Days Shelter', 'Common Ground Pantry'
    ]::text[] as names
)
insert into public.organizations (
  id, owner_id, name, description, phone, email, address, latitude, longitude,
  capacity, accepted_food_types, verified, is_demo
)
select
  md5('foodbridge-demo-org-' || n)::uuid,
  null,
  r.names[n],
  'Synthetic demonstration organization for trying FoodBridge workflows.',
  null,
  null,
  r.cities[((n - 1) % 6) + 1] || ' · Demonstration pickup point',
  r.lats[((n - 1) % 6) + 1] + ((n % 4) * 0.006),
  r.lngs[((n - 1) % 6) + 1] + ((n % 3) * 0.007),
  100 + n * 20,
  case when n % 3 = 0
    then array['All']
    else array['Cooked Food', 'Bakery', 'Produce', 'Packaged Meals']
  end,
  true,
  true
from generate_series(1, 10) as n
cross join reference r
on conflict (id) do nothing;

with reference as (
  select
    array['Hyderabad', 'Bengaluru', 'Chennai', 'Mumbai', 'Delhi']::text[] as cities,
    array[17.3850, 12.9716, 13.0827, 19.0760, 28.6139]::numeric[] as lats,
    array[78.4867, 77.5946, 80.2707, 72.8777, 77.2090]::numeric[] as lngs,
    array[
      'Vegetable biryani trays', 'Fresh bread rolls', 'Seasonal fruit boxes',
      'Lentil curry portions', 'Packaged meal kits', 'Bakery assortment',
      'Fresh greens crates', 'Rice and dal portions', 'Breakfast snack packs',
      'Cooked vegetable bowls'
    ]::text[] as foods,
    array[
      'AVAILABLE', 'AVAILABLE', 'CLAIMED', 'COMPLETED', 'AVAILABLE',
      'PICKUP_ASSIGNED', 'AVAILABLE', 'EXPIRED', 'COMPLETED', 'AVAILABLE'
    ]::public.donation_status[] as statuses
)
insert into public.donations (
  id, donor_id, food_name, food_category, description, quantity, quantity_unit,
  prepared_at, expiry_at, pickup_address, latitude, longitude, food_condition,
  status, claimed_by, is_demo
)
select
  md5('foodbridge-demo-donation-' || n)::uuid,
  null,
  r.foods[((n - 1) % array_length(r.foods, 1)) + 1],
  case n % 5
    when 0 then 'Cooked Food'
    when 1 then 'Bakery'
    when 2 then 'Produce'
    when 3 then 'Packaged Meals'
    else 'Dairy'
  end,
  'Synthetic demonstration listing. Confirm handling requirements at pickup.',
  12 + (n * 3),
  case n % 5
    when 0 then 'servings'
    when 1 then 'pieces'
    when 2 then 'kg'
    when 3 then 'packs'
    else 'kg'
  end,
  now() - ((n % 5) + 1) * interval '1 hour',
  case when r.statuses[((n - 1) % 10) + 1] = 'EXPIRED'
    then now() - interval '30 minutes'
    else now() + ((n % 4) + 1) * interval '1 hour'
  end,
  'Demonstration pickup point · ' || r.cities[((n - 1) / 4) + 1],
  r.lats[((n - 1) / 4) + 1] + ((n % 5) * 0.004),
  r.lngs[((n - 1) / 4) + 1] + ((n % 4) * 0.005),
  'Packaged for pickup; verify condition on collection.',
  r.statuses[((n - 1) % 10) + 1],
  null,
  true
from generate_series(1, 20) as n
cross join reference r
on conflict (id) do nothing;

insert into public.volunteers (
  id, user_id, vehicle_type, availability, latitude, longitude, rating,
  total_pickups, is_demo
)
select
  md5('foodbridge-demo-volunteer-' || n)::uuid,
  null,
  (array['Bicycle', 'Scooter', 'Car', 'Walking'])[((n - 1) % 4) + 1],
  n % 3 <> 0,
  17.3850 + (n * 0.002),
  78.4867 + (n * 0.003),
  4.2 + ((n % 8) * 0.1),
  n * 2,
  true
from generate_series(1, 15) as n
on conflict (id) do nothing;

with reference as (
  select
    array['Positive', 'Neutral', 'Negative', 'Pickup', 'Food quality']::text[] as categories,
    array[
      'Collection was clear and well coordinated.',
      'The handoff took longer than expected.',
      'The portions worked well for our group.',
      'Pickup directions could be easier to find.',
      'The food arrived in good condition.',
      'More notice would help us plan volunteers.'
    ]::text[] as messages
)
insert into public.feedback (
  id, user_id, rating, category, message, sentiment, ai_summary,
  possible_improvement, is_demo
)
select
  md5('foodbridge-demo-feedback-' || n)::uuid,
  null,
  ((n - 1) % 5) + 1,
  r.categories[((n - 1) % array_length(r.categories, 1)) + 1],
  r.messages[((n - 1) % array_length(r.messages, 1)) + 1],
  case when ((n - 1) % 5) <= 1 then 'POSITIVE'
       when ((n - 1) % 5) = 2 then 'NEUTRAL'
       else 'NEGATIVE'
  end,
  'Synthetic feedback entry for demonstration.',
  'Use this sample to preview feedback triage; it is not a real recommendation.',
  true
from generate_series(1, 30) as n
cross join reference r
on conflict (id) do nothing;

with reference as (
  select
    array['Cooked rice', 'Bread', 'Vegetables', 'Prepared curry', 'Fruit']::text[] as foods,
    array['Overproduction', 'Late cancellation', 'Storage issue', 'Demand changed']::text[] as reasons,
    array['Dinner', 'Lunch', 'Breakfast', 'Snacks']::text[] as meals
)
insert into public.waste_logs (
  id, donor_id, food_name, meal_type, quantity, quantity_unit, reason, is_demo
)
select
  md5('foodbridge-demo-waste-' || n)::uuid,
  null,
  r.foods[((n - 1) % array_length(r.foods, 1)) + 1],
  r.meals[((n - 1) % array_length(r.meals, 1)) + 1],
  2 + (n % 15),
  case when n % 2 = 0 then 'kg' else 'portions' end,
  r.reasons[((n - 1) % array_length(r.reasons, 1)) + 1],
  true
from generate_series(1, 30) as n
cross join reference r
on conflict (id) do nothing;

with reference as (
  select array['OPEN', 'ASSIGNED', 'ON_THE_WAY', 'PICKED_UP', 'DELIVERED']::text[] as statuses
)
insert into public.pickup_tasks (
  id, donation_id, volunteer_id, ngo_id, pickup_address, delivery_address,
  scheduled_at, picked_up_at, delivered_at, status, is_demo
)
select
  md5('foodbridge-demo-task-' || n)::uuid,
  md5('foodbridge-demo-donation-' || n)::uuid,
  md5('foodbridge-demo-volunteer-' || (((n - 1) % 15) + 1))::uuid,
  md5('foodbridge-demo-org-' || (((n - 1) % 10) + 1))::uuid,
  'Demonstration donor location',
  'Demonstration community organization',
  now() + interval '1 hour',
  case when r.statuses[((n - 1) % 5) + 1] in ('PICKED_UP', 'DELIVERED')
       then now() - interval '30 minutes' else null end,
  case when r.statuses[((n - 1) % 5) + 1] = 'DELIVERED'
       then now() - interval '10 minutes' else null end,
  r.statuses[((n - 1) % 5) + 1],
  true
from generate_series(1, 20) as n
cross join reference r
on conflict (id) do nothing;
