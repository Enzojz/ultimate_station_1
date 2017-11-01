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

local coor = {}
coor.make = laneutil.makeLanes

local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local rad = math.rad

local vecXyMeta = {
    __add = function(lhs, rhs)
        return coor.xy(lhs.x + rhs.x, lhs.y + rhs.y)
    end
    ,
    __sub = function(lhs, rhs)
        return coor.xy(lhs.x - rhs.x, lhs.y - rhs.y)
    end
    ,
    __mul = function(lhs, rhs)
        return coor.xy(lhs.x * rhs, lhs.y * rhs)
    end,
    __div = function(lhs, rhs)
        return coor.xy(lhs.x / rhs, lhs.y / rhs)
    end,
    __mod = function(lhs, rhs)
        return (lhs - rhs):length()
    end,
    __unm = function(lhs)
        return lhs * -1
    end
}

local vecXyLength = function(self) return sqrt(self:length2()) end
local vecXyLength2 = function(self) return self.x * self.x + self.y * self.y end
local vecXyNormalized = function(self) return self / self:length() end

function coor.xy(x, y)
    local result = {
        x = x,
        y = y,
        length2 = vecXyLength2,
        length = vecXyLength,
        normalized = vecXyNormalized
    }
    setmetatable(result, vecXyMeta)
    return result
end

