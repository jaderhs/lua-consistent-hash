lua-consistent-hash
===================

A reimplementation of consistent hash in lua based on yaoweibin's fork of consistent hash (https://github.com/yaoweibin/ngx_http_consistent_hash)

Usage
-----

```lua
chash = require "chash"
chash.add_upstream("192.168.0.251")
chash.add_upstream("192.168.0.252")
chash.add_upstream("192.168.0.253")

chash.get_upstream("my_hash_key")
```