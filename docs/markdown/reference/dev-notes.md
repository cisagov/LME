# Dev notes:
TODO update these to be relevant/new

Notes to convert compose -> quadlet
1. start the containers with compose
2. podlet generate from the containers created

### compose:
running:  
```shell
podman-compose up -d
```

stopping:  
```shell
podman-compose down --remove-orphans

#only run if you want to remove all volumes:
podman-compose down -v --remove-orphans
```

### install/get podlet: 
```
#https://github.com/containers/podlet/releases
wget https://github.com/containers/podlet/releases/download/v0.3.0/podlet-x86_64-unknown-linux-gnu.tar.xz
#add it to path:
cp ./podlet-x86_64-unknown-linux-gnu/podlet  .local/bin/
```

### generate the quadlet files:
[DOCS](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html), [BLOG](https://mo8it.com/blog/quadlet/)  

```
cd ~/LME-PRIV/quadlet

for x in $(podman ps --filter label=io.podman.compose.project=lme-2-arch -a  --format "{{.Names}}");do echo $x; podlet generate container $x > $x.container;done
```

### dealing with journalctl logs: 
https://unix.stackexchange.com/questions/638432/clear-failed-states-or-all-old-logs-from-systemctl-status-service
```
#delete all logs:
sudo rm /var/log/journal/$STRING_OF_HEX/user-1000*
```

### debugging commands:
```
systemctl --user stop lme.service
systemctl --user status lme*
systemctl --user restart lme.service
journalctl --user -u lme-fleet-server.service
systemctl --user status lme*
cp -r $CLONE_DIRECTORY/config/ /opt/lme && cp -r $CLONE_DIRECTORY/quadlet /opt/lme
systemctl --user daemon-reload && systemctl --user list-unit-files lme\*
systemctl --user reset-failed
podman volume rm -a

###make sure all ports are free as well: 
sudo ss -tulpn
```

### password setup stuff:
#### setup the config directory
This will setup the container config so it uses ansible vault for podman secret creation AND sets up the proper ansible-vault environment variables.

```
ln -sf /opt/lme/config/containers.conf $HOME/.config/containers/containers.conf
#preserve `chmod +x` executable
cp -rTp config/ /opt/lme/config
#source our password env var: 
. ./scripts/set_vault_key_env.sh
#create the vault directory:
/opt/lme/vault/
```

#### create password file: 
This will setup the ansible vault files in the expected paths
```
ansible-vault create /opt/lme/vault.yml
```

### **Manual Install OLD**( optional if not running ansible install):
```
export CLONE_DIRECTORY=~/LME-PRIV/lme-2-arch
#systemd will setup nix:
#Old way to setup nix if desired: sh <(curl -L https://nixos.org/nix/install) --daemon
sudo apt install jq uidmap nix-bin nix-setup-systemd  

sudo nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
sudo nix-channel --update

# Add user to nix group in /etc/group
sudo usermod -aG nix-users $USER

#install podman and podman-compose
sudo nix-env -iA nixpkgs.podman 

# Set the path for root and lme-user
#echo 'export PATH=$PATH:$HOME/.nix-profile/bin' >> ~/.bashrc
echo 'export PATH=$PATH:/nix/var/nix/profiles/default/bin' >> ~/.bashrc
sudo sh -c 'echo "export PATH=$PATH:/nix/var/nix/profiles/default/bin" >> /root/.bashrc'

#to allow 443/80 bind and setup memory/limits
sudo NON_ROOT_USER=$USER $CLONE_DIRECTORY/set_sysctl_limits.sh

#export XDG_CONFIG_HOME="$HOME/.config"
#export XDG_RUNTIME_DIR=/run/user/$(id -u)

#setup user-generator on systemd:
sudo $CLONE_DIRECTORY/link_latest_podman_quadlet.sh

#setup loginctl
sudo loginctl enable-linger $USER
```

Quadlet configuration for containers is in: `/quadlet/`
1. setup `/opt/lme` thats the running directory for lme: 
```bash
sudo mkdir -p /opt/lme
sudo chown -R $USER:$USER /opt/lme
cp -r $CLONE_DIRECTORY/config/ /opt/lme/
cp -r $CLONE_DIRECTORY/quadlet/ /opt/lme/

#setup quadlets
mkdir -p ~/.config/containers/
ln -s /opt/lme/quadlet ~/.config/containers/systemd

#setup service file
mkdir -p ~/.config/systemd/user
ln -s /opt/lme/quadlet/lme.service ~/.config/systemd/user/
```

### pull and tag all containers:
This will let us maintain the lme container versions using the `LME_LATEST` tag. Whenever we update, we change the local image to point to the newest update, and run `podman auto-update` to update the containers. 

**NOTE TO FUTURE SELVES: NEEDS TO BE `LOCALHOST` TO AVOID REMOTE TAGGING ATTACK**

```bash
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
```

```bash
#1:
# cat $CLONE_DIRECTORY/config/containers.txt | xargs -n1 -P8 podman pull -q
xargs -a $CLONE_DIRECTORY/config/containers.txt -I {} sh -c 'echo "Pulling {}..."; podman pull {} && echo "Successfully pulled {}" || echo "Failed to pull {}"'
#2:
for x in $(cat $CLONE_DIRECTORY/config/containers.txt  | tr '\n' ' ');do short=$(echo $x | awk -F/ '{print $3}'| awk -F: '{print $1}'); if [ "$short" == "" ];then short="caddy";fi;  podman image tag $x ${short}:LME_LATEST; done
```

### Start all the services
```bash
systemctl --user daemon-reload
systemctl --user start lme.service
```
