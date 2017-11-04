---
title: 'Programming with the Modbus Protocol'
description: ''
date: 2017-10-01
tags: modbus, kepware, c-programming
disqus_identifier: 2017/hardware-programming-modbus-kepware-osx-win10
disqus_title: Hardware Programming
---

Today's post is in a very different segment - hardware programming; it's nowhere near the web projects that I've been
doing so far but definitely something I'm super interested in. This project mostly works with the modbus protocol,
which is an open, communication protocol used for transmitting information over serial lines between hardware devices.
Given that IoT is becoming more and more relevant and that the modbus protocol, while old, is still a very commonly used
protocol in the IoT world. So, I hope people will find this post interesting. Let's begin.

### Backstory

The backstory of the project is that I needed a program to read some data from a spindle, as well as control it through an
inverter- the hitachi wj200 over the [Modbus][modbus] RTU protocol. At the same time, it also needs to relay some of this
information to a [KepwareServer][kepware] that acts as both a Modbus TCP/IP slave and a [OPC/UA][opc] server.
This then, in turn allows communication with other OPC/UA clients.

The project was initially developed and tested on OSX Sierra 10.12.6 but was eventually compiled and ran on a Windows 10
so that the program can just talk to Kepware over modbus TCP instead of needing 2 machines: 1 linux/OSX + external cabling
to a windows machine (Kepware only runs on windows), but it was also tested on OSX Sierra 10.12.6 first.

