---
title: Thrift Gem 0.8.0 with Mavericks 10.9
date: 2014-04-25 00:00 SGT
tags: rails
---

There seems to be some issue with building the thrift gem 0.8.0 on Mavericks. Taken from this discussion: [Jira Issue](https://issues.apache.org/jira/browse/THRIFT-2219 "Jira")

> The issue is that in Mavericks, strlcpy is now defined as a macro if you install the SDK. This conflicts with the duplicate declaration of strlcpy as a function in strlcpy.h. The fix should be simple: don't re-declare the strlcpy prototype in strlcpy.h. Just remove that line, since <string.h> is guaranteed to have declared strlcpy declared already--this is tested for already in lib/rb/ext/extconf.rb via the call to have_func("strlcpy", "string.h").

### The Solution

As suggested as well from that thread, the issue seems to be pretty easily solvable by either of these two methods:

`gem install thrift -v '0.8.0' -- --with-cppflags='-D_FORTIFY_SOURCE=0'` 

or 

`bundle config build.thrift --with-cppflags='-D_FORTIFY_SOURCE=0'` 

The only difference is that the first one will work one off and the second method should work for future builds just for thrift if you're using bundler.

