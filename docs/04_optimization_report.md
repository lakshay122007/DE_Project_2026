# Phase 4: Optimization Report

**Team T0075** · Practo doctor appointments database

All numbers come from `benchmarks/results/baseline/summary.csv` (3 runs, before) and `benchmarks/results/optimized/summary.csv` (5 runs, after), same laptop, same data. Indexes are in `sql/05_indexes.sql`, rewritten queries in `sql/06_optimized_queries.sql`. Improvement % = (before - after) / before x 100.

## 1. Optimization table

The Before and After columns are the averages from the two `summary.csv` files; the problem column comes from the scan nodes of the baseline plan. R19 alone accounts for 8,132.9 ms of the 8,347.4 ms saved, so we also give the total without it.

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---|---|
| R01 | 2.381 | Already fast: index lookups on the primary keys; only small tables are scanned in full | None gained; the new indexes are used (Index Only Scan on idx_docspec_spec_doctor, Bitmap Index Scan on idx_clinics_city) but the query only touches small tables | 2.389 | -0.3% | unchanged text |
| R02 | 0.379 | Already an Index Scan on the doctor_schedules primary key | No change needed | 0.361 | 4.7% | unchanged text |
| R03 | 15.2 | Seq Scan on appointments for the taken-slot probe | idx_appt_doctor_slot (doctor_id, slot_start) INCLUDE (status): Index Only Scan | 0.154 | 99.0% (99x) | unchanged text |
| R04 | 12.9 | Seq Scan on appointments for patient 90 | idx_appt_patient_slot (patient_id, slot_start): Bitmap Index Scan | 0.195 | 98.5% (66x) | unchanged text |
| R05 | 9.647 | Seq Scan on appointments; DATE(slot_start) puts a function on the column so no index can be used | Rewrite to a slot_start range; idx_appt_doctor_slot | 0.455 | 95.3% (21x) | yes |
| R06 | 0.042 | Already an Index Scan on the UNIQUE phone index | No change needed; difference is timing noise at 0.04 ms | 0.049 | -16.7% (noise) | unchanged text |
| R07 | 0.094 | Already Index Scans on the UNIQUE appointment_id and items primary key | No change needed | 0.091 | 3.2% | unchanged text |
| R08 | 39.0 | Seq Scan on appointments; EXTRACT(YEAR ...) on the column | Rewrite to a slot_start range, but the plan stays a Seq Scan: 2026 holds most of the rows, so reading the whole table is the cheapest plan | 39.0 | 0.0% | yes |
| R09 | 15.7 | Seq Scan on appointments for a one-month range | idx_appt_slot_covering: Index Scan on the June range | 5.031 | 68.0% (3.1x) | unchanged text |
| R10 | 34.5 | Seq Scan on appointments and patients | idx_patients_allergies_gin is used (Bitmap Index Scan); the trigram index on medicine_name is not chosen, and appointments is still scanned in full | 31.0 | 10.1% | unchanged text |
| R11 | 31.9 | Seq Scan on appointments and prescriptions | idx_presc_follow_up (partial) and idx_appt_patient_slot for the NOT EXISTS probe | 6.002 | 81.2% (5.3x) | unchanged text |
| R12 | 46.9 | Seq Scan on appointments; EXTRACT(YEAR ...) on the column | Rewrite to a slot_start range; plan stays a Seq Scan because 2026 covers most of the table | 46.4 | 1.2% | yes |
| R13 | 5.019 | WRONG RESULT: NOT IN with NULL clinic_id returns 0 rows (see section 2); small tables, Seq Scans | Rewrite to NOT EXISTS: returns 292 clinics instead of 0. Speed is unchanged, the change is for correctness | 5.070 | -1.0% | No, intentionally (see section 2) |
| R14 | 37.0 | Seq Scan on appointments and doctor_reviews; every review is aggregated | None possible, see section 7 | 36.5 | 1.3% | unchanged text |
| R15 | 38.4 | Seq Scan on prescriptions, prescription_items and appointments | idx_presc_issued is used for the June range; the joins still scan prescription_items and appointments in full | 33.8 | 12.0% | unchanged text |
| R16 | 17.7 | Seq Scan on appointments for a one-month range | idx_appt_slot_covering: Index Scan on the June range | 5.202 | 70.6% (3.4x) | unchanged text |
| R17 | 81.5 | Seq Scan on appointments and patients; age() computed per row | idx_appt_slot_covering gives an Index Only Scan on appointments; patients is still read in full and the work is per row | 72.9 | 10.5% | unchanged text |
| R18 | 7.785 | Seq Scan on doctor_schedules and doctors | Rewrite to languages @> ARRAY['Tamil']; idx_clinics_city and Index Only Scan on idx_sched_clinic_doctor. GIN on languages is not chosen for 3,000 doctors | 4.904 | 37.0% (1.6x) | yes |
| R19 | 8157.6 | Two correlated subqueries run once per doctor, each scanning appointments | Rewrite to one LEFT JOIN with a FILTER aggregate; idx_appt_doctor_slot | 24.6 | 99.7% (331x) | yes |
| R20 | 15.5 | Seq Scan on appointments; slot_start::date BETWEEN on the column | Rewrite to a slot_start range; the plan still shows a Seq Scan (planner judged it cheaper at this size), so little gain | 15.2 | 2.2% | yes |
| R21 | 16.0 | Seq Scan on appointments then sort, for the latest 100 rows | idx_appt_unpaid_completed (partial, covering, in query order): Index Only Scan | 0.174 | 98.9% (92x) | unchanged text |
| R22 | 62.5 | Seq Scan and sort of the whole table for newest-first paging | idx_appt_slot_covering: Index Only Scan read backwards; OFFSET 100000 still walks 100,000 index entries | 13.0 | 79.2% (4.8x) | unchanged text |
| R23 | 0.046 | Already an Index Scan on the UNIQUE registration_no index | No change needed | 0.043 | 6.5% | unchanged text |
| R24 | 40.1 | Self join of appointments; Seq Scan on both sides | idx_appt_doctor_slot exists but the planner keeps the Seq Scan: the join compares all active appointments | 38.5 | 4.2% | unchanged text |
| R25 | 36.2 | Seq Scan on appointments and doctor_specializations | idx_appt_slot_covering gives an Index Only Scan, but the query still reads every completed 2026 appointment | 26.4 | 27.0% (1.4x) | unchanged text |
| W01 | 1.092 | Insert; no read problem | Unchanged text; 6 more indexes to maintain on appointments (see section 5) | 1.501 | -37.5% (slower) | unchanged text |
| W02 | 12.8 | Seq Scan on appointments to find the earliest BOOKED row | idx_appt_booked_slot (partial): Index Scan | 0.521 | 95.9% (24.5x) | unchanged text |
| W03 | 0.261 | Already an Index Scan on prescriptions.appointment_id | Unchanged; idx_presc_follow_up must be updated when follow_up_date changes (see section 5) | 0.356 | -36.4% (slower) | unchanged text |
| W04 | 17.6 | Seq Scan on appointments for open appointments | idx_appt_open_slot_end (partial): Index Scan | 11.7 | 33.2% (1.5x) | unchanged text |
| W05 | 13.7 | Seq Scan on appointments to find the doctor's bookings | idx_appt_doctor_slot: Index Scan | 0.531 | 96.1% (25.7x) | unchanged text |
| **Total** | 8,769.5 | | | 422.1 | 95.2% (35.0% when R19 is left out) | |

