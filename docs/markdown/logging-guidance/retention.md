# Retention Settings

By default, LME will configure an index lifecycle policy that will delete
indexes based on estimated disk usage. Initially, 80% of the disk will be used
for the indexes, with an assumption that a day of logs will use 1Gb of disk
space.

If you wish to adjust the number of days retained, then this can be done in
Kibana. First, select the `lme_ilm_policy` from the "Index Lifecycle Policies"
list:

![Retention settings](/docs/imgs/retention_pics/retention_1.png)

Next, scroll to the bottom of the settings page and adjust the "Delete phase"
setting as appropriate.

![Retention delete phase settings](/docs/imgs/extra_beats_pics/update-retention.png)

Care must be taken to ensure that the retention period is appropriate for the
disk space available. If disk space is exhausted then the solution will
experience performance issues and new logs will not be recorded. By default,
Elasticsearch will not allocate shards to any nodes that are using 85% or more
of the available disk space. See [the Elasticsearch
documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/disk-allocator.html)
(the `cluster.routing.allocation.disk.watermark.low` setting in particular) for
more information.

Click the "Save policy" button and the new setting will be applied to the LME
indexes. The changes will be applied immediately, so care should be taken to
ensure that the new policy does not result in unwanted data loss. (E.g. by
reducing the retention period, which would cause existing logs to be deleted.)
