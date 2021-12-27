-- 8 Week SQL Challenge: Case 2: Pizza Run


/* --------------------
A. Pizza Metrics
   --------------------*/

-- 1. How many pizzas were ordered?
select count(*)
from pizza_runner.customer_orders;

-- 2. How many unique customer orders were made?
select count(distinct order_id)
from pizza_runner.customer_orders;

-- 3. How many successful orders were delivered by each runner?
select count(distinct pickup_time)
from pizza_runner.runner_orders;

-- 4. How many of each type of pizza was delivered?
select count(distinct pickup_time)
from pizza_runner.runner_orders
where pickup_time != 'null';

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
select customer_id, 
	pizza_id, 
	count(*) 
from pizza_runner.customer_orders
group by customer_id, pizza_id
order by customer_id, pizza_id;

select customer_id, pizza_name, count(*) 
from pizza_runner.customer_orders c left join pizza_runner.pizza_names p
	on c.pizza_id = p.pizza_id
group by customer_id, pizza_name
order by customer_id, pizza_name;

-- 6. What was the maximum number of pizzas delivered in a single order?
select 
	max(npizza)
from (
	select 
  		c.order_id, 
  			count(pizza_id) as npizza
	from pizza_runner.customer_orders c 
	inner join pizza_runner.runner_orders r 
  	on c.order_id = r.order_id
	where r.pickup_time != 'null'
	group by c.order_id) num;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

create table t as
select customer_id,
		case when mod > 0 then 'modified' else 'unmodified' end as mod
from(        
	select
		c.customer_id,
		((case when c.exclusions in ('', 'null', NULL)  then 0 
		else 1 end) 
		 + (case when c.extras in ('', 'null', NULL)  then 0 
		else 1 end)) as mod
	from pizza_runner.customer_orders c 
	inner join pizza_runner.runner_orders r 
		on c.order_id = r.order_id
	where r.pickup_time != 'null') mod2
;


select customer_id, 
        mod, 
        count(mod)
from t
group by customer_id, mod
order by customer_id;   

drop table t;
		
-- 8. How many pizzas were delivered that had both exclusions and extras?
select count(mod)
from(        
	select
		c.customer_id,
		((case when c.exclusions in ('', 'null', NULL)  then 0 
		else 1 end) 
		 + (case when c.extras in ('', 'null', NULL)  then 0 
		else 1 end)) as mod
	from pizza_runner.customer_orders c 
	inner join pizza_runner.runner_orders r 
		on c.order_id = r.order_id
	where r.pickup_time != 'null') mod2
where mod > 1;


-- 9. What was the total volume of pizzas ordered for each hour of the day?
select 
    date_trunc('hour', order_time) as time,
	count(pizza_id)
from pizza_runner.customer_orders
group by date_trunc('hour', order_time)
order by date_trunc('hour', order_time);

-- 10. What was the volume of orders for each day of the week?
select to_char(order_time, 'day'),
	count(pizza_id)
from pizza_runner.customer_orders
group by to_char(order_time, 'day');


/* --------------------
B. Runner and Customer Experience
   --------------------*/
   
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select to_char(registration_date,'WW') as weekly,
count(*)
from pizza_runner.runners
group by weekly
order by weekly;
		--Great documentation at: https://www.postgresql.org/docs/9.6/functions-formatting.html
		
-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
create table t as     
	select c.order_id,
		r.runner_id, 
		c.order_time, 
		to_timestamp(r.pickup_time, 'YYYY-MM-DD HH24:MI:SS') as pickup_time 
	from pizza_runner.customer_orders c
	inner join pizza_runner.runner_orders r 
			on c.order_id = r.order_id
	where r.pickup_time != 'null';

select runner_id,
	avg(difference) as pickup_avg_min
from(    
	select runner_id,
		extract(minute from(pickup_time - order_time)) difference
	from t ) a
group by runner_id;	

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

create table npizza as
	select order_id,
		count(order_id) as number_pizza
	from t
	group by order_id;    

