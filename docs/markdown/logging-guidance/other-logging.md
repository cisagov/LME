# Additional Logging

As of the release of LME v0.5, the Logstash configuration has been modified to remove the exposed Syslog port from the LME host itself. Instead, we have changed LME to support ingest from multiple Elastic Beats - to make it easier to customize LME installs to handle additional logging in a manner compliant with the Elastic Common Schema (ECS).

As the logging and analysis of Windows Event Logs is the central goal of LME, this support for other log types is not provided out of the box on fresh installations. However it can be manually configured using the steps below.

Note: We **do not** provide technical support for this process or any issues arising from it. We provide this information as an example solely to help you get started expanding LME to suit your own needs as required. This information assumes a level of familiarity with the concepts involved and is not intended to be an "out of the box" solution in the same way as LME's Windows logging capabilities. We are working to support other logging data in the future.

## Identify a Beat to Use

To ingest different log types, Elastic provides a variety of different "Beat" log shippers beyond just the Winlogbeat shipper used by LME. Each of these is aimed at a specific type of data and logging. The first step is to review the type of data that you wish to add to LME and what your needs for this log are. After you should decide which Beat suits your need the best.

The following list provides links to Elastic's description of each Beat other than Winlogbeat, which can be used to evaluate their suitability, although generally speaking Filebeat would be used for most non-Windows operating system logging:

