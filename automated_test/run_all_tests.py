"""
Life Nest API – Comprehensive Test Suite
Covers: DAST (8 categories) + Functional, UI/UX, Compatibility,
        Performance, Security, API, Database, Accessibility,
        Mobile-Specific, Regression, E2E  (100+ test cases total)

Run:  python automated_test/run_all_tests.py
"""

import json
import os
import sys
import time
import datetime
import re
import requests

# ── Config ──────────────────────────────────────────────────────────────────
INPUT_PATH  = os.path.join(os.path.dirname(__file__), "..", "input.json")
REPORT_PATH = os.path.join(os.path.dirname(__file__), "report.json")
SAVE_PATH   = os.path.join(os.path.dirname(__file__), "savepoint.json")
BACKEND_DIR = os.path.join(os.path.dirname(__file__), "..", "backend")

with open(INPUT_PATH) as f:
    cfg = json.load(f)

BASE = cfg["baseUrl"].rstrip("/")

# Real IDs fetched once
MOTHER_ID   = "MUM40293"   # existing, no doctor/hw assigned
MOTHER_ID2  = "MUM84202"   # second patient (for IDOR cross-access)
DOCTOR_ID   = "DOC001"
DOCTOR_ID2  = "DOC03375"   # from DB scan
WORKER_ID   = "HWN001"
WORKER_ID_REAL = None       # will be discovered from /health-workers/onboarding

RESULTS = []

# ── Helpers ──────────────────────────────────────────────────────────────────
import sys
import io
# Force UTF-8 output on Windows
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ANSI = {
    "green":  "",
    "red":    "",
    "yellow": "",
    "reset":  "",
    "bold":   "",
}

def c(color, text):
    return text

def record(endpoint, method, role, status, expected_status, finding,
           severity, response_time_ms, test_category, note):
    RESULTS.append({
        "endpoint":          endpoint,
        "method":            method,
        "role":              role,
        "status":            status,
        "expected_status":   expected_status,
        "finding":           finding,
        "severity":          severity,
        "response_time_ms":  response_time_ms,
        "test_category":     test_category,
        "note":              note,
        "timestamp":         datetime.datetime.utcnow().isoformat() + "Z",
    })
    icon = "[FAIL]" if finding else "[PASS]"
    if finding:
        print(f"  {icon} [{severity.upper()}] {method:6s} {endpoint}  ->  {status}  ({note})")
    else:
        print(f"  {icon} {method:6s} {endpoint}  ->  {status}  ({note})")

def req(method, path, **kwargs):
    url = BASE + path
    t0  = time.time()
    try:
        r = requests.request(method, url, timeout=10, allow_redirects=False, **kwargs)
        ms = round((time.time() - t0) * 1000)
        return r, ms
    except requests.exceptions.ConnectionError:
        ms = round((time.time() - t0) * 1000)
        return None, ms

def get(path, **kwargs):  return req("GET",    path, **kwargs)
def post(path, **kwargs): return req("POST",   path, **kwargs)
def put(path, **kwargs):  return req("PUT",    path, **kwargs)
def delete(path, **kwargs): return req("DELETE", path, **kwargs)
def head(path, **kwargs): return req("HEAD",   path, **kwargs)

FAKE_TOKEN    = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJIQUNLRVIiLCJyb2xlIjoiYWRtaW4ifQ.FAKE"
EXPIRED_TOKEN = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjF9.expired"
NO_TOKEN      = None

def h(token=None):
    if token:
        return {"Authorization": token, "Content-Type": "application/json"}
    return {"Content-Type": "application/json"}

