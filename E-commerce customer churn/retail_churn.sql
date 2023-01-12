/* find the first date each customer placed order */
SELECT customer_id, min(date) as first_order_date
FROM orders
GROUP BY customer_id;

/* calculate the interval between orders date and the first order date (period=30 days)*/
SELECT round(datediff(o.date,a.first_order_date)/30) as period,
count(distinct o.customer_id) as cohort_retained
FROM
(SELECT customer_id, min(date) as first_order_date
FROM orders
GROUP BY customer_id) a
JOIN orders as o on o.customer_id=a.customer_id
GROUP BY 1
ORDER BY period desc;

/* calculate the % of retained cohort of the period */
SELECT period,
first_value(cohort_retained) over (order by period) as cohort_size,
cohort_retained,
cohort_retained/first_value(cohort_retained) over (order by period) as pct_retained
FROM
(SELECT round(datediff(o.date,a.first_order_date)/30) as period,
count(distinct o.customer_id) as cohort_retained
FROM
(SELECT customer_id, min(date) as first_order_date
FROM orders
GROUP BY customer_id) a
JOIN orders as o on o.customer_id=a.customer_id
GROUP BY 1) t_a;

