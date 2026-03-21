-- ============================================================
--  EXTENSION: Crime Incidents Module
--  Add this to your existing smartcity_db
--  Run AFTER schema.sql and seed_data.sql
-- ============================================================

USE smartcity_db;

-- ─────────────────────────────────────────────────────────────
--  CRIME TYPES (lookup table)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS crime_types (
    crime_type_id   TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    type_name       VARCHAR(80)      NOT NULL,
    type_code       VARCHAR(20)      NOT NULL,
    severity        ENUM('low','moderate','high','critical') NOT NULL DEFAULT 'moderate',
    icon            VARCHAR(60)      DEFAULT 'fa-exclamation-triangle',
    color_hex       VARCHAR(7)       DEFAULT '#ff6b6b',
    ipc_section     VARCHAR(100)     DEFAULT NULL,   -- Indian Penal Code section
    PRIMARY KEY (crime_type_id),
    UNIQUE KEY uq_crime_code (type_code)
) ENGINE=InnoDB;

INSERT INTO crime_types (type_name, type_code, severity, icon, color_hex, ipc_section) VALUES
  ('Theft / Robbery',           'THEFT',     'high',     'fa-mask',                '#ff6b6b', 'IPC 378-382'),
  ('Vehicle Theft',             'VEH_THEFT', 'moderate', 'fa-car',                 '#ffa94d', 'IPC 378'),
  ('Chain Snatching',           'SNATCH',    'high',     'fa-link',                '#ff6b6b', 'IPC 356'),
  ('House Break-In',            'BURGLARY',  'critical', 'fa-house-crack',         '#ff4757', 'IPC 445-446'),
  ('Assault / Physical Fight',  'ASSAULT',   'high',     'fa-hand-fist',           '#ff6b6b', 'IPC 351-358'),
  ('Eve Teasing / Harassment',  'HARASS',    'high',     'fa-person-circle-exclamation','#ff6b6b','IPC 354'),
  ('Drunk & Disorderly',        'DRUNK',     'low',      'fa-wine-bottle',         '#ffd43b', 'IPC 510'),
  ('Drug Trafficking',          'DRUGS',     'critical', 'fa-pills',               '#ff4757', 'NDPS Act'),
  ('Vandalism / Property Damage','VANDAL',   'moderate', 'fa-hammer',              '#ffa94d', 'IPC 427'),
  ('Traffic Violation / Accident','TRAFFIC', 'moderate', 'fa-car-burst',           '#ffa94d', 'MV Act'),
  ('Fraud / Cybercrime',        'FRAUD',     'high',     'fa-laptop-code',         '#ff6b6b', 'IPC 420/IT Act'),
  ('Missing Person',            'MISSING',   'high',     'fa-person-circle-question','#ffd43b','CRPC 154'),
  ('Domestic Violence',         'DOM_VIO',   'critical', 'fa-house-chimney-crack', '#ff4757', 'IPC 498A'),
  ('Public Nuisance',           'PUB_NUIS',  'low',      'fa-volume-high',         '#69db7c', 'IPC 268'),
  ('Illegal Weapon Possession', 'WEAPONS',   'critical', 'fa-gun',                 '#ff4757', 'Arms Act');


