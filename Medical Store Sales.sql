CREATE DATABASE IF NOT EXISTS MedicalStore;

USE MedicalStore;

-- 1. Create the Medicines Catalog (Master Data)
CREATE TABLE Medicines_Catalog (
    MedicineID VARCHAR(10) PRIMARY KEY,
    BrandName VARCHAR(150),
    Active_ingredient VARCHAR(500),
    Category VARCHAR(150), -- e.g., Tablet, Syrup, Injection
    Manufacturer VARCHAR(150),
    Dosage_form VARCHAR(100),
    RequiresPrescription VARCHAR(50)
    );
    
SELECT * FROM Medicines_Catalog;

-- 2. Create the Inventory Batches (Stock Data)
CREATE TABLE Inventory_Batches (
    BatchID VARCHAR(15) PRIMARY KEY,
    MedicineID VARCHAR(10),
    SupplierName VARCHAR(100),
    StockQuantity INT NOT NULL,
    WholesalePrice DECIMAL(10, 2) NOT NULL,
    RetailPrice DECIMAL(10, 2) NOT NULL,
    ManufactureDate DATE,
    ExpiryDate DATE,
    FOREIGN KEY (MedicineID) REFERENCES Medicines_Catalog(MedicineID)
);

SELECT * FROM Inventory_Batches;

-- 3. Create the Customers (Loyalty/Tracking Data)
CREATE TABLE Customers (
    CustomerID VARCHAR(10) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    PhoneNumber VARCHAR(15),
    RegistrationDate DATE,
    LoyaltyPointsBalance INT DEFAULT 0
);

SELECT * FROM Customers;