You can find the reference code here: [https://github.com/aranair/modbus_adapter][code].

### Simplified Demo

If you're just here to find some code that runs a Modbus client and server, you can check out the `simplified` branch
from the repo above.

### Setup

The hardware setup looks roughly like this:

Spindle <> hitachi wj200 <> USB to COM converter <> C program on windows machine <> Kepware <> OPC/UA

In this post though, I'll focus on the first part (from the left) of the setup, up to the windows machine. The C program
was written and tested on my Mac at first so I'll talk a little bit on that. In the next post, I'll shift the focus to
Kepware and how I compiled program in Windows 10, which turned out to be harder than I thought it should be because of
some dependencies I used.

### Modbus Masters vs Slaves

I am not going to explain what is a Modbus protocol, you can head over [here][modbus] if you want a quick overview of
what it can do but I'll like to talk about something I was initially confused about.

It was the concept of masters, slaves, clients and servers in Modbus. The two different ways of
definition that are sometimes used interchangeably in documentations makes it harder to remember which is which, at
least for me. So, before moving ahead with the rest of the stuff, I should probably define it here again so that
it's less confusing for the unfortunate souls who might read on lol.

#### Master / Client

The master in a modbus network is the brain that is in charge of controlling devices. They can read and write to
slaves (devices). The concept of master and slave is [pretty common][master-slave] in software engineering, so I
won't elaborate more here.

However, in the case of the modbus protocol, the master is also called the client and physical
devices such as the inverter above, are considered servers, or slaves.  The master would be the
one that initiates the connection to the slaves. I had assumed it was the other way around.

What remains the same is that, there can only be one master in a single modbus RTU network. (You can
have multiple masters in a modbus TCP/IP network though I think.)

#### Slaves / Server

The slaves are the physical devices that you're communicating with. They're also called servers. They
accept connections from the masters.

### libconfig

With regards to config files setup in my C program, coming ƒrom ruby and the web environment, YAML seemed like a
natural choice. But I soon learned that, that's not the case in C. I'm not sure what is the de-facto solution here,
or if people used config files at all, but I eventually settled on `libconfig`. It was fairly simple to use and
the interface was semi-clean I guess, even if a little convoluted.

It provides you a way to define nested lists and hashes.

```
connections = (
  {
    type = "rtu";
    rtu_port = "COM3";
    baud = 115200;
  },
  {
    type = "tcp";
    ip = "127.0.0.1";
    port = 502;
  }
);
```

Which you can then get from the program via something like

```
setting = config_lookup(&cfg, "connections");
int connections_count = config_setting_length(setting);
conn_arr = (struct ModbusConn *) malloc(sizeof(struct ModbusConn) * connections_count);

const char *type;
for (i = 0; i < connections_count; i++) {
  config_setting_t *connection = config_setting_get_elem(setting, i);
  config_setting_lookup_string(connection, "type", &type);
  ...
}
```

I know, it is a little long if you're coming from ruby since all of those would be a single line of code.
But hey, at least I've managed to encapsulate all the config stuff into [config.h][code-config].
From the main program, I just need to search/reference it for the configs!

```
struct ModbusDevice *plc = get_device(config, "hitachiwj200");
struct ModbusDevice *kep = get_device(config, "kepware");
```

### Multiple Modbus Masters?

For each of the connections defined in [config.cfg][code-configcfg], I created a Modbus connection.
In this case, one was over RTU protocol and speaks over COM3 and one over TCP/IP.

My spindle was obviously a slave, and it accepts connections / commands from a master. But, I also needed live
information from the spindle at the windows machine with Kepware. At first, I was hoping that I could achieve
that by having a single Modbus slave to multiple Modbus masters (program + kepware). Unfortunately, that isn't
possible, at least over Modbus RTU.

To get around that, I got my program to issue commands to the spindle as a master, while periodically polling
whatever required data from it, and relaying that information as a master to another slave- the Kepware instance.

Essentially, my program initiates and maintains two separate Modbus connections as a master.

### Configuring Kepware

I'm not going to go into too much details with the configuration of Kepware since the vast majority of you who
happen to read this article will not be paying the price tag on Kepware. But, I think it's enough to say that,
it is a piece of software that provides multiple drivers and UIs that come bundled with it to allow devices who might
speak different protocols such as modbus, or OPC/UA (and a million others), to speak to each other without
needing another piece of software to translate.

For the purpose of this project, it was set up on a Windows machine such that it would host a Modbus slave
that accepts connections from my program, and would receive the data over Modbus TCP/IP as a slave and store the
streamed byte data in an internal register that is universally accessible in Kepware by it's other services e.g.
the OPC/UA driver.

### Virtual Serial Ports Via Pseudo Terminal

The above sections kinda ran through the setup that I built. This section is mostly on a quick way to run it locally
without needing a COM port connected to the actual device at first. I found it troublesome to have to test my program
with the actual spindle/hardware connected all the time so I looked for a way to simulate the Modbus RTU locally.

So far, I've found that the pseudo terminal works pretty well, okay except when it randomly stops emiting the stream
data mysteriously heh. But, a restart of the socat stuff below usually fixes that.

I used virtual serial ports to test the program using the steps below:

```
$ brew install socat
$ socat -d -d pty,raw,echo=0 pty,raw,echo=0  # to get two pseudo terminals assigned.
$ cat < /dev/ttys035
$ echo "Test" > /dev/ttys037 # on a separate terminal
```

[Socat][socat] is a command line based utility that establishes two bi-directional byte streams and allows a
transfer of data between them. The commands above, in combination, sets up a  byte stream across
`/dev/ttys035` and `/dev/ttys037` (psuedo terminals) so that any data sent from one end of it will be transmitted
over to the other.

In other words, I could then get my program, which acts as a Modbus RTU master, to connect directly to `/dev/ttys035`
that has a Modbus RTU slave connected to it. And they can talk to each other in the modbus protocol flawlessly.

### Wrapping Up

I hope this helps anyone out there who is trying to achieve the same thing and like me, doesn't have a clue how or where
to begin.

Anyways, after finishing development of the program on my Macbook, I eventually had to move this to a Windows machine running on Win 10.
Despite the fact that C is relatively well-supported on Windows (I mean it's just basically compiling to byte code), I had quite
a hard time compiling it because of all that dll shit and hoops that Windows make you jump through, and some issues surrounding
certain dependencies the program had. I did get everything to compile in MSVS 2017 eventually, but I think I'll leave that story
to Part 2 instead. If you wanna skip ahead, the project files can be found in the [win32 folder][code-win32]!

[master-slave]: https://en.wikipedia.org/wiki/Master/slave_(technology)
[code]: https://github.com/aranair/modbus_adapter
[modbus]: http://www.simplymodbus.ca/FAQ.htm
[opc]: https://opcfoundation.org/about/opc-technologies/opc-ua/
[kepware]: https://www.kepware.com/en-us/products/kepserverex/
[libconfig]: https://github.com/hyperrealm/libconfig
[libmodbus]: http://libmodbus.org/
[code-win32]: https://github.com/aranair/modbus_adapter/tree/master/win32
[code-config]: https://github.com/aranair/modbus_adapter/tree/master/config.h
[code-configcfg]: https://github.com/aranair/modbus_adapter/tree/master/config.cfg
