---
title: Deploying Meteor 0.8.0 (Meteorite) to Heroku
date: 2014-04-19 00:00 SGT
tags: meteorjs, meteorite, heroku
---
It was...surprisingly easy, no honestly, much easier than I thought.

### Steps: 

- Create new Heroku application: ```heroku create <appname> --stack cedar --buildpack https://github.com/oortcloud/heroku-buildpack-meteorite```
- Setup other than MongoDB for your Meteor application (I just added MongoHQ via `heroku addons:add mongoHQ`
- `heroku config:set ROOT_URL=http://<appname>.herokuapp.com`
- set up git with this heroku app (git init and blah blah)
- `git push heroku master`
- profit?!

