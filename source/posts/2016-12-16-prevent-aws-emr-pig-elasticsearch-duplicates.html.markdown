---
title: How to Prevent Duplicates: Amazon EMR Pig to Elasticsearch
description: 'I talk about some potential performance bottlenecks and issues in a default configuration like the speculative execution
when running Pig script from an EMR cluster; they are potential problems for indexing data into the elasticsearch.''
date: 2016-12-16
tags: elasticsearch, aws, emr, apache pig
disqus_identifier: 2016/aws-emr-pig-elasticsearch-issues
disqus_title: AWS EMR, Pig to Elasticearch, Part II: Issues
---

In the [previous post][1], I went through some steps I took to set up the Amazon EMR Hadoop cluster
to run Apache Pig scripts for indexing data to Elasticsearch. Today, I'll like to talk about some
problems I encountered during the testing phase and some of the configuration tweaks that I feel you
should consciously think about if you're looking to set it up in a similar way.

### Extra Documents in Elasticsearch

With the set up in the previous post[1], the EMR cluster started the data ETL (Extract, Transform, Load) and indexing to
the Elasticsearch cluster. However, when I had finished one batch of data, which was about `20-25 million` rows, I
noticed that there were way more indexed documents than actual data! There were consistently `2-3 million` more rows
than actual data which isn't a neglible number.

Furthermore from EMR stats, I could see how many rows the tasks have processed and the numbers there was actually correct.

### Possible Explanations

So I had a few hypothesis of the why this was happening.

-

[1]: https://aranair.github.io/posts/2016/12/14/aws-emr-pig-index-into-elasticsearch/
