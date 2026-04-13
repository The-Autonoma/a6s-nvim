-- A6s WebSocket client for Neovim
-- Connects to the local A6s CLI daemon at ws://localhost:{port}/ws
-- Pure Lua (libuv/vim.loop) implementation — no external deps beyond plenary.

local uv = vim.loop
local bit = require("bit")

local M = {}

-- ============================================================================
-- Configuration & State
-- ============================================================================

M.config = {
  port = 9876,
  host = "127.0.0.1",
  path = "/ws",
  connect_timeout_ms = 5000,
  request_timeout_ms = 30000,
  max_reconnect_attempts = 5,
  initial_backoff_ms = 1000,
  max_backoff_ms = 16000,
}

local state = {
  tcp = nil,
  connected = false,
  handshake_complete = false,
  recv_buffer = "",
  next_id = 0,
  pending = {}, -- id -> { resolve, reject, timer }
  event_handlers = {}, -- event_name -> { handler, ... }
  reconnect_attempts = 0,
  reconnect_timer = nil,
  connect_timer = nil,
  auto_reconnect = true,
  handshake_key = nil,
}

-- ============================================================================
-- Utilities
-- ============================================================================

local function log_debug(msg)
  if vim.g.a6s_debug then
    vim.schedule(function()
      vim.notify("[a6s] " .. msg, vim.log.levels.DEBUG)
    end)
  end
end

