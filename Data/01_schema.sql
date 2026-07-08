USE WAREHOUSE SIGMA_LIVE_WH;
USE DATABASE SIGMA_LIVE_MES;
USE SCHEMA PUBLIC;

-- ---------- Lookup tables ----------

CREATE TABLE route (
    route_id      INTEGER AUTOINCREMENT,
    route_name    TEXT NOT NULL,
    product_type  TEXT NOT NULL,
    PRIMARY KEY (route_id)
);

CREATE TABLE station (
    station_id    INTEGER AUTOINCREMENT,
    station_name  TEXT NOT NULL UNIQUE,
    line_name     TEXT NOT NULL DEFAULT 'Line 1',
    PRIMARY KEY (station_id)
);

CREATE TABLE operator (
    operator_id   TEXT NOT NULL CHECK (operator_id RLIKE 'OP-[0-9]{3}'),
    name          TEXT NOT NULL,
    shift         TEXT CHECK (shift IN ('DAY','SWING','NIGHT')),
    PRIMARY KEY (operator_id)
);

CREATE TABLE reject_reason (
    reject_code   TEXT NOT NULL CHECK (reject_code RLIKE 'RJ-[0-9]{2}'),
    description   TEXT NOT NULL,
    category      TEXT NOT NULL CHECK (category IN ('MECHANICAL','ELECTRICAL','SOFTWARE','COSMETIC','OTHER')),
    PRIMARY KEY (reject_code)
);

-- ---------- Routing template ----------

CREATE TABLE route_step (
    step_id           INTEGER AUTOINCREMENT,
    route_id          INTEGER NOT NULL,
    step_name         TEXT NOT NULL,
    sequence_order    INTEGER NOT NULL,
    station_id        INTEGER NOT NULL,
    target_cycle_min  FLOAT NOT NULL DEFAULT 0,
    PRIMARY KEY (step_id),
    FOREIGN KEY (route_id) REFERENCES route(route_id),
    FOREIGN KEY (station_id) REFERENCES station(station_id),
    UNIQUE (route_id, sequence_order)
);

-- ---------- Physical units ----------

CREATE TABLE unit (
    serial_number    TEXT NOT NULL CHECK (serial_number RLIKE 'SN-[0-9]{4}'),
    route_id         INTEGER NOT NULL,
    status           TEXT NOT NULL DEFAULT 'IN_PROCESS'
                     CHECK (status IN ('IN_PROCESS','PASSED','SCRAPPED','ON_HOLD')),
    current_step_id  INTEGER,
    started_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    completed_at     TIMESTAMP_NTZ,
    PRIMARY KEY (serial_number),
    FOREIGN KEY (route_id) REFERENCES route(route_id),
    FOREIGN KEY (current_step_id) REFERENCES route_step(step_id)
);

-- ---------- Core transactional table ----------

CREATE TABLE step_event (
    event_id        INTEGER AUTOINCREMENT,
    serial_number   TEXT NOT NULL,
    step_id         INTEGER NOT NULL,
    operator_id     TEXT NOT NULL,
    result          TEXT NOT NULL CHECK (result IN ('PASS','FAIL')),
    reject_code     TEXT,
    attempt_no      INTEGER NOT NULL DEFAULT 1,
    started_at      TIMESTAMP_NTZ NOT NULL,
    ended_at        TIMESTAMP_NTZ NOT NULL,
    PRIMARY KEY (event_id),
    FOREIGN KEY (serial_number) REFERENCES unit(serial_number),
    FOREIGN KEY (step_id) REFERENCES route_step(step_id),
    FOREIGN KEY (operator_id) REFERENCES operator(operator_id),
    FOREIGN KEY (reject_code) REFERENCES reject_reason(reject_code),
    CHECK (
        (result = 'FAIL' AND reject_code IS NOT NULL) OR
        (result = 'PASS' AND reject_code IS NULL)
    ),
    UNIQUE (serial_number, step_id, attempt_no),

);

