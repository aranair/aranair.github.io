---
title: 'Setting up Elasticsearch 5 on Amazon ECS'
description: 'In this post, I'
date: 2017-03-06
tags: elasticsearch, aws, ecs
disqus_identifier: 2017/elasticsearch-5-2-2-amazon-ecs
disqus_title: Elasticsearch 5.2.2 Cluster in ECS
---

One of my [previous post][previous post] was about setting up Elasticsearch 2.4.5 on ECS. One of the comments in
that post prompted me to update the setup for Elasticsearch 5 so I thought I'll just have a go at it to see
if they fare well together.

To start off, I'll save you some trouble and jump ahead to the most crucial part. You will hit this error sooner
or later.

```
elasticsearch:5.2.2 max virtual memory areas vm.max_map_count [65530] likely too low, increase to at least [262144]
```

And I found this [github issue][1] which suggests running `sudo sysctl -w vm.max_map_count=262144` or run the docker 
container with the `--sysctl` option. However, because of how ECS has implemented the agents, many of the docker 
run options are not allowed. This [github issue][2] under amazon-ecs-agent documents this. 

*Long story short, You will need to SSH into the ECS instances to run the command on the parent for it to work.*

### Forging Ahead

If you're okay with manually running that command on the instances, let's move on.

[1]: https://github.com/docker-library/elasticsearch/issues/111
[2]: https://github.com/aws/amazon-ecs-agent/issues/502
