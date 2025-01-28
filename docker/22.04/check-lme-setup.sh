#!/bin/bash

# Default timeout in seconds (30 minutes)
TIMEOUT=1800
START_TIME=$(date +%s)

# Function to check if timeout has been reached
check_timeout() {
    current_time=$(date +%s)
    elapsed_time=$((current_time - START_TIME))
    if [ $elapsed_time -gt $TIMEOUT ]; then
        echo "ERROR: Setup timed out after ${TIMEOUT} seconds"
        exit 1
    fi
}

echo "Starting LME setup check..."

# Main loop
while true; do
    # Check if the timeout has been reached
    check_timeout
    
    # Get the logs and check for completion
    logs=$(docker compose exec lme journalctl -u lme-setup -o cat --no-hostname)
    
    # Check for successful completion
    if echo "$logs" | grep -q "First-time initialization complete"; then
        echo "SUCCESS: LME setup completed successfully"
        exit 0
    fi
    
    # Check for failure indicators
    if echo "$logs" | grep -q "failed=1"; then
        echo "ERROR: Ansible playbook reported failures"
        exit 1
    fi
    
    # Track progress through the playbooks
    recap_count=$(echo "$logs" | grep -c "PLAY RECAP")
    if [ "$recap_count" -gt 0 ]; then
        echo "INFO: Detected ${recap_count} of 2 playbook completions..."
    fi
    
    # Wait before next check (60 seconds)
    sleep 60
done 