# SmartCity Complaint Analytics & Decision Support System
## Complete Setup Guide

---

## 📁 PROJECT FOLDER STRUCTURE

```
smartcity/
├── database/
│   ├── schema.sql              ← Full DB schema with tables, triggers, procedures, views
│   ├── seed_data.sql           ← 100 users + 500 complaints sample data
│   └── analytics_queries.sql  ← All 12 analytics SQL queries
│
├── backend/
│   ├── app.py                  ← Flask REST API (all endpoints)
│   └── requirements.txt        ← Python dependencies
│
└── frontend/
    ├── index.html              ← Home / Landing page (with charts)
    └── pages/
        ├── admin_dashboard.html    ← Admin analytics dashboard
        ├── admin_complaints.html   ← Complaint management table
        └── submit_complaint.html   ← Citizen complaint form
```

---

## 🗄️ STEP 1 — DATABASE SETUP (MySQL)

### Prerequisites
- MySQL 8.0+ installed
- MySQL Workbench or CLI access

### Commands

```bash
# 1. Login to MySQL
mysql -u root -p

# 2. Run schema (creates DB + all tables + triggers + procedures + views)
source /path/to/smartcity/database/schema.sql

# 3. Run seed data (100 users + 500 complaints)
source /path/to/smartcity/database/seed_data.sql

# 4. Verify setup
USE smartcity_db;
SELECT table_name, table_rows FROM information_schema.tables
WHERE table_schema = 'smartcity_db';

# 5. Test analytics view
SELECT * FROM vw_dept_performance;
SELECT * FROM vw_location_hotspot WHERE is_hotspot = 1;
```

### Tables Created
| Table            | Purpose                          | Rows (seed) |
|-----------------|----------------------------------|-------------|
| priorities      | Critical/High/Medium/Low levels  | 4           |
| departments     | 8 city departments               | 8           |
| categories      | 18 complaint categories          | 18          |
| locations       | 20 wards/areas                   | 20          |
| users           | 100 citizens + 10 officers/admin | 110         |
| complaints      | 500 complaints                   | 500         |
| status_updates  | Audit trail of status changes    | ~830        |
| feedback        | Citizen satisfaction ratings     | ~200        |
| analytics_logs  | Auto-logged events               | ~200        |

### Views Created
- `vw_complaint_detail` — Full complaint info with all JOINs
- `vw_location_hotspot` — Hotspot detection per ward
- `vw_dept_performance` — Resolution rate per department
- `vw_monthly_trend` — Month-wise complaint trends

---

## ⚙️ STEP 2 — BACKEND SETUP (Python Flask)

### Prerequisites
- Python 3.10+ installed
- pip package manager

### Installation

```bash
# 1. Navigate to backend folder
cd smartcity/backend

# 2. Create virtual environment
python -m venv venv

# 3. Activate
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# 4. Install dependencies
pip install -r requirements.txt

# 5. Configure database connection in app.py
# Edit DB_CONFIG block:
DB_CONFIG = {
    'host':     'localhost',
    'port':     3306,
    'user':     'root',
    'password': 'YOUR_MYSQL_PASSWORD',   # <-- change this
    'database': 'smartcity_db',
    'charset':  'utf8mb4',
}

# 6. Start Flask server
python app.py
# Server starts at: http://localhost:5000
```

### API Endpoints Summary

