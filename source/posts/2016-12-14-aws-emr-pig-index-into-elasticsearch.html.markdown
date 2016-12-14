---
title: How to set up Amazon EMR Hadoop with Pig to index to Elasticsearch
description: 'In this post, I quickly run through some steps I took, and the infrastructure plus some DevOps and application code that
was required to get a full production stack of jenkins, Datapipeline, Amazon emr hadoop, pig script and elasticsearch cluster to work together.'
date: 2016-12-14
tags: elasticsearch, aws, emr, apache pig, hadoop, datapipeline
disqus_identifier: 2016/aws-emr-pig-elasticsearch
disqus_title: AWS EMR, Pig to Elasticearch
---

In one of my [recent posts][self managed es], I briefly talked about using `Apache Pig`, to index an
Elasticsearch cluster. In this post, I do a walkthrough of the DevOps configurations and steps I took, along with the code
that was required to get it work at the start (barring some issues that I'll talk about in the next post).

### Production Setup

The process starts with `Jenkins`; it uses `aws-cli` to build an `AWS DataPipeLine` with config variables. This DataPipeline,
with the loaded `JSON` configurations, would then provision an Amazon EMR Hadoop cluster for the actual task.

While `Jenkins` could probably be entirely removed and a build be just triggered via DataPipeline or even EMR directly,
I feel that, this way, other devs don't have to know about certain services in AWS?

Most importantly, this abstraction takes some cognitive load off them.

### Jenkins

This line in `Jenkins` creates a `DataPipeLine` using json config files in the code.

```sh
aws datapipeline put-pipeline-definition \
  --region "${AWS_REGION}" \
  --pipeline-id "${PIPELINE_ID}" \
  --pipeline-definition file://pipeline/emr_cluster_pipeline.json \
  --parameter-values-uri 'file://'${PROPS_FILE}
```

You can read more about `pipeline-definition` and `--parameter-values-uri` in the [AWS documentation][parameterized templates].

### DataPipeLine

Let's move on to the pipeline definition files. I used something similar to this (obviously stripping away the sensitive data):

```json
{
  "objects": [
    {
      "id": "Default",
      "name": "Default",
      "failureAndRerunMode": "CASCADE",
      "schedule": {
        "ref": "DefaultSchedule"
      },
      "resourceRole": "DataPipelineDefaultResourceRole",
      "role": "DataPipelineDefaultRole",
      "scheduleType": "cron",
      "pipelineLogUri":"#{myLogsFolder}"
    },
    {
      "id": "RunJobs",
      "name": "Run the Jobs",
      "type": "ShellCommandActivity",
      "command" : "aws s3 cp #{s3SoftwareFolder} . --recursive; sh init-script.sh --verbose --run-es-pig --es-endpoint #{myEsEndpoint}",
      "runsOn": {
        "ref": "EMR_Cluster"
      },
      "schedule": {
        "ref": "DefaultSchedule"
      }
    },
    {
      "id": "EMR_Cluster",
      "name": "EMR Cluster",
      "type": "EmrCluster",
      "masterInstanceType": "m3.xlarge",
      "coreInstanceType": "m3.xlarge",
      "coreInstanceCount": "5",
      "taskInstanceType": "r3.2xlarge",
      "taskInstanceCount": "5",
      "taskInstanceBidPrice": 0.3,
      "region": "us-east-1",
      "subnetId": "subnet-xxxxx",
      "keyPair": "some-keypair ",
      "emrManagedMasterSecurityGroupId":"sg-xxxxxx",
      "emrManagedSlaveSecurityGroupId":"sg-xxxxxx",
      "terminateAfter":"6 HOURS",
      "enableDebugging":"true",
      "actionOnTaskFailure":"terminate",
      "actionOnResourceFailure":"retrynone",
      "schedule": {
        "ref": "DefaultSchedule"
      }
    },
    ...
  ]
}
```

The config above tells `DataPipeLine` to launch the EMR cluster with the id `EMR_Cluster` that contains one `m3.xlarge` master instance
and five `m3.xlarge` core instances.

#### Task Instances

For the task instances, it bids for up to 5 `r3.2xlarge` spot instances with a cost of `$0.30`
per instance hour. That's a discount of approximately `$0.088`?

**Do note that, not all instances are available as task instances**

The EMR pipeline will eventually execute the command below; it first copies essential libraries like 
maven jar files that into S3. As you'll see later, these libraries will be used in the task instances later.


```
aws s3 cp #{s3SoftwareFolder} . --recursive; sh init-script.sh --verbose --run-es-pig --es-endpoint #{myEsEndpoint}
```


### The Bash Script

It also executes `init-script.sh`. I had a bunch of other variable preparation in there but most importantly,
I pre-created the Elasticsearch index because the index that is automatically created by Pig Script
doesn't match what I want.


```bash
curl -XPUT "${ES_ENDPOINT}/data_${DAY_EPOCH}/" -d '{
  "mappings":{
     "publisher":{
        "properties":{
           "country":{ "type":"string" },
           ...
        }
     }
   }
}'
```

It also handles some miscellaneous tasks like swapping of the Elasticsearch aliases and deleting old ones.

```bash
curl -XPOST "${ES_ENDPOINT}/_aliases" -d '
{
  "actions" : [
    { "remove" : { "index" : "data_*", "alias" : "data_latest" } },
    { "add" : { "index" : "data_'${DAY_EPOCH}'", "alias" : "data_latest" } }
  ]
}'

```

### Running the Pig Script

```sh
pig -F -param ES_ENDPOINT=${ES_ENDPOINT} \
       -param INPUT="${INPUT}" \
       -param DAY_EPOCH="${DAY_EPOCH}" -f "${PHYS_DIR}/index-data.q"
```

These would automatically run in the spot instances for non-group operations. One thing to note, is that the `INPUT` variable
is where I define the S3 path to the Hadoop hdfs files to be ingested and indexed.

This **should not** be a local folder because the spot instances do not have access to them at runtime and will fail.

### Inside the Pig Script

Next, I register the required jar files; these are actually just maven files.

```pig
REGISTER piggybank.jar;
REGISTER s3://S3_BUCKET_NAME/software/libs/elasticsearch-hadoop-pig-2.3.4.jar;
```

Set the parallelism for this pig script to run in (given the right resources via the EMR cluster).

To be fair, in this particular example, this parallelism is not used.
It is only really taken into consideration for group, co-group and join operations.

```pig
SET default_parallel 20;
```

Initialize the libraries and start the ingesting of the data.

```
DEFINE CsvLoader org.apache.pig.piggybank.storage.CSVExcelStorage(',');
DEFINE EsStorage org.elasticsearch.hadoop.pig.EsStorage('es.nodes=$ES_ENDPOINT','es.http.timeout=5m');
```

The `$ES_ENDPOINT` variable is a comma delimited variable that has the ports included as well, e.g. `52.167.183.192:9200`

There are other variables that you can define here such as `es.mapping.id` that defines the id for the Elasticsearch for example,
instead of automatically letting Elasticsearch generate one.

```
raw_data = LOAD '$INPUT'
           USING CsvLoader AS (
             bundle_id:chararray,
             publisher:chararray,
             exchange_id:int,
             country:chararray,
             categories:chararray,
             ad_size:chararray,
             interstitial:int,
             apis:chararray,
             platform_id:int,
             device_os_id:int,
             video_type:int,
             ad_type:int,
             app_id:chararray,
             publisher_id:chararray,
             assets:chararray,
             frequency:long);
```

#### Extract, Transform, Load

This last step runs through each of the rows of the data and generates a subset of the data to be indexed into Elasticsearch.

```
filtered_data = FOREACH raw_data
                GENERATE $0, $1, $2, $3, $4, $5, $7, $8, $9, $10, $11, $14, $15;

STORE filtered_data INTO 'data_$DAY_EPOCH/publisher' USING EsStorage();
```

You could do many different variations of ETL in Pig Script. For instance, you can combine some of the columns
into one column.

I've found that in Pig `v0.12.0`, concatenation of multiple columns is quite finicky because you can't
combine multiple columns at one time; it has to be sequential like this:

```pig
d = FOREACH raw_data
    GENERATE
      CONCAT($0, (chararray)CONCAT($1, (chararray)CONCAT($2, $3))) as id, $4, $5, $6;
```

Note that, without the `(chararray)`, you quickly run into errors about forcing an explicit type cast.

### Summary

I've done an run-through of each of the components in a production setup: `Jenkins`, `DataPipeline`, `EMR/Pig`.

I hope this helps people out there figure out how to spin up, either periodically or on-demand, 
an Amazon EMR cluster running Hadoop to do some basic ETL to then index into an Elasticsearch cluster.

In the next post, I shall discuss some of the pitfalls, EMR / Elasticsearch performance tuning 
issues that leads to random failures in the EMR cluster. All of them could cause some rather tricky issues 
in the indexing task; one of the ones that I have personally experienced myself is having 
duplicated documents in the Elasticsearch cluster despite having only processed a correct number of them.

If you have any questions, feel free to comment below!

[self managed es]: https://aranair.github.io/posts/2016/11/22/aws-elasticsearch-elastic-cloud-self-managed/
[parameterized templates]: http://docs.aws.amazon.com/datapipeline/latest/DeveloperGuide/dp-custom-templates.html
