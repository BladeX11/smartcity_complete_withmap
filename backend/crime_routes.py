"""
CRIME & MAP API ROUTES
Add these routes to your existing app.py
(paste before the if __name__ == '__main__': line)
"""

# ══════════════════════════════════════════════════════════════
#  CRIME INCIDENT ENDPOINTS
# ══════════════════════════════════════════════════════════════

@app.route('/api/crimes', methods=['GET'])
def list_crimes():
    """All crime incidents with filters"""
    type_id  = request.args.get('type_id')
    loc_id   = request.args.get('location_id')
    severity = request.args.get('severity')
    status   = request.args.get('status')
    days     = int(request.args.get('days', 90))

    where = ['ci.incident_date >= CURDATE() - INTERVAL %s DAY']
    params = [days]

    if type_id:
        where.append('ci.crime_type_id = %s'); params.append(int(type_id))
    if loc_id:
        where.append('ci.location_id = %s'); params.append(int(loc_id))
    if severity:
        where.append('ct.severity = %s'); params.append(severity)
    if status:
        where.append('ci.status = %s'); params.append(status)

    rows = query_db(
        f'''SELECT ci.incident_id, ci.incident_code, ci.latitude, ci.longitude,
                   ci.incident_date, ci.incident_time, ci.time_of_day,
                   ci.description, ci.victim_count, ci.status,
                   ci.fir_number, ci.assigned_station, ci.is_hotspot_flag,
                   ci.address_detail,
                   ct.type_name, ct.type_code, ct.severity, ct.icon, ct.color_hex, ct.ipc_section,
                   l.area_name, l.ward_number, l.zone
            FROM crime_incidents ci
            JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
            JOIN locations   l  ON ci.location_id   = l.location_id
            WHERE {' AND '.join(where)}
            ORDER BY ci.incident_date DESC, ci.incident_time DESC''',
        params
    )
    return success(rows)


@app.route('/api/crimes/<int:incident_id>', methods=['GET'])
def get_crime(incident_id):
    """Single crime incident detail"""
    row = query_db(
        '''SELECT ci.*, ct.type_name, ct.type_code, ct.severity, ct.icon, ct.color_hex,
                  ct.ipc_section, l.area_name, l.ward_number, l.zone, l.latitude AS loc_lat,
                  l.longitude AS loc_lng
           FROM crime_incidents ci
           JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
           JOIN locations   l  ON ci.location_id   = l.location_id
           WHERE ci.incident_id = %s''',
        (incident_id,), fetchone=True
    )
    if not row:
        return error('Incident not found', 404)
    return success(row)


@app.route('/api/crimes/types', methods=['GET'])
def get_crime_types():
    rows = query_db('SELECT * FROM crime_types ORDER BY type_name')
    return success(rows)


# ══════════════════════════════════════════════════════════════
#  MAP DATA ENDPOINTS
# ══════════════════════════════════════════════════════════════

@app.route('/api/map/all-incidents', methods=['GET'])
def map_all_incidents():
    """Combined complaint + crime map data for the city map view"""
    days = int(request.args.get('days', 90))

    # Complaints with coordinates
    complaints = query_db(
        '''SELECT 'complaint' AS incident_type,
                  c.complaint_id AS id, c.complaint_code AS code,
                  cat.cat_name AS title, cat.cat_name AS sub_type, cat.icon_class AS icon,
                  p.color_code AS color, p.priority_name AS severity,
                  l.latitude AS lat, l.longitude AS lng,
                  l.area_name, l.ward_number, l.zone,
                  c.status, c.submitted_at AS event_time, c.is_hotspot_flag
           FROM complaints c
           JOIN categories cat ON c.cat_id      = cat.cat_id
           JOIN locations   l  ON c.location_id = l.location_id
           JOIN priorities  p  ON c.priority_id = p.priority_id
           WHERE l.latitude IS NOT NULL
             AND c.submitted_at >= NOW() - INTERVAL %s DAY''',
        (days,)
    )

    # Crime incidents
    crimes = query_db(
        '''SELECT 'crime' AS incident_type,
                  ci.incident_id AS id, ci.incident_code AS code,
                  ct.type_name AS title, ct.type_code AS sub_type, ct.icon,
                  ct.color_hex AS color, ct.severity,
                  ci.latitude AS lat, ci.longitude AS lng,
                  l.area_name, l.ward_number, l.zone,
                  ci.status,
                  CAST(ci.incident_date AS CHAR) AS event_time,
                  ci.is_hotspot_flag
           FROM crime_incidents ci
           JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
           JOIN locations   l  ON ci.location_id   = l.location_id
           WHERE ci.incident_date >= CURDATE() - INTERVAL %s DAY''',
        (days,)
    )

    return success({
        'complaints': complaints,
        'crimes': crimes,
        'total': len(complaints) + len(crimes)
    })


