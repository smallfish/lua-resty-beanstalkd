
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

                local ok, err = bean:connect()
                if not ok then
                    ngx.say("failed to connect beanstalkd:", err)
                    return
                end

                -- use tube
                local ok, err = bean:use("smallfish")
                if not ok then
                    ngx.say("failed to use tube:", err)
                    return
                end
                ngx.say("use tube ok:")

                -- put job
                local ok, err = bean:put("hello")
                if not ok then
                    ngx.say("failed to put hello:", err)
                    return
                end
                ngx.say("put ok, id:", ok)

                -- delete job
                local ok, err = bean:delete(10)
                if ok == nil then
                    ngx.say("failed to delete:", err)
                    return
                elseif ok == false then
                    ngx.say("failed to delete:", err)
                elseif ok then
                    ngx.say("delete ok")
                end

                local ok, err = bean:list_tubes()
                ngx.say("list_tubes:\r\n", ok)

                local ok, err = bean:stats_tube("smallfish")
                ngx.say("stats_tube:\r\n", ok)

                -- close
                bean:close()
           ';
        }
    }
