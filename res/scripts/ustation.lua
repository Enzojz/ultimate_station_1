local func = require "ustation/func"
local coor = require "ustation/coor"
local arc = require "ustation/coorarc"
local line = require "ustation/coorline"
local quat = require "ustation/quaternion"
local station = require "ustation/stationlib"
local pipe = require "ustation/pipe"
local ust = {}

local pi = math.pi
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local pow = math.pow
local e = math.exp(1)

ust.infi = 1e8

ust.varFn = function(base) return
    {
        function(_) return 1 end,
        function(x) return x end,
        function(x) return x * x end,
        function(x) return pow(x, 4) end,
        function(x) return 1 - pow(e, -x * x * 4.5) end,
        function(x) return pow(e, -pow(6 * x - 3, 2) * 0.5) end,
    }
end


ust.normalizeRad = function(rad)
    return (rad < pi * -0.5) and ust.normalizeRad(rad + pi * 2) or
        ((rad > pi + pi * 0.5) and ust.normalizeRad(rad - pi * 2) or rad)
end

ust.generateArc = function(arc)
    local sup = arc:pt(arc.sup)
    local inf = arc:pt(arc.inf)
    
    local vecSup = arc:tangent(arc.sup)
    local vecInf = arc:tangent(arc.inf)
    
    return
        {inf, sup, vecInf, vecSup}
end

ust.generateArcExt = function(arc)
    local extArc = arc:extendLimits(5)
    
    local sup = arc:pt(arc.sup)
    local inf = arc:pt(arc.inf)
    
    local vecSup = arc:tangent(arc.sup)
    local vecInf = arc:tangent(arc.inf)
    
    local supExt = arc:pt(extArc.sup)
    local infExt = arc:pt(extArc.inf)
    
    local vecSupExt = arc:tangent(extArc.sup)
    local vecInfExt = arc:tangent(extArc.inf)
    
    return {
        {infExt, inf, vecInfExt, vecInf},
        {sup, supExt, vecSup, vecSupExt},
    }
end

ust.arcPacker = function(length, slope)
    return function(radius, o, lengthVar, dislodge)
        local dislodge = dislodge and (dislodge * length / radius) or 0
        local length = lengthVar and (length * lengthVar) or length
        local initRad = (radius > 0 and pi or 0) + dislodge
        return function(z)
            local z = z or 0
            return function(lengthOverride)
                local l = lengthOverride and lengthOverride(length) or length
                return function(xDr)
                    local dr = xDr or 0
                    local ar = arc.byOR(o + coor.xyz(0, 0, z), abs(radius - dr))
                    local rad = (radius > 0 and 1 or -1) * l / ar.r * 0.5
                    return pipe.new
                        / ar:withLimits({
                            sup = initRad - rad,
                            inf = initRad,
                            slope = -slope
                        })
                        / ar:withLimits({
                            inf = initRad,
                            sup = initRad + rad,
                            slope = slope
                        })
                end
            end
        end
    end
end

ust.mRot = function(vec)
    return coor.scaleX(vec:length()) * quat.byVec(coor.xyz(1, 0, 0), (vec)):mRot()
end

local retriveNSeg = function(length, l, ...)
    return (function(x) return (x < 1 or (x % 1 > 0.5)) and ceil(x) or floor(x) end)(l:length() / length), l, ...
end

local retriveBiLatCoords = function(nSeg, l, ...)
    local rst = pipe.new * {l, ...}
    local lscale = l:length() / (nSeg * length)
    return table.unpack(
        func.map(rst,
            function(s) return abs(lscale) < 1e-5 and pipe.new * {} or pipe.new * func.seqMap({0, nSeg},
                function(n) return s:pt(s.inf + n * ((s.sup - s.inf) / nSeg)) end)
            end)
)
end

local equalizeArcs = function(f, s, ...)
    local arcs = pipe.new * {f, s, ...}
    local ptInf = f:pt(f.inf):avg(s:pt(s.inf))
    local ptSup = f:pt(f.sup):avg(s:pt(s.sup))
    local lnInf = line.byPtPt(arc.ptByPt(f, ptInf), arc.ptByPt(s, ptInf))
    local lnSup = line.byPtPt(arc.ptByPt(f, ptSup), arc.ptByPt(s, ptSup))
    return arcs * pipe.map(function(ar)
        local intInf = ar / lnInf
        local intSup = ar / lnSup
        
        return ar:withLimits({
            inf = ar:rad(((intInf[1] - ptInf):length2() < (intInf[2] - ptInf):length2()) and intInf[1] or intInf[2]),
            sup = ar:rad(((intSup[1] - ptSup):length2() < (intSup[2] - ptSup):length2()) and intSup[1] or intSup[2])
        }
    )
    end)
end

