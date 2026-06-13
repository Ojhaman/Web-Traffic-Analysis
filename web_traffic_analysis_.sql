-- ================================================================
--   WEB TRAFFIC ANALYTICS PROJECT
--   Dataset : web_traffic.csv
--   Tool    : MySQL Workbench 8.x
-- ================================================================


--  PHASE 1 : DATABASE & TABLE SETUP

-- ---------------------------------------------------------------
-- 1A. Create a fresh database for this project.
--     DROP DATABASE IF EXISTS makes it safe to re-run the script
--     without errors if the database already exists.
-- ---------------------------------------------------------------
DROP DATABASE IF EXISTS web_traffic_db;
CREATE DATABASE web_traffic_db
    CHARACTER SET utf8mb4        -- supports all Unicode characters
    COLLATE utf8mb4_unicode_ci;  -- case-insensitive text comparison

USE web_traffic_db;              -- all following statements target this DB


-- ---------------------------------------------------------------
-- 1B. Create the main raw data table.
--
--     Column design decisions:
--       - Timestamp stored as DATETIME (not VARCHAR) so MySQL can
--         do date arithmetic (HOUR(), DAYOFWEEK(), DATEDIFF(), etc.)
--       - TrafficCount stored as INT — it is always a whole number
--         even though the CSV has ".0" decimal notation
--       - record_id is an auto-increment surrogate key — the CSV has
--         no natural primary key
-- ---------------------------------------------------------------
CREATE TABLE web_traffic_raw (
    record_id     INT           AUTO_INCREMENT PRIMARY KEY,
    traffic_time  DATETIME      NOT NULL,       -- e.g. 2020-01-20 10:00:00
    traffic_count INT           NOT NULL        -- hourly visitor count
);


-- ---------------------------------------------------------------
-- 1C. IMPORT THE CSV
-- ---------------------------------------------------------------
-- 1D. Verify the import — must return exactly 2793 rows.
-- ---------------------------------------------------------------
SELECT COUNT(*) AS total_records FROM web_traffic_raw;
-- Expected: 2793


-- ---------------------------------------------------------------
-- 1E. Preview the first 10 rows to confirm data looks right.
-- ---------------------------------------------------------------
SELECT * FROM web_traffic_raw ORDER BY traffic_time LIMIT 10;


-- ---------------------------------------------------------------
-- 1F. Add derived/computed columns to enrich the raw data.
--     These columns are calculated ONCE and stored, so every
--     later query does not have to repeat the same expressions.
--
--     YEAR(), MONTH(), etc. are built-in MySQL date functions.
--     DAYOFWEEK() returns 1=Sunday … 7=Saturday in MySQL.
--     We use a CASE expression to convert number → readable name.
-- ---------------------------------------------------------------
ALTER TABLE web_traffic_raw
    ADD COLUMN traffic_year    INT,           -- e.g. 2020
    ADD COLUMN traffic_month   INT,           -- 1–12
    ADD COLUMN month_name      VARCHAR(10),   -- e.g. 'January'
    ADD COLUMN traffic_week    INT,           -- ISO week number 1–53
    ADD COLUMN traffic_date    DATE,          -- just the date part
    ADD COLUMN hour_of_day     INT,           -- 0–23
    ADD COLUMN day_of_week     INT,           -- 1(Sun)–7(Sat)
    ADD COLUMN day_name        VARCHAR(10),   -- e.g. 'Monday'
    ADD COLUMN is_weekend      TINYINT(1),    -- 1=weekend, 0=weekday
    ADD COLUMN is_business_hr  TINYINT(1),   -- 1=8am–5pm, 0=off-hours
    ADD COLUMN traffic_category VARCHAR(10),  -- Low/Medium/High/Peak
    ADD COLUMN is_spike        TINYINT(1);    -- 1 if above mean+2std


