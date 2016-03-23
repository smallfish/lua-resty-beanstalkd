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

=== TEST 1: stats_tube
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

            local res, err = bean:stats_tube("default")
            if not res then
                ngx.say("2: failed to stats: ", err)
                return
            end

            bean:close()

            ngx.say(res)
        ';
    }
--- request
GET /t
--- response_body_like chop
---
name: default
[\s\S]*
total-jobs: \d+
[\s\S]*
--- no_error_log
[error]


=== TEST 2: stats_tube not found
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

            local res, err = bean:stats_tube("_NOT_FOUND")
            if not res then
                ngx.say("2: failed to stats: ", err)
                return
            end

            bean:close()
        ';
    }
--- request
GET /t
--- response_body
2: failed to stats: NOT_FOUND
--- no_error_log
[error]


=== TEST 3: stats_tube invalid tube name
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

            local res, err = bean:stats_tube(nil)
            if not res then
                ngx.say("2: failed to stats: ", err)
                return
            end

            bean:close()
        ';
    }
--- request
GET /t
--- response_body
2: failed to stats: invalid tube name, please check your input
--- no_error_log
[error]