-- ─────────────────────────────────────────────────────────────
--  CRIME INCIDENTS  (main table)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS crime_incidents (
    incident_id       INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    incident_code     VARCHAR(25)     NOT NULL,        -- e.g. CRM-2024-00001
    crime_type_id     TINYINT UNSIGNED NOT NULL,
    location_id       INT UNSIGNED    NOT NULL,        -- FK to locations
    address_detail    VARCHAR(500)    DEFAULT NULL,
    latitude          DECIMAL(10,7)   NOT NULL,
    longitude         DECIMAL(10,7)   NOT NULL,
    incident_date     DATE            NOT NULL,
    incident_time     TIME            DEFAULT NULL,
    time_of_day       ENUM('dawn','morning','afternoon','evening','night','unknown')
                      GENERATED ALWAYS AS (
                        CASE
                          WHEN incident_time BETWEEN '04:00:00' AND '07:59:59' THEN 'dawn'
                          WHEN incident_time BETWEEN '08:00:00' AND '11:59:59' THEN 'morning'
                          WHEN incident_time BETWEEN '12:00:00' AND '16:59:59' THEN 'afternoon'
                          WHEN incident_time BETWEEN '17:00:00' AND '20:59:59' THEN 'evening'
                          WHEN incident_time BETWEEN '21:00:00' AND '23:59:59' THEN 'night'
                          WHEN incident_time BETWEEN '00:00:00' AND '03:59:59' THEN 'night'
                          ELSE 'unknown'
                        END
                      ) STORED,
    description       TEXT            DEFAULT NULL,
    victim_count      TINYINT UNSIGNED NOT NULL DEFAULT 1,
    status            ENUM('reported','under_investigation','fir_filed','chargesheet','resolved','closed')
                      NOT NULL DEFAULT 'reported',
    reporting_source  ENUM('police','citizen','anonymous','cctv','patrol') NOT NULL DEFAULT 'citizen',
    fir_number        VARCHAR(50)     DEFAULT NULL,
    assigned_station  VARCHAR(150)    DEFAULT NULL,    -- Police station name
    is_verified       TINYINT(1)      NOT NULL DEFAULT 0,
    is_hotspot_flag   TINYINT(1)      NOT NULL DEFAULT 0,
    reported_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at       TIMESTAMP       NULL,
    PRIMARY KEY (incident_id),
    UNIQUE KEY uq_incident_code (incident_code),
    CONSTRAINT fk_crime_type     FOREIGN KEY (crime_type_id) REFERENCES crime_types (crime_type_id),
    CONSTRAINT fk_crime_location FOREIGN KEY (location_id)   REFERENCES locations   (location_id),
    KEY idx_crime_date     (incident_date),
    KEY idx_crime_location (location_id),
    KEY idx_crime_type     (crime_type_id),
    KEY idx_crime_status   (status),
    KEY idx_crime_hotspot  (is_hotspot_flag),
    KEY idx_crime_tod      (time_of_day)
) ENGINE=InnoDB;


-- ─────────────────────────────────────────────────────────────
--  SAFETY SCORE per location (materialized view style table)
--  Updated by trigger/procedure
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS location_safety_scores (
    location_id         INT UNSIGNED    NOT NULL,
    safety_score        DECIMAL(5,2)    NOT NULL DEFAULT 50.00,  -- 0-100, higher = safer
    crime_count_30d     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    complaint_count_30d SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    critical_crimes_30d SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    risk_level          ENUM('very_low','low','moderate','high','critical') NOT NULL DEFAULT 'moderate',
    last_updated        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (location_id),
    CONSTRAINT fk_lss_location FOREIGN KEY (location_id) REFERENCES locations (location_id)
) ENGINE=InnoDB;


-- ─────────────────────────────────────────────────────────────
--  STORED PROCEDURE: Calculate Safety Score
-- ─────────────────────────────────────────────────────────────
DELIMITER $$

