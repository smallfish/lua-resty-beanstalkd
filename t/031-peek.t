# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_BEANSTALKD_PORT} ||= 11300;

no_long_string();
no_shuffle();

run_tests();

__DATA__

=== TEST 1: peek
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local beanstalkd = require "resty.beanstalkd"

            local bean, err = beanstalkd:new()

            local ok, err = bean:connect("127.0.0.1", $TEST_NGINX_BEANSTALKD_PORT)
            if not ok then
                ngx.say("1: failed to connect: ", err)
                return
            end

            local ok, err = bean:use("hello-peek1")
            if not ok then
                ngx.say("2: failed to use:", err)
                return
            end

            local id, err = bean:put("hello")
            if not id then
                ngx.say("3: failed to put: ", err)
                return
            end

            local ok, err = bean:watch("hello-peek1")
            if not ok then
                ngx.say("4: failed to watch: ", err)
                return
            end

            local id, data = bean:reserve()
            if not id then
                ngx.say("3: failed to reserve: ", id)
                return
            else
                ngx.say("1: reserve: ", id)
                local id, data = bean:peek(id)
                if not id then
                    ngx.say("5: peek failed, id not found")
                    return
                else
                    ngx.say("2: peek: ", data)
                end
            end

            bean:close()
        ';
    }
--- request
GET /t
--- response_body_like chop
1: reserve: \d+
2: peek: hello
--- no_error_log
[error]



=== TEST 2: peek-buried
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local beanstalkd = require "resty.beanstalkd"

            local bean, err = beanstalkd:new()

            local ok, err = bean:connect("127.0.0.1", $TEST_NGINX_BEANSTALKD_PORT)
            if not ok then
                ngx.say("1: failed to connect: ", err)
                return
            end

            local ok, err = bean:use("hello-peek2")
            if not ok then
                ngx.say("2: failed to use tube: ", err)
                return
            end

            local id, err = bean:put("hello")
            if not id then
                ngx.say("3: failed to put: ", err)
                return
            end

            local ok, err = bean:watch("hello-peek2")
            if not ok then
                ngx.say("4: failed to watch: ", err)
                return
            end

            local id, data = bean:reserve()
            if not id then
                ngx.say("5: failed to reserve: ", err)
                return
            end

            local ok, err = bean:bury(id)
            if not ok then
                ngx.say("3: failed to bury: ", id)
                return
            else
                ngx.say("1: bury: ", id)
                local id, data = bean:peek_buried()
                if not id then
                    ngx.say("6: peek_buried failed, id not found ", id)
                    return
                else
                    ngx.say("4: peek_buried: ", data)
                end

                bean:delete(id)
            end

            bean:close()
        ';
    }
--- request
GET /t
--- response_body_like chop
1: bury: \d+
4: peek_buried: hello
--- no_error_log
[error]

=== TEST 3: peek-ready
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local beanstalkd = require "resty.beanstalkd"

            local bean, err = beanstalkd:new()

            local ok, err = bean:connect("127.0.0.1", $TEST_NGINX_BEANSTALKD_PORT)
            if not ok then
                ngx.say("1: failed to connect: ", err)
                return
            end

            -- use a seperate tube
            bean:use("test-peek-ready")
            local ok, err = bean:watch("test-peek-ready")
            if not ok then
                ngx.say("2: failed to watch: ", err)
                return
            else
                bean:ignore("default")
            end

            local id, err = bean:put("hello")
            if not id then
                ngx.say("2: failed to put: ", err)
                return
            end
            bean:put("world")

            local id, data = bean:peek_ready()
            if not id then
                ngx.say("3: peek_ready failed, id not found ", id)
                return
            else
                ngx.say("3: peek_ready: ", data)
            end
            id, data = bean:peek_ready()
            if not id then
                ngx.say("4: peek_ready failed, id not found ", id)
                return
            else
                ngx.say("4: peek_ready: ", data)
            end

            id, data = bean:reserve()
            if not id then
                ngx.say("5: failed to reserve: ", err)
                return
            else
                bean:delete(id)
            end
            id, data = bean:peek_ready()
            if not id then
                ngx.say("6: peek_ready failed, id not found ", id)
                return
            else
                ngx.say("6: peek_ready: ", data)
            end

            -- clean the tube
            id, data = bean:reserve()
            if not id then
                ngx.say("7: failed to reserve: ", err)
                return
            else
                bean:delete(id)
            end
            bean:close()
        ';
    }
--- request
GET /t
--- response_body_like chop
3: peek_ready: hello
4: peek_ready: hello
6: peek_ready: world
--- no_error_log
[error]

=== TEST 4: peek-delayed
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local beanstalkd = require "resty.beanstalkd"

            local bean, err = beanstalkd:new()

            local ok, err = bean:connect("127.0.0.1", $TEST_NGINX_BEANSTALKD_PORT)
            if not ok then
                ngx.say("1: failed to connect: ", err)
                return
            end

            local ok, err = bean:use("test-peek-delayed")
            if not ok then
                ngx.say("2: failed to use tube: ", err)
                return
            end
            bean:watch("test-peek-delayed")
            bean:ignore("default")

            local id, err = bean:put("hello")
            if not id then
                ngx.say("3: failed to put: ", err)
                return
            end

            local id, data = bean:reserve()
            if not id then
                ngx.say("3: failed to reserve: ", err)
                return
            end

            local ok, err = bean:release(id, 2 ^ 32, 100)
            if not ok then
                ngx.say("3: failed to delay ", id)
                return
            else
                ngx.say("1: bury: ", id)
                local id, data = bean:peek_delayed()
                if not id then
                    ngx.say("4: peek_delayed failed, id not found ", id)
                    return
                else
                    ngx.say("4: peek_delayed ", data)
                end

                bean:delete(id)
            end

            bean:close()
        ';
    }
--- request
GET /t
--- response_body_like chop
1: bury: \d+
4: peek_delayed hello
--- no_error_log
[error]
