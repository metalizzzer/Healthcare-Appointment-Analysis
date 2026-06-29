"""Generate synthetic healthcare appointment data for the SQL portfolio project.

The generator uses only the Python standard library and a fixed random seed.
It creates realistic operational patterns with enough noise to avoid perfect
or overly obvious results.
"""

from __future__ import annotations

import csv
import random
from datetime import date, datetime, time, timedelta
from pathlib import Path


SEED = 20260627
OUTPUT_DIR = Path(__file__).resolve().parent / "csv"
SQL_OUTPUT_PATH = Path(__file__).resolve().parents[1] / "sql" / "01_insert_data.sql"
BATCH_SIZE = 500


CLINICS = [
    (1, "Northside Medical Center", "Chicago", "Illinois", "2017-03-14"),
    (2, "Riverside Health Clinic", "Milwaukee", "Wisconsin", "2018-09-04"),
    (3, "Central Specialty Hospital", "Chicago", "Illinois", "2015-01-22"),
    (4, "Westbrook Family Clinic", "Naperville", "Illinois", "2020-06-18"),
]

SPECIALTIES = [
    (1, "Cardiology", 220, 45),
    (2, "Orthopedics", 260, 45),
    (3, "Dermatology", 180, 30),
    (4, "Physiotherapy", 120, 45),
    (5, "Pediatrics", 130, 30),
    (6, "Internal Medicine", 150, 30),
    (7, "Neurology", 240, 45),
    (8, "ENT", 160, 30),
]

FIRST_NAMES = [
    "Avery", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Cameron",
    "Quinn", "Parker", "Reese", "Alex", "Jamie", "Drew", "Harper",
    "Blake", "Rowan", "Skyler", "Emerson", "Hayden", "Kendall",
]

LAST_NAMES = [
    "Miller", "Johnson", "Garcia", "Brown", "Davis", "Wilson", "Martinez",
    "Anderson", "Thomas", "Moore", "Clark", "Lewis", "Walker", "Hall",
    "Young", "Allen", "King", "Wright", "Scott", "Green",
]

PATIENT_CITIES = [
    "Chicago", "Milwaukee", "Naperville", "Evanston", "Oak Park",
    "Aurora", "Joliet", "Waukegan", "Kenosha", "Rockford",
]

STATUS_VARIANTS = {
    "attended": ["attended", "Attended", "completed", "Completed"],
    "no_show": ["no_show", "No Show", "NO-SHOW", "no-show"],
    "cancelled": ["cancelled", "Canceled", "cancelled ", "Cancelled"],
    "late_cancelled": ["late_cancelled", "Late Cancelled", "late-cancelled"],
}

SOURCE_VARIANTS = {
    "web": ["web", "Web", "online", "WEB"],
    "mobile_app": ["mobile_app", "mobile app", "MOBILE", "app"],
    "phone": ["phone", "Phone", "phone_call", "Call Center"],
    "referral": ["referral", "Referral", "doctor_referral"],
    "walk_in": ["walk_in", "Walk-in", "front desk"],
}


