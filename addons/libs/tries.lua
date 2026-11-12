--[[
A library providing tries (prefix trees): values stored under sequences of keys.

A key is a sequence (a table or list, each element one step) or a string (each character one step, in the trie's
encoding). Any value but nil and NaN can be a step.

    local tries = require('tries')
    local t = tries.new()                       -- weak, ascii
    t:set('help', 1)
    t:get({'h', 'e', 'l', 'p'})                 -- 1 (a string is the sequence of its characters)
    t:get('hello', function(key) return #key end)  -- 5, stored on first use

tries.new([settings]), settings a table with any of:
    weak        true (default): steps that are tables, functions or userdata don't keep their paths alive.
                false: the trie holds every step.
    encoding    A string.encoding (default ascii): how string keys are split into characters.

    tries.new{weak = false, encoding = string.encoding.utf8}

A weak trie can't collect a path whose value refers back to one of the path's own steps (Lua 5.1 has no ephemerons).
]]

_libs = _libs or {}

require('lists')
require('strings')

local tries = {}

_libs.tries = tries

_meta = _meta or {}
_meta.Trie = {}
_meta.Trie.__index = tries
_meta.Trie.__class = 'Trie'

-- Private keys of a node: its value, and the string it was stored from (so iteration can hand strings back).
local VALUE = {}
local STRING = {}

local weak_keys = {__mode = 'k'}

local function new_node(trie)
    return trie.weak and setmetatable({}, weak_keys) or {}
end

function tries.new(settings)
    settings = settings or {}
    local trie = {
        weak = settings.weak ~= false,
        encoding = settings.encoding or string.encoding.ascii,
    }
    trie.root = new_node(trie)
    return setmetatable(trie, _meta.Trie)
end

-- The node at the end of keys' path, created on the way if create, else nil when the path doesn't exist. Plain loops:
-- this runs on every lookup.
local function find(trie, keys, create)
    local node = trie.root
    if type(keys) == 'string' then
        for step in keys:it(trie.encoding) do
            local child = node[step]
            if child == nil then
                if not create then
                    return nil
                end
                child = new_node(trie)
                node[step] = child
            end
            node = child
        end
        return node
    end
    for i = 1, #keys do
        local step = keys[i]
        local child = node[step]
        if child == nil then
            if not create then
                return nil
            end
            child = new_node(trie)
            node[step] = child
        end
        node = child
    end
    return node
end

local function store(node, keys, value)
    node[VALUE] = value
    node[STRING] = type(keys) == 'string' and keys or nil
end

-- The value stored under keys. With make, a missing value is made by make(keys), stored and returned.
function tries.get(trie, keys, make)
    local node = find(trie, keys, make ~= nil)
    if not node then
        return nil
    end
    local value = node[VALUE]
    if value ~= nil or not make then
        return value
    end
    value = make(keys)
    if value ~= nil then
        store(node, keys, value)
    end
    return value
end

-- Stores value under keys (nil removes it). Returns the trie.
function tries.set(trie, keys, value)
    if value == nil then
        trie:remove(keys)
        return trie
    end
    store(find(trie, keys, true), keys, value)
    return trie
end

function tries.has(trie, keys)
    return trie:get(keys) ~= nil
end

-- Removes the value under keys and returns it, dropping the nodes that are left empty.
function tries.remove(trie, keys)
    local nodes, steps = {trie.root}, {}
    if type(keys) == 'string' then
        for step in keys:it(trie.encoding) do
            steps[#steps + 1] = step
        end
    else
        for i = 1, #keys do
            steps[i] = keys[i]
        end
    end
    for i, step in ipairs(steps) do
        local child = nodes[i][step]
        if child == nil then
            return nil
        end
        nodes[i + 1] = child
    end

    local node = nodes[#nodes]
    local value = node[VALUE]
    node[VALUE], node[STRING] = nil, nil
    for i = #steps, 1, -1 do
        if next(nodes[i + 1]) ~= nil then
            break
        end
        nodes[i][steps[i]] = nil
    end
    return value
end

function tries.clear(trie)
    trie.root = new_node(trie)
    return trie
end

-- The value under the longest prefix of keys that has one, and that prefix (a string for a string key, else a list).
function tries.longest(trie, keys)
    local node = trie.root
    local value, length = node[VALUE], 0
    if type(keys) == 'string' then
        local bytes = 0
        for step in keys:it(trie.encoding) do
            node = node[step]
            if node == nil then
                break
            end
            bytes = bytes + #step
            if node[VALUE] ~= nil then
                value, length = node[VALUE], bytes
            end
        end
        return value, value ~= nil and keys:sub(1, length) or nil
    end
    for i = 1, #keys do
        node = node[keys[i]]
        if node == nil then
            break
        end
        if node[VALUE] ~= nil then
            value, length = node[VALUE], i
        end
    end
    return value, value ~= nil and L{unpack(keys, 1, length)} or nil
end

-- Iterates every value (under prefix, if given) as value, key. The key is the string it was stored from, else a list
-- of its steps. The order is unspecified.
function tries.it(trie, prefix)
    local start = prefix and find(trie, prefix, false)
    if prefix and not start then
        return function() end
    end

    local path = L{}
    if type(prefix) == 'string' then
        for step in prefix:it(trie.encoding) do
            path:append(step)
        end
    elseif prefix then
        for i = 1, #prefix do
            path:append(prefix[i])
        end
    end

    local function walk(node)
        if node[VALUE] ~= nil then
            coroutine.yield(node[VALUE], node[STRING] or path:copy(false))
        end
        for step, child in pairs(node) do
            if step ~= VALUE and step ~= STRING then
                path:append(step)
                walk(child)
                path:remove()
            end
        end
    end

    return coroutine.wrap(function() walk(start or trie.root) end)
end

return tries

--[[
Copyright © 2026, Windower
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of Windower nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Windower BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
