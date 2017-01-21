---
title: 'How I Deployed My Golang Telegram Bot'
description: 'In this post, I go through the steps I took to dockerize and deploy my golang Telegram bot.
I walk through the entire process with code samples, from the self-served certificate / api setup
using of the Nginx as reverse proxy to the final deployment via git webhooks scripts.'
date: 2017-01-21 
tags: golang, telegram, bot, webhooks, ssl, nginx, digital-ocean
disqus_identifier: 2017/deploy-golang-telegram-bot
disqus_title: How I Deployed My Golang Telegram Bot
---

Continuing where I left off in the [first part][1] of my `Golang Telegram Bot`, in this post I go through all the
steps I took to get to a one command deployment of my Telegram bot into a Digital Ocean Ubuntu 16.04
instance. A number of components were involved: dockerizing the app, setting up a self-signed SSL cert,
get the Nginx to work as a reverse proxy with that, submitting the SSL to Telegram, and finally setting up
git post-update webhooks for deployment.

### Dockerizing the App

To prepare the bot for deployment, a natural choice was to dockerize it. I've found it simpler, by far, to use docker 
to get the environment needed for my apps to run instead of manually fiddling with the server in most cases. It
also gives me the benefit of being able to run multiple containers on a single instance if the load
isn't too high on them. Let's dive in to the code.

##### Dockerfile

```yaml
FROM golang:1.6

ADD configs.toml /go/bin/

ADD . /go/src/github.com/aranair/remindbot
WORKDIR /go/src/github.com/aranair/remindbot

RUN go get ./...
RUN go install ./...

WORKDIR /go/bin/
ENTRYPOINT remindbot

EXPOSE 8080
```

I start from the base [Golang 1.6 image][2]. 

From there, the next line adds a `configs.toml` into the bin folder.
This file contains credentials and configs that my app needs to run. This should be added into the server
manually, so that it doesn't get checked into the github repository for security reasons. 

I took a look at the [official Golang Dockerfile][2] and I saw that the default `gopath` is `/go`.
By adding my config item into `/go/bin` folder, I can easily give the app direct access to the file,
without having to provide it an additional arbiturary path to get that file.

The next line adds the files into the image during the build process.
Previously, I would get the files in a different way. I would use this:

```dockerfile
go get /go/src/github.com/aranair/remindbot
```

But it's actually a little easier to do it in the above way:

```dockerfile
ADD . /go/src/github.com/aranair/remindbot
```

This would take all the files at `.`, the location where `docker build` 
would run from, and copy them  into `/go/src/github.com/aranair/remindbot` during the build process, 
essentially achieving the same result as `go get ...`. 

What's different here is that I don't -have- to remember to push to github before the deployment. 
I also wouldn't need to manually `git pull`. The entire deployment process can be contained 
inside the post-update webhook. I'll discuss that in more detail further down.

### Docker Compose

Personally, I hate fiddling with manual running of the containers so I just use docker-compose, 
especially if there is more than one component to worry about. For this bot, there is really only
the mounted volume so that my sqlite3 files won't get flushed on a deployment but I could 
just as easily set-up a PostgreSQL database up with a few simple additions to this file.

```yaml
version: '2'
services:
  gobot:
    build: .
    ports:
      - "8080:8080"
    volumes:
      - /var/data:/var/data
```

The section under ports exposes and links the container's port 8080 to the server's port 8080 (`HOST::CONTAINER` format). 
More about that can be found in the [compose-file documentations][3].

For the volumes, the code above simply tells the container to link the host's `/var/data/` to the container's `/var/data/`
essentially creating a mounted volume. Again, the format is `HOST::CONTAINER`. I store the files there for my 
`Sqlite` database and this mounted volume preserves the data on deployments.

### How to Set-up Self-Signed SSL Certificate

One of the main hassles and requirements of the Telegram API is that they require https, and that requires
an SSL certificate. It encrypts communication between Telegram and my server, and this helps Telegram to
verify that my server is the correct one, and not a bogus one when a potential man-in-the-middle hijacks the 
traffic.

I could go get an SSL cert from a provider, but in this case, what we're really concerned is the
identity of my server to Telegram and not for users so a self-signed certificate would work just as well.

I SSH'd into the server to create the certs.

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/self-signed.key -out /etc/ssl/certs/self-signed.crt
```

- `-days` defines the validity span. I did adjust the validity-days to something much bigger but generally might be better with a year or two.
- `rsa:2048` means that will create an RSA key that is 2048 bits long.
- `-keyout` refers to the private key for the cert
- `-out` refers the cert itself

The process leads me through the steps above for some further information. The most important bit
is the **Common Name**. In my case, I didn't have a domain, so I simply put in the `server_IP_address` 
for my Digital Ocean instance.

```
Country Name (2 letter code) [AU]:SG
State or Province Name (full name) [Some-State]:Singapore
Locality Name (eg, city) []:Singapore
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:server_IP_address
Email Address []:boa.homan@gmail.com
```

As part of Nginx best practices, I also created a strong Diffie-Hellman group for added security.

```bash
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
```

### Configuring Nginx to Use the SSL Cert

I first made a new Nginx configuration snippet at `/etc/nginx/snippets` that simply points
to the SSL certs I just created above.

```conf
ssl_certificate /etc/ssl/certs/self-signed.crt;
ssl_certificate_key /etc/ssl/private/self-signed.key;
```

Another snippet to set-up some SSL settings based on recommendations from [https://cipherli.st/][4].

```conf
# from https://cipherli.st/
# and https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html

ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
ssl_ecdh_curve secp384r1;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the "preload" directive if you understand the implications.
#add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;

