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
        assert(#intInf == 2)
        assert(#intSup == 2)
        
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

ust.unitLane = function(f, t) return station.newModel("ust/person_lane.mdl", ust.mRot(t - f), coor.trans(f)) end

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
                    l = station.newModel(enablers[1] and "ust/terminal_lane.mdl" or "ust/standard_lane.mdl", ust.mRot(lc.i - lc.s), coor.trans(lc.s)),
                    r = station.newModel(enablers[2] and "ust/terminal_lane.mdl" or "ust/standard_lane.mdl", ust.mRot(rc.s - rc.i), coor.trans(rc.i)),
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

ust.generateModels = function(fitModel, config)
    local tZ = coor.transZ(config.hPlatform - 1.4)
    local platformZ = config.hPlatform + 0.53
    
    return function(arcs, edgeBuilder)
        local edgeBuilder = edgeBuilder or function(platformEdgeO, _) return platformEdgeO, platformEdgeO end
        
        local lc, rc, lic, ric, c = arcs.platform.lc, arcs.platform.rc, arcs.surface.lc, arcs.surface.rc, arcs.surface.c
        local lpc, rpc, lpic, rpic, pc = arcs.roof.edge.lc, arcs.roof.edge.rc, arcs.roof.surface.lc, arcs.roof.surface.rc, arcs.roof.edge.c
        local lpp, rpp, ppc = arcs.roof.pole.lc, arcs.roof.pole.rc, arcs.roof.pole.c
        local lcc, rcc, cc = arcs.chair.lc, arcs.chair.rc, arcs.chair.c
        
        local platformSurface = pipe.new
            * pipe.rep(c - 2)(config.models.surface)
            * pipe.mapi(function(p, i) return (i == (c > 5 and 4 or 2) or i == floor(c * 0.5) + 4) and config.models.stair or config.models.surface end)
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
        
        local newModels = pipe.mapn(platformEdgeL, platformEdgeR, platformSurface, platformSurfaceEx, il(lc), il(rc), il(lic), il(ric), func.seq(1, c * 2 - 1))
            (function(el, er, s, sx, lc, rc, lic, ric, i)
                local lc = i >= c and lc or {s = lc.i, i = lc.s}
                local rc = i >= c and rc or {s = rc.i, i = rc.s}
                local lic = i >= c and lic or {s = lic.i, i = lic.s}
                local ric = i >= c and ric or {s = ric.i, i = ric.s}
                
                local sizeL = assembleSize(lc, lic)
                local sizeR = assembleSize(ric, rc)
                local sizeS = assembleSize(lic, ric)
                
                local surfaces = pipe.exec * function()
                    local vecs = {
                        top = sizeS.rt - sizeS.lt,
                        bottom = sizeS.rb - sizeS.lb
                    }
                    if (vecs.top:length() < 8 and vecs.bottom:length() < 8) then
                        return pipe.new
                            / station.newModel(s .. "_br.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS, false, false))
                            / station.newModel(s .. "_tl.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS, true, true))
                    else
                        local sizeS1 = {
                            lb = sizeS.lb,
                            lt = sizeS.lt,
                            rb = sizeS.lb + vecs.bottom / 3,
                            rt = sizeS.lt + vecs.top / 3,
                        }
                        local sizeS2 = {
                            lb = sizeS1.rb,
                            lt = sizeS1.rt,
                            rb = sizeS1.rb + vecs.bottom / 3,
                            rt = sizeS1.rt + vecs.top / 3,
                        }
                        local sizeS3 = {
                            lb = sizeS2.rb,
                            lt = sizeS2.rt,
                            rb = sizeS.rb,
                            rt = sizeS.rt,
                        }
                        return pipe.new
                            / station.newModel(sx .. "_br.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS1, false, false))
                            / station.newModel(sx .. "_tl.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS1, true, true))
                            / station.newModel(s .. "_br.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS2, false, false))
                            / station.newModel(s .. "_tl.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS2, true, true))
                            / station.newModel(sx .. "_br.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS3, false, false))
                            / station.newModel(sx .. "_tl.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS3, true, true))
                    end
                end
                
                return surfaces
                    / station.newModel(el .. "_br.mdl", tZ, fitModel(0.8, 5, platformZ, sizeL, false, false))
                    / station.newModel(el .. "_tl.mdl", tZ, fitModel(0.8, 5, platformZ, sizeL, true, true))
                    / station.newModel(er .. "_bl.mdl", tZ, fitModel(0.8, 5, platformZ, sizeR, false, true))
                    / station.newModel(er .. "_tr.mdl", tZ, fitModel(0.8, 5, platformZ, sizeR, true, false))
            end)
        
        
        local platformChairs = pipe.new
            * func.seq(1, cc - 1)
            * pipe.map(function(i)
                return cc > 3 and i ~= 2 and i % floor(cc * 0.5) ~= 2 and i ~= cc - 1 and (i % 6 == 4 or (i - 1) % 6 == 4 or (i + 1) % 6 == 4) and
                    (i % 3 ~= 1 and config.models.chair .. ".mdl" or config.models.trash .. ".mdl")
            end)
            * (function(ls) return ls * pipe.rev() + {cc < 6 and config.models.chair .. ".mdl"} + ls end)
        
        local chairs = pipe.mapn(lcc, rcc, platformChairs)
            (function(lc, rc, m)
                return (not m) and {} or
                    {
                        station.newModel(m,
                            quat.byVec(coor.xyz(0, i == 1 and 1 or -1, 0), (rc - lc):withZ(0) .. coor.rotZ(0.5 * pi)):mRot(),
                            coor.trans(lc:avg(rc)))
                    }
            end)
        
        local newRoof = config.roofLength == 0
            and {}
            or pipe.new * pipe.mapn(roofEdge, roofSurface, il(lpc), il(lpic), il(rpic), il(rpc), func.seq(1, pc * 2 - 1))
            (function(e, s, lc, lic, ric, rc, i)
                local lc = i >= pc and lc or {s = lc.i, i = lc.s}
                local rc = i >= pc and rc or {s = rc.i, i = rc.s}
                local lic = i >= pc and lic or {s = lic.i, i = lic.s}
                local ric = i >= pc and ric or {s = ric.i, i = ric.s}
                
                local sizeL = assembleSize(lc, lic)
                local sizeR = assembleSize(ric, rc)
                local sizeS = assembleSize(lic, ric)
                return {
                    station.newModel(s .. "_br.mdl", tZ, fitModel(3, 5, platformZ, sizeS, false, false)),
                    station.newModel(s .. "_tl.mdl", tZ, fitModel(3, 5, platformZ, sizeS, true, true)),
                    station.newModel(e .. "_br.mdl", tZ, fitModel(1, 5, platformZ, sizeL, false, false)),
                    station.newModel(e .. "_tl.mdl", tZ, fitModel(1, 5, platformZ, sizeL, true, true)),
                    station.newModel(e .. "_br.mdl", tZ, coor.flipX(), fitModel(1, 5, platformZ, sizeR, false, true)),
                    station.newModel(e .. "_tl.mdl", tZ, coor.flipX(), fitModel(1, 5, platformZ, sizeR, true, false))
                }
            end)
            / pipe.mapn(il(lpp), il(rpp), func.seq(1, ppc * 2 - 1))
            (function(lc, rc, i)
                local lc = i >= ppc and lc or {s = lc.i, i = lc.s}
                local rc = i >= ppc and rc or {s = rc.i, i = rc.s}
                local vecPo = lc.i:avg(rc.i) - lc.s:avg(rc.s)
                return station.newModel(config.models.roofPole .. ".mdl", tZ, coor.flipY(),
                    coor.scaleY(vecPo:length() / 10), quat.byVec(coor.xyz(0, 5, 0), vecPo):mRot(),
                    coor.trans(lc.i:avg(rc.i, lc.s, rc.s)), coor.transZ(-platformZ))
            end)
        
        
        return (pipe.new / newModels / newRoof / chairs) * pipe.flatten() * pipe.flatten()
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
                edge = arcGen(general, -0.5),
                surface = arcGen(general, 0.3),
                access = arcGen(general, -4.25),
                roof = {
                    edge = arcGen(roof, -0.5),
                    surface = arcGen(roof, 0.5)
                },
                terrain = arcGen(terrain, -0.5)
            }
            
            local lc, rc, c = ust.bitLatCoords(5)(arcs.lane.l, arcs.lane.r)
            local lsc, rsc, lac, rac, lsuc, rsuc, sc = ust.bitLatCoords(5)(arcs.edge.l, arcs.edge.r, arcs.access.l, arcs.access.r, arcs.surface.l, arcs.surface.r)
            local lcc, rcc, cc = ust.bitLatCoords(10)(arcs.edge.l, arcs.edge.r)
            local lpc, rpc, lpic, rpic, pc = ust.bitLatCoords(5)(arcs.roof.edge.l, arcs.roof.edge.r, arcs.roof.surface.l, arcs.roof.surface.r)
            local lppc, rppc, ppc = ust.bitLatCoords(10)(arcs.roof.edge.l, arcs.roof.edge.r)
            local ltc, rtc, tc = ust.bitLatCoords(5)(arcs.terrain.l, arcs.terrain.r)
            return {
                [1] = arcL,
                [2] = arcR,
                lane = func.with(arcs.lane, {lc = lc, rc = rc, c = c}),
                platform = func.with(arcs.edge, {lc = lsc, rc = rsc, c = sc}),
                access = func.with(arcs.access, {lc = lac, rc = rac, c = sc}),
                surface = func.with(arcs.surface, {lc = lsuc, rc = rsuc, c = sc}),
                chair = func.with(arcs.edge, {lc = lcc, rc = rcc, c = cc}),
                roof = {
                    edge = func.with(arcs.roof.edge, {lc = lpc, rc = rpc, c = pc}),
                    surface = func.with(arcs.roof.surface, {lc = lpic, rc = rpic, c = pc}),
                    pole = func.with(arcs.roof.edge, {lc = lppc, rc = rppc, c = ppc})
                },
                terrain = func.with(arcs.terrain, {lc = ltc, rc = rtc, c = tc}),
                hasLower = (sc - 5 - floor(sc * 0.5) > 0) and (c - 5 - floor(c * 0.5) > 0),
                hasUpper = (sc + 5 + floor(sc * 0.5) <= #lsc) and (c + 5 + floor(c * 0.5) <= #lc)
            }
        else
            return p
        end
    end)
end

ust.build = function(config, entries, generateEdges, generateModels, generateTerminals, generateFences, generateTerrain)
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
                models + buildEntryPath + buildLanes,
                terrain + buildFace
        elseif (#gr == 3) then
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
    
    local lenP2 = (xpt - erpt):length2()
    local lenT = (xpt - mrpt):length()
    local r = (lenP2 / lenT + lenT) * 0.5 * (rvec < 0 and 1 or -1)
    
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

ust.entryConfig = function(config, allArcs, arcCoords)
    local isLeftTrack = #allArcs[1] == 1
    local isRightTrack = #allArcs[#allArcs] == 1
    
    return {
        main = isLeftTrack and {pos = false, model = false} or config.entries.main,
        street = {
            func.mapi(config.entries.street[1], function(t, i) return t and not (config.entries.main.model and config.entries.main.pos + 2 == i) and not isLeftTrack end),
            func.mapi(config.entries.street[2], function(t, i) return t and not isRightTrack end),
        },
        underground = {
            func.mapi(config.entries.underground[1], function(t, i) return
                (t or (isLeftTrack and config.entries.street[1][i])) and not (config.entries.main.model and config.entries.main.pos + 2 == i) end),
            func.mapi(config.entries.underground[2], function(t, i) return t or (isRightTrack and config.entries.street[2][i]) end),
        },
        allArcs = allArcs,
        arcCoords = allArcs * pipe.filter(function(a) return #a > 1 end)
    }
end

return ust
