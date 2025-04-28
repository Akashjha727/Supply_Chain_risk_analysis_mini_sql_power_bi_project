SELECT TOP (100) [Type]
      ,[Days_for_shipping_real]
      ,[Days_for_shipment_scheduled]
      ,[Benefit_per_order]
      ,[Sales_per_customer]
      ,[Delivery_Status]
      ,[Late_delivery_risk]
      ,[Category_Id]
      ,[Category_Name]
      ,[Customer_City]
      ,[Customer_Country]
      ,[Customer_Email]
      ,[Customer_Fname]
      ,[Customer_Id]
      ,[Customer_Lname]
      ,[Customer_Password]
      ,[Customer_Segment]
      ,[Customer_State]
      ,[Customer_Street]
      ,[Customer_Zipcode]
      ,[Department_Id]
      ,[Department_Name]
      ,[Latitude]
      ,[Longitude]
      ,[Market]
      ,[Order_City]
      ,[Order_Country]
      ,[Order_Customer_Id]
      ,[order_date_DateOrders]
      ,[Order_Id]
      ,[Order_Item_Cardprod_Id]
      ,[Order_Item_Discount]
      ,[Order_Item_Discount_Rate]
      ,[Order_Item_Id]
      ,[Order_Item_Product_Price]
      ,[Order_Item_Profit_Ratio]
      ,[Order_Item_Quantity]
      ,[Sales]
      ,[Order_Item_Total]
      ,[Order_Profit_Per_Order]
      ,[Order_Region]
      ,[Order_State]
      ,[Order_Status]
      ,[Order_Zipcode]
      ,[Product_Card_Id]
      ,[Product_Category_Id]
      ,[Product_Description]
      ,[Product_Image]
      ,[Product_Name]
      ,[Product_Price]
      ,[Product_Status]
      ,[shipping_date_DateOrders]
      ,[Shipping_Mode]
  FROM [Supply_Chain_Risk_analysis].[dbo].[DataCoSupplyChainData]

-- Project: Supplier Risk & Performance Analysis..

-- ** Late Delivery Risk analysis** --

--  1. Top Risk Suppliers by Country (Late Delivery Rate)

Select Order_Country,
	   count(*) as Total_Orders,
	   SUM(Case when Late_delivery_risk=1 THEN 1 ELSE 0 END) as late_deliveries,
	   ROUND(100.0*SUM(Case when Late_delivery_risk=1 THEN 1 ELSE 0 END)/count(*),2) as late_deliveries_ratio
from DataCoSupplyChainData
group by Order_country
ORDER BY late_deliveries_ratio desc;

--- 2. Average Delay vs. Scheduled Shipping Days


select Shipping_Mode,
	   AVG(CAST(Days_for_shipping_real AS INT)-CAST(Days_for_shipment_scheduled AS INT)) as avg_shipping_delays,
	   AVG(Days_for_shipping_real) as Avg_actual_days,
	   AVG(Days_for_shipment_scheduled) as Avg_scheduled_days
from DataCoSupplyChainData
GROUP BY Shipping_Mode;

-- 3. Profit Impact of Late Deliveries

select Late_delivery_risk,
	   COUNT(*) as num_orders,
	   ROUND(SUM(Order_Profit_Per_Order),2) as total_profit,
	   ROUND(AVG(Order_Profit_Per_Order),2) as avg_profit
from DataCoSupplyChainData
group by Late_delivery_risk;


---  5. Delivery Status Breakdown by Region

Select 
	Order_Region,
	Delivery_Status,
	COUNT(*) as order_count
from DataCoSupplyChainData
group by Order_Region,Delivery_Status
Order by Order_Region;

----  6. Time Series: Monthly Late Delivery Trend

SELECT 
    MONTH(order_date_DateOrders) as Ord_month,
	Count(*) as Total_orders,
	SUM(Case When Late_delivery_risk=1 THEN 1 ELSE 0 END) as late_deliveries
FROM DataCoSupplyChainData
GROUP BY MONTH(order_date_DateOrders)
ORDER BY Ord_month;


--- 7. Shipping Mode Efficiency by Segment

SELECT 
	Customer_Segment,
	Shipping_Mode,
	Count(*) As num_orders,
	ROUND(AVG(Days_for_shipping_real),2) as Avg_Shipping_time,
	ROUND(SUM(Order_Profit_Per_Order),2) As total_profit
