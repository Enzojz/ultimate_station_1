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

local dump = require "datadumper"

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

ust.unitLane = function(f, t) return station.newModel("person_lane.mdl", ust.mRot(t - f), coor.trans(f)) end

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
                    l = station.newModel(enablers[1] and "terminal_lane.mdl" or "standard_lane.mdl", ust.mRot(lc.i - lc.s), coor.trans(lc.s)),
                    r = station.newModel(enablers[2] and "terminal_lane.mdl" or "standard_lane.mdl", ust.mRot(rc.s - rc.i), coor.trans(rc.i)),
                    link = (lc.s:avg(lc.i) - rc.s:avg(rc.i)):length() > 0.5 and station.newModel("standard_lane.mdl", ust.mRot(lc.s:avg(lc.i) - rc.s:avg(rc.i)), coor.trans(rc.i:avg(rc.s)))
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
            * pipe.rep(c - 2)("platform_surface")
            * pipe.mapi(function(p, i) return (i == (c > 5 and 4 or 2) or i == floor(c * 0.5) + 4) and "platform_stair" or "platform_surface" end)
            / "platform_extremity"
            * (function(ls) return ls * pipe.rev() + ls end)
        
        local platformSurfaceEx = pipe.new
            * pipe.rep(c - 2)("platform_surface")
            / "platform_extremity"
            * (function(ls) return ls * pipe.rev() + ls end)
        
        local platformEdgeO = pipe.new
            * pipe.rep(c - 2)("platform_edge")
            / "platform_corner"
            * (function(ls) return ls * pipe.rev() + ls end)
        
        local platformEdgeL, platformEdgeR = edgeBuilder(platformEdgeO, c)
        
        local roofSurface = pipe.new
            * pipe.rep(pc - 2)("platform_roof_top")
            / "platform_roof_extremity"
            * (function(ls) return ls * pipe.rev() + ls end)
        
        local roofEdge = pipe.new
            * pipe.rep(pc - 2)("platform_roof_edge")
            / "platform_roof_corner"
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
                    (i % 3 ~= 1 and "platform_chair.mdl" or "platform_trash.mdl")
            end)
            * (function(ls) return ls * pipe.rev() + {cc < 6 and "platform_chair.mdl"} + ls end)
        
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
                return station.newModel("platform_roof_pole.mdl", tZ, coor.flipY(),
                    coor.scaleY(vecPo:length() / 10), quat.byVec(coor.xyz(0, 5, 0), vecPo):mRot(),
                    coor.trans(lc.i:avg(rc.i, lc.s, rc.s)), coor.transZ(-platformZ))
            end)
        
        
        return (pipe.new / newModels / newRoof / chairs) * pipe.flatten() * pipe.flatten()
    end
end

ust.generateTerrain = function(config)
    return function(arcs)
        local l, r = arcs[1]()(function(l) return l + 5 end)(-0.5), arcs[2]()(function(l) return l + 5 end)(0.5)
        local lc, rc = bitLatCoords(5)(l, r)
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


return ust
