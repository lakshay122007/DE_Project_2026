SET search_path TO practo, public;

CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA public;

-- idx_appt_doctor_slot: R03 (taken-slot probe), R05 (doctor's day), R19 (per-doctor counts), R24 (double-booking self join), W05 (doctor's bookings).
-- doctor_id is the equality column, slot_start the range/sort column. INCLUDE (status) lets R03 and R24 filter status without visiting the table.
CREATE INDEX idx_appt_doctor_slot ON appointments (doctor_id, slot_start) INCLUDE (status);

-- idx_appt_patient_slot: R04 (patient's upcoming list, sorted by slot_start), R10 and R11 (join from patient to appointments), R25.
-- patient_id equality first, slot_start second so the ORDER BY needs no sort.
CREATE INDEX idx_appt_patient_slot ON appointments (patient_id, slot_start);

-- idx_appt_slot_covering: R22 (newest-first paging reads the index backwards and never touches the table), plus date-range scans of R09, R12, R16, R17, R20, R25.
-- INCLUDE holds exactly the columns R22 returns, so it becomes an Index Only Scan once VACUUM has set the visibility map.
CREATE INDEX idx_appt_slot_covering ON appointments (slot_start) INCLUDE (appointment_id, patient_id, doctor_id, status);

-- idx_appt_unpaid_completed: R21 (latest 100 unpaid completed consultations).
-- Partial: only COMPLETED + PENDING rows are indexed, in the same order as the query (slot_start DESC), so LIMIT 100 stops after 100 index entries.
CREATE INDEX idx_appt_unpaid_completed ON appointments (slot_start DESC) INCLUDE (appointment_id, patient_id, clinic_id, fee)
    WHERE status = 'COMPLETED' AND payment_status = 'PENDING';

-- idx_appt_booked_slot: W02 (earliest BOOKED in-clinic appointment of a day).
-- Partial on the rare BOOKED status (about 1 percent of rows), so it stays tiny; ordered by slot_start for ORDER BY ... LIMIT 1.
CREATE INDEX idx_appt_booked_slot ON appointments (slot_start) WHERE status = 'BOOKED' AND consult_type = 'IN_CLINIC';

-- idx_appt_open_slot_end: W04 (nightly job: open appointments whose slot has ended).
-- Partial on the open statuses; slot_end is the range column of the query.
CREATE INDEX idx_appt_open_slot_end ON appointments (slot_end) WHERE status IN ('BOOKED', 'CHECKED_IN');

-- idx_presc_issued: R15 (prescriptions issued in June 2026). Range column, single column.
CREATE INDEX idx_presc_issued ON prescriptions (issued_at);

-- idx_presc_follow_up: R11 (follow-ups due in one week). Partial: 70 percent of prescriptions have no follow-up date.
CREATE INDEX idx_presc_follow_up ON prescriptions (follow_up_date) WHERE follow_up_date IS NOT NULL;

-- idx_items_medicine_trgm: R10 (ILIKE '%amoxicillin%'). A B-tree cannot serve a leading wildcard; a trigram GIN index can.
CREATE INDEX idx_items_medicine_trgm ON prescription_items USING gin (medicine_name gin_trgm_ops);

-- idx_patients_allergies_gin: R10 (allergies @> ARRAY['Penicillin']). GIN is the index type for array containment.
CREATE INDEX idx_patients_allergies_gin ON patients USING gin (allergies);

-- idx_doctors_languages_gin: R18 (language search, rewritten from = ANY to @> so GIN can be used).
CREATE INDEX idx_doctors_languages_gin ON doctors USING gin (languages);

-- idx_sched_clinic_doctor: R13 (clinics with no schedule), R01, R18, R19 (clinic to doctor lookups).
-- clinic_id first (equality from the clinics side), doctor_id second so the join is answered from the index alone.
CREATE INDEX idx_sched_clinic_doctor ON doctor_schedules (clinic_id, doctor_id);

-- idx_clinics_city: R01, R18, R19 (clinics of one city).
CREATE INDEX idx_clinics_city ON clinics (city_id);

-- idx_docspec_spec_doctor: R01 (doctors of one specialization). The primary key starts with doctor_id, so spec_id lookups need this reverse order.
CREATE INDEX idx_docspec_spec_doctor ON doctor_specializations (spec_id, doctor_id);

VACUUM (ANALYZE);