-- Populate all derived columns in a single UPDATE statement.
-- This is more efficient than multiple UPDATE calls.
UPDATE web_traffic_raw
SET
    traffic_year    = YEAR(traffic_time),
    traffic_month   = MONTH(traffic_time),

    -- DATE_FORMAT() formats a date/datetime using format codes
    -- %M = full month name (January, February …)
    month_name      = DATE_FORMAT(traffic_time, '%M'),

    -- WEEK(date, 3) returns the ISO 8601 week number
    traffic_week    = WEEK(traffic_time, 3),

    -- DATE() extracts only the date part from a datetime
    traffic_date    = DATE(traffic_time),

    hour_of_day     = HOUR(traffic_time),
    day_of_week     = DAYOFWEEK(traffic_time),  -- 1=Sun, 2=Mon … 7=Sat

    day_name        = CASE DAYOFWEEK(traffic_time)
                        WHEN 1 THEN 'Sunday'
                        WHEN 2 THEN 'Monday'
                        WHEN 3 THEN 'Tuesday'
                        WHEN 4 THEN 'Wednesday'
                        WHEN 5 THEN 'Thursday'
                        WHEN 6 THEN 'Friday'
                        WHEN 7 THEN 'Saturday'
                      END,

    -- DAYOFWEEK 1=Sun, 7=Sat → weekend is 1 or 7
    is_weekend      = IF(DAYOFWEEK(traffic_time) IN (1, 7), 1, 0),

    -- Business hours defined as 8 AM to 5 PM (inclusive)
    is_business_hr  = IF(HOUR(traffic_time) BETWEEN 8 AND 17, 1, 0),

    -- Traffic category based on actual data distribution:
    --   Low    < 500    (18.5% of records)
    --   Medium 500–4999 (43.0% of records)
    --   High   5000–19999 (20.6%)
    --   Peak   >= 20000 (17.9%)
    traffic_category = CASE
        WHEN traffic_count < 500   THEN 'Low'
        WHEN traffic_count < 5000  THEN 'Medium'
        WHEN traffic_count < 20000 THEN 'High'
        ELSE                            'Peak'
    END,

    -- Spike = traffic exceeds mean + 2×std deviation
    -- From data: mean=8591, std=11479 → threshold=31,549
    -- 144 records (5.2%) qualify as spikes
    is_spike        = IF(traffic_count > 31549, 1, 0);


-- Verify derived columns populated correctly
SELECT
    traffic_time, traffic_count, month_name, day_name,
    is_weekend, is_business_hr, traffic_category, is_spike
FROM web_traffic_raw
LIMIT 8;


-- ---------------------------------------------------------------
-- 1G. Create an analysis log table to track every query run.
--     Good practice for projects — creates an audit trail.
-- ---------------------------------------------------------------
CREATE TABLE analysis_log (
    log_id        INT         AUTO_INCREMENT PRIMARY KEY,
    logged_at     DATETIME    DEFAULT CURRENT_TIMESTAMP,
    query_name    VARCHAR(100),
    finding       VARCHAR(500)
);

INSERT INTO analysis_log (query_name, finding)
VALUES ('Phase 1 Setup', '2793 records imported, derived columns added');


--  PHASE 2 : BASIC EXPLORATORY ANALYSIS

-- ---------------------------------------------------------------
-- Q1. Dataset overview — one-line summary of the entire dataset.
--     MIN() and MAX() find the earliest and latest timestamps.
--     SUM(), AVG(), ROUND() are standard aggregate functions.
-- ---------------------------------------------------------------
SELECT
    COUNT(*)                          AS total_records,
    MIN(traffic_time)                 AS data_starts,
    MAX(traffic_time)                 AS data_ends,
    DATEDIFF(MAX(traffic_time),
             MIN(traffic_time))       AS span_days,
    SUM(traffic_count)                AS total_traffic,
    ROUND(AVG(traffic_count), 1)      AS avg_hourly_traffic,
    MIN(traffic_count)                AS min_traffic,
    MAX(traffic_count)                AS max_traffic,
    ROUND(STD(traffic_count), 1)      AS std_deviation
FROM web_traffic_raw;
-- Expected totals: 2793 records, 23,995,560 total traffic, mean ~8591


-- ---------------------------------------------------------------
-- Q2. Traffic category distribution.
--     COUNT(*) per group tells us how traffic is spread across
--     the Low/Medium/High/Peak buckets.
--     SUM(traffic_count)/total gives each bucket's share of
--     overall traffic volume.
-- ---------------------------------------------------------------
SELECT
    traffic_category,
    COUNT(*)                              AS record_count,
    ROUND(COUNT(*) * 100.0
          / (SELECT COUNT(*) FROM web_traffic_raw), 1)
                                          AS pct_of_records,
    SUM(traffic_count)                    AS total_traffic,
    ROUND(AVG(traffic_count), 1)          AS avg_traffic,
    MIN(traffic_count)                    AS min_traffic,
    MAX(traffic_count)                    AS max_traffic
FROM web_traffic_raw
GROUP BY traffic_category
ORDER BY FIELD(traffic_category, 'Peak','High','Medium','Low');
-- FIELD() sorts rows in custom order rather than alphabetical


-- ---------------------------------------------------------------
-- Q3. Spike records — moments of unusually high traffic.
--     Threshold = mean + 2×std = 31,549.
--     144 records (5.2%) exceed this — these are anomaly events.
-- ---------------------------------------------------------------
SELECT
    traffic_time,
    traffic_count,
    day_name,
    hour_of_day,
    month_name
FROM web_traffic_raw
WHERE is_spike = 1
ORDER BY traffic_count DESC
LIMIT 20;
-- Top result: 2020-03-26 21:30 with 71,925 visits


--  PHASE 3 : TIME-BASED TREND ANALYSIS

