
**Example**

    lua_package_path "/path/to/lua-resty-beanstalkd/lib/?.lua;;";

    server {
        location /test {
            content_by_lua '
                local beanstalkd = require 'resty.beanstalkd'

                -- new and connect
                local beansd, err = beanstalkd:new()
                if not beansd then
                    ngx.say("failed to init beanstalkd:", err)
                    return
                end
                ngx.say("init ok")

                local ok, err = beansd:connect()
                if not ok then
                    ngx.say("failed to connect beanstalkd:", err)
                    return
                end
                ngx.say("connect ok")

                -- put message to default tube
                local ok, err = beansd:put("hello")
                if not ok then
                    ngx.say("failed to put hello:", err)
                    return
                end
                ngx.say("put ok:", ok)

                -- close
                beansd:close()
            ';
        }
    }
