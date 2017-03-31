-- Copyright (C) 2012 Chen "smallfish" Xiaoyu (陈小玉)

local tcp       = ngx.socket.tcp
local strlen    = string.len
local strsub    = string.sub
local strmatch  = string.match
local tabconcat = table.concat

local _M = {}

_M.VERSION = "0.0.5"

local mt = {
    __index = _M,
    -- to prevent use of casual module global variables
    __newindex = function(table, key, val)
        error('attempt to write to undeclared variable "' .. key .. '"')
    end,
}

function _M.new(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end
    return setmetatable({sock = sock}, mt)
end

function _M.set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    return sock:settimeout(timeout)
end

function _M.set_keepalive(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    return sock:setkeepalive(...)
end

function _M.getreusedtimes(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    return sock:getreusedtimes()
end

function _M.connect(self, host, port, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    host = host or "127.0.0.1"
    port = port or 11300
    return sock:connect(host, port, ...)
end

function _M.use(self, tube)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"use", " ", tube, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to use tube, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to use tube, receive data error: " .. err
    end
    return line
end

function _M.watch(self, tube)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"watch", " ", tube, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to watch tube, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to watch tube, receive data error: " .. err
    end
    local size = strmatch(line, "^WATCHING (%d+)$")
    if size then
        return size, line
    end
    return nil, line
end

function _M.ignore(self, tube)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"ignore", " ", tube, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to ignore tube, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to ignore tube, receive data error: " .. err
    end
    local size = strmatch(line, "^WATCHING (%d+)$")
    if size then
        return size, line
    end
    return nil, line
end

function _M.put(self, body, pri, delay, ttr)
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
        return nil, "failed to put, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to put, receive data error:" .. err
    end
    local id = strmatch(line, " (%d+)$")
    if id then
        return id, line
    end
    return nil, line
end

function _M.delete(self, id)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"delete", " ", id, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to delete, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to delete, receive data error: " .. err
    end
    if line == "DELETED" then
        return true, line
    end
    return false, line
end

function _M.reserve(self, timeout)
    --Reserve a job from one of the watched tubes, with optional timeout in seconds.
    local sock = self.sock
    local cmd = {"reserve", "\r\n"}
    if timeout then
        cmd = {"reserve-with-timeout", " ", timeout, "\r\n"}
    end
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to reserve, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to reserve, receive data error: " .. err
    end
    local id, size = strmatch(line, "^RESERVED (%d+) (%d+)$")
    if id and size then -- remove \r\n
        local data, err = sock:receive(size+2)
        return id, strsub(data, 1, -3)
    end
    return false, line
end

function _M.release(self, id, pri, delay)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    pri = pri or 2 ^ 32
    delay = delay or 0
    local cmd = {"release", " ", id, " ", pri, " ", delay, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to release, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to release, receive data error: " .. err
    end
    if line == "RELEASED" then
        return true, line
    end
    return false, line
end

function _M.bury(self, id, pri)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    pri = pri or 2 ^ 32
    local cmd = {"bury", " ", id, " ", pri, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to release, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to release, receive data error: " .. err
    end
    if line == "BURIED" then
        return true, line
    end
    return false, line
end

function _M.kick(self, bound)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"kick", " ", bound, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to release, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to release, receive data error: " .. err
    end
    local count = strmatch(line, "^KICKED (%d+)$")
    return count, nil
end

function _M.kick_job(self, id)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"kick-job", " ", id, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to release, send data error: " .. err
    end
    local line
    line, err = sock:receive()
    if not line then
        return nil, "failed to release, receive data error: " .. err
    end
    if line == "KICKED" then
        return true, nil
    end
    return false, line
end

function _M.touch(self, id)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local cmd = {"touch", " ", id, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to release, send data error: " .. err
    end
    local line
    line, err = sock:receive()
    if not line then
        return nil, "failed to release, receive data error: " .. err
    end
    if line == 'TOUCHED' then
        return true, nil
    end
    return false, line
end

function _M.pause_tube(self, tube, delay)
    if not tube then
        return nil, "invalid tube name, please check your input"
    end
    -- beanstalkd will increase delay 0 to 1
    if not delay or delay < 0 then
        return nil, "invalid delay, please check your input"
    end
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local cmd = {"pause-tube", " ", tube, " ", delay, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to pause-tube, send data error: " .. err
    end
    local line
    line, err = sock:receive()
    if not line then
        return nil, "failed to pause-tube, receive data error: " .. err
    end
    if line == 'PAUSED' then
        return true, nil
    end
    return false, line
end

function _M.peek(self, id)
    local sock = self.sock
    local cmd = {"peek", " ", id, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to peek, send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to peek, receive data error: " .. err
    end
    local id, size = strmatch(line, "^FOUND (%d+) (%d+)$")
    if id and size then -- remove \r\n
        local data, err = sock:receive(size+2)
        return id, strsub(data, 1, -3)
    end
    return false, line
end


local function _peek_job_type(self, job_type)
    local sock = self.sock
    local cmd = {job_type, "\r\n"}
    local bytes, err = sock:send(tabconcat(cmd))
    if not bytes then
        return nil, "failed to " .. job_type .. ", send data error: " .. err
    end
    local line, err = sock:receive()
    if not line then
        return nil, "failed to " .. job_type .. ", receive data error: " .. err
    end
    local id, size = strmatch(line, "^FOUND (%d+) (%d+)$")
    if id and size then -- remove \r\n
        local data, err = sock:receive(size+2)
        if err then
            return nil, "failed to " .. job_type .. ", receive job body error: " .. err
        end
        return id, strsub(data, 1, -3)
    end
    return false, line
end

function _M.peek_buried(self)
    return _peek_job_type(self, "peek-buried")
end


function _M.peek_ready(self)
    return _peek_job_type(self, "peek-ready")
end


function _M.peek_delayed(self)
    return _peek_job_type(self, "peek-delayed")
end


function _M.close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    sock:send("quit\r\n")
    return sock:close()
end
_M.quit = _M.close


local function  _manager_command(self, ...)
    local sock = self.sock

    local bytes, err = sock:send(tabconcat({...}, " ") .. "\r\n")
    if not bytes then
        return nil, err
    end

    local line, err = sock:receive()
    if not line then
        return nil, err
    end

    local size = strmatch(line, "^OK (%d+)$")
    if not size then
        return nil, line
    end

    return sock:receive(size+2)
end

function _M.stats(self)
    return _manager_command(self, "stats")
end


function _M.list_tubes(self)
    return _manager_command(self, "list-tubes")
end

function _M.list_tube_used(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    local bytes, err = sock:send("list-tube-used\r\n")
    if not bytes then
        return nil, "failed to list tube used, send data error: " .. err
    end
    local line
    line, err = sock:receive()
    if not line then
        return nil, "failed to list tube used, receive data error: " .. err
    end
    local tube = strmatch(line, "^USING (.+)$")
    if not tube then
        return nil, line
    end
    return tube, nil
end

function _M.list_tubes_watched(self)
    return _manager_command(self, "list-tubes-watched")
end

function _M.stats_job(self, id)
    return _manager_command(self, "stats-job", id)
end

function _M.stats_tube(self, tube)
    if not tube then
        return nil, "invalid tube name, please check your input"
    end

    return _manager_command(self, "stats-tube", tube)
end


return _M
