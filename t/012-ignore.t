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

=== TEST 1: ignore
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

            local size, err = bean:watch("default")
            if not size then
                ngx.say("2: failed to watch tube: ", err)
                return
            end

            ngx.say("1: watching: ",  size)

            local size, err = bean:watch("test")
            if not size then
                ngx.say("2: failed to watch tube: ", err)
                return
            end

            ngx.say("2: watching: ",  size)

            local size, err = bean:ignore("default")
            if not size then
                ngx.say("3: failed to ignore tube: ", err)
                return
            end

            ngx.say("3: watching: ",  size)

            bean:close()
        ';
    }
--- request
GET /t
--- response_body_like chop
1: watching: \d+
2: watching: \d+
3: watching: \d+
--- no_error_log
[error]


=== TEST 2: handle ignore failure
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

            local size, err = bean:ignore("default")
            if not size then
                ngx.say("2: failed to ignore tube: ", err)
                return
            end

            ngx.say("watching: ",  size)

            bean:close()
        ';
    }
--- request
GET /t
--- response_body_like chop
2: failed to ignore tube: NOT_IGNORED
--- no_error_log
[error]