CREATE PROCEDURE sp_calculate_safety_scores()
BEGIN
    -- Delete and recalculate all scores
    DELETE FROM location_safety_scores;

    INSERT INTO location_safety_scores
      (location_id, crime_count_30d, complaint_count_30d, critical_crimes_30d, safety_score, risk_level)
    SELECT
        l.location_id,

        -- Crime count in last 30 days
        COALESCE((
            SELECT COUNT(*) FROM crime_incidents ci
            WHERE ci.location_id = l.location_id
              AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY
        ), 0) AS crime_count_30d,

        -- Complaint count in last 30 days
        COALESCE((
            SELECT COUNT(*) FROM complaints c
            WHERE c.location_id = l.location_id
              AND c.submitted_at >= NOW() - INTERVAL 30 DAY
        ), 0) AS complaint_count_30d,

        -- Critical crimes (severity = critical/high)
        COALESCE((
            SELECT COUNT(*) FROM crime_incidents ci
            JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
            WHERE ci.location_id = l.location_id
              AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY
              AND ct.severity IN ('critical','high')
        ), 0) AS critical_crimes_30d,

        -- Safety score: 100 = perfect, deduct for crimes & complaints
        GREATEST(0, LEAST(100,
            100
            - (COALESCE((SELECT COUNT(*) FROM crime_incidents ci
                         WHERE ci.location_id = l.location_id
                           AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY), 0) * 4)
            - (COALESCE((SELECT COUNT(*) FROM crime_incidents ci
                         JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
                         WHERE ci.location_id = l.location_id
                           AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY
                           AND ct.severity IN ('critical','high')), 0) * 3)
            - (COALESCE((SELECT COUNT(*) FROM complaints c
                         WHERE c.location_id = l.location_id
                           AND c.submitted_at >= NOW() - INTERVAL 30 DAY), 0) * 0.5)
        )) AS safety_score,

        -- Risk level
        CASE
            WHEN GREATEST(0, 100
                - (COALESCE((SELECT COUNT(*) FROM crime_incidents ci WHERE ci.location_id = l.location_id AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY),0)*4)
                - (COALESCE((SELECT COUNT(*) FROM complaints c WHERE c.location_id = l.location_id AND c.submitted_at >= NOW() - INTERVAL 30 DAY),0)*0.5)
            ) >= 80 THEN 'very_low'
            WHEN GREATEST(0, 100
                - (COALESCE((SELECT COUNT(*) FROM crime_incidents ci WHERE ci.location_id = l.location_id AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY),0)*4)
            ) >= 60 THEN 'low'
            WHEN GREATEST(0, 100
                - (COALESCE((SELECT COUNT(*) FROM crime_incidents ci WHERE ci.location_id = l.location_id AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY),0)*4)
            ) >= 40 THEN 'moderate'
            WHEN GREATEST(0, 100
                - (COALESCE((SELECT COUNT(*) FROM crime_incidents ci WHERE ci.location_id = l.location_id AND ci.incident_date >= CURDATE() - INTERVAL 30 DAY),0)*4)
            ) >= 20 THEN 'high'
            ELSE 'critical'
        END AS risk_level

    FROM locations l;
END$$

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
--  VIEW: Combined Crime + Complaint Map Data
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_map_incidents AS
-- Complaints
SELECT
    'complaint'                    AS incident_type,
    c.complaint_id                 AS incident_id,
    c.complaint_code               AS code,
    c.title                        AS title,
    cat.cat_name                   AS sub_type,
    cat.icon_class                 AS icon,
    p.color_code                   AS color,
    p.priority_name                AS severity,
    l.latitude                     AS lat,
    l.longitude                    AS lng,
    l.area_name,
    l.ward_number,
    c.status,
    c.submitted_at                 AS event_time,
    c.is_hotspot_flag
FROM complaints c
JOIN categories cat ON c.cat_id      = cat.cat_id
JOIN locations  l   ON c.location_id = l.location_id
JOIN priorities p   ON c.priority_id = p.priority_id
WHERE l.latitude IS NOT NULL

UNION ALL

-- Crime incidents
SELECT
    'crime'                        AS incident_type,
    ci.incident_id,
    ci.incident_code               AS code,
    ct.type_name                   AS title,
    ct.type_code                   AS sub_type,
    ct.icon                        AS icon,
    ct.color_hex                   AS color,
    ct.severity,
    ci.latitude                    AS lat,
    ci.longitude                   AS lng,
    l.area_name,
    l.ward_number,
    ci.status,
    CAST(ci.incident_date AS DATETIME) AS event_time,
    ci.is_hotspot_flag
FROM crime_incidents ci
JOIN crime_types ct  ON ci.crime_type_id = ct.crime_type_id
JOIN locations   l   ON ci.location_id   = l.location_id;


-- ─────────────────────────────────────────────────────────────
--  CRIME ANALYTICS QUERIES (for reference)
-- ─────────────────────────────────────────────────────────────
-- Q1: Crime hotspot locations (30 days)
-- SELECT l.area_name, l.ward_number, COUNT(*) AS crime_count
-- FROM crime_incidents ci JOIN locations l USING(location_id)
-- WHERE ci.incident_date >= CURDATE() - INTERVAL 30 DAY
-- GROUP BY l.location_id HAVING crime_count >= 5 ORDER BY crime_count DESC;