local function b64encode(data)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  return ((data:gsub(".", function(x)
    local r, v = "", x:byte()
    for i = 8, 1, -1 do r = r .. (v % 2 ^ i - v % 2 ^ (i - 1) > 0 and "1" or "0") end
    return r
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
    if #x < 6 then return "" end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
    return b:sub(c + 1, c + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

local function random_bytes(n)
  local out = {}
  math.randomseed(os.time() + (uv.hrtime() % 1e6))
  for _ = 1, n do
    table.insert(out, string.char(math.random(0, 255)))
  end
  return table.concat(out)
end

-- ============================================================================
-- WebSocket Frame Encoding/Decoding (RFC 6455)
-- ============================================================================

-- Encode a text frame (client->server, MUST be masked per RFC 6455)
local function encode_frame(payload)
  local fin_opcode = string.char(0x81) -- FIN=1, opcode=text
  local mask_bit = 0x80
  local len = #payload
  local header

  if len < 126 then
    header = fin_opcode .. string.char(bit.bor(mask_bit, len))
  elseif len < 65536 then
    header = fin_opcode
      .. string.char(bit.bor(mask_bit, 126))
      .. string.char(bit.band(bit.rshift(len, 8), 0xFF))
      .. string.char(bit.band(len, 0xFF))
  else
    local hi = math.floor(len / 0x100000000)
    local lo = len % 0x100000000
    header = fin_opcode
      .. string.char(bit.bor(mask_bit, 127))
      .. string.char(bit.band(bit.rshift(hi, 24), 0xFF))
      .. string.char(bit.band(bit.rshift(hi, 16), 0xFF))
      .. string.char(bit.band(bit.rshift(hi, 8), 0xFF))
      .. string.char(bit.band(hi, 0xFF))
      .. string.char(bit.band(bit.rshift(lo, 24), 0xFF))
      .. string.char(bit.band(bit.rshift(lo, 16), 0xFF))
      .. string.char(bit.band(bit.rshift(lo, 8), 0xFF))
      .. string.char(bit.band(lo, 0xFF))
  end

  local mask = random_bytes(4)
  local masked = {}
  for i = 1, #payload do
    local m = mask:byte(((i - 1) % 4) + 1)
    masked[i] = string.char(bit.bxor(payload:byte(i), m))
  end

  return header .. mask .. table.concat(masked)
end

-- Decode frames from buffer; returns list of { opcode, payload } and remaining buffer
local function decode_frames(buffer)
  local frames = {}
  local pos = 1
  while pos <= #buffer do
    if #buffer - pos + 1 < 2 then break end

    local b1 = buffer:byte(pos)
    local b2 = buffer:byte(pos + 1)
    local fin = bit.band(b1, 0x80) ~= 0
    local opcode = bit.band(b1, 0x0F)
    local masked = bit.band(b2, 0x80) ~= 0
    local len = bit.band(b2, 0x7F)
    local header_len = 2

    if len == 126 then
      if #buffer - pos + 1 < 4 then break end
      len = bit.lshift(buffer:byte(pos + 2), 8) + buffer:byte(pos + 3)
      header_len = 4
    elseif len == 127 then
      if #buffer - pos + 1 < 10 then break end
      len = 0
      for i = 0, 7 do
        len = len * 256 + buffer:byte(pos + 2 + i)
      end
      header_len = 10
    end

    local mask_key = ""
    if masked then
      if #buffer - pos + 1 < header_len + 4 then break end
      mask_key = buffer:sub(pos + header_len, pos + header_len + 3)
      header_len = header_len + 4
    end

    if #buffer - pos + 1 < header_len + len then break end

    local payload = buffer:sub(pos + header_len, pos + header_len + len - 1)
    if masked and #mask_key == 4 then
      local unmasked = {}
      for i = 1, #payload do
        local m = mask_key:byte(((i - 1) % 4) + 1)
        unmasked[i] = string.char(bit.bxor(payload:byte(i), m))
      end
      payload = table.concat(unmasked)
    end

    table.insert(frames, { opcode = opcode, payload = payload, fin = fin })
    pos = pos + header_len + len
  end
  return frames, buffer:sub(pos)
end

-- ============================================================================
-- Event dispatch
-- ============================================================================

function M.on(event, handler)
  if not state.event_handlers[event] then
    state.event_handlers[event] = {}
  end
  table.insert(state.event_handlers[event], handler)
end

function M.off(event, handler)
  local handlers = state.event_handlers[event]
  if not handlers then return end
  for i, h in ipairs(handlers) do
    if h == handler then
      table.remove(handlers, i)
      return
    end
  end
end

local function emit(event, data)
  local handlers = state.event_handlers[event]
  if not handlers then return end
  for _, h in ipairs(handlers) do
    vim.schedule(function()
      local ok, err = pcall(h, data)
      if not ok then
        log_debug("handler error for " .. event .. ": " .. tostring(err))
      end
    end)
  end
end

-- ============================================================================
-- Message handling
-- ============================================================================

local function handle_message(msg)
  local ok, decoded = pcall(vim.json.decode, msg)
  if not ok or type(decoded) ~= "table" then
    log_debug("invalid JSON: " .. tostring(msg))
    return
  end

  -- Response to pending request
  if decoded.id and state.pending[decoded.id] then
    local p = state.pending[decoded.id]
    state.pending[decoded.id] = nil
    if p.timer then p.timer:stop(); p.timer:close() end
    if decoded.error then
      p.reject(decoded.error)
    else
      p.resolve(decoded.result)
    end
    return
  end

  -- Event
  if decoded.type then
    emit(decoded.type, decoded.data or decoded)
  end
end

-- ============================================================================
-- Connection lifecycle
-- ============================================================================

local function cleanup_connection()
  if state.connect_timer then
    state.connect_timer:stop()
    state.connect_timer:close()
    state.connect_timer = nil
  end
  if state.tcp and not state.tcp:is_closing() then
    state.tcp:close()
  end
  state.tcp = nil
  state.connected = false
  state.handshake_complete = false
  state.recv_buffer = ""
  -- Reject pending requests
  for id, p in pairs(state.pending) do
    if p.timer then p.timer:stop(); p.timer:close() end
    p.reject("connection closed")
    state.pending[id] = nil
  end
end

local function do_reconnect()
  if not state.auto_reconnect then return end
  if state.reconnect_attempts >= M.config.max_reconnect_attempts then
    emit("reconnect_failed", { attempts = state.reconnect_attempts })
    return
  end
  state.reconnect_attempts = state.reconnect_attempts + 1
  local backoff = math.min(
    M.config.initial_backoff_ms * (2 ^ (state.reconnect_attempts - 1)),
    M.config.max_backoff_ms
  )
  log_debug("reconnecting in " .. backoff .. "ms (attempt " .. state.reconnect_attempts .. ")")
  state.reconnect_timer = uv.new_timer()
  state.reconnect_timer:start(backoff, 0, function()
    state.reconnect_timer:close()
    state.reconnect_timer = nil
    M.connect()
  end)
end

local function parse_handshake_response(data)
  -- Look for "\r\n\r\n" end of headers
  local headers_end = data:find("\r\n\r\n", 1, true)
  if not headers_end then return nil, data end

  local headers = data:sub(1, headers_end - 1)
  local remainder = data:sub(headers_end + 4)

  local status_line = headers:match("^([^\r\n]+)")
  if not status_line or not status_line:match("^HTTP/1%.1 101") then
    return false, nil
  end
  return true, remainder
end

function M.connect(on_ready)
  if state.connected then
    if on_ready then vim.schedule(on_ready) end
    return
  end

  cleanup_connection()
  state.auto_reconnect = true

  local tcp = uv.new_tcp()
  state.tcp = tcp

  -- Connect timeout
  state.connect_timer = uv.new_timer()
  state.connect_timer:start(M.config.connect_timeout_ms, 0, function()
    if not state.handshake_complete then
      log_debug("connect timeout")
      cleanup_connection()
      emit("disconnected", { reason = "timeout" })
      do_reconnect()
    end
  end)

  tcp:connect(M.config.host, M.config.port, function(err)
    if err then
      log_debug("tcp connect err: " .. tostring(err))
      vim.schedule(function()
        cleanup_connection()
        emit("disconnected", { reason = "connect_failed", error = err })
        do_reconnect()
      end)
      return
    end

    -- Send WebSocket handshake
    state.handshake_key = b64encode(random_bytes(16))
    local req = table.concat({
      "GET " .. M.config.path .. " HTTP/1.1",
      "Host: " .. M.config.host .. ":" .. M.config.port,
      "Upgrade: websocket",
      "Connection: Upgrade",
      "Sec-WebSocket-Key: " .. state.handshake_key,
      "Sec-WebSocket-Version: 13",
      "",
      "",
    }, "\r\n")

    tcp:write(req)

    tcp:read_start(function(rerr, chunk)
      if rerr then
        vim.schedule(function()
          cleanup_connection()
          emit("disconnected", { reason = "read_error", error = rerr })
          do_reconnect()
        end)
        return
      end
      if not chunk then
        vim.schedule(function()
          cleanup_connection()
          emit("disconnected", { reason = "eof" })
          do_reconnect()
        end)
        return
      end

      state.recv_buffer = state.recv_buffer .. chunk

      if not state.handshake_complete then
        local ok, remainder = parse_handshake_response(state.recv_buffer)
        if ok == nil then return end -- incomplete
        if ok == false then
          vim.schedule(function()
            cleanup_connection()
            emit("disconnected", { reason = "handshake_failed" })
          end)
          return
        end
        state.handshake_complete = true
        state.connected = true
        state.reconnect_attempts = 0
        state.recv_buffer = remainder
        if state.connect_timer then
          state.connect_timer:stop()
          state.connect_timer:close()
          state.connect_timer = nil
        end
        emit("connected", {})
        if on_ready then vim.schedule(on_ready) end
      end

      -- Decode frames
      local frames, rest = decode_frames(state.recv_buffer)
      state.recv_buffer = rest
      for _, f in ipairs(frames) do
        if f.opcode == 0x1 or f.opcode == 0x2 then
          vim.schedule(function() handle_message(f.payload) end)
        elseif f.opcode == 0x8 then -- close
          vim.schedule(function()
            cleanup_connection()
            emit("disconnected", { reason = "close_frame" })
            do_reconnect()
          end)
        elseif f.opcode == 0x9 then -- ping
          if state.tcp and not state.tcp:is_closing() then
            -- Send pong with same payload
            local pong = string.char(0x8A, bit.bor(0x80, #f.payload)) .. random_bytes(4) .. f.payload
            state.tcp:write(pong)
          end
        end
      end
    end)
  end)
end

function M.disconnect()
  state.auto_reconnect = false
  if state.reconnect_timer then
    state.reconnect_timer:stop()
    state.reconnect_timer:close()
    state.reconnect_timer = nil
  end
  if state.tcp and not state.tcp:is_closing() then
    -- Send close frame
    local close_frame = string.char(0x88, 0x80) .. random_bytes(4)
    pcall(function() state.tcp:write(close_frame) end)
  end
  cleanup_connection()
  emit("disconnected", { reason = "user_disconnect" })
end

function M.is_connected()
  return state.connected
end

function M.reset_state()
  -- Testing helper
  cleanup_connection()
  state.reconnect_attempts = 0
  state.event_handlers = {}
  state.next_id = 0
end

-- ============================================================================
-- Request/response
-- ============================================================================

local function request(method, params, callback)
  if not state.connected then
    vim.schedule(function() callback(nil, "not connected") end)
    return
  end

  state.next_id = state.next_id + 1
  local id = "req_" .. state.next_id
  local msg = vim.json.encode({ id = id, method = method, params = params or vim.empty_dict() })

  local timer = uv.new_timer()
  timer:start(M.config.request_timeout_ms, 0, function()
    if state.pending[id] then
      state.pending[id] = nil
      timer:stop(); timer:close()
      vim.schedule(function() callback(nil, "request timeout") end)
    end
  end)

  state.pending[id] = {
    resolve = function(result) callback(result, nil) end,
    reject = function(err) callback(nil, err) end,
    timer = timer,
  }

  local frame = encode_frame(msg)
  state.tcp:write(frame, function(err)
    if err then
      state.pending[id] = nil
      timer:stop(); timer:close()
      vim.schedule(function() callback(nil, "write failed: " .. tostring(err)) end)
    end
  end)
end

M._request = request -- exposed for testing

-- ============================================================================
-- Protocol methods (all 13)
-- ============================================================================

function M.list_agents(cb) request("agents.list", {}, cb) end

function M.invoke_agent(agent_type, task, context, cb)
  request("agents.invoke", { agentType = agent_type, task = task, context = context }, cb)
end

function M.execution_status(execution_id, cb)
  request("execution.status", { executionId = execution_id }, cb)
end

function M.list_background_tasks(cb) request("background.list", {}, cb) end

function M.launch_background_task(task, agent_type, cb)
  request("background.launch", { task = task, agentType = agent_type }, cb)
end

function M.cancel_background_task(task_id, cb)
  request("background.cancel", { taskId = task_id }, cb)
end

function M.get_task_output(task_id, cb)
  request("background.output", { taskId = task_id }, cb)
end

function M.preview_artifacts(artifacts, cb)
  request("artifacts.preview", { artifacts = artifacts }, cb)
end

function M.apply_artifacts(artifacts, cb)
  request("artifacts.apply", { artifacts = artifacts }, cb)
end

function M.explain_code(code, language, file_path, cb)
  request("code.explain", { code = code, language = language, filePath = file_path }, cb)
end

function M.refactor_code(code, language, file_path, instructions, cb)
  request("code.refactor", {
    code = code, language = language, filePath = file_path, instructions = instructions,
  }, cb)
end

function M.generate_tests(code, language, file_path, cb)
  request("code.generateTests", { code = code, language = language, filePath = file_path }, cb)
end

function M.review_code(code, language, file_path, review_type, cb)
  request("code.review", {
    code = code, language = language, filePath = file_path, reviewType = review_type or "all",
  }, cb)
end

-- ============================================================================
-- Setup
-- ============================================================================

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_extend("force", M.config, opts)
end

-- Expose internal encoders/decoders for testing
M._encode_frame = encode_frame
M._decode_frames = decode_frames
M._b64encode = b64encode

return M
