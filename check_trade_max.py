#!/usr/bin/env python
"""
Fetch sum of long/short open trades in given environment
and alert when reached thresholds
"""
import sys
import requests

# Define the Prometheus URL and query
if len(sys.argv) < 3:
    print(f"Usage: {sys.argv[0]} <env> <direction>")
    sys.exit(3)
ENV = sys.argv[1]
DIRECTION = sys.argv[2]
PROMETHEUS_URL = 'http://prometheus:9090/api/v1/query'
QUERY = 'sum({__name__=~"open_net_perc.*%s_%s"})' %(DIRECTION, ENV)

# Define the warning and critical thresholds
WARNING_THRESHOLD = 50
CRITICAL_THRESHOLD = 100

def main():
    try:
        response = requests.get(PROMETHEUS_URL, params={'query': QUERY}, timeout=20)
        response.raise_for_status()
        data = response.json()

        if data['status'] == 'success' and data['data']['result']:
            value = round(float(data['data']['result'][0]['value'][1]), 2)
            if value >= CRITICAL_THRESHOLD:
                print(f"CRITICAL: Value is {value}|value={value};{WARNING_THRESHOLD};{CRITICAL_THRESHOLD};0;400")
                sys.exit(2)
            elif value >= WARNING_THRESHOLD:
                print(f"WARNING: Value is {value}|value={value};{WARNING_THRESHOLD};{CRITICAL_THRESHOLD};0;400")
                sys.exit(1)
            else:
                print(f"OK: Value is {value}|value={value};{WARNING_THRESHOLD};{CRITICAL_THRESHOLD};0;400")
                sys.exit(0)
        else:
            # no data, defaults to 0
            value = 0
            print(f"OK: Value is {value}|value={value};{WARNING_THRESHOLD};{CRITICAL_THRESHOLD};0;400")
            sys.exit(0)
    except requests.exceptions.RequestException as e:
        print(f"UNKNOWN: Error fetching data - {e}")
        sys.exit(3)

if __name__ == "__main__":
    main()