local vecXyzMeta = {
    __add = function(lhs, rhs)
        return rhs.z and coor.xyz(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z) or coor.xy(lhs.x + rhs.x, lhs.y + rhs.y)
    end
    ,
    __sub = function(lhs, rhs)
        return rhs.z and coor.xyz(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z) or coor.xy(lhs.x - rhs.x, lhs.y - rhs.y)
    end
    ,
    __mul = function(lhs, rhs)
        return coor.xyz(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    end,
    __div = function(lhs, rhs)
        return coor.xyz(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    end,
    __concat = function(lhs, rhs)
        return coor.apply(lhs, rhs)
    end,
    __mod = function(lhs, rhs)
        return (lhs - rhs):length()
    end,
    __unm = function(lhs)
        return lhs * -1
    end
}

local vecXyzLength = function(self) return sqrt(self:length2()) end
local vecXyzLength2 = function(self) return self.x * self.x + self.y * self.y + self.z * self.z end
local vecXyzNormalized = function(self) return self / self:length() end
local vecXyzToTuple = function(self) return {self.x, self.y, self.z} end

function coor.xyz(x, y, z)
    local result = {
        x = x,
        y = y,
        z = z,
        length = vecXyzLength,
        length2 = vecXyzLength2,
        normalized = vecXyzNormalized,
        toTuple = vecXyzToTuple
    }
    setmetatable(result, vecXyzMeta)
    return result
end

coor.o = coor.xyz(0, 0, 0)

function coor.tuple2Vec(tuple)
    return coor.xyz(table.unpack(tuple))
end

function coor.vec2Tuple(vec)
    return {vec.x, vec.y, vec.z}
end

function coor.edge2Vec(edge)
    local pt, vec = table.unpack(edge)
    return coor.tuple2Vec(pt), coor.tuple2Vec(vec)
end

function coor.vec2Edge(pt, vec)
    return {pt:toTuple(), vec:toTuple()}
end

-- the original transf.mul is ill-formed. The matrix is in form of Y = X.A + b, but mul transposed the matrix for Y = A.X + b
local function mul(m1, m2)
    local m = function(line, col)
        local l = (line - 1) * 4
        return m1[l + 1] * m2[col + 0] + m1[l + 2] * m2[col + 4] + m1[l + 3] * m2[col + 8] + m1[l + 4] * m2[col + 12]
    end
    return {
        m(1, 1), m(1, 2), m(1, 3), m(1, 4),
        m(2, 1), m(2, 2), m(2, 3), m(2, 4),
        m(3, 1), m(3, 2), m(3, 3), m(3, 4),
        m(4, 1), m(4, 2), m(4, 3), m(4, 4)
    }
end

function coor.apply(vec, trans)
    local applyVal = function(col)
        return vec.x * trans[0 + col] + vec.y * trans[4 + col] + vec.z * trans[8 + col] + trans[12 + col]
    end
    return coor.xyz(applyVal(1), applyVal(2), applyVal(3))
end

function coor.applyEdge(mpt, mvec)
    return function(edge)
        local pt, vec = coor.edge2Vec(edge)
        local newPt = coor.apply(pt, mpt)
        local newVec = coor.apply(vec, mvec)
        return coor.vec2Edge(newPt, newVec)
    end
end

function coor.applyEdges(mpt, mvec)
    return function(edges)
        return func.map(edges, coor.applyEdge(mpt, mvec))
    end
end

local init = {}
local meta = {
    __mul = function(lhs, rhs)
        local result = mul(lhs, rhs)
        setmetatable(result, getmetatable(lhs))
        return result
    end,
    __call = function(lhs, rhs)
        return coor.apply(rhs, lhs)
    end
}

setmetatable(init,
    {
        __mul = function(_, rhs)
            setmetatable(rhs, meta)
            return rhs
        end
    })

function coor.I()
    return init * {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.rotZ(rotX)
    local sx = sin(rotX)
    local cx = cos(rotX)
    
    return init * {
        cx, sx, 0, 0,
        -sx, cx, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.rotY(rotX)
    local sx = sin(rotX)
    local cx = cos(rotX)
    
    return init * {
        cx, 0, sx, 0,
        0, 1, 0, 0,
        -sx, 0, cx, 0,
        0, 0, 0, 1
    }
end


function coor.rotX(rotX)
    local sx = sin(rotX)
    local cx = cos(rotX)
    
    return init * {
        1, 0, 0, 0,
        0, cx, sx, 0,
        0, -sx, cx, 0,
        0, 0, 0, 1
    }
end

function coor.xXY()
    return init * {
        0, 1, 0, 0,
        1, 0, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.xXZ()
    return init * {
        0, 0, 1, 0,
        0, 1, 0, 0,
        1, 0, 0, 0,
        0, 0, 0, 1
    }
end

function coor.flipX()
    return init * {
        -1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end


function coor.flipY()
    return init * {
        1, 0, 0, 0,
        0, -1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.flipZ()
    return init * {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, -1, 0,
        0, 0, 0, 1
    }
end

function coor.trans(vec)
    return coor.transX(vec.x) * coor.transY(vec.y) * coor.transZ(vec.z)
end

function coor.transX(dx)
    return init * {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        dx, 0, 0, 1
    }
end

function coor.transY(dy)
    return init * {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, dy, 0, 1
    }
end

function coor.transZ(dz)
    return init * {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, dz, 1
    }
end


function coor.scaleX(sx)
    return init * {
        sx, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end


function coor.scaleY(sy)
    return init * {
        1, 0, 0, 0,
        0, sy, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.scaleZ(sz)
    return init * {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, sz, 0,
        0, 0, 0, 1
    }
end

function coor.scale(vec)
    return coor.scaleX(vec.x) * coor.scaleY(vec.y) * coor.scaleZ(vec.z)
end

function coor.shearXoY(s)
    return init * {
        1, 0, 0, 0,
        s, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.shearXoZ(s)
    return init * {
        1, 0, 0, 0,
        0, 1, 0, 0,
        s, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.mul(...)
    local params = {...}
    local m = params[1]
    for i = 2, #params do
        m = m * params[i]
    end
    return m
end

function coor.shearYoX(s)
    return init * {
        1, s, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.shearYoZ(s)
    return init * {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, s, 1, 0,
        0, 0, 0, 1
    }
end

function coor.shearYoX(s)
    return init * {
        1, s, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.shearZoX(s)
    return init * {
        1, 0, s, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.shearZoY(s)
    return init * {
        1, 0, 0, 0,
        0, 1, s, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

function coor.rotate(edge, mt0, mtr, mt1)
    return coor.applyEdge(coor.mul(mt0, mtr, mt1), mtr)(edge)
end

function coor.translateAndBack(center)
    return coor.trans(coor.o - center),
        coor.trans(center)
end


function coor.centered(op, rad, center)
    local mt0, mt1 = coor.translateAndBack(center)
    local mtr = op(rad)
    return mt0 * mtr * mt1
end

function coor.rotateEdgeByZ(degree, center, edge)
    local mt0, mt1 = coor.translateAndBack(center)
    local mtr = coor.rotZ(rad(degree))
    return coor.rotate(edge, mt0, mtr, mt1)
end

function coor.rotateEdgeByX(rad, center, edge)
    local mt0, mt1 = coor.translateAndBack(center)
    local mtr = coor.rotX(rad)
    return coor.rotate(edge, mt0, mtr, mt1)
end

function coor.setHeight(height, edge)
    local mz = coor.transZ(height)
    local pt, vec = coor.edge2Vec(edge)
    local newPt = coor.apply(pt, mz)
    return coor.vec2Edge(newPt, vec)
end

return coor