ssl_dhparam /etc/ssl/certs/dhparam.pem
```

Finally, we will need to edit the Nginx configuration files to use SSL.

This is what the file intially looks like: 

```conf
# /etc/nginx/sites-available/default

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    # SSL configuration

    # listen 443 ssl default_server;
    # listen [::]:443 ssl default_server;

    ...
```

I changed it to look like this (remember to replace IP!)

```conf
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name YOUR_SERVER_IP_ADDRESS;
  return 301 https://$server_name$request_uri;
}

server {
# SSL configuration

  listen 443 ssl http2 default_server;
  listen [::]:443 ssl http2 default_server;

  include snippets/self-signed.conf;
  include snippets/ssl-params.conf;

  location / {
    proxy_pass http://127.0.0.1:8080;
  }
}
```

What I did was to basically ask Nginx to automatically redirect HTTP requests to HTTPS. And ask it to
server root from the port 8080 that the docker container is listening to.

### UFW Firewall

For security reasons, I also enabled [ufw firewall][5] by doing the following: 

```bash
sudo ufw enable
sudo ufw allow 'OpenSSH'
sudo ufw allow 'Nginx Full'
sudo ufw delete allow 'Nginx HTTP'
```

It should look something like this in `sudo ufw status`

```bash
To                         Action      From
--                         ------      ----
Nginx Full                 ALLOW       Anywhere
OpenSSH                    ALLOW       Anywhere
Nginx Full (v6)            ALLOW       Anywhere (v6)
OpenSSH (v6)               ALLOW       Anywhere (v6)
```

And its done; to start Nginx, all that's left is to `sudo nginx -t`

### Sending Telegram the SSL Cert

Telegram will need the other side of the cert. Consulting their documentation, it seems that they
need the PEM file. To get that, I had to convert the current CRT file into the PEM format.

```bash
openssl x509 -in /etc/ssl/certs/self-signed.crt -outform pem -out /etc/ssl/certs/bot.pem
```

To get the cert to Telegram's hands, I sent it via their API using this: (Replace bot keys!)

```bash
curl -F "url=https://your.domain.or.ip.com" -F "certificate=@/etc/ssl/certs/bot.pem" https://api.telegram.org/bot12345:ABC-DEF1234ghIkl-zyx57W2v1u123ew11/setWebhook
```

### Set-up Git Hooks

Great! Now all that's left is the deployment process. The general outcome that I wanted is that
it'll be a one-command process that updates the code in the server, rebuilds and restarts the docker
container with the updated app.

At my server, I created the necessary files for the server git repository

```bash
cd /var
mkdir repo && cd repo
mkdir bot.git && cd bot.git
git init --bare
```

#### The Hooks

Looking into the `hooks` folder in bot.git, there were many samples for the different hooks provided.
For the purpose of this bot, I created a `post-receive` hook with the following content.

```bash
#!/bin/sh
git --work-tree=/var/app/remindbot --git-dir=/var/repo/bot.git checkout -f
cd /var/app/remindbot
docker-compose build
docker-compose down
docker-compose up -d
```

The sets the `/var/app` folder to be the working directory for my app. And the script goes into
my working directory and rebuilds the container and restarts it. All of this will happen on deployment!

Of course, I also had to make the post-receive file executable.

```bash
chmod +x post-receive
```

### Deploy All The Things!

From my development machine, I added a remote repo to my local git repo.

```bash
git remote add prod ssh://user@my.domain.or.ip.com/var/repo/bot.git
git push prod master
```

And the Telegram bot finally goes live, responding to live chats in Telegram. All of this code can be found 
at the [project github repository][6]. The reminder bot's name is Hazel. She responds instantly to 
chats in Telegram and helps me to manage my ever-growing list of responsibilities everyday now :P

Feel free to star it or fork it or leave comments below!

[1]: https://aranair.github.io/posts/2016/12/25/how-to-set-up-golang-telegram-bot-with-webhooks/
[2]: https://github.com/docker-library/golang/blob/master/1.6/Dockerfile
[3]: https://docs.docker.com/compose/compose-file/#/ports
[4]: https://cipherli.st/
[5]: https://help.ubuntu.com/community/UFW
[6]: https://github.com/aranair/remindbot
