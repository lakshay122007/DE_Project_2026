SET search_path TO practo;

\copy cities               FROM 'seed_data/cities.csv'               WITH (FORMAT csv, HEADER true)
\copy specializations      FROM 'seed_data/specializations.csv'      WITH (FORMAT csv, HEADER true)
\copy doctors              FROM 'seed_data/doctors.csv'              WITH (FORMAT csv, HEADER true)
\copy clinics              FROM 'seed_data/clinics.csv'              WITH (FORMAT csv, HEADER true)
\copy doctor_specializations FROM 'seed_data/doctor_specializations.csv' WITH (FORMAT csv, HEADER true)
\copy doctor_schedules     FROM 'seed_data/doctor_schedules.csv'     WITH (FORMAT csv, HEADER true)
\copy patients             FROM 'seed_data/patients.csv'             WITH (FORMAT csv, HEADER true)
\copy appointments         FROM 'seed_data/appointments.csv'         WITH (FORMAT csv, HEADER true)
\copy prescriptions        FROM 'seed_data/prescriptions.csv'        WITH (FORMAT csv, HEADER true)
\copy prescription_items   FROM 'seed_data/prescription_items.csv'   WITH (FORMAT csv, HEADER true)
\copy doctor_reviews       FROM 'seed_data/doctor_reviews.csv'       WITH (FORMAT csv, HEADER true)

ANALYZE;

SELECT n, table_name, loaded, expected, loaded = expected AS ok
FROM (
              SELECT 1 AS n, 'cities' AS table_name, count(*) AS loaded, 10 AS expected FROM cities
    UNION ALL SELECT 2,  'specializations',        count(*), 15      FROM specializations
    UNION ALL SELECT 3,  'doctors',                count(*), 3000    FROM doctors
    UNION ALL SELECT 4,  'clinics',                count(*), 1500    FROM clinics
    UNION ALL SELECT 5,  'doctor_specializations', count(*), 3700    FROM doctor_specializations
    UNION ALL SELECT 6,  'doctor_schedules',       count(*), 30499   FROM doctor_schedules
    UNION ALL SELECT 7,  'patients',               count(*), 40000   FROM patients
    UNION ALL SELECT 8,  'appointments',           count(*), 150000  FROM appointments
    UNION ALL SELECT 9,  'prescriptions',          count(*), 97234   FROM prescriptions
    UNION ALL SELECT 10, 'prescription_items',     count(*), 243085  FROM prescription_items
    UNION ALL SELECT 11, 'doctor_reviews',         count(*), 30339   FROM doctor_reviews
) t
ORDER BY n;