| Method | Endpoint                            | Description              |
|--------|-------------------------------------|--------------------------|
| POST   | /api/auth/register                  | Register citizen         |
| POST   | /api/auth/login                     | Login (any role)         |
| POST   | /api/auth/logout                    | Logout                   |
| GET    | /api/auth/me                        | Current user info        |
| GET    | /api/categories                     | All categories           |
| GET    | /api/locations                      | All locations            |
| GET    | /api/departments                    | All departments          |
| GET    | /api/complaints                     | List complaints (filtered)|
| GET    | /api/complaints/{id}                | Complaint detail         |
| POST   | /api/complaints                     | Submit complaint         |
| PUT    | /api/complaints/{id}/status         | Update status            |
| POST   | /api/complaints/{id}/feedback       | Submit feedback          |
| GET    | /api/analytics/kpi                  | Dashboard KPIs           |
| GET    | /api/analytics/by-location          | Complaints by location   |
| GET    | /api/analytics/by-category          | Complaints by category   |
| GET    | /api/analytics/monthly-trend        | Monthly trend data       |
| GET    | /api/analytics/department-performance | Dept performance       |
| GET    | /api/analytics/hotspots             | Hotspot locations        |
| GET    | /api/analytics/sla                  | SLA compliance           |
| GET    | /api/analytics/high-priority-pending | Priority pending list   |
| GET    | /api/health                         | DB health check          |

---

## 🎨 STEP 3 — FRONTEND SETUP

### Option A: Direct File Opening (No server needed)
The frontend works standalone with demo data built in. Simply:
```
Open smartcity/frontend/index.html in any browser
```

### Option B: With Live Backend
1. Start Flask (Step 2 above)
2. In each HTML file, ensure `DEMO_MODE = false`
3. The `const API = 'http://localhost:5000/api'` matches your Flask port
4. Open frontend in browser — live data will load from MySQL

### Page Navigation
```
index.html                → Home/Landing page
├── pages/admin_dashboard.html    → Admin: Analytics with charts
├── pages/admin_complaints.html   → Admin: Complaint management table
└── pages/submit_complaint.html   → Citizen: Complaint submission form
```

### Demo Login Credentials
```
Admin:   admin@smartcity.gov    / Admin@123
Citizen: aarav.sharma@gmail.com / Admin@123
Officer: eng1@smartcity.gov     / Admin@123
```

---

## 🧠 AUTOMATION LOGIC EXPLAINED

### 1. Auto-Priority Assignment (Stored Procedure)
```sql
CALL sp_auto_assign_priority(complaint_id, cat_id, location_id);
```
- Gets base priority from category default
- Counts complaints in same location+category in last 30 days
- **10+ complaints** → Critical (level 1)
- **5-9 complaints** → Bumped up one level
- **1-4 complaints** → Normal base level
- **0 complaints**   → Dropped one level (lower urgency)

### 2. Department Auto-Routing
Routes automatically via FK: `complaints.dept_id = categories.dept_id`
```
Road/Pothole     → Engineering & Roads (ENG)
Garbage          → Sanitation & Waste  (SAN)
Water/Sewage     → Water & Utilities   (UTIL)
Electricity      → Electricity Board   (ELEC)
Traffic Signal   → Transport & Traffic (TRAF)
```

### 3. Hotspot Detection (Stored Procedure)
```sql
CALL sp_detect_hotspots();  -- Run daily via cron
```
- Flags locations with **≥15 complaints** in last 30 days
- Sets `is_hotspot_flag = 1` on affected complaints
- Logs detection in `analytics_logs` with count and metadata

### 4. SLA Tracking (Trigger)
`trg_sla_check` fires on every complaint update:
- Compares `age_hours` against `priorities.sla_hours`
- Logs SLA breach to `analytics_logs` if exceeded
- SLA targets: Critical=4h, High=24h, Medium=72h, Low=168h

### 5. Response Time Calculation (Generated Column)
```sql
resolution_hours DECIMAL(8,2) GENERATED ALWAYS AS (
    TIMESTAMPDIFF(MINUTE, submitted_at, resolved_at) / 60.0
) STORED
```
Auto-calculated the moment `resolved_at` is set — no manual computation.

---

## 📊 KEY SQL QUERIES EXPLAINED

### Hotspot Query
```sql
SELECT l.area_name, COUNT(*) AS total_30d
FROM complaints c JOIN locations l USING(location_id)
WHERE c.submitted_at >= NOW() - INTERVAL 30 DAY
GROUP BY location_id HAVING total_30d >= 15;
```

