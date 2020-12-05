---
title: 'Concourse CI'
description: ''
date: 2020-11-28
tags: concourse, CI/CD, devops
disqus_identifier: 2020/building-oci-images-concourse
disqus_title: Building OCI Images in Concourse
---

I run a mid-sized [Concourse CI][concourse-ci] cluster for Tulip, that runs ~2-3k fairly resource-intensive builds weekly.
I've encountered a fair share of issues with it, but overall, my experience with it has been fairly positive. I can't speak about
Github Actions, or TravisCI and CircleCI but my experience has been vastly better than that with Jenkins (another popular CI/CD tool).
It is open-source and is continuously improving with fairly frequent releases with good core contributing members. I'm actually
surprised not more people are onboard this, which is one of the reasons that prompted me to write this series.

Over the next couple posts or so, I'll be talking about some random topics related to Concourse. They might help with your decision to onboard
(or skip) Concourse.

### Infrastructure

We use [EngineerBetter/ControlTower][control-tower], also formerly known as ConcourseUp for the initial setup.
The initial setup is fairly effortless without tweaks; most of the custom configuration is done through [Bosh][bosh] directly.

The infrastructure looks something like this:
<insert image>

### Triggering builds for Pull Requests

This is a really common usecase of CI/CD. Everytime a pull request is updated with a new commit in Github, a build is triggered to
do a range of tasks, from simple go lints, unit tests, to building artifacts to full-scale integration tests. This flow is achieved through webhooks
events from Github. The receiver of those webhook events is a [github-pr-resource][pr-resource] plugin (or similar forks like
[digitalocean's][digitalocean-github-pr-resource]).

You might imagine that a pipeline can be triggered immediately after it interprets the webhook event. It's worth clarifying
that this concept of triggering a pipeline is incorrect; that's not how it works in Concourse. Pipelines are basically just set of jobs
and they are all independently scheduled. New builds are created by the scheduler when it detects that a job's dependent (e.g. trigger: true)
resources have changed.

So, what really happens after it processes a webhook event? The pr-resource queues a `check` that reaches out to Github to query for open pull-requests updates
through their GraphQL API (filtering from the latest update in a previous pull). From there, it updates the lists of versions
for the resource and rely on the scheduler to do the rest as mentioned above^.

To be honest, this flow isn't one of the strong points of Concourse. It is somewhat awkward - leading to the perception that it is slower to
trigger than other popular builds, among other concerns, such as rate-limiting if you have too many open pull-requests. For tulip though, I'll say
that this setup works acceptably well.

And, this has been acknowledged as such by the core members and listed as a primary focus in the [v10 roadmap][v10-roadmap], which I'm pretty excited about!

### `default_check_interval` / `check_recycle_period` / Github Ratelimiting <a id="intervals" href="#intervals">#</a>

Default (Bosh) setting for the web worker node's `default_check_interval` is 1 minute. This means that for every resource you define, you'll be running a check,
hitting whatever api that might be required. For example, for a [git-resource][git-resource] that hits Github, each call counts towards the rate-limit that Github sets.
It's fairly high at 5000 per hour, but it is still exhaustible if you're not careful!

Relatedly, there is another setting in Bosh, for the web/scheduler node, `check_recycle_period` - which decides
how often the containers for resource checks are garbage-collected. The default is set to 6 hours. I made the mistake of assuming that this GC interval
should be reduced when I saw a ton of containers used for checks lying around, doing nothing. This depends on the implementation of the particular
concourse resource but in my case, the [git-resource][git-resource] would re-query (history) of versions and end up consuming unnecessary calls to Github,
which led to us getting rate-limited occasionally. So, if you're using this resource, leave it around to take advantage of the caching!

### Resources and Scheduling Woes

We have resource-intensive jobs that can be triggered at the same time. When that happens, our cluster sometimes run into
resoure allocation issues. I've tested the experimental feature `limit-active-tasks` to limit the number of tasks per worker but in my opinion,
I don't think that worked out well.

Technically, we don't want to limit a job if it's just not resource-intensive. Example: the periodic resource checks.

For a time,

### Storage Volumes

This took a really long time to figure out. On hindsight, I'm not sure why I didn't check this.

Depending on individual workload, I've found that Concourse has issues dealing with

### Docker in Docker
### Overlay vs btrfs

Concourse ships with btrfs by default

### Registry Mirror

I'm sure everyone has noticed by now but Dockerhub recently put a new rate-limit on unauthenticated pulls.
We learned about this the hard way. We had a bunch of builds fail on us and scrambled to run a registry mirror as a pull-through cache.
There are a couple gotchas though, at least at the time of this post.


[bosh]: https://bosh.io/docs/
[github-pr-resource]: https://github.com/telia-oss/github-pr-resource
[git-resource]: https://github.com/concourse/git-resource
[digitalocean-github-pr-resource]: https://github.com/digitalocean/github-pr-resource
[v10-roadmap]: https://blog.concourse-ci.org/core-roadmap-towards-v10/
[control-tower]: https://github.com/EngineerBetter/control-tower
[concourse-ci]: https://concourse-ci.org/
[desc-check-recycle-period]: https://bosh.io/jobs/web?source=github.com/concourse/concourse-bosh-release&version=6.6.0#p%3dgc.check_recycle_period