-- Q2: Crime by type
-- SELECT ct.type_name, ct.severity, COUNT(*) AS total
-- FROM crime_incidents ci JOIN crime_types ct USING(crime_type_id)
-- GROUP BY ct.crime_type_id ORDER BY total DESC;

-- Q3: Crime by time of day
-- SELECT time_of_day, COUNT(*) AS incidents
-- FROM crime_incidents GROUP BY time_of_day ORDER BY incidents DESC;

-- Q4: Safety score by zone
-- SELECT l.zone, ROUND(AVG(lss.safety_score),1) AS avg_safety
-- FROM location_safety_scores lss JOIN locations l USING(location_id)
-- GROUP BY l.zone ORDER BY avg_safety DESC;


-- ─────────────────────────────────────────────────────────────
--  SEED: 150 Crime Incidents across Pune wards
-- ─────────────────────────────────────────────────────────────
INSERT INTO crime_incidents
  (incident_code, crime_type_id, location_id, address_detail, latitude, longitude,
   incident_date, incident_time, description, victim_count, status, reporting_source,
   fir_number, assigned_station, is_verified)
VALUES
-- HADAPSAR (W03) - East Zone - HIGH crime area
('CRM-2024-00001',1, 3,'Near Magnum Mall, Hadapsar',18.5030,73.9270,'Motorcycle theft from parking lot',1,'fir_filed','citizen','FIR-HAD-2024-001','Hadapsar Police Station',1),
('CRM-2024-00002',2, 3,'Hadapsar Main Road',18.5015,73.9250,'Bike stolen outside restaurant',1,'reported','citizen',NULL,'Hadapsar Police Station',1),
('CRM-2024-00003',3, 3,'Near NIBM Road junction',18.5045,73.9290,'Chain snatching from elderly woman',1,'fir_filed','citizen','FIR-HAD-2024-003','Hadapsar Police Station',1),
('CRM-2024-00004',5, 3,'Hadapsar Chowk',18.5060,73.9260,'Two men brawl outside tea stall',2,'resolved','patrol','FIR-HAD-2024-004','Hadapsar Police Station',1),
('CRM-2024-00005',10,3,'Magarpatta Road, Hadapsar',18.5025,73.9280,'Hit and run accident',1,'under_investigation','citizen','FIR-HAD-2024-005','Hadapsar Police Station',1),
('CRM-2024-00006',11,3,'Hadapsar Industrial Area',18.5080,73.9240,'Online banking fraud Rs.85,000',1,'fir_filed','citizen','FIR-HAD-2024-006','Cyber Cell Hadapsar',1),
('CRM-2024-00007',4, 3,'Hadapsar, Lane 7',18.5020,73.9265,'House burglary while owners on vacation',1,'chargesheet','citizen','FIR-HAD-2024-007','Hadapsar Police Station',1),
('CRM-2024-00008',13,3,'Hadapsar slum area',18.5070,73.9230,'Domestic violence, neighbour complaint',1,'fir_filed','citizen','FIR-HAD-2024-008','Hadapsar Police Station',1),
('CRM-2024-00009',1, 3,'Seasonal supermarket Hadapsar',18.5035,73.9255,'Shoplifting caught on CCTV',1,'resolved','cctv','FIR-HAD-2024-009','Hadapsar Police Station',1),
('CRM-2024-00010',9, 3,'Public park Hadapsar',18.5050,73.9275,'Park benches vandalized at night',1,'reported','patrol',NULL,'Hadapsar Police Station',1),

