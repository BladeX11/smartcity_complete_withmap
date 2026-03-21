import os
import re
import time
import threading
import smtplib
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


_WORKER_STARTED = False
_WORKER_LOCK = threading.Lock()


DEFAULT_TEMPLATES = {
    'complaint_received': {
        'subject': 'Complaint Received - {{complaint_code}}',
        'html': """
            <div style="font-family:Segoe UI,Arial,sans-serif;background:#0d1117;color:#e6edf3;padding:20px">
              <div style="max-width:640px;margin:0 auto;background:#161b22;border:1px solid #30363d;border-radius:12px;padding:20px">
                <h2 style="margin:0 0 10px;color:#00b0ff">SmartCity Complaint Received</h2>
                <p>Hello {{user_name}},</p>
                <p>Your complaint <strong>{{complaint_code}}</strong> has been received.</p>
                <p><strong>Category:</strong> {{category}}<br>
                   <strong>Location:</strong> {{location}}<br>
                   <strong>Priority:</strong> {{priority}}<br>
                   <strong>Estimated resolution:</strong> {{eta_hours}} hours</p>
                <p><a href="{{tracking_url}}" style="display:inline-block;background:#1565c0;color:#fff;text-decoration:none;padding:10px 14px;border-radius:8px">Track Complaint</a></p>
                <p style="font-size:13px;color:#8b949e">Next steps: We verify details → assign department → start field action.</p>
              </div>
            </div>
        """
    },
    'complaint_assigned': {
        'subject': 'Your complaint is now being handled - {{complaint_code}}',
        'html': '<p>Hello {{user_name}}, complaint {{complaint_code}} is now assigned to {{officer_name}}.</p>'
    },
    'complaint_in_progress': {
        'subject': 'Work started on your complaint - {{complaint_code}}',
        'html': '<p>Hello {{user_name}}, work has started for complaint {{complaint_code}}.</p>'
    },
    'complaint_resolved': {
        'subject': 'Complaint resolved - {{complaint_code}}',
        'html': '<p>Hello {{user_name}}, complaint {{complaint_code}} is marked resolved. Please verify and share feedback.</p>'
    },
    'reminder_pending_48h': {
        'subject': 'Status reminder - {{complaint_code}}',
        'html': '<p>Hello {{user_name}}, we have not forgotten your complaint {{complaint_code}}.</p>'
    },
    'reminder_feedback': {
        'subject': 'How did we do? - {{complaint_code}}',
        'html': '<p>Hello {{user_name}}, please rate your resolution experience for {{complaint_code}}.</p>'
    }
}


def _render_template(text, ctx):
    def replace(match):
        key = match.group(1).strip()
        return str(ctx.get(key, ''))
    return re.sub(r'{{\s*([^}]+)\s*}}', replace, text or '')


def _smtp_send(recipient, subject, html_body):
    host = os.environ.get('SMTP_HOST', '').strip()
    user = os.environ.get('SMTP_USER', '').strip()
    password = os.environ.get('SMTP_PASS', '').strip()
    sender = os.environ.get('SMTP_FROM_EMAIL', user).strip()
    sender_name = os.environ.get('SMTP_FROM_NAME', 'SmartCity Portal').strip()
    port = int(os.environ.get('SMTP_PORT', '587'))
    use_tls = os.environ.get('SMTP_USE_TLS', '1') == '1'

    if not host or not user or not password or not sender:
        return False, 'SMTP not configured'

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = f'{sender_name} <{sender}>'
    msg['To'] = recipient
    msg.attach(MIMEText(html_body, 'html', 'utf-8'))

    try:
        with smtplib.SMTP(host, port, timeout=20) as server:
            if use_tls:
                server.starttls()
            server.login(user, password)
            server.sendmail(sender, [recipient], msg.as_string())
        return True, None
    except Exception as ex:
        return False, str(ex)


def ensure_default_templates(query_db):
    rows = query_db('SELECT template_key FROM email_templates') if _has_table(query_db, 'email_templates') else []
    existing = {r['template_key'] for r in rows}
    for key, t in DEFAULT_TEMPLATES.items():
        if key in existing:
            continue
        query_db(
            '''INSERT INTO email_templates (template_key, subject_template, html_template, is_active)
               VALUES (%s, %s, %s, 1)''',
            (key, t['subject'], t['html']),
            commit=True
        )


