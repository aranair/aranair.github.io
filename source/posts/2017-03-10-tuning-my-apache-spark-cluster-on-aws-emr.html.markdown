---
title: 'Data Processing in Apache Spark on Amazon EMR'
description: 'In this post, I talk about some of the issues I faced while setting up a Spark cluster to run some
data processing tasks, and some choices and considerations I made while trying to tune the performance
of the cluster.'
date: 2017-03-10
tags: apache spark, scala, AWS, EMR, hadoop
disqus_identifier: 2017/tuning-apache-spark-cluster-on-amazon-emr
disqus_title: Data Processing with Apache Spark Cluster on Amazon EMR
---

Lately, I worked on some data integration at Pocketmath where I wrote a 
bunch of Spark scripts in Scala to run some transformations on a data set of about 
250GB on a monthly basis. In this post, I'll talk about some of the 
problems I encountered, and some considerations while setting up the cluster and running
the Spark tasks.

### Dataset Size

The size of the data set is about 250GB, which isn't quite close to the scale other data 
scientist/engineers handle, but is easily one of the bigger ones for me. Nonetheless, I do think the 
transformations are on the heavy side; it involves a chain of rather expensive operations. 

Because of the sensitive nature of the data, I'm going to skip the nitty-gritty details of the task.
I'll run through the kind of steps that were included in the script.

### Multiple Shuffle Operations

The script starts off with multiple `JOIN`s into a `UNION`, `EXPLODE`, `SORT` within partition, 
then `GROUP` and `COLLECT` into another `SORT` eventually. They're 
_pretty_ expensive shuffle operations and as you might imagine, doing this on this data size did
pose some problems at first when I wasn't so familar with the details of how Spark handles
memory allocations.

A picture speaks a thousand words:

// insert shuffle image

### Generating Ranks

Secondly, I also had to split a file that looks like the examples below. Essentially, you can imagine 
them to be ranks or row numbers. 

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

It turns out that it is a difficult operation for Spark to handle. Actually it is probably an expensive task for any
distributed system to perform. Also, I was working mostly with `Dataframes` in Spark 2.0 
and the only way that I know of currently to generate these row numbers is to first convert 
into an RDD and do a `zipWithIndex` on it. (There is another method but it involves moving all the data into one node.)

### Executer Cores and Memory Allocation

When I submit the Spark task to the Amazon EMR, I manually set the 
`--executor-cores` and `--executor-memory` configurations. The calculation is somewhat 
non-intuitive because I had to manually take into account the overheads of `YARN`, 
the application master/driver cores and memory usage et cetera.

In general, YARN overheads take roughly 7% (?) and reducing some from there is good practice, to ensure enough
is left for system processes and Hadoop.
  
Say for an instance of `r3.8xlarge` with 122GB of memory and 16 cores:

```bash
$CORES_PER_DRIVER=4
$MEMORY_PER_DRIVER=24G

$CORES_PER_EXECUTOR=4
$MEMORY_PER_EXECUTOR=24G

# 122GB/16 * (1 - 0.07) = 28G
# -> 24G
```

With 4 cores per executor, each instance could _potentially_ run 4 executors. To account for the overhead,
I multiply the memory by `(1 - 0.07)`, which works out to be `28G`. 

I further reduced this to allow for other overheads for the driver and other processes like Hadoop and the OS. 
Personally, I use `24G` in this set up, but you can probably get away with `26G`.

This directly affects how many executors that can be deployed per instance and also affects the
memory available for shuffle operations.

### Task Memory and Partition Size

One thing that I found to be quite critical is the task partition size; it is something that I think 
should be considered carefully because the task _will_ slow down by a lot if it starts to spill to disk.

In my case, there are roughly 300+ files that goes into my cluster and each of them are roughly 800-900MB.

Initially, I just set the `default_parallelism` in Spark and expected the system to automatically 
handle the rest, and was surprised to see some stages spilling to disk causing the cluster to slow down. 
I later found out that `default_parallelism` is only used for certain operations and for the rest of the time, 
Spark would infer the size by looking at the input from a previous stage, which happens to be the number of files
it reads: 300. 

As you might imagine, having only 300 paritions is not ideal since each partition will be too
big to fit into memory (alright, this actually depends on your executor setup).

I had to force a repartition via `df.repartition(2000)` right after the reading of the files. 
This would immediately add a shuffle step but performs better later on in other tasks in my opinion, YMMV though.

