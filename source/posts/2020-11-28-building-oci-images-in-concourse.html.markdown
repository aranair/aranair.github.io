---
title: 'Concourse CI - Lessons'
description: 'Part one of series that talks about Concourse CI. This post is more about some of the lessons or things that helped me stabilize the clsuter'
date: 2020-11-28
tags: Concourse, CI/CD, devops
disqus_identifier: 2020/concourse-ci-one
disqus_title: Concourse CI
---

I run a mid-sized [Concourse CI][concourse-ci] cluster for Tulip, that runs ~3000 fairly resource-intensive builds weekly.
I've encountered a fair share of stability issues with it, some from lack of experience, some from real issues,
but overall, my experience with it has been fairly positive. I can't speak about
Github Actions, or TravisCI and CircleCI but my experience has been vastly better than that with Jenkins (another popular CI/CD tool).
It is open-source and is continuously improving with fairly frequent releases with good core contributing members. It helps with not getting
locked down by a specific platform such as Github Actions. I'm actually surprised not more people are onboard this,
which is one of the reasons that prompted me to write this series.

Over the next couple posts or so, I'll be talking about some random topics related to Concourse. They might help with your decision to onboard
(or skip) Concourse. This first one might read like a rant on the issues of Concourse, but it really isn't :P

To clarify, they're more like lessons I've learned about Concourse and how some tweaks might help with smoothing the running of a cluster.

### Infrastructure

We use [EngineerBetter/ControlTower][control-tower], also formerly known as ConcourseUp for the initial setup.
The initial setup is fairly effortless (generally speaking, without deviation).
On top of that, we do most of the custom configuration for Concourse via [Bosh][bosh].
Bosh is also incharge of provisioning the different components such as the prometheus, atc, web, worker nodes.
It is also essentially self-healing because of bosh cloud-checks as well; any termination or deletion will automatically be replaced.

### Resources

I'll be talking about resources in the next few sections, so here's a quick primer.

They're like versioned artifacts with external resources. To interface with the external source of truth, there are "plugins" that are called `resource_types`.
There are [a bunch of community built resource types][resource-types] and they're an important contributor of Concourse's flexibility imo.

For example:

- the [git-resource][git-resource] tracks commits in a Git repo
- [registry-image][registry-image] would manage images for docker registries.

### Triggering builds for Pull Requests

This is a really common usecase of CI/CD. Everytime a pull request is updated with a new commit in Github, a build is triggered to
do a range of tasks, from simple go lints, unit tests, to building artifacts to full-scale integration tests. This flow is achieved through webhooks
events from Github.

