DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'Asia/Kolkata');
END $$;

SET timezone TO 'Asia/Kolkata';

DROP SCHEMA IF EXISTS practo CASCADE;
CREATE SCHEMA practo;
SET search_path TO practo;

CREATE TABLE cities (
    city_id    INTEGER      PRIMARY KEY,
    city_name  VARCHAR(60)  NOT NULL UNIQUE,
    state      VARCHAR(60)  NOT NULL
);

CREATE TABLE specializations (
    spec_id    INTEGER      PRIMARY KEY,
    spec_name  VARCHAR(60)  NOT NULL UNIQUE
);

CREATE TABLE doctors (
    doctor_id         INTEGER       PRIMARY KEY,
    full_name         VARCHAR(100)  NOT NULL,
    registration_no   VARCHAR(20)   NOT NULL UNIQUE,
    gender            VARCHAR(1)    NOT NULL,
    experience_years  SMALLINT      NOT NULL,
    consultation_fee  NUMERIC(8,2)  NOT NULL,
    video_fee         NUMERIC(8,2),
    languages         TEXT[]        NOT NULL,
    is_verified       BOOLEAN       NOT NULL,
    joined_on         DATE          NOT NULL,
    CONSTRAINT ck_doctors_gender       CHECK (gender IN ('M', 'F')),
    CONSTRAINT ck_doctors_regno        CHECK (registration_no ~ '^[A-Z]{4}-[0-9]{6}$'),
    CONSTRAINT ck_doctors_experience   CHECK (experience_years BETWEEN 0 AND 60),
    CONSTRAINT ck_doctors_fee          CHECK (consultation_fee > 0),
    CONSTRAINT ck_doctors_video_fee    CHECK (video_fee IS NULL OR video_fee > 0),
    CONSTRAINT ck_doctors_languages    CHECK (cardinality(languages) > 0)
);

CREATE TABLE doctor_specializations (
    doctor_id   INTEGER  NOT NULL REFERENCES doctors (doctor_id) ON DELETE CASCADE,
    spec_id     INTEGER  NOT NULL REFERENCES specializations (spec_id),
    is_primary  BOOLEAN  NOT NULL,
    PRIMARY KEY (doctor_id, spec_id)
);

CREATE UNIQUE INDEX uq_doctor_one_primary_spec
    ON doctor_specializations (doctor_id) WHERE is_primary;

CREATE TABLE clinics (
    clinic_id    INTEGER       PRIMARY KEY,
    clinic_name  VARCHAR(120)  NOT NULL,
    city_id      INTEGER       NOT NULL REFERENCES cities (city_id),
    locality     VARCHAR(100)  NOT NULL,
    latitude     NUMERIC(9,6)  NOT NULL,
    longitude    NUMERIC(9,6)  NOT NULL,
    phone        VARCHAR(20)   NOT NULL UNIQUE,
    CONSTRAINT ck_clinics_latitude   CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_clinics_longitude  CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_clinics_phone      CHECK (phone ~ '^\+91-[0-9]{2}-[0-9]{7}$')
);

CREATE TABLE doctor_schedules (
    doctor_id     INTEGER   NOT NULL REFERENCES doctors (doctor_id) ON DELETE CASCADE,
    weekday       SMALLINT  NOT NULL,
    start_time    TIME      NOT NULL,
    end_time      TIME      NOT NULL,
    clinic_id     INTEGER   REFERENCES clinics (clinic_id),
    slot_minutes  SMALLINT  NOT NULL,
    PRIMARY KEY (doctor_id, weekday, start_time),
    CONSTRAINT ck_schedules_weekday  CHECK (weekday BETWEEN 1 AND 7),
    CONSTRAINT ck_schedules_times    CHECK (end_time > start_time),
    CONSTRAINT ck_schedules_slot     CHECK (slot_minutes BETWEEN 5 AND 60)
);

