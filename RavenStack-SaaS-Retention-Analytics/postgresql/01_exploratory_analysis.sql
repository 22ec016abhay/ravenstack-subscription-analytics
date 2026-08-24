===================================================================
-- Project: RavenStack SaaS Subscription Health & Revenue Retention
-- File: 01_exploratory_analysis.sql
-- Purpose: Churn segmentation, revenue analysis, cohort/tenure analysis,
--          feature usage & support correlation, window function practice
-- Database: PostgreSQL (ravenstack_saas)
-- ===================================================================
CREATE TABLE accounts (
    account_id       VARCHAR(50) PRIMARY KEY,
    account_name     VARCHAR(255),
    industry         VARCHAR(50),
    country          VARCHAR(2),
    signup_date      DATE,
    referral_source  VARCHAR(50),
    plan_tier        VARCHAR(50),
    seats            INTEGER,
    is_trial         BOOLEAN,
    churn_flag       BOOLEAN
);

CREATE TABLE subscriptions (
    subscription_id   VARCHAR(50) PRIMARY KEY,
    account_id        VARCHAR(50) REFERENCES accounts(account_id),
    start_date        DATE,
    end_date          DATE,
    plan_tier         VARCHAR(50),
    seats             INTEGER,
    mrr_amount        NUMERIC(10,2),
    arr_amount        NUMERIC(10,2),
    is_trial          BOOLEAN,
    upgrade_flag      BOOLEAN,
    downgrade_flag    BOOLEAN,
    churn_flag        BOOLEAN,
    billing_frequency VARCHAR(20),
    auto_renew_flag   BOOLEAN
);

CREATE TABLE feature_usage (
    
    usage_id           VARCHAR(50),
    subscription_id    VARCHAR(50) REFERENCES subscriptions(subscription_id),
    usage_date         DATE,
    feature_name       VARCHAR(50),
    usage_count        INTEGER,
    usage_duration_secs INTEGER,
    error_count        INTEGER,
    is_beta_feature    BOOLEAN,
    row_key            integer primary key
);

CREATE TABLE support_tickets (
    
    ticket_id                   VARCHAR(50),
    account_id                  VARCHAR(50) REFERENCES accounts(account_id),
    submitted_at                TIMESTAMP,
    closed_at                   TIMESTAMP,
    resolution_time_hours       NUMERIC(10,2),
    priority                    VARCHAR(20),
    first_response_time_minutes INTEGER,
    satisfaction_score          INTEGER,
    escalation_flag              BOOLEAN
	
);

CREATE TABLE churn_events (
    churn_event_id           VARCHAR(50) PRIMARY KEY,
    account_id                VARCHAR(50) REFERENCES accounts(account_id),
    churn_date                 DATE,
    reason_code                 VARCHAR(50),
    refund_amount_usd           NUMERIC(10,2),
    preceding_upgrade_flag      BOOLEAN,
    preceding_downgrade_flag    BOOLEAN,
    is_reactivation              BOOLEAN,
    feedback_text                 TEXT
);
drop table feature_usage
SELECT column_name, ordinal_position
FROM information_schema.columns
WHERE table_name = 'feature_usage'
ORDER BY ordinal_position;

DROP TABLE support_tickets;

CREATE TABLE feature_usage (
    usage_id             VARCHAR(50),
    subscription_id      VARCHAR(50) REFERENCES subscriptions(subscription_id),
    usage_date           DATE,
    feature_name         VARCHAR(50),
    usage_count          INTEGER,
    usage_duration_secs  INTEGER,
    error_count          INTEGER,
    is_beta_feature      BOOLEAN,
    row_key              SERIAL PRIMARY KEY
);

--- to check the total now of row in each table,to verify the data load successfully---
SELECT 'accounts' AS table_name, COUNT(*) AS row_count FROM accounts
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'feature_usage', COUNT(*) FROM feature_usage
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets
UNION ALL
SELECT 'churn_events', COUNT(*) FROM churn_events;

