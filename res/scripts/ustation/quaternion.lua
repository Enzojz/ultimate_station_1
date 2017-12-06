--[[
Copyright (c) 2016 "Enzojz" from www.transportfever.net
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
local laneutil = require "laneutil"
local func = require "ustation/func"
local coor = require "ustation/coor"
local q = {}

local dump = require "datadumper"

local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local rad = math.rad

local qLength = function(self) return sqrt(self:length2()) end
local qLength2 = function(self) return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w end
local qNormalized = function(self) return self / self:length() end
local qMRot = function(q)
    return coor.I() * {
        1 - 2 * q.y * q.y - 2 * q.z * q.z,     2 * q.x * q.y + 2 * q.w * q.z,     2 * q.x * q.z - 2 * q.w * q.y,     0,
        2 * q.x * q.y - 2 * q.w * q.z,         1 - 2 * q.x * q.x - 2 * q.z * q.z, 2 * q.y * q.z + 2 * q.w * q.x,     0,
        2 * q.x * q.z + 2 * q.w * q.y,         2 * q.y * q.z - 2 * q.w * q.x,     1 - 2 * q.x * q.x - 2* q.y * q.y,  0,
        0,                                     0,                                 0,                                 1
    }
end

local qMeta = {
    __add = function(lhs, rhs)
        return q.wxyz(lhs.w + rhs.w, lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    end
    ,
    __sub = function(lhs, rhs)
        return q.wxyz(lhs.w - rhs.w, lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    end,
    __mul = function(lhs, rhs)
        return q.wxyz(lhs.w * rhs, lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    end,
    __div = function(lhs, rhs)
        return q.wxyz(lhs.w / rhs, lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    end,
    __unm = function(lhs)
        return q.wxyz(-lhs.w, -lhs.x, -lhs.y, -lhs.z)
    end
}

function q.wxyz(w, x, y, z)
    local result = {
        w = w,
        x = x,
        y = y,
        z = z,
        length = qLength,
        length2 = qLength2,
        normalized = qNormalized,
        mRot = qMRot
    }
    setmetatable(result, qMeta)
    return result
end

function q.xyzw(pt, w)
    return q.wxyz(w, pt.x, pt.y, pt.z)
end

function q.byVec(vec1, vec2)
    local cr = vec1:cross(vec2)
    return q.xyzw(cr, sqrt(vec1:length2() * vec2:length2()) + vec1:dot(vec2)):normalized()
end

return q