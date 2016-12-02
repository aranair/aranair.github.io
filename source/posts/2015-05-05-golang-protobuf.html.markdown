---
title: Golang + Protobuf
date: 2015-05-05
tags: golang, protobuf
disqus_identifier: 2015/golang-and-protobuf
disqus_title: Golang and Protobuf
---

(This is part 1 of the 3 part series where I discuss how we handled one of our new API projects and the usage of Protobuf + Heka + Kafka + BigQuery to view realtime logs.)

Recently, I've had the chance to work with Golang in Wego to build our analytics API that will log our visits into flat files + upload them into Kafka for further processing, with one caveat: we're using Protobuf Buffers (or otherwise just Protobuf) for our serialisation of data.

### What is Protobuf?

Its basically a protocol that comes with a language [proto](https://developers.google.com/protocol-buffers/docs/proto "proto") with which you define your data structure once and then you can use this source code to generate helpers/classes/models for different languages such as Golang, Python, Ruby etc .. Do note that only C++, Python and Java are officially supported right now.

Think of it as XML, JSON but smaller, faster, and simpler; yet at the same time pretty defined and structured as well. 
So, Wego is set on replacing the semi-spaghetti JSON communication that we're currently working with, with Protobuf. 

### Context

As usual, the process always have some form of a bump for us to overcome before being able to use it. Typically, I think most golang protobuf repos will have rather simple/flat structure. 

Our repo was built in a slightly odd that worked well to define the structure for other protobuf generators (we also use Protobuf for Ruby and Java). Below is a rough idea of how it looked like before a huge round of changes:

```
# OLD STRUCTURE
- protos
  - wego-protos
  - base.proto
  - flights.proto
  - hotels.proto
  - analytics.proto
  
  - wegosdk-protos (actually a symlink to ANOTHER repo)
  - flights
  - base.proto
  - hotels
  - base.proto
```

### The 1st Hurdle

Well technically it isn't a bug, more like convention. The basic command for protoc (the tool that converts .proto files) which is shown below, is meant to be run once per package. This command will then look at the included files for a package name to compile them into. But initially, our files that were all in the root folder belong to separate packages. 

```ruby
protoc --proto_path=./protos \
  --go_out ./libs/wego-protos-go \
  ./protos/wego-protos/flights.proto
  
protoc --proto_path=./protos \
  --go_out ./libs/wego-protos-go \
  ./protos/wego-protos/hotels.proto
  
...
...
```

Specifying one file at a time and repeating it for the 4 files did not work either. Because it would break the name spaces inside them; they essentially become the same package instead of separate packages. 

This issue doesn't really exist in other languages because I think files are resolved file level in Java/Ruby but at a package level in Golang. [this issue](https://github.com/golang/protobuf/issues/8 "import issue") and [this commit](https://github.com/golang/protobuf/commit/dded9133a99a3cd7c3a9d24a9f85c2b8ef76ff31 "commit") describes it in fuller details.

And so to get past it, we restructured the files in this way, such that each of the packages reside in individual folders, following the convention of Golang. 

```
# NEW STRUCTURE
- protos
  - wego-protos
   - wego
    - base.proto
   - flights
      - base.proto
   - hotels
    - base.proto 
   - analytics 
    - base.proto

  - wegosdk-protos (actually a symlink to ANOTHER repo)
  - flights
  - base.proto
  - hotels
  - base.proto
```


### The 2nd Problem

This problem is abit uglier. So in the ```wego-protos``` files, we do imports that are from the other repo ```wegosdk-protos```. It is an entirely separate git repo that is included as a git submodule. 

```
package wego.flights
import "wegosdk-protos/wegosdk/base.proto";
```

The generated package name from that snippet was wrong. I had to include an undocumented option go_package in proto2 (it is available in proto3). ``` option go_package = "wego"; ```


This actually generates ```import "wegosdk-protos/wegosdk/base"``` in the *.pb.go files. It was clear that we needed to customise the import paths + package names.

Looking at [this file](https://github.com/golang/protobuf/blob/master/protoc-gen-go/plugin/Makefile#L38 "protobuf code"), we found that the --go-out has a "M" flag that allows us to modify the final import paths to point to the correct github.com/wego/wego-protos filepaths. We also don't do another ```go get github.com/wego/wegosdk-proto```; basically treating it as one repo.


### The Solution

Finally I ended up with this long --go-out option to somewhat "replace" all of the default imports (that works with other languages) to use the correct $GOPATH source path.

```
--go-out=Mwegosdk-protos/wegosdk_hotels/base.proto=github.com/wego/wego-protos/libs/wego-protos-go/wegosdk-protos/wegosdk_hotels,
Mwegosdk-protos/wegosdk_flights/fares.proto=github.com/wego/wego-protos/libs/wego-protos-go/wegosdk-protos/wegosdk_flights,
Mwegosdk-protos/wegosdk_flights/base.proto=github.com/wego/wego-protos/libs/wego-protos-go/wegosdk-protos/wegosdk_flights,
Mwegosdk-protos/wegosdk/base.proto=github.com/wego/wego-protos/libs/wego-protos-go/wegosdk-protos/wegosdk,
Mwego-protos/wego_hotels/base.proto=github.com/wego/wego-protos/libs/wego-protos-go/wego-protos/wego_hotels,
Mwego-protos/wego_flights/base.proto=github.com/wego/wego-protos/libs/wego-protos-go/wego-protos/wego_flights,
Mwego-protos/wego_analytics/base.proto=github.com/wego/wego-protos/libs/wego-protos-go/wego-protos/wego_analytics,
Mwego-protos/wego/base.proto=github.com/wego/wego-protos/libs/wego-protos-go/wego-protos/wego,

```

On hindsight, it would probably have been alot easier if we just treated wegosdk-protos as an entirely separate project in Golang. Nevertheless I think the workaround is reasonable if we wanted to work with only 1 repo at that time.


