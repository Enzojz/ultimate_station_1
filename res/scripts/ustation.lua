local func = require "ustation/func"
local coor = require "ustation/coor"
local arc = require "ustation/coorarc"
local station = require "ustation/stationlib"
local pipe = require "ustation/pipe"
local ust = {}

local pi = math.pi
local abs = math.abs

ust.infi = 1e8

ust.normalizeRad = function(rad)
    return (rad < pi * -0.5) and ust.normalizeRad(rad + pi * 2) or rad
end

ust.generateArc = function(arc)
    local toXyz = function(pt) return coor.xyz(pt.x, pt.y, 0) end
    
    local extArc = arc:extendLimits(5)
    
    local sup = toXyz(arc:pt(arc.sup))
    local inf = toXyz(arc:pt(arc.inf))
    
    local vecSup = arc:tangent(arc.sup)
    local vecInf = arc:tangent(arc.inf)
    
    local supExt = toXyz(extArc:pt(extArc.sup))
    local infExt = toXyz(extArc:pt(extArc.inf))
    
    return
        {inf, sup, vecInf, vecSup}
end

ust.generateArcExt = function(arc)
    local toXyz = function(pt) return coor.xyz(pt.x, pt.y, 0) end
    
    local extArc = arc:extendLimits(5)
    
    local sup = toXyz(arc:pt(arc.sup))
    local inf = toXyz(arc:pt(arc.inf))
    
    local vecSup = arc:tangent(arc.sup)
    local vecInf = arc:tangent(arc.inf)
    
    local supExt = toXyz(extArc:pt(extArc.sup))
    local infExt = toXyz(extArc:pt(extArc.inf))
    
    return {
        {infExt, inf, extArc:tangent(extArc.inf), vecInf},
        {sup, supExt, vecSup, extArc:tangent(extArc.sup)},
    }
end

ust.fArcs = function(offsets, rad, r)
    return pipe.new
        * offsets
        * function(o) return r > 0 and o or o * pipe.map(pipe.neg()) * pipe.rev() end
        * pipe.map(function(x) return
            func.with(
                arc.byOR(
                    coor.xyz(r, 0, 0) .. coor.rotZ(rad),
                    abs(r) - x
                ), {xOffset = r > 0 and x or -x})
        end)
        * function(a) return r > 0 and a or a * pipe.rev() end
end

ust.makeFn = function(model, mPlace, m, length)
    m = m or coor.I()
    length = length or 5
    return function(obj)
        local coordsGen = arc.coords(obj, length)
        local function makeModel(seq, scale)
            
            return func.map2(func.range(seq, 1, #seq - 1), func.range(seq, 2, #seq), function(rad1, rad2)
                return station.newModel(model, m, coor.scaleY(scale), mPlace(obj, rad1, rad2))
            end)
        end
        return makeModel(coordsGen(ust.normalizeRad(obj.inf), ust.normalizeRad(obj.sup)))
    end
end

local generatePolyArcEdge = function(group, from, to)
    return pipe.from(ust.normalizeRad(group[from]), ust.normalizeRad(group[to]))
        * arc.coords(group, 5)
        * pipe.map(function(rad) return func.with(group:pt(rad), {z = 0, rad = rad}) end)
end

ust.generatePolyArc = function(groups, from, to)
    local groupI, groupO = (function(ls) return ls[1], ls[#ls] end)(func.sort(groups, function(p, q) return p.r < q.r end))
    return function(extLon, extLat)
            
            local groupL, groupR = table.unpack(
                pipe.new
                / (groupO + extLat):extendLimits(extLon)
                / (groupI + (-extLat)):extendLimits(extLon)
                * pipe.sort(function(p, q) return p:pt(p.inf * 0.5 + p.sup * 0.5).x < q:pt(p.inf * 0.5 + p.sup * 0.5).x end)
            )
            return generatePolyArcEdge(groupR, from, to)
                * function(ls) return ls * pipe.range(1, #ls - 1)
                    * pipe.map2(ls * pipe.range(2, #ls),
                        function(f, t) return
                            {
                                f, t,
                                func.with(groupL:pt(t.rad), {z = 0, rad = t.rad}),
                                func.with(groupL:pt(f.rad), {z = 0, rad = f.rad}),
                            }
                        end)
                end
    end
end

function ust.regularizeRad(rad)
    return rad > pi
        and ust.regularizeRad(rad - pi)
        or (rad < -pi and ust.regularizeRad(rad + pi) or rad)
end


function ust.polyGen(slope)
    return function(wallHeight, refHeight, guidelines, wHeight, fr, to)
        local f = function(s) return s.g and
            ust.generatePolyArc(s.g, fr, to)(-0.2, 0)
            * pipe.map(pipe.map(s.fz))
            * station.projectPolys(coor.I())
            or {}
        end
        local polyGen = function(l, e, g)
            return wallHeight == 0 and f(e) or (wallHeight > 0 and f(g) or f(l))
        end
        return {
            slot = polyGen(
                {},
                {},
                {g = guidelines.outer, fz = function(p) return coor.transZ(p.y * slope)(p) end}
            ),
            equal = polyGen(
                {},
                refHeight > 0 and {} or {g = guidelines.ref, fz = function(p) return coor.transZ(p.y * slope)(p) end},
                {}
            ),
            less = polyGen(
                {g = guidelines.outer, fz = function(p) return coor.transZ(p.y * slope)(p) end},
                refHeight > 0 and {g = guidelines.ref, fz = function(p) return coor.transZ(p.y * slope)(p) end} or {},
                {g = guidelines.outer, fz = function(p) return coor.transZ(p.y * slope + wallHeight)(p) end}
            ),
            greater = polyGen(
                {g = guidelines.outer, fz = function(p) return coor.transZ(p.y * slope - wHeight)(p) end},
                refHeight > 0 and {g = guidelines.ref, fz = function(p) return coor.transZ(p.y * slope)(p) end} or {},
                refHeight >= 0 and {g = guidelines.outer, fz = function(p) return coor.transZ(p.y * slope)(p) end} or
                {g = guidelines.outer, fz = function(p) return coor.transZ(p.y * slope - wHeight + wallHeight)(p) end}
        )
        }
    end
end


return ust
