USE WAREHOUSE SIGMA_LIVE_WH;
USE DATABASE SIGMA_LIVE_MES;
USE SCHEMA PUBLIC;


CREATE VIEW v_fpy_by_step AS
SELECT
    rs.step_id,
    rs.step_name,
    rs.sequence_order,
    COUNT(CASE WHEN se.attempt_no = 1 THEN 1 END) AS first_attempts,
    COUNT(CASE WHEN se.attempt_no = 1 AND se.result = 'PASS' THEN 1 END) AS first_pass,
    ROUND(
        1.0 * COUNT(CASE WHEN se.attempt_no = 1 AND se.result = 'PASS' THEN 1 END)
        / NULLIF(COUNT(CASE WHEN se.attempt_no = 1 THEN 1 END), 0)
    , 4) AS fpy
FROM route_step rs
LEFT JOIN step_event se ON se.step_id = rs.step_id
GROUP BY rs.step_id, rs.step_name, rs.sequence_order;

CREATE VIEW v_cycle_time_by_step AS
SELECT
    rs.step_id,
    rs.step_name,
    rs.target_cycle_min,
    ROUND(AVG(DATEDIFF('minute', se.started_at, se.ended_at)), 2) AS avg_actual_cycle_min,
    ROUND(
        AVG(DATEDIFF('minute', se.started_at, se.ended_at)) - rs.target_cycle_min
    , 2) AS delta_min
FROM route_step rs
LEFT JOIN step_event se ON se.step_id = rs.step_id
GROUP BY rs.step_id, rs.step_name, rs.target_cycle_min;

CREATE VIEW v_wip_by_step AS
SELECT
    rs.step_id,
    rs.step_name,
    COUNT(u.serial_number) AS units_waiting
FROM route_step rs
LEFT JOIN unit u
    ON u.current_step_id = rs.step_id AND u.status = 'IN_PROCESS'
GROUP BY rs.step_id, rs.step_name;

CREATE VIEW v_rejects_by_reason AS
SELECT
    rr.reject_code,
    rr.description,
    rr.category,
    COUNT(se.event_id) AS reject_count
FROM reject_reason rr
LEFT JOIN step_event se ON se.reject_code = rr.reject_code
GROUP BY rr.reject_code, rr.description, rr.category;