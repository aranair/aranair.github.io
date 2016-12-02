---
title: AWS ElasticSearch Service, Elastic Cloud and Self-Managed
date: 2016-11-22
tags: elasticsearch, aws, found.io, elastic-cloud
disqus_identifier: 2016/aws-es-elastic-cloud-self-manage
disqus_title: AWS ElasticSearch Service vs Elastic Cloud vs Self-Manage
---

From past experience, I found the maintenance and tuning of a Elastisearch cluster to be 
a little troublesome overtime. So it isn't surprising to see hosted Elasticsearch services pop up 
one after another. Ok, to be fair, there are hosted services for nearly everything nowadays, from 
Kafka to Wordpress lol. There is really no shortage of them. Most of them provides hassle-free launching
of entire clusters within minutes and promises to offload management of the clusters along popular 
plugins pre-installed.

Quite frankly, they're welcomed services, but they do come with some caveats and I found these the hard way
when I was evaluating the services when setting up a Elasticsearch cluster at Pocketmath.

### Cluster Node Discovery

With both Elastic cloud and Amazon Elasticsearch Service, and quite possibly others too, one of the problems 
I quickly ran into is that they hide all nodes in the cluster except for the publicly accessible gateway.

What this means is that, you'll need to disable discovery and only connect through the declared 
`es.nodes.wan.only` mode, as described below in the Elasticsearch documentation.

```
es.nodes.wan.only (default false)
Whether the connector is used against an Elasticsearch instance in a cloud/restricted environment 
over the WAN, such as Amazon Web Services. In this mode, the connector disables discovery and 
only connects through the declared es.nodes during all operations, including reads and writes. 

Note that in this mode, performance is highly affected.
```

With Elastic Cloud, the problems ended here. Although, as a side note: if you are planning on 
indexing from an AWS instance to Elastic Cloud though, re-consider that. The speed of indexing 
to Elastic Cloud is *orders of magnitudes* slower than indexing among Amazon web services.

### AWS ElasticSearch Service and IAM Roles

Unfortunately, with AWS, I encountered more problems.

AWS Elasticsearch Service currently does not allow any of the commercial plugins like Shield, Watcher
and it also lacks a good access control mechanism and/or VPC access. While there are some
alternative mechanisms to control resource access but for my use-case, none of them were ideal.

**Whitelisting of IPs:**
 This could work if the instance, which is indexing the Elasticsearch, has a static IP.  However 
for my case, I was using Apache Pig in Amazon Elastic MapReduce (EMR). It spins up task instances 
with random IPs. As you might imagine, whitelisting `54.0.0.0/8` isn't exactly safe :P
  
**IAM roles:**
 I could restrict access via IAM roles. However, all requests have to be signed individually, 
and at the time of this writing, there isn't any Pig or Hive scripts available to do that yet. To
be honest, I don't think there are many libraries that support this right now. This has been 
confirmed by AWS.

### Proxy Server

To work around this, one way is to set up a reverse proxy, which is then whitelisted via its IP
in Access Policies in AWS ElasticSearch Service. This instance will then proxy all requests from the 
indexing instance, in my case- Amazon Elastic MapReduce (EMR) cluster, to the AWS ElasticSearch Service.
It would also require an Elastic IP, so that the IP in the whitelist does not need to be constantly changed.

The upside to this is that it requires relatively few changes in the code, but the problem is, 
there is a single point of weakness & failure- the proxy server. It does not scale well and would 
also require constant monitoring to ensure that it is not the bottleneck in performance.

This method is well explained and walked-through in this [blog post](https://eladnava.com/secure-aws-elasticsearch-service-behind-vpc/#theworkaround).

### Application or Local Proxy 

This [github repo](https://github.com/abutaha/aws-es-proxy) allows you to setup a small web application
layer that sits between your code and Elasticsearch. It exposes `localhost:9200` to your app
on every instance it is running on and signs every request (based on IAM roles) before relaying 
it to Elasticsearch. This removes the need for IP-based access control and helps with the 
scaling issues by eliminating the single point of failure.

A bootstrap action (for the EMR cluster) could be added to install this and run in the background:

```bash
#!/bin/bash
wget https://github.com/abutaha/aws-es-proxy/releases/download/v0.2/aws-es-proxy-0.2-linux-amd64

chmod +x aws-es-proxy-0.2-linux-amd64
./aws-es-proxy-0.2-linux-amd64 -endpoint https://elasticsearch.endpoint.hostname /dev/null &
```

With that the remote endpoint would be available via:

```bash
curl -XGET 'http://localhost:9200'
```

### Choices

While the second method is definitely feasible, in the end, in view of the issues (and workarounds) 
and the cost of equivalent instances in AWS vs AWS ElasticSearch Service and the lack of support for
plugins and later versions of Elasticsearch, I decided that managing a cluster by ourselves would 
probably be much more flexible for us in future than a hosted service with a bunch of restrictions.

