---
title: My Dilemma With BEM
date: 2014-04-22 00:00 SGT
tags: bem, frontend
---

What exactly is BEM? 

```BEM stands for Block, Element, Modifier. ```

In case you haven't heard of BEM yet, do go to http://bem.info/method/definitions/ to have a look. It's a really interesting naming convention for your DOM elements that makes it more manageable in the long run that has gained popularity recently. Trending yo!

Its pretty useful in that it sort of namespaces each of the items on the page to help with classification and readability. When you look at a class name for example: ```left-panel__superheader```, you immediately know that you're looking at the superheader that is embedded in the left-panel block.

### My Dilemma

The convention is pretty good in most cases but I seem to always get stuck with this scenario:

```
<block-1>
  <block-2> 
    <element-1> 
    <element-2> 
  </block-2>
</block-1>
```
How would you then name the elements embedded inside both block-1 and block-2? Do you  or do you simply remove block-1?

Option 1: name it cascadingly ```block-1__block-2__element-1```
Option 2: name it only with the immediate parent block e.g. ```block-2__element-1```

The benefit with Option 1 is that it is MUCH clearer when you look at just the class name of a DOM element. You will not need to guess where is block-2 coming from? But the main problem with this approach is that if you have more than 2 levels, you're going to run into massive problems controlling the class name lengths and the html gets really ugly :/ One solution is to restrict the block-embed-level to a maximum of 2.

With Option 2, you get less readable class names but the HTML is so much cleaner. I am currently rolling with this option but IMO in a big project the number of embedded blocks might get messy and people start to forget which blocks they have initialised so I would say its best if there is something like a chart to help with the hierarchy of major blocks.


Perhaps that could be my next project!
