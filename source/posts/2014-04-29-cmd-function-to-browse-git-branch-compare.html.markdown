---
title: CMD Function to Browse Git Branch/Compare
date: 2014-04-29 00:00 SGT
tags: git, scripting
---

While I am doing development work on projects, be it at work or at home, I find that something that I do at least a couple of times (or more) daily. After commiting and pushing the changes, sometimes I want to go to the branch on github from the terminal to either create a pull request or to just view all the commits/diffs altogether. It gets a little troublesome to navigate to that exact branch in the browser. Disclaimer: I know you can do PRs in Sourcetree directly, and do all sorts of things using ```git diff```. But I just find that having that clean view in Github kind of helps me with visualisation of the changes. YMMV!

So yeah, I wrote 2 quick shell alias/functions to help me with that.

### Goes to Github Branch

```
# Opens the github page for the current git repository in your browser
function gh() {
  giturl=$(git config --get remote.origin.url)
  giturl=${giturl/git\@github\.com\:/https://github.com/}
  giturl=${giturl/\.git/\/tree/}
  # branch="$(git symbolic-ref HEAD 2>/dev/null)" ||
  branch="$(git rev-parse --abbrev-ref HEAD)" ||
  branch="(unnamed branch)" # detached HEAD
  branch=${branch##refs/heads/}
  giturl=$giturl$branch
  open $giturl
}
```

### Goes to Github Compare (current branch)

```
# Opens the github page for current git repo and compares it -> for a new PR.
function newpr() {
  giturl=$(git config --get remote.origin.url)
  giturl=${giturl/git\@github\.com\:/https://github.com/}
  giturl=${giturl/\.git/\/compare/}
  branch="$(git rev-parse --abbrev-ref HEAD)" ||
  branch="(unnamed branch)" # detached HEAD
  branch=${branch##refs/heads/}
  giturl=$giturl$branch
  open $giturl
}

```

### Usage

To use these, its as simple as dropping the functions into either of your dotfiles, so either .bashrc, .zshrc or .bash_profile in your home directory.
