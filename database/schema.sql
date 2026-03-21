-- ============================================================
--  SMART CITY COMPLAINT ANALYTICS & DECISION SUPPORT SYSTEM
--  Database Schema — MySQL
--  Fully normalized, with FK relationships, triggers, views
-- ============================================================

CREATE DATABASE IF NOT EXISTS smartcity_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE smartcity_db;

-- ─────────────────────────────────────────────────────────────
--  1. PRIORITIES  (lookup table)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE priorities (
    priority_id    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    priority_name  VARCHAR(20)      NOT NULL,          -- High / Medium / Low
    priority_level TINYINT UNSIGNED NOT NULL,          -- 1=High 2=Medium 3=Low
    sla_hours      SMALLINT UNSIGNED NOT NULL,         -- target resolution hours
    color_code     VARCHAR(7)       NOT NULL DEFAULT '#888888',
    PRIMARY KEY (priority_id),
    UNIQUE KEY uq_priority_name (priority_name)
) ENGINE=InnoDB;

INSERT INTO priorities VALUES
  (1, 'Critical', 1,  4,  '#dc3545'),
  (2, 'High',     2,  24, '#fd7e14'),
  (3, 'Medium',   3,  72, '#ffc107'),
  (4, 'Low',      4, 168, '#28a745');

-- ─────────────────────────────────────────────────────────────
--  2. DEPARTMENTS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE departments (
    dept_id       SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    dept_name     VARCHAR(100)      NOT NULL,
    dept_code     VARCHAR(20)       NOT NULL,
    head_name     VARCHAR(100)      DEFAULT NULL,
    contact_email VARCHAR(150)      DEFAULT NULL,
    contact_phone VARCHAR(20)       DEFAULT NULL,
    is_active     TINYINT(1)        NOT NULL DEFAULT 1,
    created_at    TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (dept_id),
    UNIQUE KEY uq_dept_code (dept_code)
) ENGINE=InnoDB;

INSERT INTO departments (dept_name, dept_code, head_name, contact_email, contact_phone) VALUES
  ('Engineering & Roads',    'ENG',   'Rajesh Kumar',    'eng@smartcity.gov',   '9800001001'),
  ('Sanitation & Waste',     'SAN',   'Priya Mehta',     'san@smartcity.gov',   '9800001002'),
  ('Water & Utilities',      'UTIL',  'Amit Sharma',     'util@smartcity.gov',  '9800001003'),
  ('Electricity Board',      'ELEC',  'Sunita Rao',      'elec@smartcity.gov',  '9800001004'),
  ('Parks & Recreation',     'PARK',  'Vikram Singh',    'park@smartcity.gov',  '9800001005'),
  ('Public Safety',          'SAFE',  'Deepa Nair',      'safe@smartcity.gov',  '9800001006'),
  ('Health & Hygiene',       'HLTH',  'Arun Patel',      'hlth@smartcity.gov',  '9800001007'),
  ('Transport & Traffic',    'TRAF',  'Meena Joshi',     'traf@smartcity.gov',  '9800001008');

-- ─────────────────────────────────────────────────────────────
--  3. CATEGORIES
-- ─────────────────────────────────────────────────────────────
CREATE TABLE categories (
    cat_id          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    cat_name        VARCHAR(100)      NOT NULL,
    cat_description TEXT              DEFAULT NULL,
    dept_id         SMALLINT UNSIGNED NOT NULL,
    default_priority_id TINYINT UNSIGNED NOT NULL DEFAULT 3,
    icon_class      VARCHAR(60)       DEFAULT 'fa-exclamation-circle',
    is_active       TINYINT(1)        NOT NULL DEFAULT 1,
    PRIMARY KEY (cat_id),
    CONSTRAINT fk_cat_dept     FOREIGN KEY (dept_id)            REFERENCES departments (dept_id) ON UPDATE CASCADE,
    CONSTRAINT fk_cat_priority FOREIGN KEY (default_priority_id) REFERENCES priorities  (priority_id)
) ENGINE=InnoDB;

