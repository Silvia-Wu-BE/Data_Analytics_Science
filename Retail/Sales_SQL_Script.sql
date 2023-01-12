/*get the year,month,weekday of the line*/

/*convert date fields to date format*/
UPDATE sales
SET
date=str_to_date(Date,"%d/%m/%Y");

UPDATE features
SET
date=str_to_date(Date,"%d/%m/%Y");

/*How many Depts have sales higher than 20 million?*/
SELECT count(Dept) as DeptQuantitySalesHigherThan10Millions
FROM
(
SELECT Dept,sum(Weekly_Sales) as weekly_sales
FROM sales
GROUP BY Dept
) a
WHERE weekly_sales>20000000;

/*How many months per year have "high" "medium" "low" sales?*/

SELECT Year,sales_size,count(*)
FROM
(WITH cte AS (
SELECT Year,Month, SUM(Weekly_sales) as weekly_sales
FROM sales
GROUP BY Year,Month
)

SELECT Year,Month, weekly_sales,
case
when weekly_sales<=200000000 then "low"
when weekly_sales<=250000000 then "medium"
else "high" end AS sales_size
FROM cte) AS sales_size_table
GROUP BY 1,2;

/* Check the sales_bin per week*/
SELECT log(Weekly_Sales) as sales_bin,
count(Date) as weekQuantity
FROM sales
GROUP BY 1;

/* Check the spread over 10 of the sales */
SELECT tile,count(*)
FROM(
SELECT Date, ntile(10) over (partition by Weekly_Sales order by Weekly_Sales) tile
FROM sales) AS a
GROUP BY tile;


SELECT Year,Month,case when weekly_sales<=200000000 then "low"
when weekly_sales<=250000000 then "medium"
else "high" end as sales_category
 FROM
(
SELECT Year,Month, SUM(Weekly_sales) as weekly_sales
FROM sales
GROUP BY Year,Month
ORDER BY 3);

/* Store sales min, max, and total*/
SELECT store,min(Weekly_Sales),max(Weekly_Sales),sum(Weekly_Sales) as total_sales
FROM sales
GROUP BY store;

/* Check duplicate input*/
SELECT Date,Weekly_Sales,Store,Dept,count(*) as records
FROM sales
GROUP BY 1,2,3,4
HAVING records>1;

/* Check if there is markdown value in features*/
SELECT COALESCE(MarkDown1,MarkDown2,MarkDown3,MarkDown4,MarkDown5)
FROM features;

/* nullify the dates in sales if the date not within the "features" date range*/
SELECT nullif(Date,Date) as "Date is out of range"
FROM sales
WHERE Date<(SELECT min(Date) FROM features)
OR Date>(SELECT max(Date) FROM features)
OR Date is null;

/* Check if all the dates in sales are in the feature list*/
SELECT distinct s.Date
FROM sales s
LEFT JOIN features f on s.Date=f.Date
WHERE f.Date is null

/* Calculate store type A,B,C sales */
SELECT Year,
sum(case when store_type="A" then w_sales
else 0 
end) as Sales_A,
sum(case when store_type="B" then w_sales
else 0
end) as Sales_B,
sum(case when store_type="C" then w_sales
else 0
end) as Sales_C
FROM
(SELECT Weekly_Sales as w_sales,sales.Store,stores.Type as store_type,sales.Year as Year
FROM sales
LEFT JOIN stores
ON sales.Store=stores.Store) as sales_type
GROUP BY Year;


/* What is the % of monthly sales per store?*/
SELECT store,Year,Month,sum(monthly_sales)*100/sum(monthly_sales) over (partition by Year,Month) as pct
FROM(
SELECT store,Year,Month,sum(Weekly_Sales) as monthly_sales
FROM sales
GROUP BY 1,2,3) AS store_month
GROUP BY Year,Month,store
ORDER BY Year,Month,store;


/* Index sales */