def write_csv(name: str, rows: list[dict], fieldnames: list[str]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with (OUTPUT_DIR / name).open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def sql_value(value, is_numeric: bool) -> str:
    if value == "" or value is None:
        return "NULL"
    if is_numeric:
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def batched(rows: list[dict], size: int):
    for start in range(0, len(rows), size):
        yield rows[start:start + size]


def write_insert_sql(table_specs: list[dict]) -> None:
    SQL_OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "-- Insert generated healthcare appointment data.",
        "-- Run this after sql/00_create_schema.sql in MySQL Workbench.",
        "",
        "USE healthcare_appointment_sql;",
        "",
        "START TRANSACTION;",
        "",
    ]

    for spec in table_specs:
        table_name = spec["table_name"]
        columns = spec["columns"]
        numeric_columns = set(spec["numeric_columns"])
        rows = spec["rows"]

        lines.append(f"-- {table_name}: {len(rows)} rows")
        for batch in batched(rows, BATCH_SIZE):
            lines.append(f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES")
            values = []
            for row in batch:
                rendered = [
                    sql_value(row[column], column in numeric_columns)
                    for column in columns
                ]
                values.append(f"    ({', '.join(rendered)})")
            lines.append(",\n".join(values) + ";")
            lines.append("")

    lines.append("COMMIT;")
    lines.append("")
    SQL_OUTPUT_PATH.write_text("\r\n".join(lines), encoding="utf-8")


def daterange(start: date, end: date):
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


def weighted_choice(items: list[tuple[str, float]]) -> str:
    total = sum(weight for _, weight in items)
    point = random.random() * total
    running = 0.0
    for value, weight in items:
        running += weight
        if point <= running:
            return value
    return items[-1][0]


def make_doctors() -> list[dict]:
    doctors = []
    specialty_clinic_plan = [
        (1, [1, 2, 3, 3]),
        (2, [1, 2, 3, 3, 4]),
        (3, [1, 1, 2, 3, 4]),
        (4, [1, 2, 2, 3, 4]),
        (5, [1, 2, 4]),
        (6, [1, 2, 3, 4, 4]),
        (7, [2, 3, 3]),
        (8, [1, 2, 3]),
    ]
    doctor_id = 1
    for specialty_id, clinic_ids in specialty_clinic_plan:
        for clinic_id in clinic_ids:
            first = random.choice(FIRST_NAMES)
            last = random.choice(LAST_NAMES)
            doctors.append(
                {
                    "doctor_id": doctor_id,
                    "doctor_name": f"Dr. {first} {last}",
                    "clinic_id": clinic_id,
                    "specialty_id": specialty_id,
                    "employment_type": weighted_choice(
                        [("full_time", 0.58), ("part_time", 0.32), ("contract", 0.10)]
                    ),
                    "active_from": "2022-01-01",
                    "active_to": "",
                }
            )
            doctor_id += 1
    return doctors


def make_patients(total: int = 2500) -> list[dict]:
    patients = []
    for patient_id in range(1, total + 1):
        patient_type = weighted_choice([("returning", 0.72), ("first_time", 0.28)])
        registration_start = date(2018, 1, 1)
        registration_end = date(2025, 12, 15)
        if patient_type == "first_time":
            registration_start = date(2025, 1, 1)
        days = (registration_end - registration_start).days
        registration_date = registration_start + timedelta(days=random.randint(0, days))
        patients.append(
            {
                "patient_id": patient_id,
                "patient_type": patient_type,
                "registration_date": registration_date.isoformat(),
                "age_group": weighted_choice(
                    [
                        ("0-17", 0.12),
                        ("18-34", 0.24),
                        ("35-49", 0.26),
                        ("50-64", 0.22),
                        ("65+", 0.16),
                    ]
                ),
                "city": weighted_choice(
                    [
                        ("Chicago", 0.32),
                        ("Milwaukee", 0.14),
                        ("Naperville", 0.12),
                        ("Evanston", 0.08),
                        ("Oak Park", 0.08),
                        ("Aurora", 0.07),
                        ("Joliet", 0.06),
                        ("Waukegan", 0.05),
                        ("Kenosha", 0.04),
                        ("Rockford", 0.04),
                    ]
                ),
            }
        )
    return patients


def doctor_workdays(doctor_id: int, employment_type: str) -> list[int]:
    base_days = [0, 1, 2, 3, 4]
    count = {"full_time": 3, "part_time": 2, "contract": 2}[employment_type]
    offset = doctor_id % len(base_days)
    return sorted({base_days[(offset + i * 2) % 5] for i in range(count)})


def make_slots(doctors: list[dict]) -> list[dict]:
    specialty_by_id = {row[0]: row for row in SPECIALTIES}
    slots = []
    slot_id = 1
    start_date = date(2025, 1, 1)
    end_date = date(2025, 12, 31)
    session_hours = [8, 9, 10, 11, 13, 14, 15, 16]

    for day in daterange(start_date, end_date):
        if day.weekday() >= 5:
            continue
        for doctor in doctors:
            if day.weekday() not in doctor_workdays(doctor["doctor_id"], doctor["employment_type"]):
                continue
            if random.random() < 0.08:
                continue

            hours_today = random.sample(session_hours, k=random.choice([3, 4, 4, 5]))
            for hour in sorted(hours_today):
                specialty = specialty_by_id[doctor["specialty_id"]]
                slot_start = datetime.combine(day, time(hour=hour))
                slot_end = slot_start + timedelta(minutes=specialty[3])
                is_available = 0 if random.random() < 0.018 else 1
                slots.append(
                    {
                        "slot_id": slot_id,
                        "doctor_id": doctor["doctor_id"],
                        "clinic_id": doctor["clinic_id"],
                        "specialty_id": doctor["specialty_id"],
                        "slot_start": slot_start.strftime("%Y-%m-%d %H:%M:%S"),
                        "slot_end": slot_end.strftime("%Y-%m-%d %H:%M:%S"),
                        "slot_date": day.isoformat(),
                        "slot_hour": hour,
                        "weekday_name": day.strftime("%A"),
                        "is_available": is_available,
                    }
                )
                slot_id += 1
    return slots


def lead_days_for_specialty(specialty_name: str) -> int:
    if specialty_name in {"Cardiology", "Orthopedics"}:
        value = int(random.triangular(10, 54, 31))
    elif specialty_name == "Neurology":
        value = int(random.triangular(7, 42, 23))
    elif specialty_name in {"Dermatology", "Physiotherapy"}:
        value = int(random.triangular(3, 35, 16))
    else:
        value = int(random.triangular(1, 28, 9))
    return max(0, min(value, 70))


def appointment_status(slot: dict, specialty_name: str, patient_type: str, lead_days: int, source: str) -> str:
    hour = int(slot["slot_hour"])
    weekday = slot["weekday_name"]

    no_show_prob = 0.055
    cancel_prob = 0.085
    late_cancel_share = 0.34

    if specialty_name == "Dermatology":
        no_show_prob += 0.060
    if specialty_name == "Physiotherapy":
        no_show_prob += 0.055
    if specialty_name == "Orthopedics":
        no_show_prob += 0.020
    if weekday == "Friday" and hour >= 13:
        no_show_prob += 0.045
    if weekday == "Monday" and hour < 12:
        no_show_prob += 0.040
    if patient_type == "first_time":
        no_show_prob += 0.038
    if lead_days > 21:
        no_show_prob += 0.035
    if source == "mobile_app":
        no_show_prob -= 0.010
    if random.random() < 0.08:
        no_show_prob += random.uniform(-0.025, 0.025)

    no_show_prob = max(0.025, min(no_show_prob, 0.26))
    draw = random.random()
    if draw < no_show_prob:
        return "no_show"
    if draw < no_show_prob + cancel_prob:
        return "late_cancelled" if random.random() < late_cancel_share else "cancelled"
    return "attended"


def make_appointments(slots: list[dict], patients: list[dict]) -> list[dict]:
    specialty_lookup = {row[0]: {"name": row[1], "fee": row[2]} for row in SPECIALTIES}
    patient_lookup = {row["patient_id"]: row for row in patients}
    appointments = []
    appointment_id = 100000

    for slot in slots:
        if int(slot["is_available"]) == 0:
            continue
        specialty = specialty_lookup[int(slot["specialty_id"])]
        hour = int(slot["slot_hour"])
        weekday = slot["weekday_name"]

        booking_prob = 0.76
        if int(slot["clinic_id"]) == 3:
            booking_prob += 0.06
        if int(slot["clinic_id"]) == 4:
            booking_prob -= 0.15
        if specialty["name"] in {"Cardiology", "Orthopedics"}:
            booking_prob += 0.05
        if specialty["name"] == "Physiotherapy":
            booking_prob -= 0.03
        if weekday == "Friday" and hour >= 13:
            booking_prob -= 0.06
        if weekday == "Monday" and hour < 12:
            booking_prob -= 0.03
        if int(slot["doctor_id"]) in {7, 14, 26}:
            booking_prob -= 0.13
        booking_prob += random.uniform(-0.035, 0.035)

        if random.random() > max(0.38, min(booking_prob, 0.91)):
            continue

        patient = patient_lookup[random.randint(1, len(patients))]
        lead_days = lead_days_for_specialty(specialty["name"])
        slot_start = datetime.strptime(slot["slot_start"], "%Y-%m-%d %H:%M:%S")
        booked_at_date = slot_start.date() - timedelta(days=lead_days)
        if booked_at_date < date(2024, 12, 1):
            booked_at_date = date(2024, 12, 1) + timedelta(days=random.randint(0, 10))
        booked_at = datetime.combine(
            booked_at_date,
            time(hour=random.randint(8, 18), minute=random.choice([0, 5, 10, 15, 20, 30, 45])),
        )

        source = weighted_choice(
            [
                ("web", 0.30),
                ("mobile_app", 0.28),
                ("phone", 0.22),
                ("referral", 0.13),
                ("walk_in", 0.07),
            ]
        )
        status = appointment_status(slot, specialty["name"], patient["patient_type"], lead_days, source)
        expected_fee = round(specialty["fee"] * random.uniform(0.92, 1.08), 2)
        if random.random() < 0.012:
            expected_fee_value = ""
        else:
            expected_fee_value = f"{expected_fee:.2f}"

        if status == "attended":
            payment = weighted_choice([("paid", 0.78), ("insurance", 0.18), ("pending", 0.04)])
            reason = ""
        elif status == "no_show":
            payment = weighted_choice([("unpaid", 0.68), ("deposit_retained", 0.18), ("pending", 0.08), ("", 0.06)])
            reason = ""
        elif status == "late_cancelled":
            payment = weighted_choice([("unpaid", 0.54), ("deposit_retained", 0.20), ("refunded", 0.12), ("", 0.14)])
            reason = weighted_choice(
                [
                    ("patient request", 0.34),
                    ("schedule conflict", 0.30),
                    ("illness", 0.18),
                    ("transport issue", 0.10),
                    ("", 0.08),
                ]
            )
        else:
            payment = weighted_choice([("refunded", 0.48), ("unpaid", 0.30), ("pending", 0.08), ("", 0.14)])
            reason = weighted_choice(
                [
                    ("patient request", 0.38),
                    ("schedule conflict", 0.28),
                    ("doctor unavailable", 0.12),
                    ("insurance issue", 0.10),
                    ("", 0.12),
                ]
            )

        if random.random() < 0.025:
            payment = ""

        appointments.append(
            {
                "appointment_id": appointment_id,
                "slot_id": slot["slot_id"],
                "patient_id": patient["patient_id"],
                "booked_at": booked_at.strftime("%Y-%m-%d %H:%M:%S"),
                "appointment_status": random.choice(STATUS_VARIANTS[status]),
                "cancellation_reason": reason,
                "payment_status": payment,
                "expected_fee": expected_fee_value,
                "source_channel": random.choice(SOURCE_VARIANTS[source]),
            }
        )
        appointment_id += 1

    duplicates = random.sample(appointments, k=min(65, len(appointments) // 120))
    for row in duplicates:
        duplicate = row.copy()
        if random.random() < 0.35:
            duplicate["payment_status"] = duplicate["payment_status"] or "pending"
        appointments.append(duplicate)

    appointments.sort(key=lambda row: (int(row["slot_id"]), int(row["appointment_id"])))
    return appointments


def main() -> None:
    random.seed(SEED)

    clinics = [
        {
            "clinic_id": clinic_id,
            "clinic_name": clinic_name,
            "city": city,
            "region": region,
            "opening_date": opening_date,
        }
        for clinic_id, clinic_name, city, region, opening_date in CLINICS
    ]
    specialties = [
        {
            "specialty_id": specialty_id,
            "specialty_name": specialty_name,
            "standard_fee": standard_fee,
            "visit_duration_min": visit_duration_min,
        }
        for specialty_id, specialty_name, standard_fee, visit_duration_min in SPECIALTIES
    ]
    doctors = make_doctors()
    patients = make_patients()
    slots = make_slots(doctors)
    appointments = make_appointments(slots, patients)

    clinics_columns = ["clinic_id", "clinic_name", "city", "region", "opening_date"]
    specialties_columns = ["specialty_id", "specialty_name", "standard_fee", "visit_duration_min"]
    doctors_columns = ["doctor_id", "doctor_name", "clinic_id", "specialty_id", "employment_type", "active_from", "active_to"]
    patients_columns = ["patient_id", "patient_type", "registration_date", "age_group", "city"]
    slots_columns = [
        "slot_id",
        "doctor_id",
        "clinic_id",
        "specialty_id",
        "slot_start",
        "slot_end",
        "slot_date",
        "slot_hour",
        "weekday_name",
        "is_available",
    ]
    appointments_columns = [
        "appointment_id",
        "slot_id",
        "patient_id",
        "booked_at",
        "appointment_status",
        "cancellation_reason",
        "payment_status",
        "expected_fee",
        "source_channel",
    ]

    write_csv("clinics.csv", clinics, clinics_columns)
    write_csv(
        "specialties.csv",
        specialties,
        specialties_columns,
    )
    write_csv(
        "doctors.csv",
        doctors,
        doctors_columns,
    )
    write_csv(
        "patients.csv",
        patients,
        patients_columns,
    )
    write_csv(
        "slots.csv",
        slots,
        slots_columns,
    )
    write_csv(
        "appointments_raw.csv",
        appointments,
        appointments_columns,
    )

    write_insert_sql(
        [
            {
                "table_name": "clinics",
                "rows": clinics,
                "columns": clinics_columns,
                "numeric_columns": {"clinic_id"},
            },
            {
                "table_name": "specialties",
                "rows": specialties,
                "columns": specialties_columns,
                "numeric_columns": {"specialty_id", "standard_fee", "visit_duration_min"},
            },
            {
                "table_name": "doctors",
                "rows": doctors,
                "columns": doctors_columns,
                "numeric_columns": {"doctor_id", "clinic_id", "specialty_id"},
            },
            {
                "table_name": "patients",
                "rows": patients,
                "columns": patients_columns,
                "numeric_columns": {"patient_id"},
            },
            {
                "table_name": "slots",
                "rows": slots,
                "columns": slots_columns,
                "numeric_columns": {"slot_id", "doctor_id", "clinic_id", "specialty_id", "slot_hour", "is_available"},
            },
            {
                "table_name": "appointments_raw",
                "rows": appointments,
                "columns": appointments_columns,
                "numeric_columns": {"appointment_id", "slot_id", "patient_id", "expected_fee"},
            },
        ]
    )

    print("Generated healthcare appointment CSV files:")
    for filename in [
        "clinics.csv",
        "specialties.csv",
        "doctors.csv",
        "patients.csv",
        "slots.csv",
        "appointments_raw.csv",
    ]:
        path = OUTPUT_DIR / filename
        with path.open("r", encoding="utf-8") as handle:
            rows = sum(1 for _ in handle) - 1
        print(f"- {filename}: {rows:,} rows")
    print(f"- {SQL_OUTPUT_PATH.relative_to(Path(__file__).resolve().parents[1])}")


if __name__ == "__main__":
    main()