-- ---------------------------------------------------------------
-- Q4. Monthly traffic summary.
--     Answers: "Which months had most traffic and how did it grow?"
--     Total traffic per month lets us see seasonal patterns.
-- ---------------------------------------------------------------
SELECT
    traffic_month,
    month_name,
    COUNT(*)                          AS hourly_readings,
    SUM(traffic_count)                AS total_monthly_traffic,
    ROUND(AVG(traffic_count), 1)      AS avg_hourly_traffic,
    MAX(traffic_count)                AS peak_hour_traffic,
    MIN(traffic_count)                AS slowest_hour_traffic,
    -- Month-over-month growth using a subquery
    -- LAG() would need MySQL 8+ window functions (shown later)
    ROUND(
      (SUM(traffic_count) -
        LAG(SUM(traffic_count)) OVER (ORDER BY traffic_month)
      ) / LAG(SUM(traffic_count)) OVER (ORDER BY traffic_month) * 100, 1
    )                                 AS mom_growth_pct
FROM web_traffic_raw
GROUP BY traffic_month, month_name
ORDER BY traffic_month;
-- Jan: 2,834,445 | Feb: 5,331,499 | Mar: 5,975,935 | Apr: 6,705,879


-- ---------------------------------------------------------------
-- Q5. Weekly traffic totals.
--     Week numbers show shorter-term fluctuations.
--     Helps identify which weeks had traffic spikes or dips.
-- ---------------------------------------------------------------
SELECT
    traffic_week                      AS iso_week,
    MIN(traffic_date)                 AS week_starts,
    MAX(traffic_date)                 AS week_ends,
    COUNT(*)                          AS readings,
    SUM(traffic_count)                AS total_traffic,
    ROUND(AVG(traffic_count), 1)      AS avg_hourly_traffic,
    MAX(traffic_count)                AS peak_traffic
FROM web_traffic_raw
GROUP BY traffic_week
ORDER BY traffic_week;


-- ---------------------------------------------------------------
-- Q6. Daily traffic totals — granular day-by-day view.
--     Best for spotting individual spike days or dead days.
-- ---------------------------------------------------------------
SELECT
    traffic_date,
    day_name,
    COUNT(*)                          AS hourly_readings,
    SUM(traffic_count)                AS daily_total,
    ROUND(AVG(traffic_count), 1)      AS avg_per_hour,
    MAX(traffic_count)                AS peak_hour_count
FROM web_traffic_raw
GROUP BY traffic_date, day_name
ORDER BY daily_total DESC
LIMIT 20;
-- Highest day: 2020-02-03 with 466,050 total visits


