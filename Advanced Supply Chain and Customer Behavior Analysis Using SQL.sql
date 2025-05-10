--- Project Title:
-- Supply Chain Customer & Risk Analytics Using SQL

---Customer Repeat Behavior Analysis (Advanced)


--Monthly comparatively Repeat Rate

with customer_orders AS (
SELECT
	Customer_Id,
	FORMAT(order_date_DateOrders,'yyyy-MM') as order_month
FROM DataCoSupplyChainData
),
first_order_months AS (
SELECT
	Customer_Id,
	MIN(FORMAT(order_date_DateOrders,'yyyy-MM')) as first_order_month
FROM DataCoSupplyChainData
GROUP BY Customer_Id),
combined AS (
SELECT 
	co.Customer_Id,
	co.order_month,
	CASE 
		WHEN co.order_month>fo.first_order_month THEN 1
		ELSE 0
	END AS is_repeat
FROM customer_orders co
JOIN first_order_months fo ON co.Customer_Id=fo.Customer_Id)
SELECT
	order_month,
	COUNT(DISTINCT Customer_Id) as Total_Customers,
	COUNT(DISTINCT CASE WHEN is_repeat =1 THEN Customer_Id END) as Repeat_customers,
	COUNT(DISTINCT CASE WHEN is_repeat = 0 THEN Customer_Id END) as new_customers,
	ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_repeat =1 THEN Customer_Id END) / 
	COUNT(DISTINCT Customer_Id),2) AS repeat_rate_percent
FROM combined
GROUP BY order_month
ORDER BY order_month;

--Repeat Behaviour within 30 days

WITH customer_orders AS(
SELECT 
	Customer_Id,
	order_date_DateOrders,
	FORMAT(order_date_DateOrders,'yyyy-MM') AS order_month
FROM DataCoSupplyChainData
),
repeat_flags AS (
SELECT 
	a.Customer_Id,
	a.order_month,
	CASE
		WHEN MIN(DATEDIFF (DAY,b.order_date_DateOrders,a.order_date_DateOrders)) BETWEEN 1 AND 30
		THEN 1
		ELSE 0
	END AS is_repeat_within_30days,
	CASE 
		WHEN COUNT(b.order_date_DateOrders) > 0 THEN 1
		ELSE 0
	END AS has_previous_order,
	CASE
		WHEN COUNT(b.order_date_DateOrders) = 0 THEN 1
		ELSE 0
	END AS is_new_customer
FROM customer_orders a
LEFT JOIN customer_orders b
 ON a.Customer_Id = b.Customer_Id
 AND a.order_date_DateOrders > b.order_date_DateOrders
GROUP BY a.Customer_Id,a.order_month,a.order_date_DateOrders)
SELECT 
	order_month,
	COUNT(DISTINCT Customer_Id) AS active_customers,
	COUNT(DISTINCT CASE WHEN is_repeat_within_30days =1 THEN Customer_Id END) AS repeated_customers_within_30_days,
	COUNT(DISTINCT CASE WHEN is_new_customer =1 THEN Customer_Id END) AS new_customers,
	ROUND(100.0* COUNT(DISTINCT CASE WHEN is_repeat_within_30days =1 THEN Customer_Id END) / COUNT(DISTINCT Customer_Id),2) As repeated_customer_within_30_days_rate,
	ROUND(100.0* COUNT(DISTINCT CASE WHEN is_repeat_within_30days =0 AND has_previous_order=1 THEN Customer_Id END) / COUNT(DISTINCT Customer_Id),2) As lost_customer_within_30_days_rate,
	ROUND(100.0* COUNT(DISTINCT CASE WHEN is_new_customer =1 THEN Customer_Id END) / COUNT(DISTINCT Customer_Id),2) AS New_customer_rate
FROM repeat_flags
GROUP BY order_month
ORDER BY order_month;


---- Late Delivery Risk by Region and Segment


with delivery_risk as (
SELECT 
	Order_Region,
	Customer_Segment,
	COUNT(*) AS total_orders,
	SUM(CASE WHEN Late_delivery_risk=1 THEN 1 ELSE 0 END) as late_orders
FROM DataCoSupplyChainData
GROUP BY Order_Region,Customer_Segment)
SELECT 
	Order_Region,
	Customer_Segment,
	total_orders,
	late_orders,
	ROUND(100.0*late_orders/NULLIF(total_orders,0),2) as late_delivery_orders
FROM delivery_risk
ORDER BY Order_Region,late_delivery_orders desc

---- Profitability Analysis by Customer where lifetime order is more than 5  & IS there any relation between order_profit and late_deliveries

with customer_profitability as (
SELECT 
 Customer_Id,
 COUNT(*) AS total_Orders,
 SUM(Order_Profit_Per_Order) as total_profit,
 SUM(CASE WHEN Late_delivery_risk=1 THEN 1 ELSE 0 END) as late_orders
FROM DataCoSupplyChainData
GROUP BY Customer_Id
HAVING COUNT(*) > 5)
SELECT 
	Customer_Id,
	total_Orders,
	total_profit,
	ROUND(total_profit/NULLIF(total_Orders,0),2) AS profit_per_order,
	late_orders,
	ROUND(100.0*late_orders/NULLIF(total_orders,0),2) AS late_delivery_rate_percent,
	CASE WHEN total_profit/NULLIF(total_Orders,0) > 0 THEN 'Profit' ELSE 'Loss' END AS profit_loss_segmentation_per_order
FROM customer_profitability
ORDER BY late_delivery_rate_percent desc,total_Orders desc,profit_per_order ASC;


