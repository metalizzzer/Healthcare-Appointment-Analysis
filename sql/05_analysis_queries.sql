-- Final business analysis queries.

USE healthcare_appointment_sql;

-- 1. KPI overview: network-level appointment, utilization and leakage picture.
SELECT
    COUNT(appointment_id) AS total_appointments,
    SUM(is_attended = 1) AS attended_appointments,
    ROUND(SUM(is_no_show = 1) / NULLIF(COUNT(appointment_id), 0), 4) AS no_show_rate,
    ROUND(SUM(is_cancelled = 1) / NULLIF(COUNT(appointment_id), 0), 4) AS cancellation_rate,
    ROUND(SUM(is_booked = 1) / NULLIF(SUM(is_available = 1), 0), 4) AS utilization_rate,
    ROUND(AVG(wait_time_days), 1) AS avg_wait_time_days,
    ROUND(AVG(booking_lead_days), 1) AS avg_booking_lead_days,
    ROUND(SUM(revenue_lost), 2) AS revenue_leakage
FROM v_slot_fact;

-- 2. No-show by specialty and clinic: where missed appointments are concentrated.
WITH performance AS (
    SELECT
        specialty_name,
        clinic_name,
        COUNT(*) AS appointments,
        SUM(is_no_show) AS no_show_appointments,
        ROUND(SUM(is_no_show) / NULLIF(COUNT(*), 0), 4) AS no_show_rate
    FROM v_appointments_clean
    GROUP BY specialty_name, clinic_name
    HAVING appointments >= 80
)
SELECT
    specialty_name,
    clinic_name,
    appointments,
    no_show_appointments,
    no_show_rate,
    RANK() OVER (ORDER BY no_show_rate DESC) AS no_show_rank
FROM performance
ORDER BY no_show_rank, appointments DESC;

-- 3. Revenue leakage ranking: where no-shows and late cancellations cost most.
WITH leakage AS (
    SELECT
        specialty_name,
        clinic_name,
        COUNT(*) AS appointments,
        ROUND(SUM(revenue_lost), 2) AS revenue_leakage
    FROM v_appointments_clean
    GROUP BY specialty_name, clinic_name
)
SELECT
    specialty_name,
    clinic_name,
    appointments,
    revenue_leakage,
    RANK() OVER (ORDER BY revenue_leakage DESC) AS leakage_rank
FROM leakage
ORDER BY leakage_rank;

-- 4. Weekday and time block: when no-show risk is highest.
SELECT
    weekday_name,
    time_block,
    COUNT(*) AS appointments,
    SUM(is_no_show) AS no_show_appointments,
    ROUND(SUM(is_no_show) / NULLIF(COUNT(*), 0), 4) AS no_show_rate
FROM v_appointments_clean
GROUP BY weekday_name, time_block
HAVING appointments >= 100
ORDER BY no_show_rate DESC, appointments DESC;

-- 5. Doctor utilization: doctors with lower booked-slot utilization.
WITH doctor_utilization AS (
    SELECT
        doctor_id,
        doctor_name,
        clinic_name,
        specialty_name,
        SUM(is_available = 1) AS available_slots,
        SUM(is_booked = 1) AS booked_slots,
        SUM(is_unused = 1) AS unused_slots,
        ROUND(SUM(is_booked = 1) / NULLIF(SUM(is_available = 1), 0), 4) AS utilization_rate
    FROM v_slot_fact
    GROUP BY doctor_id, doctor_name, clinic_name, specialty_name
    HAVING available_slots >= 120
)
SELECT
    doctor_id,
    doctor_name,
    clinic_name,
    specialty_name,
    available_slots,
    booked_slots,
    unused_slots,
    utilization_rate,
    DENSE_RANK() OVER (ORDER BY utilization_rate ASC) AS low_utilization_rank
FROM doctor_utilization
ORDER BY low_utilization_rank, available_slots DESC
LIMIT 12;

-- 6. Waiting time by specialty: where patient access is weakest.
SELECT
    specialty_name,
    total_appointments,
    avg_wait_time_days,
    avg_booking_lead_days,
    RANK() OVER (ORDER BY avg_wait_time_days DESC) AS waiting_time_rank
FROM v_specialty_performance
ORDER BY waiting_time_rank;

-- 7. Monthly trend: no-show rate and revenue leakage movement.
SELECT
    month_start,
    total_appointments,
    no_show_rate,
    revenue_leakage,
    LAG(no_show_rate) OVER (ORDER BY month_start) AS prior_month_no_show_rate,
    ROUND(
        no_show_rate - LAG(no_show_rate) OVER (ORDER BY month_start),
        4
    ) AS no_show_rate_point_change,
    LAG(revenue_leakage) OVER (ORDER BY month_start) AS prior_month_revenue_leakage,
    revenue_leakage_mom_change
FROM v_monthly_kpis
ORDER BY month_start;

-- Optional view check: management action shortlist from the reporting layer.
SELECT
    priority_rank,
    opportunity_area,
    business_issue,
    metric_name,
    metric_value,
    recommendation
FROM v_action_opportunities
ORDER BY priority_rank
LIMIT 10;