-- ---------------------------------------------------------------
-- Q7. 7-day rolling average — smooths out daily noise to show
--     the underlying traffic trend clearly.
--
--     Window function syntax:
--       AVG(...) OVER (ORDER BY ... ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
--       means: average this row and the 6 rows before it (= 7 rows total)
--     This requires MySQL 8.0+
-- ---------------------------------------------------------------
SELECT
    traffic_date,
    day_name,
    SUM(traffic_count)                AS daily_total,
    ROUND(
      AVG(SUM(traffic_count)) OVER (
        ORDER BY traffic_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
      ), 1)                           AS rolling_7day_avg
FROM web_traffic_raw
GROUP BY traffic_date, day_name
ORDER BY traffic_date;


--  PHASE 4 : HOURLY & DAY-OF-WEEK PATTERNS

-- ---------------------------------------------------------------
-- Q8. Hourly traffic pattern (0–23).
--     This reveals the "traffic shape" of a typical day.
--     Useful for: scheduling maintenance, ad campaigns, server scaling.
-- ---------------------------------------------------------------
SELECT
    hour_of_day,
    -- Label each hour readably e.g. "10 AM", "2 PM"
    CASE
        WHEN hour_of_day = 0  THEN '12 AM (Midnight)'
        WHEN hour_of_day < 12 THEN CONCAT(hour_of_day, ' AM')
        WHEN hour_of_day = 12 THEN '12 PM (Noon)'
        ELSE CONCAT(hour_of_day - 12, ' PM')
    END                               AS hour_label,
    COUNT(*)                          AS days_observed,
    ROUND(AVG(traffic_count), 1)      AS avg_traffic,
    MAX(traffic_count)                AS peak_traffic,
    MIN(traffic_count)                AS min_traffic,
    -- Visual bar chart using RPAD: each █ = ~500 visits
    RPAD('', ROUND(AVG(traffic_count)/500), '█')
                                      AS traffic_bar
FROM web_traffic_raw
GROUP BY hour_of_day
ORDER BY hour_of_day;
-- Peak hours: 10 AM (21,476) and 11 AM (23,627)
-- Quietest: 3 AM (317 avg)


-- ---------------------------------------------------------------
-- Q9. Day-of-week pattern.
--     Weekdays vs weekends — critical for content scheduling.
-- ---------------------------------------------------------------
SELECT
    day_of_week,
    day_name,
    COUNT(*)                          AS hourly_readings,
    ROUND(AVG(traffic_count), 1)      AS avg_hourly_traffic,
    SUM(traffic_count)                AS total_traffic,
    MAX(traffic_count)                AS peak_traffic,
    ROUND(AVG(traffic_count) * 100.0
          / (SELECT AVG(traffic_count) FROM web_traffic_raw), 1)
                                      AS pct_of_overall_avg
FROM web_traffic_raw
GROUP BY day_of_week, day_name
ORDER BY day_of_week;
-- Monday: 12,450 avg  |  Saturday: 1,117  |  Sunday: 1,057
-- Weekdays drive 96.4% of all traffic volume


-- ---------------------------------------------------------------
-- Q10. Weekday vs Weekend comparison — clean summary.
--      The IF() function picks a label based on the flag column.
-- ---------------------------------------------------------------
SELECT
    IF(is_weekend = 0, 'Weekday', 'Weekend')
                                      AS day_type,
    COUNT(*)                          AS hourly_readings,
    ROUND(AVG(traffic_count), 1)      AS avg_hourly_traffic,
    SUM(traffic_count)                AS total_traffic,
    MAX(traffic_count)                AS peak_traffic,
    ROUND(SUM(traffic_count) * 100.0
          / (SELECT SUM(traffic_count) FROM web_traffic_raw), 1)
                                      AS pct_of_total_traffic
FROM web_traffic_raw
GROUP BY is_weekend;
-- Weekday share: 96.4% of all traffic  |  Weekend: only 3.6%


-- ---------------------------------------------------------------
-- Q11. Business hours vs off-hours.
--      Business hours = 8 AM to 5 PM (Monday–Friday is implied
--      because weekends are naturally low).
-- ---------------------------------------------------------------
SELECT
    IF(is_business_hr = 1, 'Business Hours (8am-5pm)', 'Off Hours')
                                      AS period,
    COUNT(*)                          AS hourly_readings,
    ROUND(AVG(traffic_count), 1)      AS avg_hourly_traffic,
    SUM(traffic_count)                AS total_traffic,
    ROUND(SUM(traffic_count) * 100.0
          / (SELECT SUM(traffic_count) FROM web_traffic_raw), 1)
                                      AS pct_of_total_traffic
FROM web_traffic_raw
GROUP BY is_business_hr;
-- Business hours: 80.7% of all traffic despite being fewer hours


-- ---------------------------------------------------------------
-- Q12. Hour-by-day heatmap — shows traffic for every
--      hour × weekday combination. Great for planning.
-- ---------------------------------------------------------------
SELECT
    hour_of_day,
    ROUND(AVG(CASE WHEN day_name='Monday'    THEN traffic_count END),0) AS Mon,
    ROUND(AVG(CASE WHEN day_name='Tuesday'   THEN traffic_count END),0) AS Tue,
    ROUND(AVG(CASE WHEN day_name='Wednesday' THEN traffic_count END),0) AS Wed,
    ROUND(AVG(CASE WHEN day_name='Thursday'  THEN traffic_count END),0) AS Thu,
    ROUND(AVG(CASE WHEN day_name='Friday'    THEN traffic_count END),0) AS Fri,
    ROUND(AVG(CASE WHEN day_name='Saturday'  THEN traffic_count END),0) AS Sat,
    ROUND(AVG(CASE WHEN day_name='Sunday'    THEN traffic_count END),0) AS Sun
FROM web_traffic_raw
GROUP BY hour_of_day
ORDER BY hour_of_day;
-- This pivots the data: rows = hours, columns = days
-- CASE WHEN filters only that day's rows; AVG ignores NULLs


--  PHASE 5 : ADVANCED ANALYTICS WITH WINDOW FUNCTIONS
-- Window functions perform calculations "across" a set of rows
-- related to the current row, without collapsing rows like GROUP BY.
-- Syntax: FUNCTION() OVER (PARTITION BY ... ORDER BY ...)

-- ---------------------------------------------------------------
-- Q13. Daily traffic ranked within each month.
--      RANK() assigns position 1 to the highest traffic day in
--      each month. PARTITION BY restarts rank per month.
-- ---------------------------------------------------------------
SELECT
    traffic_date,
    month_name,
    day_name,
    SUM(traffic_count)                AS daily_total,
    RANK() OVER (
        PARTITION BY traffic_month    -- rank WITHIN each month
        ORDER BY SUM(traffic_count) DESC
    )                                 AS rank_in_month
FROM web_traffic_raw
GROUP BY traffic_date, month_name, day_name, traffic_month
ORDER BY traffic_month, rank_in_month
LIMIT 30;


-- ---------------------------------------------------------------
-- Q14. Cumulative (running) total of traffic by date.
--      SUM() OVER with ORDER BY creates a running total —
--      shows how total traffic accumulates day after day.
-- ---------------------------------------------------------------
SELECT
    traffic_date,
    SUM(traffic_count)                AS daily_total,
    SUM(SUM(traffic_count)) OVER (
        ORDER BY traffic_date
        ROWS UNBOUNDED PRECEDING      -- sum all rows up to current
    )                                 AS cumulative_total,
    ROUND(
      SUM(SUM(traffic_count)) OVER (ORDER BY traffic_date
          ROWS UNBOUNDED PRECEDING)
      * 100.0 / 23995560, 2)          AS pct_of_total_reached
FROM web_traffic_raw
GROUP BY traffic_date
ORDER BY traffic_date;


-- ---------------------------------------------------------------
-- Q15. Day-over-day traffic change using LAG().
--      LAG(col, 1) gives the value from the PREVIOUS row.
--      Subtracting it shows the daily change in traffic.
-- ---------------------------------------------------------------
WITH daily_totals AS (
    -- CTE (Common Table Expression) = a named temporary result set
    -- Makes the query readable by breaking it into steps
    SELECT
        traffic_date,
        day_name,
        SUM(traffic_count) AS daily_total
    FROM web_traffic_raw
    GROUP BY traffic_date, day_name
)
SELECT
    traffic_date,
    day_name,
    daily_total,
    LAG(daily_total, 1) OVER (
        ORDER BY traffic_date
    )                                 AS prev_day_total,
    daily_total -
    LAG(daily_total, 1) OVER (ORDER BY traffic_date)
                                      AS day_over_day_change,
    ROUND(
      (daily_total - LAG(daily_total,1) OVER (ORDER BY traffic_date))
      / LAG(daily_total,1) OVER (ORDER BY traffic_date) * 100, 1
    )                                 AS pct_change
FROM daily_totals
ORDER BY traffic_date;


-- ---------------------------------------------------------------
-- Q16. Percentile bucketing of traffic hours using NTILE().
--      NTILE(4) divides all rows into 4 equal groups (quartiles).
--      Q1 = bottom 25%, Q4 = top 25% of traffic hours.
-- ---------------------------------------------------------------
SELECT
    record_id,
    traffic_time,
    traffic_count,
    NTILE(4) OVER (
        ORDER BY traffic_count
    )                                 AS traffic_quartile
FROM web_traffic_raw
ORDER BY traffic_count DESC
LIMIT 30;


-- ---------------------------------------------------------------
-- Q17. Moving 3-hour average — smooths out short-term spikes
--      within each day. Useful for real-time monitoring.
-- ---------------------------------------------------------------
SELECT
    traffic_time,
    traffic_count,
    ROUND(
      AVG(traffic_count) OVER (
        ORDER BY traffic_time
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING  -- 3-hour window
      ), 1)                           AS moving_3hr_avg,
    traffic_count -
    ROUND(AVG(traffic_count) OVER (
        ORDER BY traffic_time
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING), 1)
                                      AS deviation_from_avg
FROM web_traffic_raw
ORDER BY traffic_time
LIMIT 50;


--  PHASE 6 : VIEWS (Reusable saved queries)
-- A VIEW is a stored query that behaves like a virtual table.
-- You can SELECT from a view just like a real table.
-- Views don't store data — they re-run the query each time.

-- ---------------------------------------------------------------
-- VIEW 1 : Daily summary — the most commonly needed aggregation
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW vw_daily_summary AS
SELECT
    traffic_date,
    day_name,
    month_name,
    traffic_week,
    is_weekend,
    COUNT(*)                          AS hourly_readings,
    SUM(traffic_count)                AS daily_total,
    ROUND(AVG(traffic_count), 1)      AS avg_per_hour,
    MAX(traffic_count)                AS peak_hour,
    MIN(traffic_count)                AS slowest_hour,
    SUM(is_spike)                     AS spike_hours
FROM web_traffic_raw
GROUP BY traffic_date, day_name, month_name, traffic_week, is_weekend;

-- How to use it:
SELECT * FROM vw_daily_summary ORDER BY daily_total DESC LIMIT 10;


-- ---------------------------------------------------------------
-- VIEW 2 : Hourly pattern — average behaviour for each hour
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW vw_hourly_pattern AS
SELECT
    hour_of_day,
    CASE
        WHEN hour_of_day = 0  THEN '12 AM'
        WHEN hour_of_day < 12 THEN CONCAT(hour_of_day, ' AM')
        WHEN hour_of_day = 12 THEN '12 PM'
        ELSE CONCAT(hour_of_day - 12, ' PM')
    END                               AS hour_label,
    is_business_hr,
    COUNT(*)                          AS observations,
    ROUND(AVG(traffic_count), 1)      AS avg_traffic,
    MAX(traffic_count)                AS max_traffic,
    MIN(traffic_count)                AS min_traffic,
    ROUND(STD(traffic_count), 1)      AS std_dev_traffic
FROM web_traffic_raw
GROUP BY hour_of_day, is_business_hr;

SELECT * FROM vw_hourly_pattern ORDER BY hour_of_day;


-- ---------------------------------------------------------------
-- VIEW 3 : Monthly KPI dashboard
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_kpi AS
SELECT
    traffic_year,
    traffic_month,
    month_name,
    COUNT(*)                          AS hourly_readings,
    SUM(traffic_count)                AS total_traffic,
    ROUND(AVG(traffic_count), 1)      AS avg_hourly_traffic,
    MAX(traffic_count)                AS peak_traffic,
    MIN(traffic_count)                AS min_traffic,
    SUM(is_spike)                     AS spike_count,
    COUNT(DISTINCT traffic_date)      AS active_days
FROM web_traffic_raw
GROUP BY traffic_year, traffic_month, month_name;

SELECT * FROM vw_monthly_kpi ORDER BY traffic_month;


-- ---------------------------------------------------------------
-- VIEW 4 : Spike events — all anomalous traffic hours
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW vw_spike_events AS
SELECT
    record_id,
    traffic_time,
    traffic_date,
    day_name,
    hour_of_day,
    month_name,
    traffic_count,
    ROUND((traffic_count - 8591.0) / 11479.0, 2)
                                      AS z_score   -- how many std devs above mean
FROM web_traffic_raw
WHERE is_spike = 1
ORDER BY traffic_count DESC;

-- A z_score of 2.0+ means statistically unusual traffic
SELECT * FROM vw_spike_events LIMIT 15;


--  PHASE 7 : STORED PROCEDURES
-- A stored procedure is a saved, named SQL program you can call
-- with CALL procedure_name(arguments).
-- They accept input parameters (IN) and are great for repeatable
-- analysis tasks.

-- ---------------------------------------------------------------
-- PROCEDURE 1 : Get traffic report for any specific date.
--   Usage : CALL sp_daily_report('2020-02-03');
--           CALL sp_daily_report('2020-03-26');
-- ---------------------------------------------------------------
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_daily_report$$
CREATE PROCEDURE sp_daily_report(
    IN p_date DATE    -- input: the date you want to analyse
)
BEGIN
    -- Section 1: Day-level summary
    SELECT
        p_date                        AS report_date,
        MAX(day_name)                 AS day_of_week,
        MAX(month_name)               AS month,
        COUNT(*)                      AS total_readings,
        SUM(traffic_count)            AS total_traffic,
        ROUND(AVG(traffic_count),1)   AS avg_per_hour,
        MAX(traffic_count)            AS peak_traffic,
        MIN(traffic_count)            AS min_traffic,
        SUM(is_spike)                 AS spike_hours,
        -- Rank this day among all days by traffic
        (SELECT COUNT(*) + 1
         FROM (SELECT traffic_date, SUM(traffic_count) AS dt
               FROM web_traffic_raw GROUP BY traffic_date) d2
         WHERE d2.dt > (
             SELECT SUM(traffic_count)
             FROM web_traffic_raw WHERE traffic_date = p_date))
                                      AS traffic_rank_among_all_days
    FROM web_traffic_raw
    WHERE traffic_date = p_date;

    -- Section 2: Hour-by-hour breakdown for that day
    SELECT
        hour_of_day,
        traffic_count,
        traffic_category,
        IF(is_spike=1,'⚠ SPIKE','')   AS spike_flag
    FROM web_traffic_raw
    WHERE traffic_date = p_date
    ORDER BY hour_of_day;

    -- Log this analysis run
    INSERT INTO analysis_log (query_name, finding)
    VALUES (
        CONCAT('sp_daily_report(', p_date, ')'),
        CONCAT('Report generated for ', p_date)
    );
END$$

DELIMITER ;

-- Test it with real dates from the dataset
CALL sp_daily_report('2020-02-03');   -- highest traffic day
CALL sp_daily_report('2020-03-26');   -- day with 71,925 spike


-- ---------------------------------------------------------------
-- PROCEDURE 2 : Get traffic for a custom date range.
--   Usage : CALL sp_range_report('2020-02-01', '2020-02-29');
-- ---------------------------------------------------------------
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_range_report$$
CREATE PROCEDURE sp_range_report(
    IN p_start DATE,
    IN p_end   DATE
)
BEGIN
    -- Range summary
    SELECT
        p_start                       AS from_date,
        p_end                         AS to_date,
        DATEDIFF(p_end, p_start) + 1  AS days_in_range,
        COUNT(*)                      AS hourly_readings,
        SUM(traffic_count)            AS total_traffic,
        ROUND(AVG(traffic_count),1)   AS avg_hourly_traffic,
        MAX(traffic_count)            AS peak_traffic,
        SUM(is_spike)                 AS spike_count
    FROM web_traffic_raw
    WHERE traffic_date BETWEEN p_start AND p_end;

    -- Daily breakdown within the range
    SELECT
        traffic_date,
        day_name,
        SUM(traffic_count)            AS daily_total,
        ROUND(AVG(traffic_count),1)   AS avg_per_hour,
        MAX(traffic_count)            AS peak_hour,
        SUM(is_spike)                 AS spikes
    FROM web_traffic_raw
    WHERE traffic_date BETWEEN p_start AND p_end
    GROUP BY traffic_date, day_name
    ORDER BY traffic_date;

    -- Hour-of-day pattern within the range
    SELECT
        hour_of_day,
        ROUND(AVG(traffic_count),1)   AS avg_traffic_this_range
    FROM web_traffic_raw
    WHERE traffic_date BETWEEN p_start AND p_end
    GROUP BY hour_of_day
    ORDER BY hour_of_day;
END$$

DELIMITER ;

-- Test calls
CALL sp_range_report('2020-02-01', '2020-02-29');   -- all of February
CALL sp_range_report('2020-03-01', '2020-03-31');   -- all of March
CALL sp_range_report('2020-04-01', '2020-04-30');   -- all of April


-- ---------------------------------------------------------------
-- PROCEDURE 3 : Full executive report — all KPIs in one call.
--   Usage : CALL sp_executive_report();
-- ---------------------------------------------------------------
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_executive_report$$
CREATE PROCEDURE sp_executive_report()
BEGIN
    SELECT '=== 1. DATASET OVERVIEW ===' AS section;
    SELECT COUNT(*) AS records, SUM(traffic_count) AS total_traffic,
           ROUND(AVG(traffic_count),1) AS avg_hourly,
           MAX(traffic_count) AS peak, MIN(traffic_count) AS min_traffic
    FROM web_traffic_raw;

    SELECT '=== 2. MONTHLY PERFORMANCE ===' AS section;
    SELECT * FROM vw_monthly_kpi ORDER BY traffic_month;

    SELECT '=== 3. HOURLY PATTERN ===' AS section;
    SELECT * FROM vw_hourly_pattern ORDER BY hour_of_day;

    SELECT '=== 4. WEEKDAY vs WEEKEND ===' AS section;
    SELECT IF(is_weekend=0,'Weekday','Weekend') AS day_type,
           COUNT(*) AS records, ROUND(AVG(traffic_count),1) AS avg_traffic,
           SUM(traffic_count) AS total_traffic,
           ROUND(SUM(traffic_count)*100.0/23995560,1) AS pct_of_total
    FROM web_traffic_raw GROUP BY is_weekend;

    SELECT '=== 5. TOP 10 PEAK DAYS ===' AS section;
    SELECT traffic_date, day_name, SUM(traffic_count) AS daily_total
    FROM web_traffic_raw
    GROUP BY traffic_date, day_name
    ORDER BY daily_total DESC LIMIT 10;

    SELECT '=== 6. TOP 10 LOWEST TRAFFIC DAYS ===' AS section;
    SELECT traffic_date, day_name, SUM(traffic_count) AS daily_total
    FROM web_traffic_raw
    GROUP BY traffic_date, day_name
    ORDER BY daily_total ASC LIMIT 10;

    SELECT '=== 7. TRAFFIC SPIKES (top 10) ===' AS section;
    SELECT * FROM vw_spike_events LIMIT 10;

    SELECT '=== 8. TRAFFIC CATEGORY DISTRIBUTION ===' AS section;
    SELECT traffic_category, COUNT(*) AS records,
           ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM web_traffic_raw),1) AS pct
    FROM web_traffic_raw GROUP BY traffic_category
    ORDER BY FIELD(traffic_category,'Peak','High','Medium','Low');

    INSERT INTO analysis_log(query_name, finding)
    VALUES('sp_executive_report', 'Full report generated');
