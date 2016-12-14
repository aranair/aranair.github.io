---
title: Debugging Amazon EMR Hadoop + Pig + Elasticsearch in ECS
description: 'A post about some of the issues, like performance bottlenecks and speculative execution of the EMR
that may cause problems like having extra documents to be indexed into Elasticsearch.'
date: 2016-12-16
tags: elasticsearch, aws, emr, apache pig
disqus_identifier: 2016/aws-emr-pig-elasticsearch-issues
disqus_title: AWS EMR, Pig to Elasticearch, Part II: Issues
---

In the [last post][last post], I went through some steps I took to set up the Amazon EMR Hadoop cluster
to run Apache Pig scripts on for indexing data to Elasticsearch. Today, I'll like to talk about some
issues I encountered during the testing phase of this cluster and some of the configuration tweaks  that you
should consciously think about when you set this up.

[last post]: https://aranair.github.io/posts/2016/12/14/aws-emr-pig-index-into-elasticsearch/
