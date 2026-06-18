import time
import random
import requests
import concurrent.futures
import threading
import os

BASE_URL = "http://localhost:8000"
NUM_USERS = 100
DURATION = 60 # seconds

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
        except Exception as e:
            with lock:
                exceptions_count += 1
                total_requests += 1

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
        success_count = status_codes.get(200, 0)
        times = list(response_times)
        errs = exceptions_count
        codes_summary = dict(status_codes)

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

if __name__ == "__main__":
    main()