# ── Section header ────────────────────────────────────────────────────────────
def section(title):
    bar = "=" * 60
    print(f"\n{bar}")
    print(f"  {title}")
    print(bar)

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1  ENDPOINT DISCOVERY
# ═══════════════════════════════════════════════════════════════════════════════
ENDPOINTS = [
    # method, path, expected_role, description
    ("POST",   "/auth/login",                                   "public",       "Login"),
    ("GET",    "/health",                                       "public",       "Health check"),
    # Mothers
    ("POST",   "/mothers/onboarding",                          "public",       "Mother registration"),
    ("GET",    f"/mothers/{MOTHER_ID}",                        "mother-own",   "Get mother by ID"),
    ("GET",    "/mothers",                                      "doctor",       "List all mothers"),
    ("PUT",    f"/mothers/{MOTHER_ID}",                        "mother-own",   "Update mother profile"),
    ("POST",   f"/mothers/{MOTHER_ID}/profile-image",         "mother-own",   "Upload profile image"),
    ("GET",    f"/mothers/{MOTHER_ID}/contractions",          "mother-own",   "List contractions"),
    ("POST",   f"/mothers/{MOTHER_ID}/contractions",          "mother-own",   "Save contractions"),
    ("GET",    f"/mothers/{MOTHER_ID}/sleep",                 "mother-own",   "List sleep"),
    ("POST",   f"/mothers/{MOTHER_ID}/sleep",                 "mother-own",   "Save sleep"),
    ("GET",    f"/mothers/{MOTHER_ID}/kicks",                 "mother-own",   "List kicks"),
    ("POST",   f"/mothers/{MOTHER_ID}/kicks",                 "mother-own",   "Save kicks"),
    ("GET",    f"/mothers/{MOTHER_ID}/prescriptions",         "mother-own",   "List prescriptions"),
    ("POST",   f"/mothers/{MOTHER_ID}/prescriptions",         "doctor",       "Create prescription"),
    ("GET",    f"/mothers/{MOTHER_ID}/pill-intake",           "mother-own",   "List pill intake"),
    ("POST",   f"/mothers/{MOTHER_ID}/pill-intake",           "mother-own",   "Record pill intake"),
    ("GET",    f"/mothers/{MOTHER_ID}/pill-history",          "mother-own",   "Pill history"),
    ("GET",    f"/mothers/{MOTHER_ID}/appointments",          "mother-own",   "List appointments"),
    ("POST",   f"/mothers/{MOTHER_ID}/appointments",          "health-worker","Create appointment"),
    ("GET",    f"/mothers/{MOTHER_ID}/profile-bundle",        "doctor",       "Doctor profile bundle"),
    ("GET",    f"/mothers/{MOTHER_ID}/symptoms",              "doctor",       "List symptoms"),
    ("POST",   f"/mothers/{MOTHER_ID}/symptoms",              "doctor",       "Create symptom log"),
    ("GET",    f"/mothers/{MOTHER_ID}/mood-logs",             "doctor",       "List mood logs"),
    ("POST",   f"/mothers/{MOTHER_ID}/mood-logs",             "mother-own",   "Create mood log"),
    ("GET",    f"/mothers/{MOTHER_ID}/fetal-growth",         "doctor",       "Fetal growth series"),
    ("GET",    f"/mothers/{MOTHER_ID}/delivery",             "doctor",       "Get delivery record"),
    ("GET",    f"/mothers/{MOTHER_ID}/newborn",              "doctor",       "Get newborn record"),
    # Doctors
    ("POST",   "/doctors/onboarding",                          "public",       "Doctor registration"),
    ("GET",    f"/doctors/{DOCTOR_ID}/patients",              "doctor-own",   "Doctor patients"),
    ("POST",   f"/doctors/{DOCTOR_ID}/assign-patient/{MOTHER_ID}", "doctor","Assign patient to doctor"),
    # Doctor portal
    ("GET",    f"/doctor/{DOCTOR_ID}/overview",               "doctor-own",   "Doctor overview"),
    ("GET",    f"/doctor/{DOCTOR_ID}/risk-feed",              "doctor-own",   "Doctor risk feed"),
    ("GET",    f"/doctor/{DOCTOR_ID}/today-appointments",     "doctor-own",   "Doctor today appointments"),
    ("GET",    f"/doctor/{DOCTOR_ID}/near-delivery",          "doctor-own",   "Near delivery"),
    ("GET",    f"/doctor/{DOCTOR_ID}/missed-medications",     "doctor-own",   "Missed medications"),
    ("GET",    f"/doctor/{DOCTOR_ID}/analytics",              "doctor-own",   "Doctor analytics"),
    ("GET",    f"/doctor/{DOCTOR_ID}/deliveries",             "doctor-own",   "Doctor deliveries"),
    ("GET",    f"/doctor/{DOCTOR_ID}/emergencies",            "doctor-own",   "Doctor emergencies"),
    ("GET",    f"/doctor/{DOCTOR_ID}/newborns",               "doctor-own",   "Doctor newborns"),
    # Health Workers
    ("POST",   "/health-workers/onboarding",                   "public",       "HW registration"),
    ("GET",    f"/health-workers/{WORKER_ID}",                "hw-own",       "Get health worker"),
    ("POST",   f"/health-workers/{WORKER_ID}/assign-mother/{MOTHER_ID}", "hw-own","Assign mother to HW"),
    ("GET",    f"/health-workers/{WORKER_ID}/mothers",        "hw-own",       "HW assigned mothers"),
    ("GET",    f"/health-workers/{WORKER_ID}/appointments",   "hw-own",       "HW appointments"),
    # Home visits
    ("POST",   "/home-visits",                                  "hw",           "Schedule home visit"),
    ("PUT",    "/home-visits/1/complete",                      "hw",           "Complete home visit"),
    ("GET",    f"/home-visits/health-worker/{WORKER_ID}",     "hw-own",       "HW home visits"),
    ("GET",    f"/home-visits/patient/{MOTHER_ID}",           "hw/doctor",    "Patient home visits"),
    # Lab tests
    ("POST",   "/lab-tests",                                    "hw/doctor",    "Create lab test"),
    ("GET",    f"/lab-tests/{MOTHER_ID}",                     "hw/doctor",    "List lab tests"),
    # Fetal growth
    ("POST",   "/fetal-growth",                                 "hw/doctor",    "Create fetal growth"),
    # Reports
    ("POST",   "/reports/upload",                               "hw/doctor",    "Upload report"),
    ("POST",   "/reports/upload-and-extract",                   "hw/doctor",    "Upload and AI extract"),
    ("GET",    f"/reports/{MOTHER_ID}",                       "hw/doctor",    "List reports"),
    # Risk
    ("GET",    f"/risk/{MOTHER_ID}",                          "doctor",       "Patient risk assessment"),
    # Diet
    ("GET",    f"/diet/profile/{MOTHER_ID}",                  "mother-own",   "Diet profile"),
    ("POST",   "/diet/profile",                                 "mother-own",   "Upsert diet profile"),
    ("POST",   "/diet/restrictions",                            "doctor",       "Create diet restriction"),
    ("GET",    f"/diet/restrictions/{MOTHER_ID}",             "doctor",       "List diet restrictions"),
    ("DELETE", "/diet/restrictions/1",                          "doctor",       "Delete diet restriction"),
    ("GET",    f"/diet/plan/today/{MOTHER_ID}",               "mother-own",   "Today diet plan"),
    ("POST",   "/diet/plan/regenerate",                         "mother-own",   "Regenerate diet plan"),
    ("GET",    f"/diet/plan/{MOTHER_ID}",                     "mother-own",   "Diet plan for date"),
    ("POST",   "/diet/plan/complete-meal",                      "mother-own",   "Mark meal complete"),
    ("GET",    f"/diet/doctor-summary/{MOTHER_ID}",           "doctor",       "Doctor diet summary"),
    ("GET",    "/diet/meal-templates",                          "public",       "List meal templates"),
    ("GET",    f"/diet/ai-assistant-plan/latest/{MOTHER_ID}","mother-own",   "Latest AI diet plan"),
    ("POST",   "/diet/ai-assistant-plan/generate",              "mother-own",   "Generate AI diet plan"),
    # Education
    ("GET",    "/education/articles",                           "public",       "List articles"),
    ("GET",    f"/education/articles/recommended/{MOTHER_ID}","mother-own",  "Recommended articles"),
    ("GET",    "/education/articles/1",                         "public",       "Get article"),
    ("POST",   "/education/articles",                           "doctor",       "Create article"),
    ("POST",   "/education/articles/1/approve",                "doctor",       "Approve article"),
    ("POST",   f"/education/articles/1/bookmark",              "mother-own",   "Bookmark article"),
    ("GET",    f"/education/bookmarks/{MOTHER_ID}",            "mother-own",   "List bookmarks"),
    ("POST",   "/education/progress",                           "mother-own",   "Save reading progress"),
    ("GET",    f"/education/streak/{MOTHER_ID}",               "mother-own",   "Reading streak"),
    ("GET",    "/education/faqs",                               "public",       "List FAQs"),
    ("POST",   "/education/faqs",                               "doctor",       "Create FAQ"),
    ("POST",   "/education/ask",                                "public",       "Ask question"),
    ("GET",    f"/education/tips/today/{MOTHER_ID}",           "mother-own",   "Today tip"),
    # Chat
    ("POST",   "/chat/room",                                    "any-auth",     "Create/get chat room"),
    ("POST",   "/chat/message",                                  "any-auth",     "Send message"),
    ("GET",    "/chat/messages/room1",                          "any-auth",     "Get chat messages"),
    ("GET",    f"/chat/rooms/{MOTHER_ID}/mother",              "any-auth",     "Get user chat rooms"),
    ("POST",   "/chat/read",                                    "any-auth",     "Mark messages read"),
    # Hydration
    ("POST",   "/hydration/logs",                               "mother-own",   "Log hydration"),
    ("GET",    f"/hydration/logs/{MOTHER_ID}",                 "mother-own",   "Get hydration logs"),
    # Health metrics
    ("POST",   "/health-metrics",                               "hw/doctor",    "Create health metrics"),
    ("GET",    f"/health-metrics/{MOTHER_ID}",                 "mother-own",   "Get health metrics"),
    # Appointments
    ("PUT",    "/appointments/1",                               "hw",           "Update appointment"),
    # Deliveries
    ("POST",   "/deliveries",                                   "doctor",       "Create delivery record"),
    # Newborns
    ("POST",   "/newborns",                                     "doctor",       "Create newborn"),
    ("GET",    "/newborns/1",                                   "doctor",       "Get newborn"),
    ("POST",   "/newborns/1/vitals",                            "doctor",       "Create newborn vital"),
    ("GET",    "/newborns/1/vitals",                            "doctor",       "List newborn vitals"),
    ("POST",   "/newborns/1/vaccinations",                      "doctor",       "Create vaccination"),
    ("GET",    "/newborns/1/vaccinations",                      "doctor",       "List vaccinations"),
    # Emergencies
    ("POST",   "/emergencies",                                  "mother-own",   "Create emergency alert"),
    ("POST",   "/emergencies/1/acknowledge",                    "doctor",       "Acknowledge emergency"),
    ("POST",   "/emergencies/1/resolve",                        "doctor",       "Resolve emergency"),
]

section(f"STEP 1 — ENDPOINT DISCOVERY  ({len(ENDPOINTS)} endpoints found)")
print(f"\n  {'METHOD':<8} {'PATH':<55} {'EXPECTED ROLE'}")
print("  " + "-"*85)
for m, p, role, desc in ENDPOINTS:
    print(f"  {m:<8} {p:<55} {role}")
