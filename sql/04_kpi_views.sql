-- Reusable reporting views.

USE healthcare_appointment_sql;

CREATE OR REPLACE VIEW v_slot_fact AS
SELECT
    sl.slot_id,
    sl.slot_date,
    CAST(DATE_FORMAT(sl.slot_date, '%Y-%m-01') AS DATE) AS month_start,
    sl.slot_hour,
    sl.weekday_name,
    CASE
        WHEN sl.slot_hour < 12 THEN 'morning'
        WHEN sl.slot_hour BETWEEN 12 AND 16 THEN 'afternoon'
        ELSE 'evening'
    END AS time_block,
    sl.is_available,
    c.clinic_id,
    c.clinic_name,
    c.city AS clinic_city,
    sp.specialty_id,
    sp.specialty_name,
    sp.standard_fee,
    d.doctor_id,
    d.doctor_name,
    d.employment_type,
    a.appointment_id,
    a.patient_id,
    a.patient_type,
    a.appointment_status,
    a.expected_fee,
    a.booking_lead_days,
    a.wait_time_days,
    a.is_no_show,
    a.is_cancelled,
    a.is_late_cancelled,
    a.is_attended,
    a.revenue_lost,
    CASE WHEN a.appointment_id IS NOT NULL THEN 1 ELSE 0 END AS is_booked,
    CASE WHEN sl.is_available = 1 AND a.appointment_id IS NULL THEN 1 ELSE 0 END AS is_unused
FROM slots sl
JOIN clinics c ON c.clinic_id = sl.clinic_id
JOIN specialties sp ON sp.specialty_id = sl.specialty_id
JOIN doctors d ON d.doctor_id = sl.doctor_id
LEFT JOIN v_appointments_clean a ON a.slot_id = sl.slot_id;

CREATE OR REPLACE VIEW v_monthly_kpis AS
WITH monthly AS (
    SELECT
        month_start,
        COUNT(*) AS total_slots,
        SUM(is_available = 1) AS available_slots,
        SUM(is_booked = 1) AS booked_slots,
        SUM(is_unused = 1) AS unused_slots,
        COUNT(appointment_id) AS total_appointments,
        SUM(is_attended = 1) AS attended_appointments,
        SUM(is_no_show = 1) AS no_show_appointments,
        SUM(is_cancelled = 1) AS cancelled_appointments,
        SUM(is_late_cancelled = 1) AS late_cancelled_appointments,
        ROUND(SUM(is_no_show = 1) / NULLIF(COUNT(appointment_id), 0), 4) AS no_show_rate,
        ROUND(SUM(is_cancelled = 1) / NULLIF(COUNT(appointment_id), 0), 4) AS cancellation_rate,
        ROUND(SUM(is_late_cancelled = 1) / NULLIF(COUNT(appointment_id), 0), 4) AS late_cancellation_rate,
        ROUND(SUM(is_booked = 1) / NULLIF(SUM(is_available = 1), 0), 4) AS utilization_rate,
        ROUND(AVG(wait_time_days), 1) AS avg_wait_time_days,
        ROUND(AVG(booking_lead_days), 1) AS avg_booking_lead_days,
        ROUND(SUM(revenue_lost), 2) AS revenue_leakage
    FROM v_slot_fact
    GROUP BY month_start
)
SELECT
    month_start,
    total_slots,
    available_slots,
    booked_slots,
    unused_slots,
    total_appointments,
    attended_appointments,
    no_show_appointments,
    cancelled_appointments,
    late_cancelled_appointments,
    no_show_rate,
    cancellation_rate,
    late_cancellation_rate,
    utilization_rate,
    avg_wait_time_days,
    avg_booking_lead_days,
    revenue_leakage,
    ROUND(
        (revenue_leakage - LAG(revenue_leakage) OVER (ORDER BY month_start))
        / NULLIF(LAG(revenue_leakage) OVER (ORDER BY month_start), 0),
        4
    ) AS revenue_leakage_mom_change
FROM monthly;