select number_pizza,
	avg(difference) pizza_time
from (	
	select distinct
		tm.order_id,
		tm.difference,
		npizza.number_pizza
	from (
	  select order_id,
		runner_id,
		extract(minute from(pickup_time - order_time)) difference
		from t) tm
	inner join npizza 
	on tm.order_id = npizza.order_id
	order by tm.order_id, npizza.number_pizza) pz
group by number_pizza
order by number_pizza;
	

-- 4. What was the average distance travelled for each customer?
select customer_id,
	round(avg(duration), 2) as delivery_time_min
from(    
	select distinct
		c.order_id,
		c.customer_id,
		r.runner_id, 
		NULLIF(regexp_replace(r.duration, '\D','','g'), '')::numeric as duration
	from pizza_runner.customer_orders c
	inner join pizza_runner.runner_orders r 
			on c.order_id = r.order_id
	where r.pickup_time != 'null') trav
group by customer_id
order by customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?

select 
	min(duration), 
	max(duration),
    (max(duration) - min(duration)) as difference  
from(    
	select 
		c.order_id,
		c.customer_id,
		r.runner_id, 
		NULLIF(regexp_replace(r.duration, '\D','','g'), '')::numeric as duration
	from pizza_runner.customer_orders c
	inner join pizza_runner.runner_orders r 
			on c.order_id = r.order_id
	where r.pickup_time != 'null') trav;
	
-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
select
	runner_id,
    order_id,
    round(distance/duration, 2) as km_per_min
from(
	select
		r.order_id,
		r.runner_id, 
		NULLIF(regexp_replace(r.distance, '[a-zA-Z]+','','g'), '')::numeric as distance,
		NULLIF(regexp_replace(r.duration, '\D','','g'), '')::numeric as duration
	from pizza_runner.runner_orders r 
	where r.pickup_time != 'null') trav
order by runner_id, order_id;
	-- runners are slowing down with subsequent deliveries

-- 7. What is the successful delivery percentage for each runner?
select a.runner_id,
	a.count,
	b.count,
	round(100 * (b.count/a.count), 2) as percent_success
from (
	select r.runner_id,
			cast(count(*) as decimal(5,2))
	from pizza_runner.runner_orders r 
	group by runner_id) a
inner join (
	select r.runner_id,
		cast(count(*) as decimal(5,2))
	from pizza_runner.runner_orders r 
	where r.pickup_time != 'null'
	group by runner_id) b
on a.runner_id = b.runner_id;


/* --------------------
C. Ingredient Optimisation
   --------------------*/
   
-- 1. What are the standard ingredients for each pizza?
select max(array_length(regexp_split_to_array(toppings,','),1))  
from pizza_runner.pizza_recipes;
--8
  
create table pizza_long as
with ptops as (
	SELECT pizza_id
		 , split_part(toppings, ',', 1) AS col1
		 , split_part(toppings, ',', 2) AS col2
		 , split_part(toppings, ',', 3) AS col3
		 , split_part(toppings, ',', 4) AS col4
		 , split_part(toppings, ',', 5) AS col5
		 , split_part(toppings, ',', 6) AS col6
		 , split_part(toppings, ',', 7) AS col7
		 , split_part(toppings, ',', 8) AS col8
	FROM   pizza_runner.pizza_recipes
)
select p.pizza_id, m.*
from ptops p
  cross join lateral (
    values (p.col1, 'col1'),
           (p.col2, 'col2'),
           (p.col3, 'col3'),
           (p.col4, 'col4'),
           (p.col5, 'col5'),
           (p.col6, 'col6'),
           (p.col7, 'col7'),
           (p.col8, 'col8')
  ) as m(topping_id, col_name);


select p.pizza_id,
	p.topping_id,
	t.topping_name
from 
	(select pizza_id, cast(topping_id as numeric)
	from pizza_long
	where topping_id != '') as p
inner join pizza_runner.pizza_toppings t
on p.topping_id = t.topping_id
--group by p.pizza_id
order by p.pizza_id, p.topping_id
;


