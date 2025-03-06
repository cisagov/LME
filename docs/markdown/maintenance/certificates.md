# Certificates
 
The LME installation makes use of a number of TLS certificates to protect communications between the server components and agents, and also secures the connections between Elasticsearch and Kibana. 
By default the installation will create certificates and this documentation describes how to modify and update the cert store.

## Regenerating Self-Signed Certificates
The easiest way to do this is to delete the `lme_certs` volume, and restart lme.service:

This is destructive and not recommended,but there could be cases.
```bash
sudo -i podman volume rm lme_certs
sudo systemctl restart lme.service
```

## Using Your Own Certificates
You can certificates signed by an existing root CA as part of the LME install by generating certificates manually with the correct settings and placing these within the required directory inside the LME folder. **NOTE: The default supported method of LME installation is to use the automatically created self-signed certificates, and we will be unable to support any problems that arise from generating the certificates manually incorrectly.**


### Certificate Creation
If you create certificates ensure their subject alt names allow for the ips/dns entries listed below, as well as the ips/domains you'll be connecting to the service as: 
```bash
root@ubuntu:~# cat /opt/lme/config/setup/instances.yml  | head -n 30
# Add host IP address / domain names as needed.

instances:
  - name: "elasticsearch"
    dns:
      - "lme-elasticsearch"
      - "localhost"
    ip:
      - "127.0.0.1"

  - name: "kibana"
    dns:
      - "lme-kibana"
      - "localhost"
    ip:
      - "127.0.0.1"

  - name: "fleet-server"
    dns:
      - "lme-fleet-server"
      - "localhost"
    ip:
      - "127.0.0.1"

  - name: "wazuh-manager"
    dns:
      - "lme-wazuh-manager"
      - "localhost"
    ip:
      - "127.0.0.1"
```

For example, the new kibana cert would need to support the above alternative names... you can also ensure its setup properly by viewing the current cert (assuming you've already mounted the `lme_certs` podman volume.
```bash
root@ubuntu:~$ cat /var/lib/containers/storage/volumes/lme_certs/_data/kibana/kibana.crt  | openssl x509 -text | grep -i Alternative -A 1
            X509v3 Subject Alternative Name:
                DNS:lme-kibana, IP Address:127.0.0.1, DNS:localhost
```


### Certificate Locations
All the certs are stored in the lme_certs volume. Here is how to list/change/modify the contents:

```bash
root@ubuntu:$ podman volume mount lme_certs
/var/lib/containers/storage/volumes/lme_certs/_data
root@ubuntu:$ cd /var/lib/containers/storage/volumes/lme_certs/_data/
root@ubuntu:/var/lib/containers/storage/volumes/lme_certs/_data$ tree
.
├── ACCOUNTS_CREATED
├── ca
│   ├── ca.crt
│   └── ca.key
├── ca.zip
├── caddy
│   ├── caddy.crt
│   └── caddy.key
├── certs.zip
├── curator
│   ├── curator.crt
│   └── curator.key
├── elasticsearch
│   ├── elasticsearch.chain.pem
│   ├── elasticsearch.crt
│   └── elasticsearch.key
├── fleet-server
│   ├── fleet-server.crt
│   └── fleet-server.key
├── kibana
│   ├── kibana.crt
│   └── kibana.key
├── logstash
│   ├── logstash.crt
│   └── logstash.key
└── wazuh-manager
    ├── wazuh-manager.crt
        └── wazuh-manager.key
```

To edit the certs/replace the certs, copy the new desired certificate and key to the above location on the disk: 
```
cp ~/new_kibana_cert.crt /var/lib/containers/storage/volumes/lme_certs/_data/kibana.crt
cp ~/new_kibana_key.key /var/lib/containers/storage/volumes/lme_certs/_data/kibana.key
```

## Migrating from Self-Signed Certificates

You can migrate from the default self-signed certificates to manually generated certificates at a later date, for example to move to enterprise certificates post-installation after an initial testing period. 

**NOTE: The default supported method of LME installation is to use the automatically created self-signed certificates, and we will be unable to support any problems that arise from generating the certificates manually incorrectly.**

Simply replace the certs above within the given container for the given service that you would like LME to use. If the certs are signed, ensure you also include the root ca in the  appropriate location as well.