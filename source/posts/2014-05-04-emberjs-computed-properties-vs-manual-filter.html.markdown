---
title: EmberJS Computed Properties vs Manual Filter
date: 2014-05-04 00:00 SGT
tags: emberjs
---

The problem begins when one of my 'filter functions' for the my model (delayed/active tasks lists from all tasks) wasn't getting reactively updated when the store gets new entries or updates. When I found out why, I thought to myself that this is actually a pretty easy scenario to fall into IMHO.

I realised that I wasn't actually utilising ember-data but manually creating the filter. In that manner, the activeTasks will only be evaluated on the first run and that subsequent changes to the `taskStatus`, `endDate` and `startDate` were not observed. I basically had to manually manage the lists myself, which is obviously pretty stupid given the powerful capabilities of the reactive-model-updates. The below code was placed in my task controller. 

```
activeTasks: function() {
    return this.get('content').filter(function(m) {
      var today = new Date()
      var endDate = new Date(m.get('endDate'))
      return endDate <= today && m.get('taskStatus') == true
    });
  }.property('@each.taskStatus, @each.endDate')
```

### The Solution

With some searching, I found that this use case should and only be achieved via computed properties. You have to create a `computed property` in the model file.

```
// Computed Property, Placed in the model file.
isDelayed: function() {
    var today = new Date();
    var endDate = new Date(this.get('endDate'));
    return endDate > today && this.get('taskStatus') == true
  }.property('endDate', 'taskStatus')
```

This gives you the `computed property - isDelayed` to work with in the controller. And this property is also correctly observed by ember-data and will be automatically updated when there are updates to the underlying property in the model. 


```
// Working with the computed property in the controller
delayedTasks: function() {
    return this.filterProperty('isDelayed', true);
  }.property('@each.isDelayed')
```

