---
title: 'Upgrading to ElasticSearch 5.2.2 on Amazon ECS'
description: 'I talk about some of the configuration changes that were required to bump the version of a ElasticSearch cluster
running in ECS from 2.3.5 to 5.2.2. I also talk about the massive caveat of the sysctl config issue in ECS that currently
makes this a less-than-ideal combination at the moment.'
date: 2017-04-05
tags: elasticsearch, aws, ecs
disqus_identifier: 2017/elasticsearch-5-2-2-amazon-ecs
disqus_title: Elasticsearch 5.2.2 Cluster in ECS
---

In [one of my previous post][1], I talked about how I set up Elasticsearch 2.3.5 on ECS. I got a comment in
that post that prompted me to update the setup for Elasticsearch 5. It's been awhile, but better late than never right?
I gave it a go, and in this post I'll like to share what I found in the process.

There were a couple of other configuration changes that were required to upgrade to 5.2.2 from 2.3.5 but they weren't
difficult, except one. At this point, I'll mention a caveat that will likely save you an hour of headache and trouble.

*Long story short, You will need to SSH into the ECS instances to run the command on the parent to 
get past the error message below. I am not aware of any other solutions but if you do, feel free to
let me know in the comments section below!*

```
elasticsearch:5.2.2 max virtual memory areas vm.max_map_count [65530] likely too low, increase to at least [262144]
```

This [github issue][1] suggests running `sudo sysctl -w vm.max_map_count=262144` or run the docker 
container with the `--sysctl` option. 

**However**, because of how ECS has implemented the agents, many of the docker run options are not available. 
This [github issue][2] under amazon-ecs-agent documents this and it seems like there are a few others who
are encountering the same issue.

In my opinion, this makes the combination slightly less-than-ideal because the manual configuration work that is required 
on the EC2 instances takes away some of the benefits of implementing ElasticSearch in ECS.

### Continuing..

If you're okay with the manual configuration running that command on the instances, or for example, if you plan to provision
a few instances and leave them there for awhile, then this hiccup would deal no damage. Let's move on.

### Configuration Changes

The starting point is the [Dockerfile][3] for ElasticSearch 2.3.5 in my [docker-elasticsearch-ecs repo][4].

```Dockerfile
FROM elasticsearch:5.2.2

COPY elasticsearch.yml config/elasticsearch.yml
COPY logging.yml config/logging.yml
COPY elasticsearch-entrypoint.sh /docker-entrypoint.sh

RUN bin/elasticsearch-plugin install discovery-ec2
```

Notable changes include bumping the version and changing `cloud-aws` plugin to `discovery-ec2` which
is the new plugin for the same purpose of node discovery in cloud environments.

### File Descriptors and Ulimits

I needed to change the docker-compose file slightly to include the `ulimits`. It is a new mandatory configuration item.
You can find out more in [this documentation][5].

```Dockerfile
version: '2'
services:
  data:
    build: ./docker-data/
    volumes:
      - /usr/share/elasticsearch/data

  search:
    build: ./docker-elasticsearch/
    volumes_from:
      - data
    ports:
      - "9200:9200"
      - "9300:9300"
    ulimits:
        nofile:
           soft: 65536
           hard: 65536
```

### elasticsearch.yml

`plugin.mandatory: cloud-aws` and `discovery.type: EC2` and `discovery.zen.ping.multicast.enabled: false` has been
removed or modified to the following below.

```yaml
script.inline: true
bootstrap.memory_lock: false
network.host: 0.0.0.0
network.publish_host: _ec2:privateIp_
discovery.zen.hosts_provider: ec2
discovery.ec2.groups: dockerecs
```

### Heap Size

In Elasticsearch 5, the heap size is also a mandatory configuration. For this, I set it directly in ECS via 
the JSON task definition. You can either set the `ES_HEAP_SIZE` or the `ES_JAVA_OPTS`. 

```
ES_HEAP_SIZE="1g"
# or
ES_JAVA_OPTS="-Xms1g -Xmx1g"
```

### Wrapping up

It isn't a whole lot of changes but it did take some time googling each of the issues that came up as I tried to start
the services on ECS and also eventually had to SSH into the instance to set the `vm.max_map_count` which really is
less than ideal in a deployment process otherwise full-automated. But if you're still looking ahead to use ElasticSearch 5
in ECS, the above steps should serve you well.

[1]: https://github.com/docker-library/elasticsearch/issues/111
[2]: https://github.com/aws/amazon-ecs-agent/issues/502
[3]: https://github.com/aranair/docker-elasticsearch-ecs/blob/master/docker-elasticsearch/Dockerfile
[4]: https://github.com/aranair/docker-elasticsearch-ecs
[5]: https://www.elastic.co/guide/en/elasticsearch/reference/current/setting-system-settings.html
