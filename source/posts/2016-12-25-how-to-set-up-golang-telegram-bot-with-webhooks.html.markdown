---
title: 'How I Built a Golang Telegram Bot Part 1: Application Code'
description: 'In this post, I go through all the steps I took to build a golang telegram bot. 
It would include code to show how to dockerize the app and what to take note of when you are building 
a telegram bot to use webhooks with.'
date: 2016-12-25
tags: golang, telegram, bot, webhooks
disqus_identifier: 2016/build-golang-telegram-bot-webhooks
disqus_title: How to Build a Golang Telegram Bot with Webhooks
---

This is the first part of the `Golang Telegram Bot` series. 
In this series, I'll show you, with code samples, how I built a Golang Telegram Bot for my own use. 
It would listen in and respond in real-time to certain text cues. 
Finally I'll also demonstrate how to get a self-signed SSL cert working with Nginx
and deploying the application in a Docker container on a Digital Ocean instance.

Hopefully this will help anyone out there who would like to try their hand at their own bot on Telegram!
The code for this bot is currently hosted at [https://github.com/aranair/remindbot][2] if you'll like
to just skip to the code immediately.

### Backstory

I've been using [Telegram][1] for a really long time, and been wanting to build a Telegram bot 
for a long time since they first announced it. 
  
Initially, I was thrown off a little by the requirement of https for the webhooks, 
thinking that I might need a domain and a SSL cert to get it working but I quickly found out that
a self-signed SSL certificate would work just as well in this scenario!

So, if you find yourself in the same situation, don't worry about it! It might be slightly more complex 
to set up a self-signed SSL cert with Nginx, but it's not that difficult! In this series, I'll show you the code
samples that got my own bot up and running in production!

### Creating a Bot and Getting an API Key

First, I sent `/newbot` to the [![botfather.png](https://s24.postimg.org/d0amvsmut/botfather.png)](https://telegram.me/botfather).

After creating the bot, I got a set of (botId and API key) by sending him a `/token` command.

The credentials are needed for subsequent requests to execute methods using the Telegram API. 

```yaml
# {botId}:{apiKey}
123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
```

**Take note** of the word `bot` before the `<token>`!

```yaml
https://api.telegram.org/bot<token>/METHOD_NAME
```

There are a ton of Api methods listed over at the [Telegram Bot docs][3] but for the purpose
of this simple starter bot, I will only be using [setWebhook][4] and [sendMessage][5].

### Webhook vs Polling

Great! I have the API key now. Next, I have to choose between the two ways to get messages from Telegram.

- Webhooks via `setWebhook` or
- Polling via `getUpdates`

I'm fairly certain that it is easier to set up with `getUpdates` but polling isn't always an option and not having
real-time updates isn't as fun IMHO :P So, for this bot, I went with webhooks as I wanted the bot to respond in real-time.

With webhooks, everytime there is a message (when privacy mode is disabled anyway), the API endpoint
will be sent a message. So the main objective, is simply, to parse each of these updates and respond appropriately.

To set up the Webhook all I had to do is to send a curl request to the Telegram Api.

```bash
curl -F "url=https://your.domain.com" -F "certificate=@/file/path/ssl/bot.pem" https://api.telegram.org/bot12345:ABC-DEF1234ghIkl-zyx57W2v1u123ew11/setWebhook
```

Of course, before that, I need the self-signed SSL **public** pem file; that is sent as an `InputFile` so that
Telegram can differentiate the correct server it's supposed to send all the messages to. This part is a bit more relevant
in the second part of the series where I deploy the bot to Digital Ocean so I'll leave this explanation to the second part.

### Router

I had a choice of many popular router implementations out there like [gin][gin] and [gorilla][gorilla].
But for this project, I chose to go a bit ligher with just `github.com/gorilla/context` and 
`github.com/julienschmidt/httprouter` since I don't really need that much functionality.

*Ok, to be fair, even the context (for the params) isn't really needed at this point, but
since I would need them for get requests in future, I've set it all up first.*

```go
package router

import (
	"net/http"

	"github.com/gorilla/context"
	"github.com/julienschmidt/httprouter"
)

type router struct {
	*httprouter.Router
}

func New() *router {
	return &router{httprouter.New()}
}

func (r *router) POST(path string, h http.Handler) {
	r.Handle("POST", path, wrapHandler(h))
}

func wrapHandler(h http.Handler) httprouter.Handle {
	return func(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
		context.Set(r, "params", ps)
		h.ServeHTTP(w, r)
	}
}
```

### Configs

To parse the config toml file, I used `github.com/BurntSushi/toml` with `toml` files. It's like `yml` on steroids lol.

The `datapath` is actually the data volume path for Docker; but I'll talk about that in more details in the second part 
of this series about deployments.

**Sample configs.toml**

```go
[bot]
  bot_id = "YOUR_BOT_ID"
  api_key = "YOUR_API_KEY"
[database]
  datapath = "PATH_TO_SQLITEE_FOLDER"
```

### App Context / Http Handlers Glue

Instead of a global object, I mixed app-wide objects like configs and the DB object into an `AppContext`.
To link the `AppContext` and the `http handlers` together, I used [github.com/justinas/alice][alice] as the glue.

**App Context**:

```go
type AppContext struct {
	db   *sql.DB
	conf config.Config
	cmds commands.Commands
}

func NewAppContext(db *sql.DB, conf config.Config, cmds commands.Commands) AppContext {
	return AppContext{db: db, conf: conf, cmds: cmds}
}
```

**Message Receiver**:

```go
func (ac *AppContext) CommandHandler(w http.ResponseWriter, r *http.Request) { ... }
```

**Main**

Since this bot was mainly built for personal reminders, I've chosen to go with `Sqlite3` for now but I've 
got it set up with `pq` before and it is fairly easy to swap it out, since both the libraries uses the `database/sql` 
library.

```go
_, err := toml.DecodeFile("configs.toml", &conf)
db, err := sql.Open("sqlite3", conf.DB.Datapath+"/reminders.db")
checkErr(err)

ac := handlers.NewAppContext(db, conf, commands.NewCommandList())

stack := alice.New()
r := router.New()
r.POST("/reminders", stack.ThenFunc(ac.CommandHandler))

http.ListenAndServe(":8080", r)
```

### Parsing the Updates

The updates that Telegram sends to the bot contains a lot of fields, including some optional ones 
that may or may not appear depending on the type of update, but the ones I'm concerned with for
this bot are only these:

```go
type Update struct {
	Id  int64   `json:"update_id"`
	Msg Message `json:"message"`
}

type Message struct {
	Id   int64  `json:"message_id"`
	Text string `json:"text"`
	Chat Chat   `json:"chat"`
	User User   `json:"from"` # Note: this is an optional field so it may be empty
}

type Chat struct {
	Id    int64  `json:"id"`
	Title string `json:"title"`
}

type User struct {
 	Id	      int64	 `json:"id"`
 	FirstName string `json:"first_name"`
 	Username  string `json:"username"` # Note: another optional field
}
```

Updates comes in as `JSON` and you can use the code snippet below with the structs above to decode it
into a more usable object.

```go
func (ac *AppContext) CommandHandler(w http.ResponseWriter, r *http.Request) {
	var update Update

	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(&update); err != nil {
		log.Println(err)
	} else {
		log.Println(update.Msg.Text)
	}

	cmd, txt := ac.cmds.Extract(update.Msg.Text)
	chatId := update.Msg.Chat.Id

	switch s.ToLower(cmd) {
      ...
	}
}
```

**Some key things to note here:**

- The message is parsed into `update.Msg.Text`
- The `chatId` is in `update.Msg.Chat.Id`. This is important because you'll need it to send a 
response back.
- The bot currently doesn't use `User` but I've written the code above so that you can get it as well.

### Command Extraction

There is a `Commands` object that contains all the `regexp.Regexp` items that are used to find matches 
for commands. These are instantiated once during bot startup but I admit this part is a lot more 
repetitive than needed and I am still looking for ways to clean this up.

So if you have any suggestions, do let me know in the comments below!

```go
package commands

import "regexp"

type Commands struct {
	rmt   *regexp.Regexp
	r     *regexp.Regexp
	l     *regexp.Regexp
	c     *regexp.Regexp
	cl    *regexp.Regexp
	hazel *regexp.Regexp
}

func NewCommandList() Commands {
	return Commands{
		rmt:   compileRegexp(`(?i)^(remind) me to (.+)`),
		r:     compileRegexp(`(?i)^(remind) (.+)`),
		l:     compileRegexp(`(?i)^(list)`),
		c:     compileRegexp(`(?i)^(clear) (\d+)`),
		cl:    compileRegexp(`(?i)^(clearall)`),
		hazel: compileRegexp(`(?i)(hazel)`),
	}
}

func compileRegexp(s string) *regexp.Regexp {
	r, _ := regexp.Compile(s)
	return r
}

func (c *Commands) Extract(t string) (string, string) {
	var a []string

	a = c.rmt.FindStringSubmatch(t)
	if len(a) == 3 {
		return a[1], a[2]
	}

    ...

	return "", ""
}
```

**A couple of comments for the code above:**

- The `(?i)` is there for case-insensitive regexp.
- I parse the commands and return the command and messages separately back to the route handler for 
it to do more there.
- If it doesn't match, it'll just return empty strings and subsequently gets thrown away.

### Sending a Response

I can send either a `GET` or a `POST` request to the appropriate API. I used the `sendMessage` method via the API.
The text in this case, can contain codes like `\n` and Unicode like `안녕`.

To replace the botId, apiKey, chatId and text for the `GET` request, I do the following:

```go
func (ac *AppContext) sendText(chatId int64, text string) {
	link := "https://api.telegram.org/bot{botId}:{apiKey}/sendMessage?chat_id={chatId}&text={text}"
	link = s.Replace(link, "{botId}", ac.conf.BOT.BotId, -1)
	link = s.Replace(link, "{apiKey}", ac.conf.BOT.ApiKey, -1)
	link = s.Replace(link, "{chatId}", strconv.FormatInt(chatId, 10), -1)
	link = s.Replace(link, "{text}", url.QueryEscape(text), -1)

	_, _ = http.Get(link)
}
```

And it's done! The application code is pretty short I'll say.

### To Be Continued

I hope this gives you a rough idea if you would like to get started in writing the application code for a Telegram Bot.

In Part 2, I will talk about how I set up `Docker` for the bot, and also
the self-signed SSL cert with Nginx as the reverse proxy on a Digital Ocean instance. Finally, 
I'll also show how I set up the git webhooks so that I can deploy with just one command!

[1]: https://web.telegram.org
[2]: https://github.com/aranair/remindbot
[3]: https://core.telegram.org/bots/api#available-methods
[4]: https://core.telegram.org/bots/api#setwebhook
[5]: https://core.telegram.org/bots/api#sendMessage
[gin]: https://github.com/gin-gonic/gin
[gorilla]: https://github.com/gorilla/context
[alice]: https://github.com/justinas/alice

