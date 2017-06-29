---
title: 'Building a CLI Stock Ticker with Python & Urwid'
description: 'In this post, I run through how I built a graphical CLI stock ticker in Python and Urwid. It also contains
the steps to publish it to Pypi so that others can install it via pip. I talk about some of the issues and maybe pitfalls
as well as some other existing toolings out there that you can use to further enhance it.'
date: 2017-06-28
tags: python, cli, urwid
disqus_identifier: 2017/cli-stock-ticker-python-urwid
disqus_title: CLI Stock Ticker with Python and Urwid
---

Since I do a bit of investing on the side in the HK market, I've always wanted to build a simple stock ticker in the form of a
CLI app, that shows the information I want, in a minimalistic fashion. That way, I can stay in terminal all day long! Jokes aside, 
I thought it was a fun exercise overall for me since I haven't much experience building a graphical CLI. I've been starting
to work with Python more now that I'm venturing into data-related work at Pocketmath so that was a natural choice. And after 
surveying the couple of options out there for CLI apps such as [ncurses][1] in C, [curses][2] / [urwid][3] / [click][4] 
in Python, I went with whatever was easiest to start with
in my opinion.

[1]: http://tldp.org/HOWTO/NCURSES-Programming-HOWTO/intro.html#WHATIS
[2]: https://docs.python.org/2/howto/curses.html
[3]: http://urwid.org/
[4]: http://click.pocoo.org/5/
[5]: https://www.elastic.co/guide/en/elasticsearch/reference/current/setting-system-settings.html
