#!/usr/bin/env bash

set -euo pipefail

export CLONE_DIRECTORY=~/LME-PRIV/lme-2-arch

sudo apt-get update

sudo apt install -y jq uidmap nix-bin nix-setup-systemd

sudo nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs

sudo nix-channel --update

sudo usermod -aG nix-users $USER

sudo nix-env -iA nixpkgs.podman

echo 'export PATH=$PATH:/nix/var/nix/profiles/default/bin' >> ~/.bashrc

sudo sh -c 'echo "export PATH=$PATH:/nix/var/nix/profiles/default/bin" >> /root/.bashrc'

# Set it for the local shell because sourcing ~/.bashrc wasn't enough
export PATH=$PATH:/nix/var/nix/profiles/default/bin

sudo NON_ROOT_USER=$USER $CLONE_DIRECTORY/set_sysctl_limits.sh

sudo $CLONE_DIRECTORY/link_latest_podman_quadlet.sh

sudo loginctl enable-linger $USER

sudo mkdir -p /opt/lme

sudo chown -R $USER:$USER /opt/lme

cp -r $CLONE_DIRECTORY/config/ /opt/lme/

cp -r $CLONE_DIRECTORY/quadlet/ /opt/lme/

mkdir -p ~/.config/containers/

ln -s /opt/lme/quadlet ~/.config/containers/systemd

mkdir -p ~/.config/systemd/user

ln -s /opt/lme/quadlet/lme.service ~/.config/systemd/user/

systemctl --user daemon-reload

systemctl --user list-unit-files lme\*

cp $CLONE_DIRECTORY/example.env /opt/lme/lme-environment.env

sudo mkdir -p /etc/containers

sudo tee /etc/containers/policy.json <<EOF
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
EOF

xargs -a $CLONE_DIRECTORY/config/containers.txt -I {} bash -c 'echo "Pulling {}..."; podman pull {} && echo "Successfully pulled {}" || echo "Failed to pull {}"'

for x in $(cat $CLONE_DIRECTORY/config/containers.txt  | tr '\n' ' ');do short=$(echo $x | awk -F/ '{print $3}'| awk -F: '{print $1}'); if [ "$short" == "" ];then short="caddy";fi;  podman image tag $x ${short}:LME_LATEST; done

systemctl --user daemon-reload

systemctl --user start lme.service
