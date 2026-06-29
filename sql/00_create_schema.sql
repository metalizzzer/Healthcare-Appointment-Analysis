-- Creates the Healthcare Appointment Analytics database schema.
-- Existing objects are dropped if they already exist, allowing repeatable execution.

CREATE DATABASE IF NOT EXISTS healthcare_appointment_sql;
USE healthcare_appointment_sql;

DROP VIEW IF EXISTS v_action_opportunities;
DROP VIEW IF EXISTS v_clinic_performance;
DROP VIEW IF EXISTS v_specialty_performance;
DROP VIEW IF EXISTS v_monthly_kpis;
DROP VIEW IF EXISTS v_slot_fact;
DROP VIEW IF EXISTS v_appointments_clean;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS appointments_raw;
DROP TABLE IF EXISTS slots;
DROP TABLE IF EXISTS patients;
DROP TABLE IF EXISTS doctors;
DROP TABLE IF EXISTS specialties;
DROP TABLE IF EXISTS clinics;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE clinics (
    clinic_id INT NOT NULL,
    clinic_name VARCHAR(100) NOT NULL,
    city VARCHAR(60) NOT NULL,
    region VARCHAR(60) NOT NULL,
    opening_date DATE NOT NULL,
    PRIMARY KEY (clinic_id)
);

CREATE TABLE specialties (
    specialty_id INT NOT NULL,
    specialty_name VARCHAR(60) NOT NULL,
    standard_fee DECIMAL(8,2) NOT NULL,
    visit_duration_min INT NOT NULL,
    PRIMARY KEY (specialty_id),
    UNIQUE KEY uk_specialty_name (specialty_name)
);

CREATE TABLE doctors (
    doctor_id INT NOT NULL,
    doctor_name VARCHAR(100) NOT NULL,
    clinic_id INT NOT NULL,
    specialty_id INT NOT NULL,
    employment_type VARCHAR(30) NOT NULL,
    active_from DATE NOT NULL,
    active_to DATE NULL,
    PRIMARY KEY (doctor_id),
    KEY ix_doctors_clinic (clinic_id),
    KEY ix_doctors_specialty (specialty_id),
    CONSTRAINT fk_doctors_clinic
        FOREIGN KEY (clinic_id) REFERENCES clinics (clinic_id),
    CONSTRAINT fk_doctors_specialty
        FOREIGN KEY (specialty_id) REFERENCES specialties (specialty_id)
);

CREATE TABLE patients (
    patient_id INT NOT NULL,
    patient_type VARCHAR(30) NOT NULL,
    registration_date DATE NOT NULL,
    age_group VARCHAR(20) NOT NULL,
    city VARCHAR(60) NOT NULL,
    PRIMARY KEY (patient_id)
);

CREATE TABLE slots (
    slot_id INT NOT NULL,
    doctor_id INT NOT NULL,
    clinic_id INT NOT NULL,
    specialty_id INT NOT NULL,
    slot_start DATETIME NOT NULL,
    slot_end DATETIME NOT NULL,
    slot_date DATE NOT NULL,
    slot_hour TINYINT NOT NULL,
    weekday_name VARCHAR(10) NOT NULL,
    is_available TINYINT NOT NULL,
    PRIMARY KEY (slot_id),
    KEY ix_slots_doctor_date (doctor_id, slot_date),
    KEY ix_slots_clinic_date (clinic_id, slot_date),
    KEY ix_slots_specialty_date (specialty_id, slot_date),
    CONSTRAINT fk_slots_doctor
        FOREIGN KEY (doctor_id) REFERENCES doctors (doctor_id),
    CONSTRAINT fk_slots_clinic
        FOREIGN KEY (clinic_id) REFERENCES clinics (clinic_id),
    CONSTRAINT fk_slots_specialty
        FOREIGN KEY (specialty_id) REFERENCES specialties (specialty_id)
);

-- Raw appointments intentionally do not use appointment_id as a primary key.
-- The source feed can contain duplicate candidates, handled in v_appointments_clean.
CREATE TABLE appointments_raw (
    appointment_id INT NOT NULL,
    slot_id INT NOT NULL,
    patient_id INT NOT NULL,
    booked_at DATETIME NOT NULL,
    appointment_status VARCHAR(40) NULL,
    cancellation_reason VARCHAR(100) NULL,
    payment_status VARCHAR(40) NULL,
    expected_fee DECIMAL(8,2) NULL,
    source_channel VARCHAR(40) NULL,
    KEY ix_appointments_raw_appointment (appointment_id),
    KEY ix_appointments_raw_slot (slot_id),
    KEY ix_appointments_raw_patient (patient_id),
    CONSTRAINT fk_appointments_raw_slot
        FOREIGN KEY (slot_id) REFERENCES slots (slot_id),
    CONSTRAINT fk_appointments_raw_patient
        FOREIGN KEY (patient_id) REFERENCES patients (patient_id)
);
