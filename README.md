# Web Traffic Analytics — MySQL Project

> A complete SQL-based web traffic analysis project built on MySQL Workbench.  
> Analyses 2,793 hourly traffic readings from January to May 2020 to uncover peak hours, traffic trends, spike events, and actionable business insights.

---

## Dataset Overview

| Property | Value |
|---|---|
| **File** | `web_traffic.csv` |
| **Rows** | 2,793 hourly readings |
| **Columns** | `Timestamp`, `TrafficCount` |
| **Date Range** | 2020-01-20 → 2020-05-17 |
| **Interval** | ~1 hour per record |
| **Traffic Range** | 22 (min) → 71,925 (max) |
| **Mean Traffic** | 8,591 visits/hour |
| **Total Traffic** | 23,995,560 visits |

---

## Database Objects Created

### Tables
| Table | Purpose |
|---|---|
| `web_traffic_raw` | Main data table — stores all 2,793 records with 12 derived columns added |
| `analysis_log` | Audit trail — logs every major query/procedure run with timestamps |

### Derived Columns Added to `web_traffic_raw`
| Column | Type | Description |
|---|---|---|
| `traffic_year` | INT | Year extracted from timestamp |
| `traffic_month` | INT | Month number (1–12) |
| `month_name` | VARCHAR | Month name (e.g. "February") |
| `traffic_week` | INT | ISO week number |
| `traffic_date` | DATE | Date-only part of timestamp |
| `hour_of_day` | INT | Hour 0–23 |
| `day_of_week` | INT | 1=Sunday … 7=Saturday |
| `day_name` | VARCHAR | e.g. "Monday" |
| `is_weekend` | TINYINT | 1 = Saturday/Sunday, 0 = weekday |
| `is_business_hr` | TINYINT | 1 = 8 AM to 5 PM, 0 = off-hours |
| `traffic_category` | VARCHAR | Low / Medium / High / Peak |
| `is_spike` | TINYINT | 1 if traffic > 31,549 (mean + 2×std) |

### Views (Reusable Saved Queries)
| View | Description |
|---|---|
| `vw_daily_summary` | Daily totals, averages, peak hours, spike count |
| `vw_hourly_pattern` | Average traffic for each hour of the day |
| `vw_monthly_kpi` | Monthly KPIs — total traffic, peaks, spike count |
| `vw_spike_events` | All 144 anomalous spike hours with z-scores |

### Stored Procedures
| Procedure | Usage | Description |
|---|---|---|
| `sp_daily_report(date)` | `CALL sp_daily_report('2020-02-03');` | Full hourly breakdown for any single day |
| `sp_range_report(start, end)` | `CALL sp_range_report('2020-02-01','2020-02-29');` | Summary + daily breakdown for any date range |
| `sp_executive_report()` | `CALL sp_executive_report();` | Complete report with all KPIs in one call |


### Stored Procedures
| `sp_daily_report(date)` | `CALL sp_daily_report('2020-02-03');` | Full hourly breakdown for any single day |
| `sp_range_report(start, end)` | `CALL sp_range_report('2020-02-01','2020-02-29');` | Summary + daily breakdown for any date range |
| `sp_executive_report()` | `CALL sp_executive_report();` | Complete report with all KPIs in one call |

---
### Step 5 — Run remaining phases in order
Run each phase by selecting it and pressing `Ctrl + Shift + Enter`.

| Phase | What it does |
|---|---|
| Phase 1 | Setup — database, table, derived columns |
| Phase 2 | Exploratory analysis — overview, categories, spikes |
| Phase 3 | Time trends — monthly, weekly, daily, rolling averages |
| Phase 4 | Hourly & day-of-week patterns + heatmap |
| Phase 5 | Advanced window functions — rank, running total, LAG, NTILE |
| Phase 6 | Views — create 4 reusable virtual tables |
| Phase 7 | Stored procedures — create 3 callable reports |
| Phase 8 | Insight queries — 6 business intelligence findings |
| Phase 9 | Final log and summary |

---

## Key Findings

### Traffic Volume
- **Total traffic:** 23,995,560 visits across the dataset
- **Highest day:** 2020-02-03 with **466,050** visits
- **Lowest day:** 2020-02-09 with **3,525** visits
- **Peak single hour:** 2020-03-26 at 21:30 with **71,925** visits

### Monthly Trends
| Month | Total Traffic | Avg Hourly | Growth |
|---|---|---|---|
| January 2020 | 2,834,445 | 9,774 | — (partial month) |
| February 2020 | 5,331,499 | 7,817 | +87.9% |
| March 2020 | 5,975,935 | 8,562 | +12.1% |
| April 2020 | 6,705,879 | 9,262 | +12.2% |
| May 2020 | 3,147,802 | 7,889 | — (partial month) |

### Hourly Pattern
- **Peak hours:** 10 AM (21,476 avg) and **11 AM (23,627 avg)**
- **Quietest hours:** 3 AM (317 avg) and 2 AM (485 avg)
- Business hours (8 AM–5 PM) carry **80.7%** of all traffic

### Weekday vs Weekend
| Day Type | Avg Hourly Traffic | Share of Total |
|---|---|---|
| Weekday | 11,567 | 96.4% |
| Weekend | 1,088 | 3.6% |

### Traffic Spikes
- **144 spike events** detected (5.2% of all readings)
- Spike threshold: **31,549** visits/hour (mean + 2×std deviation)
- Spikes occur mostly **10 AM – 2 PM on weekdays**

### Traffic Category Distribution
| Category | Range | Records | % |
|---|---|---|---|
| Peak | ≥ 20,000 | 499 | 17.9% |
| High | 5,000–19,999 | 575 | 20.6% |
| Medium | 500–4,999 | 1,201 | 43.0% |
| Low | < 500 | 518 | 18.5% |

---

