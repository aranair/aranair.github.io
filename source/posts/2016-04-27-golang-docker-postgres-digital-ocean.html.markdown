---
title: Dockerized Golang + Postgres on Digital Ocean
date: 2016-04-27
tags: golang, docker, devops
---

My previous deploy on the Rails stack was a little more involved so I chose to just deploy it in the conventional capistrano way after setting the server up.

But with the rise in popularity of Docker recently, I've been wanting to deploy something into production with Docker but never found the right app for it until this one.

It was a simple Golang scraper + Api that is backed by PostgreSQL.

### Overview

I went with a fresh Ubuntu 14.04 DigitalOcean droplet (yes again). Some boilerplate setup for a digital ocean instance is recorded here in a [previous post](https://aranair.github.io/posts/2016/01/22/capistrano-postgres-rails-rvm-nginx-puma):

The basic idea was to have 2 Dockerized components to this deployment. The first Docker container would be running the Golang app. The second one is to run Postgres via linked data.

### Dockerize the Postgres

I chose to go with a base installation of Postgres and configure it from there, but YMMV.

This runs the postgres service under `db` name and as a daemon.

```
docker run --name db -e POSTGRES_PASSWORD=YOUR_PASSWORD -d postgres
```

To setup a dedicated user for the app and create the database, I opened the bash shell into the container via: 

```
docker exec -it db /bin/bash
```

From there, a new user was created and granted privileges via psql CLI.

```
psql -U postgres
```

```
CREATE USER app;
CREATE DATABASE appdb;
GRANT ALL PRIVILEGES ON DATABASE appdb TO app;
```

If you try to connect the app at this point, it will fail because it does not listen to addresses outside of 127.0.0.1 and doesn't allow client authentication in connections yet. 

In order for it to work, there were two files which I had to modify:

- `hba_file` - To enable client authentication
- `postgresql.conf` - To enable listening of addresses other than localhost

To find the location of the `hba_file` simply run `show hba_file;` in the psql interactive shell. 

The default one should lie at this location: 

```
/var/lib/postgresql/data/pg_hba.conf
```

Installed my favourite text editor via:

```
apt-get update && apt-get install vim
```

Changed from this:

```
host  all  all  127.0.0.1/32  md5
```

To this, so that it allows connections that are from the same machine:

```
host all  all  192.168.1.0/24  md5
```

For `/etc/postgresql/9.3/main/postgresql.conf`:  Changing `#listen_addresses = 'localhost'` to `listen_addresses = '*'` would enable it to listen for incoming connection requests from all available IP addresses.

A restart of the postgres service was also required.

```
sudo service postgresql stop
sudo service postgresql start
```

### Docker Volumes

The best practice for all dockerized database components is for it to have an external data volume so that you can always restart the container without losing the data. 
In my deployment, you'll notice that I do not specifically set this up and that is because the [Postgres Dockerfile]("https://github.com/docker-library/postgres/blob/8e867c8ba0fc8fd347e43ae53ddeba8e67242a53/9.3/Dockerfile") already does this by default!

```
ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data
```

You can find out more about it in the [official documentation](https://docs.docker.com/engine/userguide/containers/dockervolumes/) if you're interested.


### Dockerize the Golang App

This is the simple Dockerfile that I've used for my Golang App.

```
FROM golang:onbuild

RUN go get bitbucket.org/liamstask/goose/cmd/goose

RUN ["apt-get", "update"]
RUN ["apt-get", "install", "-y", "vim"]

ADD config.toml /go/bin/
ADD dbconf.yml /go/src/app/db/

EXPOSE 5000
```

A quick run through of each line:

- The first line runs the 'onbuild' variant of the golang image that automatically copies the source, build and run it. 
- The second line installs 'goose', which is the tool I use to get (somewhat) Rails-like database migrations.
- Next two lines just installs Vim, and are just nice to haves when I ssh into the Docker instance to check the config files out.
- Then copy some app config files into the docker image.
- Last line simply exposes port 5000 of the container to the outside world. 

```
docker built -t app
docker run -d -p 80:5000 --name gosnap --link db:postgres app
```

- `-d` tells it to run it as a daemon,
- `-p 80:5000` tells it to link the host container's port 80 to port 5000 of the docker container
- `--link db:postgres` links our app to the postgres container that we've created earlier

Via the link to the postgres container, you automatically get this environment variable `$POSTGRES_PORT_5432_TCP_ADDR` in the app. This contains

If like me, you use goose, your dbconf.yml will should look something like this at the end.

```
db:
   driver: postgres
   open: host=$POSTGRES_PORT_5432_TCP_ADDR user=app dbname=appdb sslmode=disable
```

I then ran the migrations at this point:

```
docker exec -it gosnap goose up
```
