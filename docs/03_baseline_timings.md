# Phase 3: Baseline Timings

**Team T0075** · Practo doctor appointments database

This is how fast the 30 workload queries run on our Phase 2 schema before any tuning. The only indexes are the ones PostgreSQL creates automatically for PRIMARY KEY and UNIQUE constraints. These numbers are the "before" side of every comparison in Phase 4.

## How we measured

| Item | Value |
|---|---|
| Laptop | MacBook Pro, Apple M4, 16GB RAM |
| Database | FILL: output of `psql --version`, database `practo_db`, schema `practo` |
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
| R01: Find a doctor: verified dermatologists practising in Bengaluru, most experienced first | READ | | | | |
| R02: Doctor profile: doctor 217's weekly timetable with clinic names | READ | | | | |
| R03: Slot picker: doctor 217's free in-clinic slots on Friday 3 July 2026 | READ | | | | |
| R04: "My appointments": patient 90's upcoming appointments | READ | | | | |
| R05: Doctor's queue: doctor 16's appointments on 30 June 2026 | READ | | | | |
| R06: Sign-in with mobile number | READ | | | | |
| R07: Prescription view: the prescription and medicines of appointment 18872 | READ | | | | |
| R08: Quality: no-show rate per specialization in 2026 | READ | | | | |
| R09: Clinic experience: average minutes patients waited after their slot time, per clinic (June 2026) | READ | | | | |
| R10: Patient safety: patients allergic to penicillin who were prescribed amoxicillin | READ | | | | |
| R11: Care team: follow-ups due in the first week of July 2026 that the patient has not booked yet | READ | | | | |
| R12: Product analytics: video vs in-clinic appointments per month in 2026 | READ | | | | |
| R13: Clinic partnerships: clinics where no doctor has any schedule | READ | | | | |
| R14: Doctor ranking: average rating and recommendation rate (at least 10 reviews) | READ | | | | |
| R15: Pharmacy partners: most prescribed medicines per primary specialization in June 2026 | READ | | | | |
| R16: Finance: fees collected per clinic in June 2026 | READ | | | | |
| R17: Population health: completed appointments by patient age group and blood group (2026) | READ | | | | |
| R18: Search filter: Tamil-speaking doctors with Chennai clinics | READ | | | | |
| R19: City report: June 2026 completed consultations and latest consultation of every doctor with a Bengaluru clinic | READ | | | | |
| R20: Platform analytics: completed appointments per day and running total, June 2026 | READ | | | | |
| R21: Finance: completed in-clinic consultations whose fee is still unpaid | READ | | | | |
| R22: Support console: all appointments, newest first, page 4,001 (25 per page) | READ | | | | |
| R23: Verification team: look up a doctor by medical council registration number | READ | | | | |
| R24: Data quality: two active appointments of the same doctor in the same slot (double bookings) | READ | | | | |
| R25: Care quality: patients who saw 3 or more different doctors of the same specialization in 2026 | READ | | | | |
| W01: Book: patient 90 books doctor 217's 10:30 slot on Friday 3 July 2026 | WRITE | | | | |
| W02: Reception: check in the earliest BOOKED in-clinic appointment of 1 July 2026 | WRITE | | | | |
| W03: Doctor: add notes and a follow-up date to the prescription of appointment 18872 | WRITE | | | | |
| W04: Nightly job (run at 00:00 on 2 July 2026): BOOKED appointments whose slot has ended become NO_SHOW | WRITE | | | | |
| W05: Doctor on leave: cancel and refund all of doctor 504's appointments on 3 July 2026 | WRITE | | | | |
| **Total (sum of all 30)** | | | | | |

## What the numbers say

FILL after the run: which query is the slowest and how much of the total it takes, which group of queries is fast, which is slow, and any query whose run 1 is much slower than runs 2 and 3 (and why: cold caches, hint bits).

## Scan type and reason for each query

FILL: for every query, copy the scan types from the `scan_nodes` column of `summary.csv`, then open the raw plan (`benchmarks/results/baseline/<id>.txt`) and write one line on why it is slow or fast. Look at: Seq Scan vs Index Scan, `Rows Removed by Filter`, number of loops, and any sort that spills to disk.

| Query | Avg (ms) | Scan type(s) in the plan | Why it is slow or fast |
|---|---:|---|---|
| R01 | | | |
| R02 | | | |
| R03 | | | |
| R04 | | | |
| R05 | | | |
| R06 | | | |
| R07 | | | |
| R08 | | | |
| R09 | | | |
| R10 | | | |
| R11 | | | |
| R12 | | | |
| R13 | | | |
| R14 | | | |
| R15 | | | |
| R16 | | | |
| R17 | | | |
| R18 | | | |
| R19 | | | |
| R20 | | | |
| R21 | | | |
| R22 | | | |
| R23 | | | |
| R24 | | | |
| R25 | | | |
| W01 | | | |
| W02 | | | |
| W03 | | | |
| W04 | | | |
| W05 | | | |

## Summary of the baseline

FILL after the run: how many queries use a Seq Scan, which tables are read in full, which queries put a function on a column, and the list of findings that starts Phase 4.