INSERT INTO categories (cat_name, cat_description, dept_id, default_priority_id, icon_class) VALUES
  ('Pothole / Road Damage',     'Damaged roads, potholes, road cave-ins',            1, 2, 'fa-road'),
  ('Broken Footpath',           'Damaged sidewalks or pedestrian paths',             1, 3, 'fa-walking'),
  ('Street Light Not Working',  'Non-functional or damaged street lights',           4, 3, 'fa-lightbulb'),
  ('Garbage Not Collected',     'Uncollected garbage, overflowing bins',             2, 2, 'fa-trash'),
  ('Illegal Dumping',           'Waste dumped in unauthorized areas',                2, 2, 'fa-dumpster'),
  ('Water Supply Issue',        'Water supply disruption or low pressure',           3, 1, 'fa-tint'),
  ('Water Leakage / Pipeline',  'Pipe burst, leakage, or sewage overflow',          3, 1, 'fa-water'),
  ('Electricity Outage',        'Power outage or electrical fault',                 4, 1, 'fa-bolt'),
  ('Illegal Construction',      'Unauthorized building activity',                   1, 2, 'fa-building'),
  ('Park / Green Area Damage',  'Damaged park equipment or encroachment',           5, 3, 'fa-tree'),
  ('Stray Animal Menace',       'Stray dogs or cattle causing public nuisance',     6, 2, 'fa-dog'),
  ('Mosquito / Pest Control',   'Infestation or breeding grounds',                  7, 2, 'fa-bug'),
  ('Traffic Signal Issue',      'Malfunctioning traffic signals or road markings',  8, 1, 'fa-traffic-light'),
  ('Sewage Overflow',           'Blocked or overflowing sewage drain',              3, 1, 'fa-toilet'),
  ('Noise Pollution',           'Excessive noise from construction or events',      6, 3, 'fa-volume-up'),
  ('Air / Water Pollution',     'Industrial or vehicle pollution complaint',        7, 2, 'fa-smog'),
  ('Public Property Damage',    'Vandalised or damaged public infrastructure',      6, 3, 'fa-hammer'),
  ('Other',                     'Miscellaneous city complaint',                     6, 4, 'fa-question-circle');

-- ─────────────────────────────────────────────────────────────
--  4. LOCATIONS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE locations (
    location_id   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    ward_number   VARCHAR(10)   NOT NULL,
    area_name     VARCHAR(150)  NOT NULL,
    zone          VARCHAR(60)   NOT NULL,            -- North / South / East / West / Central
    latitude      DECIMAL(10,7) DEFAULT NULL,
    longitude     DECIMAL(10,7) DEFAULT NULL,
    pincode       VARCHAR(10)   DEFAULT NULL,
    district      VARCHAR(80)   DEFAULT 'City District',
    PRIMARY KEY (location_id),
    KEY idx_ward   (ward_number),
    KEY idx_zone   (zone),
    KEY idx_pincode(pincode)
) ENGINE=InnoDB;

INSERT INTO locations (ward_number, area_name, zone, latitude, longitude, pincode) VALUES
  ('W01','Koregaon Park',    'East',    18.5362, 73.8938, '411001'),
  ('W02','Kothrud',          'West',    18.5074, 73.8077, '411038'),
  ('W03','Hadapsar',         'East',    18.5018, 73.9263, '411028'),
  ('W04','Aundh',            'North',   18.5590, 73.8075, '411007'),
  ('W05','Shivajinagar',     'Central', 18.5308, 73.8474, '411005'),
  ('W06','Pimpri',           'North',   18.6270, 73.7956, '411018'),
  ('W07','Chinchwad',        'North',   18.6453, 73.7834, '411019'),
  ('W08','Yerawada',         'East',    18.5547, 73.9006, '411006'),
  ('W09','Bibwewadi',        'South',   18.4743, 73.8561, '411037'),
  ('W10','Katraj',           'South',   18.4530, 73.8671, '411046'),
  ('W11','Warje',            'West',    18.4894, 73.7945, '411058'),
  ('W12','Baner',            'West',    18.5590, 73.7868, '411045'),
  ('W13','Viman Nagar',      'East',    18.5679, 73.9143, '411014'),
  ('W14','Kharadi',          'East',    18.5517, 73.9414, '411014'),
  ('W15','Deccan Gymkhana',  'Central', 18.5196, 73.8439, '411004'),
  ('W16','Swargate',         'Central', 18.5018, 73.8573, '411042'),
  ('W17','Magarpatta',       'South',   18.5127, 73.9286, '411028'),
  ('W18','Hinjewadi',        'West',    18.5912, 73.7389, '411057'),
  ('W19','Wakad',            'West',    18.5990, 73.7667, '411057'),
  ('W20','Pimple Saudagar',  'North',   18.6019, 73.7995, '411027');

