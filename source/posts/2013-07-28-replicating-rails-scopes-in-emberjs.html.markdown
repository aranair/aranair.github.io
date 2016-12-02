---
title: Replicating Rails 'scopes' in Emberjs
date: 2013-07-28 00:00 SGT
tags: emberjs
disqus_identifier: 2013/replicating-rails-scopes-emberjs
disqus_title: Replicating Rails scopes in Emberjs
---
After setting up all the boilerplate stuff and a quick mock up for the new Task project, I went on to the more dynamic code in Emberjs. 

So basically, today I wanted to have tasks displayed out in the /tasks page separated into a few different 'categories' - delayed, active, completed, and coming soon etc. Something so simple would probably be done in Rails views via a few different variables set in the controller that calls the model's pre-defined scopes. Nothing more than a few minutes work. It shouldn't be too difficult in Ember too, right? ...Well if the final solution was pretty damn easy but I had to scourage quite a few places to be able to get to that and the solution was quite a surprise lol. I'll cut to the chase and just begin with the solution.

Basically: in a template view say tasks like below:

```
<script type="te​xt/x-handlebars" data-template-name="tasks">
{{ taskCompleted }}
</script>
```

If you called a custom attribute like the one shown above, it first goes to the corresponding controller (in this case the TasksController) and tries to find this attribute before trying to find it in any models. What this means is that I can now define some specific logic in this controller like this:

````
App.TasksController = Ember.ArrayController.extend({
   completedTasks: function() {
     return this.filterProperty('isCompleted', true);
   }.property('@each.isCompleted')
});
```

To pull the data from the model in whatever way I want, it is fed to the template, good ol' Rails fasion! I suppose this is what Emberjs pros meant when they said the controllers were something like a proxy to the underlying data models. 