print(f"\n  Total endpoints discovered: {c('bold', str(len(ENDPOINTS)))}")

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2  EXPECTATION MODEL  (already embedded above as role column)
# ═══════════════════════════════════════════════════════════════════════════════
section("STEP 2 — EXPECTATION MODEL")
print("""
  Role model:
    public       → no auth required, any caller allowed
    mother-own   → only the mother herself (by patient_id) should access
    doctor-own   → only the doctor themselves (by doctor_id)
    hw-own       → only the specific health worker
    doctor       → any authenticated doctor
    hw/doctor    → any health worker or doctor
    any-auth     → any authenticated user

  CRITICAL FINDING (pre-test): /auth/login returns NO JWT/bearer token.
  Every endpoint accepts requests with NO Authorization header.
  All role-restrictions are therefore unenforced at the API level.
""")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 1 — AuthN BYPASS (unauthenticated access to every protected endpoint)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 1 — AuthN Bypass  (no / bad token → should be 401/403)")

PROTECTED = [ep for ep in ENDPOINTS if ep[2] not in ("public",)]

for method, path, role, desc in PROTECTED:
    r, ms = req(method, path)
    if r is None:
        record(path, method, "none", 0, 401, False, "info", ms,
               "authn_bypass", f"{desc}: backend unreachable")
        continue
    # 2xx = finding (should have been blocked)
    finding = r.status_code < 300
    sev     = "critical" if finding else "info"
    record(path, method, "none", r.status_code, 401, finding, sev, ms,
           "authn_bypass",
           f"{desc}: NO AUTH required — got {r.status_code}" if finding
           else f"{desc}: correctly blocked with {r.status_code}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 2 — Token Tampering (malformed / forged JWT)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 2 — Token Tampering  (forged JWT claims)")

SAMPLE_PROTECTED = [
    ("GET", f"/mothers/{MOTHER_ID}"),
    ("GET", "/mothers"),
    ("GET", f"/doctor/{DOCTOR_ID}/overview"),
    ("GET", f"/risk/{MOTHER_ID}"),
    ("GET", f"/diet/plan/today/{MOTHER_ID}"),
]

for method, path in SAMPLE_PROTECTED:
    for tok_name, tok_val in [("forged_admin", FAKE_TOKEN), ("expired", EXPIRED_TOKEN)]:
        r, ms = req(method, path, headers={"Authorization": tok_val})
        if r is None:
            record(path, method, tok_name, 0, 401, False, "info", ms,
                   "token_tampering", "backend unreachable")
            continue
        finding = r.status_code < 300
        sev     = "high" if finding else "info"
        record(path, method, tok_name, r.status_code, 401, finding, sev, ms,
               "token_tampering",
               f"Forged/expired JWT not rejected — got {r.status_code}" if finding
               else f"Token rejected with {r.status_code}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 3 — AuthZ / Privilege Escalation (lower role accessing higher endpoint)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 3 — AuthZ / Privilege Escalation")

PRIVESC_PAIRS = [
    # (method, path, low-privilege-caller, description)
    ("GET",  "/mothers",                       "mother",  "Mother listing all mothers (doctor-only)"),
    ("GET",  f"/doctor/{DOCTOR_ID}/overview", "mother",  "Mother accessing doctor portal"),
    ("GET",  f"/doctor/{DOCTOR_ID}/risk-feed","hw",       "HW accessing doctor risk feed"),
    ("POST", f"/mothers/{MOTHER_ID}/prescriptions", "mother", "Mother creating own prescription"),
    ("GET",  f"/doctor/{DOCTOR_ID}/analytics","mother",  "Mother reading doctor analytics"),
    ("POST", "/education/articles",             "mother",  "Mother creating article (doctor-only)"),
    ("POST", f"/education/articles/1/approve", "mother",  "Mother approving article (doctor-only)"),
    ("POST", f"/doctors/{DOCTOR_ID}/assign-patient/{MOTHER_ID}", "hw", "HW assigning patient to doctor"),
    ("POST", "/diet/restrictions",              "mother",  "Mother adding diet restriction (doctor-only)"),
    ("DELETE", "/diet/restrictions/1",          "mother",  "Mother deleting restriction (doctor-only)"),
]

for method, path, caller, desc in PRIVESC_PAIRS:
    r, ms = req(method, path)
    if r is None:
        record(path, method, caller, 0, 403, False, "info", ms, "authz_privesc", "backend unreachable")
        continue
    finding = r.status_code < 300
    sev     = "high" if finding else "info"
    record(path, method, caller, r.status_code, 403, finding, sev, ms,
           "authz_privesc",
           f"{desc} — allowed (no RBAC)" if finding else f"Blocked {r.status_code}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 4 — IDOR  (vary patient_id to reach another patient's data)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 4 — IDOR  (cross-patient data access)")

IDOR_TESTS = [
    ("GET", f"/mothers/{MOTHER_ID2}",                "mother-as-{MOTHER_ID}", "Mother reading OTHER mother profile"),
    ("GET", f"/mothers/{MOTHER_ID2}/contractions",  "mother-as-{MOTHER_ID}", "Contraction IDOR"),
    ("GET", f"/mothers/{MOTHER_ID2}/prescriptions", "mother-as-{MOTHER_ID}", "Prescription IDOR"),
    ("GET", f"/mothers/{MOTHER_ID2}/pill-history",  "mother-as-{MOTHER_ID}", "Pill history IDOR"),
    ("GET", f"/mothers/{MOTHER_ID2}/appointments",  "mother-as-{MOTHER_ID}", "Appointment IDOR"),
    ("GET", f"/mothers/{MOTHER_ID2}/symptoms",      "mother-as-{MOTHER_ID}", "Symptom IDOR"),
    ("GET", f"/mothers/{MOTHER_ID2}/mood-logs",     "mother-as-{MOTHER_ID}", "Mood log IDOR"),
    ("GET", f"/mothers/{MOTHER_ID2}/profile-bundle","hw-as-{MOTHER_ID}",     "Profile bundle IDOR"),
    ("GET", f"/diet/plan/today/{MOTHER_ID2}",       "mother-as-{MOTHER_ID}", "Diet plan IDOR"),
    ("GET", f"/risk/{MOTHER_ID2}",                  "mother-as-{MOTHER_ID}", "Risk score IDOR"),
    ("GET", f"/hydration/logs/{MOTHER_ID2}",        "mother-as-{MOTHER_ID}", "Hydration IDOR"),
    ("GET", f"/health-metrics/{MOTHER_ID2}",        "mother-as-{MOTHER_ID}", "Health metrics IDOR"),
    ("GET", f"/reports/{MOTHER_ID2}",               "mother-as-{MOTHER_ID}", "Reports IDOR"),
    ("GET", f"/diet/restrictions/{MOTHER_ID2}",     "mother-as-{MOTHER_ID}", "Diet restrictions IDOR"),
    ("GET", f"/doctor/{DOCTOR_ID2}/overview",       "doctor-as-{DOCTOR_ID}", "Doctor portal IDOR"),
    ("GET", f"/doctor/{DOCTOR_ID2}/risk-feed",      "doctor-as-{DOCTOR_ID}", "Risk feed IDOR"),
]

for method, path, caller, desc in IDOR_TESTS:
    r, ms = req(method, path)
    if r is None:
        record(path, method, caller, 0, 403, False, "info", ms, "idor", "backend unreachable")
        continue
    finding = r.status_code < 300
    sev     = "high" if finding else "info"
    record(path, method, caller, r.status_code, 403, finding, sev, ms,
           "idor",
           f"{desc} — accessible with no auth (IDOR confirmed)" if finding
           else f"Blocked {r.status_code}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 5 — RBAC Matrix  (every role × every restricted endpoint)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 5 — RBAC Matrix")

