---
title: Embers Handlebars Setup Problem
date: 2013-07-27 00:00 SGT
tags: emberjs
disqus_identifier: /2013/embers-handlebars-setup
disqus_title: Ember Handlebar Setup
---
Went with ```ember-rails``` gem's default setup, did a bundle install/minimum rails set up and got this error in the browser...

<span style="color:rgb(255, 0, 0); font-family:menlo,monospace; font-size:11px">Assertion failed: Ember Handlebars requires Handlebars version 1.0.0, COMPILER_REVISION expected: 4, got: 3 - Please note: Builds of master may have other COMPILER_REVISION values.</span><span style="color:rgb(255, 0, 0); font-family:menlo,monospace; font-size:11px"> </span>

<div class="console-message console-debug-level" style="box-sizing: border-box; clear: right; position: relative; border-top-width: 1px; border-top-style: solid; border-top-color: rgb(240, 240, 240); padding: 1px 22px 1px 0px; margin-left: 24px; min-height: 16px; color: rgb(48, 57, 66); font-family: Menlo, monospace; font-size: 11px; line-height: normal;"><span style="color:blue">EBUG: Ember.VERSION : 1.0.0-rc.6 <a class="console-message-url webkit-html-resource-link" href="http://127.0.0.1:3000/assets/ember.js?body=1" style="box-sizing: border-box; float: right; text-align: right; max-width: 100%; margin-left: 4px; color: rgb(84, 84, 84); cursor: pointer;" title="http://127.0.0.1:3000/assets/ember.js?body=1:364">ember.js?body=1:364</a></span></div>

<div class="console-message console-debug-level" style="box-sizing: border-box; clear: right; position: relative; border-top-width: 1px; border-top-style: solid; border-top-color: rgb(240, 240, 240); padding: 1px 22px 1px 0px; margin-left: 24px; min-height: 16px; color: rgb(48, 57, 66); font-family: Menlo, monospace; font-size: 11px; line-height: normal;"><span style="color:blue">DEBUG: Handlebars.VERSION : 1.0.0-rc.4 <a class="console-message-url webkit-html-resource-link" href="http://127.0.0.1:3000/assets/ember.js?body=1" style="box-sizing: border-box; float: right; text-align: right; max-width: 100%; margin-left: 4px; color: rgb(84, 84, 84); cursor: pointer;" title="http://127.0.0.1:3000/assets/ember.js?body=1:364">ember.js?body=1:364</a></span></div>

<div class="console-message console-debug-level" style="box-sizing: border-box; clear: right; position: relative; border-top-width: 1px; border-top-style: solid; border-top-color: rgb(240, 240, 240); padding: 1px 22px 1px 0px; margin-left: 24px; min-height: 16px; color: rgb(48, 57, 66); font-family: Menlo, monospace; font-size: 11px; line-height: normal;"><span style="color:blue">DEBUG: jQuery.VERSION : 1.10.2</span></div>

<br>

Turns out that ember rc.6 is not compatible with handlebars rc4 because it hardcodes it to require rc3....... - -'

Short of modifying emberjs files myself, I did the ```rails generate ember:install --head``` again to get the latest nightly builds of ember hoping to get rc6.1 but unfortunately it didn't grab rc6.1 to my dismay... So I went to [http://builds.emberjs.com/ember-1.0.0-rc.6.1.js](http://builds.emberjs.com/ember-1.0.0-rc.6.1.js, "Ember Nightly") and downloaded it manually into my vendor folders and finally got it to work