local function ungroup(fst, ...)
    local f = {...}
    return function(lst, ...)
        local l = {...}
        return function(result, c)
            if (fst and lst) then
                return ungroup(table.unpack(f))(table.unpack(l))(
                    result /
                    (fst * pipe.range(2, #fst) * pipe.rev() + {fst[1]:avg(lst[1])} + lst * pipe.range(2, #lst)),
                    floor((#fst + #lst) * 0.5)
            )
            else
                return result / c
            end
        end
    end
end

local bitLatCoords = function(length)
    return function(...)
        local arcs = pipe.new * {...}
        local arcsInf = equalizeArcs(table.unpack(func.map({...}, pipe.select(1))))
        local arcsSup = equalizeArcs(table.unpack(func.map({...}, pipe.select(2))))
        local nSegInf = retriveNSeg(length, table.unpack(arcsInf))
        local nSegSup = retriveNSeg(length, table.unpack(arcsSup))
        if (nSegInf % 2 ~= nSegSup % 2) then
            if (nSegInf > nSegSup) then
                nSegSup = nSegSup + 1
            else
                nSegInf = nSegInf + 1
            end
        end
        return table.unpack(ungroup
            (retriveBiLatCoords(nSegInf, table.unpack(arcsInf)))
            (retriveBiLatCoords(nSegSup, table.unpack(arcsSup)))
            (pipe.new)
    )
    end
end

ust.bitLatCoords = bitLatCoords

local assembleSize = function(lc, rc)
    return {
        lb = lc.i,
        lt = lc.s,
        rb = rc.i,
        rt = rc.s
    }
end

ust.assembleSize = assembleSize

ust.fitModel2D = function(w, h, _, size, fitTop, fitLeft)
    local s = {
        coor.xyz(0, 0),
        coor.xyz(fitLeft and w or -w, 0),
        coor.xyz(0, fitTop and -h or h),
    }
    
    local t = fitTop and
        {
            fitLeft and size.lt or size.rt,
            fitLeft and size.rt or size.lt,
            fitLeft and size.lb or size.rb,
        } or {
            fitLeft and size.lb or size.rb,
            fitLeft and size.rb or size.lb,
            fitLeft and size.lt or size.rt,
        }
    
    local mX = {
        {s[1].x, s[1].y, 1},
        {s[2].x, s[2].y, 1},
        {s[3].x, s[3].y, 1},
    }
    
    local mU = {
        t[1].x, t[1].y, 1,
        t[2].x, t[2].y, 1,
        t[3].x, t[3].y, 1,
    }
    
    local dX = coor.det(mX)
    
    local miX = coor.minor(mX)
    local mXI = func.mapFlatten(func.seq(1, 3),
        function(l)
            return func.seqMap({1, 3}, function(c)
                return ((l + c) % 2 == 0 and 1 or -1) * coor.det(miX(c, l)) / dX
            end)
        end)
    
    local function mul(m1, m2)
        local m = function(line, col)
            local l = (line - 1) * 3
            return m1[l + 1] * m2[col + 0] + m1[l + 2] * m2[col + 3] + m1[l + 3] * m2[col + 6]
        end
        return {
            m(1, 1), m(1, 2), m(1, 3),
            m(2, 1), m(2, 2), m(2, 3),
            m(3, 1), m(3, 2), m(3, 3),
        }
    end
    
    local mXi = mul(mXI, mU)
    
    return coor.I() * {
        mXi[1], mXi[2], 0, mXi[3],
        mXi[4], mXi[5], 0, mXi[6],
        0, 0, 1, 0,
        mXi[7], mXi[8], 0, mXi[9]
    }
end

ust.fitModel = function(w, h, d, size, fitTop, fitLeft)
    local s = {
        coor.xyz(0, 0, d),
        coor.xyz(fitLeft and w or -w, 0, d),
        coor.xyz(0, fitTop and -h or h, d),
        coor.xyz(0, 0, 0)
    }
    
    local t = fitTop and
        {
            fitLeft and size.lt or size.rt,
            fitLeft and size.rt or size.lt,
            fitLeft and size.lb or size.rb,
        } or {
            fitLeft and size.lb or size.rb,
            fitLeft and size.rb or size.lb,
            fitLeft and size.lt or size.rt,
        }
    
    local mX = {
        {s[1].x, s[1].y, s[1].z, 1},
        {s[2].x, s[2].y, s[2].z, 1},
        {s[3].x, s[3].y, s[3].z, 1},
        {s[4].x, s[4].y, s[4].z, 1}
    }
    
    local mU = {
        t[1].x, t[1].y, t[1].z, 1,
        t[2].x, t[2].y, t[2].z, 1,
        t[3].x, t[3].y, t[3].z, 1,
        t[1].x, t[1].y, t[1].z - d, 1
    }
    
    local dX = coor.det(mX)
    
    local miX = coor.minor(mX)
    local mXI = func.mapFlatten(func.seq(1, 4),
        function(l)
            return func.seqMap({1, 4}, function(c)
                return ((l + c) % 2 == 0 and 1 or -1) * coor.det(miX(c, l)) / dX
            end)
        end)
    
    return coor.I() * mXI * mU
end

local il = pipe.interlace({"s", "i"})

ust.unitLane = function(f, t) return ((t - f):length2() > 1e-2 and (t - f):length2() < 562500) and station.newModel("ust/person_lane.mdl", ust.mRot(t - f), coor.trans(f)) or nil end

ust.generateEdges = function(edges, isLeft, arcPacker)
    local arcs = arcPacker()()()
    local eInf, eSup = table.unpack(arcs * pipe.map2(isLeft and {pipe.noop(), arc.rev} or {arc.rev, pipe.noop()}, function(a, op) return op(a) end) * pipe.map(ust.generateArc))
    if isLeft then
        eInf[1] = eInf[1]:avg(eSup[2])
        eSup[2] = eInf[1]
        eInf[3] = eInf[3]:avg(eSup[4])
        eSup[4] = eInf[3]
    else
        eInf[2] = eInf[2]:avg(eSup[1])
        eSup[1] = eInf[2]
        eInf[4] = eInf[4]:avg(eSup[3])
        eSup[3] = eInf[4]
    end
    return edges /
        {
            edge = pipe.new / eInf / eSup + arcs * pipe.mapFlatten(ust.generateArcExt) * function(ls) return {ls[2], ls[4]} end,
            snap = pipe.new / {false, false} / {false, false} / {false, true} / {false, true}
        }
end

ust.generateTerminals = function(config)
    local platformZ = config.hPlatform + 0.53
    return function(edges, terminals, terminalsGroup, arcs, enablers)
        local lc, rc, c = arcs.lane.lc, arcs.lane.rc, arcs.lane.c
        local newTerminals = pipe.new
            * pipe.mapn(il(lc), il(rc))(function(lc, rc)
                return {
                    l = station.newModel(enablers[1] and "ust/terminal_lane.mdl" or "ust/standard_lane.mdl", ust.mRot(lc.s - lc.i), coor.trans(lc.i)),
                    r = station.newModel(enablers[2] and "ust/terminal_lane.mdl" or "ust/standard_lane.mdl", ust.mRot(rc.i - rc.s), coor.trans(rc.s)),
                    link = (lc.s:avg(lc.i) - rc.s:avg(rc.i)):length() > 0.5 and station.newModel("ust/standard_lane.mdl", ust.mRot(lc.s:avg(lc.i) - rc.s:avg(rc.i)), coor.trans(rc.i:avg(rc.s)))
                }
            end)
            * function(ls)
                return pipe.new
                    / func.map(ls, pipe.select("l"))
                    / func.map(ls, pipe.select("r"))
                    / (ls * pipe.map(pipe.select("link")) * pipe.filter(pipe.noop()))
            end
        
        return terminals + newTerminals * pipe.flatten(),
            terminalsGroup
            + (
            (enablers[1] and enablers[2]) and {
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[1]) * pipe.map(function(s) return {s - 1 + #terminals, 0} end),
                    vehicleNodeOverride = #edges * 8 - 16
                },
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[2]) * pipe.map(function(s) return {s - 1 + #terminals + #newTerminals[1], 0} end),
                    vehicleNodeOverride = #edges * 8 - 7
                }
            } or enablers[1] and {
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[1]) * pipe.map(function(s) return {s - 1 + #terminals, 0} end),
                    vehicleNodeOverride = #edges * 8 - 8
                }
            } or enablers[2] and {
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[2]) * pipe.map(function(s) return {s - 1 + #terminals + #newTerminals[1], 0} end),
                    vehicleNodeOverride = #edges * 8 - 7
                }
            } or {}
    )
    end
end


ust.generateTerminalsDual = function(config)
    local platformZ = config.hPlatform + 0.53
    return function(edges, terminals, terminalsGroup, arcsL, arcsR, enablers)
        local lc, rc = arcsL.lane.lc
            * pipe.range(1, arcsL.lane.intersection), arcsR.lane.rc
            * pipe.range(1, arcsR.lane.intersection)
        
        local llc, lrc = arcsL.lane.lc
            * pipe.range(arcsL.lane.intersection, #arcsL.lane.lc), arcsL.lane.rc
            * pipe.range(arcsL.lane.intersection, #arcsL.lane.rc)
        
        local rlc, rrc = arcsR.lane.lc
            * pipe.range(arcsR.lane.intersection, #arcsR.lane.lc), arcsR.lane.rc
            * pipe.range(arcsR.lane.intersection, #arcsR.lane.rc)
        
        local clc, crc =
            arcsL.lane.rc * pipe.range(arcsL.lane.intersection, arcsL.lane.common),
            arcsR.lane.lc * pipe.range(arcsR.lane.intersection, arcsR.lane.common)
        
        local terminalsL = arcsL.lane.lc * il
            * pipe.map(function(lc) return station.newModel(enablers[1] and "ust/terminal_lane.mdl" or "ust/standard_lane.mdl", ust.mRot(lc.s - lc.i), coor.trans(lc.i)) end)
        
        local terminalsR = arcsR.lane.rc * il
            * pipe.map(function(lc) return station.newModel(enablers[2] and "ust/terminal_lane.mdl" or "ust/standard_lane.mdl", ust.mRot(lc.s - lc.i), coor.trans(lc.i)) end)
        
        local links =
            pipe.new +
            pipe.mapn(lc * il + llc * il + rlc * il + clc * il, rc * il + lrc * il + rrc * il + crc * il)
                (
                function(lc, rc)
                    return (lc.s:avg(lc.i) - rc.s:avg(rc.i)):length() > 0.5 and
                        station.newModel("ust/standard_lane.mdl", ust.mRot(lc.s:avg(lc.i) - rc.s:avg(rc.i)), coor.trans(rc.i:avg(rc.s)))
                end
            )
            + func.map(il(lrc), function(c) return station.newModel("ust/standard_lane.mdl", ust.mRot(c.s - c.i), coor.trans(c.i)) end)
            + func.map(il(rlc), function(c) return station.newModel("ust/standard_lane.mdl", ust.mRot(c.s - c.i), coor.trans(c.i)) end)
            + pipe.mapn(clc * il, crc * il)(function(lc, rc)
                return (lc.s:avg(lc.i) - rc.s:avg(rc.i)):length() > 0.5 and station.newModel("ust/standard_lane.mdl", ust.mRot(lc.s:avg(rc.s) - lc.i:avg(rc.i)), coor.trans(lc.i:avg(rc.i)))
            end
        )
        local newTerminals = pipe.new / terminalsL / terminalsR / links
        
        return terminals + newTerminals * pipe.flatten() * pipe.filter(pipe.noop()), terminalsGroup +
            ((enablers[1] and enablers[2]) and
            {
                {
                    terminals = pipe.new
                    * func.seq(1, #newTerminals[1])
                    * pipe.map(function(s) return {s - 1 + #terminals, 0} end),
                    vehicleNodeOverride = #edges * 8 - 16
                },
                {
                    terminals = pipe.new
                    * func.seq(1, #newTerminals[2])
                    * pipe.map(function(s) return {s - 1 + #terminals + #newTerminals[1], 0} end),
                    vehicleNodeOverride = #edges * 8 - 7
                }
            } or
            enablers[1] and
            {
                {
                    terminals = pipe.new
                    * func.seq(1, #newTerminals[1])
                    * pipe.map(function(s) return {s - 1 + #terminals, 0} end),
                    vehicleNodeOverride = #edges * 8 - 8
                }
            } or
            enablers[2] and
            {
                {
                    terminals = pipe.new
                    * func.seq(1, #newTerminals[2]) *
                    pipe.map(function(s) return {s - 1 + #terminals + #newTerminals[1], 0} end),
                    vehicleNodeOverride = #edges * 8 - 7
                }
            } or
            {})
    end
end


ust.generateFences = function(fitModel, config)
    local platformZ = config.hPlatform + 0.53
    return function(arcRef, isLeft, isTrack, filter)
        local filter = filter and filter(isLeft, isTrack) or function(_) return true end
        local li, ri =
            arcRef(platformZ)(function(l) return l - 0.3 end)((isTrack and -0.5 * config.wTrack or -0.5) + 0.3),
            arcRef(platformZ)(function(l) return l - 0.3 end)((isTrack and 0.5 * config.wTrack or 0.5) - 0.3)
        
        local newModels = pipe.new
            + pipe.mapn(func.seq(1, #li), li, ri)(function(i, li, ri)
                local lc, rc = retriveBiLatCoords(retriveNSeg(config.fencesLength, table.unpack(equalizeArcs(li, ri))))
                local c = isLeft and lc or rc
                return {
                    pipe.new * il(c)
                    * pipe.filter(filter)
                    * pipe.map(function(ic)
                        local vec = ic.i - ic.s
                        return station.newModel(config.fencesModel[1],
                            coor.rotZ(((not isLeft and i == 1) or (isLeft and i ~= 1)) and 0 or pi),
                            coor.scaleX(vec:length() / config.fencesLength),
                            quat.byVec(coor.xyz(config.fencesLength, 0, 0), vec):mRot(),
                            coor.trans(ic.s:avg(ic.i) + (isTrack and coor.xyz(0, 0, -platformZ) or coor.o)))
                    end),
                    pipe.new * c
                    * pipe.filter(filter)
                    * pipe.map(function(ic)
                        return station.newModel(config.fencesModel[2],
                            coor.rotZ(0.5 * pi),
                            coor.rotZ(li:rad(ic)),
                            coor.trans(ic + (isTrack and coor.xyz(0, 0, -platformZ) or coor.o)))
                    end)
                }
            end)
        return newModels * pipe.flatten() * pipe.flatten()
    end
end

local buildSurface = function(fitModel, platformZ, tZ)
    return function(c, w)
        return function(i, s, sx, lic, ric)
            local lic = i >= c and lic or {s = lic.i, i = lic.s}
            local ric = i >= c and ric or {s = ric.i, i = ric.s}
            
            local sizeS = ust.assembleSize(lic, ric)
            
            local vecs = {
                top = sizeS.rt - sizeS.lt,
                bottom = sizeS.rb - sizeS.lb
            }
            if (vecs.top:length() < (1.5 * w) and vecs.bottom:length() < (1.5 * w)) then
                return pipe.new
                    / station.newModel(s .. "_br.mdl", tZ, fitModel(w, 5, platformZ, sizeS, false, false))
                    / station.newModel(s .. "_tl.mdl", tZ, fitModel(w, 5, platformZ, sizeS, true, true))
            else
                local n = (function(l)
                    return (l - floor(l) < 0.5)
                        and (function(n) return n % 2 == 0 and n - 1 or n end)(floor(l))
                        or (function(n) return n % 2 == 0 and n + 1 or n end)
                        (ceil(l))
                end)((vecs.top:length() + vecs.bottom:length()) / 14)
                
                local h = (n - 1) * 0.5
                
                local sizeS2 = {
                    lb = sizeS.lb + vecs.bottom * h / n,
                    lt = sizeS.lt + vecs.top * h / n,
                    rb = sizeS.rb - vecs.bottom * h / n,
                    rt = sizeS.rt - vecs.top * h / n
                }
                
                return pipe.new
                    * func.seq(1, h)
                    * pipe.map(function(i)
                        local size = {
                            lb = sizeS.lb + vecs.bottom * (i - 1) / n,
                            lt = sizeS.lt + vecs.top * (i - 1) / n,
                            rb = sizeS.lb + vecs.bottom * i / n,
                            rt = sizeS.lt + vecs.top * i / n
                        }
                        
                        return pipe.new
                            / station.newModel(sx .. "_br.mdl", tZ, fitModel(w, 5, platformZ, size, false, false))
                            / station.newModel(sx .. "_tl.mdl", tZ, fitModel(w, 5, platformZ, size, true, true))
                    end
                    )
                    * pipe.flatten()
                    + {
                        station.newModel(s .. "_br.mdl", tZ, fitModel(w, 5, platformZ, sizeS2, false, false)),
                        station.newModel(s .. "_tl.mdl", tZ, fitModel(w, 5, platformZ, sizeS2, true, true))
                    }
                    + pipe.new
                    * func.seq(1, h)
                    * pipe.map(
                        function(i)
                            local size = {
                                lb = sizeS.rb - vecs.bottom * i / n,
                                lt = sizeS.rt - vecs.top * i / n,
                                rb = sizeS.rb - vecs.bottom * (i - 1) / n,
                                rt = sizeS.rt - vecs.top * (i - 1) / n
                            }
                            
                            return pipe.new
                                / station.newModel(sx .. "_br.mdl", tZ, fitModel(w, 5, platformZ, size, false, false))
                                / station.newModel(sx .. "_tl.mdl", tZ, fitModel(w, 5, platformZ, size, true, true))
                        end
                    )
                    * pipe.flatten()
            end
        end
    end
end

local retriveModels = function(fitModel, platformZ, tZ)
    return function(c, ccl, ccr, w)
        local buildSurface = buildSurface(fitModel, platformZ, tZ)(c, 5 - w * 2)
        return function(i, el, er, s, sx, lc, rc, lic, ric)
            local surface = buildSurface(i, s, sx, lic, ric)
            
            local lce = i >= ccl and lc or {s = lc.i, i = lc.s}
            local rce = i >= ccr and rc or {s = rc.i, i = rc.s}
            local lice = i >= ccl and lic or {s = lic.i, i = lic.s}
            local rice = i >= ccr and ric or {s = ric.i, i = ric.s}
            
            local sizeLe = ust.assembleSize(lce, lice)
            local sizeRe = ust.assembleSize(rice, rce)
            
            return surface
                / station.newModel(el .. "_br.mdl", tZ, fitModel(w, 5, platformZ, sizeLe, false, false))
                / station.newModel(el .. "_tl.mdl", tZ, fitModel(w, 5, platformZ, sizeLe, true, true))
                / station.newModel(er .. "_bl.mdl", tZ, fitModel(w, 5, platformZ, sizeRe, false, true))
                / station.newModel(er .. "_tr.mdl", tZ, fitModel(w, 5, platformZ, sizeRe, true, false))
        end
    end
end

local function buildPoles(config, platformZ, tZ)
    return function(mc, c, f, t)
        local seq = pipe.new
            * pipe.rep(c - 2)(config.models.roofPole)
            / config.models.roofPoleExtreme
            * function(ls) return ls * pipe.rev() + ls end
        
        return pipe.mapn(
            pipe.range(f, t)(pipe.mapi(function(mc, i) return i >= c and coor.I() or coor.flipY() end)(seq)),
            pipe.range(f, t)(il(mc)),
            pipe.range(f, t)(seq)
        )
        (function(t, mc, m)
            local vecPo = mc.s - mc.i
            return station.newModel(m .. ".mdl", tZ, t,
                coor.scaleY(vecPo:length() / 10),
                quat.byVec(coor.xyz(0, 10, 0), vecPo):mRot(),
                coor.trans(mc.i:avg(mc.s)),
                coor.transZ(-platformZ))
        end)
    end
end

local function buildChairs(config, platformZ, tZ)
    return function(lc, rc, mc, c, f, t)
        local platformChairs = pipe.new
            * func.seq(1, c - 1)
            * pipe.map(function(i)
                return c > 3 and i ~= 2 and i % floor(c * 0.5) ~= 2 and i ~= c - 1 and (i % 6 == 4 or (i - 1) % 6 == 4 or (i + 1) % 6 == 4) and
                    (i % 3 ~= 1 and config.models.chair .. ".mdl" or config.models.trash .. ".mdl")
            end)
            * (function(ls) return ls * pipe.rev() + {c < 6 and config.models.chair .. ".mdl"} + ls end)
        local r = pipe.range(f, t)
        return
            pipe.mapn(
                r(lc),
                r(rc),
                r(mc),
                r(platformChairs)
            )
            (function(lc, rc, mc, m)
                return m
                    and {
                        station.newModel(m,
                            quat.byVec(coor.xyz(0, i == 1 and 1 or -1, 0), (rc - lc):withZ(0) .. coor.rotZ(0.5 * pi)):mRot(),
                            coor.trans(mc))
                    }
                    or {}
            end)
    end
end

ust.generateModels = function(fitModel, config)
    local tZ = coor.transZ(config.hPlatform - 1.4)
    local platformZ = config.hPlatform + 0.53
    
    local buildSurface = buildSurface(fitModel, platformZ, tZ)
    local retriveModels = retriveModels(fitModel, platformZ, tZ)
    local buildPoles = buildPoles(config, platformZ, tZ)
    local buildChairs = buildChairs(config, platformZ, tZ)
    
    return function(arcs, edgeBuilder)
        local edgeBuilder = edgeBuilder or function(platformEdgeO, _) return platformEdgeO, platformEdgeO end
        
        local lc, rc, lic, ric, c = arcs.platform.lc, arcs.platform.rc, arcs.surface.lc, arcs.surface.rc, arcs.surface.c
        local lpc, rpc, lpic, rpic, pc = arcs.roof.edge.lc, arcs.roof.edge.rc, arcs.roof.surface.lc, arcs.roof.surface.rc, arcs.roof.edge.c
        local lpp, rpp, mpp, ppc = arcs.roof.pole.lc, arcs.roof.pole.rc, arcs.roof.pole.mc, arcs.roof.pole.c
        local lcc, rcc, mcc, cc = arcs.chair.lc, arcs.chair.rc, arcs.chair.mc, arcs.chair.c
        
        local platformSurface = pipe.new
            * pipe.rep(c - 2)(config.models.surface)
            * pipe.mapi(function(p, i) return (i == (c > 5 and 4 or 2) or (i == floor(c * 0.5) + 4) and (arcs.hasLower or arcs.hasUpper)) and config.models.stair or config.models.surface end)
            / config.models.extremity
            * (function(ls) return ls * pipe.rev() + ls end)
        
        local platformSurfaceEx = pipe.new
            * pipe.rep(c - 2)(config.models.surface)
            / config.models.extremity
            * (function(ls) return ls * pipe.rev() + ls end)
        
        local platformEdgeO = pipe.new
            * pipe.rep(c - 2)(config.models.edge)
            / config.models.corner
            * (function(ls) return ls * pipe.rev() + ls end)
        
        local platformEdgeL, platformEdgeR = edgeBuilder(platformEdgeO, c)
        
        local roofSurface = pipe.new
            * pipe.rep(pc - 2)(config.models.roofTop)
            / config.models.roofExtremity
            * (function(ls) return ls * pipe.rev() + ls end)
        
        local roofEdge = pipe.new
            * pipe.rep(pc - 2)(config.models.roofEdge)
            / config.models.roofCorner
            * (function(ls) return ls * pipe.rev() + ls end)
        
        
        local newModels = pipe.mapn(
            func.seq(1, 2 * c - 2),
            platformEdgeL,
            platformEdgeR,
            platformSurface,
            platformSurfaceEx,
            il(lc), il(rc), il(lic), il(ric)
        )(retriveModels(c, c, c, 0.8))
        
        local chairs = buildChairs(lcc, rcc, mcc, cc, 1, 2 * cc - 1)
        
        local newRoof = config.roofLength == 0
            and {}
            or pipe.new * pipe.mapn(
                func.seq(1, 2 * pc - 2),
                roofEdge,
                roofEdge,
                roofSurface,
                roofSurface,
                il(lpc), il(rpc), il(lpic), il(rpic)
            )(retriveModels(pc, pc, pc, 1))
            / buildPoles(mpp, ppc, 1, ppc * 2 - 1)
        
        
        return (pipe.new / newModels / newRoof / chairs) * pipe.flatten() * pipe.flatten()
    end
end


ust.generateModelsDual = function(fitModel, config)
    local tZ = coor.transZ(config.hPlatform - 1.4)
    local platformZ = config.hPlatform + 0.53
    
    local buildSurface = buildSurface(fitModel, platformZ, tZ)
    local retriveModels = retriveModels(fitModel, platformZ, tZ)
    
    local buildPoles = buildPoles(config, platformZ, tZ)
    local buildChairs = buildChairs(config, platformZ, tZ)
    
    return function(arcsL, arcsR, edgeBuilder)
        local edgeBuilder = edgeBuilder or function(platformEdgeO, _) return platformEdgeO, platformEdgeO end
        
        local platformModels = function()
            local intersection = arcsL.platform.intersection
            local commonLength = arcsL.platform.common
            
            local function modelSeq(arcs, isLeft)
                local c = arcs.surface.c
                
                local platformSurface =
                    pipe.new * pipe.rep(c - 2)(config.models.surface) *
                    pipe.mapi(
                        function(p, i)
                            return (i == (c > 5 and 4 or 2) or (i == floor(c * 0.5) + 4) and (arcs.hasLower or arcs.hasUpper))
                                and config.models.stair
                                or config.models.surface
                        end
                    ) /
                    config.models.extremity *
                    (function(ls)
                        return ls * pipe.rev() + ls
                    end)
                
                local platformSurfaceEx = pipe.new
                    * pipe.rep(c - 2)(config.models.surface) / config.models.extremity
                    * (function(ls) return ls * pipe.rev() + ls end)
                
                local platformEdgeO = pipe.new
                    * pipe.rep(c - 2)(config.models.edge) / config.models.corner
                    * (function(ls) return ls * pipe.rev() + ls end)
                
                local platformEdgeL, platformEdgeR = edgeBuilder(platformEdgeO, c)
                
                local fn = pipe.mapi(
                    function(m, i) return i >= intersection and i < commonLength and config.models.edgeSurface or i ~= commonLength and m or
                        commonLength == 2 * (c - 1) and config.models.edgeSurfaceExtreme or
                        config.models.edgeSurfaceCorner
                    end
                )
                if isLeft then platformEdgeR = platformEdgeR * fn else platformEdgeL = platformEdgeL * fn end
                
                local platformEdgeSurface = pipe.new
                    * pipe.rep(c - 1)(config.models.edgeSurface)
                    * (function(ls) return ls * pipe.rev() + ls end)
                
                return {
                    platformSurface = platformSurface,
                    platformSurfaceEx = platformSurfaceEx,
                    platformEdgeSurface = platformEdgeSurface,
                    platformEdgeO = platformEdgeO,
                    platformEdgeL = platformEdgeL,
                    platformEdgeR = platformEdgeR
                }
            end
            
            local models = {
                l = modelSeq(arcsL, true),
                r = modelSeq(arcsR, false)
            }
            
            local function commonParts()
                local lc, rc, lic, ric, c = arcsL.platform.lc, arcsR.platform.rc, arcsL.surface.lc, arcsR.surface.rc, arcsL.surface.c
                return pipe.mapn(
                    func.seq(1, intersection - 1),
                    models.l.platformEdgeL,
                    models.r.platformEdgeR,
                    models.l.platformSurface,
                    models.l.platformSurfaceEx,
                    il(lc), il(rc), il(lic), il(ric)
                )(retriveModels(c, c, c, 0.8))
            end
            
            local function middlePart()
                local lc, rc, c = arcsL.platform.rc, arcsR.platform.lc, arcsL.surface.c
                local fn = function(f, t)
                    local range = pipe.range(f, t)
                    return pipe.mapn(
                        func.seq(f, t),
                        models.l.platformSurfaceEx * pipe.range(f, t - 1) / config.models.extremity,
                        models.l.platformSurfaceEx * pipe.range(f, t - 1) / config.models.extremity,
                        lc * il * range,
                        rc * il * range
                )
                end
                return pipe.new + fn(intersection, commonLength)(buildSurface(commonLength, 3.4))
            end
            
            local function leftPart()
                local lc, rc, lic, ric, c = arcsL.platform.lc, arcsL.platform.rc, arcsL.surface.lc, arcsL.surface.rc, arcsL.surface.c
                local fn = function(f, t)
                    local range = pipe.range(f, t)
                    return pipe.mapn(
                        func.seq(f, t),
                        models.l.platformEdgeL * range,
                        models.l.platformEdgeR * range,
                        models.l.platformSurface * range,
                        models.l.platformSurfaceEx * range,
                        lc * il * range,
                        rc * il * range,
                        lic * il * range,
                        ric * il * range
                )
                end
                return pipe.new + fn(intersection, #models.l.platformEdgeL)(retriveModels(c, c, commonLength, 0.8))
            end
            
            local function rightPart()
                local lc, rc, lic, ric, c = arcsR.platform.lc, arcsR.platform.rc, arcsR.surface.lc, arcsR.surface.rc, arcsR.surface.c
                local fn = function(f, t)
                    local range = pipe.range(f, t)
                    return pipe.mapn(
                        func.seq(f, t),
                        models.r.platformEdgeL * range,
                        models.r.platformEdgeR * range,
                        models.r.platformSurface * range,
                        models.r.platformSurfaceEx * range,
                        lc * il * range,
                        rc * il * range,
                        lic * il * range,
                        ric * il * range
                )
                end
                return pipe.new + fn(intersection, #models.r.platformEdgeL)(retriveModels(c, commonLength, c, 0.8))
            end
            return
                pipe.new
                + commonParts()
                + leftPart()
                + rightPart()
                + middlePart()
        end
        
        local roofModels = function()
            local function modelSeq(arcs, intersection, commonLength, isLeft)
                local c = arcs.roof.edge.c
                local pc = arcs.roof.edge.c
                
                local roofSurface = pipe.new
                    * pipe.rep(pc - 2)(config.models.roofTop) / config.models.roofExtremity
                    * (function(ls) return ls * pipe.rev() + ls end)
                
                local roofEdge = pipe.new
                    * pipe.rep(pc - 2)(config.models.roofEdge) / config.models.roofCorner
                    * (function(ls) return ls * pipe.rev() + ls end)
                
                local roofEdgeSurface = pipe.new
                    * pipe.rep(pc - 2)(config.models.roofEdgeTop) / config.models.roofEdgeTop
                    * (function(ls) return ls * pipe.rev() + ls end)
                
                local roofEdgeL = roofEdge
                local roofEdgeR = roofEdge
                
                local fn = pipe.mapi(
                    function(m, i) return i >= intersection and i < commonLength and config.models.roofEdgeTop or i ~= commonLength and m or
                        commonLength == 2 * (c - 1) and config.models.roofEdgeTopExtreme or
                        config.models.roofEdgeTopCorner
                    end
                )
                if isLeft then roofEdgeR = roofEdge * fn else roofEdgeL = roofEdge * fn end
                
                return {
                    roofSurface = roofSurface,
                    roofEdge = roofEdge,
                    roofEdgeL = roofEdgeL,
                    roofEdgeR = roofEdgeR,
                    roofEdgeSurface = roofEdgeSurface
                }
            end
            
            local intersection = arcsL.roof.intersection
            local commonLength = arcsL.roof.common
            
            local models = {
                l = modelSeq(arcsL, intersection, commonLength, true),
                r = modelSeq(arcsR, intersection, commonLength, false)
            }
            
            local function commonParts()
                local lc, rc, lic, ric, c = arcsL.roof.edge.lc, arcsR.roof.edge.rc, arcsL.roof.surface.lc, arcsR.roof.surface.rc, arcsL.roof.surface.c
                return pipe.mapn(
                    func.seq(1, intersection - 1),
                    models.l.roofEdge,
                    models.r.roofEdge,
                    models.l.roofSurface,
                    models.l.roofSurface,
                    il(lc), il(rc), il(lic), il(ric)
                )(retriveModels(c, c, c, 1))
            end
            
            local function middlePart()
                local lc, rc, c = arcsL.roof.edge.rc, arcsR.roof.edge.lc, arcsL.roof.surface.c
                local fn = function(f, t)
                    local range = pipe.range(f, t)
                    return pipe.mapn(
                        func.seq(f, t),
                        models.l.roofSurface * pipe.range(f, t - 1) / config.models.roofExtremity,
                        models.l.roofSurface * pipe.range(f, t - 1) / config.models.roofExtremity,
                        lc * il * range,
                        rc * il * range
                )
                end
                return pipe.new + fn(intersection, commonLength)(buildSurface(commonLength, 3))
            end
            
            local function leftPart()
                local lc, rc, lic, ric, c = arcsL.roof.edge.lc, arcsL.roof.edge.rc, arcsL.roof.surface.lc, arcsL.roof.surface.rc, arcsL.roof.surface.c
                local fn = function(f, t)
                    local range = pipe.range(f, t)
                    return pipe.mapn(
                        func.seq(f, t),
                        models.l.roofEdgeL * range,
                        models.l.roofEdgeR * range,
                        models.l.roofSurface * range,
                        models.l.roofSurface * range,
                        lc * il * range,
                        rc * il * range,
                        lic * il * range,
                        ric * il * range
                )
                end
                return pipe.new + fn(intersection, #models.l.roofEdge)(retriveModels(c, c, commonLength, 1))
            end
            
            local function rightPart()
                local lc, rc, lic, ric, c = arcsR.roof.edge.lc, arcsR.roof.edge.rc, arcsR.roof.surface.lc, arcsR.roof.surface.rc, arcsR.roof.surface.c
                local fn = function(f, t)
                    local range = pipe.range(f, t)
                    return pipe.mapn(
                        func.seq(f, t),
                        models.r.roofEdgeL * range,
                        models.r.roofEdgeR * range,
                        models.r.roofSurface * range,
                        models.r.roofSurface * range,
                        lc * il * range,
                        rc * il * range,
                        lic * il * range,
                        ric * il * range
                )
                end
                return pipe.new + fn(intersection, #models.r.roofEdge)(retriveModels(c, commonLength, c, 1))
            end
            
            
            return
                pipe.new
                + commonParts()
                + leftPart()
                + rightPart()
                + middlePart()
                + {
                    buildPoles(
                        pipe.mapn(
                            pipe.range(1, pipe.min()({#arcsL.roof.pole.mc, #arcsR.roof.pole.mc}))(arcsL.roof.pole.mc),
                            pipe.range(1, pipe.min()({#arcsL.roof.pole.mc, #arcsR.roof.pole.mc}))(arcsR.roof.pole.mc)
                        )(function(l, r) return l:avg(r) end)
                        , arcsL.roof.pole.c, 1, arcsL.roof.pole.intersection),
                    buildPoles(arcsL.roof.pole.mc, arcsL.roof.pole.c, arcsL.roof.pole.intersection, arcsL.roof.pole.c * 2 - 1),
                    buildPoles(arcsR.roof.pole.mc, arcsR.roof.pole.c, arcsR.roof.pole.intersection, arcsR.roof.pole.c * 2 - 1)
                }
        end
        
        local chairs =
            pipe.new
            + buildChairs(arcsL.chair.lc, arcsL.chair.rc, arcsL.chair.mc, arcsL.chair.c, arcsL.chair.intersection, arcsL.chair.c * 2 - 1)
            + buildChairs(arcsR.chair.lc, arcsR.chair.rc, arcsR.chair.mc, arcsR.chair.c, arcsR.chair.intersection, arcsR.chair.c * 2 - 1)
            + buildChairs(
                pipe.range(1, pipe.min()({#arcsL.chair.lc, #arcsR.chair.lc}))(arcsL.chair.lc),
                pipe.range(1, pipe.min()({#arcsL.chair.rc, #arcsR.chair.rc}))(arcsR.chair.rc),
                pipe.mapn(
                    pipe.range(1, pipe.min()({#arcsL.chair.mc, #arcsR.chair.mc}))(arcsL.chair.mc),
                    pipe.range(1, pipe.min()({#arcsL.chair.mc, #arcsR.chair.mc}))(arcsR.chair.mc)
                )
                (function(l, r) return l:avg(r) end),
                pipe.min()({arcsL.chair.c, arcsR.chair.c}), 1, arcsL.chair.intersection)
        
        return (platformModels() + (config.roofLength == 0 and {} or roofModels()) + chairs) * pipe.flatten()
    end
end


ust.generateTerrain = function(config)
    return function(arcs)
        return pipe.new
            / {
                equal = pipe.new
                * pipe.mapn(il(arcs.terrain.lc), il(arcs.terrain.rc))
                (function(lc, rc)
                    local size = assembleSize(lc, rc)
                    return pipe.new / size.lt / size.lb / size.rb / size.rt * station.finalizePoly
                end)
            }
    end
end

ust.generateTerrainDual = function(config)
    return function(arcsL, arcsR)
        return pipe.new
            / {
                equal = pipe.new
                * pipe.mapn(il(arcsL.terrain.lc), il(arcsL.terrain.rc))
                (function(lc, rc)
                    local size = assembleSize(lc, rc)
                    return pipe.new / size.lt / size.lb / size.rb / size.rt * station.finalizePoly
                end)
            }
            / {
                equal = pipe.new
                * pipe.mapn(il(arcsR.terrain.lc), il(arcsR.terrain.rc))
                (function(lc, rc)
                    local size = assembleSize(lc, rc)
                    return pipe.new / size.lt / size.lb / size.rb / size.rt * station.finalizePoly
                end)
            }
            / {
                equal = pipe.new
                * pipe.mapn(
                    il(arcsL.terrain.rc * pipe.range(arcsL.terrain.intersection, arcsL.terrain.common + 1)),
                    il(arcsR.terrain.lc * pipe.range(arcsR.terrain.intersection, arcsR.terrain.common + 1))
                )
                (function(lc, rc)
                    local size = assembleSize(lc, rc)
                    return pipe.new / size.lt / size.lb / size.rb / size.rt * station.finalizePoly
                end)
            }
    end
end

ust.generateTrackTerrain = function(config)
    return function(arc)
        local ar = arc()()
        local arl = ar(-0.5 * config.wTrack)
        local arr = ar(0.5 * config.wTrack)
        local lc, rc, c = ust.bitLatCoords(5)(arl, arr)
        return pipe.new
            / {
                equal = pipe.new
                * pipe.mapn(il(lc), il(rc))
                (function(lc, rc)
                    local size = assembleSize(lc, rc)
                    return pipe.new / size.lt / size.lb / size.rb / size.rt * station.finalizePoly
                end)
            }
    end
end

ust.coordIntersection = function(coordL, coordR)
    local seqL = func.mapi(il(coordL), function(s, i) return {s = s.s, i = s.i, l = line.byPtPt(s.s, s.i), index = i} end)
    local seqR = func.mapi(il(coordR), function(s, i) return {s = s.s, i = s.i, l = line.byPtPt(s.s, s.i), index = i} end)
    
    local r = func.fold(seqL, false, function(result, l)
        if result then return result
        else
            local r = func.fold(seqR, false,
                function(result, r)
                    if result then return result
                    else
                        local x = l.l - r.l
                        return (x - l.s):dot(x - l.i) <= 0 and (x - r.s):dot(x - r.i) <= 0 and (r.index + 1)
                    end
                end)
            return r and {(l.index + 1), r}
        end
    end)
    or
    pipe.exec * function()
        l = seqL[1]
        r = seqR[1]
        local x = l.l - r.l
        return ((l.s - x):dot(l.s - l.i) <= 0 and (r.s - x):dot(r.s - r.i) <= 0) and {2, 2}
    end
    or
    pipe.exec * function()
        l = seqL[2]
        r = seqR[2]
        local x = l.l - r.l
        return ((l.s - x):dot(l.s - l.i) <= 0 and (r.s - x):dot(r.s - r.i) <= 0) and {2, 2}
    end
    or {#seqL, #seqR}
    
    return table.unpack(r)
end

ust.allArcs = function(arcGen, config)
    local refZ = config.hPlatform + 0.53
    return pipe.map(function(p)
        if (#p == 2) then
            local arcL, arcR = table.unpack(p)
            
            local lane = {
                l = arcL(refZ)(function(l) return l - 3 end),
                r = arcR(refZ)(function(l) return l - 3 end)
            }
            local general = {
                l = arcL(refZ)(),
                r = arcR(refZ)()
            }
            local roof = {
                l = arcL(refZ)(function(l) return l * config.roofLength end),
                r = arcR(refZ)(function(l) return l * config.roofLength end)
            }
            local terrain = {
                l = arcL()(function(l) return l + 5 end),
                r = arcR()(function(l) return l + 5 end)
            }
            
            local arcGen = function(p, o) return {
                l = p.l(o),
                r = p.r(-o)
            } end
            
            local arcs = {
                lane = arcGen(lane, 1),
                laneEdge = arcGen(lane, -0.5),
                edge = arcGen(general, -0.5),
                surface = arcGen(general, 0.3),
                access = arcGen(general, -4.25),
                roof = {
                    edge = arcGen(roof, -0.5),
                    surface = arcGen(roof, 0.5)
                },
                terrain = arcGen(terrain, -0.5)
            }
            local mc = function(lc, rc) return func.map2(lc, rc, function(l, r) return l:avg(r) end) end
            
            local lc, rc, lec, rec, c = ust.bitLatCoords(5)(arcs.lane.l, arcs.lane.r, arcs.laneEdge.l, arcs.laneEdge.r)
            local lsc, rsc, lac, rac, lsuc, rsuc, ltc, rtc, sc = ust.bitLatCoords(5)(arcs.edge.l, arcs.edge.r, arcs.access.l, arcs.access.r, arcs.surface.l, arcs.surface.r, arcs.terrain.l, arcs.terrain.r)
            local lcc, rcc, cc = ust.bitLatCoords(10)(arcs.edge.l, arcs.edge.r)
            local lpc, rpc, lpic, rpic, pc = ust.bitLatCoords(5)(arcs.roof.edge.l, arcs.roof.edge.r, arcs.roof.surface.l, arcs.roof.surface.r)
            local lppc, rppc, ppc = ust.bitLatCoords(10)(arcs.roof.edge.l, arcs.roof.edge.r)
            return {
                [1] = arcL,
                [2] = arcR,
                lane = func.with(arcs.lane, {lc = lc, rc = rc, mc = mc(lc, rc), c = c}),
                laneEdge = func.with(arcs.laneEdge, {lc = lec, rc = rec, mc = mc(lec, rec), c = c}),
                platform = func.with(arcs.edge, {lc = lsc, rc = rsc, mc = mc(lsc, rsc), c = sc}),
                access = func.with(arcs.access, {lc = lac, rc = rac, mc = mc(lac, rac), c = sc}),
                surface = func.with(arcs.surface, {lc = lsuc, rc = rsuc, mc = mc(lsuc, rsuc), c = sc}),
                chair = func.with(arcs.edge, {lc = lcc, rc = rcc, mc = mc(lcc, rcc), c = cc}),
                roof = {
                    edge = func.with(arcs.roof.edge, {lc = lpc, rc = rpc, mc = mc(lpc, rpc), c = pc}),
                    surface = func.with(arcs.roof.surface, {lc = lpic, rc = rpic, mc = mc(lpic, rpic), c = pc}),
                    pole = func.with(arcs.roof.edge, {lc = lppc, rc = rppc, mc = mc(lppc, rppc), c = ppc})
                },
                terrain = func.with(arcs.terrain, {lc = ltc, rc = rtc, mc = mc(ltc, rtc), c = sc}),
                hasLower = (sc - 5 - floor(sc * 0.5) > 0) and (c - 5 - floor(c * 0.5) > 0),
                hasUpper = (sc + 5 + floor(sc * 0.5) <= #lsc) and (c + 5 + floor(c * 0.5) <= #lc)
            }
        else
            return p
        end
    end)
end

ust.build = function(config, fitModel, entries)
    local generateEdges = ust.generateEdges
    local generateModels = ust.generateModels(fitModel, config)
    local generateModelsDual = ust.generateModelsDual(fitModel, config)
    local generateTerminals = ust.generateTerminals(config)
    local generateTerminalsDual = ust.generateTerminalsDual(config)
    local generateFences = ust.generateFences(fitModel, config)
    local generateTerrain = ust.generateTerrain(config)
    local generateTerrainDual = ust.generateTerrainDual(config)
    local generateTrackTerrain = ust.generateTrackTerrain(config)
    local function build(edges, terminals, terminalsGroup, models, terrain, gr, ...)
        local isLeftmost = #models == 0
        local isRightmost = #{...} == 0
        if (gr == nil) then
            local buildEntryPath = entries * pipe.map(pipe.select("access")) * pipe.flatten()
            local buildFace = entries * pipe.map(pipe.select("terrain")) * pipe.flatten()
            local buildAccessRoad = entries * pipe.map(pipe.select("street")) * pipe.flatten()
            local buildLanes = entries * pipe.map(pipe.select("lane")) * pipe.flatten()
            return edges, buildAccessRoad, terminals, terminalsGroup,
                (models + buildEntryPath + buildLanes) * pipe.filter(pipe.noop()),
                terrain + buildFace
        elseif (#gr == 3 and #gr[1] == 1 and #gr[2] > 1 and #gr[3] == 1) then
            local edges = generateEdges(edges, true, gr[1][1])
            local edges = generateEdges(edges, false, gr[3][1])
            local terminals, terminalsGroup = generateTerminals(edges, terminals, terminalsGroup, gr[2], {true, true})
            return build(
                edges,
                terminals,
                terminalsGroup,
                models + generateModels(gr[2])
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, true) or {})
                + (config.rightFences and isRightmost and generateFences(gr[3][1], false, true) or {}),
                terrain + generateTerrain(gr[2]) + generateTrackTerrain(gr[1][1]) + generateTrackTerrain(gr[3][1]),
                ...)
        elseif (#gr == 2 and #gr[1] == 1 and #gr[2] > 1) then
            local edges = generateEdges(edges, true, gr[1][1])
            local terminals, terminalsGroup = generateTerminals(edges, terminals, terminalsGroup, gr[2], {true, false})
            return build(
                edges,
                terminals,
                terminalsGroup,
                models
                + generateModels(gr[2], entries[3].edgeBuilder(isLeftmost, isRightmost))
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, true, entries[3].fenceFilter) or {})
                + (config.rightFences and isRightmost and generateFences(gr[2][2], false, false, entries[3].fenceFilter) or {}),
                terrain + generateTerrain(gr[2]) + generateTrackTerrain(gr[1][1]),
                ...)
        elseif (#gr == 2 and #gr[1] > 1 and #gr[2] == 1) then
            local edges = generateEdges(edges, false, gr[2][1])
            local terminals, terminalsGroup = generateTerminals(edges, terminals, terminalsGroup, gr[1], {false, true})
            return build(edges,
                terminals,
                terminalsGroup,
                models
                + generateModels(gr[1], entries[3].edgeBuilder(isLeftmost, isRightmost))
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, false, entries[3].fenceFilter) or {})
                + (config.rightFences and isRightmost and generateFences(gr[2][1], false, true, entries[3].fenceFilter) or {}),
                terrain + generateTerrain(gr[1]) + generateTrackTerrain(gr[2][1]),
                ...)
        elseif (#gr == 1 and #gr[1] > 1) then
            local terminals, terminalsGroup = generateTerminals(edges, terminals, terminalsGroup, gr[1], {false, false})
            return build(edges,
                terminals,
                terminalsGroup,
                models
                + generateModels(gr[1], entries[3].edgeBuilder(isLeftmost, isRightmost))
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, false, entries[3].fenceFilter) or {})
                + (config.rightFences and isRightmost and generateFences(gr[1][1], false, false, entries[3].fenceFilter) or {}),
                terrain + generateTerrain(gr[1]),
                ...)
        elseif (#gr == 2 and #gr[1] > 1 and #gr[2] > 1) then
            local terminals, terminalsGroup = generateTerminalsDual(edges, terminals, terminalsGroup, gr[1], gr[2], {false, false})
            return build(edges,
                terminals,
                terminalsGroup,
                models
                + generateModelsDual(gr[1], gr[2], entries[3].edgeBuilder(isLeftmost, isRightmost))
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, false, entries[3].fenceFilter) or {})
                + (config.rightFences and isRightmost and generateFences(gr[2][2], false, false, entries[3].fenceFilter) or {}),
                terrain + generateTerrainDual(gr[1], gr[2]),
                ...)
        elseif (#gr == 3 and #gr[1] > 1 and #gr[2] > 1 and #gr[3] == 1) then
            local edges = generateEdges(edges, false, gr[3][1])
            local terminals, terminalsGroup = generateTerminalsDual(edges, terminals, terminalsGroup, gr[1], gr[2], {false, true})
            return build(edges,
                terminals,
                terminalsGroup,
                models
                + generateModelsDual(gr[1], gr[2], entries[3].edgeBuilder(isLeftmost, isRightmost))
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, false, entries[3].fenceFilter) or {})
                + (config.rightFences and isRightmost and generateFences(gr[3][1], false, true, entries[3].fenceFilter) or {}),
                terrain + generateTerrainDual(gr[1], gr[2]),
                ...)
        elseif (#gr == 4 and #gr[1] == 1 and #gr[2] > 1 and #gr[3] > 1 and #gr[4] == 1) then
            local edges = generateEdges(edges, true, gr[1][1])
            local edges = generateEdges(edges, false, gr[4][1])
            local terminals, terminalsGroup = generateTerminalsDual(edges, terminals, terminalsGroup, gr[2], gr[3], {true, true})
            return build(edges,
                terminals,
                terminalsGroup,
                models
                + generateModelsDual(gr[2], gr[3], entries[3].edgeBuilder(isLeftmost, isRightmost))
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, true, entries[3].fenceFilter) or {})
                + (config.rightFences and isRightmost and generateFences(gr[4][1], false, true, entries[3].fenceFilter) or {}),
                terrain + generateTerrainDual(gr[2], gr[3]),
                ...)
        else
            local edges = generateEdges(edges, false, gr[1][1])
            return build(edges,
                terminals,
                terminalsGroup,
                models,
                terrain + generateTrackTerrain(gr[1][1]),
                ...)
        end
    end
    return build
end

local platformArcGenParam = function(la, ra, rInner, pWe)
    local mlpt = la:pt(la.inf)
    local mrpt = ra:pt(ra.inf)
    
    local mvec = (mrpt - mlpt):normalized()
    local f = mvec:dot(mlpt - la.o) > 0 and 1 or -1
    
    mvec = (mlpt - la.o):normalized()
    
    local elpt = la:pt(la.sup)
    local erpt = (elpt - la.o):normalized() * f * pWe + elpt
    
    local mln = line.byVecPt(mvec, mrpt)
    local pln = line.byVecPt(mvec .. coor.rotZ(pi * 0.5), erpt)
    local xpt = (mln - pln):withZ(0)
    
    local rvec = (xpt - mrpt):dot(xpt - la.o) * rInner
    local cvec = (elpt - la.o):dot(mlpt - la.o)
    
    local lenP2 = (xpt - erpt):length2()
    local lenT = (xpt - mrpt):length()
    local r = (lenP2 / lenT + lenT) * 0.5 * (rvec < 0 and 1 or -1) * (cvec > 0 and 1 or -1)
    
    local o = mrpt + (xpt - mrpt):normalized() * abs(r)
    
    return r, o
end

ust.platformArcGen = function(tW, pW)
    return function(arcPacker)
        return function(r, o, lPct, oPct, pWe, isRight)
            local rInner = r - (isRight and 1 or -1) * (0.5 * tW)
            local rOuter = r - (isRight and 1 or -1) * (0.5 * tW + pW)
            local inner = arcPacker(rInner, o, lPct, oPct)
            local li, ls = table.unpack(inner()()())
            local ri, rs = table.unpack(arcPacker(rOuter, o, lPct * abs(rOuter - rInner) / rOuter, oPct)()()())
            
            local r, o = platformArcGenParam(li, ri, rInner, pWe)
            
            return r + 0.5 * tW * (isRight and 1 or -1), o, {
                isRight and inner or arcPacker(r, o, lPct, oPct),
                isRight and arcPacker(r, o, lPct, oPct) or inner
            }
        end
    end
end

ust.platformDualArcGen = function(tW, pW)
    return function(arcPacker)
        return function(rA, oA, rB, oB, lPct, oPct, pWe, isRight)
            local rInnerA = rA - (isRight and 1 or -1) * (0.5 * tW)
            local rOuterA = rA - (isRight and 1 or -1) * (0.5 * tW + pW)
            local rInnerB = rB - (isRight and 1 or -1) * (0.5 * tW)
            local rOuterB = rB - (isRight and 1 or -1) * (0.5 * tW + pW)
            local inner = arcPacker(rInnerA, oA, rInnerB, oB, lPct, oPct)
            local li, ls = table.unpack(inner()()())
            local ri, rs = table.unpack(arcPacker(rOuterA, oA, rOuterB, oB, lPct, oPct)()()())
            
            local rA, oA = platformArcGenParam(li, ri, rInnerA, pWe)
            local rB, oB = platformArcGenParam(ls, rs, rInnerB, pWe)
            
            return rA + 0.5 * tW * (isRight and 1 or -1), oA, rB + 0.5 * tW * (isRight and 1 or -1), oB, {
                isRight and inner or arcPacker(rA, oA, rB, oB, lPct, oPct),
                isRight and arcPacker(rA, oA, rB, oB, lPct, oPct) or inner
            }
        end
    end
end


local function trackGrouping(result, ar1, ar2, ar3, ar4, ...)
    if (ar1 == nil) then return table.unpack(result) end
    
    if (ar1 and ar2 and ar3) then
        if #ar1 == 1 and #ar2 == 2 and #ar3 == 1 then
            if (ar4 and #ar4 == 2 and #{...} == 0) then
                return trackGrouping(result / {ar1, ar2} / {ar3, ar4}, ...)
            else
                return trackGrouping(result / {ar1, ar2, ar3}, ar4, ...)
            end
        elseif #ar1 == 2 and #ar2 == 1 and #ar3 == 2 and not ar4 then
            return trackGrouping(result / {ar1} / {ar2, ar3}, ar4, ...)
        elseif #ar1 == 1 and #ar2 == 2 and #ar3 == 2 and ar4 and #ar4 == 1 then
            return trackGrouping(result / {ar1, ar2, ar3, ar4}, ...)
        elseif #ar1 == 2 and #ar2 == 2 and #ar3 == 1 and ar4 and #ar4 == 2 then
            return trackGrouping(result / {ar1, ar2} / {ar3, ar4}, ...)
        elseif #ar1 == 2 and #ar2 == 2 and #ar3 == 1 then
            return trackGrouping(result / {ar1, ar2, ar3}, ar4, ...)
        end
    end
    
    if (ar1 and ar2) then
        if (#ar1 + #ar2 == 3) then
            return trackGrouping(result / {ar1, ar2}, ar3, ar4, ...)
        end
    end
    
    return trackGrouping(result / {ar1}, ar2, ar3, ar4, ...)
end

ust.trackGrouping = trackGrouping

ust.entryConfig = function(config, allArcs, arcCoords, ignoreMain)
    local isLeftTrack = #allArcs[1] == 1
    local isRightTrack = #allArcs[#allArcs] == 1
    local withoutMain = function(i) return ignoreMain or (not config.entries.main.model) or config.entries.main.pos + 2 ~= i end
    return {
        main = isLeftTrack and {pos = false, model = false} or config.entries.main,
        street = {
            func.mapi(config.entries.street[1], function(t, i) return t and withoutMain(i) and not isLeftTrack end),
            func.mapi(config.entries.street[2], function(t, i) return t and not isRightTrack end),
        },
        underground = {
            func.mapi(config.entries.underground[1], function(t, i) return
                (t or (isLeftTrack and config.entries.street[1][i])) and withoutMain(i) end),
            func.mapi(config.entries.underground[2], function(t, i) return t or (isRightTrack and config.entries.street[2][i]) end),
        },
        allArcs = allArcs,
        arcCoords = arcCoords
    }
end

ust.models = function(prefixM)
    local prefixM = function(p) return prefixM .. p end
    return {
        surface = prefixM("platform/platform_surface"),
        extremity = prefixM("platform/platform_extremity"),
        corner = prefixM("platform/platform_corner"),
        edge = prefixM("platform/platform_edge"),
        edgeSurface = prefixM("platform/platform_edge_surface"),
        edgeSurfaceCorner = prefixM("platform/platform_edge_surface_corner"),
        edgeSurfaceExtreme = prefixM("platform/platform_edge_surface_extreme"),
        edgeOpen = prefixM("platform/platform_edge_open"),
        roofTop = prefixM("platform/platform_roof_top"),
        roofExtremity = prefixM("platform/platform_roof_extremity"),
        roofEdge = prefixM("platform/platform_roof_edge"),
        roofEdgeTop = prefixM("platform/platform_roof_edge_top"),
        roofEdgeTopCorner = prefixM("platform/platform_roof_edge_top_corner"),
        roofEdgeTopExtreme = prefixM("platform/platform_roof_edge_top_extreme"),
        roofCorner = prefixM("platform/platform_roof_corner"),
        roofPole = prefixM("platform/platform_roof_pole"),
        roofPoleExtreme = prefixM("platform/platform_roof_pole_extreme_1"),
        stair = prefixM("platform/platform_stair"),
        trash = prefixM("platform/platform_trash"),
        chair = prefixM("platform/platform_chair"),
        access = prefixM("platform/platform_access_t"),
        underground = prefixM("underground_entry.mdl")
    }
end

ust.fencesGen = function(colorCode, styleCode)
    return {
        "ust/fences/" .. tostring(colorCode) .. "/platform_fences_" .. tostring(styleCode) .. ".mdl",
        "ust/fences/" .. tostring(colorCode) .. "/platform_fences_pole_" .. tostring(styleCode) .. ".mdl",
    }
end

ust.findIntersections = function(config)
    return function(allArcs)
        for i = 1, #allArcs - 1 do
            if #allArcs[i] > 1 and #allArcs[i + 1] > 1 then
                local arcsL, arcsR = allArcs[i], allArcs[i + 1]
                local greater = function(x, y) return x > y and x or y end
                
                local retriveBaseParams = function(arcsL, arcsR)
                    local intersection = greater(ust.coordIntersection(arcsL.rc, arcsR.lc))
                    
                    local max = arcsL.c > arcsR.c and 2 * (arcsR.c - 1) or 2 * (arcsL.c - 1)
                    local r =
                        pipe.new
                        * (pipe.mapn(
                            func.seq(intersection, max),
                            arcsL.rc * pipe.range(intersection, max + 1) * il,
                            arcsR.lc * pipe.range(intersection, max + 1) * il
                        )
                        (function(i, l, r)
                            local vecL = (l.i - l.s):withZ(0)
                            local vecR = (r.i - l.s):withZ(0)
                            local vec = (r.s - l.s):withZ(0)
                            return vec:cross(vecL).z > 0 and vec:cross(vecR).z < 0 and i or false
                        end
                        ))
                        * pipe.filter(pipe.noop())
                        * function(r) return #r > 0 and r[#r] or max end
                    return intersection, intersection + floor(config.lengthMiddlePlatform * (r - intersection))
                end
                
                local intersection, commonLength = retriveBaseParams(arcsL.platform, arcsR.platform)
                
                local ln = line.byPtPt(arcsL.surface.rc[commonLength + 1], arcsR.surface.lc[commonLength + 1])
                local retriveParams = function(arcsL, arcsR)
                    local intersection = greater(ust.coordIntersection(arcsL.rc, arcsR.lc))
                    local max = arcsL.c > arcsR.c and 2 * (arcsR.c - 1) or 2 * (arcsL.c - 1)
                    local commonLength =
                        pipe.exec
                        * function()
                            local r =
                                pipe.new
                                * (pipe.mapn(
                                    func.seq(intersection, max - 1),
                                    arcsL.rc * pipe.range(intersection, max) * il,
                                    arcsR.lc * pipe.range(intersection, max) * il
                                )
                                (function(i, l, r)
                                    local xL = line.byPtPt(l.i, l.s) - ln
                                    local xR = line.byPtPt(r.i, r.s) - ln
                                    return ((l.i - xL):dot(l.s - xL) < 0 or (r.i - xR):dot(r.s - xR) < 0) and i or false
                                end)
                                )
                                * pipe.filter(pipe.noop())
                                * function(r) return #r > 0 and r[1] or max end
                            return floor(r)
                        end
                    return intersection, commonLength
                end
                
                local roofIntersection, roofCommonLength = retriveParams(arcsL.roof.edge, arcsR.roof.edge)
                local roofPoleIntersection = retriveBaseParams(arcsL.roof.pole, arcsR.roof.pole)
                local chairIntersection = retriveBaseParams(arcsL.chair, arcsR.chair)
                local laneIntersection, laneCommonLength = retriveParams(arcsL.laneEdge, arcsR.laneEdge)
                
                
                local ptL = arcsL.surface.lc[intersection]
                local ptR = arcsR.surface.rc[intersection]
                local vec = ptR - ptL
                
                arcsL.platform.intersection = intersection
                arcsR.platform.intersection = intersection
                arcsL.lane.intersection = laneIntersection
                arcsR.lane.intersection = laneIntersection
                arcsL.terrain.intersection = intersection
                arcsR.terrain.intersection = intersection
                
                arcsL.lane.common = laneCommonLength
                arcsR.lane.common = laneCommonLength
                arcsL.platform.common = commonLength
                arcsR.platform.common = commonLength
                arcsL.terrain.common = commonLength
                arcsR.terrain.common = commonLength
                
                arcsL.platformO = func.with(arcsL.platform, {})
                arcsR.platformO = func.with(arcsR.platform, {})
                
                if (intersection < #arcsL.surface.lc and intersection < #arcsR.surface.lc) then
                    
                    local lL = (arcsL.surface.lc[intersection + 1] - arcsL.surface.rc[intersection + 1]):length()
                    local rL = (arcsR.surface.lc[intersection + 1] - arcsR.surface.rc[intersection + 1]):length()
                    local mL = (arcsR.surface.lc[intersection + 1] - arcsL.surface.rc[intersection + 1]):length()
                    
                    
                    arcsL.platform.rc = func.with(arcsL.platform.rc, {[intersection] = ptL + vec * (lL / (lL + rL + mL))})
                    arcsR.platform.lc = func.with(arcsR.platform.lc, {[intersection] = ptL + vec * ((mL + lL) / (lL + rL + mL))})
                    arcsL.surface.rc = func.with(arcsL.surface.rc, {[intersection] = arcsL.platform.rc[intersection] - vec:normalized() * 0.8})
                    arcsR.surface.lc = func.with(arcsR.surface.lc, {[intersection] = arcsR.platform.lc[intersection] + vec:normalized() * 0.8})
                
                end
                
                if (config.roofLength > 0) then
                    local ptL = arcsL.roof.edge.lc[roofIntersection]
                    local ptR = arcsR.roof.edge.rc[roofIntersection]
                    local vec = ptR - ptL
                    
                    arcsL.roof.intersection = roofIntersection
                    arcsL.roof.common = roofCommonLength
                    arcsR.roof.intersection = roofIntersection
                    arcsR.roof.common = roofCommonLength
                    
                    if (roofIntersection < #arcsL.roof.edge.lc and roofIntersection < #arcsR.roof.edge.lc) then
                        local lL = (arcsL.roof.edge.lc[roofIntersection + 1] - arcsL.roof.edge.rc[roofIntersection + 1]):length()
                        local rL = (arcsR.roof.edge.lc[roofIntersection + 1] - arcsR.roof.edge.rc[roofIntersection + 1]):length()
                        local mL = (arcsR.roof.edge.lc[roofIntersection + 1] - arcsL.roof.edge.rc[roofIntersection + 1]):length()
                        
                        
                        arcsL.roof.edge.rc = func.with(arcsL.roof.edge.rc, {[roofIntersection] = ptL + vec * (lL / (lL + rL + mL))})
                        arcsR.roof.edge.lc = func.with(arcsR.roof.edge.lc, {[roofIntersection] = ptL + vec * ((mL + lL) / (lL + rL + mL))})
                        arcsL.roof.surface.rc = func.with(arcsL.roof.surface.rc, {[roofIntersection] = arcsL.roof.edge.rc[roofIntersection] - vec:normalized() * 0.8})
                        arcsR.roof.surface.lc = func.with(arcsR.roof.surface.lc, {[roofIntersection] = arcsR.roof.edge.lc[roofIntersection] + vec:normalized() * 0.8})
                    end
                    
                    arcsL.roof.pole.intersection = roofPoleIntersection
                    arcsR.roof.pole.intersection = roofPoleIntersection
                    arcsL.chair.intersection = chairIntersection
                    arcsR.chair.intersection = chairIntersection
                end
            end
        end
        return allArcs
    end
end


ust.defaultParams = function(params)
    local defParams = params()
    return function(param)
        local function limiter(d, u)
            return function(v) return v and v < u and v or d end
        end
        param.trackType = param.trackType or 0
        param.catenary = param.catenary or 0
        
        func.forEach(
            func.filter(defParams, function(p) return p.key ~= "tramTrack" end),
            function(i)param[i.key] = limiter(i.defaultIndex or 0, #i.values)(param[i.key]) end)
        return param
    end
end

ust.safeBuild = function(params, updateFn)
    local defaultParams = ust.defaultParams(params)
    local paramsOnFail = params() *
        pipe.mapPair(function(i) return i.key, i.defaultIndex or 0 end)
    
    return function(param)
        local r, result = xpcall(
            updateFn,
            function(e)
                print("========================")
                print("Ultimate Station failure")
                print("Algorithm failure:", debug.traceback())
                print("Params:")
                func.forEach(
                    params() * pipe.filter(function(i) return param[i.key] ~= (i.defaultIndex or 0) end),
                    function(i)print(i.key .. ": " .. param[i.key]) end)
                print("End of Ultimate Station failure")
                print("========================")
            end,
            defaultParams(param)
        )
        return r and result or updateFn(defaultParams(paramsOnFail))
    -- return updateFn(defaultParams(param))
    end
end

return ust
