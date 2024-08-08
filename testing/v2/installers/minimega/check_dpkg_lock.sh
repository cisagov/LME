#!/bin/bash

# Function to check if the lock file exists and is held by a process
check_lock() {
    if [ -f /var/lib/dpkg/lock-frontend ]; then
        pid=$(fuser /var/lib/dpkg/lock-frontend 2>/dev/null)
        if [ ! -z "$pid" ]; then
            echo "Lock is held by process $pid: $(ps -o comm= -p $pid)"
            return 0
        fi
    fi
    return 1
}

echo "Waiting for dpkg lock to be released..."

# Loop until the lock is released
while check_lock; do
    echo "Still waiting... Will check again in 10 seconds."
    sleep 10
done

echo "Lock has been released. You can now run your apt commands."

# Run the command passed as arguments to this script
if [ $# -gt 0 ]; then
    echo "Executing command: $@"
    "$@"
else
    echo "No command specified. Exiting."
fi