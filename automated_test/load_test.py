import time
import random
import requests
import concurrent.futures
import threading
import os
import json

BASE_URL = "http://localhost:8000"
# Allow running shorter tests via env var (e.g. for CI/CD)
NUM_USERS = int(os.environ.get("LOAD_TEST_USERS", 100))
DURATION = int(os.environ.get("LOAD_TEST_DURATION", 60)) # seconds

ENDPOINTS = [
    "/health",
    "/education/articles",
    "/education/faqs",
    "/diet/meal-templates"
]

# Statistics collection
lock = threading.Lock()
response_times = []
status_codes = {}
exceptions_count = 0
total_requests = 0

# Endpoint-specific statistics
endpoint_stats = {
    ep: {
        "response_times": [],
        "success_count": 0,
        "failure_count": 0,
        "status_codes": {}
    } for ep in ENDPOINTS
}

def run_user_session(stop_time):
    global exceptions_count, total_requests
    session = requests.Session()
    
    while time.time() < stop_time:
        endpoint = random.choice(ENDPOINTS)
        url = f"{BASE_URL}{endpoint}"
        start_time = time.time()
        try:
            resp = session.get(url, timeout=10)
            latency = (time.time() - start_time) * 1000  # ms
            
            with lock:
                response_times.append(latency)
                status_codes[resp.status_code] = status_codes.get(resp.status_code, 0) + 1
                total_requests += 1
                
                ep_stat = endpoint_stats[endpoint]
                ep_stat["response_times"].append(latency)
                if 200 <= resp.status_code < 400:
                    ep_stat["success_count"] += 1
                else:
                    ep_stat["failure_count"] += 1
                ep_stat["status_codes"][resp.status_code] = ep_stat["status_codes"].get(resp.status_code, 0) + 1
        except Exception as e:
            with lock:
                exceptions_count += 1
                total_requests += 1
                
                ep_stat = endpoint_stats[endpoint]
                ep_stat["failure_count"] += 1

def main():
    print(f"Starting Baseline/Load Test...")
    print(f"Target URL: {BASE_URL}")
    print(f"Concurrent Users: {NUM_USERS}")
    print(f"Duration: {DURATION} seconds")
    print(f"Endpoints: {', '.join(ENDPOINTS)}")
    print("---------------------------------------------")
    
    start_time = time.time()
    stop_time = start_time + DURATION
    
    # Start thread pool
    with concurrent.futures.ThreadPoolExecutor(max_workers=NUM_USERS) as executor:
        futures = [executor.submit(run_user_session, stop_time) for _ in range(NUM_USERS)]
        
        # Monitor progress
        elapsed = 0
        while elapsed < DURATION:
            time.sleep(5)
            elapsed = int(time.time() - start_time)
            with lock:
                reqs_so_far = total_requests
            print(f"Elapsed: {elapsed}s | Requests sent: {reqs_so_far} | Current RPS estimate: {reqs_so_far / max(1, elapsed):.1f}")
            
        # Wait for all threads to finish
        concurrent.futures.wait(futures)

    end_time = time.time()
    total_duration = end_time - start_time
    
    # Calculate results
    with lock:
        total_reqs = total_requests
        success_count = sum(endpoint_stats[ep]["success_count"] for ep in ENDPOINTS)
        times = list(response_times)
        errs = exceptions_count
        codes_summary = dict(status_codes)
        
        endpoints_summary = {}
        for ep in ENDPOINTS:
            ep_times = endpoint_stats[ep]["response_times"]
            endpoints_summary[ep] = {
                "total_requests": endpoint_stats[ep]["success_count"] + endpoint_stats[ep]["failure_count"],
                "success_count": endpoint_stats[ep]["success_count"],
                "failure_count": endpoint_stats[ep]["failure_count"],
                "avg_latency": sum(ep_times) / len(ep_times) if ep_times else 0,
                "min_latency": min(ep_times) if ep_times else 0,
                "max_latency": max(ep_times) if ep_times else 0,
                "status_codes": dict(endpoint_stats[ep]["status_codes"])
            }

    rps = total_reqs / total_duration if total_duration > 0 else 0
    
    avg_latency = sum(times) / len(times) if times else 0
    min_latency = min(times) if times else 0
    max_latency = max(times) if times else 0
    
    print("\n================ LOAD TEST RESULTS ================")
    print(f"Total Duration: {total_duration:.2f} seconds")
    print(f"Total Requests: {total_reqs}")
    print(f"Requests per second (RPS): {rps:.1f} req/sec")
    print("\n--- Response Time ---")
    print(f"Average: {avg_latency:.1f}ms")
    print(f"Min: {min_latency:.1f}ms")
    print(f"Max: {max_latency:.1f}ms")
    print("\n--- Status Codes ---")
    for code, count in codes_summary.items():
        print(f"HTTP {code}: {count} requests")
    if errs > 0:
        print(f"Connection failures/Timeouts: {errs} occurrences")
    print("===================================================")

    # Save to JSON report
    success_rate_val = (success_count / total_reqs * 100) if total_reqs > 0 else 0
    json_report = {
        "target_url": BASE_URL,
        "virtual_users": NUM_USERS,
        "duration_seconds": total_duration,
        "total_requests": total_reqs,
        "success_rate": f"{success_rate_val:.1f}%",
        "requests_per_second": rps,
        "avg_latency_ms": avg_latency,
        "min_latency_ms": min_latency,
        "max_latency_ms": max_latency,
        "exceptions_count": errs,
        "status_codes": codes_summary,
        "endpoints": endpoints_summary
    }
    
    report_file = os.path.join(os.path.dirname(__file__), "load_test_results.json")
    with open(report_file, "w") as f:
        json.dump(json_report, f, indent=2)
    print(f"Results JSON saved to: {report_file}")

if __name__ == "__main__":
    main()
