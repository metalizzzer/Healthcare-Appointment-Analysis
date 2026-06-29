-- Profile raw data before cleaning.

USE healthcare_appointment_sql;

-- Row counts by table.
SELECT 'clinics' AS table_name, COUNT(*) AS row_count FROM clinics
UNION ALL SELECT 'specialties', COUNT(*) FROM specialties
UNION ALL SELECT 'doctors', COUNT(*) FROM doctors
UNION ALL SELECT 'patients', COUNT(*) FROM patients
UNION ALL SELECT 'slots', COUNT(*) FROM slots
UNION ALL SELECT 'appointments_raw', COUNT(*) FROM appointments_raw;

-- Slot and appointment date ranges.
SELECT
    MIN(slot_date) AS first_slot_date,
    MAX(slot_date) AS last_slot_date,
    COUNT(*) AS slots
FROM slots;

SELECT
    MIN(DATE(booked_at)) AS first_booking_date,
    MAX(DATE(booked_at)) AS last_booking_date,
    COUNT(*) AS raw_appointment_rows
FROM appointments_raw;

-- Appointment status distribution before standardization.
SELECT
    appointment_status,
    COUNT(*) AS rows
FROM appointments_raw
GROUP BY appointment_status
ORDER BY rows DESC;

-- Source channel distribution before standardization.
SELECT
    source_channel,
    COUNT(*) AS rows
FROM appointments_raw
GROUP BY source_channel
ORDER BY rows DESC;

-- NULL and empty value checks in raw appointments.
SELECT
    SUM(appointment_status IS NULL OR TRIM(appointment_status) = '') AS missing_status,
    SUM(cancellation_reason IS NULL OR TRIM(cancellation_reason) = '') AS missing_cancellation_reason,
    SUM(payment_status IS NULL OR TRIM(payment_status) = '') AS missing_payment_status,
    SUM(expected_fee IS NULL) AS missing_expected_fee,
    SUM(source_channel IS NULL OR TRIM(source_channel) = '') AS missing_source_channel
FROM appointments_raw;

-- Duplicate appointment candidates from the source feed.
SELECT
    appointment_id,
    slot_id,
    patient_id,
    booked_at,
    COUNT(*) AS duplicate_rows
FROM appointments_raw
GROUP BY appointment_id, slot_id, patient_id, booked_at
HAVING COUNT(*) > 1
ORDER BY duplicate_rows DESC, appointment_id;

-- Status values that need cleaning or review.
SELECT
    appointment_status,
    LOWER(REPLACE(REPLACE(TRIM(appointment_status), '-', '_'), ' ', '_')) AS normalized_candidate,
    COUNT(*) AS rows
FROM appointments_raw
GROUP BY appointment_status
ORDER BY rows DESC;

-- Available and booked slot profile by clinic.
SELECT
    c.clinic_name,
    COUNT(*) AS total_slots,
    SUM(s.is_available = 1) AS available_slots,
    COUNT(a.appointment_id) AS raw_booked_rows
FROM slots s
JOIN clinics c ON c.clinic_id = s.clinic_id
LEFT JOIN appointments_raw a ON a.slot_id = s.slot_id
GROUP BY c.clinic_name
ORDER BY available_slots DESC;

-- Foreign key sanity checks.
SELECT
    SUM(s.slot_id IS NULL) AS appointments_without_slot,
    SUM(p.patient_id IS NULL) AS appointments_without_patient
FROM appointments_raw a
LEFT JOIN slots s ON s.slot_id = a.slot_id
LEFT JOIN patients p ON p.patient_id = a.patient_id;