The receiver of those webhook events is a [github-pr-resource][github-pr-resource] `resource_type` (or similar forks like
[digitalocean's][digitalocean-github-pr-resource]).

You might imagine that a pipeline can be triggered immediately after it interprets the webhook event. It's worth clarifying
that this concept of triggering a pipeline is incorrect; that's not how it works in Concourse. Pipelines are basically just set of jobs
and they are all independently scheduled. New builds are created by the scheduler when it detects that a job's dependent (e.g. trigger: true)
resources have changed.

So, what really happens after it processes a webhook event?

The `pr-resource` queues a `check` that reaches out to Github to query for open pull-requests updates
through their GraphQL API (filtering from the latest update in a previous pull). From there, it updates the lists of versions
for the resource and rely on the scheduler to do the rest as mentioned above^.

To be honest, this flow isn't one of the strong points of Concourse. It is somewhat awkward - leading to the perception that it is slower to
trigger than other popular builds, among other concerns, such as rate-limiting (if you have too many open pull-requests at one time).

For me though, I'll say that this setup has worked acceptably well.

And, this has been acknowledged as such by the core members and listed as a primary focus in the [v10 roadmap][v10-roadmap], which I'm pretty excited about!

### `default_check_interval` / `check_recycle_period` / Github Ratelimiting <a id="intervals" href="#intervals"></a>

Default (Bosh) setting for the [web node][web-node]'s `default_check_interval` is 1 minute. This means that for every resource you define, you'll be running a check,
hitting whatever api that might be required. For example, for a [git-resource][git-resource] that hits Github, each call counts towards the rate-limit that Github sets.
It's fairly high at 5000 per hour, but it is still exhaustible if you're not careful!

Relatedly, there is another setting in Bosh, for the web/scheduler node, `check_recycle_period` - which decides
how often the containers for resource checks are garbage-collected. The default is 6 hours.

Don't make the mistake (like me!) of drastically reducing this GC interval even if there might be containers used for checks lying around, doing nothing.
It depends on the implementation of the particular concourse resource but in my case, the [git-resource][git-resource] would init and re-query
(history) of versions and end up consuming unnecessary calls to Github, which led to us getting rate-limited occasionally.

YMMV, but if you're using this resource, consider leaving it at a higher enough interval to take advantage of the caching!

### Container Placement Strategy

We have resource-intensive jobs (across different pipelines) that can be triggered at the same time. When that happens, our cluster occasionally run into
resoure deprivation issues.

I've tried the experimental feature `limit-active-tasks` - a `container_placement_strategy` that limits the number of tasks per worker. In my opinion,
that does not work well for clusters with varying types of workloads. It would inevitably end up blocking tasks that may not be resource-intensive.
An example is the periodic resource check, or worse, at times, it might only allow light tasks through and blocking tasks that could still fit well.

You can also do `volume-locality`, `random` and `fewest-build-containers` placements. We've ultimately gone with `fewest-build-containers` because
we have CPU-intensive tasks but for most usecases, but I think every workload / situation is probably different and this is one of those settings
to consider tweaking when setting Concourse up.

Sidenote: I believe this is also on the v10 improvement list!

### Resource Allocation

This is obviously deeply related to the section above. If you run smaller nodes and can't have multiple (heavy) jobs run at the same time, you do have
a number of knobs to help you restrict these.

You can control the number of builds per job that happens at the same time, with `max_in_flight` (or `serial: true` for 1) at the job definition level.
If you would like all jobs that belong some specific category to run serially, you can group all of these jobs up and run them different groups serially.

```yaml
jobs:
- name: job-a
  serial_groups: [some-tag]
- name: job-b
  serial_groups: [some-tag, some-other-tag]
- name: job-c
  serial_groups: [some-other-tag]
```

Also, it's probably prudent to also define a default cpu/memory allocation with this [Bosh settings][bosh-resource] and then override each task with `container_limits`,
to avoid any rogue jobs just spinning out of control. Anecdotally, I had jobs that pegged and took down 4xlarge nodes; to be fair they were erlang/beam jobs that
are notorious for the amount of resources they demand.

```yaml
# Bosh -> web node defaults
# This is the equivalent of
default_task_cpu_limit: 256
default_task_memory_limit: 4GB
```

```yaml
# Override at the Job level
container_limits:
  cpu: 256
  memory: 1GB
```

Do note that the CPU defined here is not the number of cores but the CPU shares. I believe the Concourse / system stuff running on each node runs
with a default of `512` so using `256` would slightly lower the priority of user-level jobs so important system processes don't get starved.

### (Storage) Volumes / Baggage Claims

I've discovered that, when the volumes choke up (IOPS or otherwise), Concourse baggage-claims (gc of volumes and such) seem to fail rather silently,
and you start having containers failing to schedule within the time limit.

I only really realized this when we went from many small(xlarge) EC2 nodes to fewer 4xlarge nodes and had our EBS volumes' IOPS constantly get
pegged by certain IO intensive jobs. It was extremely surprising how much IOPS we needed (thanks, yarn). Many of our performance issues went away with this fixed.

I encourage people who are facing issues, just double-check this in their cluster as well.

### Overlay vs btrfs

Concourse ships with btrfs by default. There are obviously things that btrfs does that overlay doesn't but it has stability issues. The problem set and
trade-offs are clearly talked about in [this github issue][btrfs-issue] so I won't rehash them.

One thing I'll say though, I encourage people to switch over to overlay for most usecases.

### Next

Again, this might have read like a rant on the problems, but it really is more like the things that I've learned over running our cluster. To be honest,
alot of these are surrounding issues that are not Concourse specific per-se. And it is extremely positive in my opinion that the core team acknowledges
some of the real issues (that really still work reasonably well) and put real work towards them for v10.

In the next few posts, I'll go over in more technical details how you might do certain things, like

- building from PR, or
- building docker OCI images in Concourse, or
- running docker-in-docker in overlay
- running a registry-mirror and using it in Concourse

[web-node]: https://concourse-ci.org/concourse-web.html
[bosh]: https://bosh.io/docs/
[bosh-resource]: https://bosh.io/jobs/web?source=github.com/concourse/concourse-bosh-release&version=6.6.0#p%3ddefault_task_cpu_limit
[github-pr-resource]: https://github.com/telia-oss/github-pr-resource
[registry-image]: https://github.com/concourse/registry-image-resource
[git-resource]: https://github.com/concourse/git-resource
[digitalocean-github-pr-resource]: https://github.com/digitalocean/github-pr-resource
[v10-roadmap]: https://blog.concourse-ci.org/core-roadmap-towards-v10/
[control-tower]: https://github.com/EngineerBetter/control-tower
[concourse-ci]: https://concourse-ci.org/
[resource-types]: https://resource-types.concourse-ci.org/
[desc-check-recycle-period]: https://bosh.io/jobs/web?source=github.com/concourse/concourse-bosh-release&version=6.6.0#p%3dgc.check_recycle_period
[btrfs-issue]: https://github.com/concourse/concourse/issues/1045
