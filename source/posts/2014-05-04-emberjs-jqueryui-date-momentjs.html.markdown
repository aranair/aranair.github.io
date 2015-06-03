---
title: EmberJS + JQueryUI Date + Moment.js
date: 2014-05-04
tags: emberjs
---

### The Reason
When handling the dates in one of my EmberJS apps, obviously I had to find a date picker to work with. In the end, with the recommendation from my fellow colleagues, I went with `jQuery UI's date picker` + `moment.js` for the parsing/display of the dates.

### The Issues
There were a few things that kinda put me off guard. 

The first: when deserializing/serializing it seems that there is some timezone problem with moment.js. The solution wasn't too difficult to find with a little bit of googling. It was to simply subtract away the timezone offset when serializing the data. 

```
DS.JSONTransforms.customdate = {
  deserialize: function(serialized) {
    var date, offset;
    if (serialized) {
      date = new Date(serialized);
      return moment(date).format('MMMM D YYYY');
    } else {
      return null;
    }
  },
  serialize: function(date) {
    if (date) {
      date = new Date(date);
      offset = -date.getTimezoneOffset();
      date = new Date(date.getTime() + offset * 60000);
      return moment(date);
    } else {
      return null;
    }
  }
};
```

After which, to wrap the query date picker in a ember view (so that it is easier to work with in the handlebars). There was this very nice hook that I couldn't find ANYWHERE except in some blog posts. 

```
App.DateField = Ember.TextField.extend({
  didInsertElement: function() {
    // return this.$().fdatepicker({format: 'MM dd yyyy'});
    return this.$().datepicker({
      dateFormat: 'MM d yy',
      numberOfMonths: 3,
      showButtonPanel: true
    });
  }
});
```

It basically means that when it inserts the time view (or rather kinda like a on render hook), it appends the date in that format and calls the jQuery ui's function on that element. this.$() is the same as this.$('element').


So when that was done, i realized that we had a CSRF issue that seems to have popped out of nowhere. I spent quite a bit of time searching on how to perform the automatic appending of the token to all the ajax requests (e.g. from DS.RestAdapter). With usual jQuery with rails, jQuery-rails gem handles the sending of the CSRF token. However, since we are not going to use that gem and ember has nothing to do with that(lol), we had to inject some code in order to send that manually.

```
$(function() {
  $(document).foundation();
  var token;
  token = $('meta[name="csrf-token"]').attr('content');
  return $.ajaxPrefilter(function(options, originalOptions, xhr) {
    return xhr.setRequestHeader('X-CSRF-Token', token);
  });
});
```

This basically just gets the csrf-meta stuff that is in the application layout file in rails and sends that token in every request.
