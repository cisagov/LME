#!/usr/bin/env bash

user=$1

echo "export GOPATH=/home/user/work" >> /home/$user/.bashrc
echo "export GOROOT=/usr/lib/go" >> /home/$user/.bashrc
echo "export PATH=$PATH:/usr/lib/go/bin" >> /home/$user/.bashrc

echo "export GOPATH=$HOME/work" >> ~/.bashrc
echo "export GOROOT=/usr/lib/go" >> ~/.bashrc
echo "export PATH=$PATH:/usr/lib/go/bin" >> ~/.bashrc