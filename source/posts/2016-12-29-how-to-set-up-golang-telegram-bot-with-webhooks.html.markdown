---
title: 'How I Built My Golang Telegram Bot Part 1: Application Code'
description: 'In this post, I go through all the steps I took to build a golang telegram bot. 
It would include code to show how to dockerize the app and what to take note of when you are building 
a telegram bot to use webhooks with.'
date: 2016-12-29
tags: golang, telegram, bot, webhooks
disqus_identifier: 2016/build-golang-telegram-bot-webhooks
disqus_title: How to Build a Golang Telegram Bot with Webhooks
---

This is the first part of the `Golang Telegram Bot` series. 
In this series, I'll show you code samples and guide you through them on how to 
build a Golang Telegram Bot for my own use. It would listen in and respond only upon 
certain text cues. Finally I'll also demonstrate how to get a self-signed SSL cert working with Nginx
and deploying the application in a Docker container on a Digital Ocean instance.

Hopefully this will help anyone out there who would like to try their hand at their own bot on Telegram!
The code for this bot is currently hosted at [https://github.com/aranair/remindbot][2] if you'll like
to just skip to the code immediately.

### Backstory

I've been using [Telegram][1] for a really long time, and I've been wanting to build a Telegram bot 
for a long time since they first announced it. 
  
Initially, I was thrown off a little by the requirement of https for the webhooks, 
thinking that I might need a domain and a SSL cert to get it working but I quickly found out that
a self-signed SSL certificate would work just as well in this scenario!

So, if you find yourself in the same situation, don't worry about it! It might be slightly more complex 
to set up a self-signed SSL cert with Nginx, but it's not all that difficult! In this series, 
I'll explain code examples that I used to set it all up in `production`!

### Getting an API Key

First, you'll need an API key from the [![botfather.png](https://s24.postimg.org/d0amvsmut/botfather.png)](https://telegram.me/botfather)

Send him a `/token` command to get a set of tokens (botId and API key). 
You will need it for requests to execute methods using the telegram API. 

```yaml
# {botId}:{apiKey}
123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
```

**Take note** of the word `bot` before the `<token>`!

```yaml
https://api.telegram.org/bot<token>/METHOD_NAME
```

All the methods are listed over at the [Telegram Bot docs][3] but for the purpose
of this simple starter bot, I will really only be using [setWebhook][4] and [sendMessage][5].

### Webhook vs Polling

Great! You have an API key now. Now, you'll need to choose between two ways to get messages from Telegram.

- Webhooks via `setWebhook`
- Polling via `getUpdates`

I'm fairly certain that it is easier to set up with `getUpdates` but polling isn't always an option.
For this bot, I went with webhooks as I wanted the bot to immediately respond upon certain text cues.

With webhooks, everytime there is a message (when privacy mode is disabled anyway), the webhook endpoint
will be sent a message. So the main objective, is to parse each of these messages or updates and
respond appropriately.

To set up the Webhook you'll need to send a curl request to the Telegram Api.

```bash
curl -F "url=https://your.domain.com" -F "certificate=@/file/path/ssl/bot.pem" https://api.telegram.org/bot12345:ABC-DEF1234ghIkl-zyx57W2v1u123ew11/setWebhook
```

Of course, you'll need to send the self-signed SSL **public** pem file as an `InputFile` as well so that
Telegram knows that it's really the correct server it's sending all the messages to. I'll leave that
explanation to the second part of this series.

### Router

There are many popular router implementations out there like [gin][gin] and [gorilla][gorilla].
For me, I've chosen to go a bit more minimalistic with `github.com/gorilla/context` and 
`github.com/julienschmidt/httprouter` for the router.

*Ok, to be fair, context (for the params) actually isn't really needed at this point, but
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

I use `github.com/BurntSushi/toml` to parse the config toml file. It's like `yml` on steroids lol.

I will explain the `datapath` in the second part of this series where I will talk about the dockerization
and deployments. For now, it suffices to know that it will be used as a data volume for docker.

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

Since this bot was mainly built for reminders and for personal use really, I've chosen to go with
sqlite for now but I've actually got it set up with `pq` before and it is really quick to swap it out.

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

The updates that Telegram sends to the bot  will contain numerous fields, including some optional ones 
that may or may not appear depending on the type of update, but the ones we're concerned with for
this bot are:

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

- The message would be contained in `update.Msg.Text`
- The `chatId` is in `update.Msg.Chat.Id`. This is important because you'll need it to send a 
response back.
- The bot currently doesn't use `User` but I've written the code above so that you can get it as well.

### Command Extraction

There is a `Commands` object that contains all the `regexp.Regexp` items that are used to find matches 
for commands. These are instantiated once during bot startup but I admit this part is a lot more 
repetitive than needed and I am still looking for ways to clean this up.

So if you have any suggestions, feel free to let me know in the comments below!

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

You can send either a `GET` or a `POST` request to the appropriate API. In this case, we would use
the `sendMessage` method. The text in this case, can contain codes like `\n` and Unicode like `안녕`.

I use the code below to replace the botId, apiKey, chatId and text for the `GET` request. It is
pretty straightforward, right?

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


### To Be Continued

I hope you now have a rough idea on how to get started in writing the application code for a Telegram Bot.

In Part 2, I will talk about how to set up `Docker` for the application and how to set up 
the self-signed SSL cert with Nginx as the reverse proxy on a Digital Ocean instance. Finally, 
I will also set up git webhooks so that I can deploy with just one command! Stay tuned!

[1]: https://web.telegram.org
[2]: https://github.com/aranair/remindbot
[3]: https://core.telegram.org/bots/api#available-methods
[4]: https://core.telegram.org/bots/api#setwebhook
[5]: https://core.telegram.org/bots/api#sendMessage
[gin]: https://github.com/gin-gonic/gin
[gorilla]: https://github.com/gorilla/context
[alice]: https://github.com/justinas/alice

