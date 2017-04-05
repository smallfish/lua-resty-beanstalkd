Name
====

lua-resty-beanstalkd - non-blocking beanstalkd lib for ngx_lua.

[![Build Status](https://api.travis-ci.org/smallfish/lua-resty-beanstalkd.png)](https://travis-ci.org/smallfish/lua-resty-beanstalkd)


Status
======

This library is considered experimental and still under active development.

The API is still in flux and may change without notice.

Description
===========

This library requires an nginx, the [ngx_lua module](http://wiki.nginx.org/HttpLuaModule)

Commands
========

All beanstalkd commands are supported, following the name convention below:
* The command name is the method name, with `-` replaced by `_`.
* The arguments of such method are the arguments of corresponding command.
For instance, call `bean:stats_tube(tube)` is equal to send `stats-tube tube` to beanstalkd.

For more details, please see the below Synopsis section.

Synopsis
========

    lua_package_path "/path/to/lua-resty-beanstalkd/lib/?.lua;;";

    server {
        location /test {
            content_by_lua '

                local beanstalkd = require 'resty.beanstalkd'

                -- new and connect
                local bean, err = beanstalkd:new()
                if not bean then
                    ngx.say("failed to init beanstalkd:", err)
                    return
                end
                ngx.say("initialized ok")

                local ok, err = bean:connect()
                if not ok then
                    ngx.say("failed to connect beanstalkd:", err)
                    return
                end
                ngx.say("connect ok")

                -- use tube
                local ok, err = bean:use("smallfish")
                if not ok then
                    ngx.say("failed to use tube:", err)
                end
                ngx.say("use smallfish tube ok")

                -- put job
                local id, err = bean:put("hello")
                if not id then
                    ngx.say("failed to put hello to smallfish tube, error:", err)
                end
                ngx.say("put hello to smallfish tube, id:", id)

                -- watch tube
                local ok, err = bean:watch("smallfish")
                if not ok then
                    ngx.say("failed to watch tube smallfish, error:", err)
                    return
                end
                ngx.say("watch smallfish tube ok, tube size:", ok)

                -- reserve job,with optional timeout in seconds. reserve(timeout?)
                local id, data = bean:reserve()
                if not id then
                    ngx.say("reserve hello failed, error:", id, data)
                else
                    ngx.say("reserve hello ok, id:", id, "data:", data)
                end

                -- release job
                local ok, err = bean:release(id)
                if not ok then
                    ngx.say("failed to release, id:", id, " error:", err)
                else
                    ngx.say("release ok, id:", id)
                end

                local id, data = bean:reserve()
                if not id then
                    ngx.say("reserve hello failed, error:", id, data)
                else
                    ngx.say("reserve hello ok, id:", id, " data:", data)
                end

                -- peek job
                local id, data = bean:peek(id)
                if not id then
                    ngx.say("peek failed, id not found")
                else
                    ngx.say("peek ok, data:", data)
                end

                -- bury job
                local ok, err = bean:bury(id)
                if not ok then
                    ngx.say("bury failed, id:", id, " error:", err)
                else
                    ngx.say("bury ok, id:", id)
                end

                -- kick job
                local count, err = bean:kick(1)
                if not count then
                    ngx.say("kick failed, error:", err)
                else
                    ngx.say("kick ok, count:", count)
                end

                local id, data = bean:reserve()
                if not id then
                    ngx.say("reserve hello failed, error:", id, data)
                else
                    ngx.say("reserve hello ok, id:", id, " data:", data)
                end

                -- delete job
                local ok, err = bean:delete(id)
                if ok then
                    ngx.say("delete ok, id:", id)
                else
                    ngx.say("delete failed, id:", id, ok, err)
                end

                -- put it into the connection pool of size 100,
                -- with 0 idle timeout

                bean:set_keepalive(0, 100)

                -- close and quit beanstalkd
                -- bean:close()
           ';
        }
    }


Author
======

Chen "smallfish" Xiaoyu (陈小玉) <smallfish.xy@gmail.com>

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2012, by Chen "smallfish" Xiaoyu (陈小玉) <smallfish.xy@gmail.com>

Portions of the code are from [lua-resty-memcached](https://github.com/agentzh/lua-resty-memcached) Copyright (C) 2012, by Zhang "agentzh" Yichun (章亦春) <agentzh@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

See Also
========
* [ngx_lua module](http://wiki.nginx.org/HttpLuaModule)
* [beanstalkd protocol specification](https://github.com/kr/beanstalkd/blob/master/doc/protocol.txt)
* [lua-resty-memcached](https://github.com/agentzh/lua-resty-memcached)
* [lua-resty-redis](https://github.com/agentzh/lua-resty-redis)
* [lua-resty-mysql](https://github.com/agentzh/lua-resty-mysql)
