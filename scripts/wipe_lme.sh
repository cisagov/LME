sudo systemctl stop lme*
sudo systemctl reset-failed
sudo systemctl disable lme.service
sudo -i podman volume rm -a
sudo -i podman secret rm -a
sudo rm -rf /opt/lme /etc/containers/systemd
sudo -i podman stop $(sudo -i podman ps -aq)
sudo -i podman rm $(sudo -i podman ps -aq)
rm -rf ~/.config/containers
rm -rf /etc/containers/storage.conf