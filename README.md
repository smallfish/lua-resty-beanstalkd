
**Example**

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

                -- reserve job
                local id, data = bean:reserve(2)
                if not id then
                    ngx.say("reserve hello failed, error:", id, data)
                else
                    ngx.say("reserve hello ok, id:", id, "data:", data)
                end

                -- delete job
                local ok, err = bean:delete(id)
                if ok then
                    ngx.say("delete ok, id:", id)
                else
                    ngx.say("delete failed, error:", ok, err)
                end

                -- close
                bean:close()
           ';
        }
    }