---*** COHORT Analysis** --	
---- COHORT MONTH wise retention rate

with first_customer_month AS (
SELECT 
	Customer_Id,
	MIN(DATEFROMPARTS(Year(order_date_DateOrders),month(order_date_DateOrders),1)) as cohort_month
FROM DataCoSupplyChainData
WHERE year(order_date_DateOrders) BETWEEN 2016 AND 2019
GROUP BY Customer_Id),
orders_with_cohort as (
SELECT
	do.Customer_Id,
	do.Order_Id,
	DATEFROMPARTS(year(do.order_date_DateOrders),month(do.order_date_DateOrders),1) as order_month,
	fo.cohort_month,
	do.Order_Profit_Per_Order,
	do.Late_delivery_risk
FROM DataCoSupplyChainData do
JOIN first_customer_month fo ON do.Customer_Id=fo.Customer_Id
WHERE DATEFROMPARTS(year(do.order_date_DateOrders),month(do.order_date_DateOrders),1) >= fo.cohort_month),
Cohort_lifetime_data as (
SELECT
	order_month,
	cohort_month,
	DATEDIFF(month,cohort_month,order_month) as cohort_index,
	COUNT(DISTINCT Customer_Id) as total_customers,
	ROUND(SUM(Order_Profit_Per_Order),2) as total_profit,
	CAST(ROUND(AVG(CASE WHEN Late_delivery_risk=1 THEN 1.0 ELSE 0 END),2) AS FLOAT) as late_delivery_rate
FROM orders_with_cohort
GROUP BY order_month,cohort_month),
cohort_sizes as  (
SELECT 
	cohort_month,
	count(distinct customer_id) as initial_customers
FROM orders_with_cohort
WHERE DATEDIFF(month,cohort_month,order_month) = 0
GROUP BY cohort_month
)
SELECT 
	cld.*,
	CONCAT(ROUND (CAST(cld.total_customers AS float)*100.0 / cs.initial_customers,2), '%') as retention_rate
from Cohort_lifetime_data cld
JOIN cohort_sizes cs ON cld.cohort_month=cs.cohort_month
order by cohort_month;

--- Rolling AVG's focus on Sales, Profit, and Repeat Customer Behavior

--- Rolling Average of Monthly Sales (Past 3 Months)

WITH monthly_sales AS (
SELECT 
	FORMAT(order_date_DateOrders,'yyyy-MM') as order_month,
	SUM(Sales) AS total_sales
FROM DataCoSupplyChainData
GROUP BY FORMAT(order_date_DateOrders,'yyyy-MM')
)
SELECT 
	order_month,
	CAST(ROUND(total_sales,2) AS FLOAT) as Total_sales,
	CAST(ROUND(AVG(total_sales) OVER ( ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW ),2) AS FLOAT) as Rolling_3_month_sales_avg,
	CAST (ROUND(SUM(total_sales) OVER ( ORDER BY order_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),2) AS FLOAT) as Running_total_sales
FROM monthly_sales
ORDER BY order_month;

---  Rolling Avg of Monthly Profit per Order (Customer Segmentation)
with customer_monthly_profit as (
select
	Customer_Segment,
	CAST(DATEFROMPARTS(YEAR(order_date_DateOrders),MONTH(order_date_DateOrders),1) AS DATE) as Order_month,
	AVG(Order_Profit_Per_Order) as avg_profit
from DataCoSupplyChainData
GROUP BY Customer_Segment,CAST(DATEFROMPARTS(YEAR(order_date_DateOrders),MONTH(order_date_DateOrders),1) AS DATE))
SELECT 
	Customer_Segment,
	Order_month,
	ROUND(AVG(avg_profit) OVER (PARTITION BY Customer_Segment ORDER BY Order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) as rolling_avg_3_month
FROM customer_monthly_profit;

--- Rolling Repeat Customer Rate (Past 3 Months)
with customer_orders AS (
SELECT
	Customer_Id,
	DATEFROMPARTS(YEAR(order_date_DateOrders),MONTH(order_date_DateOrders),1) as order_month
FROM DataCoSupplyChainData),
first_order_month AS (
SELECT
	Customer_Id,
	MIN(DATEFROMPARTS(YEAR(order_date_DateOrders),MONTH(order_date_DateOrders),1)) as first_order_month
FROM DataCoSupplyChainData
GROUP BY Customer_Id
),
combined as (
SELECT 
 co.Customer_Id,
 co.order_month,
 CASE WHEN co.order_month > fo.first_order_month THEN 1 
	  ELSE 0
 END as is_repeat
FROM customer_orders co
JOIN first_order_month fo ON co.Customer_Id=fo.Customer_Id
),
monthly_behaviour AS (
SELECT
	order_month,
	COUNT(DISTINCT Customer_Id) as Total_customers,
	COUNT(DISTINCT CASE WHEN is_repeat =1 THEN Customer_Id END) as repeat_customers,
	CAST (ROUND(100.0* COUNT(DISTINCT CASE WHEN is_repeat =1 THEN Customer_Id END) / COUNT(DISTINCT Customer_Id),2) AS FLOAT) as repeat_rate_percent
FROM combined
GROUP BY order_month
)
SELECT order_month,
    repeat_rate_percent,
		AVG(repeat_rate_percent) OVER ( ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as rolling_repeat_rate_3_months
FROM monthly_behaviour;

Select 100.0* SUM(Case when Late_delivery_risk=1 THEN 1 ELSE 0 END)/ COUNT(*)
FROM DataCoSupplyChainData