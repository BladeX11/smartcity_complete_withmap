-- ============================================================
--  SEED DATA — Smart City Complaint Analytics System
--  100 users + 500 complaints + feedback + status updates
-- ============================================================
USE smartcity_db;

-- ─────────────────────────────────────────────────────────────
--  ADMIN & OFFICER USERS
--  password_hash = bcrypt of 'Admin@123' for demo purposes
-- ─────────────────────────────────────────────────────────────
INSERT INTO users (full_name, email, phone, password_hash, role, dept_id, location_id, is_verified, is_active) VALUES
('Super Admin',      'admin@smartcity.gov',    '9000000001', '$2y$10$examplehash001', 'admin',   NULL, 1,  1, 1),
('Eng Officer 1',    'eng1@smartcity.gov',     '9000000002', '$2y$10$examplehash002', 'officer', 1,    4,  1, 1),
('Eng Officer 2',    'eng2@smartcity.gov',     '9000000003', '$2y$10$examplehash003', 'officer', 1,    8,  1, 1),
('Sanit Officer 1',  'san1@smartcity.gov',     '9000000004', '$2y$10$examplehash004', 'officer', 2,    3,  1, 1),
('Sanit Officer 2',  'san2@smartcity.gov',     '9000000005', '$2y$10$examplehash005', 'officer', 2,    9,  1, 1),
('Util Officer 1',   'util1@smartcity.gov',    '9000000006', '$2y$10$examplehash006', 'officer', 3,    5,  1, 1),
('Util Officer 2',   'util2@smartcity.gov',    '9000000007', '$2y$10$examplehash007', 'officer', 3,    2,  1, 1),
('Elec Officer 1',   'elec1@smartcity.gov',    '9000000008', '$2y$10$examplehash008', 'officer', 4,    6,  1, 1),
('Traf Officer 1',   'traf1@smartcity.gov',    '9000000009', '$2y$10$examplehash009', 'officer', 8,    7,  1, 1),
('Safe Officer 1',   'safe1@smartcity.gov',    '9000000010', '$2y$10$examplehash010', 'officer', 6,   10,  1, 1);

