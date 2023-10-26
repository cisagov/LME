# LME Resilience

The Elasticsearch Stack components of LME are installed on a single server using
Docker for Linux, and this is the only supported installation. However, **if LME
is installed on a single server and the hard drive fails or the server crashes
then there is the potential for all of the logs to be lost.** It is therefore
recommended that LME installers aim to configure a multi-server cluster to help
ensure data resiliency.

The [Elastic website](https://www.elastic.co/) contains documentation about how
to install and configure multi-server clusters and in particular mentions the
requirement for a minimum of three master nodes (which in turn implies a minimum
of two data nodes) in their [node documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html).
LME users should follow the official guidance when configuring their own
cluster.
