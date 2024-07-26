#!/usr/bin/env bash
cat /home/admin.ackbar/.ssh/id_rsa.pub >> /home/admin.ackbar/.ssh/authorized_keys
sudo chown admin.ackbar:admin.ackbar /home/admin.ackbar/.ssh/*
perl -p -i -e 's/root\@LS1/admin.ackbar\@DC1/' /home/admin.ackbar/.ssh/authorized_keys
