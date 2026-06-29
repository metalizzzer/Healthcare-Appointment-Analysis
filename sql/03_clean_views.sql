-- Cleaning layer for appointment-level analysis.

USE healthcare_appointment_sql;

CREATE OR REPLACE VIEW v_appointments_clean AS
WITH ranked_raw AS (
    SELECT
        a.*,
        ROW_NUMBER() OVER (
            PARTITION BY a.appointment_id, a.slot_id, a.patient_id, a.booked_at
            ORDER BY
                CASE WHEN a.expected_fee IS NOT NULL THEN 0 ELSE 1 END,
                CASE WHEN a.payment_status IS NOT NULL AND TRIM(a.payment_status) <> '' THEN 0 ELSE 1 END
        ) AS rn
    FROM appointments_raw a
),
standardized AS (
    SELECT
        r.appointment_id,
        r.slot_id,
        r.patient_id,
        r.booked_at,
        CASE
            WHEN LOWER(REPLACE(REPLACE(TRIM(r.appointment_status), '-', '_'), ' ', '_')) IN ('attended', 'completed', 'complete', 'checked_in') THEN 'attended'
            WHEN LOWER(REPLACE(REPLACE(TRIM(r.appointment_status), '-', '_'), ' ', '_')) IN ('no_show', 'noshow') THEN 'no_show'
            WHEN LOWER(REPLACE(REPLACE(TRIM(r.appointment_status), '-', '_'), ' ', '_')) IN ('cancelled', 'canceled', 'cancel') THEN 'cancelled'
            WHEN LOWER(REPLACE(REPLACE(TRIM(r.appointment_status), '-', '_'), ' ', '_')) IN ('late_cancelled', 'late_canceled', 'late_cancel') THEN 'late_cancelled'
            ELSE 'unknown'
        END AS appointment_status,
        NULLIF(TRIM(r.cancellation_reason), '') AS cancellation_reason,
        COALESCE(NULLIF(LOWER(TRIM(r.payment_status)), ''), 'unknown') AS payment_status,
        r.expected_fee,
        CASE
            WHEN LOWER(REPLACE(TRIM(r.source_channel), ' ', '_')) IN ('web', 'online') THEN 'web'
            WHEN LOWER(REPLACE(TRIM(r.source_channel), ' ', '_')) IN ('mobile_app', 'mobile', 'app') THEN 'mobile_app'
            WHEN LOWER(REPLACE(TRIM(r.source_channel), ' ', '_')) IN ('phone', 'phone_call', 'call_center') THEN 'phone'
            WHEN LOWER(REPLACE(TRIM(r.source_channel), ' ', '_')) IN ('referral', 'doctor_referral') THEN 'referral'
            WHEN LOWER(REPLACE(TRIM(r.source_channel), ' ', '_')) IN ('walk_in', 'walk-in', 'front_desk') THEN 'walk_in'
            ELSE 'unknown'
        END AS source_channel
    FROM ranked_raw r
    WHERE r.rn = 1
)
SELECT
    s.appointment_id,
    s.slot_id,
    s.patient_id,
    p.patient_type,
    p.age_group,
    p.city AS patient_city,
    sl.doctor_id,
    d.doctor_name,
    sl.clinic_id,
    c.clinic_name,
    c.city AS clinic_city,
    sl.specialty_id,
    sp.specialty_name,
    s.booked_at,
    sl.slot_start,
    sl.slot_end,
    sl.slot_date,
    sl.slot_hour,
    sl.weekday_name,
    CASE
        WHEN sl.slot_hour < 12 THEN 'morning'
        WHEN sl.slot_hour BETWEEN 12 AND 16 THEN 'afternoon'
        ELSE 'evening'
    END AS time_block,
    s.appointment_status,
    COALESCE(s.cancellation_reason, 'not_applicable') AS cancellation_reason,
    s.payment_status,
    s.source_channel,
    COALESCE(s.expected_fee, sp.standard_fee) AS expected_fee,
    DATEDIFF(sl.slot_date, DATE(s.booked_at)) AS booking_lead_days,
    DATEDIFF(sl.slot_date, DATE(s.booked_at)) AS wait_time_days,
    CASE WHEN s.appointment_status = 'no_show' THEN 1 ELSE 0 END AS is_no_show,
    CASE WHEN s.appointment_status IN ('cancelled', 'late_cancelled') THEN 1 ELSE 0 END AS is_cancelled,
    CASE WHEN s.appointment_status = 'late_cancelled' THEN 1 ELSE 0 END AS is_late_cancelled,
    CASE WHEN s.appointment_status = 'attended' THEN 1 ELSE 0 END AS is_attended,
    CASE
        WHEN s.appointment_status IN ('no_show', 'late_cancelled')
            THEN COALESCE(s.expected_fee, sp.standard_fee)
        ELSE 0
    END AS revenue_lost
FROM standardized s
JOIN slots sl ON sl.slot_id = s.slot_id
JOIN patients p ON p.patient_id = s.patient_id
JOIN doctors d ON d.doctor_id = sl.doctor_id
JOIN clinics c ON c.clinic_id = sl.clinic_id
JOIN specialties sp ON sp.specialty_id = sl.specialty_id;
