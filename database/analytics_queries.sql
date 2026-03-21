-- ============================================================
--  ANALYTICS QUERIES — Smart City Complaint System
--  All queries used by the dashboard & decision support panel
-- ============================================================
USE smartcity_db;

-- ────────────────────────────────────────────────────────────
-- Q1. COMPLAINTS BY LOCATION (for map & bar chart)
-- ────────────────────────────────────────────────────────────
SELECT
    l.location_id,
    l.area_name,
    l.ward_number,
    l.zone,
    l.latitude,
    l.longitude,
    COUNT(c.complaint_id)                                          AS total_complaints,
    SUM(CASE WHEN c.status = 'pending'              THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN c.status = 'in_progress'          THEN 1 ELSE 0 END) AS in_progress,
    SUM(CASE WHEN c.status IN ('resolved','closed') THEN 1 ELSE 0 END) AS resolved,
    SUM(CASE WHEN c.submitted_at >= NOW() - INTERVAL 30 DAY
             THEN 1 ELSE 0 END)                                    AS last_30_days,
    ROUND(SUM(CASE WHEN c.submitted_at >= NOW() - INTERVAL 30 DAY
                   THEN 1 ELSE 0 END) / 30.0, 1)                  AS daily_avg_30d
FROM locations l
LEFT JOIN complaints c ON l.location_id = c.location_id
GROUP BY l.location_id, l.area_name, l.ward_number, l.zone, l.latitude, l.longitude
ORDER BY total_complaints DESC;

-- ────────────────────────────────────────────────────────────
-- Q2. COMPLAINTS BY CATEGORY (for pie/donut chart)
-- ────────────────────────────────────────────────────────────
SELECT
    cat.cat_id,
    cat.cat_name,
    cat.icon_class,
    d.dept_name,
    COUNT(c.complaint_id)                                           AS total,
    SUM(CASE WHEN c.status = 'pending'              THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN c.status IN ('resolved','closed') THEN 1 ELSE 0 END) AS resolved,
    ROUND(AVG(c.resolution_hours), 2)                              AS avg_resolution_hrs,
    ROUND(COUNT(c.complaint_id) * 100.0 /
          (SELECT COUNT(*) FROM complaints), 1)                    AS pct_of_total
FROM categories cat
LEFT JOIN complaints c ON cat.cat_id  = c.cat_id
JOIN  departments   d  ON cat.dept_id = d.dept_id
GROUP BY cat.cat_id, cat.cat_name, cat.icon_class, d.dept_name
ORDER BY total DESC;

