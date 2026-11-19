SET search_path TO practo, public;
SET timezone TO 'Asia/Kolkata';

DROP TABLE IF EXISTS appointments_part CASCADE;

CREATE TABLE appointments_part (LIKE appointments INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
    PARTITION BY RANGE (slot_start);

ALTER TABLE appointments_part ADD CONSTRAINT pk_appointments_part PRIMARY KEY (appointment_id, slot_start);
ALTER TABLE appointments_part ADD CONSTRAINT fk_apart_patient FOREIGN KEY (patient_id) REFERENCES patients (patient_id);
ALTER TABLE appointments_part ADD CONSTRAINT fk_apart_doctor  FOREIGN KEY (doctor_id)  REFERENCES doctors (doctor_id);
ALTER TABLE appointments_part ADD CONSTRAINT fk_apart_clinic  FOREIGN KEY (clinic_id)  REFERENCES clinics (clinic_id);

DO $$
DECLARE
    m date := DATE '2025-01-01';
BEGIN
    WHILE m < DATE '2027-01-01' LOOP
        EXECUTE format(
            'CREATE TABLE appointments_p_%s PARTITION OF appointments_part FOR VALUES FROM (%L) TO (%L)',
            to_char(m, 'YYYY_MM'),
            to_char(m, 'YYYY-MM-DD') || ' 00:00:00+05:30',
            to_char(m + interval '1 month', 'YYYY-MM-DD') || ' 00:00:00+05:30');
        m := (m + interval '1 month')::date;
    END LOOP;
END $$;

CREATE TABLE appointments_p_default PARTITION OF appointments_part DEFAULT;

CREATE INDEX idx_apart_doctor_slot ON appointments_part (doctor_id, slot_start) INCLUDE (status);
CREATE INDEX idx_apart_patient_slot ON appointments_part (patient_id, slot_start);

INSERT INTO appointments_part SELECT * FROM appointments;

VACUUM (ANALYZE) appointments_part;

SELECT tableoid::regclass AS partition, count(*) AS rows
FROM appointments_part
GROUP BY 1
ORDER BY 1;

SELECT count(*) AS rows_original, (SELECT count(*) FROM appointments_part) AS rows_partitioned FROM appointments;

EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT slot_start::date AS day, count(*) AS consults
FROM appointments_part
WHERE status = 'COMPLETED' AND slot_start >= '2026-06-01' AND slot_start < '2026-07-01'
GROUP BY 1
ORDER BY 1;

EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT date_trunc('month', slot_start) AS month, consult_type, count(*)
FROM appointments_part
WHERE slot_start >= '2026-01-01' AND slot_start < '2027-01-01'
GROUP BY 1, 2;

EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT a.appointment_id, p.full_name, a.slot_start, a.status
FROM appointments_part a JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01';

EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT count(*) FROM appointments_part WHERE doctor_id = 16;