-- 4. Create the Sales Invoices (Transaction Headers)
CREATE TABLE Sales_Invoices (
    InvoiceID VARCHAR(15) PRIMARY KEY,
    CustomerID VARCHAR(10),
    TransactionDate DATETIME,
    TotalAmount DECIMAL(10, 2),
    PaymentMethod VARCHAR(50), -- e.g., Cash, UPI, Card
    CashierID VARCHAR(10),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

SELECT * FROM Sales_Invoices;

-- 5. Create the Sales Items (Transaction Line Items)
CREATE TABLE Sales_Items (
    ItemID VARCHAR(20) PRIMARY KEY,
    InvoiceID VARCHAR(15),
    BatchID VARCHAR(15),
    QuantitySold INT NOT NULL,
    PriceAtSale DECIMAL(10, 2) NOT NULL,
    LineTotal DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (InvoiceID) REFERENCES Sales_Invoices(InvoiceID),
    FOREIGN KEY (BatchID) REFERENCES Inventory_Batches(BatchID)
);

SELECT * FROM Sales_Items;


-- Expiry Risk & Inventory Mitigation
-- Focus: Identifying wastage before it happens and managing suppliers.

-- 1. The 90-Day Expiry Alert
-- Identify batches expiring in the next 90 days with their exact remaining shelf life.

SELECT 
    b.BatchID,
    m.BrandName,
    b.StockQuantity,
    b.ExpiryDate,
    DATEDIFF(b.ExpiryDate, CURDATE()) AS DaysUntilExpiry
FROM
    Inventory_Batches b
        JOIN
    Medicines_Catalog m ON b.MedicineID = m.MedicineID
WHERE
    DATEDIFF(b.ExpiryDate, CURDATE()) BETWEEN 0 AND 90
ORDER BY DaysUntilExpiry ASC;


-- 2. Financial Risk of Expiring Stock (Potential Loss)
-- Calculate the total lost wholesale investment if the expiring stock is not sold.

SELECT 
    m.Category,
    SUM(b.StockQuantity) AS TotalRiskQuantity,
    SUM(b.StockQuantity * b.WholesalePrice) AS PotentialFinancialLoss
FROM
    Inventory_Batches b
        JOIN
    Medicines_Catalog m ON b.MedicineID = m.MedicineID
WHERE
    DATEDIFF(b.ExpiryDate, CURDATE()) <= 90
GROUP BY m.Category
ORDER BY PotentialFinancialLoss DESC;

-- 3. Supplier Risk Profiling
-- Which suppliers are sending us batches with the shortest shelf-life?
SELECT 
    SupplierName,
    AVG(DATEDIFF(ExpiryDate, ManufactureDate)) AS AvgShelfLife_Days,
    COUNT(BatchID) AS TotalBatchesSupplied
FROM
    Inventory_Batches
GROUP BY SupplierName
ORDER BY AvgShelfLife_Days ASC;

-- 4. Out-of-Stock (OOS) Warning System
-- Find medicines where total stock across all active batches is critically low (< 50 units).
SELECT 
    m.BrandName, m.Category, SUM(b.StockQuantity) AS TotalStock
FROM
    Medicines_Catalog m
        LEFT JOIN
    Inventory_Batches b ON m.MedicineID = b.MedicineID
GROUP BY m.MedicineID , m.BrandName , m.Category
HAVING TotalStock < 50 OR TotalStock IS NULL
ORDER BY TotalStock ASC;

-- 5. Dead Stock Identification
-- Medicines that have >100 units in stock but haven't been sold in the last 6 months.
WITH RecentSales AS (
    SELECT DISTINCT BatchID FROM Sales_Items 
    JOIN Sales_Invoices USING (InvoiceID)
    WHERE TransactionDate >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
)
SELECT 
    m.BrandName, b.BatchID, b.StockQuantity, b.SupplierName
FROM
    Inventory_Batches b
        JOIN
    Medicines_Catalog m ON b.MedicineID = m.MedicineID
        LEFT JOIN
    RecentSales rs ON b.BatchID = rs.BatchID
WHERE
    rs.BatchID IS NULL
        AND b.StockQuantity > 100;
        
-- 6. Inventory Markup Violation Check
-- Find any batches where the retail price was set incorrectly (Markup < 10% of wholesale).
SELECT 
    BatchID,
    MedicineID,
    WholesalePrice,
    RetailPrice,
    ((RetailPrice - WholesalePrice) / WholesalePrice) * 100 AS MarkupPercentage
FROM
    Inventory_Batches
WHERE
    ((RetailPrice - WholesalePrice) / WholesalePrice) < 0.10;
    
-- Profitability & Sales Performance
-- Focus: Margin analysis, revenue tracking, and product performance.

-- 7. Monthly Gross Profit Trend
-- Total revenue and actual profit (Retail - Wholesale) grouped by month.
SELECT 
    DATE_FORMAT(si.TransactionDate, '%Y-%m') AS SalesMonth,
    SUM(i.LineTotal) AS TotalRevenue,
    SUM((i.PriceAtSale - b.WholesalePrice) * i.QuantitySold) AS GrossProfit
FROM
    Sales_Invoices si
        JOIN
    Sales_Items i ON si.InvoiceID = i.InvoiceID
        JOIN
    Inventory_Batches b ON i.BatchID = b.BatchID
GROUP BY SalesMonth
ORDER BY SalesMonth;

-- 8. Top 10 Most Profitable Medicines
SELECT 
    m.BrandName,
    SUM((i.PriceAtSale - b.WholesalePrice) * i.QuantitySold) AS TotalProfit
FROM
    Sales_Items i
        JOIN
    Inventory_Batches b ON i.BatchID = b.BatchID
        JOIN
    Medicines_Catalog m ON b.MedicineID = m.MedicineID
GROUP BY m.BrandName
ORDER BY TotalProfit DESC
LIMIT 10;

-- 9. Profitability: Prescription vs. OTC
-- Do we make more money on prescriptions or over-the-counter (OTC) drugs?
SELECT 
    m.RequiresPrescription,
    SUM(i.LineTotal) AS Revenue,
    SUM((i.PriceAtSale - b.WholesalePrice) * i.QuantitySold) AS Profit
FROM
    Sales_Items i
        JOIN
    Inventory_Batches b ON i.BatchID = b.BatchID
        JOIN
    Medicines_Catalog m ON b.MedicineID = m.MedicineID
GROUP BY m.RequiresPrescription;

-- 10. Profit Margin by Drug Category
SELECT 
    m.Category,
    SUM((i.PriceAtSale - b.WholesalePrice) * i.QuantitySold) / SUM(i.LineTotal) * 100 AS MarginPercentage
FROM
    Sales_Items i
        JOIN
    Inventory_Batches b ON i.BatchID = b.BatchID
        JOIN
    Medicines_Catalog m ON b.MedicineID = m.MedicineID
GROUP BY m.Category
ORDER BY MarginPercentage DESC;

-- 11. Month-over-Month Revenue Growth (Using Window Functions)
-- Crucial interview question using LAG().
WITH MonthlySales AS (
    SELECT DATE_FORMAT(TransactionDate, '%Y-%m') AS Month, SUM(TotalAmount) AS Revenue
    FROM Sales_Invoices GROUP BY Month
)
SELECT Month, Revenue,
       LAG(Revenue) OVER (ORDER BY Month) AS PrevMonthRevenue,
       ((Revenue - LAG(Revenue) OVER (ORDER BY Month)) / LAG(Revenue) OVER (ORDER BY Month)) * 100 AS GrowthPct
FROM MonthlySales;

-- 12. Average Daily Sales vs. Actual Daily Sales
-- Find days where sales were unusually high (above the overall daily average).
WITH DailyTotals AS (
    SELECT 
    DATE(TransactionDate) AS SalesDate,
    SUM(TotalAmount) AS DailyRev
FROM
    Sales_Invoices
GROUP BY DATE(TransactionDate)
)
SELECT 
    SalesDate, DailyRev
FROM
    DailyTotals
WHERE
    DailyRev > (SELECT 
            AVG(DailyRev)
        FROM
            DailyTotals);
            
-- 13. Revenue Breakdown by Payment Method
SELECT 
    PaymentMethod,
    COUNT(InvoiceID) AS TransactionCount,
    SUM(TotalAmount) AS TotalRevenue,
    (SUM(TotalAmount) / (SELECT 
            SUM(TotalAmount)
        FROM
            Sales_Invoices)) * 100 AS PctOfTotalRevenue
FROM
    Sales_Invoices
GROUP BY PaymentMethod;

-- Customer VIP & Retention Analysis
-- Focus: Customer Lifetime Value (CLV), churn, and RFM (Recency, Frequency, Monetary).

-- 14. Top 50 VIP Customers (Lifetime Value)
SELECT 
    c.CustomerID,
    c.Name,
    c.LoyaltyPointsBalance,
    SUM(si.TotalAmount) AS LifetimeValue,
    COUNT(si.InvoiceID) AS TotalVisits
FROM
    Customers c
        JOIN
    Sales_Invoices si ON c.CustomerID = si.CustomerID
GROUP BY c.CustomerID , c.Name , c.LoyaltyPointsBalance
ORDER BY LifetimeValue DESC
LIMIT 50;

-- 15. Customer Churn Risk (High Spenders missing for 90 days)
SELECT 
    c.Name,
    c.PhoneNumber,
    MAX(si.TransactionDate) AS LastVisit,
    DATEDIFF(CURDATE(), MAX(si.TransactionDate)) AS DaysSinceLastVisit
FROM
    Customers c
        JOIN
    Sales_Invoices si ON c.CustomerID = si.CustomerID
GROUP BY c.CustomerID , c.Name , c.PhoneNumber
HAVING DaysSinceLastVisit > 90
ORDER BY DaysSinceLastVisit DESC;

-- 16. Loyalty Liability (Unredeemed Points Value)
-- Assuming 1 Loyalty Point = ₹1. What is the store's financial liability?
SELECT 
    SUM(LoyaltyPointsBalance) AS TotalUnredeemedPoints_Rupees,
    AVG(LoyaltyPointsBalance) AS AvgPointsPerCustomer
FROM
    Customers;
    
-- 17. Average Order Value (AOV) by Customer Cohort
-- Does a customer who joined in 2023 spend more per visit than one who joined in 2024?
SELECT 
    YEAR(c.RegistrationDate) AS CohortYear,
    SUM(si.TotalAmount) / COUNT(si.InvoiceID) AS AverageOrderValue
FROM
    Customers c
        JOIN
    Sales_Invoices si ON c.CustomerID = si.CustomerID
GROUP BY CohortYear;

-- 18. RFM Analysis: Recency Ranking
-- Rank customers based on how recently they visited.
SELECT CustomerID, MAX(TransactionDate) AS LastPurchase,
       RANK() OVER (ORDER BY MAX(TransactionDate) DESC) AS RecencyRank
FROM Sales_Invoices
GROUP BY CustomerID;

-- 19. Single-Visit Customers (Poor Retention)
-- Find customers who registered, bought once, and never returned.
SELECT 
    c.CustomerID,
    c.Name,
    COUNT(si.InvoiceID) AS TotalPurchases
FROM
    Customers c
        JOIN
    Sales_Invoices si ON c.CustomerID = si.CustomerID
GROUP BY c.CustomerID , c.Name
HAVING TotalPurchases = 1;

-- 20. Pareto Principle (80/20 Rule) - Running Total
-- Which customers make up the top percentile of sales? (Uses Cumulative Sum).
WITH CustSpends AS (
    SELECT 
    CustomerID, SUM(TotalAmount) AS TotalSpend
FROM
    Sales_Invoices
GROUP BY CustomerID
),
RankedSpends AS (
    SELECT CustomerID, TotalSpend,
           SUM(TotalSpend) OVER (ORDER BY TotalSpend DESC) AS CumulativeSpend,
           SUM(TotalSpend) OVER () AS GrandTotal
    FROM CustSpends
)
SELECT 
    CustomerID,
    TotalSpend,
    (CumulativeSpend / GrandTotal) * 100 AS CumulativePct
FROM
    RankedSpends
WHERE
    (CumulativeSpend / GrandTotal) <= 0.80;
    
-- Store Operations & Analytics
-- Focus: Cashier performance, peak hours, and basket sizes.

-- 21. Peak Trading Hours
-- Which hour of the day requires the most cashiers on duty?
SELECT 
    HOUR(TransactionDate) AS HourOfDay,
    COUNT(InvoiceID) AS TrafficCount,
    SUM(TotalAmount) AS RevenueGenerated
FROM
    Sales_Invoices
GROUP BY HourOfDay
ORDER BY TrafficCount DESC;

-- 22. Cashier Efficiency Matrix
-- Who is processing the most transactions and revenue?
SELECT 
    CashierID,
    COUNT(InvoiceID) AS TotalTransactions,
    SUM(TotalAmount) AS TotalProcessed,
    SUM(TotalAmount) / COUNT(InvoiceID) AS AvgBasketHandled
FROM
    Sales_Invoices
GROUP BY CashierID
ORDER BY TotalProcessed DESC;

-- 23. Busiest Day of the Week
SELECT 
    DAYNAME(TransactionDate) AS DayOfWeek,
    COUNT(InvoiceID) AS TotalInvoices,
    SUM(TotalAmount) AS Revenue
FROM
    Sales_Invoices
GROUP BY DayOfWeek
ORDER BY TotalInvoices DESC;

-- 24. Average Basket Size
-- How many distinct items are people buying per visit?
WITH ItemsPerInvoice AS (
    SELECT 
    InvoiceID, COUNT(ItemID) AS ItemCount
FROM
    Sales_Items
GROUP BY InvoiceID
)
SELECT 
    AVG(ItemCount) AS AvgItemsPerBasket
FROM
    ItemsPerInvoice;
    
-- 25. Discount Tracking
-- Did a cashier sell an item for less than the official Retail Price?
SELECT 
    i.InvoiceID,
    si.CashierID,
    i.BatchID,
    b.RetailPrice,
    i.PriceAtSale,
    (b.RetailPrice - i.PriceAtSale) AS DiscountGiven
FROM
    Sales_Items i
        JOIN
    Inventory_Batches b ON i.BatchID = b.BatchID
        JOIN
    Sales_Invoices si ON i.InvoiceID = si.InvoiceID
WHERE
    i.PriceAtSale < b.RetailPrice;
    
-- The "Capstone" Advanced Queries

-- 26. Market Basket Analysis (Products frequently bought together)
-- Self-Joins are required here. This finds which items are bought on the same invoice.
SELECT 
    m1.BrandName AS ProductA,
    m2.BrandName AS ProductB,
    COUNT(*) AS TimesBoughtTogether
FROM
    Sales_Items i1
        JOIN
    Sales_Items i2 ON i1.InvoiceID = i2.InvoiceID
        AND i1.ItemID < i2.ItemID
        JOIN
    Inventory_Batches b1 ON i1.BatchID = b1.BatchID
        JOIN
    Medicines_Catalog m1 ON b1.MedicineID = m1.MedicineID
        JOIN
    Inventory_Batches b2 ON i2.BatchID = b2.BatchID
        JOIN
    Medicines_Catalog m2 ON b2.MedicineID = m2.MedicineID
GROUP BY ProductA , ProductB
ORDER BY TimesBoughtTogether DESC
LIMIT 10;

-- 27. THE TARGETED CAMPAIGN ENGINE (Business Problem Solved)
/* Find customers who have bought a specific OTC medicine in the past, 
where we currently have stock of that EXACT medicine expiring in < 90 days. 
We can text these customers a discount code! */
WITH ExpiringStock AS (
    SELECT 
    b.MedicineID, m.BrandName, SUM(b.StockQuantity) AS Qty
FROM
    Inventory_Batches b
        JOIN
    Medicines_Catalog m ON b.MedicineID = m.MedicineID
WHERE
    DATEDIFF(b.ExpiryDate, CURDATE()) < 90
        AND m.RequiresPrescription = FALSE
GROUP BY b.MedicineID , m.BrandName
)
SELECT DISTINCT
    c.Name,
    c.PhoneNumber,
    c.LoyaltyPointsBalance,
    es.BrandName AS RecommendedProduct
FROM
    Customers c
        JOIN
    Sales_Invoices si ON c.CustomerID = si.CustomerID
        JOIN
    Sales_Items i ON si.InvoiceID = i.InvoiceID
        JOIN
    Inventory_Batches b ON i.BatchID = b.BatchID
        JOIN
    ExpiringStock es ON b.MedicineID = es.MedicineID
WHERE
    c.LoyaltyPointsBalance > 50; -- Only target people who can use points!
    
-- 28. Manufacturer ROI Ranking
-- Which manufacturer's products yield the highest return on investment?
SELECT 
    m.Manufacturer,
    SUM((i.PriceAtSale - b.WholesalePrice) * i.QuantitySold) AS TotalNetProfit,
    SUM(b.StockQuantity * b.WholesalePrice) AS CapitalTiedUpInStock
FROM
    Medicines_Catalog m
        JOIN
    Inventory_Batches b ON m.MedicineID = b.MedicineID
        LEFT JOIN
    Sales_Items i ON b.BatchID = i.BatchID
GROUP BY m.Manufacturer
HAVING TotalNetProfit IS NOT NULL
ORDER BY TotalNetProfit DESC;

-- 29. First Purchase vs. Repeat Purchase Revenue
-- Using ROW_NUMBER() to split revenue into "New Customer Acquisition" vs. "Retained Customer Revenue".
WITH RankedPurchases AS (
    SELECT InvoiceID, CustomerID, TotalAmount,
           ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY TransactionDate) AS VisitNumber
    FROM Sales_Invoices
)
SELECT 
    CASE
        WHEN VisitNumber = 1 THEN 'First Visit Revenue'
        ELSE 'Repeat Customer Revenue'
    END AS RevenueType,
    SUM(TotalAmount) AS TotalRevenue
