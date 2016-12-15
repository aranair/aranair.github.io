---
title: How to Prevent Duplicates: Amazon EMR Pig to Elasticsearch
description: 'I talk about some potential performance bottlenecks and issues in a default configuration like the speculative execution
when running Pig script from an EMR cluster; they are potential problems for indexing data into the elasticsearch.''
date: 2016-12-16
tags: elasticsearch, aws, emr, apache pig
disqus_identifier: 2016/aws-emr-pig-elasticsearch-issues
disqus_title: AWS EMR, Pig to Elasticearch, Part II: Issues
---

In the [last post][last post], I went through some steps I took to set up the Amazon EMR Hadoop cluster
to run Apache Pig scripts for indexing data to Elasticsearch. Today, I'll like to talk about some
problems I encountered during the testing phase and some of the configuration tweaks that I feel you
should consciously think about if you're looking to set it up in a similar way.

### Extra Documents in Elasticsearch

[last post]: https://aranair.github.io/posts/2016/12/14/aws-emr-pig-index-into-elasticsearch/
