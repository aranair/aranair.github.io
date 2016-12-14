---
title: Nil, Try & The Lonely Operator
description: 'A small discussion about nil, try and lonely operator in ruby code'
date: 2016-07-28
tags: rails, try
disqus_identifier: 2016/nil-try-lonely-operator
disqus_title: Nil, Try and the Lonely Operator
---

Recently, I left a comment on one of my colleague's PR and we had a discussion with him about
the use of `try` vs the lonely operator `&.` and it led to a number of conclusions personally.

I used to use lots of `.try`. I've also come across codebases littered with it, be it in the
presentation layer or in the models. From personal experience, I'll say it's pretty easy to end up with
`.try` littered all around.

I was curious about when it shouldn't be used, and if there were better alternatives.

### The Obvious Scenario

Before the lonely operator was introduced, I used `try` in a 2 distinct scenarios.

The first obvious usecase: when I am not sure if the object that I are calling the method on
could be a `nil` object or not. Obviously, calling any method on a `nil` object
rightfully throws an error during runtime. Of course, I could use something like this to avoid the
error.

```ruby
user && user.name
```

And `user.try(:name)` yields the same result.

### The Not So Obvious Scenario

Surprisingly, even when I don't know what the object is and whether it even has that method defined or not,
I still found myself using `try`. It still returns `nil`. It's like this deceivingly good and
lazy way to sidestep `NoMethodError`. But I find that this laziness, potentially leads to surprises
(which obviously isn't good).

```ruby
# Either a guest user without a name, or a registered user with a name
some_user.try(:name)
```

### The Lonely Operator

`user&.name` is equivalent to `user && user.name` and only this. It still throws a `NoMethodError`
when the method doesn't exist on the object. And that's good for various reasons.

```ruby
[]&.invalid_method # throws NoMethodError
```

In the event where I have no idea what the object is, it is a *clear* sign that I should spend
the time to refactor the code so that the object class is deterministic and
not rely on a `.try` to squirm out of the situation.

Another nice side effect is that, the lonely operator really doesn't look great when I chain it.
Being huge on aesthetics and coding styles, I just end up chaining less.

```ruby
user&.name&.truncate(5) # this just looks clunky imo
```

All those `.try(..).try(..)`? I always knew I should be getting rid of those too, but it was just
so safe. [Law of Demeter](https://en.wikipedia.org/wiki/Law_of_Demeter) literally screams at me
every time.

I hope this post makes you think twice the next time `.try` chains comes to mind:P
