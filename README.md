# Healthcare Appointment Analysis

## Business problem

A private healthcare network wants to reduce lost revenue from no-shows and late cancellations while improving doctor utilization and patient access.

This project analyzes appointment slots, bookings, doctors, clinics, specialties and patients to identify where operational changes can have the highest impact.

## Questions answered

* Which specialties and clinics have the highest no-show rate?
* Where is revenue leakage highest?
* Which weekdays and time blocks carry the most no-show risk?
* Which doctors have low slot utilization?
* Which specialties have the longest waiting time?
* What actions should management prioritize?

## Data

The project uses synthetic appointment data created for portfolio purposes. It covers 12 months of activity across 4 clinics, 8 specialties, 33 doctors, 2,500 patients, about 14,000 slots and about 10,000 raw appointment records.

The data includes realistic operational patterns: higher no-shows in Dermatology and Physiotherapy, riskier Monday morning and Friday afternoon slots, longer waiting times in Cardiology and Orthopedics, and lower utilization at one clinic.

The dataset also includes inconsistent statuses, missing fees and duplicate candidates, which are handled in the cleaning layer.

Utilization is calculated as booked slots divided by available slots.

## Repo structure

```text
healthcare-appointment-sql/
|-- data/                  # data generator and CSV files
|-- docs/                  # project notes and data dictionary
`-- sql/                   # schema, inserts, profiling, cleaning, KPI and analysis SQL
```

## SQL techniques

* MySQL views for the reporting layer
* `CASE`, `COALESCE`, `NULLIF` for cleaning and business flags
* `ROW_NUMBER` for duplicate handling
* `RANK`, `DENSE_RANK` and `LAG` for ranking and trend analysis
* date functions for waiting time, booking lead time and monthly KPIs

## Main findings

In the sample dataset:

* Dermatology and Physiotherapy have the highest no-show rates, around 14%.
* Orthopedics creates the largest revenue leakage, with Dermatology close behind.
* No-show risk is highest on Friday afternoons and Monday mornings.
* First-time patients and long-lead bookings have higher no-show risk.
* Westbrook Family Clinic has weaker slot utilization, around 55%.
* Cardiology and Orthopedics have the longest average waiting times, around 31 days.

Recommended actions:

* Add confirmation rules for high-risk specialties, first-time patients and long-lead bookings.
* Use waitlists or deposits for expensive specialties with high leakage.
* Review Westbrook schedules and shift capacity toward long-wait specialties.

## How to run

1. Open MySQL Workbench and run the SQL files in order:

   1. `sql/00_create_schema.sql`
   2. `sql/01_insert_data.sql`
   3. `sql/02_profile_quality.sql`
   4. `sql/03_clean_views.sql`
   5. `sql/04_kpi_views.sql`
   6. `sql/05_analysis_queries.sql`

2. Review the final query outputs and `v_action_opportunities`.

Data is loaded with standard `INSERT` statements, so no CSV import setup is required.

The CSV files are already included. Run `python data/generate_data.py` only if you want to regenerate both the CSV files and `sql/01_insert_data.sql`.
