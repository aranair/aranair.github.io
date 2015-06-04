---
title: Emberjs Model RestAdapter Conventions
date: 2013-08-04 00:00 SGT
tags: emberjs
---

After I was done with exploring with local fixtures data, its time to experiment with using the RestAdapter provided by Emberjs to call the appropriate json data from the rails backend.

It was pretty simple and straightforward mostly. You basically just change the store to have "adapter: DS.RESTAdapter" and extend the model to have the appropriate attribute names from the server. (I'm using ActiveModel serializers) It then automagically works. Emberjs helps to figure out all the paths it needs to get the appropriate data.  

So for example, if you bound the index/root "/" to the tasks model via a task router and set a nested resource for tasks in the same route. 

```
App.Router.map(function() {
    this.resource(tasks, {path: /}, function() {
       this.resource(task, {path: :task_id});
    });
});
```
It'll send a get request to /tasks when you're at root. It will also know that when you are at #/2, it should be sending the request to /tasks/2 as long as you provide the task_id to the router like above.

 
One small thing that tripped me was the code below:

```
App.Task = DS.Model.extend({
   name: DS.attr('string'),
   task_details: DS.attr('string'),
   isCompleted: DS.attr('boolean')
});
```
How do you think the json data should look like? Like this?

```
{ name: 'test', task_details: 'details', isCompleted: false}
```

Apparently not so!  It turns out that Emberjs expects snake case in the JSON when the attribute name is camelized! So the correct format that you should be sending from the server should be like this!

```
{ name: 'test', task_details: 'details', is_completed: false}
```