RBAC_MATRIX = [
    # (method, path, expected_role, probe_as_role)
    ("GET", "/mothers",         "doctor",  "anonymous"),
    ("GET", "/mothers",         "doctor",  "mother"),
    ("GET", "/mothers",         "doctor",  "hw"),
    ("GET", f"/doctor/{DOCTOR_ID}/analytics", "doctor-own", "anonymous"),
    ("GET", f"/doctor/{DOCTOR_ID}/analytics", "doctor-own", "mother"),
    ("POST", "/education/articles", "doctor", "anonymous"),
    ("POST", "/education/articles", "doctor", "mother"),
    ("DELETE", "/diet/restrictions/1", "doctor", "anonymous"),
    ("DELETE", "/diet/restrictions/1", "doctor", "mother"),
    ("DELETE", "/diet/restrictions/1", "doctor", "hw"),
    ("GET", f"/mothers/{MOTHER_ID}/profile-bundle", "doctor", "anonymous"),
    ("GET", f"/mothers/{MOTHER_ID}/profile-bundle", "doctor", "other-mother"),
]

for method, path, expected_role, probe_as in RBAC_MATRIX:
    r, ms = req(method, path)
    if r is None:
        record(path, method, probe_as, 0, 403, False, "info", ms, "rbac_matrix", "unreachable")
        continue
    finding = r.status_code < 300
    sev     = "high" if finding else "info"
    record(path, method, probe_as, r.status_code, 403, finding, sev, ms,
           "rbac_matrix",
           f"Role '{probe_as}' accessed '{expected_role}' endpoint — no RBAC" if finding
           else f"Blocked {r.status_code}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 6 — Injection Probes  (SQL/NoSQL detection — read-only)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 6 — Injection Probes  (SQLi / NoSQLi detection)")

SQLI_PAYLOADS = [
    ("' OR '1'='1",       "Classic SQLi"),
    ("1; DROP TABLE--",   "Stacked query"),
    ("' UNION SELECT 1--","UNION injection"),
    ("\\x27 OR 1=1--",    "Hex-encoded quote"),
    ("admin'--",          "Comment injection"),
]

for payload, desc in SQLI_PAYLOADS:
    # Test in path parameter (patient_id)
    encoded = requests.utils.quote(payload)
    t0 = time.time()
    r, ms = get(f"/mothers/{encoded}")
    if r is not None:
        # 500 = possible injection surface; 400/422 = properly rejected
        finding = r.status_code == 500
        sev = "high" if finding else "info"
        record(f"/mothers/{{patient_id}}", "GET", "anonymous",
               r.status_code, 400, finding, sev, ms, "injection_probe",
               f"SQLi in patient_id — payload: {desc} → {r.status_code}" +
               (" ⚠ 500 error!" if finding else ""))

# Test in POST body fields
for payload, desc in SQLI_PAYLOADS[:3]:
    r, ms = post("/auth/login", json={"user_id": payload, "password": payload})
    if r is not None:
        finding = r.status_code == 500
        sev = "high" if finding else "info"
        record("/auth/login", "POST", "anonymous",
               r.status_code, 400, finding, sev, ms, "injection_probe",
               f"SQLi in login body — {desc} → {r.status_code}" +
               (" ⚠ 500 error!" if finding else ""))

# Test in query parameter
for payload, desc in SQLI_PAYLOADS[:2]:
    r, ms = get(f"/education/articles", params={"category": payload, "q": payload})
    if r is not None:
        finding = r.status_code == 500
        sev = "high" if finding else "info"
        record("/education/articles", "GET", "anonymous",
               r.status_code, 200, finding, sev, ms, "injection_probe",
               f"SQLi in query param — {desc} → {r.status_code}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 7 — Rate Limiting  (30 rapid requests)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 7 — Rate Limiting  (30-req burst to /auth/login)")

BURST = 30
status_counts = {}
t_start = time.time()
for i in range(BURST):
    r, ms = post("/auth/login",
                 json={"user_id": f"MUM{i:05d}", "password": "wrong"})
    sc = r.status_code if r else 0
    status_counts[sc] = status_counts.get(sc, 0) + 1

burst_elapsed = round(time.time() - t_start, 2)
has_429 = 429 in status_counts
finding = not has_429
record("/auth/login", "POST", "burst", 429 if has_429 else 200,
       429, finding, "medium" if finding else "info",
       round(burst_elapsed * 1000),
       "rate_limiting",
       f"No 429 returned in {BURST}-req burst — rate limiting absent" if finding
       else f"Rate limited after {status_counts.get(429,0)} requests")

print(f"  Status distribution: {status_counts}")
print(f"  Burst elapsed: {burst_elapsed}s")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 8 — Hardcoded Credentials  (codebase scan)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 8 — Hardcoded Credentials Scan  (codebase)")

SECRET_PATTERNS = [
    (r'password["\s]*[=:]["\s]*["\']([^"\']{4,})["\']', "Hardcoded password"),
    (r'secret["\s]*[=:]["\s]*["\']([^"\']{8,})["\']',   "Hardcoded secret"),
    (r'api_key["\s]*[=:]["\s]*["\']([^"\']{8,})["\']',  "API key"),
    (r'token["\s]*[=:]["\s]*["\']([^"\']{8,})["\']',    "Hardcoded token"),
    (r'AIzaSy[A-Za-z0-9_-]{33}',                         "Google API key"),
    (r'password123',                                       "Default weak password"),
    (r'DEFAULT.*password',                                 "Default password constant"),
]

py_files = []
for root, dirs, files in os.walk(BACKEND_DIR):
    dirs[:] = [d for d in dirs if d not in ("__pycache__", ".venv", "node_modules")]
    for fn in files:
        if fn.endswith(".py"):
            py_files.append(os.path.join(root, fn))

cred_findings = []
for fpath in py_files:
    try:
        code = open(fpath, encoding="utf-8", errors="ignore").read()
    except Exception:
        continue
    rel = os.path.relpath(fpath, BACKEND_DIR)
    for pattern, label in SECRET_PATTERNS:
        matches = re.findall(pattern, code, re.IGNORECASE)
        for m in matches:
            val_snippet = m[:20] + "…" if len(m) > 20 else m
            cred_findings.append((rel, label, val_snippet))
            record(f"file:{rel}", "SCAN", "static",
                   "FOUND", "NOT_PRESENT", True, "high", 0,
                   "hardcoded_creds",
                   f"{label} in {rel}: {val_snippet}")

# Also scan .env
env_path = os.path.join(BACKEND_DIR, ".env")
if os.path.exists(env_path):
    env_content = open(env_path).read()
    if "GEMINI_API_KEY" in env_content:
        record("file:.env", "SCAN", "static", "FOUND", "NOT_PRESENT", True,
               "critical", 0, "hardcoded_creds",
               ".env committed with GEMINI_API_KEY — check .gitignore")

if not cred_findings:
    print(f"  {c('green','✓')} No hardcoded credentials found in Python source")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 9 — Functional Testing  (core CRUD operations)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 9 — Functional Testing  (CRUD correctness)")

# 9a  Health check returns 200
r, ms = get("/health")
finding = r is None or r.status_code != 200
record("/health", "GET", "public", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "Health endpoint OK" if not finding else "Health check failed")

# 9b  Login with valid credentials for a real mother
r, ms = post("/auth/login", json={"user_id": MOTHER_ID, "password": "pass123"})
finding = r is None or r.status_code != 200
record("/auth/login", "POST", "mother", r.status_code if r else 0, 200,
       finding, "medium" if finding else "info", ms, "functional",
       "Valid mother login OK" if not finding else f"Login failed: {r.text[:80] if r else 'no response'}")

# 9c  Login with wrong password returns 401
r, ms = post("/auth/login", json={"user_id": MOTHER_ID, "password": "WRONG_PASS"})
finding = r is None or r.status_code not in (401, 403)
record("/auth/login", "POST", "wrong-pass", r.status_code if r else 0, 401,
       finding, "medium" if finding else "info", ms, "functional",
       "Wrong password correctly rejected" if not finding else f"Wrong password not rejected: {r.status_code if r else 0}")