-- SHIVAJINAGAR (W05) - Central Zone - MODERATE crime
('CRM-2024-00011',6, 5,'FC Road, Shivajinagar',18.5310,73.8475,'Eve teasing near college gate',1,'fir_filed','citizen','FIR-SJN-2024-001','Shivajinagar PS',1),
('CRM-2024-00012',7, 5,'JM Road, Shivajinagar',18.5295,73.8490,'Drunk youth creating nuisance near pub',3,'resolved','patrol','FIR-SJN-2024-002','Shivajinagar PS',1),
('CRM-2024-00013',2, 5,'Shivajinagar station parking',18.5320,73.8460,'Two-wheeler theft from station',1,'under_investigation','citizen','FIR-SJN-2024-003','Shivajinagar PS',1),
('CRM-2024-00014',11,5,'Online - Shivajinagar',18.5308,73.8474,'UPI scam - Rs.1.2 lakhs lost',1,'fir_filed','citizen','FIR-SJN-2024-004','Cyber Cell',1),
('CRM-2024-00015',5, 5,'Deccan Gymkhana area',18.5300,73.8480,'Road rage assault',2,'chargesheet','citizen','FIR-SJN-2024-005','Shivajinagar PS',1),

-- BIBWEWADI (W09) - South Zone - HIGH crime
('CRM-2024-00016',1, 9,'Bibwewadi market',18.4750,73.8565,'Mobile phone snatching',1,'fir_filed','citizen','FIR-BIB-2024-001','Bibwewadi PS',1),
('CRM-2024-00017',3, 9,'Bibwewadi main road',18.4740,73.8555,'Chain snatching from scooter rider',1,'under_investigation','citizen','FIR-BIB-2024-002','Bibwewadi PS',1),
('CRM-2024-00018',8, 9,'Bibwewadi locality',18.4760,73.8570,'Drug peddling complaint',1,'fir_filed','citizen','FIR-BIB-2024-003','Bibwewadi PS',1),
('CRM-2024-00019',4, 9,'Bibwewadi residential',18.4735,73.8545,'Burglary during Diwali holidays',1,'chargesheet','citizen','FIR-BIB-2024-004','Bibwewadi PS',1),
('CRM-2024-00020',5, 9,'Bibwewadi chowk',18.4770,73.8560,'Gang fight over dispute',4,'fir_filed','patrol','FIR-BIB-2024-005','Bibwewadi PS',1),
('CRM-2024-00021',13,9,'Bibwewadi private residence',18.4745,73.8575,'Domestic violence report',1,'under_investigation','citizen','FIR-BIB-2024-006','Bibwewadi PS',1),

-- BANER (W12) - West Zone
('CRM-2024-00022',2, 12,'Baner IT Park road',18.5590,73.7870,'Car theft from office campus',1,'fir_filed','citizen','FIR-BAN-2024-001','Baner PS',1),
('CRM-2024-00023',11,12,'Baner - Balewadi road',18.5600,73.7855,'Online investment fraud Rs.3 lakhs',1,'fir_filed','citizen','FIR-BAN-2024-002','Cyber Cell',1),
('CRM-2024-00024',9, 12,'Baner pub lane',18.5580,73.7880,'Property damaged after pub brawl',3,'resolved','police','FIR-BAN-2024-003','Baner PS',1),
('CRM-2024-00025',6, 12,'Baner road near school',18.5605,73.7890,'Harassment case near school',1,'fir_filed','citizen','FIR-BAN-2024-004','Baner PS',1),

-- KOTHRUD (W02) - West Zone
('CRM-2024-00026',1, 2,'Kothrud market',18.5080,73.8082,'Pickpocket in crowded market',1,'reported','citizen',NULL,'Kothrud PS',1),
('CRM-2024-00027',3, 2,'Chandani Chowk, Kothrud',18.5065,73.8070,'Chain snatching from jogger',1,'fir_filed','citizen','FIR-KTH-2024-001','Kothrud PS',1),
('CRM-2024-00028',10,2,'Kothrud main road',18.5090,73.8090,'Two vehicles collision, hit and run',2,'under_investigation','citizen','FIR-KTH-2024-002','Kothrud PS',1),
('CRM-2024-00029',12,2,'Kothrud, near bus stand',18.5055,73.8060,'Missing teenage girl, found later',1,'resolved','citizen','FIR-KTH-2024-003','Kothrud PS',1),