FROM DataCoSupplyChainData
GROUP BY Customer_Segment,Shipping_Mode
ORDER BY total_profit desc;


--- Shipping Delay Impact by Region and category(Risk Score)

SELECT 
	Order_Region,
	Category_Name,
	SUM(CASE WHEN Late_delivery_risk =1 THEN 1 ELSE 0 END) as late_orders,
	ROUND(1.0 * SUM(CASE WHEN Late_delivery_risk =1 THEN 1 ELSE 0 END) / COUNT(*),2) as late_delivery_rate,
	ROUND(1.0 * SUM(CASE WHEN Order_Profit_Per_Order < 0 THEN 1 ELSE 0 END) / COUNT(*),2) as Negative_profit_ratio,
	ROUND(
		  (0.6 * 1.0 * SUM(CASE WHEN Late_delivery_risk=1 THEN 1 ELSE 0 END)/COUNT(*)) +
		  (0.4 * 1.0 * SUM(CASE WHEN Order_Profit_Per_Order <0  THEN 1 ELSE 0 END)/COUNT(*)),2
		  ) as supply_risk_score
FROM DataCoSupplyChainData
GROUP BY Order_Region,Category_Name
ORDER BY Order_Region ASC,supply_risk_score DESC;

--- Late Delivery Risk Trend Over Time (Rolling Analysis)

SELECT 
	 FORMAT(order_date_DateOrders,'yyyy-MM') AS month,
	 COUNT(*) AS Total_orders,
	 SUM(CASE WHEN Late_delivery_risk=1 THEN 1 ELSE 0 END) as late_orders,
	 ROUND(1.0* SUM(CASE WHEN Late_delivery_risk=1 THEN 1 ELSE 0 END)/COUNT(*),2) as delivery_rate
FROM DataCoSupplyChainData
GROUP BY FORMAT(order_date_DateOrders,'yyyy-MM')
Order By month;

--- Late Delivery Risk Trend by Region and Time
-- Goal: Understand how late delivery risk is trending in each region monthly.

