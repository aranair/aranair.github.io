---
title: Dnsmasq for Local Dev
date: 2014-04-28 00:00 SGT
tags: dnsmasq
---

I work for Wego (hotels/flights metasearch) and we've got many sites for the various cctlds. To test them after frontend development, usually I'll just add like www.wego.com.sg to my host file and direct it to 127.0.0.1 but sometimes it gets a little troublesome, especially when the autocomplete forms breaks from www.wego.com.sg without the 3000 port. 

I found this little gem the other day to help me deal with that. It basically helps me to just add .dev behind any domain and it'll automatically be redirected back to 127.0.0.1; a real life-saver!


```
brew install dnsmasq

mkdir -pv $(brew --prefix)/etc/

echo 'address=/.dev/127.0.0.1' > $(brew --prefix)/etc/dnsmasq.conf

sudo cp -v $(brew --prefix 
dnsmasq)/homebrew.mxcl.dnsmasq.plist /Library/LaunchDaemons

sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist

sudo mkdir -v /etc/resolver

sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/dev'

```

