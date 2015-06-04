---
title: VIM Toggle Background Scheme
date: 2015-05-20 00:00 SGT
tags: vim
---

Have you ever wanted BOTH the dark and the light background schemes in VIM? Perhaps in the day, you feel that you can concentrate better with a light background and at night, the dark. I did! So I bound one of my Fn keys to do just that. 

This works well for color schemes that offer both dark and light versions, for example Solarized.

```
let g:scheme_bg = "dark"
```

```
function! ToggleDark()
  if g:scheme_bg == "dark"
    set background=light
    let g:scheme_bg = "light"
  else
    set background=dark
    let g:scheme_bg = "dark"
  endif
endfunction
```


```
map <F3> :call ToggleDark()<CR>
```

