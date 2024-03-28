# Certificates
The LME installation makes use of a number of TLS certificates to protect communications between Winlogbeat and Logstash, as well as to secure connections to Elasticsearch and Kibana. The installation script can generate these certificates, or you can import them from an existing trusted Certificate Authority if one is in use within the environment.

## Regenerating Self-Signed Certificates
By default the installation script will generate a root Certificate Authority (CA) and then use this to generate certificates for Elasticsearch, Logstash and Kibana, as well as client certificates which will be used to authenticate the Winlogbeat client to Logstash.

These self-signed certificates are only valid for two-years from the date of creation, and you will need to renew them periodically before they expire to ensure LME continues to function correctly. Note that the root self-signed CA has a validity of ten years by default and will not need to be regenerated regularly, unlike the others.

Regenerating the relevant certificates can be done by calling the "renew" function within the deploy script as shown below (*NOTE: You will need to know the IP address and the Fully Qualified Domain Name for the server before doing this*):


```
cd /opt/lme/Chapter\ 3\ Files/
sudo ./deploy.sh renew
```

This will prompt you to select which certificates to regenerate, and can be used to individually recreate certificates as required or to replace the root CA and all other certificates entirely. When re-creating the certificates due to an imminent expiry the root CA can be left as is, with all of the certificates which are due to expire selected to be recreated:

```bash
Do you want to regenerate the root Certificate Authority (warning - this will invalidate all current certificates in use) ([y]es/[n]o): n
Do you want to regenerate the Logstash certificate ([y]es/[n]o): y
Do you want to regenerate the Elasticsearch certificate ([y]es/[n]o): y
Do you want to regenerate the Kibana certificate ([y]es/[n]o): y
Do you want to regenerate the Winlogbeat client certificate (warning - you will need to re-install Winlogbeat with the new certificate on the WEC server if you do this) ([y]es/[n]o): y
```

### Re-configure Winlogbeat

If the Winlogbeat client certificate has been recreated this will need to be copied over to the Windows Event Collector (WEC) server and Winlogbeat will need to be modified to make use of the new certificate.