--- 1. BASIC EXPLORATION ---
SELECT * FROM accounts    LIMIT 10;
SELECT * FROM subscriptions LIMIT 10;
SELECT * FROM feature_usage LIMIT 10;
SELECT * FROM support_tickets LIMIT 10;
SELECT * FROM churn_events LIMIT 10;

--- 2. CHURN RATE BY SEGMENT-----
select*from accounts;
-- 2.1 CHURN RATE BY PLAIN TIER----

SELECT plan_tier,
    COUNT(*) AS total_accounts,
    COUNT(*) FILTER (WHERE churn_flag = TRUE) AS churned_accounts,
    ROUND(COUNT(*) FILTER (WHERE churn_flag = TRUE)::NUMERIC / COUNT(*) * 100,2) AS churn_rate_pct
FROM accounts
GROUP BY plan_tier
ORDER BY churn_rate_pct DESC;
---2.2 CHURN RATE BY INDUSTRY---
SELECT industry,
count(*) as total_accounts,
 count(*) filter (where churn_flag = True) as churned_accunts,
 round(count(*) filter (where churn_flag= TRUE):: NUMERIC /COUNT(*)*100,2) as churn_rate_pct
from accounts
group by industry
order by churn_rate_pct desc;

---2.3 churn rate by country ---
select country,
count(*) as total_accounts,
count(*) filter(where churn_flag= true)
as churned_accounts,
round(count(*) filter (where churn_flag = true):: numeric /count(*)* 100,2) as churn_rate_pct
from accounts
group by country
order by churn_rate_pct desc;
--2.4 referral source ---
select referral_source,
count(*) as total_accounts,
count(*) filter(where churn_flag = true)
as churned_accounts,
round(count(*) filter (where churn_flag = true):: numeric /count(*)* 100,2) as churn_rate_pct
from accounts
group by referral_source
order by churn_rate_pct desc;

--- 3.REVENUE ANALYSIS----
select* from subscriptions;
---- 3.1 Total MRR/ARR by plan tier (uses subscriptions table)------

SELECT plan_tier,
    COUNT(*) AS subscription_count,
    SUM(mrr_amount) AS total_mrr,
    SUM(arr_amount) AS total_arr,
	ROUND(AVG(mrr_amount),2) AS avg_mrr_per_subscription
FROM subscriptions
GROUP BY plan_tier
ORDER BY total_mrr DESC;
---3.2 Active-only MRR (end_date is null = still active)---
select plan_tier,
count(*) as subcription_count,
sum(mrr_amount) as active_mrr
from subscriptions
where end_date is null
group by plan_tier
order by active_mrr desc;


--- 3.4 Revenue by billing frequency---
select billing_frequency,
count(*) as subcription_count,
sum(mrr_amount) as total_mrr,
round(avg(mrr_amount)) as avg_mrr
from subscriptions
group by billing_frequency;

--- 3.5 MRR contribution: does a small % of accounts drive a big % of revenue? (Pareto-style)---

/*Customers → their MRR → sort biggest first → calculate % → keep adding % 
→ find out how dependent the business is on its biggest customers.*/
with account_mrr as 
(select
account_id,
sum(mrr_amount) as total_mrr
from subscriptions
 WHERE end_date IS NULL
group by account_id

), 
ranked as (
select account_id,total_mrr,
rank() over(order  by total_mrr desc) as mrr_rank,
sum(total_mrr) over() as grand_total_mrr
from account_mrr

)
SELECT account_id,total_mrr,mrr_rank,
round(total_mrr/grand_total_mrr*100,2) as pct_total_mrr,
round(sum(total_mrr)over(order  by total_mrr desc)/grand_total_mrr*100,2 ) as cummutive_pct
FROM ranked
ORDER BY total_mrr DESC;
 
---- 4.  AVG TENURE / FEATURE USAGE / CHURN ANALYSIS

--- 4.1 Average tenure at churn, by plan tier----
--- avg month a customer stay before they churn or stop the plan on the basics of plan_tier---

select*from churn_events;
select*from accounts;