-- AUNDH (W04) - North Zone
('CRM-2024-00030',2, 4,'Aundh D-Mart parking',18.5595,73.8080,'SUV broken into, laptop stolen',1,'fir_filed','cctv','FIR-AUN-2024-001','Aundh PS',1),
('CRM-2024-00031',14,4,'Aundh residential area',18.5585,73.8065,'Public nuisance, loud music party',10,'resolved','anonymous',NULL,'Aundh PS',1),
('CRM-2024-00032',11,4,'Online - Aundh',18.5590,73.8075,'Phishing scam Rs.50,000',1,'under_investigation','citizen','FIR-AUN-2024-002','Cyber Cell',1),
('CRM-2024-00033',5, 4,'Aundh road near bridge',18.5600,73.8095,'Road rage, assault on car driver',1,'fir_filed','citizen','FIR-AUN-2024-003','Aundh PS',1),

-- PIMPRI (W06) - North Zone
('CRM-2024-00034',8, 6,'Pimpri industrial zone',18.6275,73.7960,'Drug trafficking, 3 arrested',3,'chargesheet','police','FIR-PMP-2024-001','Pimpri PS',1),
('CRM-2024-00035',1, 6,'Pimpri market area',18.6265,73.7950,'Cash snatching from elderly',1,'fir_filed','citizen','FIR-PMP-2024-002','Pimpri PS',1),
('CRM-2024-00036',4, 6,'Pimpri colony',18.6280,73.7970,'Burglary, safe cracked',1,'under_investigation','citizen','FIR-PMP-2024-003','Pimpri PS',1),
('CRM-2024-00037',15,6,'Pimpri warehouse',18.6260,73.7945,'Illegal weapon found',1,'chargesheet','police','FIR-PMP-2024-004','Pimpri PS',1),

-- KHARADI (W14) - East Zone
('CRM-2024-00038',2, 14,'EON IT Park, Kharadi',18.5520,73.9415,'Bike theft from tech park',1,'fir_filed','cctv','FIR-KHR-2024-001','Kharadi PS',1),
('CRM-2024-00039',11,14,'Kharadi - Online',18.5515,73.9410,'Job offer scam, Rs.2 lakhs',1,'fir_filed','citizen','FIR-KHR-2024-002','Cyber Cell',1),
('CRM-2024-00040',6, 14,'Kharadi main road',18.5530,73.9420,'Stalking complaint',1,'under_investigation','citizen','FIR-KHR-2024-003','Kharadi PS',1),

-- VIMAN NAGAR (W13) - East Zone
('CRM-2024-00041',2, 13,'Viman Nagar mall parking',18.5682,73.9147,'Car break-in, valuables stolen',1,'fir_filed','citizen','FIR-VMN-2024-001','Viman Nagar PS',1),
('CRM-2024-00042',3, 13,'Airport road, Viman Nagar',18.5675,73.9140,'Chain snatching from auto',1,'reported','citizen',NULL,'Viman Nagar PS',1),
('CRM-2024-00043',11,13,'Viman Nagar - Online',18.5679,73.9143,'Credit card skimming Rs.75,000',1,'fir_filed','citizen','FIR-VMN-2024-002','Cyber Cell',1),

-- DECCAN (W15) - Central Zone
('CRM-2024-00044',1, 15,'Deccan bus stop',18.5198,73.8440,'Wallet stolen in crowd',1,'reported','citizen',NULL,'Deccan PS',1),
('CRM-2024-00045',9, 15,'Lakdi Pool bridge',18.5190,73.8435,'Graffiti and vandalism at night',1,'reported','patrol',NULL,'Deccan PS',1),
('CRM-2024-00046',5, 15,'Sambhaji Park, Deccan',18.5200,73.8445,'Park brawl, 3 people',3,'resolved','patrol','FIR-DEC-2024-001','Deccan PS',1),

-- KATRAJ (W10) - South Zone
('CRM-2024-00047',8, 10,'Katraj, near highway',18.4535,73.8675,'Drug supply chain bust, 5 arrested',5,'chargesheet','police','FIR-KTJ-2024-001','Katraj PS',1),
('CRM-2024-00048',4, 10,'Katraj residential colony',18.4525,73.8665,'Repeated break-ins at empty flat',1,'fir_filed','citizen','FIR-KTJ-2024-002','Katraj PS',1),
('CRM-2024-00049',13,10,'Katraj home',18.4540,73.8680,'DV case, wife filed complaint',1,'under_investigation','citizen','FIR-KTJ-2024-003','Katraj PS',1),