## 2. The query with the wrong answer: R13

R13 asks for clinics where no doctor has any schedule. It uses `clinic_id NOT IN (SELECT sc.clinic_id FROM doctor_schedules sc)`. In `doctor_schedules`, `clinic_id` is NULL for the 5,899 video sessions. With a NULL in the list, `x NOT IN (...)` is never true, so the query returns 0 rows no matter which clinics are unused.

Fix: `NOT EXISTS (SELECT 1 FROM doctor_schedules sc WHERE sc.clinic_id = c.clinic_id)`. The original returns 0 rows; the fixed query returns 292 clinics with no schedule. Comparing the original `NOT IN` with `WHERE sc.clinic_id IS NOT NULL` added to the subquery gives the same 292 rows, which shows the NULL is the only cause.

## 3. Proof that the results are unchanged

Output of `psql -d practo_db -f scratch/04_equivalence.sql` (row counts and EXCEPT in both directions for the original and the rewritten text on the same data):

| Query | Original rows | Rewritten rows | Only in original | Only in rewritten | Verdict |
|---|---:|---:|---:|---:|---|
| R05 | 3 | 3 | 0 | 0 | SAME |
| R08 | 15 | 15 | 0 | 0 | SAME |
| R12 | 14 | 14 | 0 | 0 | SAME |
| R13, NOT IN with IS NOT NULL vs NOT EXISTS | 292 | 292 | 0 | 0 | SAME |
| R13, original vs NOT EXISTS | 0 | 292 | 0 | 292 | DIFFERENT (this is the fix) |
| R18 | 360 | 360 | 0 | 0 | SAME |
| R19 | 480 | 480 | 0 | 0 | SAME |
| R20 | 26 | 26 | 0 | 0 | SAME |

