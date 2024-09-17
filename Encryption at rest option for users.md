# Encryption at rest option for users.md

To ensure encryption at rest for all data managed by Elastic Cloud Enterprise, the hosts running Elastic Cloud Enterprise must be configured with disk-level encrytption, such as dm-crypt. Elastic Cloud Enterprise does not implement encryption at rest out of the box.

Since Elastic doesn't support data encryption at rest, it provides a paid option outside of disk-level encryption available to users. This option is called X-pack.

X-pack is a security feature that provides a secure and compliant way to protect data in Elasticsearch.

X-pack has a 30-day trial and once trial is over, users might need to acquire a platium license if they want to keep us some of the X-pack features including the data encryption.

https://www.elastic.co/guide/en/cloud-enterprise/current/ece-securing-considerations.html#:~:text=To%20ensure%20encryption%20at%20rest,encrypted%20at%20rest%20as%20well.

https://opster.com/guides/elasticsearch/security/x-pack/#:~:text=X%2DPack%20is%20an%20Elastic,features%20you%20want%20to%20use.
