#!/bin/bash

# Change to the directory where the script is located
script_dir=$(dirname "$0")
cd $script_dir || exit 1
# We need to get the full path of the script dir for below
script_dir=$(pwd)

# Default username
username="admin.ackbar"

# Process command line arguments
while getopts "u:v:b:" opt; do
  case $opt in
    u) username=$OPTARG ;;
    v) version=$OPTARG ;;
    b) branch=$OPTARG ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

# Check if version matches the pattern
if [[ -n "$version" && ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Version should match \d+.\d+.\d+"
    exit 1
fi

# Remove any existing LME directories
sudo rm -rf /opt/cisagov-LME-* /opt/lme

# Get the tarball URL for the specified version
get_tarball_url() {
    echo "https://api.github.com/repos/cisagov/LME/tarball/v$1"
}

if [ -n "$branch" ]; then
    # Clone from the specified branch
    git clone --branch "$branch" https://github.com/cisagov/LME.git /opt/lme
else
  echo "Getting the code from GitHub"
  # Check if a version is provided
  if [ -n "$version" ]; then
      tarball_url=$(get_tarball_url "$version")
  else
      tarball_url=$(curl -s https://api.github.com/repos/cisagov/LME/releases/latest | jq -r '.tarball_url')
  fi

  # Get the version from the tarball URL
  v_version=$(basename "$tarball_url")

  echo "Downloading $tarball_url to file: $v_version"
  curl -L "$tarball_url" -o "$v_version"

  # extracts it to a folder like cisagov-LME-3412897
  sudo tar -xzpf "$v_version" -C /opt
  rm -rf "$v_version"

  extracted_filename=$(sudo ls -ltd /opt/cisagov-LME-* | grep "^d" | head -n 1 | awk '{print $NF}')

  echo "Extracted to $extracted_filename"

  echo "Renaming directory to /opt/lme"
  sudo mv "$extracted_filename" /opt/lme
fi

<<<<<<< HEAD
# Change the way we check disk usage in the old versions
perl -pi -e 's/DISK_SIZE="\$\(echo "\$DF_OUTPUT".+?\)"/DISK_SIZE=130/' /opt/lme/Chapter\ 3\ Files/deploy.sh
perl -pi -e 's/DISK_80=\$\(\(DISK_SIZE_ROUND \* 80 \/ 100\)\)/DISK_80=91/g' /opt/lme/Chapter\ 3\ Files/deploy.sh


=======
>>>>>>> origin/release-1.4.0
echo 'export DEBIAN_FRONTEND=noninteractive' >> ~/.bashrc
echo 'export NEEDRESTART_MODE=a' >> ~/.bashrc
. ~/.bashrc

# Set the noninteractive modes for root
echo 'export DEBIAN_FRONTEND=noninteractive' | sudo tee -a /root/.bashrc
echo 'export NEEDRESTART_MODE=a' | sudo tee -a /root/.bashrc

<<<<<<< HEAD
#get interface name of default route
DEFAULT_IF="$(route | grep '^default' | grep -o '[^ ]*$')"

#get ip of the interface
EXT_IP="$(/sbin/ifconfig "$DEFAULT_IF" | awk -F ' *|:' '/inet /{print $3}')"

function installdocker() {
  echo -e "\e[32m[X]\e[0m Installing Docker"
  curl -fsSL https://get.docker.com -o get-docker.sh >/dev/null
  sudo sh get-docker.sh >/dev/null
  echo "Starting docker"
  sudo service docker start
  sleep 5
}

# Pull the images so you don't have to wait for them in expect
installdocker

echo -e "\e[32m[X]\e[0m Pulling the images. This may take some time."
docker compose -f /opt/lme/Chapter\ 3\ Files/docker-compose-stack.yml pull --quiet

=======
>>>>>>> origin/release-1.4.0
# Execute script with root privileges
# Todo: We could put a switch here for different versions and just run different expect scripts
sudo -E bash -c  ". /root/.bashrc && $script_dir/linux_install_lme.exp"

sudo chmod ugo+w "/opt/lme/Chapter 3 Files/output.log"

if [ -f "/opt/lme/files_for_windows.zip" ]; then
    sudo cp /opt/lme/files_for_windows.zip /home/"$username"/
    sudo chown "$username":"$username" /home/"$username"/files_for_windows.zip
else
    echo "files_for_windows.zip does not exist. Probably because a reboot is required in order to proceed with the install"
fi
