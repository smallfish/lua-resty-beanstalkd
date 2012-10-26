-- Copyright (C) 2012 Chen "smallfish" Xiaoyu (陈小玉)

module("resty.beanstalkd", package.seeall)

_VERSION = "0.01"

local tcp       = ngx.socket.tcp
local strlen    = string.len
local strmatch  = string.match
local tabconcat = table.concat

local class = resty.beanstalkd
local mt    = {__index = class}

function new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end

    return setmetatable({sock = sock}, mt)
end

function set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(timeout)
end

function connect(self, host, port, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    host = host or "127.0.0.1"
    port = port or 11300

    return sock:connect(host, port, ...)
end

function put(self, body, priority, delay, ttr)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    priority = priority or 2 ^ 31
    delay    = delay or 0
    ttr      = ttr or 120

    local cmd = {"put", " ", priority, " ", delay, " ", ttr, " ", strlen(body), "\r\n", body, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to send command:" .. err
    end

    local line, err = sock:receive()
    if not line then
        return nil, "failed to receive line:" .. err
    end

    local id = strmatch(line, "^INSERTED (%d+)$")
    if not id then
        return nil, "failed to get insert id"
    end

    return id, nil
end

function close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:close()
end

-- to prevent use of casual module global variables
getmetatable(class).__newindex = function (table, key, val)
    error("attempt to write to undeclared variable " .. key .. "")
end
