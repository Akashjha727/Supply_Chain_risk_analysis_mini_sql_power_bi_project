--- Project Title:
-- Advanced Supply Chain and Customer Behavior Analysis Using SQL

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





