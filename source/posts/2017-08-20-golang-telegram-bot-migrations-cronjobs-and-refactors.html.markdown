---
title: 'Golang Telegram Bot - Migrations, Cronjobs & Refactors'
description: 'In this post, I talk about how I added timed executions or cronjobs to my telegram bot.
I also run through some of the code organizational changes I made to the previous versions.'
date: 2017-08-20
tags: golang, telegram, bot
disqus_identifier: 2017/golang-telegram-bot-migrations-crons-refactors
disqus_title: Golang Telegram Bot Migrations, Cronjobs & Refactors
---

This post is kind of like a continuation from the previous posts of my Golang Telegram Bot, so if you
haven't seen that yet, it's probably better to start with those first: [part 1][1] and [part 2][2]. I
basically wanted my telegram bot to be able to remember dated / timed reminders and send messages to
notify me when that time comes (like a calendar). Furthermore, just to force me to complete the tasks
quickly, I also make it repeat the notifications until its cleared.

### Code Organization

Something that I've never really gotten right in Golang, is code organization.
I find it hard to decide where each piece belongs; it almost feels like a naming- kind of problem to me
and I wish there was a little more convention around this, or a generally accepted framework to think about how
to arrange things.

When I realised I needed the web-app (for responding to messages/commands) and the timer-app (for
periodically checking the time and sending overdue reminders etc) to run at the same time,
a couple of questions came up:

- Are these 2 related? (For which the answer is yes - configs, db, handlers)
- Should these two be separate git repos? (No, because of the previous question)
- Can they be run with just one 'app'? (No, reasons in another section)
- They are logically separate 'apps', so where should each `main.go` be at?
- How do I organise the shared packages and shared configurations?
- How do I structure it such that my Dockerfile and docker-compose configs don't require massive
changes? Or even better, can they be shared? (Yes)

While researching, I came across this [blog post][blog post] that talks about code organization in
Golang in general and thinking about the application from the perspective of a library, which
all made a ton of sense to me. Head over there to check it out if you're in the same situation as
me.

### CMD Folder

Anyway, so one of the things that was recommended, is to use a `cmd` folder to contain
the main running packages (those that actually need a `main.go`), thereby removing the main.go
from the root folder. It also satisfies my other criteria of not needing to change my docker
setup drastically, so that's all good.

Shared packages are left untouched under the root folder so that logically they're like libraries
and exist in some sort of a common area and they can also be easily imported in the timer/webapp packages.

The general structure comes up to something like this:

```
remindbot/
  cmd/
    timer/
      main.go
      ...
    webapp/
      main.go
      ...
  config/
  commands/
  handlers/
  migrations/
```

### Cron / Scheduled Task

I needed a cron that would run perpetually and schedules a task every 5 minutes.

I feel that this cron job and my webapp should be in somewhat separated. While they are somewhat
related in terms of configs, commands and databases,I felt that they have two rather different
responsibilities.

I could use a single app, with background tasks or threads running the cron that does exactly
what the timer app does but I've done them in a way that they run in separate containers,
almost like microservices. I feel that that is a better way of representing the clear distinction
of their responsibilities.

I use [gocron][gocron] to run a function in a shared package every 5 minutes but if you look at the
code inside, you probably can do without the package if you're afraid of adding dependencies.

### Migrations

I needed to make changes to the database schema; I think there isn't a defacto package for handling
that out there? There are a couple of them out there like goose for example.

I ended up using [rubenv/sql-migrate][sql-migrate] though; goose was slightly finicky for me, YMMV.
They're also run manually for now since I don't forsee that many migrations to happen but if they start to
become more frequent, I would definitely move them out into a separate docker container that runs
briefly on every deploy.

### Docker Setup

There were minimal changes to my Dockerfile and docker-compose config files.

For the `docker-compose.yml`, I've added a `base` key that builds the Dockerfile in the root
folder. And then each of the other 2 services would just define a different entrypoint. I could
also have two separate Dockerfiles but at this point I think they're still similar enough to just
have one Dockerfile.

```yml
version: '2'
services:
  base:
    build: .
  hazel:
    extends: base
    ports:
      - "8080:8080"
    expose:
      - "8080"
    volumes:
      - /var/data:/var/data
    entrypoint:
      - webapp
  timer:
    extends: base
    volumes:
      - /var/data:/var/data
    entrypoint:
      - timer
```

I've also setup [Godep][godep] to deal with external package version control. It does a simple job -
save the external packages into the vendor folder so that they can be restored easily the next time.

That way, the Dockerfile would have just one package to grab and restore all the package locally,
instead of getting all of them via `go get`. Other than that, the Dockerfile basically remains
unchanged other than the Godep stuff and moving the entrypoint from before into the docker-compose
instead.

```
FROM golang:1.6

ADD configs.toml /go/bin/
ADD . /go/src/github.com/aranair/remindbot
WORKDIR /go/src/github.com/aranair/remindbot

RUN go get github.com/tools/godep
RUN godep restore
RUN go install ./...

WORKDIR /go/src/github.com/aranair/remindbot
WORKDIR /go/bin/
```

### Next Iterations

- I want to be able to use "today" / "tomorrow" / "next week" instead of having to put in a date
manually; this probably just means better datetime parsing.
- Ideally, I also want a snooze function, where you can postpone the notifications by X number of
hours.

[1]: https://aranair.github.io/posts/2016/12/25/how-to-set-up-golang-telegram-bot-with-webhooks/
[2]: https://aranair.github.io/posts/2017/01/21/how-i-deployed-golang-bot-on-digital-ocean/
[blog post]: https://medium.com/@benbjohnson/structuring-applications-in-go-3b04be4ff091
[godep]: https://github.com/tools/godep
[gocron]: https://github.com/jasonlvhit/gocron
[sql-migrate]: https://github.com/rubenv/sql-migrate
