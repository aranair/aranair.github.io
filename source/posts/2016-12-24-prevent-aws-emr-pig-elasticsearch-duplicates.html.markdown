---
title: 'Preventing Duplicates: Amazon EMR Pig to Elasticsearch'
description: 'I talk about some potential performance bottlenecks and issues in a default configuration like the speculative execution
when running Pig script from an EMR cluster; they are potential problems for indexing data into the elasticsearch.'
date: 2016-12-24
tags: elasticsearch, aws, emr, apache pig
disqus_identifier: 2016/aws-emr-pig-elasticsearch-issues
disqus_title: AWS EMR, Pig to Elasticearch, Part II- Issues
---

In the [previous post][1], I went through some steps I took to set up the Amazon EMR Hadoop cluster
to run Apache Pig scripts for indexing data to Elasticsearch. In today's series, I walk through some of the
problems I encountered when I set the system up and some of the configuration tweaks to both
Elasticsearch and the EMR cluster that I feel you should consciously think about if you're looking 
to set it up in a similar way.

### Extra Documents in Elasticsearch

With the set up in the [previous post][1], the EMR cluster starts the data ETL (Extract, Transform, Load) and indexes to
the Elasticsearch cluster. I had already let it run for a day or two, before I noticed an issue. 

I had finished one batch of data, which was about `20-25 million` rows, I noticed that there were way 
more indexed documents than actual data! There were consistently `2-3 million` more rows
than actual data. It certainly isn't a neglible difference.

From EMR stats, I could see how many rows the cluster has processed and the number there was actually correct?!
I was puzzled at why this was happening.

### Hypothesis

I came up with a few hypothesis at first:

1. EMR tasks consume too much memory, causing EMR jobs to fail and retry.
causing EMR tasks to fail and retry.
2. Too little memory reserved for Elasticsearch heap size.
3. Pig script not handling rejection of documents properly, causing retries.
4. Pig script parallelism was too high; Elasticsearch cluster was getting overloaded by the indexing,

All of the above, technically, could cause duplicates to be sent to Elasticsearch. I did end up 
making a few changes to configs before it eventually worked and learnt a few things along the way!

Below, I document some of the steps I took before I found out why. Some of these are actually
helpful even if you don't run into this issue but if you'll like to skip right to the solution, fast-forward 
to the last section ;)

### Tweaking Elasticsearch

I increased the memory allocation in ECS for the Elasticsearch task, and made some temporary changes to the
to the Elasticsearch index settings during the indexing phase:

```
"settings": {
  "index": {
    "number_of_shards":5,
    "number_of_replicas":0,
    "max_result_window":1,
    "refresh_interval":"-1"
  },
  ...
}
```

This stops the `refresh` of the index and stops `replica propagation` during the indexing to reduce flow of
data. After the indexing is done, I would revert it back to normal via:

```
"settings": {
  "index": {
      "number_of_replicas": 2,
      "max_result_window": 10000,
      "refresh_interval" : "30s"
  },
  ...
}
```

The combination of the memory increase and the above tweaks did speed up the indexing process overall 
but the duplicate documents were still getting indexed after. 

*Hypothesis rejected*.

### Pig Script

First, I lowered the parallelism in the Pig Script to get it to index slower (just to eliminate this as a problem).
Unfortunately, later on I found out that the parallelism is only used for certain operations like group/join etc. *Dead-end*.

Then I found out that the `elasticsearch-hadoop-pig-2.3.4` plugin already handles document rejection 
and retries properly. 

*Great, another dead-end!*

### EMR Memory Usage

I then tried to change the EMR cluster's task instance sizes to have about `60GB` memory to get that possibility 
out of the way. (It was also at that point, I learnt that only a few instance types are available for selection for spot 
instance bidding). 

*That too didn't help.*

### Hadoop Speculative Execution

let me just quickly run through what is speculative execution; it is a feature built to 
combat random delays and slowdowns in a distribution environment.

```
As the EMR cluster processes data, some machines would naturally finish their task quicker than others.

To prevent a system-wide slowdown because of the slower tasks, Hadoop always tries to detect slower-than-expected machines/jobs and assigns a replica of their tasks to other free nodes (or spins up new nodes), as a backup. 

The node that finishes first, would be considered successful; the other slower ones would be killed.
```

This, as you might expect, would create a ton of problems for Elasticsearch indexing tasks.

Towards the end of each indexing cycle, Elasticsearch would slow down by a fraction and Hadoop 
would detect the slowdown and spin up all those backup tasks that would be indexing the exact 
same data at the same time! Since I left the `id` generation to Elasticsearch (recommended), this would
ultimately cause the duplicates I saw.

*Finally!*

### How Do I Fix It Then?

For me, there were 2 ways out.

I could generate a composite column to serve as an unique `id` for each Elasticsearch row that is indexed, 
so that even if they were duplicated, Elasticsearch would be able to throw away all the duplicate ones. 
However, this was entirely not viable for the data I was indexing as the composite column would 
take up so much space it wouldn't really be worth it.

The way I chose was to disable the speculative execution in the Hadoop environment altogether. 

For EMR software version 4 and below, you could re-define the bootstrap action for the Hadoop environment.

```
"bootstrapAction": [
  "s3://us-east-1.elasticmapreduce/bootstrap-actions/configure-hadoop,-m,mapred.map.tasks.speculative.execution=false,-m,mapred.reduce.tasks.speculative.execution=false"
],
```

For API version 5+, you would need to do it via the `mapred-site` classification via configuration JSON files.
You can read more about them in [this documentation][2] for EMR V5.

```
[
  {
    "Classification": "mapred-site",
    "Properties": {
      "mapred.map.tasks.speculative.execution": "false",
      "mapred.reduce.tasks.speculative.execution": "false"
    }
  }
]
```

### Round up

I hope my learnings can help anyone out there facing a similar issue; do let me know in the comments
if you have any questions!


[1]: https://aranair.github.io/posts/2016/12/14/aws-emr-pig-index-into-elasticsearch/
[2]: http://docs.aws.amazon.com/ElasticMapReduce/latest/ReleaseGuide/emr-configure-apps.html