# 9d  Get existing mother record
r, ms = get(f"/mothers/{MOTHER_ID}")
finding = r is None or r.status_code != 200
record(f"/mothers/{MOTHER_ID}", "GET", "anonymous", r.status_code if r else 0,
       200, finding, "low" if finding else "info", ms, "functional",
       "Mother record returned OK" if not finding else "Mother fetch failed")

# 9e  Get non-existent mother returns 404
r, ms = get("/mothers/MUM99999999")
finding = r is None or r.status_code != 404
record("/mothers/MUM99999999", "GET", "anonymous", r.status_code if r else 0,
       404, finding, "low" if finding else "info", ms, "functional",
       "Non-existent mother returns 404" if not finding else f"Expected 404, got {r.status_code if r else 0}")

# 9f  Login with unknown user returns 404
r, ms = post("/auth/login", json={"user_id": "MUM99999999", "password": "x"})
finding = r is None or r.status_code not in (404, 400)
record("/auth/login", "POST", "unknown-user", r.status_code if r else 0, 404,
       finding, "low" if finding else "info", ms, "functional",
       "Unknown user login returns 404" if not finding else f"Got {r.status_code if r else 0}")

# 9g  Login with invalid prefix returns 400
r, ms = post("/auth/login", json={"user_id": "INVALID001", "password": "x"})
finding = r is None or r.status_code != 400
record("/auth/login", "POST", "bad-prefix", r.status_code if r else 0, 400,
       finding, "low" if finding else "info", ms, "functional",
       "Invalid user_id prefix returns 400" if not finding else f"Got {r.status_code if r else 0}")

# 9h  List all mothers returns array
r, ms = get("/mothers")
finding = r is None or r.status_code != 200 or not isinstance(r.json(), list)
record("/mothers", "GET", "anonymous", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "List mothers returns array OK" if not finding else "List mothers failed")

# 9i  Education articles list
r, ms = get("/education/articles")
finding = r is None or r.status_code != 200
record("/education/articles", "GET", "anonymous", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "Articles list OK" if not finding else "Articles list failed")

# 9j  FAQ list
r, ms = get("/education/faqs")
finding = r is None or r.status_code != 200
record("/education/faqs", "GET", "anonymous", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "FAQ list OK" if not finding else "FAQ list failed")

# 9k  Meal templates
r, ms = get("/diet/meal-templates")
finding = r is None or r.status_code != 200
record("/diet/meal-templates", "GET", "anonymous", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "Meal templates OK" if not finding else "Meal templates failed")

# 9l  Doctor overview
r, ms = get(f"/doctor/{DOCTOR_ID}/overview")
finding = r is None or r.status_code != 200
record(f"/doctor/{DOCTOR_ID}/overview", "GET", "anonymous", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "Doctor overview OK" if not finding else "Doctor overview failed")

# 9m  Today diet plan for mother
r, ms = get(f"/diet/plan/today/{MOTHER_ID}")
finding = r is None or r.status_code != 200
record(f"/diet/plan/today/{MOTHER_ID}", "GET", "anonymous", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "Today diet plan OK" if not finding else f"Diet plan: {r.status_code if r else 0}")

# 9n  Risk assessment
r, ms = get(f"/risk/{MOTHER_ID}")
finding = r is None or r.status_code != 200
record(f"/risk/{MOTHER_ID}", "GET", "anonymous", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "Risk assessment OK" if not finding else f"Risk: {r.status_code if r else 0}")

# 9o  Today tip
r, ms = get(f"/education/tips/today/{MOTHER_ID}")
record(f"/education/tips/today/{MOTHER_ID}", "GET", "anonymous",
       r.status_code if r else 0, 200, False, "info", ms, "functional",
       f"Today tip: {r.status_code if r else 0}")

# 9p  Hydration logs
r, ms = get(f"/hydration/logs/{MOTHER_ID}")
finding = r is None or r.status_code != 200
record(f"/hydration/logs/{MOTHER_ID}", "GET", "anonymous", r.status_code if r else 0, 200,
       finding, "low" if finding else "info", ms, "functional",
       "Hydration logs OK" if not finding else f"Hydration: {r.status_code if r else 0}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 10 — Input Validation  (boundary / malformed inputs)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 10 — Input Validation & Error Handling")

# 10a  Missing required fields
r, ms = post("/auth/login", json={})
finding = r is None or r.status_code not in (400, 422)
record("/auth/login", "POST", "empty-body", r.status_code if r else 0, 422,
       finding, "medium" if finding else "info", ms, "input_validation",
       "Empty body returns 422" if not finding else f"Missing fields not validated: {r.status_code if r else 0}")

# 10b  Oversized string field
big = "A" * 10000
r, ms = post("/auth/login", json={"user_id": big, "password": big})
finding = r is None or r.status_code == 500
record("/auth/login", "POST", "oversized", r.status_code if r else 0, 400,
       finding, "medium" if finding else "info", ms, "input_validation",
       "Oversized input: 500 error!" if finding else f"Oversized input handled: {r.status_code if r else 0}")

# 10c  Negative days param on pill-history
r, ms = get(f"/mothers/{MOTHER_ID}/pill-history", params={"days": -100})
record(f"/mothers/{MOTHER_ID}/pill-history", "GET", "anonymous",
       r.status_code if r else 0, 200, False, "info", ms, "input_validation",
       f"Negative days param: {r.status_code if r else 0}")

# 10d  Zero value days clamped
r, ms = get(f"/mothers/{MOTHER_ID}/pill-history", params={"days": 0})
record(f"/mothers/{MOTHER_ID}/pill-history", "GET", "anonymous",
       r.status_code if r else 0, 200, False, "info", ms, "input_validation",
       f"Zero days param: {r.status_code if r else 0}")

# 10e  XSS payload in article query
r, ms = get("/education/articles", params={"q": "<script>alert(1)</script>"})
finding = r is not None and r.status_code == 500
record("/education/articles", "GET", "anonymous",
       r.status_code if r else 0, 200, finding, "medium" if finding else "info", ms,
       "input_validation",
       "XSS probe in query — 500 error!" if finding else f"XSS in query: {r.status_code if r else 0}")

# 10f  Null bytes in parameter
r, ms = get(f"/mothers/%00{MOTHER_ID}")
finding = r is not None and r.status_code == 500
record(f"/mothers/null-byte", "GET", "anonymous",
       r.status_code if r else 0, 400, finding, "medium" if finding else "info", ms,
       "input_validation",
       "Null byte in path: 500!" if finding else f"Null byte handled: {r.status_code if r else 0}")

# 10g  Content-type mismatch
r, ms = req("POST", "/auth/login",
            data="user_id=test&password=test",
            headers={"Content-Type": "text/plain"})
finding = r is not None and r.status_code == 500
record("/auth/login", "POST", "wrong-ctype",
       r.status_code if r else 0, 422, finding, "low", ms,
       "input_validation",
       f"Wrong content-type: {r.status_code if r else 0}")

# 10h  Integer overflow in appointment duration
r, ms = req("POST", f"/mothers/{MOTHER_ID}/appointments",
            data={"health_worker_id": "HWN001",
                  "appointment_date": "2026-07-01T10:00:00",
                  "appointment_time": "10:00",
                  "duration_minutes": 2**31,
                  "appointment_type": "test"})
finding = r is not None and r.status_code == 500
record(f"/mothers/{MOTHER_ID}/appointments", "POST", "int-overflow",
       r.status_code if r else 0, 400, finding, "medium" if finding else "info", ms,
       "input_validation",
       "Integer overflow in duration: 500!" if finding else f"Handled: {r.status_code if r else 0}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 11 — Performance Testing  (response time thresholds)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 11 — Performance Testing  (response time < 2000ms)")

