# Data Dictionary

## Schema overview

```mermaid
erDiagram
    clinics ||--o{ doctors : employs
    clinics ||--o{ slots : hosts
    specialties ||--o{ doctors : covers
    specialties ||--o{ slots : categorizes
    doctors ||--o{ slots : owns
    patients ||--o{ appointments_raw : books
    slots ||--o{ appointments_raw : receives

    clinics {
        int clinic_id PK
        varchar clinic_name
        varchar city
        varchar region
        date opening_date
    }

    specialties {
        int specialty_id PK
        varchar specialty_name
        decimal standard_fee
        int visit_duration_min
    }

    doctors {
        int doctor_id PK
        varchar doctor_name
        int clinic_id FK
        int specialty_id FK
        varchar employment_type
        date active_from
        date active_to
    }

    patients {
        int patient_id PK
        varchar patient_type
        date registration_date
        varchar age_group
        varchar city
    }

    slots {
        int slot_id PK
        int doctor_id FK
        int clinic_id FK
        int specialty_id FK
        datetime slot_start
        datetime slot_end
        date slot_date
        int slot_hour
        varchar weekday_name
        int is_available
    }

    appointments_raw {
        int appointment_id
        int slot_id FK
        int patient_id FK
        datetime booked_at
        varchar appointment_status
        varchar cancellation_reason
        varchar payment_status
        decimal expected_fee
        varchar source_channel
    }
```

## Tables

### clinics

Medical locations in the private healthcare network.

| Column | Description |
| --- | --- |
| `clinic_id` | Clinic identifier. |
| `clinic_name` | Clinic name used in reporting. |
| `city` | Clinic city. |
| `region` | State or region. |
| `opening_date` | Clinic opening date. |

### specialties

Medical services offered by the network.

| Column | Description |
| --- | --- |
| `specialty_id` | Specialty identifier. |
| `specialty_name` | Specialty name. |
| `standard_fee` | Typical expected appointment fee. |
| `visit_duration_min` | Planned visit duration in minutes. |

### doctors

Doctors assigned to one clinic and one main specialty.

| Column | Description |
| --- | --- |
| `doctor_id` | Doctor identifier. |
| `doctor_name` | Synthetic doctor name. |
| `clinic_id` | Doctor's clinic. |
| `specialty_id` | Doctor's specialty. |
| `employment_type` | Full-time, part-time or contract. |
| `active_from` | Start date in the network. |
| `active_to` | End date if inactive. Blank means active. |

### patients

Synthetic patient dimension. No real personal data is used.

| Column | Description |
| --- | --- |
| `patient_id` | Patient identifier. |
| `patient_type` | `first_time` or `returning`. |
| `registration_date` | Date the patient registered. |
| `age_group` | Age band used for analysis. |
| `city` | Patient city. |

### slots

Available doctor appointment slots.

| Column | Description |
| --- | --- |
| `slot_id` | Slot identifier. |
| `doctor_id` | Doctor assigned to the slot. |
| `clinic_id` | Clinic where the slot is available. |
| `specialty_id` | Specialty for the slot. |
| `slot_start` | Slot start timestamp. |
| `slot_end` | Slot end timestamp. |
| `slot_date` | Slot date. |
| `slot_hour` | Start hour. |
| `weekday_name` | Weekday label. |
| `is_available` | Whether the slot was available for booking. |

### appointments_raw

Raw appointment booking feed. It can contain duplicate candidates, so `appointment_id` is not a primary key in the raw table.

| Column | Description |
| --- | --- |
| `appointment_id` | Source appointment identifier. |
| `slot_id` | Booked slot. |
| `patient_id` | Patient who booked. |
| `booked_at` | Booking timestamp. |
| `appointment_status` | Raw appointment status, before cleaning. |
| `cancellation_reason` | Reason if cancelled. |
| `payment_status` | Raw payment status. |
| `expected_fee` | Expected appointment fee, sometimes missing. |
| `source_channel` | Raw booking channel, before cleaning. |

## Main derived fields

| Field | View | Definition |
| --- | --- | --- |
| `booking_lead_days` | `v_appointments_clean` | Days between booking and appointment date. |
| `wait_time_days` | `v_appointments_clean` | Same business definition as booking lead time for this dataset. |
| `is_no_show` | `v_appointments_clean` | 1 when cleaned status is `no_show`. |
| `is_late_cancelled` | `v_appointments_clean` | 1 when the source system flagged a late cancellation. |
| `revenue_lost` | `v_appointments_clean` | Expected fee for no-shows and late cancellations. |
| `time_block` | `v_appointments_clean`, `v_slot_fact` | Morning, afternoon or evening from slot hour. |
| `is_booked` | `v_slot_fact` | 1 when an available slot has a cleaned appointment. |
| `is_unused` | `v_slot_fact` | 1 when an available slot has no appointment. |