def _has_table(query_db, table_name):
    row = query_db(
        '''SELECT COUNT(*) AS c
           FROM information_schema.tables
           WHERE table_schema = DATABASE() AND table_name = %s''',
        (table_name,),
        fetchone=True
    )
    return bool(row and row.get('c'))


def _get_complaint_context(query_db, complaint_id):
    return query_db(
        '''SELECT c.complaint_id, c.complaint_code, c.status, c.priority_id,
                  u.user_id, u.full_name AS user_name, u.email,
                  cat.cat_name AS category, l.area_name AS location,
                  p.priority_name AS priority,
                  COALESCE(ao.full_name, 'Assigned Officer') AS officer_name
           FROM complaints c
           JOIN users u ON c.user_id = u.user_id
           JOIN categories cat ON c.cat_id = cat.cat_id
           JOIN locations l ON c.location_id = l.location_id
           JOIN priorities p ON c.priority_id = p.priority_id
           LEFT JOIN users ao ON c.assigned_to = ao.user_id
           WHERE c.complaint_id = %s''',
        (complaint_id,),
        fetchone=True
    )


def _preferred_send_time(query_db, user_id, is_critical):
    if os.environ.get('EMAIL_FORCE_IMMEDIATE', '1') == '1':
        return datetime.now()
    now = datetime.now()
    if is_critical:
        return now

    if not _has_table(query_db, 'user_email_preferences'):
        return now

    pref = query_db(
        '''SELECT preferred_hour, frequency, quiet_hours_enabled, quiet_start_hour, quiet_end_hour
           FROM user_email_preferences WHERE user_id = %s''',
        (user_id,),
        fetchone=True
    ) or {}

    preferred_hour = int(pref.get('preferred_hour') or 9)
    quiet_enabled = int(pref.get('quiet_hours_enabled') or 1) == 1
    quiet_start = int(pref.get('quiet_start_hour') or 22)
    quiet_end = int(pref.get('quiet_end_hour') or 7)

    send_at = now.replace(hour=preferred_hour, minute=0, second=0, microsecond=0)
    if send_at <= now:
        send_at = send_at + timedelta(days=1)

    if quiet_enabled and (quiet_start <= now.hour or now.hour < quiet_end):
        send_at = now.replace(hour=quiet_end, minute=0, second=0, microsecond=0)
        if send_at <= now:
            send_at = send_at + timedelta(days=1)

    return send_at


def enqueue_notification(query_db, complaint_id, template_key, force_immediate=False):
    if not _has_table(query_db, 'email_queue'):
        return {'status': 'disabled'}

    ctx = _get_complaint_context(query_db, complaint_id)
    if not ctx:
        return {'status': 'skipped', 'reason': 'complaint_not_found'}

    is_critical = int(ctx.get('priority_id') or 4) == 1
    send_at = datetime.now() if (force_immediate or is_critical) else _preferred_send_time(query_db, ctx['user_id'], False)
    priority = 'critical' if is_critical else 'normal'
    idem = f"{complaint_id}:{template_key}:{ctx.get('status') or 'pending'}:{send_at.strftime('%Y%m%d%H')}"
    payload = {
        'template_key': template_key,
        'eta_hours': 24 if is_critical else 72
    }

    query_db(
        '''INSERT INTO email_queue
             (user_id, complaint_id, template_key, priority, status, scheduled_at, payload_json, idempotency_key)
           VALUES (%s, %s, %s, %s, 'queued', %s, %s, %s)
           ON DUPLICATE KEY UPDATE scheduled_at = VALUES(scheduled_at)''',
        (ctx['user_id'], complaint_id, template_key, priority, send_at, str(payload).replace("'", '"'), idem),
        commit=True
    )
    return {'status': 'queued', 'scheduled_at': send_at.isoformat(sep=' ', timespec='minutes')}


def _pick_template(query_db, template_key):
    if _has_table(query_db, 'email_templates'):
        row = query_db(
            '''SELECT subject_template, html_template
               FROM email_templates
               WHERE template_key = %s AND is_active = 1''',
            (template_key,),
            fetchone=True
        )
        if row:
            return row['subject_template'], row['html_template']
    base = DEFAULT_TEMPLATES.get(template_key, DEFAULT_TEMPLATES['complaint_received'])
    return base['subject'], base['html']


