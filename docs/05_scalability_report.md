# Phase 5: Scalability Report

**Team T0075** · Practo doctor appointments database

Sections 5 to 8 below are the design part and can be committed before the large data arrives. Sections 1 to 4 and 9 need the large-data run: every FILL marker is a number or plan that comes from `benchmarks/results/large/`.

## 1. Results on the large dataset

Setup: new database `practo_large`, `sql/01_schema.sql`, load of `large_data/`, `sql/05_indexes.sql`, `ANALYZE`. Queries: `sql/06_optimized_queries.sql` only. FILL: run `python3 scratch/merge_summaries.py large benchmarks/results/optimized/summary.csv benchmarks/results/large/summary.csv` and paste the table. For every NO in the last column, add a row to section 3.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large / seed) | Target (ms) | Meets target? |
|---|---:|---:|---:|---:|:-:|
| FILL | | | | | |

Targets: R02 to R07, R23, W01 to W03 under 5 ms; R01, R11, R13, R18, R21, R22, W05 under 250 ms; R08, R09, R10, R12, R14 to R17, R19, R20, R24, R25 under 5,000 ms; W04 under 1,000 ms.

## 2. Growth analysis

FILL from the table above. Sort every query into one group.

| Group | Queries | Why |
|---|---|---|
| Stayed about the same | FILL | Index lookups cost O(log n); 20x rows adds roughly one more tree level |
| Grew about 20x | FILL | They read a fixed share of a table (for example every appointment of a month or a year), so work grows with the table |
| Grew more than 20x | FILL | FILL: reason from the plan (for example a hash join or sort that no longer fits in work_mem and spills to disk, or a plan that switched from index to sequential scan) |

## 3. What broke at scale and how it was fixed

FILL: one subsection per query that missed its target: the plan before (key lines), the cause, the change (index in `sql/05_indexes.sql` or rewrite in `sql/06_optimized_queries.sql`), the plan after. If the change alters the files, re-run the seed benchmark too so the seed and large columns stay comparable. R22: it still uses OFFSET 100000 with a covering index; FILL its time on large data, and if it misses 250 ms, switch to keyset paging and explain that the last-seen (slot_start, appointment_id) pair comes from the previous page.

## 4. Storage

FILL: run `psql -d practo_db -f scratch/05_index_sizes.sql` on seed and on `practo_large` and paste both outputs. Then state total database size, tables versus indexes, and the growth factor.

| | Seed | Large |
|---|---:|---:|
| Database size | FILL | FILL |
| Tables | FILL | FILL |
| Indexes | FILL | FILL |

## 5. Partitioning

Table: `appointments`. It is the largest and fastest-growing table (about 3,000,000 rows at 20x, and it grows every day), and most of its heavy queries filter on a time window: R09, R12, R16, R17, R20, R25 and the nightly job W04.

Method: RANGE on `slot_start`, one partition per month, plus a DEFAULT partition. Reasons: a monthly report touches one partition instead of the whole table; old months can be detached and archived instead of deleted row by row; each partition's indexes are small enough to stay in cache; VACUUM runs per partition. HASH on `doctor_id` was rejected because time-window queries would still touch every partition; LIST has no natural values to list.

DDL: `sql/08_partitioning.sql` (creates `appointments_part`, 24 monthly partitions for 2025 and 2026, a default partition, loads the rows and shows pruning plans).

Rules and costs we hit:

- **Primary key rule.** A primary key or unique constraint on a partitioned table must contain the partition key. The key becomes `(appointment_id, slot_start)`; `appointment_id` alone can no longer be guaranteed unique by the database.
- **Foreign keys pointing to it.** `prescriptions.appointment_id` and `doctor_reviews.appointment_id` reference `appointments(appointment_id)`. That needs a unique constraint on `appointment_id` alone, which a partitioned table cannot have, so those two foreign keys would have to be dropped or replaced by a check in the application. This is the main price of partitioning here.
- **Pruning works only when the filter has the key.** FILL: paste the four EXPLAIN outputs from the script. The June query scans one partition; the 2026 query scans 12 partitions; the doctor-only query (`WHERE doctor_id = 16`) scans every partition. Say which queries benefit and which do not.

FILL: after the large run, report the partitioned timing of one monthly query (R20 or R16) against the unpartitioned time, using the same data.

## 6. Sharding

Choice: shard `appointments` (and the tables hanging off it) by `doctor_id`, using a hash. Reasons: the busiest screens are all doctor-local (R03 slot picker, R05 doctor queue, R24 double-booking check, W01 booking, W05 leave). Booking correctness (no two active appointments in one slot) can only be enforced inside one shard, which is true if all of a doctor's appointments live together.

Why not by city: patients book video consultations with doctors in other cities, and doctors practise in several cities (R19), so a city shard would split one doctor's calendar. Why not by patient: a doctor's queue would be scattered over every shard.

Small reference tables (cities, specializations, clinics, doctors, doctor_specializations, doctor_schedules) are copied to every shard.

Queries that become cross-shard, and the handling:

| Queries | Why cross-shard | Handling |
|---|---|---|
| R04, R10, R11, R25 | Follow one patient across many doctors | Keep a small patient-to-appointments lookup table, or ask all shards in parallel and merge |
| R08, R12, R14, R16, R17, R20, R24 | Aggregates over all doctors | Compute partial aggregates per shard and add them up centrally; or read from a warehouse |
| R22 | Global newest-first order | Each shard returns its top rows; the router merges them; keyset paging replaces OFFSET |
| R15 | Joins prescriptions across doctors | Per-shard partial counts, merged centrally |
| R06, R23 | Patient and doctor lookups | Reference data, stays single-node |

## 7. Read replicas and caching

| Send to | Queries | Why |
|---|---|---|
| Primary only | W01 to W05, R03, R04, R05, R06, R07 | A booking or check-in must be visible to the next read; a slot picker on a stale replica would show a slot that was just taken |
| Read replica | R08, R09, R10, R12, R14, R15, R16, R17, R19, R20, R24, R25, R11, R13, R21, R22 | Reports and tools that tolerate seconds of delay and are heavy enough to disturb bookings |
| Cache (minutes to hours) | R01, R02, R18, R23 | Doctor search, profile and registration look-ups change rarely |

## 8. Maintenance

- **Autovacuum on `appointments`:** the table gets constant status updates (W02, W04, W05). Set per-table storage parameters, for example `ALTER TABLE appointments SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_analyze_scale_factor = 0.01);` so vacuum starts after 2 percent of rows change instead of 20 percent. This is a table setting, not a server setting.
- **Visibility map:** the Index Only Scans (R22, R03) depend on regular VACUUM; check `Heap Fetches` in the plans.
- **Archiving:** with monthly partitions, `ALTER TABLE appointments_part DETACH PARTITION ...` moves a closed month out of the hot table in one step.
- **Summary tables:** R12 and R20 do not need live data. Refresh a monthly summary (materialized view or table) nightly with `REFRESH MATERIALIZED VIEW` and read the reports from it.
- **New partitions:** create next month's partition before it is needed; the DEFAULT partition catches strays and must be checked.

## 9. Conclusion

FILL after the run: say whether every query meets its target on 20x data, which ones needed a change, which are the remaining risks (for example R22 with OFFSET, R17 and R25 growing about 20x, index storage, write overhead of the 6 added indexes on `appointments`), and what you would do first for 100x (partition `appointments` by month).
