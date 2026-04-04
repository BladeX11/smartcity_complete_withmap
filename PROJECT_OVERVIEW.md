# Smart City Crime Reporting & Analytics Platform

## Tech Stack

### Backend
- **Language:** Python 3.x
- **Framework:** Flask
- **Database:** SQL (custom schema, see `database/`)
- **Email Service:** Custom Python module
- **Machine Learning:** Resolution predictor (Python script)

### Frontend
- **HTML/CSS/JS:** Static web pages
- **UI Theme:** Modern, dark, neon-cyan-accented (per user preference)

### Project Structure
- `backend/` — Flask API, ML, email service
- `database/` — SQL schema, seed data, analytics queries
- `frontend/` — Static HTML pages (admin, user, map, tracker, etc.)

---

## Features

- **User Complaint Submission:** Citizens can submit crime complaints online
- **Complaint Tracking:** Users can track the status of their complaints
- **Admin Dashboard:** Admins can view, manage, and resolve complaints
- **City Crime Map:** Visual map of reported crimes
- **Analytics:** SQL-based analytics for crime trends
- **Email Notifications:** Automated updates to users
- **AI Resolution Prediction:** ML model predicts complaint resolution likelihood

---

## Workflow

1. **User submits complaint** via frontend form
2. **Backend API** receives and stores complaint in database
3. **Admin reviews** complaints in dashboard
4. **Complaint status** is updated by admin (resolved/pending)
5. **User tracks** complaint status via tracker page
6. **Email notifications** sent on status changes
7. **Analytics** and **crime map** updated in real-time
8. **ML model** predicts resolution probability for new complaints

---

## System Architecture

```mermaid
graph TD
    User[User]
    Admin[Admin]
    Frontend[Frontend (HTML/CSS/JS)]
    Backend[Backend (Flask API)]
    DB[(SQL Database)]
    Email[Email Service]
    ML[ML Resolution Predictor]
    Map[City Map]
    Analytics[Analytics Engine]

    User -- submits complaint --> Frontend
    Frontend -- API calls --> Backend
    Backend -- stores/fetches --> DB
    Backend -- triggers --> Email
    Backend -- invokes --> ML
    Backend -- serves data --> Frontend
    Frontend -- displays --> Map
    Frontend -- displays --> Analytics
    Admin -- manages --> Frontend
```

---

## Current Directory Structure

- backend/
  - app.py
  - crime_routes.py
  - email_service.py
  - requirements.txt
  - train_resolution_predictor.py
- database/
  - analytics_queries.sql
  - crime_schema.sql
  - phase1_ai_migration.sql
  - schema.sql
  - seed_data.sql
- frontend/
  - index.html
  - pages/
    - admin_complaints.html
    - admin_dashboard.html
    - city_map.html
    - complaint_tracker.html
    - crime_report.html
    - submit_complaint.html
- README.md
- IMPLEMENTATION_ROADMAP.md
- HOW_TO_RUN.html
- SETUP_GUIDE.html

---

*Last updated: April 1, 2026*