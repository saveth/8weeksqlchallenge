-- 8 Week SQL Challenge: Case 1: Danny's Dinner


/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
select customer_id, sum(price)
from sales inner join menu on sales.product_id = menu.product_id
group by customer_id;


-- 2. How many days has each customer visited the restaurant?
select customer_id, count(distinct(order_date))
from sales
group by customer_id
order by customer_id;

-- 3. What was the first item from the menu purchased by each customer?
select distinct on (customer_id)
	customer_id 
	, product_name
from sales inner join menu on sales.product_id = menu.product_id       
--group by customer_id, product_name  
order by customer_id, order_date asc;
                                  
                                  
with added_row_number as (
select *,
	row_number() over(partition by customer_id order by order_date asc) as row_number
from sales inner join menu on sales.product_id = menu.product_id
)
select customer_id
	, product_name
from added_row_number
where row_number=1;
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select product_name
from menu inner join
	(select product_id, count(product_id) 
	from sales 
	group by product_id
	order by count(product_id) desc
	limit 1) a on menu.product_id = a.product_id;

select customer_id, count(*)
from sales
where product_id = (select product_id
	from sales 
	group by product_id
	order by count(product_id) desc
	limit 1)
group by customer_id
;

-- 5. Which item was the most popular for each customer?

select a.customer_id, a.product_id
from (select customer_id, product_id, count(product_id) 
	from dannys_diner.sales
	group by customer_id, product_id
    order by customer_id, count(*) desc) a
    
inner join (
  select customer_id, max(count) as max
      from (select customer_id, product_id, count(product_id) as count
            from dannys_diner.sales
            group by customer_id, product_id
            order by customer_id, count(*) desc) d
      group by customer_id) d
 on a.customer_id = d.customer_id and a.count = d.max      

-- 6. Which item was purchased first by the customer after they became a member?
select distinct on (customer_id)
	members.customer_id,
    menu.product_name
from dannys_diner.members
left join dannys_diner.sales 
on members.customer_id = sales.customer_id
inner join dannys_diner.menu on sales.product_id = menu.product_id
where order_date >= join_date
;
-- 7. Which item was purchased just before the customer became a member?
--Option 1: allows for tie
select sales.customer_id, menu.product_name
from dannys_diner.sales 
inner join dannys_diner.menu on sales.product_id = menu.product_id
inner join (
  select members.customer_id, max(sales.order_date)
  from dannys_diner.members
  left join dannys_diner.sales 
  on members.customer_id = sales.customer_id
  where order_date < join_date
  group by members.customer_id) f
on sales.customer_id = f.customer_id and sales.order_date = f.max
;

--Option 2: unique
select distinct on (members.customer_id)
*    
from dannys_diner.members
left join dannys_diner.sales 
on members.customer_id = sales.customer_id
inner join dannys_diner.menu on sales.product_id = menu.product_id
where order_date < join_date
order by members.customer_id, sales.order_date desc
;

-- 8. What is the total items and amount spent for each member before they became a member?

select members.customer_id, count(sales.product_id), sum(menu.price)
from dannys_diner.members
left join dannys_diner.sales 
on members.customer_id = sales.customer_id
inner join dannys_diner.menu on sales.product_id = menu.product_id
where order_date < join_date
group by members.customer_id
;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
select sales.customer_id
     , sum(p.points)  
from dannys_diner.sales
inner join (
  select product_id
    , case when product_name = 'sushi'
    		then price * 10 * 2
            else price * 10
       end as points
	from dannys_diner.menu) p
on sales.product_id = p.product_id
group by sales.customer_id

;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
select members.customer_id
	, sales.order_date
    , sales.product_id
    , 2 as new_member
from dannys_diner.members
left join dannys_diner.sales 
on members.customer_id = sales.customer_id
where order_date >= join_date and order_date <= (join_date +6)
;

select product_id
    , case when product_name = 'sushi'
    		then price * 10 * 2
            else price * 10
       end as points
	from dannys_diner.menu;

select sales.customer_id
     ,sales.order_date
     , p.points  
from dannys_diner.sales
inner join (
  select product_id
    , case when product_name = 'sushi'
    		then price * 10 * 2
            else price * 10
       end as points
	from dannys_diner.menu) p
on sales.product_id = p.product_id
--group by sales.customer_id
;



