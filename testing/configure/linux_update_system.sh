# Install Git client to be able to clone the LME repository
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt install git curl zip net-tools jq nodejs expect python3-venv -y