END$$

DELIMITER ;

CALL sp_executive_report();


--  PHASE 8 : INSIGHT QUERIES (Business Recommendations)

-- ---------------------------------------------------------------
-- INSIGHT 1 : Optimal server scaling windows.
--   Find the exact hours that contribute 80% of daily traffic.
--   These hours need max server capacity.
-- ---------------------------------------------------------------
WITH hourly_avg AS (
    SELECT
        hour_of_day,
        ROUND(AVG(traffic_count), 1) AS avg_traffic
    FROM web_traffic_raw
    GROUP BY hour_of_day
),
total AS (
    SELECT SUM(avg_traffic) AS grand_total FROM hourly_avg
)
SELECT
    h.hour_of_day,
    h.avg_traffic,
    ROUND(h.avg_traffic / t.grand_total * 100, 2)   AS pct_of_day_traffic,
    ROUND(SUM(h.avg_traffic) OVER (ORDER BY h.avg_traffic DESC
          ROWS UNBOUNDED PRECEDING)
          / t.grand_total * 100, 1)                 AS cumulative_pct
FROM hourly_avg h, total t
ORDER BY h.avg_traffic DESC;
-- Hours 9–16 carry ~80% of all traffic → scale servers for those hours


-- ---------------------------------------------------------------
-- INSIGHT 2 : Best time for maintenance (lowest traffic window).
--   Maintenance should happen in the 4-hour window with
--   the least average traffic.
-- ---------------------------------------------------------------
SELECT
    hour_of_day                       AS window_start,
    ROUND(AVG(traffic_count), 1)      AS avg_traffic_in_window,
    -- Sum this hour + next 3 hours using window function
    ROUND(SUM(AVG(traffic_count)) OVER (
        ORDER BY hour_of_day
        ROWS BETWEEN CURRENT ROW AND 3 FOLLOWING
    ), 1)                             AS total_4hr_window_avg
