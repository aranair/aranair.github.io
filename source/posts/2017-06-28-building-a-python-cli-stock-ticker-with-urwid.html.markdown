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

I imagined the app to be a long-running CLI that continuously accepts commands, on top of 
re-painting the information on screen of course. That can be modelled with a loop and 
it's exactly what Urwid calls it - a `MainLoop`.

```python
import urwid
main_loop = urwid.MainLoop(layout, palette, unhandled_input=handle_input)
main_loop.set_alarm_in(0, refresh)
main_loop.run()
```

The code above basically creates a `MainLoop` which ties together a display module, some widgets
and an event loop. Quoting the documentation: *It handles passing input from the display module to the 
widgets, rendering the widgets and passing the rendered canvas to the display module to be drawn.* 

**I think of it as a controller of sorts.**

`set_alarm_in` is like `setTimeout` in the JavaScript world; it just calls the `refresh` method instantly
in this case. 

### Implementation - Refresh Mechanism 

Within the refresh function above, I would set another alarm that goes off in `10s`, 
that is the time between each data pull from Google Finance.

```python
def refresh(_loop, _data):
    main_loop.draw_screen()
    quote_box.base_widget.set_text(get_update())
    main_loop.set_alarm_in(10, refresh)
```

This calls the `get_update()` method that spits out an array of tuples of `(color_scheme, text)`.

### Color Palette

That palette in the MainLoop section above? That's where I define a color scheme that can be used
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

In other parts of the app where text is displayed, those keys will be used to tell the app
what color / background the text span should be.

```python
# Notice "refresh button" and "quit button" keys were defined above in the color scheme.
menu = urwid.Text([
    u'Press (', ('refresh button', u'R'), u') to manually refresh. ',
    u'Press (', ('quit button', u'Q'), u') to quit.'
])
```

### Layout

This creates a header and assigns the `titlebar` key color scheme to it.

```python
header_text = urwid.Text(u' Stock Quotes')
header = urwid.AttrMap(header_text, 'titlebar')
```

Same for `quote_text`, except this time a bunch of other widgets were used.

A [filler][filler] will maximise itself to the screen and the [padding][padding] widget is self-explanatory;
it keeps one column open on each side. And finally the `LineBox` leaves a border around the main area.

```python
quote_text = urwid.Text(u'Press (R) to get your first quote!')
quote_filler = urwid.Filler(quote_text, valign='top', top=1, bottom=1)
v_padding = urwid.Padding(quote_filler, left=1, right=1)
quote_box = urwid.LineBox(v_padding)
```

Finally, the `Frame` ties it all up into a layout for my app and it is used in the initialization
of the `MainLoop`.

```python
# Assemble the widgets
layout = urwid.Frame(header=header, body=quote_box, footer=menu)
# main_loop = urwid.MainLoop(layout, palette, unhandled_input=handle_input)
```

There are a ton of other ways you can structure the main components of the app and there are so many widgets
implemented in the library. One example are the [container widgets][container widgets] like 
Piles(stacking vertically) or ListBox (for menus) for example.

### Implementation - User Interaction 

I didn't really need much user interaction so that made things alot easier; the only interaction 
was basically just 2 keys: `R` - which forces a refresh of the data and `Q` - which exits the program.

```python
# Handle key presses
def handle_input(key):
    if key == 'R' or key == 'r':
        refresh(main_loop, '')

    if key == 'Q' or key == 'q':
        raise urwid.ExitMainLoop()
```

**Note:** The method has to accept the 2 keys. That's the contract of the `main_loop.set_alarm_in()`
I believe.

### Preparing the Package for Pypi

I added a `setup.py`, this is sort of like the `gemspec` of ruby gems where metadata and dependencies
are stated. I didn't use any folders because the script is so short already.

```python
from setuptools import setup
setup(
    name='rtscli',
    version='0.3',
    description='A realtime stocks ticker that runs in CLI',
    url='http://github.com/aranair/rtscli',
    author='Boa Ho Man',
    author_email='boa.homan@gmail.com',
    license='MIT',
    install_requires=[
        'urwid',
        'HTMLParser',
        'simplejson',
        ],
    zip_safe=False,
    py_modules=['rtscli'],
    entry_points={ 'console_scripts': ['rtscli=rtscli:cli'] },
)
```

Of course, you do have to setup a [pypi][pypi] account and have the credentials in the `.pypirc` file.
After that, all that was left was:

```bash
$ python setup.py register -r pypi
$ python setup.py sdist upload -r pypi
```

That's it; All ready for `pip install rtscli`!

### Next Iteration

There are a bunch of improvements I can think of, but for a start:

0. Perhaps, most importantly, I would like to refactor this into using proper widgets 
instead of appending texts into the quote_box.
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
[container widgets]: http://urwid.org/manual/widgets.html#container-widgets
[filler]: http://urwid.org/reference/widget.html?highlight=frame#filler
[pypi]: https://pypi.python.org/pypi
