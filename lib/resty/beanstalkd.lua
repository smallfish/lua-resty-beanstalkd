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

function use(self, tube)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"use", " ", tube, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to use tube:" .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to use tube:" .. err
    end
    return line
end

function put(self, body, pri, delay, ttr)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    pri   = pri or 2 ^ 32
    delay = delay or 0
    ttr   = ttr or 120
    local cmd = {"put", " ", pri, " ", delay, " ", ttr, " ", strlen(body), "\r\n", body, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to put:" .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to put:" .. err
    end
    local id = strmatch(line, "^INSERTED (%d+)$")
    if id then
        return id, line
    end
    local id = strmatch(line, "^BURIED (%d+)$")
    if id then
        return id, line
    end
    return nil, line
end

function delete(self, id)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"delete", " ", id, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to delete:" .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to delete:" .. err
    end
    if line == "DELETED" then
        return true, line
    end
    return false, line
end

function list_tubes(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local bytes, err = sock:send("list-tubes\r\n")
    if not bytes then
        return nil, "failed to list-tubes:" .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to list-tubes:" .. err
    end
    local size = strmatch(line, "^OK (%d+)$")
    if not size then
        return nil, "failed to list-tubes:" .. err
    end
    local line, err = sock:receive(size)
    if not line then
        return nil, "failed to list-tubes:" .. err
    end
    return line, nil
end

function stats_tube(self, name)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"stats-tube", " ", name, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to stats-tube:" .. err
    end
    local line, err = sock:receive()
    local line, err = sock:receive()
    if not line then
        return nil, "failed to stats-tube:" .. err
    end
    local size = strmatch(line, "^OK (%d+)$")
    if size then
        local line, err = sock:receive(size)
        return line, nil
    end
    return line, nil
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