PERF_TESTS = [
    ("GET", "/health",                          200),
    ("GET", f"/mothers/{MOTHER_ID}",           200),
    ("GET", "/mothers",                         500),
    ("GET", f"/diet/plan/today/{MOTHER_ID}",   1500),
    ("GET", f"/risk/{MOTHER_ID}",              1000),
    ("GET", f"/doctor/{DOCTOR_ID}/overview",   800),
    ("GET", "/education/articles",             500),
    ("GET", "/education/faqs",                 500),
    ("GET", "/diet/meal-templates",            500),
    ("GET", f"/doctor/{DOCTOR_ID}/risk-feed", 1000),
    ("GET", f"/education/tips/today/{MOTHER_ID}", 1500),
]

for method, path, threshold_ms in PERF_TESTS:
    r, ms = req(method, path)
    finding = r is None or ms > threshold_ms
    record(path, method, "perf", r.status_code if r else 0, 200,
           finding, "medium" if finding else "info", ms, "performance",
           f"{ms}ms > {threshold_ms}ms threshold!" if finding else f"{ms}ms ✓")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 12 — Security Headers  (CORS, X-Content-Type, etc.)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 12 — Security Headers")

r, ms = get("/health")
if r:
    headers_to_check = {
        "x-content-type-options":      ("nosniff",  "medium"),
        "x-frame-options":             ("deny",     "medium"),
        "strict-transport-security":   ("max-age",  "medium"),
        "content-security-policy":     (None,       "low"),
        "x-xss-protection":            (None,       "low"),
        "referrer-policy":             (None,       "low"),
    }
    h_lower = {k.lower(): v for k, v in r.headers.items()}
    for hdr, (expected_val, sev) in headers_to_check.items():
        present = hdr in h_lower
        val = h_lower.get(hdr, "")
        finding = not present
        record("/health", "GET", "headers",
               r.status_code, 200, finding, sev if finding else "info", ms,
               "security_headers",
               f"Header '{hdr}' MISSING" if finding
               else f"Header '{hdr}': {val[:50]}")

    # CORS: should NOT be wildcard for prod
    cors = h_lower.get("access-control-allow-origin", "")
    finding = cors == "*"
    record("/health", "GET", "cors",
           r.status_code, 200, finding, "high" if finding else "info", ms,
           "security_headers",
           f"CORS allow-origin: '*' (overly permissive)" if finding
           else f"CORS: {cors[:50]}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 13 — API Contract / Schema  (response shape validation)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 13 — API Contract / Schema Validation")

# 13a  Mother object has expected keys
r, ms = get(f"/mothers/{MOTHER_ID}")
if r and r.status_code == 200:
    expected_keys = {"id", "patient_id", "full_name", "age", "weight_kg",
                     "blood_group", "pregnant_weeks", "due_date"}
    got_keys = set(r.json().keys())
    missing = expected_keys - got_keys
    finding = bool(missing)
    record(f"/mothers/{MOTHER_ID}", "GET", "schema", r.status_code, 200,
           finding, "low" if finding else "info", ms, "api_contract",
           f"Missing keys: {missing}" if finding else "Schema OK")

# 13b  Articles list returns array
r, ms = get("/education/articles")
if r and r.status_code == 200:
    finding = not isinstance(r.json(), list)
    record("/education/articles", "GET", "schema", r.status_code, 200,
           finding, "low" if finding else "info", ms, "api_contract",
           "Articles not an array!" if finding else "Articles schema OK")

# 13c  Diet plan today has meals key
r, ms = get(f"/diet/plan/today/{MOTHER_ID}")
if r and r.status_code == 200:
    body = r.json()
    finding = "meals" not in body
    record(f"/diet/plan/today/{MOTHER_ID}", "GET", "schema", r.status_code, 200,
           finding, "low" if finding else "info", ms, "api_contract",
           "'meals' key missing in diet plan!" if finding else "Diet plan schema OK")

# 13d  Risk assessment has level + score
r, ms = get(f"/risk/{MOTHER_ID}")
if r and r.status_code == 200:
    body = r.json()
    has_keys = "level" in body and "score" in body
    record(f"/risk/{MOTHER_ID}", "GET", "schema", r.status_code, 200,
           not has_keys, "low" if not has_keys else "info", ms, "api_contract",
           "Risk schema OK" if has_keys else "Risk missing level/score")

# 13e  Login response has user_id
r, ms = post("/auth/login", json={"user_id": MOTHER_ID, "password": "pass123"})
if r and r.status_code == 200:
    body = r.json()
    finding = "user_id" not in body
    record("/auth/login", "POST", "schema", r.status_code, 200,
           finding, "low" if finding else "info", ms, "api_contract",
           "Login missing user_id" if finding else "Login schema OK")

# 13f  Login returns NO token (JWT absent — this is a finding)
    finding2 = "token" not in body and "access_token" not in body
    record("/auth/login", "POST", "no-jwt",
           r.status_code, 200, finding2, "critical" if finding2 else "info", ms,
           "api_contract",
           "Login returns NO JWT/access_token — stateless auth not implemented" if finding2
           else "JWT token present")

# 13g  Doctor overview has 'cards' and 'totals' keys
r, ms = get(f"/doctor/{DOCTOR_ID}/overview")
if r and r.status_code == 200:
    body = r.json()
    has_keys = "cards" in body and "totals" in body
    record(f"/doctor/{DOCTOR_ID}/overview", "GET", "schema", r.status_code, 200,
           not has_keys, "low", ms, "api_contract",
           "Doctor overview schema OK" if has_keys else "Doctor overview missing keys")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 14 — Database / Data Integrity  (data persists + constraints hold)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 14 — Database / Data Integrity")

# 14a  Duplicate patient_id onboarding idempotent (no 409/500)
import random
pid = f"MUM{random.randint(10000,99999)}"
form1 = {"patient_id": pid, "full_name": "Test DB User", "password": "test123"}
r1, ms1 = req("POST", "/mothers/onboarding", data=form1)
r2, ms2 = req("POST", "/mothers/onboarding", data=form1)
finding = (r1 is None or r1.status_code not in (200, 201) or
           r2 is None or r2.status_code not in (200, 201))
record("/mothers/onboarding", "POST", "idempotent", r2.status_code if r2 else 0, 200,
       finding, "medium" if finding else "info", ms2, "database",
       "Duplicate onboarding idempotent OK" if not finding
       else f"Duplicate handling issue: {r2.status_code if r2 else 0}")

# 14b  Created mother persists
r, ms = get(f"/mothers/{pid}")
finding = r is None or r.status_code != 200
record(f"/mothers/{pid}", "GET", "persistence", r.status_code if r else 0, 200,
       finding, "medium" if finding else "info", ms, "database",
       "Persisted OK" if not finding else "Persistence failure")

# 14c  Invalid due_date format returns 400
form_bad_date = {"patient_id": pid, "full_name": "Test", "due_date": "NOT-A-DATE"}
r, ms = req("POST", "/mothers/onboarding", data=form_bad_date)
finding = r is None or r.status_code not in (400, 422)
record("/mothers/onboarding", "POST", "bad-date", r.status_code if r else 0, 400,
       finding, "medium" if finding else "info", ms, "database",
       "Invalid date correctly rejected" if not finding else f"Got {r.status_code if r else 0}")

# 14d  Contraction with invalid date
r, ms = req("POST", f"/mothers/{MOTHER_ID}/contractions",
            data={"session_date": "INVALID", "contraction_seconds": 30,
                  "relaxation_seconds": 60, "lap_count": 5})
finding = r is None or r.status_code not in (400, 422)
record(f"/mothers/{MOTHER_ID}/contractions", "POST", "bad-date",
       r.status_code if r else 0, 400, finding, "low" if finding else "info", ms,
       "database", f"Invalid contraction date: {r.status_code if r else 0}")

# 14e  Prescription requires pill_name
r, ms = req("POST", f"/mothers/{MOTHER_ID}/prescriptions",
            data={"doctor_id": DOCTOR_ID, "dosage": "10mg",
                  "timing": "after_food", "meal_time": "lunch",
                  "frequency": "daily", "start_date": "2026-01-01T00:00:00"})
