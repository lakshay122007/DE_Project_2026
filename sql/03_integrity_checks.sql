SET search_path TO practo;

SELECT 1 AS check_no, 'Appointment slot lies inside a schedule row of that doctor for that weekday' AS rule, count(*) AS violations
FROM appointments a
WHERE NOT EXISTS (SELECT 1 FROM doctor_schedules sc
                  WHERE sc.doctor_id = a.doctor_id
                    AND sc.weekday = EXTRACT(ISODOW FROM a.slot_start)::int
                    AND a.slot_start::time >= sc.start_time
                    AND a.slot_end::time <= sc.end_time)
UNION ALL
SELECT 2, 'In-clinic appointment is at a clinic where the doctor has a schedule', count(*)
FROM appointments a
WHERE a.consult_type = 'IN_CLINIC'
  AND NOT EXISTS (SELECT 1 FROM doctor_schedules sc
                  WHERE sc.doctor_id = a.doctor_id AND sc.clinic_id = a.clinic_id)
UNION ALL
SELECT 3, 'Appointment fee equals the doctor fee for that consult type', count(*)
FROM appointments a
JOIN doctors d ON d.doctor_id = a.doctor_id
WHERE a.fee IS DISTINCT FROM CASE WHEN a.consult_type = 'IN_CLINIC' THEN d.consultation_fee ELSE d.video_fee END
UNION ALL
SELECT 4, 'Appointment length equals the slot_minutes of the schedule row it falls in', count(*)
FROM appointments a
WHERE NOT EXISTS (SELECT 1 FROM doctor_schedules sc
                  WHERE sc.doctor_id = a.doctor_id
                    AND sc.weekday = EXTRACT(ISODOW FROM a.slot_start)::int
                    AND a.slot_start::time >= sc.start_time
                    AND a.slot_start::time < sc.end_time
                    AND a.slot_end - a.slot_start = sc.slot_minutes * interval '1 minute')
UNION ALL
SELECT 5, 'Prescription belongs to a COMPLETED appointment', count(*)
FROM prescriptions p
JOIN appointments a ON a.appointment_id = p.appointment_id
WHERE a.status <> 'COMPLETED'
UNION ALL
SELECT 6, 'Review belongs to a COMPLETED appointment', count(*)
FROM doctor_reviews r
JOIN appointments a ON a.appointment_id = r.appointment_id
WHERE a.status <> 'COMPLETED'
UNION ALL
SELECT 7, 'Review is written after the appointment slot has ended', count(*)
FROM doctor_reviews r
JOIN appointments a ON a.appointment_id = r.appointment_id
WHERE r.created_at < a.slot_end
UNION ALL
SELECT 8, 'No penicillin-allergic patient is prescribed amoxicillin', count(*)
FROM patients pt
JOIN appointments a       ON a.patient_id = pt.patient_id
JOIN prescriptions p      ON p.appointment_id = a.appointment_id
JOIN prescription_items i ON i.prescription_id = p.prescription_id
WHERE pt.allergies @> ARRAY['Penicillin']
  AND i.medicine_name ILIKE '%amoxicillin%'
UNION ALL
SELECT 9, 'No two active appointments of one doctor share a slot', count(*)
FROM appointments a
JOIN appointments b ON b.doctor_id = a.doctor_id AND b.slot_start = a.slot_start AND b.appointment_id > a.appointment_id
WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED'
ORDER BY check_no;
