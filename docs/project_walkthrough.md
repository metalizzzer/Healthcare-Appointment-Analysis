# Project Walkthrough

## File order

1. `sql/00_create_schema.sql` creates the MySQL database and tables.
2. `sql/01_insert_data.sql` inserts the generated rows.
3. `sql/02_profile_quality.sql` profiles raw data quality.
4. `sql/03_clean_views.sql` creates the appointment cleaning view.
5. `sql/04_kpi_views.sql` creates reusable reporting views.
6. `sql/05_analysis_queries.sql` answers the business questions.

`data/generate_data.py` is optional and recreates the CSV files and `sql/01_insert_data.sql`.

## Model logic

The model separates operational dimensions from appointment activity:

- clinics, specialties, doctors and patients describe the business entities.
- slots represent available doctor capacity.
- appointments_raw represents the booking feed.

Slots are kept separate from appointments because utilization requires both booked and unbooked capacity.

## Cleaning logic

`v_appointments_clean` handles the main raw-data issues:

- standardizes inconsistent statuses such as `No Show`, `NO-SHOW` and `no-show`;
- standardizes source channels such as `Web`, `online`, `MOBILE` and `phone_call`;
- converts empty cancellation reasons to a readable default;
- fills missing expected fees with the specialty standard fee;
- deduplicates raw appointment candidates with `ROW_NUMBER`;
- adds flags for no-show, cancellation, late cancellation and attendance;
- derives booking lead time, waiting time, revenue lost and time block.

The raw table is intentionally not cleaned in place. Views preserve the original source data and make the reporting logic repeatable.

## Main reporting views

| View | Purpose |
| --- | --- |
| `v_appointments_clean` | Clean appointment-level dataset. |
| `v_slot_fact` | Slot-level fact view joined to clinics, doctors, specialties and appointments. |
| `v_monthly_kpis` | Monthly KPI trend including no-show rate, utilization and revenue leakage. |
| `v_specialty_performance` | Specialty-level operational and financial performance. |
| `v_clinic_performance` | Clinic-level utilization and leakage view. |
| `v_action_opportunities` | Simple management action shortlist. |

## KPI definitions

- No-show rate = no-show appointments / total booked appointments.
- Cancellation rate = cancelled or late-cancelled appointments / total booked appointments.
- Late cancellation rate = late-cancelled appointments / total booked appointments.
- Booked-slot utilization rate = booked slots / available slots.
- Revenue leakage = expected fee from no-show and late-cancelled appointments.
- Waiting time = days between booking date and appointment date.
- Unused slots = available slots without a booking.

## Where window functions are used

- `ROW_NUMBER` removes duplicate appointment candidates in the cleaning view.
- `LAG` calculates month-over-month revenue leakage and no-show trend changes.
- `RANK` ranks no-show and revenue leakage results.
- `DENSE_RANK` ranks doctors by low utilization.

## How to interpret the results

The analysis separates three related operational issues:

1. No-show rate shows where appointment attendance is weakest.
2. Revenue leakage shows where missed or late-cancelled visits have the largest financial impact.
3. Utilization and waiting time show where capacity is either underused or constrained.

For example, Dermatology may have a high no-show rate, while Orthopedics may create more lost revenue because each appointment is more expensive. This distinction helps prioritize actions instead of treating all no-shows equally.