FROM web_traffic_raw
GROUP BY hour_of_day
ORDER BY total_4hr_window_avg ASC
LIMIT 5;
-- Expected: 1 AM–4 AM window is safest for maintenance


-- ---------------------------------------------------------------
-- INSIGHT 3 : Traffic anomaly calendar — count spike hours
--   per day and flag "high-alert" days (3+ spike hours).
-- ---------------------------------------------------------------
SELECT
    traffic_date,
    day_name,
    month_name,
    SUM(traffic_count)                AS daily_total,
    SUM(is_spike)                     AS spike_hours,
    CASE
        WHEN SUM(is_spike) >= 3 THEN 'HIGH ALERT'
        WHEN SUM(is_spike) >= 1 THEN 'ELEVATED'
        ELSE 'NORMAL'
    END                               AS alert_level
FROM web_traffic_raw
GROUP BY traffic_date, day_name, month_name
HAVING SUM(is_spike) >= 1             -- only show days that had spikes
ORDER BY SUM(is_spike) DESC, daily_total DESC;


-- ---------------------------------------------------------------
-- INSIGHT 4 : Weekend traffic profile — what hours get traffic?
--   Weekends are mostly dead but certain hours still spike.
-- ---------------------------------------------------------------
SELECT
    hour_of_day,
    ROUND(AVG(CASE WHEN is_weekend=0 THEN traffic_count END), 1)
                                      AS weekday_avg,
    ROUND(AVG(CASE WHEN is_weekend=1 THEN traffic_count END), 1)
                                      AS weekend_avg,
    -- Ratio: weekend traffic as % of weekday
    ROUND(
      AVG(CASE WHEN is_weekend=1 THEN traffic_count END) /
      AVG(CASE WHEN is_weekend=0 THEN traffic_count END) * 100, 1
    )                                 AS weekend_as_pct_of_weekday
