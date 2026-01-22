#!/bin/bash
set -e

# Test that firewall feature installed correctly
echo "Testing firewall feature installation..."

# Check that init script exists
if [ ! -f /usr/local/bin/init-firewall.sh ]; then
    echo "FAIL: init-firewall.sh not found"
    exit 1
fi
echo "PASS: init-firewall.sh exists"

# Check that script is executable
if [ ! -x /usr/local/bin/init-firewall.sh ]; then
    echo "FAIL: init-firewall.sh not executable"
    exit 1
fi
echo "PASS: init-firewall.sh is executable"

# Check that required tools are installed
for cmd in iptables ipset dig curl jq; do
    if ! command -v $cmd &>/dev/null; then
        echo "FAIL: $cmd not found"
        exit 1
    fi
    echo "PASS: $cmd is available"
done

# Check sudoers file exists
if [ ! -f /etc/sudoers.d/firewall ]; then
    echo "FAIL: sudoers.d/firewall not found"
    exit 1
fi
echo "PASS: sudoers configuration exists"

echo ""
echo "All firewall feature tests passed!"