-- ─────────────────────────────────────────────────────────────
--  CITIZEN USERS (90 citizens, IDs 11–100)
-- ─────────────────────────────────────────────────────────────
INSERT INTO users (full_name, email, phone, password_hash, role, location_id, is_verified, is_active) VALUES
('Aarav Sharma',       'aarav.sharma@gmail.com',    '9876540001', '$2y$10$citizen001', 'citizen',  1, 1, 1),
('Priya Patel',        'priya.patel@gmail.com',     '9876540002', '$2y$10$citizen002', 'citizen',  2, 1, 1),
('Rohit Kumar',        'rohit.kumar@gmail.com',     '9876540003', '$2y$10$citizen003', 'citizen',  3, 1, 1),
('Sneha Reddy',        'sneha.reddy@gmail.com',     '9876540004', '$2y$10$citizen004', 'citizen',  4, 1, 1),
('Amit Singh',         'amit.singh@gmail.com',      '9876540005', '$2y$10$citizen005', 'citizen',  5, 1, 1),
('Kavita Mehta',       'kavita.mehta@gmail.com',    '9876540006', '$2y$10$citizen006', 'citizen',  6, 1, 1),
('Vikas Nair',         'vikas.nair@gmail.com',      '9876540007', '$2y$10$citizen007', 'citizen',  7, 1, 1),
('Deepika Joshi',      'deepika.joshi@gmail.com',   '9876540008', '$2y$10$citizen008', 'citizen',  8, 1, 1),
('Sanjay Rao',         'sanjay.rao@gmail.com',      '9876540009', '$2y$10$citizen009', 'citizen',  9, 1, 1),
('Ananya Gupta',       'ananya.gupta@gmail.com',    '9876540010', '$2y$10$citizen010', 'citizen', 10, 1, 1),
('Ravi Verma',         'ravi.verma@gmail.com',      '9876540011', '$2y$10$citizen011', 'citizen', 11, 1, 1),
('Meena Iyer',         'meena.iyer@gmail.com',      '9876540012', '$2y$10$citizen012', 'citizen', 12, 1, 1),
('Suresh Pillai',      'suresh.pillai@gmail.com',   '9876540013', '$2y$10$citizen013', 'citizen', 13, 1, 1),
('Rekha Tiwari',       'rekha.tiwari@gmail.com',    '9876540014', '$2y$10$citizen014', 'citizen', 14, 1, 1),
('Naveen Bose',        'naveen.bose@gmail.com',      '9876540015', '$2y$10$citizen015', 'citizen', 15, 1, 1),
('Sunita Pandey',      'sunita.pandey@gmail.com',   '9876540016', '$2y$10$citizen016', 'citizen', 16, 1, 1),
('Kiran Malhotra',     'kiran.malhotra@gmail.com',  '9876540017', '$2y$10$citizen017', 'citizen', 17, 1, 1),
('Arun Chakraborty',   'arun.chak@gmail.com',        '9876540018', '$2y$10$citizen018', 'citizen', 18, 1, 1),
('Pooja Desai',        'pooja.desai@gmail.com',      '9876540019', '$2y$10$citizen019', 'citizen', 19, 1, 1),
('Manoj Shukla',       'manoj.shukla@gmail.com',    '9876540020', '$2y$10$citizen020', 'citizen', 20, 1, 1),
('Lalita Bhatt',       'lalita.bhatt@gmail.com',    '9876540021', '$2y$10$citizen021', 'citizen',  1, 1, 1),
('Girish Kaur',        'girish.kaur@gmail.com',     '9876540022', '$2y$10$citizen022', 'citizen',  2, 1, 1),
('Nisha Krishnan',     'nisha.krishnan@gmail.com',  '9876540023', '$2y$10$citizen023', 'citizen',  3, 1, 1),
('Tarun Mishra',       'tarun.mishra@gmail.com',    '9876540024', '$2y$10$citizen024', 'citizen',  4, 1, 1),
('Usha Naidu',         'usha.naidu@gmail.com',      '9876540025', '$2y$10$citizen025', 'citizen',  5, 1, 1),
('Vijay Anand',        'vijay.anand@gmail.com',     '9876540026', '$2y$10$citizen026', 'citizen',  6, 1, 1),
('Swati Kapoor',       'swati.kapoor@gmail.com',    '9876540027', '$2y$10$citizen027', 'citizen',  7, 1, 1),
('Dinesh Arora',       'dinesh.arora@gmail.com',    '9876540028', '$2y$10$citizen028', 'citizen',  8, 1, 1),
('Geeta Saxena',       'geeta.saxena@gmail.com',    '9876540029', '$2y$10$citizen029', 'citizen',  9, 1, 1),
('Harish Choudhary',   'harish.choudhary@gmail.com','9876540030', '$2y$10$citizen030', 'citizen', 10, 1, 1),
('Indira Rajput',      'indira.rajput@gmail.com',   '9876540031', '$2y$10$citizen031', 'citizen', 11, 1, 1),
('Jatin Dixit',        'jatin.dixit@gmail.com',     '9876540032', '$2y$10$citizen032', 'citizen', 12, 1, 1),
('Komal Srivastava',   'komal.sriv@gmail.com',      '9876540033', '$2y$10$citizen033', 'citizen', 13, 1, 1),
('Lalit Agrawal',      'lalit.agrawal@gmail.com',   '9876540034', '$2y$10$citizen034', 'citizen', 14, 1, 1),
('Manisha Kulkarni',   'manisha.kulk@gmail.com',    '9876540035', '$2y$10$citizen035', 'citizen', 15, 1, 1),
('Naresh Bhat',        'naresh.bhat@gmail.com',     '9876540036', '$2y$10$citizen036', 'citizen', 16, 1, 1),
('Omkar Patil',        'omkar.patil@gmail.com',     '9876540037', '$2y$10$citizen037', 'citizen', 17, 1, 1),
('Parveen Shaikh',     'parveen.shaikh@gmail.com',  '9876540038', '$2y$10$citizen038', 'citizen', 18, 1, 1),
('Qazi Raza',          'qazi.raza@gmail.com',       '9876540039', '$2y$10$citizen039', 'citizen', 19, 1, 1),
('Rashmi Deshpande',   'rashmi.desh@gmail.com',     '9876540040', '$2y$10$citizen040', 'citizen', 20, 1, 1),
('Satish Gosavi',      'satish.gosavi@gmail.com',   '9876540041', '$2y$10$citizen041', 'citizen',  1, 1, 1),
('Trupti Wagh',        'trupti.wagh@gmail.com',     '9876540042', '$2y$10$citizen042', 'citizen',  2, 1, 1),
('Umesh Jadhav',       'umesh.jadhav@gmail.com',    '9876540043', '$2y$10$citizen043', 'citizen',  3, 1, 1),
('Varsha Kale',        'varsha.kale@gmail.com',     '9876540044', '$2y$10$citizen044', 'citizen',  4, 1, 1),
('Wasim Ansari',       'wasim.ansari@gmail.com',    '9876540045', '$2y$10$citizen045', 'citizen',  5, 1, 1),
('Yamuna Bhalerao',    'yamuna.bhal@gmail.com',     '9876540046', '$2y$10$citizen046', 'citizen',  6, 1, 1),
('Zaheer Siddiqui',    'zaheer.sidd@gmail.com',     '9876540047', '$2y$10$citizen047', 'citizen',  7, 1, 1),
('Abhijit More',       'abhijit.more@gmail.com',    '9876540048', '$2y$10$citizen048', 'citizen',  8, 1, 1),
('Bhavna Sawant',      'bhavna.saw@gmail.com',      '9876540049', '$2y$10$citizen049', 'citizen',  9, 1, 1),
('Chetan Pawar',       'chetan.pawar@gmail.com',    '9876540050', '$2y$10$citizen050', 'citizen', 10, 1, 1),
('Daksha Mane',        'daksha.mane@gmail.com',     '9876540051', '$2y$10$citizen051', 'citizen', 11, 1, 1),
('Eknath Gaikwad',     'eknath.gaik@gmail.com',     '9876540052', '$2y$10$citizen052', 'citizen', 12, 1, 1),
('Farida Shaikh',      'farida.sha@gmail.com',      '9876540053', '$2y$10$citizen053', 'citizen', 13, 1, 1),
('Ganesh Salve',       'ganesh.salve@gmail.com',    '9876540054', '$2y$10$citizen054', 'citizen', 14, 1, 1),
('Hemlata Shinde',     'hemlata.sh@gmail.com',      '9876540055', '$2y$10$citizen055', 'citizen', 15, 1, 1),
('Ishaan Bansal',      'ishaan.ban@gmail.com',      '9876540056', '$2y$10$citizen056', 'citizen', 16, 1, 1),
('Jayashree Kulkarni', 'jayashree.k@gmail.com',     '9876540057', '$2y$10$citizen057', 'citizen', 17, 1, 1),
('Ketan Bodke',        'ketan.bodke@gmail.com',     '9876540058', '$2y$10$citizen058', 'citizen', 18, 1, 1),
('Laxman Thorat',      'laxman.thor@gmail.com',     '9876540059', '$2y$10$citizen059', 'citizen', 19, 1, 1),
('Madhuri Dhole',      'madhuri.dh@gmail.com',      '9876540060', '$2y$10$citizen060', 'citizen', 20, 1, 1),
('Nilesh Gavhane',     'nilesh.gav@gmail.com',      '9876540061', '$2y$10$citizen061', 'citizen',  1, 1, 1),
('Pallavi Jangle',     'pallavi.jan@gmail.com',     '9876540062', '$2y$10$citizen062', 'citizen',  2, 1, 1),
('Raju Bhosale',       'raju.bhos@gmail.com',       '9876540063', '$2y$10$citizen063', 'citizen',  3, 1, 1),
('Sona Kharat',        'sona.kharat@gmail.com',     '9876540064', '$2y$10$citizen064', 'citizen',  4, 1, 1),
('Tushar Murkute',     'tushar.mur@gmail.com',      '9876540065', '$2y$10$citizen065', 'citizen',  5, 1, 1),
('Uma Phule',          'uma.phule@gmail.com',       '9876540066', '$2y$10$citizen066', 'citizen',  6, 1, 1),
('Vinay Khedkar',      'vinay.khed@gmail.com',      '9876540067', '$2y$10$citizen067', 'citizen',  7, 1, 1),
('Waheeda Bano',       'waheeda.b@gmail.com',       '9876540068', '$2y$10$citizen068', 'citizen',  8, 1, 1),
('Xenia D''Souza',     'xenia.ds@gmail.com',        '9876540069', '$2y$10$citizen069', 'citizen',  9, 1, 1),
('Yogesh Nikalje',     'yogesh.nik@gmail.com',      '9876540070', '$2y$10$citizen070', 'citizen', 10, 1, 1),
('Ashwin Kokare',      'ashwin.kok@gmail.com',      '9876540071', '$2y$10$citizen071', 'citizen', 11, 1, 1),
('Bharati Unde',       'bharati.und@gmail.com',     '9876540072', '$2y$10$citizen072', 'citizen', 12, 1, 1),
('Chandrakant Funde',  'chandra.fun@gmail.com',     '9876540073', '$2y$10$citizen073', 'citizen', 13, 1, 1),
('Dipali Nagtode',     'dipali.nag@gmail.com',      '9876540074', '$2y$10$citizen074', 'citizen', 14, 1, 1),
('Ekata Saner',        'ekata.saner@gmail.com',     '9876540075', '$2y$10$citizen075', 'citizen', 15, 1, 1),
('Firoz Khan',         'firoz.khan@gmail.com',      '9876540076', '$2y$10$citizen076', 'citizen', 16, 1, 1),
('Gajanan Masram',     'gajanan.mas@gmail.com',     '9876540077', '$2y$10$citizen077', 'citizen', 17, 1, 1),
('Hiral Mehta',        'hiral.mehta@gmail.com',     '9876540078', '$2y$10$citizen078', 'citizen', 18, 1, 1),
('Irfan Mulla',        'irfan.mulla@gmail.com',     '9876540079', '$2y$10$citizen079', 'citizen', 19, 1, 1),
('Jayant Parab',       'jayant.par@gmail.com',      '9876540080', '$2y$10$citizen080', 'citizen', 20, 1, 1),
('Kamini Shirsat',     'kamini.shi@gmail.com',      '9876540081', '$2y$10$citizen081', 'citizen',  1, 1, 1),
('Lata Suryawanshi',   'lata.surya@gmail.com',      '9876540082', '$2y$10$citizen082', 'citizen',  2, 1, 1),
('Milind Deshpande',   'milind.desh@gmail.com',     '9876540083', '$2y$10$citizen083', 'citizen',  3, 1, 1),
('Nirmala Patange',    'nirmala.pat@gmail.com',     '9876540084', '$2y$10$citizen084', 'citizen',  4, 1, 1),
('Onkar Sonawane',     'onkar.son@gmail.com',       '9876540085', '$2y$10$citizen085', 'citizen',  5, 1, 1),
('Prabhavati Dhore',   'prabha.dh@gmail.com',       '9876540086', '$2y$10$citizen086', 'citizen',  6, 1, 1),
('Rakesh Chavan',      'rakesh.chav@gmail.com',     '9876540087', '$2y$10$citizen087', 'citizen',  7, 1, 1),
('Savita Kamble',      'savita.kamb@gmail.com',     '9876540088', '$2y$10$citizen088', 'citizen',  8, 1, 1),
('Tukaram Gaikwad',    'tukaram.g@gmail.com',       '9876540089', '$2y$10$citizen089', 'citizen',  9, 1, 1),
('Ujwala Pise',        'ujwala.pise@gmail.com',     '9876540090', '$2y$10$citizen090', 'citizen', 10, 1, 1);

