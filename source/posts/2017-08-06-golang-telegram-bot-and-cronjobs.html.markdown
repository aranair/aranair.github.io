---
title: 'Golang Telegram Bot & Cronjobs'
description: 'In this post, I talk about how I added timed executions or cronjobs to my telegram bot. 
I also run through some of the code organizational changes I made to the previous versions.'
date: 2017-08-06
tags: golang, telegram, bot
disqus_identifier: 2017/golang-telegram-bot-cron
disqus_title: Golang Telegram Bot & Cronjobs
---

This post is sort of a continuation from the previous posts of my Golang Telegram Bot, so if you
haven't read those, it might be a good idea to head over to [part 1][1] and [part 2][2] first. I
basically wanted my telegram bot to be able to remember dated / timed reminders and send messages to
notify me when that time comes (like a calendar). Furthermore, just to force me to complete the tasks
quickly, I also make it repeat the notifications until its cleared.

### Code Organization

Something that has eluded me so far, is the code organization of internally used packages in Golang.
I find it hard to decide where they should belong; it almost feels like a naming- kind of problem to me
and I wish there was a little more convention regarding this, or a generally more widely-accepted
way of code organization.

So when I first realised I will need to have a webapp & the timer-app (for checking the time and 
sending the reminders etc) running at the same time, a couple of questions came across my mind:

- Are these 2 related? (For which the answer is evidently yes)
- Where should the `main.go` for the webapp and the timer-app be?
- How do I organise the shared packages and shared configurations?
- How do I structure it such that my Dockerfile and docker-compose configs don't require massive changes?

### CMD Folder

I came across this [stackoverflow post][so post] that talked about the `cmd` folder, which made a 
ton of sense and seems to be quite a widely-accepted convention so far.

### Next Iterations

- I kinda want to be able to use "today" / "tomorrow" / "next week" instead of having to put in a date
manually; this probably just means better datetime parsing.
- Ideally, I also want a snooze function, where you can postpone the notifications by X number of hours.

[![Demo](https://raw.githubusercontent.com/aranair/rtscli/master/rtscli-demo.png)](https://raw.githubusercontent.com/aranair/rtscli/master/rtscli-demo.png)

### Timer

