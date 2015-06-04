---
title: Opt-Arrow Navigation in iTerm2
date: 2015-05-12 00:00 SGT
tags: vim, iterm
---

Something that most people use frequently but take for granted for sure is the use of Option + Arrow keys to navgiate between words in Mac OS X. Its just something you use and not think about much and it becomes second nature almost. So when I moved to iTerm, I'm sure a couple of you would have wanted to maintain the the same behaviour of that in iTerm2 instead of having to use the ```Escape + b/f``` sequence which is at best just a working but hard to execute sequence. 

### Solution?

It turns out to just require a simple change of 2 preferences in iTerm2 for it to work like before!

- Under Profiles -> Keys
- Modify the option + arrows key
- Set the action to “Send Escape Sequence”
- Set the Esc+ field to:

```
[1;5C (Option-Right)
[1;5D (Option-Left)
```
