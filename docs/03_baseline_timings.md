# Phase 3: Baseline Timings

**Team T0075** · Practo doctor appointments database

This is how fast the 30 workload queries run on our Phase 2 schema before any tuning. The only indexes are the ones PostgreSQL creates automatically for PRIMARY KEY and UNIQUE constraints. These numbers are the "before" side of every comparison in Phase 4.

## How we measured

| Item | Value |
|---|---|
| Laptop | Apple M4, 16 GB RAM, Darwin 27.2.0 |
| Database | psql (PostgreSQL) 18.6 (Homebrew), database `practo_db`, schema `practo` |
| Data | Seed data: 150,000 appointments, 243,085 prescription items, 40,000 patients |
| State | Fresh rebuild with `sql/01_schema.sql` and `sql/02_load_data.sql` (which ends with `ANALYZE`). No extra indexes and no VACUUM, because those are Phase 4 techniques. |
| Command | `./benchmarks/run_benchmark.sh practo_db baseline` |
| Method | Each query runs with `EXPLAIN (ANALYZE, BUFFERS)` 3 times. We read the `Execution Time` line of each run and report the average of the 3. |
| Writes | W01 to W05 run inside `BEGIN; ... ROLLBACK;`, so the data never changes |
| Queries | `queries/workload_30.sql`, unchanged |
| Raw plans | `benchmarks/results/baseline/R01.txt` to `W05.txt` hold the plans of all 3 runs; `summary.csv` holds avg, median, min, max and the scan nodes |

Every number below is copied from the `Execution Time` lines of the raw files. Each average equals `avg_ms` in `summary.csv`.

## Timing table (all 30 queries)

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Find a doctor: verified dermatologists practising in Bengaluru, most experienced first | READ | 2.531 | 2.298 | 2.313 | 2.381 |
| R02: Doctor profile: doctor 217's weekly timetable with clinic names | READ | 0.382 | 0.374 | 0.380 | 0.379 |
| R03: Slot picker: doctor 217's free in-clinic slots on Friday 3 July 2026 | READ | 14.5 | 15.7 | 15.6 | 15.3 |
| R04: "My appointments": patient 90's upcoming appointments | READ | 12.5 | 13.5 | 12.7 | 12.9 |
| R05: Doctor's queue: doctor 16's appointments on 30 June 2026 | READ | 9.181 | 9.930 | 9.831 | 9.647 |
| R06: Sign-in with mobile number | READ | 0.042 | 0.042 | 0.041 | 0.042 |
| R07: Prescription view: the prescription and medicines of appointment 18872 | READ | 0.129 | 0.079 | 0.075 | 0.094 |
| R08: Quality: no-show rate per specialization in 2026 | READ | 38.7 | 39.3 | 39.1 | 39.0 |
| R09: Clinic experience: average minutes patients waited after their slot time, per clinic (June 2026) | READ | 14.5 | 15.8 | 16.9 | 15.7 |
| R10: Patient safety: patients allergic to penicillin who were prescribed amoxicillin | READ | 33.0 | 37.8 | 32.6 | 34.5 |
| R11: Care team: follow-ups due in the first week of July 2026 that the patient has not booked yet | READ | 32.5 | 31.6 | 31.7 | 31.9 |
| R12: Product analytics: video vs in-clinic appointments per month in 2026 | READ | 44.8 | 46.1 | 49.9 | 46.9 |
| R13: Clinic partnerships: clinics where no doctor has any schedule | READ | 4.935 | 4.881 | 5.242 | 5.019 |
| R14: Doctor ranking: average rating and recommendation rate (at least 10 reviews) | READ | 36.6 | 37.5 | 36.9 | 37.0 |
| R15: Pharmacy partners: most prescribed medicines per primary specialization in June 2026 | READ | 38.4 | 39.2 | 37.6 | 38.4 |
| R16: Finance: fees collected per clinic in June 2026 | READ | 17.8 | 17.3 | 18.0 | 17.7 |
| R17: Population health: completed appointments by patient age group and blood group (2026) | READ | 80.9 | 81.3 | 82.4 | 81.5 |
| R18: Search filter: Tamil-speaking doctors with Chennai clinics | READ | 7.843 | 7.764 | 7.747 | 7.785 |
| R19: City report: June 2026 completed consultations and latest consultation of every doctor with a Bengaluru clinic | READ | 8178.4 | 8157.1 | 8137.2 | 8157.6 |
| R20: Platform analytics: completed appointments per day and running total, June 2026 | READ | 16.3 | 15.0 | 15.3 | 15.5 |
| R21: Finance: completed in-clinic consultations whose fee is still unpaid | READ | 16.1 | 16.9 | 15.1 | 16.0 |
| R22: Support console: all appointments, newest first, page 4,001 (25 per page) | READ | 60.3 | 63.8 | 63.4 | 62.5 |
| R23: Verification team: look up a doctor by medical council registration number | READ | 0.042 | 0.044 | 0.051 | 0.046 |
| R24: Data quality: two active appointments of the same doctor in the same slot (double bookings) | READ | 39.6 | 40.8 | 39.9 | 40.1 |
| R25: Care quality: patients who saw 3 or more different doctors of the same specialization in 2026 | READ | 35.8 | 36.1 | 36.6 | 36.2 |
| W01: Book: patient 90 books doctor 217's 10:30 slot on Friday 3 July 2026 | WRITE | 1.166 | 1.042 | 1.069 | 1.092 |
| W02: Reception: check in the earliest BOOKED in-clinic appointment of 1 July 2026 | WRITE | 12.8 | 13.0 | 12.6 | 12.8 |
| W03: Doctor: add notes and a follow-up date to the prescription of appointment 18872 | WRITE | 0.269 | 0.273 | 0.242 | 0.261 |
| W04: Nightly job (run at 00:00 on 2 July 2026): BOOKED appointments whose slot has ended become NO_SHOW | WRITE | 17.2 | 18.5 | 17.0 | 17.6 |
| W05: Doctor on leave: cancel and refund all of doctor 504's appointments on 3 July 2026 | WRITE | 13.2 | 14.2 | 13.6 | 13.7 |
| **Total (sum of all 30)** | | | | | 8769.5 |