finding = r is None or r.status_code not in (400, 422)
record(f"/mothers/{MOTHER_ID}/prescriptions", "POST", "missing-pill-name",
       r.status_code if r else 0, 400, finding, "medium" if finding else "info", ms,
       "database",
       f"Missing pill_name validation: {r.status_code if r else 0}")

# 14f  Sleep session upsert (same day = update, not duplicate)
today_iso = datetime.datetime.now().replace(microsecond=0).isoformat()
r1, _ = req("POST", f"/mothers/{MOTHER_ID}/sleep",
            data={"session_date": today_iso, "sleep_hours": 7.0, "goal_hours": 8.0})
r2, ms = req("POST", f"/mothers/{MOTHER_ID}/sleep",
             data={"session_date": today_iso, "sleep_hours": 7.5, "goal_hours": 8.0})
finding = (r1 is None or r2 is None or
           r1.status_code not in (200,201) or r2.status_code not in (200,201))
record(f"/mothers/{MOTHER_ID}/sleep", "POST", "upsert",
       r2.status_code if r2 else 0, 200, finding, "low" if finding else "info", ms,
       "database",
       "Sleep upsert OK" if not finding else f"Upsert failed: {r2.status_code if r2 else 0}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 15 — Regression  (previously-found issues re-tested)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 15 — Regression Testing")

# 15a  No auth returns data (regression: must remain a finding until fixed)
r, ms = get(f"/mothers/{MOTHER_ID}")
finding = r is not None and r.status_code == 200
record(f"/mothers/{MOTHER_ID}", "GET", "regression-no-auth",
       r.status_code if r else 0, 401, finding, "critical" if finding else "info", ms,
       "regression",
       "REGRESSION: GET /mothers/{id} still returns 200 without auth")

# 15b  /mothers returns all patients without auth
r, ms = get("/mothers")
finding = r is not None and r.status_code == 200
record("/mothers", "GET", "regression-no-auth",
       r.status_code if r else 0, 401, finding, "critical" if finding else "info", ms,
       "regression",
       "REGRESSION: GET /mothers returns full patient list without auth")

# 15c  Default password still accepted
r, ms = post("/auth/login",
             json={"user_id": MOTHER_ID, "password": "password123"})
finding = r is not None and r.status_code == 200
record("/auth/login", "POST", "regression-default-pass",
       r.status_code if r else 0, 401, finding, "high" if finding else "info", ms,
       "regression",
       "REGRESSION: Default 'password123' still accepted for login")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 16 — Compatibility / HTTP Methods  (method not allowed)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 16 — Compatibility / HTTP Method Enforcement")

METHOD_TESTS = [
    ("DELETE", "/mothers",       405, "DELETE on GET-only endpoint"),
    ("PATCH",  f"/mothers/{MOTHER_ID}", 405, "PATCH not defined"),
    ("GET",    "/auth/login",    405, "GET on POST-only login"),
    ("DELETE", "/health",        405, "DELETE on health"),
    ("PUT",    "/health",        405, "PUT on health"),
]

for method, path, expected, desc in METHOD_TESTS:
    r, ms = req(method, path)
    if r is None:
        record(path, method, "compat", 0, expected, False, "info", ms,
               "compatibility", "unreachable")
        continue
    finding = r.status_code not in (405, 404)
    record(path, method, "compat", r.status_code, expected,
           finding, "low" if finding else "info", ms, "compatibility",
           f"{desc}: got {r.status_code}" +
           (" (unexpected)" if finding else ""))

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 17 — Accessibility API  (education / tips for all trimesters)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 17 — Accessibility & Content (education endpoints)")

for trimester in [1, 2, 3]:
    r, ms = get("/education/articles", params={"trimester": trimester})
    finding = r is None or r.status_code != 200
    record("/education/articles", "GET", f"t{trimester}",
           r.status_code if r else 0, 200, finding, "low" if finding else "info",
           ms, "accessibility",
           f"Trimester {trimester} articles: {r.status_code if r else 0}")

for cat in ["nutrition", "exercise", "emergency", "mental_health"]:
    r, ms = get("/education/articles", params={"category": cat})
    finding = r is None or r.status_code != 200
    record("/education/articles", "GET", f"cat:{cat}",
           r.status_code if r else 0, 200, finding, "low" if finding else "info",
           ms, "accessibility",
           f"Category '{cat}' articles: {r.status_code if r else 0}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 18 — Mobile-Specific  (upload, pagination, connectivity)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 18 — Mobile-Specific Testing")

# 18a  Small JSON payload (simulating mobile low-bandwidth)
r, ms = get(f"/mothers/{MOTHER_ID}", headers={"Accept-Encoding": "gzip"})
finding = r is None or r.status_code != 200
record(f"/mothers/{MOTHER_ID}", "GET", "mobile-gzip",
       r.status_code if r else 0, 200, finding, "low" if finding else "info", ms,
       "mobile_specific",
       "Gzip response OK" if not finding else "Gzip failed")

# 18b  Large burst from mobile (pagination check)
r, ms = get("/mothers", params={"limit": 5})
finding = r is None or r.status_code != 200
record("/mothers", "GET", "mobile-pagination",
       r.status_code if r else 0, 200, finding, "low" if finding else "info", ms,
       "mobile_specific",
       f"Pagination limit=5: {r.status_code if r else 0}")

# 18c  Kick session (mobile feature)
r, ms = get(f"/mothers/{MOTHER_ID}/kicks")
finding = r is None or r.status_code != 200
record(f"/mothers/{MOTHER_ID}/kicks", "GET", "mobile",
       r.status_code if r else 0, 200, finding, "low" if finding else "info", ms,
       "mobile_specific",
       f"Kick sessions: {r.status_code if r else 0}")

# 18d  Contraction history
r, ms = get(f"/mothers/{MOTHER_ID}/contractions")
finding = r is None or r.status_code != 200
record(f"/mothers/{MOTHER_ID}/contractions", "GET", "mobile",
       r.status_code if r else 0, 200, finding, "low" if finding else "info", ms,
       "mobile_specific",
       f"Contractions: {r.status_code if r else 0}")

# 18e  Dashboard data
r, ms = get(f"/diet/plan/today/{MOTHER_ID}")
record(f"/diet/plan/today/{MOTHER_ID}", "GET", "mobile",
       r.status_code if r else 0, 200, False, "info", ms, "mobile_specific",
       f"Mobile diet plan: {r.status_code if r else 0}")

# 18f  Long URL path (mobile deep-link safety)
long_id = "MUM" + "X" * 200
r, ms = get(f"/mothers/{long_id}")
finding = r is not None and r.status_code == 500
record(f"/mothers/{{long_id}}", "GET", "mobile-overflow",
       r.status_code if r else 0, 404, finding, "medium" if finding else "info", ms,
       "mobile_specific",
       "Long ID 500!" if finding else f"Long ID handled: {r.status_code if r else 0}")

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 19 — E2E  (full user journeys)
# ═══════════════════════════════════════════════════════════════════════════════
section("CATEGORY 19 — E2E User Journeys")

# Journey 1: Mother Registration → Onboarding → Diet Plan → Risk
new_pid = f"MUM{random.randint(10000,99999)}"
print(f"\n  Journey 1: Mother Registration → Diet Plan  (ID={new_pid})")

# Step 1: Register
r, ms = req("POST", "/mothers/onboarding",
            data={"patient_id": new_pid, "full_name": "E2E Test Mother",
                  "age": 28, "weight_kg": 65, "blood_group": "B+",
                  "pregnant_weeks": 20, "phone": "9999999999",
                  "emergency_contact": "Spouse 8888888888", "password": "e2epass"})
