#!/bin/sh

echo "Running DNS resolution test..."

# Function to check Unbound process
check_unbound_process() {
    echo "Checking Unbound process..."
    ps aux | grep unbound || echo "Unbound process not found"
}

# Function to check DNS ports
check_dns_ports() {
    echo "Checking DNS ports status..."
    netstat -tuln | grep -E ':(5353|5336)'
}

# Show diagnostic information
check_unbound_process
check_dns_ports

# Test basic DNS resolution with retry
dns_working=false
i=1
while [ $i -le 3 ]; do
    dig_output=$(dig +short @127.0.0.1 -p 5335 google.com)
    if [ -n "$dig_output" ]; then
        dns_working=true
        echo "Basic DNS resolution working"
        break
    fi
    echo "DNS resolution attempt $i failed, retrying..."
    echo "dig output: $dig_output"
    i=$((i + 1))
    sleep 2
done

if [ "$dns_working" != "true" ]; then
    echo "Basic DNS resolution test failed"
    exit 1
fi

# Test DNSSEC validation
echo "Testing DNSSEC validation..."

# Test valid DNSSEC
echo "Testing valid DNSSEC domain (dnssec.works)..."
dig_output=$(dig @127.0.0.1 -p 5335 dnssec.works)
echo "$dig_output"
if ! echo "$dig_output" | grep -q 'status: NOERROR'; then
    echo "Valid DNSSEC test failed"
    exit 1
fi

# Test invalid DNSSEC
echo "Testing invalid DNSSEC domain (fail01.dnssec.works)..."
dig_output=$(dig @127.0.0.1 -p 5335 fail01.dnssec.works)
echo "$dig_output"
if ! echo "$dig_output" | grep -q 'status: SERVFAIL'; then
    echo "Invalid DNSSEC test failed"
    exit 1
fi

# Test reverse DNS
echo "Testing reverse DNS..."
dig_output=$(dig @127.0.0.1 -p 5335 -x 8.8.8.8)
echo "$dig_output"
if ! echo "$dig_output" | grep -q 'dns.google'; then
    echo "Reverse DNS test failed"
    exit 1
fi

# Test response time
echo "Testing DNS response time..."
start_time=$(date +%s%N)
dig @127.0.0.1 -p 5335 +short google.com > /dev/null
end_time=$(date +%s%N)
duration=$((($end_time - $start_time)/1000000))
echo "Response time: ${duration}ms"

if [ $duration -gt 1000 ]; then
    echo "Warning: DNS response time is high (${duration}ms)"
fi

echo "All DNS tests completed successfully"
