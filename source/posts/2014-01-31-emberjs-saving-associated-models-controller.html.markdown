---
title: EmberJS - Saving Associated Models (controller)
date: 2014-01-31
tags: emberjs
---

So after a few months of inactivity from Emberjs, I've decided to come back to abit of development fun!

I went on to upgrade ember to 1.3.0 and ember-data to one of their 1.0.0 nightly builds. It didn't require that many changes like before (thank god for that). 

Anyways, I had this piece of existing code break on me: 

```javascript
task.save().then(function() {
   task._data.subtasks.invoke('save').then(function() {
      // console.log('Associations saved')
   }
}, function() {
   task.rollback();
});
```

Its basically just calling save on the model, then after which continue to save its children. What .save() returns is a promise which basically allows you to concatenate the then function to perform further operations on it, a bit like a callback. But this piece of code throws an error because ```.invoke('save')``` **does not** return a promise as you might expect it to since the ```.save()``` still does!

There really needs to be better documentation for ember-data if they want people to start using it more :/