/* Common standard topping
select p.topping_id,
	t.topping_name, 
	count(*)
from 
	(select pizza_id, cast(topping_id as numeric)
	from pizza_long
	where topping_id != '') as p
inner join pizza_runner.pizza_toppings t
on p.topping_id = t.topping_id
group by  
	p.topping_id,
	t.topping_name
order by count desc ;
*/

-- 2. What was the most commonly added extra?
create table t as
select 
	split_part(extras, ',',1) as col1
    , split_part(extras, ',',2) as col2
from pizza_runner.customer_orders
where extras not in ('', 'null');

select pt.topping_name,
	count(*)
from
	(select cast(e.topping_id as numeric)
	from t
		 cross join lateral (
		   values (t.col1, 'col1'),
				   (t.col2, 'col2')
		  ) as e(topping_id, col_name)
	 where topping_id <> ''
	 ) e
inner join pizza_runner.pizza_toppings pt
on e.topping_id = pt.topping_id
group by pt. topping_name
order by count desc
limit 1
;

-- 3. What was the most common exclusion?
create table t as
select 
	split_part(exclusions, ',',1) as col1
    , split_part(exclusions, ',',2) as col2
from pizza_runner.customer_orders
where exclusions not in ('', 'null');

select pt.topping_name,
	count(*)
from
	(select cast(e.topping_id as numeric)
	from t
		 cross join lateral (
		   values (t.col1, 'col1'),
				   (t.col2, 'col2')
		  ) as e(topping_id, col_name)
	 where topping_id <> ''
	 ) e
inner join pizza_runner.pizza_toppings pt
on e.topping_id = pt.topping_id
group by pt. topping_name
order by count desc
limit 1
;



-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
/*Meat Lovers
Meat Lovers - Exclude Beef
Meat Lovers - Extra Bacon
Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers */

create table t as
select * 
	, split_part(exclusions, ',',1) as exc1
    , split_part(exclusions, ',',2) as exc2
    , split_part(extras, ',',1) as ext1
    , split_part(extras, ',',2) as ext2
from pizza_runner.customer_orders
;


update t
set exc1 = nullif(regexp_replace(exc1, '[^0-9.]', '', 'g'), '')::int,
	exc2 = nullif(exc2, '')::int,
	ext1 = nullif(regexp_replace(ext1, '[^0-9.]', '', 'g'), '')::int,
	ext2 = nullif(ext2, '')::int
;

alter table t
alter column exc1 type int using exc1::integer
	, alter column exc2 type int using exc2::integer
	, alter column ext1 type int using ext1::integer
	, alter column ext2 type int using ext2::integer
;

create table pizza_allnames as 
select t.*  
    , pz.pizza_name
    , concat_ws(', ', pt.topping_name,
		pt2.topping_name) as exclusion_name
    , concat_ws(', ', et1.topping_name,
		et2.topping_name) as extras_name
from t
left join pizza_runner.pizza_names pz
on t.pizza_id = pz.pizza_id
left join pizza_runner.pizza_toppings pt
on t.exc1 = pt.topping_id
left join pizza_runner.pizza_toppings pt2
on t.exc2 = pt2.topping_id

left join pizza_runner.pizza_toppings et1
on t.ext1 = et1.topping_id
left join pizza_runner.pizza_toppings et2
on t.ext2 = et2.topping_id

order by order_id;


select (pizza_name || ' - Exclusion ' || exclusion_name || ' - Extras ' || extras_name) as full_name
from pizza_allnames;






-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--  For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

/* --------------------
D. Pricing and Ratings
   --------------------*/
   
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
-- 2. What if there was an additional $1 charge for any pizza extras?
--  Add cheese is $1 extra
-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
/*customer_id
order_id
runner_id
rating
order_time
pickup_time
Time between order and pickup
Delivery duration
Average speed
Total number of pizzas */
-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?


/* --------------------
E. Bonus Questions
   --------------------*/
-- If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