CREATE TABLE patients (
    patient_id   INTEGER       PRIMARY KEY,
    full_name    VARCHAR(100)  NOT NULL,
    phone        VARCHAR(10)   NOT NULL UNIQUE,
    email        VARCHAR(120)  UNIQUE,
    dob          DATE          NOT NULL,
    gender       VARCHAR(1)    NOT NULL,
    blood_group  VARCHAR(3),
    allergies    TEXT[],
    city_id      INTEGER       NOT NULL REFERENCES cities (city_id),
    created_at   TIMESTAMPTZ   NOT NULL,
    CONSTRAINT ck_patients_phone      CHECK (phone ~ '^[0-9]{10}$'),
    CONSTRAINT ck_patients_email      CHECK (email IS NULL OR (email ~ '^[^@\s]+@[^@\s]+\.[a-z]{2,}$' AND email = lower(email))),
    CONSTRAINT ck_patients_gender     CHECK (gender IN ('M', 'F', 'X')),
    CONSTRAINT ck_patients_blood      CHECK (blood_group IS NULL OR blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    CONSTRAINT ck_patients_allergies  CHECK (allergies IS NULL OR cardinality(allergies) > 0),
    CONSTRAINT ck_patients_dob        CHECK (dob >= DATE '1900-01-01' AND dob <= created_at::date)
);

CREATE TABLE appointments (
    appointment_id      INTEGER       PRIMARY KEY,
    patient_id          INTEGER       NOT NULL REFERENCES patients (patient_id),
    doctor_id           INTEGER       NOT NULL REFERENCES doctors (doctor_id),
    clinic_id           INTEGER       REFERENCES clinics (clinic_id),
    consult_type        VARCHAR(10)   NOT NULL,
    booked_at           TIMESTAMPTZ   NOT NULL,
    slot_start          TIMESTAMPTZ   NOT NULL,
    slot_end            TIMESTAMPTZ   NOT NULL,
    reason              VARCHAR(200)  NOT NULL,
    status              VARCHAR(10)   NOT NULL,
    checked_in_at       TIMESTAMPTZ,
    consult_started_at  TIMESTAMPTZ,
    consult_ended_at    TIMESTAMPTZ,
    fee                 NUMERIC(8,2)  NOT NULL,
    payment_status      VARCHAR(10)   NOT NULL,
    CONSTRAINT ck_appt_consult_type   CHECK (consult_type IN ('IN_CLINIC', 'VIDEO')),
    CONSTRAINT ck_appt_status         CHECK (status IN ('BOOKED', 'CHECKED_IN', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
    CONSTRAINT ck_appt_payment        CHECK (payment_status IN ('PAID', 'PENDING', 'REFUNDED')),
    CONSTRAINT ck_appt_clinic_rule    CHECK ((consult_type = 'IN_CLINIC' AND clinic_id IS NOT NULL)
                                          OR (consult_type = 'VIDEO' AND clinic_id IS NULL)),
    CONSTRAINT ck_appt_slot_order     CHECK (slot_end > slot_start),
    CONSTRAINT ck_appt_booked_order   CHECK (booked_at <= slot_start),
    CONSTRAINT ck_appt_consult_order  CHECK (consult_ended_at IS NULL OR consult_started_at IS NULL OR consult_ended_at >= consult_started_at),
    CONSTRAINT ck_appt_fee            CHECK (fee >= 0),
    CONSTRAINT ck_appt_completed_times CHECK ((status = 'COMPLETED' AND consult_started_at IS NOT NULL AND consult_ended_at IS NOT NULL)
                                          OR (status <> 'COMPLETED' AND consult_started_at IS NULL AND consult_ended_at IS NULL)),
    CONSTRAINT ck_appt_checkin_status  CHECK (checked_in_at IS NULL OR status IN ('CHECKED_IN', 'COMPLETED', 'NO_SHOW')),
    CONSTRAINT ck_appt_video_checkin  CHECK (consult_type <> 'VIDEO' OR checked_in_at IS NULL),
    CONSTRAINT ck_appt_refund_rule    CHECK (payment_status <> 'REFUNDED' OR status = 'CANCELLED'),
    CONSTRAINT ck_appt_booked_pending CHECK (status <> 'BOOKED' OR payment_status = 'PENDING')
);

CREATE TABLE prescriptions (
    prescription_id  INTEGER       PRIMARY KEY,
    appointment_id   INTEGER       NOT NULL UNIQUE REFERENCES appointments (appointment_id),
    diagnosis        VARCHAR(200)  NOT NULL,
    notes            TEXT,
    follow_up_date   DATE,
    issued_at        TIMESTAMPTZ   NOT NULL,
    CONSTRAINT ck_presc_follow_up CHECK (follow_up_date IS NULL OR follow_up_date >= issued_at::date)
);

CREATE TABLE prescription_items (
    prescription_id  INTEGER       NOT NULL REFERENCES prescriptions (prescription_id) ON DELETE CASCADE,
    line_no          SMALLINT      NOT NULL,
    medicine_name    VARCHAR(100)  NOT NULL,
    dosage           VARCHAR(10)   NOT NULL,
    duration_days    SMALLINT      NOT NULL,
    instructions     VARCHAR(200),
    PRIMARY KEY (prescription_id, line_no),
    CONSTRAINT ck_items_line      CHECK (line_no > 0),
    CONSTRAINT ck_items_dosage    CHECK (dosage ~ '^[0-9]-[0-9]-[0-9]$'),
    CONSTRAINT ck_items_duration  CHECK (duration_days > 0)
);

CREATE TABLE doctor_reviews (
    review_id         INTEGER       PRIMARY KEY,
    appointment_id    INTEGER       NOT NULL UNIQUE REFERENCES appointments (appointment_id),
    rating            SMALLINT      NOT NULL,
    recommends        BOOLEAN       NOT NULL,
    wait_time_bucket  VARCHAR(10)   NOT NULL,
    review_text       TEXT,
    created_at        TIMESTAMPTZ   NOT NULL,
    CONSTRAINT ck_reviews_rating  CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT ck_reviews_wait    CHECK (wait_time_bucket IN ('<15 min', '15-30 min', '30-60 min', '>1 hr'))
);