-- WARJE (W11) - West Zone
('CRM-2024-00050',2, 11,'Warje bridge area',18.4895,73.7950,'Bike theft, CCTV footage available',1,'under_investigation','cctv','FIR-WAR-2024-001','Warje PS',1),
('CRM-2024-00051',10,11,'Warje-Malwadi road',18.4900,73.7940,'Drunk driving accident',1,'fir_filed','patrol','FIR-WAR-2024-002','Warje PS',1),
('CRM-2024-00052',14,11,'Warje residential',18.4890,73.7960,'Noise complaint - construction at night',20,'resolved','anonymous',NULL,'Warje PS',0),

-- HINJEWADI (W18) - West Zone (IT hub)
('CRM-2024-00053',11,18,'Hinjewadi IT Park Phase 1',18.5915,73.7391,'Tech employee scammed of Rs.5 lakhs',1,'fir_filed','citizen','FIR-HIN-2024-001','Hinjewadi PS',1),
('CRM-2024-00054',2, 18,'Hinjewadi Phase 2 road',18.5910,73.7385,'Car stolen from office parking',1,'under_investigation','cctv','FIR-HIN-2024-002','Hinjewadi PS',1),
('CRM-2024-00055',6, 18,'Hinjewadi road, near bus stop',18.5920,73.7395,'Harassment of woman at bus stop',1,'fir_filed','citizen','FIR-HIN-2024-003','Hinjewadi PS',1),

-- KOREGAON PARK (W01) - East Zone
('CRM-2024-00056',7, 1,'KP lane pub area',18.5365,73.8940,'Drunk brawl outside nightclub',4,'resolved','patrol','FIR-KP-2024-001','Koregaon Park PS',1),
('CRM-2024-00057',8, 1,'Koregaon Park side lane',18.5358,73.8935,'Drug possession, arrested',2,'chargesheet','police','FIR-KP-2024-002','Koregaon Park PS',1),
('CRM-2024-00058',1, 1,'KP Row House colony',18.5370,73.8945,'Jewellery theft from residence',1,'under_investigation','citizen','FIR-KP-2024-003','Koregaon Park PS',1),

-- YERAWADA (W08) - East Zone
('CRM-2024-00059',1, 8,'Yerawada market',18.5550,73.9010,'Pickpocket in morning rush',1,'reported','citizen',NULL,'Yerawada PS',1),
('CRM-2024-00060',5, 8,'Nagar road, Yerawada',18.5545,73.9000,'Road rage near signal',2,'fir_filed','citizen','FIR-YRW-2024-001','Yerawada PS',1),

-- CHINCHWAD (W07) - North Zone
('CRM-2024-00061',4, 7,'Chinchwad colony',18.6457,73.7838,'Burglary, Rs.1.5 lakh cash stolen',1,'fir_filed','citizen','FIR-CCW-2024-001','Chinchwad PS',1),
('CRM-2024-00062',8, 7,'Chinchwad MIDC area',18.6450,73.7830,'Drug seizure, factory raided',7,'chargesheet','police','FIR-CCW-2024-002','Chinchwad PS',1),
('CRM-2024-00063',10,7,'Chinchwad main highway',18.6460,73.7845,'Reckless driving, cyclist injured',1,'fir_filed','citizen','FIR-CCW-2024-003','Chinchwad PS',1),

-- MAGARPATTA (W17) - South Zone
('CRM-2024-00064',2, 17,'Magarpatta City parking',18.5130,73.9290,'Car theft from gated society',1,'fir_filed','cctv','FIR-MGP-2024-001','Hadapsar PS',1),
('CRM-2024-00065',11,17,'Magarpatta - Online',18.5125,73.9285,'KYC fraud, bank account emptied',1,'under_investigation','citizen','FIR-MGP-2024-002','Cyber Cell',1),