CREATE OR REPLACE VIEW v_specialty_performance AS
SELECT
    specialty_id,
    specialty_name,
    COUNT(*) AS total_slots,
    SUM(is_available = 1) AS available_slots,
    SUM(is_booked = 1) AS booked_slots,
    SUM(is_unused = 1) AS unused_slots,
    COUNT(appointment_id) AS total_appointments,
    SUM(is_attended = 1) AS attended_appointments,
    SUM(is_no_show = 1) AS no_show_appointments,
    SUM(is_cancelled = 1) AS cancelled_appointments,
    SUM(is_late_cancelled = 1) AS late_cancelled_appointments,
    ROUND(SUM(is_no_show = 1) / NULLIF(COUNT(appointment_id), 0), 4) AS no_show_rate,
    ROUND(SUM(is_booked = 1) / NULLIF(SUM(is_available = 1), 0), 4) AS utilization_rate,
    ROUND(AVG(wait_time_days), 1) AS avg_wait_time_days,
    ROUND(AVG(booking_lead_days), 1) AS avg_booking_lead_days,
    ROUND(SUM(revenue_lost), 2) AS revenue_leakage
FROM v_slot_fact
GROUP BY specialty_id, specialty_name;

CREATE OR REPLACE VIEW v_clinic_performance AS
SELECT
    clinic_id,
    clinic_name,
    clinic_city,
    COUNT(*) AS total_slots,
    SUM(is_available = 1) AS available_slots,
    SUM(is_booked = 1) AS booked_slots,
    SUM(is_unused = 1) AS unused_slots,
    COUNT(appointment_id) AS total_appointments,
    SUM(is_attended = 1) AS attended_appointments,
    SUM(is_no_show = 1) AS no_show_appointments,
    SUM(is_cancelled = 1) AS cancelled_appointments,
    SUM(is_late_cancelled = 1) AS late_cancelled_appointments,
    ROUND(SUM(is_no_show = 1) / NULLIF(COUNT(appointment_id), 0), 4) AS no_show_rate,
    ROUND(SUM(is_booked = 1) / NULLIF(SUM(is_available = 1), 0), 4) AS utilization_rate,
    ROUND(AVG(wait_time_days), 1) AS avg_wait_time_days,
    ROUND(AVG(booking_lead_days), 1) AS avg_booking_lead_days,
    ROUND(SUM(revenue_lost), 2) AS revenue_leakage
FROM v_slot_fact
GROUP BY clinic_id, clinic_name, clinic_city;

CREATE OR REPLACE VIEW v_action_opportunities AS
WITH doctor_utilization AS (
    SELECT
        doctor_id,
        doctor_name,
        clinic_name,
        specialty_name,
        ROUND(AVG(standard_fee), 2) AS average_fee,
        SUM(is_available = 1) AS available_slots,
        SUM(is_booked = 1) AS booked_slots,
        ROUND(SUM(is_booked = 1) / NULLIF(SUM(is_available = 1), 0), 4) AS utilization_rate
    FROM v_slot_fact
    GROUP BY doctor_id, doctor_name, clinic_name, specialty_name
    HAVING available_slots >= 120
),
opportunities AS (
    SELECT
        'No-show risk' AS opportunity_area,
        CONCAT(specialty_name, ' no-show rate') AS business_issue,
        'no_show_rate' AS metric_name,
        no_show_rate AS metric_value,
        revenue_leakage AS priority_score,
        'Add confirmation and reminder rules for high-risk appointment types.' AS recommendation
    FROM v_specialty_performance
    WHERE total_appointments >= 500

    UNION ALL

    SELECT
        'Revenue leakage',
        CONCAT(clinic_name, ' lost revenue'),
        'revenue_leakage',
        revenue_leakage,
        revenue_leakage,
        'Prioritize waitlists and deposits where lost revenue is highest.'
    FROM v_clinic_performance

    UNION ALL

    SELECT
        'Low utilization',
        CONCAT(doctor_name, ' utilization at ', clinic_name),
        'utilization_rate',
        utilization_rate,
        (available_slots - booked_slots) * average_fee,
        'Review schedule mix, weak time blocks and local demand.'
    FROM doctor_utilization
    WHERE utilization_rate < 0.65

    UNION ALL

    SELECT
        'Patient access',
        CONCAT(specialty_name, ' average waiting time'),
        'avg_wait_time_days',
        avg_wait_time_days,
        avg_wait_time_days * total_appointments,
        'Shift capacity toward specialties with long waiting times.'
    FROM v_specialty_performance
)
SELECT
    ROW_NUMBER() OVER (ORDER BY priority_score DESC) AS priority_rank,
    opportunity_area,
    business_issue,
    metric_name,
    metric_value,
    recommendation
FROM opportunities;
