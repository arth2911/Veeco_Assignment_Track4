USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SIGMA_LIVE_WH;
USE DATABASE SIGMA_LIVE_MES;
USE SCHEMA PUBLIC;

CREATE OR REPLACE PROCEDURE sp_insert_step_event(
    p_serial_number STRING,
    p_step_name STRING,
    p_operator_id STRING,
    p_result STRING,
    p_reject_code STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    v_step_id INTEGER;
    v_attempt_no INTEGER;
BEGIN
    -- Resolve the human-picked step name into the real numeric step_id
    SELECT step_id INTO :v_step_id FROM route_step WHERE step_name = :p_step_name;
    IF (v_step_id IS NULL) THEN
        RETURN 'ERROR: step_name not found: ' || p_step_name;
    END IF;

    -- Same validation the CHECK constraints describe, enforced here
    -- since Snowflake itself won't enforce them at insert time
    IF (p_result NOT IN ('PASS','FAIL')) THEN
        RETURN 'ERROR: result must be PASS or FAIL';
    END IF;

    IF (p_result = 'FAIL' AND (p_reject_code IS NULL OR p_reject_code = '')) THEN
        RETURN 'ERROR: reject_code is required when result = FAIL';
    END IF;

    IF (p_result = 'PASS' AND p_reject_code IS NOT NULL AND p_reject_code != '') THEN
        RETURN 'ERROR: reject_code must be empty when result = PASS';
    END IF;

    -- attempt_no: count existing attempts at this step for this unit, +1
    SELECT COALESCE(MAX(attempt_no), 0) + 1 INTO :v_attempt_no
    FROM step_event
    WHERE serial_number = :p_serial_number AND step_id = :v_step_id;

    INSERT INTO step_event
        (serial_number, step_id, operator_id, result, reject_code, attempt_no, started_at, ended_at)
    VALUES
        (:p_serial_number, :v_step_id, :p_operator_id, :p_result,
         IFF(:p_reject_code = '', NULL, :p_reject_code),
         :v_attempt_no, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

    RETURN 'OK: inserted attempt ' || v_attempt_no || ' for ' || p_serial_number || ' at ' || p_step_name;
END;
$$;