@app.route('/api/map/heatmap-data', methods=['GET'])
def heatmap_data():
    """Lat/lng + weight for heatmap overlay"""
    # Combine crimes and complaints weighted by severity/priority
    rows = query_db(
        '''SELECT lat, lng, weight FROM (
            -- Crimes (higher weight)
            SELECT ci.latitude AS lat, ci.longitude AS lng,
                   CASE ct.severity
                     WHEN 'critical' THEN 1.0
                     WHEN 'high'     THEN 0.75
                     WHEN 'moderate' THEN 0.5
                     ELSE 0.25
                   END AS weight
            FROM crime_incidents ci
            JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
            WHERE ci.incident_date >= CURDATE() - INTERVAL 30 DAY

            UNION ALL

            -- Complaints
            SELECT l.latitude, l.longitude,
                   CASE c.priority_id
                     WHEN 1 THEN 0.8
                     WHEN 2 THEN 0.6
                     WHEN 3 THEN 0.35
                     ELSE 0.15
                   END AS weight
            FROM complaints c
            JOIN locations l ON c.location_id = l.location_id
            WHERE c.submitted_at >= NOW() - INTERVAL 30 DAY
              AND l.latitude IS NOT NULL
        ) combined'''
    )
    return success(rows)


@app.route('/api/map/safety-scores', methods=['GET'])
def map_safety_scores():
    """Safety score per location for choropleth"""
    rows = query_db(
        '''SELECT lss.*, l.area_name, l.ward_number, l.zone,
                  l.latitude, l.longitude, l.pincode
           FROM location_safety_scores lss
           JOIN locations l ON lss.location_id = l.location_id
           ORDER BY lss.safety_score DESC'''
    )
    return success(rows)


@app.route('/api/map/hotspot-zones', methods=['GET'])
def hotspot_zones():
    """Combined hotspot analysis (crimes + complaints per location)"""
    rows = query_db(
        '''SELECT
              l.location_id, l.area_name, l.ward_number, l.zone,
              l.latitude, l.longitude,
              COALESCE(cr.crime_30d,  0) AS crime_count_30d,
              COALESCE(cp.comp_30d,   0) AS complaint_count_30d,
              COALESCE(cr.critical,   0) AS critical_crimes,
              COALESCE(cr.crime_30d,0) + COALESCE(cp.comp_30d,0) AS total_incidents,
              CASE
                WHEN COALESCE(cr.crime_30d,0) >= 10
                  OR COALESCE(cp.comp_30d,0)  >= 15 THEN 'critical'
                WHEN COALESCE(cr.crime_30d,0) >= 6
                  OR COALESCE(cp.comp_30d,0)  >= 10 THEN 'high'
                WHEN COALESCE(cr.crime_30d,0) >= 3
                  OR COALESCE(cp.comp_30d,0)  >= 5  THEN 'moderate'
                ELSE 'normal'
              END AS hotspot_level
           FROM locations l
           LEFT JOIN (
               SELECT location_id,
                      COUNT(*) AS crime_30d,
                      SUM(CASE WHEN ct.severity='critical' THEN 1 ELSE 0 END) AS critical
               FROM crime_incidents ci
               JOIN crime_types ct USING(crime_type_id)
               WHERE incident_date >= CURDATE() - INTERVAL 30 DAY
               GROUP BY location_id
           ) cr ON l.location_id = cr.location_id
           LEFT JOIN (
               SELECT location_id, COUNT(*) AS comp_30d
               FROM complaints
               WHERE submitted_at >= NOW() - INTERVAL 30 DAY
               GROUP BY location_id
           ) cp ON l.location_id = cp.location_id
           HAVING total_incidents > 0
           ORDER BY total_incidents DESC'''
    )
    return success(rows)


@app.route('/api/analytics/crime-stats', methods=['GET'])
@admin_required
def crime_stats():
    """Crime analytics for admin dashboard"""
    summary = query_db(
        '''SELECT
              COUNT(*) AS total_crimes,
              SUM(ct.severity='critical') AS critical,
              SUM(ct.severity='high')     AS high,
              SUM(ci.status='fir_filed' OR ci.status='chargesheet') AS fir_filed,
              SUM(ci.status='resolved')   AS resolved,
              SUM(ci.victim_count)        AS total_victims,
              AVG(ci.victim_count)        AS avg_victims_per_incident
           FROM crime_incidents ci
           JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id''',
        fetchone=True
    )

    by_type = query_db(
        '''SELECT ct.type_name, ct.severity, ct.color_hex,
                  COUNT(*) AS total,
                  SUM(ci.status='resolved') AS resolved
           FROM crime_incidents ci
           JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
           GROUP BY ct.crime_type_id, ct.type_name, ct.severity, ct.color_hex
           ORDER BY total DESC'''
    )

    by_time = query_db(
        '''SELECT time_of_day, COUNT(*) AS incidents
           FROM crime_incidents
           WHERE time_of_day != 'unknown'
           GROUP BY time_of_day
           ORDER BY incidents DESC'''
    )

    by_location = query_db(
        '''SELECT l.area_name, l.ward_number, COUNT(*) AS total,
                  SUM(ct.severity IN ('critical','high')) AS serious
           FROM crime_incidents ci
           JOIN locations l   ON ci.location_id   = l.location_id
           JOIN crime_types ct ON ci.crime_type_id = ct.crime_type_id
           WHERE ci.incident_date >= CURDATE() - INTERVAL 30 DAY
           GROUP BY l.location_id, l.area_name, l.ward_number
           ORDER BY total DESC LIMIT 10'''
    )

    return success({
        'summary': summary,
        'by_type': by_type,
        'by_time': by_time,
        'by_location': by_location
    })