Queries whose text we did not change keep identical results by construction (only indexes were added).

## 4. Before and after plans of the five biggest improvements

The five queries with the largest absolute saving. Plan lines are copied from `benchmarks/results/baseline/<id>.txt` and `benchmarks/results/optimized/<id>.txt` (run 1 of each file shown; later runs are noted).

### R19: 8,157.6 ms to 24.6 ms

Before: the two correlated subqueries run once for each of the 480 Bengaluru doctors, and each run scans all of `appointments`.
```
SubPlan 1
  -> Seq Scan on appointments a (actual time=9.257..9.779 rows=2.26 loops=480)
       Rows Removed by Filter: 149998
SubPlan 2
  -> Seq Scan on appointments a_1 (actual time=0.149..7.235 rows=49.60 loops=480)
       Rows Removed by Filter: 149950
Execution Time: 8178.359 ms
```
After: one join with a FILTER aggregate, reading each doctor's appointments through the index.
```
-> Index Only Scan using idx_appt_doctor_slot on appointments a (actual time=0.003..0.004 rows=2.26 loops=480)
-> Bitmap Index Scan on idx_appt_doctor_slot (actual time=0.004..0.004 rows=49.60 loops=480)
Execution Time: 21.216 ms
```

### R22: 62.5 ms to 13.0 ms

Before: the whole table is read and sorted, and the sort does not fit in memory.
```
Sort Method: external merge  Disk: 6176kB
-> Seq Scan on appointments (actual time=0.011..15.939 rows=150000.00 loops=1)
Execution Time: 60.288 ms
```
After: the covering index is read backwards, so there is no sort and no table access. It still walks 100,025 entries because of OFFSET 100000. Run 1 took 19.057 ms (cold cache), runs 2 to 5 about 11.4 ms.
```
-> Index Only Scan Backward using idx_appt_slot_covering on appointments (actual time=0.051..15.742 rows=100025.00 loops=1)
Execution Time: 19.057 ms
```

### R11: 31.9 ms to 6.0 ms

Before: Seq Scan of 150,000 appointments to probe for later bookings, plus a Seq Scan of prescriptions that discards 96,804 rows.
```
Seq Scan on appointments f (actual time=0.005..16.989 rows=135100.00 loops=1)
Seq Scan on prescriptions p (actual time=5.764..6.281 rows=430.00 loops=1)
  Rows Removed by Filter: 96804
Execution Time: 32.506 ms
```
After: the one-week follow-up range comes from the partial index, and each of the 430 patients is checked through the patient index. Run 1 was 20.433 ms (cold cache), later runs about 2.4 ms.
```
Index Scan using idx_presc_follow_up on prescriptions p (actual time=0.585..0.796 rows=430.00 loops=1)
Index Scan using idx_appt_patient_slot on appointments f (actual time=0.043..0.043 rows=0.00 loops=430)
Execution Time: 20.433 ms
```

### R21: 16.0 ms to 0.17 ms

Before: a parallel Seq Scan of all appointments, then a sort to find the latest 100.
```
Sort Method: top-N heapsort  Memory: 38kB
-> Parallel Seq Scan on appointments (actual time=0.011..10.965 rows=12341.50 loops=2)
     Rows Removed by Filter: 62658
Execution Time: 16.051 ms
```
After: the partial index holds only unpaid completed rows in the order of the query, so exactly 100 index entries are read. Run 1 was 0.503 ms, later runs about 0.09 ms.
```
-> Index Only Scan using idx_appt_unpaid_completed on appointments (actual time=0.469..0.475 rows=100.00 loops=1)
Execution Time: 0.503 ms
```

### R03: 15.2 ms to 0.15 ms

Before: the taken-slot check scans all appointments.
```
-> Seq Scan on appointments a (actual time=0.316..14.387 rows=72.00 loops=1)
     Rows Removed by Filter: 149928
Execution Time: 14.499 ms
```
After: an Index Only Scan on the doctor's slots.
```
-> Index Only Scan using idx_appt_doctor_slot on appointments a (actual time=0.072..0.078 rows=72.00 loops=1)
Execution Time: 0.168 ms
```

