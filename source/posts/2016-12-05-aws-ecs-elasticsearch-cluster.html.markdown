---
title: Elasticsearch Cluster in Amazon ECS
date: 2016-12-05
tags: elasticsearch, aws, ecs
disqus_identifier: 2016/aws-ecs-elasticsearch
disqus_title: Elasticsearch Cluster in ECS
---

At Pocketmath, we heavily utilize the EC2 container service (ECS) to host a big portion of our applications. It
provides us with an easily scalable, zero-downtime infrastructure. Recently, I upgraded the Elasticsearch to `2.3.5` 
for our clusters so I thought it was a good idea to just jot down some of the things I had to do or was already 
there for it to function properly.

### Dockerfile

First things first: locations for the installs were changed so a quick update for them was required.

```
FROM elasticsearch:2.3

WORKDIR /usr/share/elasticsearch

RUN bin/plugin install cloud-aws
RUN bin/plugin install mobz/elasticsearch-head
RUN bin/plugin install analysis-phonetic

COPY elasticsearch.yml config/elasticsearch.yml
COPY logging.yml config/logging.yml
COPY elasticsearch-entrypoint.sh /docker-entrypoint.sh
```

### Docker & Elasticsearch Setup

Do take note that the `network.host` line is absolutely required for **Zen Discovery** to work in ECS.

Its a simple dockerized container setup with mounted volumes in a separate data container and exposed ports for
elasticsearch communication.

`docker-compose.yml` sample:

```yml
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
```

elasticsearch.yml:

```yml
script.inline: true
bootstrap.mlockall: true

network.host: 0.0.0.0
plugin.mandatory: cloud-aws
network.publish_host: _ec2:privateIp_
discovery.type: ec2
discovery.ec2.groups: xx-xxxxx
discovery.zen.ping.multicast.enabled: false
```

The first 2 lines are fairly standard so I'll skip them; you can find these around in the official docs. Its the last
few lines that I had to meddle around with abit for it to work.

### Discovery

So, the default node discovery module for Elasticsearch is [Zen Discovery][zen discovery] and it supports both multicast and unicast.
Although, since EC2 [doesn't support multicast][aws faq], I disabled multicast and used only unicast. There are some 
notable things that was in that docs though: **the ping (discovery)** and **the master election**.

During the `ping phase`, each node uses the discovery mechanism to find other nodes in the cluster. That process however, 
won't really work out-of-the-box for a cloud environments like Elastic cloud or AWS EC2. There is a plugin that 
fixes this- `cloud-aws`. So I installed it via the Dockerfile above, for each container that runs inside
the cluster. One issue is that the plugin was built for EC2 where each instance naturally publishes their own instance's IP
for the discovery process. Inside ECS, that discovery mechanism will fail since it just publishes its container's IP address.

### Running it in ECS

Back in Elasticsearch V1, I think the following was the de-facto solution as an entrypoint for docker. It basically 
pings Amazon's `169.254.169.254` instance information endpoint for the private IP. The service would then be started 
with its container's Ip as the published address for other nodes to connect to. A fairly updated 
[github repo][github es ecs] still uses this method. **And it still works.** But there is a cleaner way now.


```bash
#!/bin/bash

set -e

# Add elasticsearch as command if needed
if [ "${1:0:1}" = '-' ]; then
    set -- elasticsearch "$@"
fi

# Drop root privileges if we are running elasticsearch
if [ "$1" = 'elasticsearch' ]; then
    # Change the ownership of /usr/share/elasticsearch/data to elasticsearch
    chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/data
    exec gosu elasticsearch "$@"
fi

# ECS will report the docker interface without help, so we override that with host's private ip
AWS_PRIVATE_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
set -- "$@" --network.publish_host=$AWS_PRIVATE_IP

# As argument is not related to elasticsearch,
# then assume that user wants to run his own process,
# for example a `bash` shell to explore this image
exec "$@"
```

Now, just open up port 9200/9300 for communication within the security groups and that's it!

### Cleaner, you say?

In later versions, (along with later cloud-aws plugin versions), you can now `_ec2:privateIp_` in the elasticsearch.yml file.

```yml
network.host: 0.0.0.0
plugin.mandatory: cloud-aws
network.publish_host: _ec2:privateIp_
discovery.type: ec2
discovery.ec2.groups: xx-xxxxx
discovery.zen.ping.multicast.enabled: false
```

### Master Election, and why it is important

Next we go on to the master election part of the cluster.

Like all distributed systems, the master/leader election is an important process that allows a cluster to choose its `brain`,
for the purpose of handling allocations, state maintenance, index creations etc. It is vital to the health of the cluster. 
Elastic.co has a comphrehensive [blog post][master election] and you can read a quick intro there. 

In this context, I could set a minimum number of master nodes. 

```
The discovery.zen.minimum_master_nodes sets the minimum number of master eligible nodes that need to join a newly 
elected master in order for an election to complete and for the elected node to accept its mastership.
```

The minimum number should be set to a quorum (a majority wins situation) otherwise the cluster is inoperable.
You can read more about the split-brain scenario [here][split-brain]. For automatic election, having only 2 
master-eligible nodes should be avoided, since a quorum of 2 is 2 and a loss of either master-eligible nodes 
will result in the split-brain state.

If you dynamically scale your clusters, the below command would help with dynamically changing that number as you grow
your cluster.

```curl
PUT /_cluster/settings
{
    "persistent" : {
        "discovery.zen.minimum_master_nodes" : 2
    }
}
```

### Container memory limit and Heap Size

Next, this is something that gets tricky if you deploy to ECS and use the default settings. 

In my case, my task definitions were set to 1gb and the Elasticsearch service was running with a default of 1gb heap size.
After deploying to ECS, I noticed my docker container was just repeatedly getting stopped and restarted by the ECS agent.
For the love of my life, I couldn't figure it out why for a long time. There were no errors; and elasticsearch logs 
just announced that it was shutting itself down, gracefully.

And then I tweaked the container hard limits on ECS and the restarts stopped. Then I realised, it was a combination 
of the heap size that the Elasticsearch service was using and the hard memory limit of the container that shut it down.

So if you deploy these docker containers to ECS, its good practice to set a hard memory limit to the ECS task definition!

Ontop of that, you should also run the containers with the environment variable `ES_HEAP_SIZE=2g`. The value there should be
roughly half the size of the hard memory limit in ECS to prevent the above scenario from happening.

### Round up

That's it! I hope this post has helped you get your own cluster setup in the ECS.

I will be putting together a proper Docker compose file that deals with everything I've discussed above and run through
quickly the whole process of deployment.

Do check back in a week or two!

[zen discovery]: https://www.elastic.co/guide/en/elasticsearch/reference/5.x/modules-discovery-zen.html
[aws faq]: https://aws.amazon.com/vpc/faqs/
[split-brain]: http://blog.trifork.com/2013/10/24/how-to-avoid-the-split-brain-problem-in-elasticsearch/
[master election]: https://www.elastic.co/blog/found-leader-election-in-general
[github es ecs]: https://github.com/daptiv/elasticsearch-ecs