SELECT Year,Month,sales,CONCAT(Year,"/",Month,"/","01") as Date,
(sales/first_value(sales) over (order by Year,Month)-1)*100 as index_sales
FROM
(
SELECT Year(Date) as Year,Month(Date) as Month,
sum(Weekly_Sales) as sales
FROM sales
GROUP BY 1,2
) as month_sales;

/*Index CPI*/
SELECT Year,Month,AVG(CPI),
(CPI/first_value(CPI) over (order by Year,Month)-1)*100 as index_cpi
FROM
(
SELECT Year(Date) as Year,Month(Date) as Month,avg(CPI) as CPI
FROM features
GROUP BY 1,2) as CPI
GROUP BY Year,Month;

/* Compare the sales per month with same month of previous year and the YTY increase by month*/
WITH monthly_sales as (SELECT Year(Date) as Year,Month(Date) as Month,
sum(Weekly_Sales) as month_sales
FROM sales
GROUP BY 1,2) 
SELECT a.Year,a.Month,a.month_sales as sales_of_year,b.month_sales as sales_of_last_year,(a.month_sales-b.month_sales)*100/b.month_sales as YTY_growth
FROM monthly_sales a
JOIN monthly_sales b on a.Year=b.Year+1
and a.Month=b.Month;



/* What is the rolling average of sales in the last three months? */
WITH monthly_sales as (SELECT Year(Date) as Year,Month(Date) as Month,
sum(Weekly_Sales) as month_sales
FROM sales
GROUP BY 1,2) 
SELECT Year, Month, AVG(month_sales) over (order by Year,Month 
rows between 2 preceding and current row ) as moving_avg_of_quarter,
count(month_sales) over (order by Year,Month 
rows between 2 preceding and current row ) as records_count
FROM monthly_sales;

/* What is the cumulative sales of YTD? */
WITH monthly_sales as 
(SELECT Year(Date) as Year,Month(Date) as Month,
sum(Weekly_Sales) as month_sales
FROM sales
GROUP BY 1,2) 
SELECT Year, Month, month_sales, sum(month_sales) over (partition by Year order by month) as sales_ytd
FROM monthly_sales;

/* What is the MoM sales growth? */
WITH monthly_sales as 
(SELECT Year(Date) as Year,Month(Date) as Month,
sum(Weekly_Sales) as month_sales
FROM sales
GROUP BY 1,2) 
SELECT Year, Month, month_sales as current_month_sales,
lag(Month) over (order by Year,Month) as pre_month,
lag(month_sales) over (order by Year,Month) as pre_month_salesd,(month_sales-lag(month_sales) over (order by Year,Month))*100/lag(month_sales) over (order by Year,Month) as growth_rate_from_previous_month
FROM monthly_sales;


/* Partition-Compare the sales per month with same month of previous year and the YTY increase by month*/
WITH monthly_sales as (SELECT DATE_ADD(LAST_DAY(Date),INTERVAL 1 DAY) as Month,
sum(Weekly_Sales) as month_sales
FROM sales
GROUP BY 1) 
SELECT Month,month_sales,
lag(Month) over (partition by month(Month)
order by Month) as prev_month,
lag(month_sales) over (partition by month(Month)
order by Month) as pre_month_sales,
(lag(month_sales) over (partition by month(Month)
order by Month)-month_sales)/month_sales*100 as pct_diff
FROM monthly_sales;

/* Compare monthly sales of three periods */
WITH monthly_sales as (SELECT DATE_ADD(LAST_DAY(Date),INTERVAL 1 DAY) as Month,
sum(Weekly_Sales) as month_sales
FROM sales
GROUP BY 1) 
SELECT Month,month_sales,
lag(month_sales,1) over (partition by month(Month)
order by Month) as pre_sales_1,
lag(month_sales,2) over (partition by month(Month)
order by Month) as pre_sales_2,
lag(month_sales,3) over (partition by month(Month)
order by Month) as pre_sales_3
FROM monthly_sales;
