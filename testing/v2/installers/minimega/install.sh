#!/usr/bin/env bash

set -e

# Check if the required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <username> <hostname> <password_file>"
    exit 1
fi

# Set the remote server details from the command-line arguments
user=$1
hostname=$2
password_file=$3

# Copy the SSH key to the remote machine
./minimega/copy_ssh_key.sh $user $hostname $password_file

# Copy the minimega directory to the remote machine
scp -r ./minimega $user@$hostname:/home/$user

# Run the update_packages.sh script on the remote machine this reboots the machine
ssh $user@$hostname "cd /home/$user/minimega && sudo ./update_packages.sh" 

# Reboot the server to apply the changes
ssh $user@$hostname "sudo shutdown -r now" || true

echo "Server is rebooting..."

# Loop until the server is reachable via SSH
echo "Waiting for the server to come back..."
while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $user@$hostname "exit" >/dev/null 2>&1; do
    sleep 5
done
echo "Server is back online."

# Additional check: Verify that necessary services are running
echo "Verifying necessary services are running..."
while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $user@$hostname "ls" >/dev/null 2>&1; do
    sleep 5
done

echo "Necessary services are running."

# Fix the DNS settings
ssh $user@$hostname "cd /home/$user/minimega && sudo ./fix_dnsmasq.sh" 

# Set the GOPATH
ssh $user@$hostname "cd /home/$user/minimega && sudo ./set_gopath.sh '$user'" 

# Install minimega
ssh $user@$hostname "wget https://github.com/sandia-minimega/minimega/releases/download/2.9/minimega-2.9.deb && sudo apt install ./minimega-2.9.deb" 

# Set up the service and start minimega service
ssh $user@$hostname "cd /home/$user/minimega && sudo cp minimega.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable minimega && sudo systemctl start minimega"

echo "export PATH=$PATH:/opt/minimega/bin/" >> /root/.bashrc

