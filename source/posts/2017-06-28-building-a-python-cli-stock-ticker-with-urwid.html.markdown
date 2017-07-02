---
title: 'Building a Python CLI Stock Ticker with Urwid'
description: 'In this post, I run through how I built a python CLI with the urwid package - 
a realtime updated stock ticker.  I also talk about how I published it to Pypi so that others 
can install it easily via the python pip command.'
date: 2017-06-28
tags: python, cli, urwid
disqus_identifier: 2017/cli-stock-ticker-python-urwid
disqus_title: CLI Stock Ticker with Python and Urwid
---

I do some investing in equities on the side and I've always wanted to build a simple stock ticker in the form of a
CLI app that runs in my terminal setup. There were a few out there but none that would should show 
just the information I needed, in a minimalistic fashion. So I thought it would be a fun project 
for me since I don't have much prior experience building a CLI app. 
  
So last weekend, I decided to just build one for fun! Here is the quick image of it running and 
you can find the code discussed here over at [https://github.com/aranair/rtscli][gh].

[![Demo](https://raw.githubusercontent.com/aranair/rtscli/master/rtscli-demo.png)](https://raw.githubusercontent.com/aranair/rtscli/master/rtscli-demo.png)

### CLI Libraries

I've been starting to work with Python more now that I'm doing more data-related work at Pocketmath 
so language-wise, Python was a natural choice. But many other languages do offer packages that 
can achieve the same result - like the [ccurses][1] library in C.

For Python, I found a number of different CLI libraries:

- [curses][2]
- [urwid][3]
- [click][4]
- [curtsies][5]

### Urwid

Eventually I went with [urwid][3] because it seems easier to just jump in and get started with it instantly.
[Urwid][3] is an alternative to the [curses][2] library in Python and it implements a variety of boilerplate
functions. You can find a list of them at their [documentation][6]. 

### Stock Ticker - Details

Okay, this section is mainly describing some of the functionalities I wanted and strictly
speaking, has nothing to do with urwid nor python nor code so feel free to skip if you're not into this ;)

The basic functionalities I wanted was:

- Read a list of stock tickers that contain the following:
  - Name of the Stock
  - Symbol (google symbol - `HKG:0005` e.g.)
  - Buy-in price
  - Number of shares held
- Display key information per stock:
  - Change (day)
  - % Change (day)
  - Gain (overall)
  - % Gain (overall)
- Display a portfolio wide change

### Implementation - MainLoop

I wanted a long-running CLI that continuously accepts commands (on top of updating the information on screen) 
can be modelled with a loop and that's exactly what Urwid calls it - a `MainLoop`.

```python
import urwid
main_loop = urwid.MainLoop(layout, palette, unhandled_input=handle_input)
main_loop.set_alarm_in(0, refresh)
main_loop.run()
```

The code above basically creates the `MainLoop` and calls the `refresh` method instantly (0s).
Don't worry about all the other stuff, I'll talk about those in a minute.

### Color Palette

That palette in the MainLoop above? That's where I define a color scheme that can be used
throughout the app. It's kind of like, when a web designer sets aside 5 colors for the entire
site to use.

```python
# Tuples of (Key, font color, background color)
palette = [
  ('titlebar', 'dark red', ''),
  ('refresh button', 'dark green,bold', ''),
  ('quit button', 'dark red', ''),
  ('getting quote', 'dark blue', ''),
  ('headers', 'white,bold', ''),
  ('change ', 'dark green', ''),
  ('change negative', 'dark red', '')]
```

In other parts of the app where I display text, I can then do this to change the color / background
of the text span.

```python
# Notice "refresh button" and "quit button" keys were defined above in the color scheme.
urwid.Text([
    u'Press (', ('refresh button', u'R'), u') to manually refresh. ',
    u'Press (', ('quit button', u'Q'), u') to quit.'
])
```

### Layout

```python
header_text = urwid.Text(u' Stock Quotes')
header = urwid.AttrMap(header_text, 'titlebar')
```

```python
# Create the menu
menu = urwid.Text([
    u'Press (', ('refresh button', u'R'), u') to manually refresh. ',
    u'Press (', ('quit button', u'Q'), u') to quit.'
])

# Create the quotes box
quote_text = urwid.Text(u'Press (R) to get your first quote!')
quote_filler = urwid.Filler(quote_text, valign='top', top=1, bottom=1)
v_padding = urwid.Padding(quote_filler, left=1, right=1)
quote_box = urwid.LineBox(v_padding)

# Assemble the widgets
layout = urwid.Frame(header=header, body=quote_box, footer=menu)

header_text = urwid.Text(u' Stock Quotes')
header = urwid.AttrMap(header_text, 'titlebar')
```

### Implementation - User Interaction 

I didn't need much user interaction so that makes things alot easier. The only interaction 
was basically just 2 keys `R` - which forces a refresh of the data and `Q` - which exits the program.
Otherwise, it was just grabbing data from a configuration file of sorts, pulling data from 
Google periodically and painting them onto the screen. 

In the end, these were the functions from urwid that I used.

- `MainLoop`
- `Frame`
- `Filler`
- `LineBox`
- `Padding`
- `Text`
- `AttrMap`
- `ExitMainLoop`

### Publishing it on Pypi

### Next Iteration

The next features that I am probably going to add on to this is probably either:

1. Grab news from Google related to the stock tickers and displays them in a separate window OR
2. Track transactions (but this is a lot more complicated that I have time for :P)

If you have any suggestions, feel free to let me know below!

[gh]: https://github.com/aranair/rtscli
[1]: http://tldp.org/HOWTO/NCURSES-Programming-HOWTO/intro.html#WHATIS
[2]: https://docs.python.org/2/howto/curses.html
[3]: http://urwid.org/
[4]: http://click.pocoo.org/5/
[5]: https://github.com/thomasballinger/curtsies
[6]: http://urwid.org/manual/index.html
[7]: http://urwid.org/tutorial/index.html
