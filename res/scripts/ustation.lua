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
    return (rad < pi * -0.5) and ust.normalizeRad(rad + pi * 2) or
        ((rad > pi + pi * 0.5) and ust.normalizeRad(rad - pi * 2) or rad)
end

ust.generateArc = function(fz, fs)
    return function(arc)
        local sup = arc:pt(arc.sup):withZ(fz(arc.sup))
        local inf = arc:pt(arc.inf):withZ(fz(arc.inf))
        
        local vecSup = func.with(arc:tangent(arc.sup), {z = fs(arc.sup)}):normalized()
        local vecInf = func.with(arc:tangent(arc.inf), {z = fs(arc.inf)}):normalized()
        
        return
            {inf, sup, vecInf, vecSup}
    end
end

ust.generateArcExt = function(fz, fs)
    return function(arc)
        local extArc = arc:extendLimits(5)
        
        local sup = arc:pt(arc.sup):withZ(fz(arc.sup))
        local inf = arc:pt(arc.inf):withZ(fz(arc.inf))
        
        local vecSup = func.with(arc:tangent(arc.sup), {z = fs(arc.sup)}):normalized()
        local vecInf = func.with(arc:tangent(arc.inf), {z = fs(arc.inf)}):normalized()
        
        local supExt = extArc:pt(extArc.sup):withZ(fz(extArc.sup))
        local infExt = extArc:pt(extArc.inf):withZ(fz(extArc.inf))
        
        local vecSupExt = func.with(arc:tangent(extArc.sup), {z = fs(extArc.sup)}):normalized()
        local vecInfExt = func.with(arc:tangent(extArc.inf), {z = fs(extArc.inf)}):normalized()
        
        return {
            {infExt, inf, vecInfExt, vecInf},
            {sup, supExt, vecSup, vecSupExt},
        }
    end
end

return ust