-- ────────────────────────────────────────────────────────────
-- Q3. MONTHLY COMPLAINT TRENDS (for line chart)
-- ────────────────────────────────────────────────────────────
SELECT
    DATE_FORMAT(submitted_at, '%Y-%m')                             AS month,
    DATE_FORMAT(submitted_at, '%b %Y')                             AS month_label,
    COUNT(*)                                                        AS total_submitted,
    SUM(CASE WHEN status IN ('resolved','closed') THEN 1 ELSE 0 END) AS resolved,
    SUM(CASE WHEN status = 'pending'              THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN priority_id = 1                 THEN 1 ELSE 0 END) AS critical,
    SUM(CASE WHEN priority_id = 2                 THEN 1 ELSE 0 END) AS high,
    ROUND(AVG(resolution_hours), 2)                                AS avg_resolution_hrs,
    ROUND(SUM(CASE WHEN status IN ('resolved','closed') THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                                   AS resolution_rate_pct
FROM complaints
GROUP BY DATE_FORMAT(submitted_at, '%Y-%m'), DATE_FORMAT(submitted_at, '%b %Y')
ORDER BY month;

-- ────────────────────────────────────────────────────────────
-- Q4. DEPARTMENT PERFORMANCE (for bar/radar chart)
-- ────────────────────────────────────────────────────────────
SELECT
    d.dept_id,
    d.dept_name,
    d.dept_code,
    d.head_name,
    COUNT(c.complaint_id)                                          AS total_assigned,
    SUM(CASE WHEN c.status IN ('resolved','closed') THEN 1 ELSE 0 END) AS resolved,
    SUM(CASE WHEN c.status = 'pending'              THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN c.status = 'in_progress'          THEN 1 ELSE 0 END) AS in_progress,
    ROUND(AVG(CASE WHEN c.status IN ('resolved','closed')
                   THEN c.resolution_hours END), 1)                AS avg_resolution_hrs,
    ROUND(SUM(CASE WHEN c.status IN ('resolved','closed') THEN 1 ELSE 0 END)
          * 100.0 / NULLIF(COUNT(c.complaint_id), 0), 1)           AS resolution_rate_pct,
    -- SLA compliance: resolved within SLA hours
    SUM(CASE WHEN c.status IN ('resolved','closed')
              AND c.resolution_hours <= p.sla_hours THEN 1 ELSE 0 END) AS within_sla,
    ROUND(SUM(CASE WHEN c.status IN ('resolved','closed')
                    AND c.resolution_hours <= p.sla_hours THEN 1 ELSE 0 END)
          * 100.0 / NULLIF(SUM(CASE WHEN c.status IN ('resolved','closed')
                                    THEN 1 ELSE 0 END), 0), 1)    AS sla_compliance_pct
FROM departments d
LEFT JOIN complaints c  ON d.dept_id      = c.dept_id
LEFT JOIN priorities  p ON c.priority_id  = p.priority_id
GROUP BY d.dept_id, d.dept_name, d.dept_code, d.head_name
ORDER BY resolution_rate_pct DESC;

-- ────────────────────────────────────────────────────────────
-- Q5. AVERAGE RESPONSE TIME ANALYTICS
-- ────────────────────────────────────────────────────────────
SELECT
    p.priority_name,
    p.sla_hours                                                    AS sla_target_hours,
    COUNT(c.complaint_id)                                          AS total_complaints,
    ROUND(AVG(c.resolution_hours), 2)                             AS avg_actual_hours,
    ROUND(MIN(c.resolution_hours), 2)                             AS min_hours,
    ROUND(MAX(c.resolution_hours), 2)                             AS max_hours,
    SUM(CASE WHEN c.resolution_hours <= p.sla_hours THEN 1 ELSE 0 END) AS within_sla,
    SUM(CASE WHEN c.resolution_hours >  p.sla_hours THEN 1 ELSE 0 END) AS breached_sla,
    ROUND(SUM(CASE WHEN c.resolution_hours <= p.sla_hours THEN 1 ELSE 0 END)
          * 100.0 / NULLIF(COUNT(c.complaint_id), 0), 1)          AS sla_compliance_pct
FROM priorities p
JOIN complaints c ON p.priority_id = c.priority_id
WHERE c.status IN ('resolved','closed')
  AND c.resolution_hours IS NOT NULL
GROUP BY p.priority_id, p.priority_name, p.sla_hours
ORDER BY p.priority_level;

-- ────────────────────────────────────────────────────────────
-- Q6. HIGH PRIORITY PENDING ISSUES (decision support)
-- ────────────────────────────────────────────────────────────
SELECT
    c.complaint_code,
    c.title,
    p.priority_name,
    p.color_code,
    cat.cat_name,
    l.area_name,
    l.ward_number,
    d.dept_name,
    TIMESTAMPDIFF(HOUR, c.submitted_at, NOW())                    AS age_hours,
    p.sla_hours                                                    AS sla_hours,
    CASE WHEN TIMESTAMPDIFF(HOUR, c.submitted_at, NOW()) > p.sla_hours
         THEN 'BREACHED' ELSE 'WITHIN SLA' END                    AS sla_status,
    TIMESTAMPDIFF(HOUR, c.submitted_at, NOW()) - p.sla_hours      AS hours_overdue,
    c.submitted_at
FROM complaints c
JOIN priorities  p  ON c.priority_id = p.priority_id
JOIN categories  cat ON c.cat_id     = cat.cat_id
JOIN locations   l  ON c.location_id = l.location_id
JOIN departments d  ON c.dept_id     = d.dept_id
WHERE c.status IN ('pending','assigned','in_progress')
  AND c.priority_id IN (1, 2)
ORDER BY p.priority_level, age_hours DESC
LIMIT 50;

-- ────────────────────────────────────────────────────────────
-- Q7. HOTSPOT DETECTION (areas with >15 complaints/30 days)
-- ────────────────────────────────────────────────────────────
SELECT
    l.location_id,
    l.ward_number,
    l.area_name,
    l.zone,
    l.latitude,
    l.longitude,
    COUNT(c.complaint_id)                                         AS total_30d,
    GROUP_CONCAT(DISTINCT cat.cat_name ORDER BY cat.cat_name SEPARATOR ', ') AS top_categories,
    SUM(CASE WHEN c.priority_id IN (1,2) THEN 1 ELSE 0 END)      AS high_priority_count,
    SUM(CASE WHEN c.status = 'pending'   THEN 1 ELSE 0 END)      AS unresolved_count,
    'HOTSPOT' AS zone_status
FROM complaints c
JOIN locations   l   ON c.location_id = l.location_id
JOIN categories  cat ON c.cat_id      = cat.cat_id
WHERE c.submitted_at >= NOW() - INTERVAL 30 DAY
GROUP BY l.location_id, l.ward_number, l.area_name, l.zone, l.latitude, l.longitude
HAVING total_30d >= 15
ORDER BY total_30d DESC;

-- ────────────────────────────────────────────────────────────
-- Q8. DASHBOARD KPI SUMMARY (for stat cards)
-- ────────────────────────────────────────────────────────────
SELECT
    COUNT(*)                                                       AS total_complaints,
    SUM(CASE WHEN status = 'pending'              THEN 1 ELSE 0 END) AS total_pending,
    SUM(CASE WHEN status = 'in_progress'          THEN 1 ELSE 0 END) AS total_in_progress,
    SUM(CASE WHEN status IN ('resolved','closed') THEN 1 ELSE 0 END) AS total_resolved,
    SUM(CASE WHEN priority_id = 1                 THEN 1 ELSE 0 END) AS total_critical,
    SUM(CASE WHEN is_hotspot_flag = 1             THEN 1 ELSE 0 END) AS total_hotspot,
    ROUND(AVG(resolution_hours), 1)                                AS avg_resolution_hrs,
    SUM(CASE WHEN submitted_at >= NOW() - INTERVAL 24 HOUR
             THEN 1 ELSE 0 END)                                    AS new_today,
    SUM(CASE WHEN submitted_at >= NOW() - INTERVAL 7  DAY
             THEN 1 ELSE 0 END)                                    AS new_this_week,
    ROUND(SUM(CASE WHEN status IN ('resolved','closed') THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                                   AS overall_resolution_pct
FROM complaints;

-- ────────────────────────────────────────────────────────────
-- Q9. CITIZEN COMPLAINT TRACKER (by user_id)
-- ────────────────────────────────────────────────────────────
-- (Replace :user_id with actual user ID)
SELECT
    c.complaint_code,
    c.title,
    c.status,
    cat.cat_name,
    l.area_name,
    p.priority_name,
    p.color_code,
    c.submitted_at,
    c.resolved_at,
    c.resolution_hours,
    d.dept_name,
    TIMESTAMPDIFF(HOUR, c.submitted_at, NOW()) AS age_hours,
    f.rating,
    f.comment AS feedback_comment
FROM complaints c
JOIN categories  cat ON c.cat_id      = cat.cat_id
JOIN locations   l   ON c.location_id = l.location_id
JOIN priorities  p   ON c.priority_id = p.priority_id
JOIN departments d   ON c.dept_id     = d.dept_id
LEFT JOIN feedback f ON c.complaint_id = f.complaint_id
WHERE c.user_id = 11   -- replace with :user_id
ORDER BY c.submitted_at DESC;

-- ────────────────────────────────────────────────────────────
-- Q10. WEEKLY RESOLUTION RATE (last 12 weeks)
-- ────────────────────────────────────────────────────────────
SELECT
    YEARWEEK(submitted_at, 1)                                      AS year_week,
    DATE_FORMAT(MIN(submitted_at), 'Week of %d %b')               AS week_label,
    COUNT(*)                                                        AS submitted,
    SUM(CASE WHEN status IN ('resolved','closed') THEN 1 ELSE 0 END) AS resolved,
    ROUND(SUM(CASE WHEN status IN ('resolved','closed') THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                                   AS resolution_rate_pct
FROM complaints
WHERE submitted_at >= NOW() - INTERVAL 12 WEEK
GROUP BY YEARWEEK(submitted_at, 1)
ORDER BY year_week;

-- ────────────────────────────────────────────────────────────
-- Q11. TOP RECURRING ISSUES (category + location combos)
-- ────────────────────────────────────────────────────────────
SELECT
    cat.cat_name,
    l.area_name,
    l.ward_number,
    d.dept_name,
    COUNT(*)                                                       AS occurrence_count,
    SUM(CASE WHEN c.status = 'pending' THEN 1 ELSE 0 END)         AS still_pending,
    ROUND(AVG(c.resolution_hours), 1)                             AS avg_resolution_hrs
FROM complaints c
JOIN categories  cat ON c.cat_id      = cat.cat_id
JOIN locations   l   ON c.location_id = l.location_id
JOIN departments d   ON c.dept_id     = d.dept_id
WHERE c.submitted_at >= NOW() - INTERVAL 90 DAY
GROUP BY cat.cat_id, l.location_id, d.dept_id,
         cat.cat_name, l.area_name, l.ward_number, d.dept_name
HAVING occurrence_count >= 3
ORDER BY occurrence_count DESC
LIMIT 20;

-- ────────────────────────────────────────────────────────────
-- Q12. CITIZEN SATISFACTION SCORE
-- ────────────────────────────────────────────────────────────
SELECT
    d.dept_name,
    COUNT(f.feedback_id)                                          AS total_feedback,
    ROUND(AVG(f.rating), 2)                                       AS avg_rating,
    SUM(CASE WHEN f.rating >= 4 THEN 1 ELSE 0 END)               AS satisfied,
    SUM(CASE WHEN f.rating <= 2 THEN 1 ELSE 0 END)               AS dissatisfied,
    ROUND(SUM(CASE WHEN f.rating >= 4 THEN 1 ELSE 0 END)
          * 100.0 / NULLIF(COUNT(f.feedback_id), 0), 1)          AS satisfaction_pct
FROM departments d
JOIN complaints c  ON d.dept_id     = c.dept_id
JOIN feedback   f  ON c.complaint_id = f.complaint_id
GROUP BY d.dept_id, d.dept_name
ORDER BY avg_rating DESC;
