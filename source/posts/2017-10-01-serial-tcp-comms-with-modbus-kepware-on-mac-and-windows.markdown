---
title: 'Programming with the Modbus Protocol and Kepware on OSX Sierra and Win 10'
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

### Premise

The premise of the project is that I need a program to read data from a spindle, as well as control it through an
inverter- the hitachi wj200 over the [Modbus][modbus] RTU protocol. At the same time, it also needs to relay these
information to a [KepwareServer][kepware] that has a [OPC/UA][opc] server. This then, in turn allows communication with
other OPC/UA clients.

The project was initially developed and tested on OSX Sierra 10.12.6 but was eventually compiled and ran on a Windows 10
so that the program can just talk to Kepware over modbus TCP instead of needing 2 machines: 1 linux/OSX + external cabling
to a windows machine (Kepware only runs on windows), but it was also tested on OSX Sierra 10.12.6 first.

You can find the reference code here: [https://github.com/aranair/modbus_adapter][code].

### Architecture

Spindle < hitachi wj200 < C program on windows > Kepware > OPC

= Insert Architecture Diagram =

### Modbus Masters vs Slaves

Initially, I was confused about the concept of masters, slaves, clients and servers in modbus. The two different ways of
definition that are sometimes used interchangeably in documentations makes it harder to remember which is which, at
least for me. So I should probably define it here properly so that it's less confusing for anyone who might read this.

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

As I've mentioned above, the slaves are the physical devices that you're communicating with. They're also called servers.


### Modbus Addressing

### Kepware

### Configuring Kepware

### Controlling Spindle and Relaying

[master-slave]: https://en.wikipedia.org/wiki/Master/slave_(technology)
[code]: https://github.com/aranair/modbus_adapter
[modbus]: http://www.simplymodbus.ca/FAQ.htm
[opc]: https://opcfoundation.org/about/opc-technologies/opc-ua/
[kepware]: https://www.kepware.com/en-us/products/kepserverex/
