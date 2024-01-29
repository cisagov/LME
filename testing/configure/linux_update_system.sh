# Install Git client to be able to clone the LME repository
curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
chmod +x nodesource_setup.sh
sudo ./nodesource_setup.sh
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt install git curl zip net-tools jq nodejs expect python3-venv -y