## What the numbers say

The slowest query is R19 at 8157.6 ms, which is 93.0% of the 8769.5 ms total. The three slowest are R19 (8157.6 ms), R17 (81.5 ms), R22 (62.5 ms). 5 of 30 queries run in under 1 ms, which are the ones that use a primary key or unique index. No query has a run 1 that is much slower than runs 2 and 3, so the cache state did not change the picture.

## Scan type and reason for each query

Scan types come from the plan of the last run of each query (`benchmarks/results/baseline/<id>.txt`).

| Query | Avg (ms) | Scan type(s) in the plan | Why it is slow or fast |
|---|---:|---|---|
| R01 | 2.381 | Seq Scan on doctor_specializations, Seq Scan on specializations, Index Scan using doctors_pkey on doctors, Index Scan using doctor_schedules_pkey on doctor_schedules, Seq Scan on clinics | Seq scan on doctor_specializations reads all 3,700 rows; seq scan on clinics reads 1,500 rows and throws away 1,260 with the filter. |
| R02 | 0.379 | Index Scan using doctor_schedules_pkey on doctor_schedules, Seq Scan on clinics | Seq scan on clinics reads all 1,500 rows. |
| R03 | 15.3 | Index Scan using doctor_schedules_pkey on doctor_schedules, Seq Scan on appointments | Seq scan on appointments reads 150,000 rows and throws away 149,928 with the filter. |
| R04 | 12.9 | Seq Scan on appointments, Index Scan using doctors_pkey on doctors, Seq Scan on clinics | Seq scan on appointments reads 150,000 rows and throws away 149,998 with the filter; seq scan on clinics runs 2 times and reads 1,705 rows in total. |
| R05 | 9.647 | Parallel Seq Scan on appointments, Index Scan using patients_pkey on patients | Seq scan on appointments runs 2 times and reads 149,999 rows in total; a function on a column in the filter stops index use. |
| R06 | 0.042 | Index Scan using patients_phone_key on patients | Index lookups touch only the rows needed. |
| R07 | 0.094 | Index Scan using prescriptions_appointment_id_key on prescriptions, Index Scan using prescription_items_pkey on prescription_items | Index lookups touch only the rows needed. |
| R08 | 39.0 | Parallel Seq Scan on appointments, Seq Scan on doctor_specializations, Seq Scan on specializations | Seq scan on appointments runs 2 times and reads 150,000 rows in total; seq scan on doctor_specializations runs 2 times and reads 7,400 rows in total. |
| R09 | 15.7 | Seq Scan on appointments | Seq scan on appointments reads 150,000 rows and throws away 144,378 with the filter. |
| R10 | 34.5 | Parallel Seq Scan on appointments, Seq Scan on patients, Index Scan using prescriptions_appointment_id_key on prescriptions, Index Scan using prescription_items_pkey on prescription_items | Seq scan on appointments runs 2 times and reads 150,000 rows in total; seq scan on patients runs 2 times and reads 80,000 rows in total. |
| R11 | 31.9 | Seq Scan on appointments, Seq Scan on prescriptions, Index Scan using appointments_pkey on appointments | Seq scan on appointments reads 150,000 rows and throws away 14,900 with the filter; seq scan on prescriptions reads 97,234 rows and throws away 96,804 with the filter. |
| R12 | 46.9 | Seq Scan on appointments | Seq scan on appointments reads 150,000 rows and throws away 98,499 with the filter. |
| R13 | 5.019 | Seq Scan on clinics, Seq Scan on doctor_schedules | Seq scan on clinics reads 1,500 rows and throws away 1,500 with the filter; seq scan on doctor_schedules reads all 30,499 rows. |
| R14 | 37.0 | Seq Scan on appointments, Seq Scan on doctor_reviews | Seq scan on appointments reads all 150,000 rows; seq scan on doctor_reviews reads all 30,339 rows. |
| R15 | 38.4 | Parallel Seq Scan on prescription_items, Parallel Seq Scan on appointments, Seq Scan on prescriptions, Seq Scan on doctor_specializations, Seq Scan on specializations | Seq scan on prescription_items runs 2 times and reads 243,085 rows in total; seq scan on appointments runs 2 times and reads 150,000 rows in total; seq scan on prescriptions runs 2 times and reads 194,468 rows in total; seq scan on doctor_specializations runs 2 times and reads 7,400 rows in total. |
| R16 | 17.7 | Seq Scan on appointments, Seq Scan on clinics | Seq scan on appointments reads 150,000 rows and throws away 143,638 with the filter; seq scan on clinics reads all 1,500 rows. |
| R17 | 81.5 | Seq Scan on appointments, Seq Scan on patients | Seq scan on appointments reads 150,000 rows and throws away 109,330 with the filter; seq scan on patients reads all 40,000 rows. |
| R18 | 7.785 | Seq Scan on doctor_schedules, Seq Scan on doctors, Seq Scan on clinics | Seq scan on doctor_schedules reads all 30,499 rows; seq scan on doctors reads 3,000 rows and throws away 2,640 with the filter; seq scan on clinics reads 1,500 rows and throws away 1,320 with the filter. |
| R19 | 8157.6 | Seq Scan on doctor_schedules, Seq Scan on clinics, Seq Scan on doctors, Seq Scan on appointments | Seq scan on doctor_schedules reads all 30,499 rows; seq scan on clinics reads 1,500 rows and throws away 1,260 with the filter; seq scan on doctors reads all 3,000 rows; seq scan on appointments runs 480 times and reads 72,000,124 rows in total; seq scan on appointments runs 480 times and reads 71,999,808 rows in total. |
| R20 | 15.5 | Parallel Seq Scan on appointments | Seq scan on appointments runs 2 times and reads 149,999 rows in total. |
| R21 | 16.0 | Parallel Seq Scan on appointments | Seq scan on appointments runs 2 times and reads 149,999 rows in total. |
| R22 | 62.5 | Seq Scan on appointments | Seq scan on appointments reads all 150,000 rows; a sort spills 6,176 kb to disk. |
| R23 | 0.046 | Index Scan using doctors_registration_no_key on doctors | Index lookups touch only the rows needed. |
| R24 | 40.1 | Parallel Seq Scan on appointments | Seq scan on appointments runs 2 times and reads 150,000 rows in total; seq scan on appointments runs 2 times and reads 150,000 rows in total. |
| R25 | 36.2 | Seq Scan on appointments, Seq Scan on doctor_specializations | Seq scan on appointments reads 150,000 rows and throws away 109,330 with the filter; seq scan on doctor_specializations reads 3,700 rows and throws away 700 with the filter. |
| W01 | 1.092 | Index Scan using doctor_schedules_pkey on doctor_schedules, Index Scan using doctors_pkey on doctors | Index lookups touch only the rows needed. |
| W02 | 12.8 | Seq Scan on appointments, Index Scan using appointments_pkey on appointments | Seq scan on appointments reads 150,000 rows and throws away 149,773 with the filter. |
| W03 | 0.261 | Index Scan using prescriptions_appointment_id_key on prescriptions | Index lookups touch only the rows needed. |
| W04 | 17.6 | Seq Scan on appointments | Seq scan on appointments reads 150,000 rows and throws away 149,671 with the filter. |
| W05 | 13.7 | Seq Scan on appointments | Seq scan on appointments reads 150,000 rows and throws away 149,997 with the filter. |

## Summary of the baseline

- 25 of 30 queries use a Seq Scan on a large table (R01, R02, R03, R04, R05, R08, R09, R10, R11, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R24, R25, W02, W04, W05).
- Tables read in full: appointments, clinics, doctor_reviews, doctor_schedules, doctor_specializations, doctors, patients, prescription_items, prescriptions.
- Queries with a function on a column in the filter: R05.
- Queries where a subquery runs once per outer row and scans a large table each time: R19.
- Queries that sort on disk: R22.
- Starting points for Phase 4: add indexes on the filter and join columns of the queries above, rewrite the function-on-column filters as ranges, replace per-row subqueries with one join, and check R13 for the NULL problem with NOT IN.
