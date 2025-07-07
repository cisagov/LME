#!/bin/bash

check_password() {
    local password="$1"
    local min_length=12

    # Check password length
    if [ ${#password} -lt $min_length ]; then
        echo "Input is too short. It should be at least $min_length characters long."
        return 1
    fi

    # Skip HIBP check if in offline mode
    if [ "$OFFLINE_MODE" = "true" ]; then
        echo "Offline mode enabled - skipping HIBP password breach check."
        echo "Input meets the complexity requirements. Ensure you are using a secure password."
        return 0
    fi

    # Generate SHA-1 hash of the password
    hash=$(echo -n "$password" | openssl sha1 | awk '{print $2}')
    prefix="${hash:0:5}"
    suffix="${hash:5}"

    # Check against HIBP API
    response=$(curl -s "https://api.pwnedpasswords.com/range/$prefix")

    if echo "$response" | grep -qi "$suffix"; then
        echo "This input has been found in known data breaches. Please choose a different one."
        return 1
    fi

    # If we've made it here, the input meets the requirements
    echo "Input meets the complexity requirements and hasn't been found in known data breaches."
    return 0
}

# Main script
if [ -n "$CHECKME" ]; then
    # Use input from environment variable
    check_password "$CHECKME"
elif [ $# -eq 1 ]; then
    # Use input from command-line argument
    check_password "$1"
else
    echo "Usage: CHECKME=your_input $0"
    echo "   or: $0 your_input"
    exit 1
fi