def _log_email_event(query_db, queue_row, recipient, subject, status, error=None):
    if _has_table(query_db, 'email_logs'):
        query_db(
            '''INSERT INTO email_logs
                 (queue_id, user_id, complaint_id, template_key, recipient_email, subject_rendered, delivery_status, event_at, metadata_json)
               VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), %s)''',
            (
                queue_row['queue_id'],
                queue_row['user_id'],
                queue_row['complaint_id'],
                queue_row['template_key'],
                recipient,
                subject,
                status,
                ('{"error":"%s"}' % str(error).replace('"', "'")) if error else None
            ),
            commit=True
        )


def process_email_queue(query_db, batch_size=10):
    if not _has_table(query_db, 'email_queue'):
        return 0

    if _has_table(query_db, 'email_templates'):
        ensure_default_templates(query_db)

    queued = query_db(
        '''SELECT queue_id, user_id, complaint_id, template_key, attempts, max_attempts
           FROM email_queue
           WHERE status = 'queued' AND scheduled_at <= NOW()
           ORDER BY priority = 'critical' DESC, scheduled_at ASC
           LIMIT %s''',
        (batch_size,)
    )
    sent_count = 0
    for q in queued:
        query_db(
            '''UPDATE email_queue
               SET status = 'processing', attempts = attempts + 1, updated_at = NOW()
               WHERE queue_id = %s''',
            (q['queue_id'],),
            commit=True
        )

        ctx = _get_complaint_context(query_db, q['complaint_id'])
        if not ctx:
            query_db(
                "UPDATE email_queue SET status='failed', last_error='Complaint not found' WHERE queue_id = %s",
                (q['queue_id'],),
                commit=True
            )
            continue

        pref_email = None
        if _has_table(query_db, 'user_email_preferences'):
            pref = query_db(
                'SELECT preferred_email, opted_out FROM user_email_preferences WHERE user_id = %s',
                (ctx['user_id'],),
                fetchone=True
            ) or {}
            if int(pref.get('opted_out') or 0) == 1 and q['template_key'] != 'complaint_received':
                query_db(
                    "UPDATE email_queue SET status='cancelled', last_error='User opted out' WHERE queue_id = %s",
                    (q['queue_id'],),
                    commit=True
                )
                continue
            pref_email = pref.get('preferred_email')

        recipient = pref_email or ctx.get('email')
        if not recipient:
            query_db(
                "UPDATE email_queue SET status='failed', last_error='No recipient email' WHERE queue_id = %s",
                (q['queue_id'],),
                commit=True
            )
            continue

        subject_t, html_t = _pick_template(query_db, q['template_key'])
        app_base = os.environ.get('APP_BASE_URL', 'http://127.0.0.1:5500/frontend')
        context = {
            'user_name': ctx.get('user_name') or 'Citizen',
            'complaint_code': ctx.get('complaint_code'),
            'category': ctx.get('category'),
            'location': ctx.get('location'),
            'priority': ctx.get('priority'),
            'eta_hours': 24 if int(ctx.get('priority_id') or 4) == 1 else 72,
            'tracking_url': f"{app_base}/pages/complaint_tracker.html",
            'officer_name': ctx.get('officer_name') or 'Assigned Officer',
        }
        subject = _render_template(subject_t, context)
        html = _render_template(html_t, context)
        ok, err = _smtp_send(recipient, subject, html)

        if ok:
            query_db(
                "UPDATE email_queue SET status='sent', sent_at = NOW(), last_error = NULL WHERE queue_id = %s",
                (q['queue_id'],),
                commit=True
            )
            query_db("UPDATE users SET last_email_sent = NOW() WHERE user_id = %s", (ctx['user_id'],), commit=True)
            _log_email_event(query_db, q, recipient, subject, 'sent')
            sent_count += 1
        else:
            final_fail = (int(q.get('attempts') or 0) + 1) >= int(q.get('max_attempts') or 5)
            query_db(
                "UPDATE email_queue SET status=%s, last_error=%s WHERE queue_id = %s",
                ('failed' if final_fail else 'queued', (err or 'send_failed')[:480], q['queue_id']),
                commit=True
            )
            _log_email_event(query_db, q, recipient, subject, 'failed', err)
    return sent_count


def start_email_worker(query_db):
    global _WORKER_STARTED
    with _WORKER_LOCK:
        if _WORKER_STARTED:
            return
        _WORKER_STARTED = True

    poll_seconds = int(os.environ.get('EMAIL_POLL_SECONDS', '20'))

    def _run():
        while True:
            try:
                process_email_queue(query_db, batch_size=10)
            except Exception:
                pass
            time.sleep(max(5, poll_seconds))

    thread = threading.Thread(target=_run, daemon=True, name='email-queue-worker')
    thread.start()
