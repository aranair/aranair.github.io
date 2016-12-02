---
title: Kafka + Heka to Bigquery Setup for Realtime Logs
date: 2015-07-04
tags: golang, heka, bigquery, kafka
disqus_identifier: 2015/kafka-heka-bigquery-realtime-logs
disqus_title: Kafka, Heka, Bigquery Setup for Realtime Logs
---

This is part 2 of the 3 part series of a quick intro of the realtime logging system in Wego. In [Part 1 of this series](/posts/2015/05/05/golang-protobuf "Golang with Protobuf"), I talked about how we generated Go packages for Protobuf (protocol buffers) in Wego. 

The packages allows us to process 2 different modes of communication protocol with just one set of schema defined in proto files:

- `json` package to unmarshal json requests into the generated Go structs, 
- protobuf package to unmarshal incoming protobuf messages. 

With this, we started sending test requests to the API and logged each of them into simple logfiles. However, we also needed the logs (such as clicks & visits data) to be displayed live on [Google BigQuery](https://cloud.google.com/bigquery/ "Google BigQuery") for our data scientist and market managers to have better perspectives of the traffic in realtime.

### Overview of Setup

We have a number of components in our API log setup:

- The API server that logs the requests into files
- [Heka](https://github.com/mozilla-services/heka/ "Heka") process that monitors the files and streams it to Kafka topics
- [Kafka](http://kafka.apache.org/documentation.html "Kafka") as the messaging system to distribute the messages which are then consumed by the services that need them.
- Heka server with plugin(s) that consume data from Kafka topics and upload them to:
  - [Heka Plugin to BigQuery](https://github.com/aranair/heka-bigquery "Heka-BigQuery plugin")
  - [Heka Plugin to S3](https://github.com/uohzxela/heka-s3 "Heka-S3 plugin")

### (Logs + Heka) to Kafka

For both sections of Heka, We used a fork of [this cookbook](https://github.com/augieschwer/chef-cookbook-heka "chef-cookbook-heka") in our cookbook/recipes when cooking the API + Heka servers. It helps us to manage the required config files and also help with the necessary steps to create and run the Hekad daemon as a service.

Our cookbook that generated a require config file ended up looking like this:

```toml
# This part defines the Kafka servers that the Heka plugin communicates with and also the topic that the heka plugin will consume information from. 
[<%=@topic%>-input-kafka]
type = "KafkaInput"
topic = "<%=@topic%>"
addrs = <%=@kafka_hosts%>

# This defines the configs used in the Heka server for the BigQuery Plugin.
[<%=@topic%>-output-bq]
type = "BqOutput"
message_matcher = "Logger == '<%=@topic%>-input-kafka'"
project_id = "<%=@project_id%>"
dataset_id = "<%=@dataset_id%>"
table_id = "<%=@table_id%>"
schema_file_path = "<%=@schema_file_path%>"
pem_file_path = "<%=@pem_file_path%>"
buffer_path = "<%=@buffer_path%>"
buffer_file = "<%=@buffer_file%>"
```

### Kafka to Heka to BigQuery

Plugins cannot be loaded dynamically in Heka; the only way to do it is to define it as a dependency in the cmake file and load it via the plugin_loader when building Heka. Fortunately, this can be setup via [this recipe](https://github.com/wego/chef-cookbook-heka/blob/master/attributes/source.rb) in the cookbook when creating the servers. 

A sample of the plugins we used for our hekad:

```ruby
"plugins" => [
    # Add items here like the following that's required for integration with kafka
    "add_external_plugin(git https://github.com/genx7up/heka-kafka acf3ac7a3d6d6dab313510f81828fca2f9375229)",
    "add_external_plugin(git https://github.com/uohzxela/heka-s3 master)",
    "add_external_plugin(git https://github.com/wego/heka-bigquery master)"
  ],
```

This setup will get us the bare infrastructure working, treating the plugins as blackboxes for now.

Stay tuned for the 3rd part of this series where I will go into details and discuss how the [heka-bigquery plugin](https://github.com/aranair/heka-bigquery) works!