### Department Performance Query
```sql
SELECT d.dept_name,
    ROUND(SUM(c.status IN ('resolved','closed')) * 100.0 / COUNT(*), 1) AS resolution_pct,
    ROUND(AVG(CASE WHEN c.status='resolved' THEN c.resolution_hours END), 1) AS avg_hrs
FROM departments d LEFT JOIN complaints c USING(dept_id)
GROUP BY d.dept_id;
```

### Monthly Trend Query
```sql
SELECT DATE_FORMAT(submitted_at,'%Y-%m') AS month,
    COUNT(*) AS total, SUM(status='resolved') AS resolved
FROM complaints
GROUP BY month ORDER BY month;
```

---

## 🧪 TESTING THE SYSTEM

### Test Database
```sql
-- Check complaint distribution
SELECT cat_name, COUNT(*) FROM complaints c JOIN categories cat USING(cat_id) GROUP BY cat_id;

-- Check hotspot detection
SELECT * FROM vw_location_hotspot WHERE is_hotspot = 1;

-- Check dept performance
SELECT * FROM vw_dept_performance ORDER BY resolution_rate_pct DESC;

-- Test auto-priority
CALL sp_auto_assign_priority(1, 6, 3);  -- Water Supply in Hadapsar

-- Check SLA compliance
SELECT priority_name, COUNT(*), AVG(resolution_hours)
FROM complaints c JOIN priorities p USING(priority_id)
WHERE status='resolved' GROUP BY priority_id;
```

### Test API (curl)
```bash
# Health check
curl http://localhost:5000/api/health

# Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@smartcity.gov","password":"Admin@123"}' \
  -c cookies.txt

# Get dashboard KPIs (admin only)
curl http://localhost:5000/api/analytics/kpi -b cookies.txt

# Submit complaint (citizen)
curl -X POST http://localhost:5000/api/complaints \
  -H "Content-Type: application/json" \
  -d '{"cat_id":1,"location_id":3,"title":"Large pothole","description":"Deep pothole on main road causing accidents"}' \
  -b cookies.txt
```

---

## 📚 DATABASE CONCEPTS DEMONSTRATED

| Concept                  | Where Used                                           |
|--------------------------|------------------------------------------------------|
| Primary Keys             | All 9 tables                                         |
| Foreign Keys             | 10+ FK relationships with cascade rules              |
| Normalization (3NF)      | All tables — no redundant columns                    |
| Stored Procedures        | Priority assignment, hotspot detection               |
| Triggers                 | Complaint code generation, status audit, SLA check   |
| Generated Columns        | `resolution_hours` auto-computed from timestamps     |
| Views                    | 4 analytics views for dashboard queries             |
| Indexes                  | 12+ indexes for query performance                    |
| JSON columns             | analytics_logs.meta_json for flexible metadata       |
| Window Functions         | Via GROUP BY + HAVING in analytics                   |
| Aggregate Functions      | COUNT, AVG, SUM, ROUND in every analytics query      |
| Date Functions           | TIMESTAMPDIFF, DATE_FORMAT, NOW(), INTERVAL          |
| Subqueries               | In category percentage calculation                   |
| CASE expressions         | Status distribution, priority coloring               |
| ENUM type                | complaint status, user role                          |
| Connection Pooling       | Flask MySQLConnectionPool (10 connections)            |

---

## 🚀 QUICK START (5 minutes)

```bash
# 1. Setup DB
mysql -u root -p < database/schema.sql
mysql -u root -p smartcity_db < database/seed_data.sql

# 2. Start backend
cd backend && pip install -r requirements.txt && python app.py

# 3. Open frontend
# In browser: open frontend/index.html
# Login as admin → see full dashboard with charts
```

**That's it! Full Smart City analytics system running in 5 minutes.**