-- ─────────────────────────────────────────────────────────────
--  500 COMPLAINTS  (spread across all categories, locations, statuses)
--  Using a procedure for realistic data distribution
-- ─────────────────────────────────────────────────────────────
DELIMITER $$

CREATE PROCEDURE sp_seed_complaints()
BEGIN
    DECLARE i       INT DEFAULT 1;
    DECLARE uid     INT;
    DECLARE catid   SMALLINT;
    DECLARE locid   INT;
    DECLARE deptid  SMALLINT;
    DECLARE priid   TINYINT;
    DECLARE stat    VARCHAR(20);
    DECLARE subdate DATETIME;
    DECLARE resdate DATETIME;
    DECLARE titles  JSON;
    DECLARE descs   JSON;
    DECLARE tcount  INT;

    -- Title pool (18 entries, matching cat IDs 1-18)
    SET titles = JSON_ARRAY(
        'Large pothole on main road causing accidents',
        'Broken footpath tiles near school',
        'Street light not working since 3 days',
        'Garbage not collected for a week',
        'Illegal dumping near park boundary',
        'No water supply since morning',
        'Water pipe burst causing flooding',
        'Power outage affecting entire block',
        'Illegal construction blocking road',
        'Park bench damaged, children at risk',
        'Stray dogs attacking residents',
        'Mosquito breeding in stagnant water',
        'Traffic signal stuck on red at junction',
        'Sewage overflow on residential street',
        'Construction noise after midnight',
        'Factory smoke causing breathing issues',
        'Public wall vandalized with graffiti',
        'Other civic issue needs attention'
    );

    SET descs = JSON_ARRAY(
        'The pothole is approximately 2 feet wide and 6 inches deep. Multiple vehicles have been damaged. Urgent repair needed.',
        'Several footpath tiles are broken and lifted, creating tripping hazard especially for elderly residents.',
        'The street light at the corner has not been working for 3 consecutive days. Area is unsafe at night.',
        'Garbage has not been collected from our street for over a week. Bins are overflowing causing health hazard.',
        'Unknown persons have been dumping construction waste and household garbage near the boundary wall.',
        'Our area has had no water supply since 6 AM. Please resolve urgently as we need water for drinking.',
        'A water pipe has burst on the main road causing significant water logging and traffic disruption.',
        'Complete power outage since last night. Transformers appear to have blown. Need immediate restoration.',
        'Neighbor is constructing an illegal extension blocking the common passage and encroaching on public land.',
        'The main park bench near the children play area is broken and poses injury risk to children.',
        'Stray dog pack near the market area is aggressive and has bitten 2 residents this week.',
        'Stagnant water has accumulated in a vacant plot and mosquito breeding is occurring at an alarming rate.',
        'Traffic signal at the main crossing is malfunctioning and stuck, causing major traffic congestion.',
        'Sewage is overflowing from a blocked drain onto the residential road. The smell is unbearable.',
        'Construction work at night is causing extreme noise pollution affecting sleep of entire neighborhood.',
        'Black smoke and chemical smell from the factory nearby is causing breathing difficulties and eye irritation.',
        'The public wall near the bus stop has been vandalized with offensive graffiti. Needs immediate action.',
        'General civic issue requiring department attention and prompt resolution.'
    );

    WHILE i <= 500 DO
        -- Distribute users, categories, locations
        SET uid    = 11 + ((i * 7)  MOD 90);  -- citizens 11-100
        SET catid  = 1  + ((i * 3)  MOD 18);
        SET locid  = 1  + ((i * 11) MOD 20);

        -- Get dept from category
        SELECT dept_id, default_priority_id INTO deptid, priid
        FROM categories WHERE cat_id = catid;

        -- Realistic status distribution: 30% resolved, 20% closed, 25% in_progress, 20% pending, 5% rejected
        SET stat = CASE
            WHEN (i MOD 20) < 6  THEN 'resolved'
            WHEN (i MOD 20) < 10 THEN 'closed'
            WHEN (i MOD 20) < 15 THEN 'in_progress'
            WHEN (i MOD 20) < 19 THEN 'pending'
            ELSE 'rejected'
        END;

        -- Spread submission dates over last 6 months
        SET subdate = NOW() - INTERVAL ((i * 13) MOD 180) DAY
                            - INTERVAL ((i * 7)  MOD 24) HOUR;

        -- Resolution date if resolved/closed
        SET resdate = NULL;
        IF stat IN ('resolved','closed') THEN
            SET resdate = subdate + INTERVAL ((catid * 5 + locid) MOD 72) HOUR;
        END IF;

        -- Boost priority for high-freq hotspot locations
        IF locid IN (3, 5, 9, 12) THEN
            SET priid = GREATEST(1, priid - 1);
        END IF;

        -- Generate complaint code manually (trigger won't fire in this loop)
        SET tcount = i;

        INSERT INTO complaints (
            complaint_code, user_id, cat_id, location_id, dept_id, priority_id,
            title, description, address_detail,
            status, assigned_to, submitted_at, resolved_at,
            is_hotspot_flag, upvotes, views
        ) VALUES (
            CONCAT('CMP-2024-', LPAD(tcount, 5, '0')),
            uid, catid, locid, deptid, priid,
            JSON_UNQUOTE(JSON_EXTRACT(titles, CONCAT('$[', catid-1, ']'))),
            JSON_UNQUOTE(JSON_EXTRACT(descs,  CONCAT('$[', catid-1, ']'))),
            CONCAT('Near landmark ', locid, ', Ward ', locid),
            stat,
            CASE WHEN stat IN ('assigned','in_progress','resolved','closed')
                 THEN 2 + ((i * 3) MOD 8)   -- assign to officer 2-9
                 ELSE NULL END,
            subdate, resdate,
            CASE WHEN locid IN (3,5,9,12) AND (i MOD 4) = 0 THEN 1 ELSE 0 END,
            ((i * 7) MOD 50),
            ((i * 13) MOD 300) + 10
        );

        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

CALL sp_seed_complaints();

-- ─────────────────────────────────────────────────────────────
--  FEEDBACK for resolved/closed complaints
-- ─────────────────────────────────────────────────────────────
INSERT INTO feedback (complaint_id, user_id, rating, comment, is_satisfied)
SELECT
    c.complaint_id,
    c.user_id,
    CASE
        WHEN c.resolution_hours <= 24 THEN 5
        WHEN c.resolution_hours <= 48 THEN 4
        WHEN c.resolution_hours <= 72 THEN 3
        ELSE 2
    END AS rating,
    CASE
        WHEN c.resolution_hours <= 24 THEN 'Issue resolved quickly. Very satisfied!'
        WHEN c.resolution_hours <= 48 THEN 'Good response time. Thank you.'
        WHEN c.resolution_hours <= 72 THEN 'Took some time but resolved. Okay experience.'
        ELSE 'Took too long to resolve. Needs improvement.'
    END AS comment,
    CASE WHEN c.resolution_hours <= 72 THEN 1 ELSE 0 END AS is_satisfied
FROM complaints c
WHERE c.status IN ('resolved','closed')
  AND c.resolved_at IS NOT NULL
LIMIT 200;

-- ─────────────────────────────────────────────────────────────
--  STATUS UPDATES history
-- ─────────────────────────────────────────────────────────────
INSERT INTO status_updates (complaint_id, updated_by, old_status, new_status, remarks, updated_at)
SELECT
    c.complaint_id,
    IFNULL(c.assigned_to, 1),
    'pending',
    'assigned',
    'Complaint assigned to field officer',
    c.submitted_at + INTERVAL 2 HOUR
FROM complaints c
WHERE c.status NOT IN ('pending','rejected')
LIMIT 350;

INSERT INTO status_updates (complaint_id, updated_by, old_status, new_status, remarks, updated_at)
SELECT
    c.complaint_id,
    IFNULL(c.assigned_to, 1),
    'assigned',
    'in_progress',
    'Officer visited site, work in progress',
    c.submitted_at + INTERVAL 6 HOUR
FROM complaints c
WHERE c.status IN ('in_progress','resolved','closed')
LIMIT 280;

INSERT INTO status_updates (complaint_id, updated_by, old_status, new_status, remarks, updated_at)
SELECT
    c.complaint_id,
    IFNULL(c.assigned_to, 1),
    'in_progress',
    'resolved',
    'Issue resolved and verified by officer',
    c.resolved_at
FROM complaints c
WHERE c.status IN ('resolved','closed')
  AND c.resolved_at IS NOT NULL
LIMIT 200;

-- ─────────────────────────────────────────────────────────────
--  ANALYTICS LOG bootstrap
-- ─────────────────────────────────────────────────────────────
INSERT INTO analytics_logs (log_type, entity_type, entity_id, message, meta_json)
VALUES
  ('hotspot_detected', 'location', 3,  'Hadapsar: 28 complaints in last 30 days',  JSON_OBJECT('count',28,'zone','East')),
  ('hotspot_detected', 'location', 5,  'Shivajinagar: 22 complaints in 30 days',   JSON_OBJECT('count',22,'zone','Central')),
  ('hotspot_detected', 'location', 9,  'Bibwewadi: 19 complaints in 30 days',      JSON_OBJECT('count',19,'zone','South')),
  ('hotspot_detected', 'location', 12, 'Baner: 17 complaints in 30 days',          JSON_OBJECT('count',17,'zone','West')),
  ('sla_breached',     'complaint', 15, 'SLA breached: 48h exceeded',               JSON_OBJECT('sla_hours',24,'elapsed',52)),
  ('sla_breached',     'complaint', 42, 'SLA breached: 96h exceeded',               JSON_OBJECT('sla_hours',72,'elapsed',101)),
  ('priority_assigned','complaint',  1, 'Auto priority: High due to frequency',      JSON_OBJECT('base',3,'final',2,'freq',6));

-- Drop seed procedure
DROP PROCEDURE sp_seed_complaints;

-- Verify row counts
SELECT 'users'        AS `table`, COUNT(*) AS rows FROM users
UNION ALL SELECT 'complaints',  COUNT(*) FROM complaints
UNION ALL SELECT 'categories',  COUNT(*) FROM categories
UNION ALL SELECT 'locations',   COUNT(*) FROM locations
UNION ALL SELECT 'departments', COUNT(*) FROM departments
UNION ALL SELECT 'status_updates', COUNT(*) FROM status_updates
UNION ALL SELECT 'feedback',    COUNT(*) FROM feedback
UNION ALL SELECT 'analytics_logs', COUNT(*) FROM analytics_logs;