* [Auditbeat](https://www.elastic.co/beats/auditbeat) - Lightweight shipper for audit data
* [Filebeat](https://www.elastic.co/beats/filebeat) - Lightweight shipper for logs and other data
* [Functionbeat](https://www.elastic.co/beats/functionbeat) - Serverless shipper for cloud data
* [Heartbeat](https://www.elastic.co/beats/heartbeat) - Lightweight shipper for uptime monitoring
* [Metricbeat](https://www.elastic.co/beats/metricbeat) - Lightweight shipper for metric data
* [Packetbeat](https://www.elastic.co/beats/packetbeat) - Lightweight shipper for network data

Once you have identified the correct Beat to use for your logging requirements, review the Elastic installation and configuration instructions for this before proceeding to the next stage.

### Identifying a module

In the event you are using Filebeat, Auditbeat, or Metricbeat, you will also have the option of using an additional "module" as part of your configuration to transform your data to comply with the Elastic Common Schema. Review the list of modules for the relevant Beat and decide if any of these are appropriate for the type of data you wish to ingest before proceeding:

* [Auditbeat](https://www.elastic.co/guide/en/beats/auditbeat/current/auditbeat-modules.html)
* [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-modules.html)
* [Metricbeat](https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-modules.html)

## Configuring LME Permissions

Once you have identified the Beat required, LME will require additional configuration to allow Logstash to correctly create and use the relevant indices. Specifically, Elasticsearch needs to be modified to allow the logstash_writer user to manage an index pattern associated with the Beat you have chosen.

This can be done by accessing the `Roles` section under `Stack Management`:

![Stack Management](/docs/imgs/extra_beats_pics/stack-management.png)

![Roles](/docs/imgs/extra_beats_pics/roles.png)

From here select the "logstash_writer" role:

![Logstash Writer](/docs/imgs/extra_beats_pics/logstash-writer.png)

Then modify the `Indices` section to include a pattern matching the Beat you are planning to use to gather your log data - making sure to leave the existing indices in place. For example, with Filebeat the index pattern would be `filebeat-*`, as shown below:

![Adding filebeat](/docs/imgs/extra_beats_pics/filebeat.png)

After this click `Update role`:

![Update role](/docs/imgs/extra_beats_pics/update-role.png)

## Beat Setup

Once you configure LME with the required permissions, you can to proceed with the configuration of your chosen Beat. The steps for this will vary dependent upon the Beat you have selected and the logs you wish to collect.

### Installation

The installation will vary from Beat to Beat. In general it will likely involve either copying files in to Program Files and running a PowerShell script (similar to the LME Winlogbeat installation) if installing on Windows or installing a package containing the Beat if installing on Linux or Mac OS.

Note: It is also possible to install a second Beat alongside the host used to run Winlogbeat as part of the LME installation process. This may be desirable to simplify the configuration process and transferring of files, although in practice any host compatible with the relevant Elastic beat can be used.

The Beat version used must match that officially supported by LME. Please check the corresponding document in [Chapter 3](/docs/markdown/chapter3/chapter3.md#331-files-required)

The instructions for the installation of each Beat available can be found by following **step 1** available here:
[Current Beats](https://www.elastic.co/guide/en/beats/libbeat/current/beats-reference.html)

#### Enable Modules (Optional)

If using a "module" as part of the Beat set up, you can now enable this. To enable a specific module please refer to the documentation for the relevant Beat, as listed here.

Generally, modules can be listed by running the Beat directly with the command `modules list`, and then enabled by running `modules enable [module]`. For example to enable the Cisco module in Filebeat on Windows you would run the following commands from an administrative PowerShell window within the Filebeat directory:

```
PS > .\filebeat.exe modules list
PS > .\filebeat.exe modules enable cisco
```

### Configuration

#### Log Collection

Once installed, configuring the Beat will depend largely on what log sources you wish to collect, how you wish to ingest them and which Beat you have chosen to do this. Please see the standard Elastic documentation for specifics on how to ingest the log set which is relevant to you.

If using a module to collect logs, the log input should be configured in the `modules.d` folder within the Beat's installation directory. If not making use of a Beat which uses modules, it is instead configured in the Beat's base `yaml` file in the installation directory.

For example, a Filebeat installation without a module used would have the log input configured within `filebeat.yml`, whereas a Filebeat installation that made use of the Cisco module to ingest Cisco logs would have its log input configured in `modules.d/cisco.yml`.

A common requirement with this configuration may be to ingest Syslog data, as this capability was natively removed from LME's Logstash deployment in v0.5. This can be achieved by exposing Syslog as a file input within the Beat (or module) configuration, and then redirecting your existing Syslog infrastructure to this Beat, rather than directing it to Logstash directly. This has the added benefit of allowing the Beat (or module) to appropriately normalize the data, ensuring that it is in ECS format and allowing you to better take advantage of Elastic's built-in tooling.

An example of how this input may be configured, using Syslog to ingest Cisco Meraki data into Filebeat with the Cisco module, is shown below. This is configured within the `modules.d/cisco.yml` file with the relevant options explained [here](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-module-cisco.html#_meraki_fileset_settings):

```
- module: cisco
  meraki:
    var.syslog_host: 0.0.0.0
    var.syslog_port: 12514
```

From here, Meraki could be configured to point its Syslog output at the host running Filebeat, in a similar fashion to the previously exposed Syslog port within Logstash.

**Note that this example is purely illustrative, has not been tested, and will likely require further configuration to work in a production setting depending on your logging requirements.**

#### Asset Setup

Once you have decided which Beat to used and configured log ingest appropriately, you will have to configure some additional settings within Elastic in order for the data to be ingested correctly and stored in an appropriate location. This should be done first before enabling the Beat's output, to ensure that Elastic is properly prepared to handle any incoming data.

As with other steps in this process, the exact steps required for this will vary depending upon the Beat and module in use, but generally will require running the `setup` command for the Beat itself.

As the Beat does not yet have its output configuration set up you will need to specify this on the command line, including the location of the LME host for both Elasticsearch and Kibana. This can be done with the following arguments:

```
-E output.logstash.enabled=false
-E 'output.elasticsearch.hosts=["https://*lme-hostname*:9200"]'
-E setup.kibana.host=https://*lme-hostname*:443
```

You will also need to provide the root Certificate Authority configured in [Step 3](/docs/markdown/chapter3/chapter3.md) of the LME installation process if you opted to use the default self-signed certificate. This can be done with the following arguments:

```
-E output.elasticsearch.ssl.certificate_authorities='*Root CA location*\root-ca.crt'
-E setup.kibana.ssl.certificate_authorities='*Root CA location*\root-ca.crt'
```

You will also need to include credentials for a user with permission to configure both Elasticsearch and Kibana, which in LME will likely either be the `elastic` user or a suitably configured alternative. It is advised that you do not include sensitive credentials on the commandline and instead make use of the Beat's secrets keystore in order to securely store the relevant value. This can be configured by running the installed Beat as follows, and then entering the password when prompted:

```
*beat keystore create
*beat keystore add ES_PWD
```

This can then be used with the following arguments on Windows:

```
 -E output.elasticsearch.username=elastic
 -E output.elasticsearch.password=$`{ES_PWD`}
```

On Linux or Mac OS hosts you will need to swap ``$`{ES_PWD`}`` with `\${ES_PWD}`.

By putting all of these arguments together, you can build a command that will run the setup process of the installed Beat and configure both Elasticsearch and Kibana within LME for the logs you are going to be ingesting. An example of how this might look for Filebeat running on a Windows installation is shown below:

```
.\filebeat.exe setup -e `
 -E output.logstash.enabled=false `
 -E 'output.elasticsearch.hosts=["https://elastic-lme.lme.local:9200"]' `
 -E output.elasticsearch.ssl.certificate_authorities='C:\Program Files\lme\root-ca.crt' `
 -E output.elasticsearch.username=elastic `
 -E output.elasticsearch.password=$`{ES_PWD`} `
 -E setup.kibana.host=https://elastic-lme.lme.local:443 `
 -E setup.kibana.ssl.certificate_authorities='C:\Program Files\lme\root-ca.crt'
```

This will output the outcome of the setup process to the console, which should be reviewed to ensure they have completed succesfully.

### Troubleshooting

If there is a requirement to perform the setup manually or you are unable to use the generic `setup` command above, each step in the process can be performed individually by following the below three steps:

1. Load the required index template
* [Auditbeat](https://www.elastic.co/guide/en/beats/auditbeat/current/auditbeat-template.html#load-template-manually)
* [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-template.html#load-template-manually)
* [Functionbeat](https://www.elastic.co/guide/en/beats/functionbeat/current/functionbeat-template.html#load-template-manually)
* [Heartbeat](https://www.elastic.co/guide/en/beats/heartbeat/current/heartbeat-template.html#load-template-manually)
* [Metricbeat](https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-template.html#load-template-manually)
* [Packetbeat](https://www.elastic.co/guide/en/beats/packetbeat/current/packetbeat-template.html#load-template-manually)
2. Load Kibana dashboards *(optional)*
* [Auditbeat](https://www.elastic.co/guide/en/beats/auditbeat/current/load-kibana-dashboards.html)
* [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/load-kibana-dashboards.html)
* [Metricbeat](https://www.elastic.co/guide/en/beats/metricbeat/current/load-kibana-dashboards.html)
* [Packetbeat](https://www.elastic.co/guide/en/beats/packetbeat/current/load-kibana-dashboards.html)
3. Load ingest pipelines
* [Auditbeat](https://www.elastic.co/guide/en/beats/auditbeat/current/auditbeat-template.html#load-template-manually)
* [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-template.html#load-template-manually)
* [Functionbeat](https://www.elastic.co/guide/en/beats/functionbeat/current/functionbeat-template.html#load-template-manually)
* [Heartbeat](https://www.elastic.co/guide/en/beats/heartbeat/current/heartbeat-template.html#load-template-manually)
* [Metricbeat](https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-template.html#load-template-manually)
* [Packetbeat](https://www.elastic.co/guide/en/beats/packetbeat/current/packetbeat-template.html#load-template-manually)

#### Retention Adjustments

By default, Beats will not set a retention period for their log data. This means that they will continue to store data until the disk on the LME server is full and runs out of space. In order to change this navigate to `Index Lifecycle Policies` under `Stack Management`:

![Stack Management](/docs/imgs/extra_beats_pics/stack-management.png)

![Index Lifecycle Policies](/docs/imgs/extra_beats_pics/ilm.png)

Select the Index Lifecycle Management (ILM) policy with the same name as the Beat you are using and then select `Delete data after this phase`:

![Enable Deletion](/docs/imgs/extra_beats_pics/deletion-enable.png)

This will enable a `Delete` phased, which can be updated to remove data that is the desired number of days old. The exact value to use here will depend on your average log volume and retention requirements:

![Update Retention](/docs/imgs/extra_beats_pics/update-retention.png)

You may also wish to adjust the default LME retention settings to adjust for the higher log storage associated with storing both Windows and additional logging data on the same LME host. This is done in the same way as above but editing the `lme_ilm_policy` ILM policy. For further information on this see [here](/docs/markdown/logging-guidance/retention.md).

#### Elastic Connection

Once the initial setup is complete and Elastic is correctly configured, you can configure the output for the relevant Beat in order for it to talk succesfully to LME's Logstash instance.

As LME is already configured to allow Winlogbeat to make this connection, repurposing this to include additional Beats should be fairly straight forward, and can make use of some of the files already generated.

First you will need to create a client certificate which can be used for the Beat to authenticate to Logstash. This can be done by executing the following script on the host running LME, which will output the required files in `/opt/lme/Chapter 3 Files/certs` - this script will need to be run with elevated privileges in order for it to access the required root CA:

```bash
#!/bin/bash
cd "/opt/lme/Chapter 3 Files"
#make a new key for the client Beat
echo -e "\e[32m[X]\e[0m Making Beat client certificate"
openssl genrsa -out certs/beatclient.key 4096

#make a cert signing request for the client Beat
openssl req -new -key certs/beatclient.key -out certs/beatclient.csr -sha256 -subj '/C=US/ST=DC/L=Washington/O=CISA/CN=beatclient'

#set openssl so that this cert can only perform auth and cannot sign certs
echo "[server]" >certs/beatclient.cnf
echo "authorityKeyIdentifier=keyid,issuer" >> certs/beatclient.cnf
echo "basicConstraints = critical,CA:FALSE" >> certs/beatclient.cnf
echo "extendedKeyUsage=clientAuth" >> certs/beatclient.cnf
echo "keyUsage = critical, digitalSignature, keyEncipherment" >> certs/beatclient.cnf
echo "subjectKeyIdentifier=hash" >> certs/beatclient.cnf

#sign the Beat client cert
echo -e "\e[32m[X]\e[0m Signing beatclient cert"
openssl x509 -req -days 750 -in certs/beatclient.csr -sha256 -CA certs/root-ca.crt -CAkey certs/root-ca.key -CAcreateserial -out certs/beatclient.crt -extfile certs/beatclient.cnf -extensions server
```

Once completed the script will have created four additional files in the `certs` folder:

```
-rw-r--r-- 1 root root  191 Sep 21 14:52 beatclient.cnf
-rw-r--r-- 1 root root 2013 Sep 21 14:52 beatclient.crt
-rw-r--r-- 1 root root 1667 Sep 21 14:52 beatclient.csr
-rw------- 1 root root 3243 Sep 21 14:52 beatclient.key
```

You will need to copy `beatclient.key` and `beatclient.crt` on to the server running your intended Beat. You will also need a copy of of the `root-ca.crt` file from the same directory - although you may already have this file on the server if you are installing the Beat to the same location as you installed Winlogbeat, in which case it can be found in `C:\Program Files\lme\root-ca.crt`.

Once these files are copied succesfully on to the server where your Beat is installed, they should be placed in a folder where they can be stored, for example in the same folder structure as the Beat installation for ease.

After this, the Beat's configuration file, which matches the Beats name and ends in `.yml` within its installation directory, should be configured to include the output as follows, replacing the sections in asteriks with the correct information:

```
output.logstash:
  hosts: ["*LME hostname*:5044"]
  ssl.certificate_authorities: ["*Root CA folder*\root-ca.crt"]
  ssl.certificate: "*Client certificate folder*\beatclient.crt"
  ssl.key: "*Client certificate folder*\beatclient.key"
```

For example a Beat installation on the same Windows host running LME and pointing at an LME installation in the domain "lme.local" may look like the following:

```
output.logstash:
  hosts: ["elastic-lme.lme.local:5044"]
  ssl.certificate_authorities: ["C:\\Program Files\\lme\\root-ca.crt"]
  ssl.certificate: "C:\\Program Files\\lme\\beatclient.crt"
  ssl.key: "C:\\Program Files\\lme\\beatclient.key"
```

Once this file is succesfully configured you should be able to confirm everything is correctly configured by running the Beat with the `test` command. This can be used to confirm that both the configuration file is correct, and that the Beat is able to succesfully connect to the Logstash instance for its output using the following arguments respectively

* [beatname] test config - Tests the configuration settings
* [beatname] test output - Tests that the Beat can connect to the output configured in its current settings

If both of these tests pass succesfully you can move on to start the Beat and ingesting the additional data into your LME instance.

### Running the Beat

Once everything is succesfully configured the Beat can be run by simply starting the already installed service. The exact command to do this varies depending upon the type of operating system used on the server running the Beat, with more specific instructions available here:

* [Auditbeat](https://www.elastic.co/guide/en/beats/auditbeat/current/auditbeat-installation-configuration.html#start)
* [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-installation-configuration.html#start)
* [Functionbeat](https://www.elastic.co/guide/en/beats/functionbeat/current/functionbeat-installation-configuration.html#deploy-to-aws)
* [Heartbeat](https://www.elastic.co/guide/en/beats/heartbeat/current/heartbeat-installation-configuration.html#start)
* [Metricbeat](https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-installation-configuration.html#start)
* [Packetbeat](https://www.elastic.co/guide/en/beats/packetbeat/current/packetbeat-installation-configuration.html#start)

After this is done and the service is started successfully you should be able to view data in Kibana as usual, by navigating to the index pattern that matches the Beat you are using in the left hand side of the "Discover" view:

![Filebeat selection](/docs/imgs/extra_beats_pics/filebeat-selection.png)

If you chose to install the built-in dashboards relevant to your Beat you should also be able to make use of these.

Once you can view data in Kibana your setup is complete, and you will be able to continue to use LME to review the standard Windows logging data, alongside the additional logs you have configured above.

## Troubleshooting

No specific advice around troubleshooting a custom log setup is available, as the core function of LME is to provide an out of the box Windows logging environment and extending this to additional logs will vary entirely dependent upon your specific requirements and configuration.

The generic troubleshooting steps listed [here](/docs/markdown/reference/troubleshooting.md) are still likely to be a good starting point if you do encounter any issues with this customisation, and should be reviewed if something goes wrong.

One commonly observed flaw with some Beats is to default to a relication setting that is incompatible with LME's default single-node cluster, causing a yellow cluster health state and unassigned replica shards. Elastic will likely fix this in a later release, but in the meantime details on diagnosing and resolving it is here. If this re-occurs each time a new index is created for your additional logs, it can be resolved by editing the index template in `Stack Management` -> `Index Management` -> `Index Templates` -> `[beatname]-[beatversion]` to include the following settings:

```
{
  "index.number_of_replicas": 1
}
```