FROM
    RankedPurchases
GROUP BY RevenueType;

-- 30. Dynamic Re-Ordering Priority List
-- Rank out-of-stock items by how much profit they usually generate, telling the manager exactly what to re-order first.
WITH HistoricalProfit AS (
    SELECT b.MedicineID, SUM((i.PriceAtSale - b.WholesalePrice) * i.QuantitySold) AS PastProfit
    FROM Sales_Items i
    JOIN Inventory_Batches b ON i.BatchID = b.BatchID
    GROUP BY b.MedicineID
),
CurrentStock AS (
    SELECT MedicineID, SUM(StockQuantity) AS TotalQty FROM Inventory_Batches GROUP BY MedicineID
)
SELECT m.BrandName, m.Manufacturer, hp.PastProfit, COALESCE(cs.TotalQty, 0) AS CurrentStockLevel,
       DENSE_RANK() OVER (ORDER BY hp.PastProfit DESC) AS ReorderPriorityRank
FROM Medicines_Catalog m
LEFT JOIN HistoricalProfit hp ON m.MedicineID = hp.MedicineID
LEFT JOIN CurrentStock cs ON m.MedicineID = cs.MedicineID
WHERE COALESCE(cs.TotalQty, 0) < 20 AND hp.PastProfit IS NOT NULL
ORDER BY ReorderPriorityRank;