with tenure as (
select a.account_id,a.plan_tier,
 date_part('year',age(c.churn_date,a.signup_date)) * 12
 +
 date_part('month',age(c.churn_date,a.signup_date))
 as tenure_months
 from accounts a
 inner join  churn_events c
 on c.account_id=a.account_id
)
select plan_tier,
ROUND(avg(tenure_months):: NUMERIC,1) as avg_tenure_months,
min(tenure_months) as min_tenure,
max(tenure_months) as max_tenure
from tenure
group by plan_tier
order by avg_tenure_months desc;

---4.2 Total usage events and avg errors, churned vs active accounts----
---Do customers who churned use the product differently from customers who stayed?---
WITH usage_by_accounts as (
select s.account_id,
sum (f.usage_count) as total_usage,
sum(f.error_count) as total_error,
count(distinct f.feature_name) as distinct_feature_used
from feature_usage f
inner join subscriptions s 
on f.subscription_id = s.subscription_id
group by s.account_id
)
select a.churn_flag,
round(avg(t.total_usage),1)  as avg_total_usage,
round(avg(t.total_error),1) as avg_total_error,
round(avg(t.distinct_feature_used),1) as  avg_distinct_feature_used
FROM accounts a
inner join usage_by_accounts t 
on t.account_id=a.account_id
group by a.churn_flag;



----4.3 Most-used features overall---
select feature_name,
count(*) as usage_events,
sum(usage_count) as total_usage_count,
sum(error_count) as total_error_count
from feature_usage
group by feature_name
order by total_usage_count desc
limit 10;

--- 4.5 Beta feature usage vs error rate -----
select
is_beta_feature,
count(*) as usage_events,
round(avg(error_count),2) as avg_error_per_event
from feature_usage
group by is_beta_feature;

---- 5 SUPPORT TICKETS vs CHURN-----
----5.1 Ticket volume and satisfaction, churned vs active accounts---
WITH ticket_summary AS (
select account_id,
count(*) as ticket_count,
round(avg(satisfaction_score),2) as avg_satisfaction,
round(avg(resolution_time_hours),2) as avg_resolve_time,
count(*) filter (where escalation_flag = True) as escalation
from support_tickets
group by account_id
)
select a.churn_flag,
 round(avg(t.ticket_count), 2) AS avg_tickets_per_acc,
  round(avg(t.avg_satisfaction), 2) AS avg_satisfy_score,
  round(avg(t.avg_resolve_time), 2) AS avg_resolve_hours,
  round(avg(t.escalation), 2) AS avg_escaltion
  from accounts a 
  inner join ticket_summary t on
  t.account_id=a.account_id
  group by a.churn_flag;
 
  
  
----5.2 Ticket priority breakdown by churn status----
select a.churn_flag,
s.priority,
count(*) as ticket_count
from support_tickets s
inner join accounts a on s.account_id = a.account_id
group by a.churn_flag,s.priority
order by a.churn_flag,ticket_count desc;

---- 6. WINDOW FUNCTIONS PRACTICE SET------
----- 6.1 ROW_NUMBER: most recent subscription per account------
select*from (
select *, 
row_number()over(partition by account_id order by start_date desc) as rn from subscriptions)
ranked 
where rn=1;
)

-- 6.2 RANK: rank accounts by total MRR within their plan tier----
SELECT
    account_id,
    plan_tier,
    mrr_amount,
    RANK() OVER (PARTITION BY plan_tier ORDER BY mrr_amount DESC) AS rank_within_plan
FROM subscriptions
WHERE end_date IS NULL
ORDER BY plan_tier, rank_within_plan;

-- 6.3 LAG: days between an account's consecutive support tickets----
SELECT
    account_id,
    submitted_at,
    LAG(submitted_at) OVER (PARTITION BY account_id ORDER BY submitted_at) AS previous_ticket_date,
    submitted_at - LAG(submitted_at) OVER (PARTITION BY account_id ORDER BY submitted_at) AS days_since_last_ticket
FROM support_tickets
ORDER BY account_id, submitted_at;

-- 6.4 LEAD: next subscription start date per account (gap analysis)----
SELECT
    account_id,
    start_date,
    end_date,
    LEAD(start_date) OVER (PARTITION BY account_id ORDER BY start_date) AS next_subscription_start
FROM subscriptions
ORDER BY account_id, start_date;






