# Medical-Store-Sales-Analytics
Leveraging SQL &amp; Data Modeling to Combat Inventory Wastage and Maximize Customer Lifetime Value

# Medical Store Analytics & Inventory Management System

## Project Overview
This project demonstrates a robust database schema and an analytical suite for a modern pharmacy/medical store. It moves beyond basic CRUD operations to solve real-world business problems such as **expiry risk mitigation**, **customer churn prediction**, and **profitability analysis**.

The system is designed to handle master data (Medicines), operational data (Inventory Batches), and transactional data (Sales).

---

## Database Schema (ERD)
The database follows a relational model optimized for integrity and analytical depth:

*   **`Medicines_Catalog`**: Master list of all pharmaceutical products.
*   **`Inventory_Batches`**: Tracks specific batches, expiry dates, and wholesale vs. retail pricing.
*   **`Customers`**: Manages loyalty points and contact information.
*   **`Sales_Invoices`**: Transaction headers (Date, Payment Method, Total).
*   **`Sales_Items`**: Line-item details for every transaction.



---

##  Key Analytical Features

### 1. Inventory & Risk Management
*   **Expiry Alerts:** 90-day countdown for expiring stock to prevent wastage.
*   **Financial Risk Assessment:** Calculation of potential losses based on wholesale price of expiring items.
*   **Dead Stock Identification:** Identifying products with high stock but zero sales in the last 6 months.
*   **Markup Violations:** Automated check for pricing errors (where margin is < 10%).

### 2. Profitability & Sales Intelligence
*   **Month-over-Month (MoM) Growth:** Using `LAG()` window functions to track revenue trends.
*   **Category Analysis:** Comparing profit margins between Prescription (Rx) and Over-the-Counter (OTC) drugs.
*   **Market Basket Analysis:** A self-join query to find products frequently bought together (e.g., Vitamin C with Cold Medicine).

### 3. Customer & VIP Analytics
*   **RFM (Recency) Ranking:** Ranking customers by their last visit date using `RANK()`.
*   **Churn Risk:** Identifying high-value customers who haven't visited in over 90 days.
*   **Pareto Principle (80/20 Rule):** Using cumulative sums to identify the 20% of customers driving 80% of revenue.

### 4. Operational Efficiency
*   **Peak Trading Hours:** Analyzing transaction timestamps to optimize staff scheduling.
*   **Cashier Performance:** Measuring efficiency through average basket size and total revenue processed.

---

##  Technical Skills Demonstrated
*   **Advanced SQL Joins:** (INNER, LEFT, SELF-JOINS)
*   **Window Functions:** `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `LAG()`, and `OVER(PARTITION BY...)`
*   **Common Table Expressions (CTEs):** For modular and readable complex logic.
*   **Data Aggregation:** Complex `GROUP BY` and `HAVING` clauses.
*   **Date/Time Manipulation:** `DATEDIFF`, `DATE_FORMAT`, and `DATE_SUB`.

---

##  Sample Insights Generated
*   **Marketing Opportunity:** A query targets OTC customers who have bought specific medicines before and offers them a discount on batches expiring soon.
*   **Re-Ordering Logic:** A dynamic priority list that ranks out-of-stock items based on their historical profitability, ensuring the store restocks high-margin items first.

---

##  How to Run
1.  Ensure you have **MySQL** or a compatible SQL engine installed.
2.  Copy the contents of the `.sql` file into your query editor.
3.  Execute the script to build the schema.
4.  (Optional) Populate with sample data to see the analytical queries in action.

---
**Project Category:** Data Engineering / Business Intelligence / Retail Analytics