FROM web_traffic_raw
GROUP BY hour_of_day
ORDER BY hour_of_day;


-- ---------------------------------------------------------------
-- INSIGHT 5 : Month-over-month growth analysis.
--   Is traffic growing or declining over time?
-- ---------------------------------------------------------------
WITH monthly AS (
    SELECT
        traffic_month,
        month_name,
        SUM(traffic_count)  AS total_traffic,
        COUNT(DISTINCT traffic_date) AS active_days,
        ROUND(SUM(traffic_count) / COUNT(DISTINCT traffic_date), 1) AS avg_daily
    FROM web_traffic_raw
    GROUP BY traffic_month, month_name
)
SELECT
    traffic_month,
    month_name,
    total_traffic,
    avg_daily,
    LAG(total_traffic) OVER (ORDER BY traffic_month)
                                      AS prev_month_traffic,
    ROUND(
      (total_traffic - LAG(total_traffic) OVER (ORDER BY traffic_month))
      / LAG(total_traffic) OVER (ORDER BY traffic_month) * 100, 1
    )                                 AS growth_pct
FROM monthly
ORDER BY traffic_month;
-- Feb: +87.9%  |  Mar: +12.1%  |  Apr: +12.2%  |  May: incomplete month


-- ---------------------------------------------------------------
-- INSIGHT 6 : Traffic consistency score per hour.
--   Low coefficient of variation (CV) = predictable traffic hour.
--   High CV = volatile/unpredictable hour.
--   CV = (std_dev / mean) × 100
-- ---------------------------------------------------------------
SELECT
    hour_of_day,
    ROUND(AVG(traffic_count), 1)      AS avg_traffic,
    ROUND(STD(traffic_count), 1)      AS std_dev,
    ROUND(STD(traffic_count)
          / AVG(traffic_count) * 100, 1)
                                      AS coefficient_of_variation,
    CASE
        WHEN STD(traffic_count)/AVG(traffic_count) < 0.5
            THEN 'Predictable'
        WHEN STD(traffic_count)/AVG(traffic_count) < 1.0
            THEN 'Moderate'
        ELSE 'Volatile'
    END                               AS traffic_stability
FROM web_traffic_raw
GROUP BY hour_of_day
ORDER BY coefficient_of_variation ASC;

--  PHASE 9 : FINAL LOG & SUMMARY

INSERT INTO analysis_log (query_name, finding)
VALUES
    ('Monthly peak',    'April 2020 highest month: 6,705,879 total traffic'),
    ('Daily peak',      '2020-02-03 highest day: 466,050 visits'),
    ('Hourly peak',     '11 AM average: 23,627 visits — peak business hour'),
    ('Spike events',    '144 hourly spike events detected (5.2% of readings)'),
    ('Weekday share',   'Weekdays = 96.4% of all traffic; weekends = 3.6%'),
    ('Maintenance',     'Safest window: 1 AM – 4 AM (lowest traffic)'),
    ('Growth',          'Feb vs Jan growth: +87.9% month-over-month'),
    ('Project done',    'All 9 phases, 4 views, 3 stored procs complete');

SELECT * FROM analysis_log ORDER BY logged_at;
-- END