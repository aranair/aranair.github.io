---
title: Elasticsearch Cluster in ECS
date: 2016-12-05
tags: elasticsearch, aws, ecs
disqus_identifier: 2016/aws-ecs-elasticsearch
disqus_title: Elasticsearch Cluster in ECS
---

The Amazon EC2 Container service (ECS) has been increasingly used alongside with the popularity of Docker.
At Pocketmath, we heavily utilize it to host most of our dockerized containers to provide us with a easily scalable,
zero-downtime infrastructure. Our existing Elasticsearch cluster running on version `1.7.5`, while underutilized, 
is already running in ECS. 

When I recently upgraded the Elasticsearch from `1.7.5` to `2.3.5` on our clusters and because of a slight lack of
transfer of knowledge, I ran into a few issues.
