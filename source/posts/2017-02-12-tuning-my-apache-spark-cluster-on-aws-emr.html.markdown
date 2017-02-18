---
title: 'Tuning My Apache Spark Cluster on Amazon EMR'
description: 'In this post, I
date: 2017-02-02
tags: apache spark, scala, AWS, EMR, hadoop
disqus_identifier: 2017/tuning-apache-spark-cluster-on-amazon-emr
disqus_title: Tuning My Apache Spark Cluster on Amazon EMR
---

Lately, I worked on some partner data integration at Pocketmath where I wrote a 
bunch of Spark scripts in Scala to run some transformations on a data set of about 
250GB on a monthly basis. In this post, I'll talk about some of the 
problems I encountered, and some considerations while setting up the cluster and running
the Spark tasks.

### Resources

All of the information has been sourced from multiple sources including, but not limited to:

- 
-
- 
- 

### Dataset Size

The size of the data set currently stands at 250GB, which isn't quite close to the scale some data 
scientist/engineers handle, but is easily one of the bigger ones for me. However, I do think the 
transformations are a bit on the heavy side. It involves a chain of rather expensive operations. 

Because of the sensitive nature of the data, I decided that I should skip the details of the task.
However, I'll roughly go through what are the kind of steps that were included in the script.

### Multiple Shuffle Operations

The scripts first starts off with multiple `JOIN`s into a `UNION`, `EXPLODE`, `SORT` 
within partition, into `GROUP` and `COLLECT` then another `SORT` eventually. They're 
all expensive `SHUFFLE` operations and as you might imagine, doing this on this data size did
pose some problems at first when I wasn't so familar with the details of how Spark handles
memory allocations.

// insert shuffle image

### Generating Ranks

Secondly, I also had to split a file that looks something along the lines of the following:

```csv
51abebcfab2ef2abeed2f 8,120,384,898 
21abfbbeef5791adef3f2 1,9,1214,8827 
...
```

Into two files:

```csv
51abebcfab2ef2abeed2f 1
21abfbbeef5791adef3f2 2
...
```

```csv
1 8,120,384,898 
2 1,9,1214,8827 
3 ..
4 ..
...
```

Essentially, you can imagine them to be ranks or row numbers. It turns out that
it is a difficult operation for Spark to handle; or rather an expensive task for any
distributed system to perform. Also, I was working mostly with `Dataframes` in Spark 2.0 
and the only way that I know of currently to generate these row numbers is to first convert 
into an RDD and do a `zipWithIndex` on it.

### Executer Cores and Memory Allocation

When I submit the Spark task to the Amazon EMR, I choose to manually set the 
`--executor-cores` and `--executor-memory` configurations. The calculation is somewhat 
un-intuitive because I had to manually take into account the overheads of `YARN`, 
the application master/driver cores and memory usage etc among other things.

To give an example, say for an instance of `r3.8xlarge` with 122GB of memory and 16 cores:

```bash
# 122GB/16 * (1-0.07) = 28

$CORES_PER_DRIVER=4
$MEMORY_PER_DRIVER=24G

$CORES_PER_EXECUTOR=4
$MEMORY_PER_EXECUTOR=24G
```

With 4 cores per executor, each instance could -potentially- run 4 executors. To account for the overhead,
you can multiply the total memory by `1-(0.07)`, which works out to be `28G`. I suggest further
reducing this to allow for other overheads for the driver and other processes like Hadoop and the OS. 
Personally, I used 24G in this set up.

This directly affects how many executors that can be deployed per instance and also affects the
memory available for shuffles which I'll elaborate in a bit.

### Task Memory and Partition Size

One thing that I found quite critical was the task partition size. The input files into my system 
were files of ~800-900MB and that works out to be about ~310 files on average.

At first I simply set the `default_parallelism` in Spark and expected the system to automatically 
handle the rest, and was surprised to see some stages spilling to disk causing the cluster to slow down. 
I later found out that `default_parallelism` is only used for certain operations and for the rest of the time, 
Spark would infer the size by looking at the input from the previous stage, which incidentally is the number of files
it read, and in my case, 300. As you might imagine, having only 300 paritions is not ideal since
each partition will be too big to fit into memory normally.

I got around this by setting the task size manually by doing a `df.repartition(3500)` right after
the input. This would immediately add a shuffle step but performs better later on 
in other tasks in my opinion, YMMV.

### Shuffle Memory Usage, Executor Memory-Core ratio

In general, I tried to optimize the system to avoid any form of spilling, both memory and disk. If
the entire shuffle read can fit into memory, it should avoid this.

For each core in an executor, it runs a single task. Furthermore, not the entire memory space 
allocated for each executor per task can be used for shuffles. Using the same example above: 
the memory available for shuffle use works out to be `24/4 * 0.2 * 0.8 = 0.96GB per task` where
0.2 and 0.8 are the default values of `spark.shuffle.memoryFraction` and `spark.shuffle.safetyFraction`
respectively.

With about 3500 paritions and 250GB data, each partition or task works out to be only about 70MB.
The exact shuffle memory required is more than that but unfortunately I do not know 
way to evaluate how much it requires other than running the cluster once to get some
statistics and calculating it from there.

Previously, with only 300 partitions (resulting in 800+ MB task size), this would still fit IMO, 
but after increasing the partition count to 3500, I believe it is more efficient to run `c3.4xlarge`
instances with a lower memory to core ratio.

Another note is that it is better to err on a higher number of partitions.

// insert spill image

### Spot Instances and HDFS

Amazon EMR allows you to bid for spot instances at a fraction of the cost of the original instance
price. I use them frequently and have found them to be massively discounted during some hours.

For this task, I have HDFS running for the `shuffles`. The results of each `result stage`
are stored into the HDFS for future reference. 

At first, I ran a test of running spot instances completely, even for the CORE instance group 
but when the units spin down, I have found that Spark is unable to recover from the 
lost data (in the case of a spot instances losing their bids), even after taking an 
extended time for retries later on.

As such, I recommend using non-spot disk-optimized instances for the CORE instance group. For
example, I could get 2*800GB SSDs with an `i2.2xlarge` which costs only ~$1.70 (TODO: factcheck) 
per hour. In comparison, `c3` or `r3` instances give you way lesser disk space.

For the actual computation in the TASK instance group, I would switch to using only 
spot instances (`r3.8xlarge` or `c3.8xlarge`). I've found that this was the most 
cost-efficient to run my task.

To bring things into perspective, I used 20 spot instances of `r3.8xlarge`(just to eliminate
the potential issue of shuffle spills) and 4 `i2.2xlarge` on-demand instances; 
the task took ~10 hours to complete for the first try.

This should improve a lot with compute instances when I lower the executor memory to core ratio.

### To Persist or Not

In some of heavy shuffles, I found that it was sometimes much faster to persist them on DISK to 
prevent re-calculations. This is especially true if you're re-using scala variables further
down the chain. Obviously, you'll need to look into the total calculation time and compare it with
the network read bytes (divided by an average network throughput) to see if it is worth while to
persist. One good thing is that the Amazon EMR handles the HDFS integrations seamlessly which makes
it effortless to do a `DISK_ONLY` persistance.

### Row Number

The key thing that decided if I should persist or not was because of the rank number. On 2
separate re-calculations, `zipWithIndex` could potentially produce different results which 
would render the results useless.