Run 1 of the optimized queries is slower than runs 2 to 5 for R11, R21 and R22. The first run reads index pages that are not yet in memory; later runs hit the cache. That is why the optimized benchmark uses 5 runs and reports the average.

## 5. Write overhead

| Write | Before (ms) | After (ms) | Change |
|---|---:|---:|---|
| W01 | 1.092 | 1.501 | +0.409 ms, slower |
| W02 | 12.8 | 0.521 | faster |
| W03 | 0.261 | 0.356 | +0.095 ms, slower |
| W04 | 17.6 | 11.7 | faster |
| W05 | 13.7 | 0.531 | faster |

W01 is slower because the new row must be added to the 6 new indexes on `appointments` as well as the primary key. W03 is slower because `idx_presc_follow_up` is updated when `follow_up_date` changes. Both stay near 1 ms or below, which is acceptable for a booking and a notes update; W02, W04 and W05 gain far more from finding their rows by index than they lose in maintenance. Because every index also slows bulk loads and inserts, we only kept indexes that a query uses.

## 6. Index storage

Sizes of the indexes we created (from `pg_relation_size`), against their table:

| Index | Table | Index size | Table size | % of table |
|---|---|---:|---:|---:|
| idx_appt_slot_covering | appointments | 7,352 kB | 21 MB | 33.7 |
| idx_appt_doctor_slot | appointments | 7,168 kB | 21 MB | 32.9 |
| idx_items_medicine_trgm | prescription_items | 6,968 kB | 17 MB | 41.1 |
| idx_appt_patient_slot | appointments | 4,640 kB | 21 MB | 21.3 |
| idx_presc_issued | prescriptions | 2,000 kB | 7,296 kB | 27.4 |
| idx_appt_unpaid_completed | appointments | 1,208 kB | 21 MB | 5.5 |
| idx_sched_clinic_doctor | doctor_schedules | 408 kB | 1,800 kB | 22.7 |
| idx_presc_follow_up | prescriptions | 224 kB | 7,296 kB | 3.1 |
| idx_docspec_spec_doctor | doctor_specializations | 104 kB | 160 kB | 65.0 |
| idx_patients_allergies_gin | patients | 80 kB | 4,440 kB | 1.8 |
| idx_appt_open_slot_end | appointments | 40 kB | 21 MB | 0.2 |
| idx_appt_booked_slot | appointments | 40 kB | 21 MB | 0.2 |
| idx_clinics_city | clinics | 32 kB | 168 kB | 19.0 |
| idx_doctors_languages_gin | doctors | 24 kB | 408 kB | 5.9 |

Whole schema: database 112 MB, tables 54 MB, all indexes 49 MB (including primary and unique keys). The two covering indexes on `appointments` are the largest, each about a third of the table; partial indexes are tiny. The cost is acceptable at this size, but at 20x the three largest would be several hundred MB.

## 7. Queries we could not speed up, and why

- **R08 (39.0 to 39.0 ms) and R12 (46.9 to 46.4 ms):** the year 2026 holds most of the appointments, so the cheapest plan is to read the whole table. The range rewrite is correct and sargable but cannot save work.
- **R14 (37.0 to 36.5 ms):** averages every review per doctor, so every review must be read.
- **R17 (81.5 to 72.9 ms):** reads every completed 2026 appointment and computes `age()` for each row; this is the slowest query left.
- **R24 (40.1 to 38.5 ms):** compares all active appointments of the same doctor and slot; the planner prefers a hash join over a Seq Scan to an index nested loop.
- **R10 (34.5 to 31.0 ms) and R15 (38.4 to 33.8 ms):** the indexes are used for the filters, but the joins still read most of appointments and prescription_items.
- **R20 (15.5 to 15.2 ms):** the range rewrite did not change the Seq Scan the planner chose at this size.
- **R01, R02, R06, R07, R13, R23:** already at or under about 5 ms before tuning (R13 was changed for correctness, not speed).

## 8. Other observations

- R21 is titled "completed in-clinic consultations" but its SQL has no `consult_type` filter, so video consultations are included. We kept the SQL as given.
- `VACUUM (ANALYZE)` at the end of `05_indexes.sql` builds the visibility map that Index Only Scans need.