-- ─────────────────────────────────────────────────────────────
--  5. USERS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE users (
    user_id       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    full_name     VARCHAR(150)  NOT NULL,
    email         VARCHAR(200)  NOT NULL,
    phone         VARCHAR(20)   DEFAULT NULL,
    password_hash VARCHAR(255)  NOT NULL,
    role          ENUM('citizen','admin','officer') NOT NULL DEFAULT 'citizen',
    dept_id       SMALLINT UNSIGNED DEFAULT NULL,   -- for officers
    location_id   INT UNSIGNED  DEFAULT NULL,       -- home area
    is_verified   TINYINT(1)    NOT NULL DEFAULT 0,
    is_active     TINYINT(1)    NOT NULL DEFAULT 1,
    profile_pic   VARCHAR(255)  DEFAULT NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login    TIMESTAMP     NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_user_email (email),
    CONSTRAINT fk_user_dept     FOREIGN KEY (dept_id)     REFERENCES departments (dept_id) ON DELETE SET NULL,
    CONSTRAINT fk_user_location FOREIGN KEY (location_id) REFERENCES locations   (location_id) ON DELETE SET NULL,
    KEY idx_user_role (role),
    KEY idx_user_active (is_active)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
--  6. COMPLAINTS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE complaints (
    complaint_id     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    complaint_code   VARCHAR(20)   NOT NULL,          -- e.g. CMP-2024-00001
    user_id          INT UNSIGNED  NOT NULL,
    cat_id           SMALLINT UNSIGNED NOT NULL,
    location_id      INT UNSIGNED  NOT NULL,
    dept_id          SMALLINT UNSIGNED NOT NULL,       -- auto-routed
    priority_id      TINYINT UNSIGNED NOT NULL,        -- auto-assigned
    title            VARCHAR(300)  NOT NULL,
    description      TEXT          NOT NULL,
    address_detail   VARCHAR(500)  DEFAULT NULL,       -- specific street/landmark
    latitude         DECIMAL(10,7) DEFAULT NULL,
    longitude        DECIMAL(10,7) DEFAULT NULL,
    image_path       VARCHAR(255)  DEFAULT NULL,
    status           ENUM('pending','assigned','in_progress','resolved','closed','rejected')
                     NOT NULL DEFAULT 'pending',
    assigned_to      INT UNSIGNED  DEFAULT NULL,       -- officer user_id
    submitted_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_at      TIMESTAMP     NULL,
    resolved_at      TIMESTAMP     NULL,
    closed_at        TIMESTAMP     NULL,
    resolution_hours DECIMAL(8,2)  GENERATED ALWAYS AS (
                       TIMESTAMPDIFF(MINUTE, submitted_at, resolved_at) / 60.0
                     ) STORED,
    is_hotspot_flag  TINYINT(1)    NOT NULL DEFAULT 0,
    upvotes          SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    views            INT UNSIGNED  NOT NULL DEFAULT 0,
    PRIMARY KEY (complaint_id),
    UNIQUE KEY uq_complaint_code (complaint_code),
    CONSTRAINT fk_comp_user     FOREIGN KEY (user_id)     REFERENCES users       (user_id),
    CONSTRAINT fk_comp_cat      FOREIGN KEY (cat_id)      REFERENCES categories  (cat_id),
    CONSTRAINT fk_comp_location FOREIGN KEY (location_id) REFERENCES locations   (location_id),
    CONSTRAINT fk_comp_dept     FOREIGN KEY (dept_id)     REFERENCES departments (dept_id),
    CONSTRAINT fk_comp_priority FOREIGN KEY (priority_id) REFERENCES priorities  (priority_id),
    CONSTRAINT fk_comp_officer  FOREIGN KEY (assigned_to) REFERENCES users       (user_id) ON DELETE SET NULL,
    KEY idx_comp_status   (status),
    KEY idx_comp_date     (submitted_at),
    KEY idx_comp_location (location_id),
    KEY idx_comp_cat      (cat_id),
    KEY idx_comp_priority (priority_id),
    KEY idx_comp_dept     (dept_id),
    KEY idx_comp_hotspot  (is_hotspot_flag)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
--  7. STATUS UPDATES  (audit trail of every status change)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE status_updates (
    update_id    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    complaint_id INT UNSIGNED  NOT NULL,
    updated_by   INT UNSIGNED  NOT NULL,
    old_status   VARCHAR(20)   NOT NULL,
    new_status   VARCHAR(20)   NOT NULL,
    remarks      TEXT          DEFAULT NULL,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (update_id),
    CONSTRAINT fk_su_complaint FOREIGN KEY (complaint_id) REFERENCES complaints (complaint_id) ON DELETE CASCADE,
    CONSTRAINT fk_su_user      FOREIGN KEY (updated_by)   REFERENCES users      (user_id),
    KEY idx_su_complaint (complaint_id),
    KEY idx_su_date      (updated_at)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
--  8. FEEDBACK
-- ─────────────────────────────────────────────────────────────
CREATE TABLE feedback (
    feedback_id    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    complaint_id   INT UNSIGNED  NOT NULL,
    user_id        INT UNSIGNED  NOT NULL,
    rating         TINYINT UNSIGNED NOT NULL,          -- 1–5
    comment        TEXT          DEFAULT NULL,
    is_satisfied   TINYINT(1)    NOT NULL DEFAULT 1,
    submitted_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (feedback_id),
    UNIQUE KEY uq_feedback_complaint (complaint_id),   -- one per complaint
    CONSTRAINT fk_fb_complaint FOREIGN KEY (complaint_id) REFERENCES complaints (complaint_id) ON DELETE CASCADE,
    CONSTRAINT fk_fb_user      FOREIGN KEY (user_id)      REFERENCES users      (user_id),
    CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5),
    KEY idx_fb_rating (rating)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
--  9. ANALYTICS LOGS  (auto-populated by triggers/procedures)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE analytics_logs (
    log_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    log_type     VARCHAR(50)  NOT NULL,    -- hotspot_detected / priority_changed / sla_breached
    entity_type  VARCHAR(30)  NOT NULL,    -- complaint / location / department
    entity_id    INT UNSIGNED DEFAULT NULL,
    message      VARCHAR(500) NOT NULL,
    meta_json    JSON         DEFAULT NULL,
    logged_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    KEY idx_al_type   (log_type),
    KEY idx_al_entity (entity_type, entity_id),
    KEY idx_al_date   (logged_at)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
--  EMAIL NOTIFICATION SYSTEM
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS email_templates (
    template_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    template_key      VARCHAR(80)     NOT NULL,
    subject_template  VARCHAR(255)    NOT NULL,
    html_template     LONGTEXT        NOT NULL,
    is_active         TINYINT(1)      NOT NULL DEFAULT 1,
    created_at        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP       NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (template_id),
    UNIQUE KEY uq_email_template_key (template_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_email_preferences (
    user_id             INT UNSIGNED  NOT NULL,
    preferred_email     VARCHAR(200)  DEFAULT NULL,
    preferred_hour      TINYINT UNSIGNED NOT NULL DEFAULT 9,
    frequency           ENUM('instant','batched','daily_digest') NOT NULL DEFAULT 'instant',
    quiet_hours_enabled TINYINT(1)    NOT NULL DEFAULT 1,
    quiet_start_hour    TINYINT UNSIGNED NOT NULL DEFAULT 22,
    quiet_end_hour      TINYINT UNSIGNED NOT NULL DEFAULT 7,
    critical_override   TINYINT(1)    NOT NULL DEFAULT 1,
    opted_out           TINYINT(1)    NOT NULL DEFAULT 0,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP     NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_uep_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    KEY idx_uep_opted_out (opted_out)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS email_queue (
    queue_id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id            INT UNSIGNED  NOT NULL,
    complaint_id       INT UNSIGNED  NOT NULL,
    template_key       VARCHAR(80)   NOT NULL,
    priority           ENUM('critical','high','normal','low') NOT NULL DEFAULT 'normal',
    status             ENUM('queued','processing','sent','failed','cancelled') NOT NULL DEFAULT 'queued',
    scheduled_at       DATETIME      NOT NULL,
    attempts           TINYINT UNSIGNED NOT NULL DEFAULT 0,
    max_attempts       TINYINT UNSIGNED NOT NULL DEFAULT 5,
    payload_json       JSON          DEFAULT NULL,
    idempotency_key    VARCHAR(140)  DEFAULT NULL,
    last_error         VARCHAR(500)  DEFAULT NULL,
    sent_at            DATETIME      DEFAULT NULL,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (queue_id),
    UNIQUE KEY uq_email_queue_idempotency (idempotency_key),
    CONSTRAINT fk_eq_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_eq_complaint FOREIGN KEY (complaint_id) REFERENCES complaints(complaint_id) ON DELETE CASCADE,
    KEY idx_eq_status_scheduled (status, scheduled_at),
    KEY idx_eq_user_created (user_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS email_logs (
    email_log_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    queue_id           BIGINT UNSIGNED NOT NULL,
    user_id            INT UNSIGNED NOT NULL,
    complaint_id       INT UNSIGNED NOT NULL,
    template_key       VARCHAR(80)  NOT NULL,
    recipient_email    VARCHAR(200) NOT NULL,
    subject_rendered   VARCHAR(255) NOT NULL,
    delivery_status    ENUM('sent','failed','opened','clicked','bounced') NOT NULL,
    event_at           DATETIME     NOT NULL,
    metadata_json      JSON         DEFAULT NULL,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (email_log_id),
    CONSTRAINT fk_el_queue FOREIGN KEY (queue_id) REFERENCES email_queue(queue_id) ON DELETE CASCADE,
    CONSTRAINT fk_el_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_el_complaint FOREIGN KEY (complaint_id) REFERENCES complaints(complaint_id) ON DELETE CASCADE,
    KEY idx_el_user_event (user_id, event_at),
    KEY idx_el_complaint (complaint_id)
) ENGINE=InnoDB;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS email_verified TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_email_sent DATETIME NULL;

-- ─────────────────────────────────────────────────────────────
--  10. CRIME TYPES
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS crime_types (
    crime_type_id  SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    type_name      VARCHAR(120)      NOT NULL,
    type_code      VARCHAR(30)       NOT NULL,
    severity       ENUM('low','moderate','high','critical') NOT NULL DEFAULT 'moderate',
    icon           VARCHAR(10)       DEFAULT '⚠️',
    color_hex      VARCHAR(7)        NOT NULL DEFAULT '#ff3d5a',
    ipc_section    VARCHAR(80)       DEFAULT NULL,
    is_active      TINYINT(1)        NOT NULL DEFAULT 1,
    PRIMARY KEY (crime_type_id),
    UNIQUE KEY uq_crime_type_code (type_code),
    KEY idx_crime_type_active (is_active)
) ENGINE=InnoDB;

INSERT IGNORE INTO crime_types (crime_type_id, type_name, type_code, severity, icon, color_hex, ipc_section) VALUES
  (1, 'Theft / Robbery',      'THEFT',    'high',     '🎭', '#ff3d5a', 'IPC 378'),
  (2, 'Vehicle Theft',        'VEH',      'moderate', '🚗', '#ff6b35', 'IPC 379'),
  (3, 'Assault',              'ASSAULT',  'high',     '👊', '#ef4444', 'IPC 351'),
  (4, 'Chain Snatching',      'SNATCH',   'high',     '⛓️', '#f97316', 'IPC 379'),
  (5, 'House Break-In',       'BURGLARY', 'critical', '🏠', '#dc2626', 'IPC 454'),
  (6, 'Cybercrime / Fraud',   'FRAUD',    'high',     '💻', '#8b5cf6', 'IT Act 66C'),
  (7, 'Drug Trafficking',     'DRUGS',    'critical', '💊', '#b91c1c', 'NDPS Act'),
  (8, 'Domestic Violence',    'DOM_VIO',  'critical', '⚠️', '#e11d48', 'DV Act'),
  (9, 'Harassment',           'HARASS',   'high',     '🚨', '#f43f5e', 'IPC 354'),
  (10,'Traffic Accident',     'TRAFFIC',  'moderate', '🚦', '#f59e0b', 'MV Act');

-- ─────────────────────────────────────────────────────────────
--  11. CRIME INCIDENTS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS crime_incidents (
    incident_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    incident_code    VARCHAR(25)  NOT NULL,
    user_id          INT UNSIGNED NOT NULL,
    crime_type_id    SMALLINT UNSIGNED NOT NULL,
    location_id      INT UNSIGNED NOT NULL,
    incident_date    DATE         NOT NULL,
    incident_time    TIME         DEFAULT NULL,
    time_of_day      ENUM('morning','afternoon','evening','night','unknown') NOT NULL DEFAULT 'unknown',
    description      TEXT         NOT NULL,
    address_detail   VARCHAR(500) DEFAULT NULL,
    latitude         DECIMAL(10,7) DEFAULT NULL,
    longitude        DECIMAL(10,7) DEFAULT NULL,
    victim_count     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    status           ENUM('reported','fir_filed','under_investigation','chargesheet','resolved') NOT NULL DEFAULT 'reported',
    fir_number       VARCHAR(60)  DEFAULT NULL,
    assigned_station VARCHAR(150) DEFAULT NULL,
    is_hotspot_flag  TINYINT(1)   NOT NULL DEFAULT 0,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (incident_id),
    UNIQUE KEY uq_incident_code (incident_code),
    CONSTRAINT fk_crime_user      FOREIGN KEY (user_id)       REFERENCES users(user_id),
    CONSTRAINT fk_crime_type      FOREIGN KEY (crime_type_id) REFERENCES crime_types(crime_type_id),
    CONSTRAINT fk_crime_location  FOREIGN KEY (location_id)   REFERENCES locations(location_id),
    KEY idx_crime_date (incident_date),
    KEY idx_crime_type (crime_type_id),
    KEY idx_crime_location (location_id),
    KEY idx_crime_status (status),
    KEY idx_crime_hotspot (is_hotspot_flag)
) ENGINE=InnoDB;

-- ═══════════════════════════════════════════════════════════
--  TRIGGERS
-- ═══════════════════════════════════════════════════════════

DELIMITER $$

-- Auto-generate complaint code on insert
CREATE TRIGGER trg_complaint_code
BEFORE INSERT ON complaints
FOR EACH ROW
BEGIN
    DECLARE next_seq INT;
    SELECT COUNT(*) + 1 INTO next_seq FROM complaints;
    SET NEW.complaint_code = CONCAT('CMP-', YEAR(NOW()), '-', LPAD(next_seq, 5, '0'));
END$$

CREATE TRIGGER trg_crime_code
BEFORE INSERT ON crime_incidents
FOR EACH ROW
BEGIN
    DECLARE next_seq INT;
    IF NEW.incident_code IS NULL OR NEW.incident_code = '' OR NEW.incident_code LIKE 'CRM-TEMP-%' THEN
        SELECT COUNT(*) + 1 INTO next_seq FROM crime_incidents;
        SET NEW.incident_code = CONCAT('CRM-', YEAR(NOW()), '-', LPAD(next_seq, 5, '0'));
    END IF;
END$$

-- Log every status change into status_updates
CREATE TRIGGER trg_status_change
AFTER UPDATE ON complaints
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO status_updates (complaint_id, updated_by, old_status, new_status, remarks)
        VALUES (NEW.complaint_id,
                IFNULL(NEW.assigned_to, NEW.user_id),
                OLD.status, NEW.status,
                CONCAT('Status changed from ', OLD.status, ' to ', NEW.status));
    END IF;
END$$

-- Flag SLA breach when complaint is updated but still not resolved
CREATE TRIGGER trg_sla_check
AFTER UPDATE ON complaints
FOR EACH ROW
BEGIN
    DECLARE sla_hrs SMALLINT;
    SELECT sla_hours INTO sla_hrs FROM priorities WHERE priority_id = NEW.priority_id;
    IF NEW.status NOT IN ('resolved','closed') AND
       TIMESTAMPDIFF(HOUR, NEW.submitted_at, NOW()) > sla_hrs THEN
        INSERT INTO analytics_logs (log_type, entity_type, entity_id, message, meta_json)
        VALUES ('sla_breached', 'complaint', NEW.complaint_id,
                CONCAT('SLA breached for complaint ', NEW.complaint_code),
                JSON_OBJECT('sla_hours', sla_hrs,
                            'elapsed_hours', TIMESTAMPDIFF(HOUR, NEW.submitted_at, NOW())));
    END IF;
END$$

DELIMITER ;

-- ═══════════════════════════════════════════════════════════
--  STORED PROCEDURES
-- ═══════════════════════════════════════════════════════════

DELIMITER $$

-- Auto-assign priority based on category default + frequency boost
CREATE PROCEDURE sp_auto_assign_priority(IN p_complaint_id INT, IN p_cat_id SMALLINT, IN p_location_id INT)
BEGIN
    DECLARE base_priority TINYINT;
    DECLARE freq_30days   INT;
    DECLARE final_priority TINYINT;

    -- Get category's default priority
    SELECT default_priority_id INTO base_priority
    FROM categories WHERE cat_id = p_cat_id;

    -- Count complaints in same location + category in last 30 days
    SELECT COUNT(*) INTO freq_30days
    FROM complaints
    WHERE cat_id = p_cat_id
      AND location_id = p_location_id
      AND submitted_at >= NOW() - INTERVAL 30 DAY
      AND complaint_id <> p_complaint_id;

    -- Boost priority if frequency is high
    SET final_priority = CASE
        WHEN freq_30days >= 10 THEN 1   -- Critical
        WHEN freq_30days >= 5  THEN GREATEST(1, base_priority - 1)  -- Bump up
        WHEN freq_30days >= 2  THEN base_priority
        ELSE LEAST(4, base_priority + 1)  -- Low freq = drop one level
    END;

    UPDATE complaints SET priority_id = final_priority WHERE complaint_id = p_complaint_id;

    -- Log the action
    INSERT INTO analytics_logs (log_type, entity_type, entity_id, message, meta_json)
    VALUES ('priority_assigned', 'complaint', p_complaint_id,
            CONCAT('Auto priority assigned: level ', final_priority),
            JSON_OBJECT('base_priority', base_priority, 'frequency_30d', freq_30days, 'final_priority', final_priority));
END$$

-- Hotspot detection: flag locations with >15 complaints in 30 days
CREATE PROCEDURE sp_detect_hotspots()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE loc_id INT;
    DECLARE comp_count INT;

    DECLARE hotspot_cursor CURSOR FOR
        SELECT location_id, COUNT(*) AS cnt
        FROM complaints
        WHERE submitted_at >= NOW() - INTERVAL 30 DAY
          AND status NOT IN ('closed','rejected')
        GROUP BY location_id
        HAVING cnt >= 15;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN hotspot_cursor;
    read_loop: LOOP
        FETCH hotspot_cursor INTO loc_id, comp_count;
        IF done THEN LEAVE read_loop; END IF;

        -- Flag complaints in this hotspot location
        UPDATE complaints
        SET is_hotspot_flag = 1
        WHERE location_id = loc_id
          AND submitted_at >= NOW() - INTERVAL 30 DAY
          AND status NOT IN ('closed','rejected');

        -- Log it
        INSERT INTO analytics_logs (log_type, entity_type, entity_id, message, meta_json)
        VALUES ('hotspot_detected', 'location', loc_id,
                CONCAT('Hotspot detected: ', comp_count, ' complaints in 30 days'),
                JSON_OBJECT('complaint_count', comp_count, 'window_days', 30));
    END LOOP;
    CLOSE hotspot_cursor;
END$$

-- Department routing based on category
CREATE PROCEDURE sp_route_to_department(IN p_complaint_id INT, IN p_cat_id SMALLINT)
BEGIN
    DECLARE routed_dept SMALLINT;
    SELECT dept_id INTO routed_dept FROM categories WHERE cat_id = p_cat_id;
    UPDATE complaints SET dept_id = routed_dept WHERE complaint_id = p_complaint_id;
END$$

DELIMITER ;

-- ═══════════════════════════════════════════════════════════
--  VIEWS  (pre-built for analytics queries)
-- ═══════════════════════════════════════════════════════════

-- Full complaint detail view
CREATE OR REPLACE VIEW vw_complaint_detail AS
SELECT
    c.complaint_id,
    c.complaint_code,
    c.title,
    c.description,
    c.status,
    c.submitted_at,
    c.resolved_at,
    c.resolution_hours,
    c.is_hotspot_flag,
    c.upvotes,
    u.full_name         AS citizen_name,
    u.email             AS citizen_email,
    cat.cat_name        AS category,
    cat.icon_class,
    l.area_name,
    l.ward_number,
    l.zone,
    d.dept_name         AS department,
    d.dept_code,
    p.priority_name,
    p.priority_level,
    p.color_code        AS priority_color,
    p.sla_hours,
    CASE
        WHEN c.status NOT IN ('resolved','closed')
             AND TIMESTAMPDIFF(HOUR, c.submitted_at, NOW()) > p.sla_hours
        THEN 1 ELSE 0
    END                 AS is_sla_breached,
    TIMESTAMPDIFF(HOUR, c.submitted_at, NOW()) AS age_hours
FROM complaints c
JOIN users       u   ON c.user_id     = u.user_id
JOIN categories  cat ON c.cat_id      = cat.cat_id
JOIN locations   l   ON c.location_id = l.location_id
JOIN departments d   ON c.dept_id     = d.dept_id
JOIN priorities  p   ON c.priority_id = p.priority_id;

-- Location hotspot view
CREATE OR REPLACE VIEW vw_location_hotspot AS
SELECT
    l.location_id,
    l.ward_number,
    l.area_name,
    l.zone,
    l.latitude,
    l.longitude,
    COUNT(c.complaint_id)                                         AS total_complaints,
    SUM(CASE WHEN c.status = 'pending'    THEN 1 ELSE 0 END)     AS pending_count,
    SUM(CASE WHEN c.status = 'resolved'   THEN 1 ELSE 0 END)     AS resolved_count,
    ROUND(AVG(c.resolution_hours), 2)                             AS avg_resolution_hours,
    SUM(CASE WHEN c.submitted_at >= NOW() - INTERVAL 30 DAY
             THEN 1 ELSE 0 END)                                   AS complaints_last_30d,
    CASE WHEN SUM(CASE WHEN c.submitted_at >= NOW() - INTERVAL 30 DAY
                       THEN 1 ELSE 0 END) >= 15
         THEN 1 ELSE 0 END                                        AS is_hotspot
FROM locations l
LEFT JOIN complaints c ON l.location_id = c.location_id
GROUP BY l.location_id, l.ward_number, l.area_name, l.zone, l.latitude, l.longitude;

-- Department performance view
CREATE OR REPLACE VIEW vw_dept_performance AS
SELECT
    d.dept_id,
    d.dept_name,
    d.dept_code,
    COUNT(c.complaint_id)                                          AS total_assigned,
    SUM(CASE WHEN c.status IN ('resolved','closed') THEN 1 ELSE 0 END) AS resolved_count,
    SUM(CASE WHEN c.status = 'pending'              THEN 1 ELSE 0 END) AS pending_count,
    SUM(CASE WHEN c.status = 'in_progress'          THEN 1 ELSE 0 END) AS in_progress_count,
    ROUND(AVG(CASE WHEN c.status IN ('resolved','closed')
                   THEN c.resolution_hours END), 2)                AS avg_resolution_hours,
    ROUND(
        SUM(CASE WHEN c.status IN ('resolved','closed') THEN 1 ELSE 0 END)
        / NULLIF(COUNT(c.complaint_id), 0) * 100, 1)               AS resolution_rate_pct
FROM departments d
LEFT JOIN complaints c ON d.dept_id = c.dept_id
GROUP BY d.dept_id, d.dept_name, d.dept_code;

-- Monthly trend view
CREATE OR REPLACE VIEW vw_monthly_trend AS
SELECT
    DATE_FORMAT(submitted_at, '%Y-%m')                            AS month,
    COUNT(*)                                                       AS total_complaints,
    SUM(CASE WHEN status IN ('resolved','closed') THEN 1 ELSE 0 END) AS resolved,
    SUM(CASE WHEN status = 'pending'              THEN 1 ELSE 0 END) AS pending,
    ROUND(AVG(resolution_hours), 2)                               AS avg_resolution_hours
FROM complaints
GROUP BY DATE_FORMAT(submitted_at, '%Y-%m')
ORDER BY month;

-- ═══════════════════════════════════════════════════════════
--  INDEXES for analytics performance
-- ═══════════════════════════════════════════════════════════
CREATE INDEX idx_comp_submitted_month ON complaints ((MONTH(submitted_at)), (YEAR(submitted_at)));
CREATE INDEX idx_comp_resolved        ON complaints (resolved_at);
CREATE INDEX idx_comp_location_cat    ON complaints (location_id, cat_id);
CREATE INDEX idx_comp_dept_status     ON complaints (dept_id, status);
