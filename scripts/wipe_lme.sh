sudo systemctl stop lme.service 2>/dev/null || true
sudo systemctl reset-failed
sudo systemctl daemon-reload
sudo systemctl disable lme.service 2>/dev/null || true
sudo -i podman stop $(sudo -i podman ps -aq) 2>/dev/null || true
sudo -i podman rm $(sudo -i podman ps -aq) 2>/dev/null || true
sudo -i podman volume rm -a 2>/dev/null || true
sudo -i podman secret rm -a 2>/dev/null || true
sudo -i podman image rm -a 2>/dev/null || true
sudo rm -rf /opt/lme /etc/containers/systemd /etc/lme /etc/systemd/system/lme.service
sudo rm -rf /root/.config/containers
sudo rm -rf /etc/containers/storage.conf
sudo systemctl daemon-reload