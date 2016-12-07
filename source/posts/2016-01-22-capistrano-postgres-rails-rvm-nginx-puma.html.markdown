---
title: Capistrano, Postgres, Rails, Nginx & Puma on DigitalOcean
date: 2016-01-22
tags: capistrano, rails, devops
disqus_identifier: 2016/capistrano-postgres-rails-nginx-puma-digitalocean
disqus_title: Capistrano, Postgres, Rails, Nginx, Puma on DigitalOcean
---

Recently, I've been working on my squash club, [UCSC's new site](http://www.ucsc.sg). And of course, being slightly short of time, I kinda just fell back on Rails to quickly get something up for the club.

Before Heroku decided to put a 7 USD price on their free tier, it was an easy default for hosting any mini prototypes or projects. Ok I admit, I've historically used Pingdom to avoid having the free instances spin down after 30 mins :P. 

### Overview of Setup

I went with a fresh Ubuntu 14.04 DigitalOcean droplet to see how long it takes for me to setup a fresh server for Rails deployment. tl;dr Its actually doesn't take long at all :P

The stack I chose was nothing out of the ordinary:
- RVM for ruby (just more used to RVM, no intention to start a war on rbenv vs rvm :P)
- Rails for application code
- Postgres for the database
- Capistrano for deployment (there really isn't other better option imo)
- Nginx for the reverse proxy (again)
- Puma for the webserver

I've kinda just compiled the steps these posts mainly:

- [Initial Server Setup](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-14-04),
- [PostgreSQL](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-postgresql-on-ubuntu-14-04)
- [Nginx, Puma, RVM](https://www.digitalocean.com/community/tutorials/deploying-a-rails-app-on-ubuntu-14-04-with-capistrano-nginx-and-puma)
- [Nameserver setup)] (https://www.digitalocean.com/community/tutorials/how-to-set-up-a-host-name-with-digitalocean)

### Devise 3, Capistrano & Env Vars

I must admit I was stuck here for a good bit haha.

So, since Devise 3, a secret key has been required on production defined in the Devise initializer:

```config.secret_key = ENV["SECRET_KEY_BASE"] if Rails.env.production?```

There are notably 2 ways to get this working:

- Symlink configs/secrets.yml with an actual key on capistrano deploy
- Use "environment variables" (I assumed so after seeing ENV)

Most of the people I see fix this by using [rbenv-var](https://github.com/rbenv/rbenv-vars) to manage environment variables for ruby projects but since I'm using rvm, I don't exactly have that option.

So I ssh'd into the server and did this ```export $SECRET_KEY_BASE=...``` and fully expected it to work after seeing the same value with ```ruby -e "p ENV['SECRET_KEY_BASE']"```

Except it didn't.

### The Problem?

After a little digging around, I found out that when you are using Capistrano to deploy, apparently it uses SHELL variables that exist in the lifetime of the deployment (well technically its just SSH) instead of the actual environment variables.

So the correct place to put the export was in ```~/.bashrc```!

```
export SECRET_KEY_BASE="xxx"
```

The deployment with capistrano was relatively straightforward otherwise.

Below, I've compiled the commands I'ved used (most of them) for the entire process.

### Adding Deploy User

```
adduser deploy
gpasswd -a deploy sudo
```

Copy public key up to server

```
ssh-copy-id deploy@server_ip_address
```

### Install Postgres

```
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo -i -u postgres
createuser --interactive
```

### Install Nginx
```
sudo apt-get install curl git-core nginx -y
```

### Install RVM & Ruby

```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm requirements
rvm install 2.2.1
rvm use 2.2.1 --default
gem install rails -V --no-ri --no-rdoc
gem install bundler -V --no-ri --no-rdoc
gem install pg
```

### Setting up SSH (Github)

```ssh -T git@github.com``` on the server then add the server's public key into your github account.


### Gemfile

```
group :development do
    gem 'capistrano',         require: false
    gem 'capistrano-rvm',     require: false
    gem 'capistrano-rails',   require: false
    gem 'capistrano-bundler', require: false
    gem 'capistrano3-puma',   require: false
end

gem 'puma'
```

### Deploy.rb

```ruby
set :application, 'ucsc'
set :repo_url, 'git@github.com:aranair/ucsc.git'
set :user,            'deploy'
set :puma_threads,    [4, 16]
set :puma_workers,    1

# Don't change these unless you know what you're doing
set :pty,             true
set :use_sudo,        false
set :stage,           :production
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true  # Change to false when not using ActiveRecord

## Defaults:
set :scm,           :git
set :branch,        :master
set :format,        :pretty
set :log_level,     :debug
set :keep_releases, 5

## Linked Files & Directories (Default None):
set :linked_files, %w{config/database.yml}
set :linked_dirs,  %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
        puts "WARNING: HEAD is not the same as origin/master"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end

  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
    end
  end

  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
end

```

### Capfile

```ruby
require 'capistrano/setup'
require 'capistrano/deploy'

require 'capistrano/rails'
require 'capistrano/bundler'
require 'capistrano/rvm'
require 'capistrano/puma'


Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }

```

### Nginx 

config/nginx.conf

```
upstream puma {
  server unix:///home/deploy/apps/ucsc/shared/tmp/sockets/appname-puma.sock;
}

server {
  listen 80 default_server deferred;
  # server_name *.ucsc.sg;

  root /home/deploy/apps/ucsc/current/public;
  access_log /home/deploy/apps/ucsc/current/log/nginx.access.log;
  error_log /home/deploy/apps/ucsc/current/log/nginx.error.log info;

  location ^~ /assets/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  try_files $uri $uri @puma;
  location @puma {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;

    proxy_pass http://puma;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 10M;
  keepalive_timeout 10;
}
```

After Capistrano deploy via ```ap production deploy: initial```

```
sudo rm /etc/nginx/sites-enabled/default
sudo ln -nfs "/home/deploy/apps/ucsc/current/config/nginx.conf" "/etc/nginx/sites-enabled/ucsc"
sudo service nginx restart
```


### Conclusion

Setting it up wasn't too hard, but it does seem a little tedious and it is really easy to forget something along the way. No wonder people are turning to ansible/chef for multi-server setups. For individual web developers though, perhaps a bash script is enough.

Maybe in another post I'll have a go at using Ansible or a bash script to automatically set the servers up.

Future posts:

- Ansible / Bash script to set up
- Docker