With Monthly_late as (
Select 
	FORMAT(order_date_DateOrders,'yyyy-MM') as Order_month,
	Order_Region,
	AVG(CAST(Late_delivery_risk as float)) as late_delivery_rate
from DataCoSupplyChainData
GROUP BY FORMAT(order_date_DateOrders,'yyyy-MM'),Order_Region)
SELECT *,
	AVG(late_delivery_rate) OVER (PARTITION BY Order_Region ORDER BY Order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as rolling_3_month_avg
FROM Monthly_late;

--- Shipping Delay Detection

SELECT
	Order_Id,
	Days_for_shipping_real,
	Days_for_shipment_scheduled,
	CASE
		WHEN Days_for_shipping_real > Days_for_shipment_scheduled THEN 1 ELSE 0 END AS is_late
FROM DataCoSupplyChainData;

---*** COHORT Analysis** --

----    What Is True Cohort Analysis in ERP or eCommerce Context?
---- Cohort analysis helps you answer questions like:

--- How long do new customers stay profitable?

--- How does supplier delivery performance evolve over time from onboarding?

--- Do newer cohorts of customers generate more or less revenue over time?

---- Advanced SQL Cohort Analysis: Profit and Delivery Risk Over Time


WITH customer_first_order AS (
select Customer_id,
	   DATETRUNC(month,MIN (order_date_DateOrders)) as cohort_month
from DataCoSupplyChainData
where year(order_date_DateOrders) BETWEEN 2016 AND 2019
Group By Customer_id),
orders_with_cohort AS 
(select do.Customer_id,
	   do.Order_Id,
	   DATETRUNC(month,do.order_date_DateOrders) as order_month,
	   cfo.cohort_month,
	   do.Order_Profit_Per_Order,
	   do.Late_delivery_risk
from DataCoSupplyChainData do
JOIN customer_first_order cfo
ON do.Customer_id=cfo.Customer_id
WHERE DATETRUNC(month, do.order_date_DateOrders) >= cfo.cohort_month),
cohort_lifetime_data AS (
Select 
	cohort_month,
	order_month,
	DATEDIFF(MONTH,cohort_month,order_month) as cohort_index,
	count(distinct Customer_id) as active_customers,
	ROUND(SUM(Order_Profit_Per_Order),2) AS total_profit,
	ROUND(AVG(CASE WHEN Late_delivery_risk = 1 THEN 1.0 ELSE 0 END),2) AS late_delivery_rate
FROM orders_with_cohort
GROUP BY cohort_month,order_month),
cohort_sizes AS (
SELECT cohort_month,
       count(distinct Customer_id) as initial_customers
FROM orders_with_cohort
WHERE DATEDIFF(month,cohort_month,order_month) =0
GROUP BY cohort_month)
SELECT cld.*,
	   CONCAT (ROUND (CAST(cld.active_customers AS FLOAT) *100.0 / cs.initial_customers,2) , ' %') As Retention_rate
FROM cohort_lifetime_data cld
JOIN cohort_sizes cs 
	 ON cld.cohort_month=cs.cohort_month
ORDER BY cld.cohort_month,cld.cohort_index;


---*** 4. Monthly Customer Dropoff Cohort (like Retention)***
----Concepts Used: COHORT + TIME WINDOW + RETENTION-----

with customer_first_order as (
SELECT 
	Customer_Id,
	MIN(DATEFROMPARTS(YEAR(order_date_DateOrders),MONTH(order_date_DateOrders),1)) as Cohort_month
FROM DataCoSupplyChainData
GROUP BY Customer_Id),
orders_with_cohort AS (
SELECT 
	d.Customer_Id,
	d.Order_Id,
	DATEFROMPARTS(YEAR(d.order_date_DateOrders),MONTH(d.order_date_DateOrders),1) as Order_month,
	c.Cohort_month
FROM DataCoSupplyChainData d
JOIN customer_first_order c ON c.Customer_Id=d.Customer_Id),
Cohort_data as (
SELECT
	Cohort_month,
	Order_month,
	DATEDIFF(MONTH,Cohort_month,Order_month) as Cohort_index,
	Count(DISTINCT Customer_Id) as Active_customers
FROM orders_with_cohort
GROUP BY Cohort_month,Order_month),
base_counts as (
SELECT 
	Cohort_month,
	MAX(CASE WHEN Cohort_index = 0 THEN Active_customers END) As Cohort_Size
FROM Cohort_data
GROUP BY Cohort_month)
SELECT
	c.Cohort_month,
	c.Order_month,
	c.Cohort_index,
	c.Active_customers,
	b.Cohort_Size,
	ROUND(100.0 * c.Active_customers/b.Cohort_Size,2) As retention_rate
FROM Cohort_data c
JOIN base_counts b ON c.Cohort_month=b.Cohort_month
ORDER BY c.Cohort_month,c.Cohort_index;




--** Profit,Loss,Sales,Risk ANalysiss**--

----  Anomaly Detection: Negative Profits on High Sales

select * from DataCoSupplyChainData
where Order_Profit_Per_Order < 0 AND Sales > 300;

--- Cohort Analysis: Profit & Risk by Customer Segment

Select
	Customer_Segment,
	COUNT(DISTINCT Customer_Id) AS unique_customers,
	COUNT(*) As total_orders,
	SUM(Order_Profit_Per_Order) as total_profit,
	ROUND(SUM(CASE WHEN Late_Delivery_Risk = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),2) AS late_percent
from DataCoSupplyChainData
GROUP BY Customer_Segment
ORDER BY total_profit desc;

--- Profit Change Analysis Using LEAD
-- Goal: Track how profit per order is changing across orders for each customer.

SELECT
	Customer_Id,
	Order_Id,
	Order_Profit_Per_Order,
	LEAD(Order_Profit_Per_Order) OVER (PARTITION BY Customer_Id ORDER BY order_date_DateOrders) as next_order_profit,
	LEAD(Order_Profit_per_Order) OVER (PARTITION BY Customer_Id ORDER BY order_date_DateOrders) - Order_Profit_Per_Order AS profit_diff
FROM DataCoSupplyChainData
ORDER BY Customer_Id;

---- Product Lifecycle Tracking
SELECT 
	Product_Name,
	Category_Name,
	MIN(order_date_DateOrders) As First_order,
	MAX(order_date_DateOrders) AS last_order,
	DATEDIFF(DAY,MIN(order_date_DateOrders),MAX(order_date_DateOrders)) AS Lifecycle_days
FROM DataCoSupplyChainData
GROUP BY Product_Name,Category_Name
Order BY Category_Name,Lifecycle_days ASC;


--- Customer Repeat Behavior Analysis
-- Goal: Identify how frequently a customer returns to place another order and calculate time between purchases.

SELECT 
	Customer_Id,
	Order_Id,
	order_date_DateOrders,
	LAG(order_date_DateOrders) OVER (PARTITION BY Customer_Id Order by order_date_DateOrders) AS prev_order_date,
	DATEDIFF(DAY,LAG(order_date_DateOrders) OVER (PARTITION BY Customer_Id Order by order_date_DateOrders),order_date_DateOrders) AS days_between_orders
FROM DataCoSupplyChainData;

--- Calculate Average Repeat Time per Customer

WITH order_gaps AS (
SELECT
	Customer_Id,
	DATEDIFF(DAY,LAG(order_date_DateOrders)OVER(PARTITION BY Customer_Id ORDER BY order_date_DateOrders),order_date_DateOrders) AS gap_days
FROM DataCoSupplyChainData
)
SELECT
	Customer_Id,
	COUNT(*) - 1 AS repeat_orders,
	AVG(gap_days) AS avg_days_between_orders,
	MIN(gap_days) AS min_gap,
	MAX(gap_days) AS max_gap
FROM order_gaps
WHERE gap_days IS NOT NULL
GROUP BY Customer_Id
ORDER BY repeat_orders DESC;
;

--- Identify Loyal vs One-Time Buyers
SELECT
	Customer_Id,
	COUNT(Order_Id) AS total_orders,
	CASE
		WHEN COUNT(Order_Id) = 1 THEN 'One_Time Buyer'
		WHEN COUNT(Order_Id)  BETWEEN 2 AND 4 THEN 'Occasional Buyer'
		ELSE 'Frequent Buyer'
	END AS Buyer_type
FROM DataCoSupplyChainData
GROUP BY Customer_Id;

--- Monthly Repeat Rate per Customer Segment

WITH customer_orders AS (
SELECT
	Customer_Id,
	FORMAT(order_date_DateOrders,'yyyy-MM') AS order_month
FROM DataCoSupplyChainData
),
first_order_month AS (
SELECT
	Customer_Id,
	MIN(FORMAT(order_date_DateOrders,'yyyy-MM')) AS First_order_month
FROM DataCoSupplyChainData
GROUP BY Customer_Id
),
combined AS(
SELECT
co.Customer_Id,
co.order_month,
CASE
	WHEN fo.First_order_month < co.order_month THEN 1
	ELSE 0
END AS is_repeat
FROM customer_orders co
JOIN first_order_month fo ON  co.Customer_Id=fo.Customer_Id)
SELECT
	order_month,
	Count(DISTINCT Customer_Id) AS total_customers,
	COUNT(DISTINCT CASE WHEN is_repeat =1 THEN Customer_Id END) As repeat_customers,
	COUNT(DISTINCT CASE WHEN is_repeat =0 THEN Customer_Id END) AS new_customers,
	ROUND (100.0*COUNT(DISTINCT CASE WHEN is_repeat =1 THEN Customer_Id END) /
	COUNT(DISTINCT Customer_Id),2) As repeat_rate_percent
FROM combined
GROUP BY order_month
ORDER BY order_month;


---- Time to Second Purchase

With ordered_customers AS (
SELECT
	Customer_Id,
	order_date_DateOrders,
	ROW_NUMBER() OVER (PARTITION BY Customer_Id ORDER BY order_date_DateOrders) AS rn
FROM DataCoSupplyChainData),
first_second_day_orders AS (
SELECT 
	Customer_Id,
	MAX(CASE WHEN rn=1 THEN order_date_DateOrders END) AS first_order_date,
	MAX (CASE WHEN rn=2 THEN order_date_DateOrders END) AS second_order_date
FROM ordered_customers
GROUP BY Customer_Id)
SELECT 
	Customer_Id,
	DATEDIFF(DAY,first_order_date,second_order_date) AS days_to_second_purchase
FROM first_second_day_orders
WHERE second_order_date is NOT NULL
ORDER BY days_to_second_purchase DESC;







select top 5 * from DataCoSupplyChainData;