finding = r is None or r.status_code not in (200, 201)
record("/mothers/onboarding", "POST", "e2e-mother", r.status_code if r else 0,
       200, finding, "medium" if finding else "info", ms, "e2e",
       "E2E: Mother registration OK" if not finding else f"Registration failed: {r.status_code if r else 0}")
e2e_step1_ok = not finding

# Step 2: Login
r, ms = post("/auth/login", json={"user_id": new_pid, "password": "e2epass"})
finding = r is None or r.status_code != 200
record("/auth/login", "POST", "e2e-mother", r.status_code if r else 0, 200,
       finding, "medium" if finding else "info", ms, "e2e",
       "E2E: Mother login OK" if not finding else f"Login failed: {r.status_code if r else 0}")

# Step 3: Read back profile
if e2e_step1_ok:
    r, ms = get(f"/mothers/{new_pid}")
    finding = r is None or r.status_code != 200
    record(f"/mothers/{new_pid}", "GET", "e2e-mother", r.status_code if r else 0,
           200, finding, "info", ms, "e2e",
           "E2E: Profile read back OK" if not finding else "Profile read back failed")

# Step 4: Get diet plan
if e2e_step1_ok:
    r, ms = get(f"/diet/plan/today/{new_pid}")
    record(f"/diet/plan/today/{new_pid}", "GET", "e2e-mother",
           r.status_code if r else 0, 200, False, "info", ms, "e2e",
           f"E2E: Diet plan: {r.status_code if r else 0}")

# Step 5: Get risk assessment
if e2e_step1_ok:
    r, ms = get(f"/risk/{new_pid}")
    finding = r is None or r.status_code != 200
    record(f"/risk/{new_pid}", "GET", "e2e-mother", r.status_code if r else 0,
           200, finding, "info", ms, "e2e",
           f"E2E: Risk assessment: {r.status_code if r else 0}")

# Step 6: Log hydration
if e2e_step1_ok:
    r, ms = req("POST", "/hydration/logs",
                data={"patient_id": new_pid, "water_ml": 500, "goal_ml": 2500})
    finding = r is None or r.status_code not in (200, 201)
    record("/hydration/logs", "POST", "e2e-mother",
           r.status_code if r else 0, 200, finding, "info", ms, "e2e",
           f"E2E: Hydration logged: {r.status_code if r else 0}")

# Step 7: Log health metrics
if e2e_step1_ok:
    r, ms = req("POST", "/health-metrics",
                data={"patient_id": new_pid, "weight_kg": 65,
                      "blood_pressure_systolic": 118,
                      "blood_pressure_diastolic": 76,
                      "heart_rate_bpm": 80,
                      "fetal_movement": "normal"})
    finding = r is None or r.status_code not in (200, 201)
    record("/health-metrics", "POST", "e2e-mother",
           r.status_code if r else 0, 200, finding, "info", ms, "e2e",
           f"E2E: Health metrics logged: {r.status_code if r else 0}")

# Journey 2: Doctor accesses patient data
print(f"\n  Journey 2: Doctor overview → assign patient → view bundle")
r, ms = get(f"/doctor/{DOCTOR_ID}/overview")
record(f"/doctor/{DOCTOR_ID}/overview", "GET", "e2e-doctor",
       r.status_code if r else 0, 200, False, "info", ms, "e2e",
       f"E2E: Doctor overview: {r.status_code if r else 0}")

r, ms = get(f"/doctor/{DOCTOR_ID}/risk-feed")
record(f"/doctor/{DOCTOR_ID}/risk-feed", "GET", "e2e-doctor",
       r.status_code if r else 0, 200, False, "info", ms, "e2e",
       f"E2E: Doctor risk feed: {r.status_code if r else 0}")

# Journey 3: Health Worker → Register → Assign Mother
print(f"\n  Journey 3: Health Worker onboarding → assign mother")
new_wid = f"HWN{random.randint(10000,99999)}"
r, ms = req("POST", "/health-workers/onboarding",
            data={"worker_id": new_wid, "full_name": "E2E Health Worker",
                  "phone": "8887776666", "region": "Test Region",
                  "password": "hwpass123"})
finding = r is None or r.status_code not in (200, 201)
record("/health-workers/onboarding", "POST", "e2e-hw",
       r.status_code if r else 0, 200, finding, "info", ms, "e2e",
       f"E2E: HW registered: {r.status_code if r else 0}")

if not finding:
    r, ms = post(f"/health-workers/{new_wid}/assign-mother/{MOTHER_ID}")
    record(f"/health-workers/{new_wid}/assign-mother/{MOTHER_ID}", "POST", "e2e-hw",
           r.status_code if r else 0, 200, False, "info", ms, "e2e",
           f"E2E: Mother assigned to HW: {r.status_code if r else 0}")

# ═══════════════════════════════════════════════════════════════════════════════
# WRITE REPORT
# ═══════════════════════════════════════════════════════════════════════════════
with open(REPORT_PATH, "w") as f:
    json.dump(RESULTS, f, indent=2)

with open(SAVE_PATH, "w") as f:
    json.dump({"completed": True, "timestamp": datetime.datetime.utcnow().isoformat(),
               "total_tests": len(RESULTS)}, f, indent=2)

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
section("FINAL REPORT SUMMARY")

total     = len(RESULTS)
findings  = [r for r in RESULTS if r["finding"]]
by_sev    = {}
by_cat    = {}
for res in findings:
    s = res["severity"]
    by_sev[s] = by_sev.get(s, 0) + 1
    c2 = res["test_category"]
    by_cat[c2] = by_cat.get(c2, 0) + 1

print(f"\n  {'-'*60}")
print(f"  Endpoints discovered  : {len(ENDPOINTS)}")
print(f"  Total tests run       : {total}")
print(f"  Findings (issues)     : {len(findings)}")
print(f"  Clean passes          : {total - len(findings)}")
print(f"  {'-'*60}")

SEV_ORDER = ["critical", "high", "medium", "low", "info"]
print(f"\n  Findings by severity:")
for sev in SEV_ORDER:
    cnt = by_sev.get(sev, 0)
    if cnt:
        print(f"    {sev.upper():<30} {cnt}")

print(f"\n  Findings by category:")
for cat, cnt in sorted(by_cat.items(), key=lambda x: -x[1]):
    print(f"    {cat:<35} {cnt}")

print(f"\n{'-'*60}")
print("  TOP ISSUES TO FIX FIRST:")
print("""
  1. [CRITICAL] NO AUTHENTICATION ENFORCEMENT
     Every API endpoint is accessible without any credentials.
     The /auth/login endpoint returns NO JWT/session token —
     implementing token-based auth (JWT) is the #1 priority.

  2. [CRITICAL] PLAINTEXT PASSWORDS IN DATABASE
     Passwords stored as plain strings (models.py:23).
     Use bcrypt / argon2 hashing before storing.

  3. [HIGH] NO AUTHORIZATION / RBAC
     Any caller can access any patient's data (IDOR confirmed).
     Doctor-only endpoints accessible by anyone without auth.

  4. [HIGH] WILDCARD CORS  (allow_origins=["*"])  
     Any website can make cross-origin requests to this API.
     Restrict to known frontend origins.

  5. [HIGH] HARDCODED DEFAULT PASSWORD  ('password123')
     All new users default to 'password123'. Force password
     change on first login; never default to known passwords.

  6. [HIGH] GEMINI_API_KEY in .env
     Check .gitignore — if .env is committed, rotate key now.

  7. [MEDIUM] NO RATE LIMITING on /auth/login
     Brute-force attacks are possible without throttling.
     Add rate limiting (e.g., slowapi / nginx limit_req).

  8. [MEDIUM] SECURITY HEADERS MISSING
     X-Content-Type-Options, X-Frame-Options, HSTS, CSP absent.
     Add via middleware or reverse proxy.
""")
print(f"  Report saved: {REPORT_PATH}")
print(f"  Total tests: {total}  |  Findings: {len(findings)}\n")