### Shuffle Memory Usage, Executor Memory-Core ratio

In general, I tried to optimize the system to avoid any form of spilling, both memory and disk. If
the entire shuffle read can fit into memory, it can be avoided.

Each core in an executor runs a single task at any one time. Hence, with `26G` per executor and 4 cores each executor, 
the HEAP_SIZE allocated for each task is `26/4` or `4G`.  However, not all the memory allocated can be used 
for shuffle operations. The memory available for shuffle works out to be `24/4 * 0.2 * 0.8 = 0.96GB per task` where
0.2 and 0.8 are the default values of `spark.shuffle.memoryFraction` and `spark.shuffle.safetyFraction`
respectively.

With about 2000 paritions and 250GB data, each partition or task works out to be only about 125MB, which is close 
to the 128MB , I do not know how to find it without running the entire process once first and going through the formula
below with the numbers.

```ruby
shuffle_write * shuffle_spill_mem * (4)executor_cores
———————————————————————
shuffle_spill_disk * (24)executor_mem * (0.2)shuffle_mem_fraction * (0.8)shuffle_safety_fraction
```

This area turned out to be one of the bigger improvements while tuning my cluster. Key takeaway: It is definitely 
better to err on a higher number of partitions, which results in a smaller task bite size.

### Counter Example

To quickly illustrate how things can go wrong, I'll use one of my iterations for the configurations.
I used `c3` & `m3` instances and only allocating 10G for 3 cores. This works out
to be about 500MB for each task. With only 300 partitions, my task sizes were well beyond 850MB. When the task size
is bigger than the shuffle memory available to each core/task, data will get spilled to disk during shuffle operations. 

// insert spill image

After increasing the partition count to 2000, I believe it should be more efficient to run `c3.4xlarge` instances with 
a lower memory to core ratio, instead of the `i2.2xlarge` memory instances that I used. I did this to
eliminate any possibility of a memory constraint issue. 

### Spot Instances and HDFS

Amazon EMR allows you to bid for spot instances at a fraction of the cost of the original instance
price. I use them frequently and have found them to be massively discounted during some hours.

I had HDFS running for the `shuffles`. The results of each `result stage` are stored into the HDFS for future use. 

At first, I ran a test using spot instances completely, even for the CORE instance group, which turned out to be
a big mistake.

When I lose the units inevitably, from getting outbid during peak hours, I lose the data in them. Spark is unable 
to recover fully from the lost data, even after taking extra time for stage-retries. I'm not sure if it was my setup
that was causing it, but I found it easier to eliminate this entirely.

### Instance Setup 

I recommend using non-spot, disk-optimized instances for the CORE instance group. For example, I got two 800GB SSDs 
with an `i2.2xlarge` which costs only ~$1.70 (TODO: factcheck) per hour. In comparison, `c3` or `r3` instances 
give you way lesser disk space.

For the actual computation in the *task instance group*, I would switch to using only spot instances 
(`r3.8xlarge` or `c3.8xlarge`). I've found that this was the most cost-efficient to run my task.

To bring things into perspective, I used 20 spot instances of `r3.8xlarge`(just to eliminate the potential issue of 
shuffle spills) and 4 `i2.2xlarge` on-demand instances for the HDFS; the task took ~10 hours to complete.

This should improve a lot with compute instances when I lower the executor memory to core ratio. If I swap
the r3 instances for c3 instances, this should run a lot faster, assuming task size is calculated properly and spills
don't happen anymore.

### To Persist or Not?

In some of the heavy shuffles, I found that it was sometimes faster to persist them on DISK to 
prevent re-calculations. This is especially true if you're re-using scala variables further
down the chain. Obviously, you'll need to look into the total calculation time and compare it with
the network read bytes (divided by an average network throughput) to see if it is worth while to
persist. 

One good thing is that the Amazon EMR handles the HDFS integrations seamlessly which makes
it effortless to do a `DISK_ONLY` persistance. One thing to note is that since I was doing some disk persistance, 
I do end up using more disk space than the total data size. This is also why I chose to use the `i2` instances
for HDFS.

### Row Number

In my case, having to generate a key for each row was the one requirement I couldn't remove. And it forces me to persist.
Without persisting, it would cause re-calculations and `zipWithIndex` could potentially produce results which are 
different each time and be rendered absolutely useless.

### Resources

All of the information has been sourced from multiple sources including, but not limited to:

- 
-
- 
- 