The deploy script will automatically create the file ```/opt/lme/new_client_certificates.zip```  if the Winlogbeat client certificate is renewed, which will contain the newly generated certificates and should be copied over to the WEC server as described in [Chapter 3.2.4](/docs/markdown/chapter3/chapter3.md#324-download-files-for-windows-event-collector).

The Winlogbeat service can then be stopped by opening an administrative PowerShell window and executing the following command:

```
Stop-Service winlogbeat
```

From here the service can now be modified to use the new certificates. Firstly within the ```new_client_certificates.zip``` archive copied to the WEC server, the following files should be extracted:
* root-ca.crt
* wlbclient.key
* wlbclient.crt

These files should then be copied to the following folder, overwriting the existing files when prompted to do so by Windows:

```
C:\Program Files\lme
```

Then within the administrative PowerShell window opened earlier, restart the winlogbeat service by running:

```
Start-Service winlogbeat
```

Lastly, open ```services.msc``` as an administrator, and make sure the winlogbeat service is installed, is set to start automatically, and is running:

![Winlogbeat Service Running](/docs/imgs/winlogbeat-running.png)
<p align="center">

***Troubleshooting***

Should problems arise during the reinstallation of Winlogbeat, the relevant logs can be found in ```%programdata%/winlogbeat/``` which may help identify any issues.

## Using Your Own Certificates
It is possible to use certificates signed by an existing root CA as part of the LME install by generating certificates manually with the correct settings and placing these within the required directory inside the LME folder. **NOTE: The default supported method of LME installation is to use the automatically created self-signed certificates, and we will be unable to support any problems that arise from generating the certificates manually incorrectly.**

### Certificate Creation

The exact method for generating and configuring these certificates will vary dependent upon the method you have used to create your root CA and currently manage certificates in your enterprise. However you choose to generate these, you will need the following certificates to successfully deploy LME (further information on the exact requirements can be found by inspecting the certificate generation methods within the [deploy script](/Chapter%203%20Files/deploy.sh) in Chapter 3 if required):

***Elasticsearch***

This certificate must only be created to peform server authentication and not signing.  The certificate must have ```elasticsearch``` as the CommonName and the DNS name ```elasticsearch``` and the IP address ```127.0.0.1``` within its SubjectAltName. If there is a requirement to access Elasticsearch directly from an external perspective the certificate may also have an additional SubjectAltName containing the DNS name of the LME host and its IP address.

***Kibana***

This certificate must only be created to peform server authentication and not signing. The certificate should have a CommonName of ```kibana``` and must have the FQDN of the LME server set as the SubjectAltName.   If desired, the server's IP address, the IP address ```127.0.0.1``` or the DNS name ```kibana``` can be set in the SubjectAltName.

***Logstash***

This certificate must only be created to peform server authentication and not signing.  The certificate's CommonName must have the FQDN of the LME server set.  If desired, the server's DNS name and IP address can be set in the SubjectAltName.

***Winlogbeat***

This certificate must only be created to perform client authentication and not signing. The certificate enables authentication between the Winlogbeat client and the Logstash endpoint. It should be set with the CommonName ```wlbclient```, a SubjectAltName is not required.

### Certificate Locations

Once you have successfully created the required certificates they must be placed in the following locations:

***CA Certificate***

```
/opt/lme/Chapter\ 3\ Files/certs/root-ca.crt
```

***Logstash Certificate***
```
/opt/lme/Chapter\ 3\ Files/certs/logstash.key
/opt/lme/Chapter\ 3\ Files/certs/logstash.crt
```

***Elasticsearch Certificate***
```
/opt/lme/Chapter\ 3\ Files/certs/elasticsearch.key
/opt/lme/Chapter\ 3\ Files/certs/elasticsearch.crt
```

***Kibana Certificate***
```
/opt/lme/Chapter\ 3\ Files/certs/kibana.key
/opt/lme/Chapter\ 3\ Files/certs/kibana.crt
```

***Winlogbeat Client Certificate***

In order for the Winlogbeat client certificate to be included in the ```files_for_windows.zip``` file generated by the installer, please ensure they are present as below:
```
/opt/lme/Chapter\ 3\ Files/certs/wlbclient.key
/opt/lme/Chapter\ 3\ Files/certs/wlbclient.crt
```
Alternatively these files can be transfered to the Windows Event Collector server separately if desired.

### Installation

Once the certificates have been generated as required and copied into the correct location, simply run the installer as instructed in [Chapter 3](/docs/markdown/chapter3/chapter3.md), selecting "No" when prompted to generate self-signed certificates. The installer should then ensure that the files are in the correct location and proceed as normal, making use of the manually created certificates instead.

## Migrating from Self-Signed Certificates

It is possible to migrate from the default self-signed certificates to manually generated certificates at a later date. You can move to enterprise certificates post-installation after an initial testing period if desired. You can do this by taking advantage of the "renew" functionality within the deploy script to replace the certificates once they are in the correct place.

**NOTE: The default supported method of LME installation is to use the automatically created self-signed certificates, and we will be unable to support any problems that arise from generating the certificates manually incorrectly.**

To begin this process you will need to generate the required certificates that you intend to use as part of the LME installation going forward. The certificates must meet the requirements set out above under [Certificate Creation](#certificate-creation).

Once the required certificates have been created they must be copied into the correct location, as described in the [Certificate Location](#certificate-locations) section above. If you have an existing installation with self-signed certificates then files will already exist in these locations, and will need to be overwritten with the newly created certificate files.

Once the certificate files have been copied into the correct locations calling the deploy script's "renew" function and prompting it **not** to regenerate any of the certificates will cause it to replace the currently in-use certificates with the newly copied files:

```
cd /opt/lme/Chapter\ 3\ Files/
sudo ./deploy.sh renew
```

```bash
Do you want to regenerate the root Certificate Authority (warning - this will invalidate all current certificates in use) ([y]es/[n]o): n
Do you want to regenerate the Logstash certificate ([y]es/[n]o): n
Do you want to regenerate the Elasticsearch certificate ([y]es/[n]o): n
Do you want to regenerate the Kibana certificate ([y]es/[n]o): n
Do you want to regenerate the Winlogbeat client certificate (warning - you will need to re-install Winlogbeat with the new certificate on the WEC server if you do this) ([y]es/[n]o): n
```

Once this is done Winlogbeat will need to be modified to use the newly created client certificate, as detailed in the [Re-configure Winlogbeat](#re-configure-winlogbeat) section above, substituting your manually created client certificate and key for those stored in the ```new_client_certificates.zip``` file.


