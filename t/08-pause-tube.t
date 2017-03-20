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

=== TEST 1: reserve
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local beanstalkd = require "resty.beanstalkd"

            local bean, err = beanstalkd:new()

            local ok, err = bean:connect("127.0.0.1", $TEST_NGINX_BEANSTALKD_PORT)
            if not ok then
                ngx.say("1: failed to connect: ", err)
                return
            end

            ok, err = bean:pause_tube(nil, 15)
            if ok or err ~= "invalid tube name, please check your input" then
                ngx.say("2: failed to pause_tube: ", err)
                return
            end

            ok, err = bean:pause_tube("default")
            if ok or err ~= "invalid delay, please check your input" then
                ngx.say("3: failed to pause_tube: ", err)
                return
            end

            ok, err = bean:pause_tube("null", 15)
            if ok or err ~= "NOT_FOUND" then
                ngx.say("4: failed to pause_tube: ", err)
                return
            end

            ok, err = bean:pause_tube("default", 15)
            if not ok then
                ngx.say("5: failed to pause_tube: ", err)
                return
            end

            local stats, err = bean:stats_tube("default")
            if not stats then
                ngx.say("6: failed to stats tube: ", err)
                return
            end
            ngx.say(stats)
            bean:close()
        }
    }
--- request
GET /t
--- response_body_like chop
pause-time-left: \d\d
--- no_error_log
[error]

