---
title: Block Scope in Javascript
date: 2014-05-07 00:00 SGT
tags: javascript
---

I do abit of development work using plain Javascript on and off. I've written OOP modular Javascript for Wego as well but my development work is never really deep enough to encounter all the classic "noob" problems. 

Today I came across one. It was something that got me a little mind-blown because it is something that I have entirely taken for granted in other OO programming languages like Ruby. It is the lack of block scopes in JavaScript.

Let me illustrate this with some code:

```
var x = 5;
function foo () {
   // position a
   if (x > 0) {
      var x = 0
      console.log('x > 0');
   } else {
      console.log('x <= 0');
   }
}
```


### The Wrong Way to Evaluate

What do you think it should print? 

The conventional way to think about this is to say that the if/else is first evaluated before going into the if block and then getting the local variable declared thus printing `x > 0`. However, contrary to other languages like ruby, JavaScript does not have a block scope (the if scope).

### Why?

When you declare `x = 0` in the if block, on runtime, JavaScript actually moves the `var x = 0` to `position a` where it becomes a variable in the function scope, effectively overwriting the `var x = 5` outside the function, causing this code to print `x <= 0`.

### The Correct Way

Because of the lack of block scopes, you should try not to declare variables in a block but move them outside in a function and then proceed to assign values to it in the block as per normal. This will prevent undesired behaviours from happening!

