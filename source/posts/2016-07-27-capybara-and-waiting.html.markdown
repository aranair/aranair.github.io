---
title: Capybara & Waiting
date: 2016-07-27
tags: capybara, rails
disqus_identifier: 2016/capybara-and-waiting
disqus_title: Capybara and Waiting
---

All of us do TDD or at least some form of automated testing, I hope! If you’re writing tests in Rails, 
you’re likely to be doing feature tests with [Capybara](https://github.com/jnicklas/capybara) as well.

Some of these slipped my mind while adding feature specs at work at 
[pocketmath](https://www.pocketmath.com/) and I spent extra time that I shouldn't have! 
So I hope this post can be a reminder to myself in future and be of help to anyone who 
encounters the same problems!

### Common Scenario

Let’s look at a common scenario in a feature test: 

- Load some form
- Click a random button
- Check if the refreshed page (or partially re-rendered pages) matches your expected results

If you’re just transitioning from unit tests, it might be tempting to jump right to this option:

```ruby
visit some_path
click_button 'Submit' # Does an AJAX request

# -- Page refresh or re-render --

expect(find('#dom-id').text).to eq 'something'
```

You'll find that it doesn't work too well (not at all actually). This is because there is a delay 
between the button click and the actual completion of the code that is run as a result of that click. 

It is not synchronous. It could be a page refresh, a partial render or a simple AJAX call. 
Its hard to predict how long exactly that is going to take.

### Magical Built-in Matchers

For this reason, Capybara provides us with some built-in matchers. They work amazingly well 
for these scenarios where you are waiting for something to finish before checking the content for text, 
DOM elements for visibility etc. Since the start, it was designed to automatically wait for elements 
to appear or disappear on the page.


```ruby
find('#dom-id').should have_content 'something'
# have_css, have_selector
```

You can even define if the element should be visible or not after it is rendered. 

```ruby
find('#dom-id').should have_content 'something', visible: false
```

Magical. Right? 

### Old solutions 

Despite the fact that the awesome Capybara matchers were there from the start, pre-2.0, many people didn't use them.
Instead they used `wait_until { ... }` or even `sleep(3)` despite being clunkier solutions. 
`wait_until` was then deprecated in Capybara v2.0 altogether.


### Complications

Take a look at the scenario below, is that single `have_content` there sufficient? What do you think?

```ruby
fill_in :name, with: 'Daniel'
click_button 'Link' #some AJAX call happens
reload_page
expect(page).to have_content 'Linked'
```

Nope! There's still a chance that the `reload_page` would happen before the AJAX code finishes. 
And the tests would randomly fail since the content-check is dependant on the click event's code execution.
That's not good; we all want deterministic results for our tests, right?

### What now?

So what do we do now? Well, one pretty elegant way to fix this is explained over at a thoughtbot blog post 
[here](https://robots.thoughtbot.com/automatically-wait-for-ajax-with-capybara).  Through spec 
helpers, they introduce a `wait_for_ajax` method that was designed to be used whenever you need 
to make sure that all AJAX calls have completed before proceeding, or in this case, before the page reload.

### Alternatives

Alternatively, you could also use `have_selector` infront of the reload to block the execution. But in my opinion, 
if you don't actually want to test the content, using `wait_for_ajax` makes more sense. 

So the next time you encounter similar issues, stay calm and first check to make sure that you are 
using the Capybara built-in matchers before using `sleep`!

What does everyone think? Are your experiences similar?
