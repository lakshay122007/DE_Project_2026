# Phase 1: Problem Understanding

**Team T0075** · Practo doctor appointments database

Practo lets patients find doctors and book a slot, either at a clinic or as a video consultation. The database was put together quickly, nobody documented its schema, and several teams say their screens and reports are slow or wrong. The table below says what each team needs and who suffers when it is slow.

**Real-time** means a person is waiting on a screen right now, so the answer must come back in milliseconds. **Reporting** means someone reads a summary later, so a few seconds is acceptable.

| # | What the business needs | Who is affected | Type | Queries |
|---|---|---|---|---|
| **P1** | Patients search for a doctor by specialization, city and language, open a doctor's profile and use the slot picker. The picker builds the free slots from the weekly schedule every time it opens, so it has to be fast or patients leave. | Patient, doctor (profile visibility) | **Real-time** (R02, R03), interactive search (R01, R18) | R01, R02, R03, R18 |
| **P2** | A patient opens My appointments, signs in with a mobile number, reads a prescription and books a slot. Each of these waits on the database, and booking lags. | Patient, support | **Real-time** | R04, R06, R07, W01 |
| **P3** | Clinic reception must see the doctor's queue for the day and check the patient in at once. A slow screen means a queue at the desk. | Clinic reception, doctor | **Real-time** | R05, W02 |
| **P4** | Patient safety: find patients allergic to penicillin who were given amoxicillin, find follow-ups that are due but not booked, find patients who see three or more doctors of the same specialization ("doctor shopping"), and let a doctor add notes and a follow-up date to a prescription. | Patient-safety team, care team, doctor | **Reporting** (R10, R25), interactive (R11), real-time write (W03) | R10, R11, R25, W03 |
| **P5** | The list of clinics where no doctor has a schedule is always empty. That is a wrong answer, not a speed problem. We expect the cause is a NOT IN subquery over `clinic_id`, which is empty (NULL) for video schedules. We will confirm this when we run the query. | Clinic partnerships | **Reporting** (wrong result, interactive target) | R13 |
| **P6** | Quality reports time out: no-show rate per specialization, how long patients wait after their slot time, doctor ratings and recommendation rate, and double bookings. A nightly job also has to mark missed appointments as NO_SHOW. | Quality team, clinic managers, doctors | **Reporting / analytics**, W04 is a batch job | R08, R09, R14, R24, W04 |
| **P7** | Finance, pharmacy and population-health reports are slow: fees collected per clinic, unpaid consultations, most prescribed medicines, video vs in-clinic volume, age and blood-group breakdowns, daily totals, the support console's appointment list, doctor lookup by registration number, and cancelling a doctor's day when they go on leave. Appointments will grow 20 times, so these must still work at that size. | Finance, pharmacy partners, population-health / insights team, support, verification team | **Reporting / analytics**; R21, R22, W05 interactive; R23 real-time | R12, R15, R16, R17, R19, R20, R21, R22, R23, W05 |

### Query groups (these set our speed targets later)

| Group | Queries | Target on the large data |
|---|---|---|
| Real-time (patient and clinic screens) | R02, R03, R04, R05, R06, R07, R23, W01, W02, W03 | under 5 ms |
| Interactive search and tools | R01, R11, R13, R18, R21, R22, W05 | under 250 ms |
| Reports and analytics | R08, R09, R10, R12, R14, R15, R16, R17, R19, R20, R24, R25 | under 5,000 ms |
| Batch job | W04 | under 1,000 ms |

### Assumptions

1. The CSV exports are the real production data. The schema must accept every row. Rows that look wrong are kept and reported as data problems, never deleted or edited.
2. All timestamps are Indian time (+05:30). "June 2026" means 1 June 00:00 to 30 June 23:59:59 IST.
3. The data covers 1 Jan 2025 to 30 Jun 2026. The workload queries behave as if today is between 30 June and 3 July 2026.
4. An appointment belongs to one patient and one doctor. An in-clinic appointment has a clinic. A video consultation has none.
5. A schedule row with no clinic is a video consultation slot.
6. The 30 queries are fixed. We may change the schema, add indexes and write rewritten copies of the queries. We do not change the data or the server settings.
7. We measure one user at a time on one laptop. This is not a load test.
