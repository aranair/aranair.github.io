---
title: 'Upgrading to ElasticSearch 5.2.2 on Amazon ECS'
description: 'I talk about some of the configuration changes that were required to bump the version of a ElasticSearch cluster
running in ECS from 2.3.5 to 5.2.2. I also talk about the massive caveat of the sysctl config issue in ECS that currently
makes this a less-than-ideal combination at the moment.'
date: 2017-03-06
tags: elasticsearch, aws, ecs
disqus_identifier: 2017/elasticsearch-5-2-2-amazon-ecs
disqus_title: Elasticsearch 5.2.2 Cluster in ECS
---

In [one of my previous post][1], I talked about how I set up Elasticsearch 2.3.5 on ECS. I got a comments in
that post that kinda prompted me to update the setup for Elasticsearch 5 so I thought why not? I gave it a go, and I'll
like to share what I found in the process in today's post.

There were a couple of other configuration changes that were required to upgrade to 5.2.2 from 2.3.5 but they weren't
difficult, except one. At this point, I'll mention a caveat that will likely save you an hour of headache and trouble.

*Long story short, You will need to SSH into the ECS instances to run the command on the parent to 
get past the error message below.*

```
elasticsearch:5.2.2 max virtual memory areas vm.max_map_count [65530] likely too low, increase to at least [262144]
```

This [github issue][1] suggests running `sudo sysctl -w vm.max_map_count=262144` or run the docker 
container with the `--sysctl` option. 

**However**, because of how ECS has implemented the agents, many of the docker run options are not available. 
This [github issue][2] under amazon-ecs-agent documents this and it seems like there are a few others who
are encountering the same issue.

In my opinion, this makes the combination slightly less-than-ideal because the manual configuration work that is required 
on the EC2 instances takes away the benefits of implementing ElasticSearch in ECS.

### Continuing..

If you're okay with the manual configuration running that command on the instances, or for example, if you plan to provision
a few instances and leave them there for awhile, then this hiccup would deal no damage. Let's move on.

### Configuration Changes

I will be basing this off my [Dockerfile][3] for ElasticSearch 2.3.5 in the [docker-elasticsearch-ecs repo][4].

First, I bumped the version.

```Dockerfile
FROM elasticsearch:5.2.2

COPY elasticsearch.yml config/elasticsearch.yml
COPY logging.yml config/logging.yml
COPY elasticsearch-entrypoint.sh /docker-entrypoint.sh

RUN bin/elasticsearch-plugin install discovery-ec2
```

[1]: https://github.com/docker-library/elasticsearch/issues/111
[2]: https://github.com/aws/amazon-ecs-agent/issues/502
[3]: https://github.com/aranair/docker-elasticsearch-ecs/blob/master/docker-elasticsearch/Dockerfile
[4]: https://github.com/aranair/docker-elasticsearch-ecs
