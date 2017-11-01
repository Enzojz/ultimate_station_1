--[[
Copyright (c) 2017 "Enzojz" from www.transportfever.net
(https://www.transportfever.net/index.php/User/27218-Enzojz/)

Github repository:
https://github.com/Enzojz/transportfever

Anyone is free to use the program below, however the auther do not guarantee:
* The correctness of program
* The invariance of program in future
=====!!!PLEASE  R_E_N_A_M_E  BEFORE USE IN YOUR OWN PROJECT!!!=====

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including the right to distribute and without limitation the rights to use, copy and/or modify
the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--]]
local func = {}

func.pi = require "ustation/pipe"

function func.fold(ls, init, fun)
    return func.pi.fold(init, fun)(ls)
end

function func.forEach(ls, fun)
    func.pi.forEach(fun)(ls)
end

function func.map(ls, fun)
    return func.pi.map(fun)(ls)
end

function func.mapValues(ls, fun)
    return func.pi.mapValues(fun)(ls)
end

function func.mapPair(ls, fun)
    return func.pi.mapPair(fun)(ls)
end

function func.filter(ls, pre)
    return func.pi.filter(pre)(ls)
end

function func.concat(t1, t2)
    return func.pi.concat(t2)(t1)
end

function func.flatten(ls)
    return func.pi.flatten()(ls)
end

function func.mapFlatten(ls, fun)
    return func.pi.mapFlatten(fun)(ls)
end

function func.map2(ls1, ls2, fun)
    return func.pi.map2(ls2, fun)(ls1)
end

function func.range(ls, from, to)
    return func.pi.range(from, to)(ls)
end

function func.max(ls, less)
    return func.pi.max(less)(ls)
end

function func.min(ls, less)
    return func.pi.min(less)(ls)
end

function func.with(ls, newValues)
    local newValue = func.pi.with(newValues)(ls)
    setmetatable(newValue, getmetatable(ls) or nil)
    return newValue
end

function func.sort(ls, fn)
    return func.pi.sort(fn)(ls)
end

function func.rev(ls)
    return func.pi.rev()(ls)
end

function func.contains(ls, e)
    return func.pi.contains(e)(ls)
end

function func.seq(from, to)
    local result = {}
    for i = from, to do result[#result + 1] = i end
    return result
end

function func.zip(ls1, ls2, name)
    return func.pi.zip(ls2, name)(ls1)
end
function func.seqValue(n, value)
    return func.seqMap({1, n}, function(_) return value end)
end

function func.seqMap(range, fun)
    return func.map(func.seq(table.unpack(range)), fun)
end


function func.bind(fun, ...)
    local rest = {...}
    return function(...)
        local param = {...}
        local args = {}
        for i = 1, #rest do
            if (rest[i] == nil and #param > 0) then
                table.insert(args, table.remove(param, 1))
            else
                table.insert(args, rest[i])
            end
        end
        return fun(table.unpack(func.concat(args, param)))
    end
end


func.p = func.pi.new

func.nop = function(x) return x end
func.b = func.bind



return func