-- PIMPLE SAUDAGAR (W20) - North Zone
('CRM-2024-00066',3, 20,'Pimple Saudagar road',18.6020,73.8000,'Chain snatching morning walk',1,'fir_filed','citizen','FIR-PSD-2024-001','Pimple Saudagar PS',1),
('CRM-2024-00067',1, 20,'Pimple Saudagar market',18.6015,73.7990,'Shopkeeper robbed at knifepoint',1,'chargesheet','citizen','FIR-PSD-2024-002','Pimple Saudagar PS',1),
('CRM-2024-00068',13,20,'Pimple Saudagar residential',18.6025,73.8005,'Domestic violence, child present',1,'fir_filed','citizen','FIR-PSD-2024-003','Pimple Saudagar PS',1),

-- WAKAD (W19) - West Zone
('CRM-2024-00069',2, 19,'Wakad Spine road',18.5992,73.7670,'Two bikes stolen from apartment',2,'under_investigation','citizen','FIR-WKD-2024-001','Wakad PS',1),
('CRM-2024-00070',11,19,'Wakad - Cyber',18.5990,73.7667,'Fake matrimonial fraud, Rs.80,000',1,'fir_filed','citizen','FIR-WKD-2024-002','Cyber Cell',1),

-- SWARGATE (W16) - Central Zone
('CRM-2024-00071',1, 16,'Swargate bus terminal',18.5020,73.8576,'Luggage theft at bus station',1,'reported','citizen',NULL,'Swargate PS',1),
('CRM-2024-00072',7, 16,'Swargate pub area',18.5015,73.8570,'Drunk driving caught at naka',1,'fir_filed','patrol','FIR-SWG-2024-001','Swargate PS',1),
('CRM-2024-00073',5, 16,'Swargate chowk',18.5025,73.8580,'Public brawl, 5 arrested',5,'chargesheet','patrol','FIR-SWG-2024-002','Swargate PS',1),

-- Additional incidents for realistic heatmap density
('CRM-2024-00074',1, 3,'Hadapsar lane 12',18.5040,73.9285,'ATM card skimming',1,'fir_filed','citizen','FIR-HAD-2024-010','Hadapsar PS',1),
('CRM-2024-00075',2, 3,'Hadapsar, SB road',18.5010,73.9260,'Truck theft from godown',1,'under_investigation','citizen','FIR-HAD-2024-011','Hadapsar PS',1),
('CRM-2024-00076',5, 9,'Bibwewadi gaothan',18.4780,73.8555,'Knife fight, 2 injured',2,'fir_filed','patrol','FIR-BIB-2024-007','Bibwewadi PS',1),
('CRM-2024-00077',3, 9,'Bibwewadi morning walk track',18.4730,73.8565,'Elderly woman attacked',1,'chargesheet','citizen','FIR-BIB-2024-008','Bibwewadi PS',1),
('CRM-2024-00078',8, 6,'Pimpri highway',18.6270,73.7965,'Major drug haul, 120kg seized',4,'chargesheet','police','FIR-PMP-2024-005','Pimpri PS',1),
('CRM-2024-00079',4, 12,'Baner residential society',18.5585,73.7875,'Weekend burglary',1,'under_investigation','citizen','FIR-BAN-2024-005','Baner PS',1),
('CRM-2024-00080',11,5,'JM Road cyber cafe',18.5295,73.8485,'Hacking of business account',1,'fir_filed','citizen','FIR-SJN-2024-006','Cyber Cell',1);

-- Initialize safety scores
CALL sp_calculate_safety_scores();

-- Verification
SELECT 'crime_types' AS tbl, COUNT(*) AS rows FROM crime_types
UNION ALL SELECT 'crime_incidents', COUNT(*) FROM crime_incidents
UNION ALL SELECT 'location_safety_scores', COUNT(*) FROM location_safety_scores;
USE smartcity_db;

SELECT 'complaints' AS table_name, COUNT(*) AS rows FROM complaints
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'crime_incidents', COUNT(*) FROM crime_incidents
UNION ALL
SELECT 'categories', COUNT(*) FROM categories
UNION ALL
SELECT 'locations', COUNT(*) FROM locations;
SELECT * FROM users WHERE email='admin@smartcity.gov';
 


