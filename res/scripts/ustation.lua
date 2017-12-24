local func = require "ustation/func"
local coor = require "ustation/coor"
local arc = require "ustation/coorarc"
local quat = require "ustation/quaternion"
local station = require "ustation/stationlib"
local pipe = require "ustation/pipe"
local ust = {}

local pi = math.pi
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local pi = math.pi

ust.infi = 1e8

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
    return function(radius, o)
        local initRad = radius > 0 and pi or 0
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

local retriveBiLatCoords = function(length, l, ...)
    local nSeg = (function(x) return (x < 1 or (x % 1 > 0.5)) and ceil(x) or floor(x) end)(l:length() / length)
    local rst = pipe.new * {l, ...}
    local lscale = l:length() / (nSeg * length)
    return table.unpack(
        func.map(rst,
            function(s) return abs(lscale) < 1e-5 and pipe.new * {} or pipe.new * func.seqMap({0, nSeg},
                function(n) return s:pt(s.inf + n * ((s.sup - s.inf) / nSeg)) end)
            end)
)
end

local equalizeArcs = function(...)
    local arcs = pipe.new * {...}
    local ptInf = func.fold(arcs, coor.xyz(0, 0, 0), function(p, ar) return p + ar:pt(ar.inf) end) / #arcs
    local ptSup = func.fold(arcs, coor.xyz(0, 0, 0), function(p, ar) return p + ar:pt(ar.sup) end) / #arcs
    return table.unpack(arcs * pipe.map(function(ar)
        return ar:withLimits({
            inf = ar:rad(ptInf),
            sup = ar:rad(ptSup)
        }
    )
    end)
)
end

ust.equalizeArcs = equalizeArcs

local bitLatCoords = function(l, r, length)
    local lcs1, rcs1 = retriveBiLatCoords(length, equalizeArcs(l[1], r[1]))
    local lcs2, rcs2 = retriveBiLatCoords(length, equalizeArcs(l[2], r[2]))
    return
        lcs1 * pipe.range(2, #lcs1) * pipe.rev() + {lcs1[1]:avg(lcs2[1])} + lcs2 * pipe.range(2, #lcs2),
        rcs1 * pipe.range(2, #rcs1) * pipe.rev() + {rcs1[1]:avg(rcs2[1])} + rcs2 * pipe.range(2, #rcs2),
        #lcs1
end

ust.bitLatCoords = bitLatCoords

local assembleSize = function(l, r, lc, rc)
    return {
        lb = lc.i,
        lt = lc.s,
        rb = rc.i,
        rt = rc.s
    }
end

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
    local il = pipe.interlace({"i", "s"})
    local platformZ = config.hPlatform + 0.53
    return function(edges, terminals, terminalsGroup, arcL, arcR, enablers)
        local l, r = arcL(platformZ)(function(l) return l - 3 end)(1), arcR(platformZ)(function(l) return l - 3 end)(-1)
        local lc, rc, c = bitLatCoords(l, r, 10)
        local newTerminals = pipe.new
            * pipe.mapn(il(lc), il(rc))(function(lc, rc)
                return {
                    l = station.newModel("terminal_lane.mdl", ust.mRot(lc.i - lc.s), coor.trans(lc.s)),
                    r = station.newModel("terminal_lane.mdl", ust.mRot(rc.s - rc.i), coor.trans(rc.i)),
                    link = station.newModel("standard_lane.mdl", ust.mRot(lc.s:avg(lc.i) - rc.s:avg(rc.i)), coor.trans(rc.i:avg(rc.s)))
                }
            end)
            * function(ls)
                return pipe.new
                    / (enablers[1] and func.map(ls, pipe.select("l")) or {})
                    / (enablers[2] and func.map(ls, pipe.select("r")) or {})
                    / (enablers[1] and enablers[2] and func.map(ls, pipe.select("link")) or {})
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
                    vehicleNodeOverride = #edges * 8 - 7
                }
            } or enablers[2] and {
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[2]) * pipe.map(function(s) return {s - 1 + #terminals, 0} end),
                    vehicleNodeOverride = #edges * 8 - 7
                }
            } or {}
    )
    end
end


ust.generateFences = function(fitModel, config)
    local il = pipe.interlace({"s", "i"})
    local platformZ = config.hPlatform + 0.53
    return function(arcL, arcR, isLeft, isTrack)
        local li, ri =
            arcL(platformZ)(function(l) return l - 0.3 end)((isTrack and -0.5 * config.wTrack or -0.5) + 0.3),
            arcR(platformZ)(function(l) return l - 0.3 end)((isTrack and 0.5 * config.wTrack or 0.5) - 0.3)
        local newModels = pipe.new
            + pipe.mapn(func.seq(1, #li), li, ri)(function(i, li, ri)
                local lc, rc = retriveBiLatCoords(config.fencesLength, equalizeArcs(li, ri))
                local c = isLeft and lc or rc
                return {
                    func.map(il(c), function(ic)
                        local vec = ic.i - ic.s
                        return station.newModel(config.fencesModel[1],
                            coor.rotZ(((not isLeft and i == 1) or (isLeft and i ~= 1)) and 0 or pi),
                            coor.scaleX(vec:length() / config.fencesLength),
                            quat.byVec(coor.xyz(config.fencesLength, 0, 0), vec):mRot(),
                            coor.trans(ic.s:avg(ic.i) + (isTrack and coor.xyz(0, 0, -platformZ) or coor.o)))
                    end),
                    func.map(c, function(ic)
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
    local il = pipe.interlace({"s", "i"})
    local tZ = coor.transZ(config.hPlatform - 1.4)
    local platformZ = config.hPlatform + 0.53
    return function(arcL, arcR, noEquipement)
        noEquipement = noEquipement or false
        local baseL, baseR = arcL(platformZ), arcR(platformZ)
        local baseRL, baseRR = baseL(function(l) return l * config.roofLength end), baseR(function(l) return l * config.roofLength end)
        local l, r = baseL()(-0.5), baseR()(0.5)
        local li, ri = baseL()(0.3), baseR()(-0.3)
        local lp, rp = baseRL(-0.5), baseRR(0.5)
        local lpi, rpi = baseRL(0.5), baseRR(-0.5)
        local newModels = pipe.new
            + pipe.mapn(func.seq(1, #l), l, r, li, ri)(function(i, l, r, li, ri)
                local lc, rc, lci, rci = retriveBiLatCoords(5, equalizeArcs(l, r, li, ri))
                local platformSurface = pipe.new
                    * pipe.rep(#lci - 2)("platform_surface")
                    * pipe.mapi(function(p, i) return (i - 4) % (floor(#lci * 0.5)) == 0 and (i ~= 4 or not noEquipement) and "platform_stair" or "platform_surface" end)
                    / "platform_extremity"
                
                local platformEdge = pipe.new * pipe.rep(#lci - 2)("platform_edge") / "platform_corner"
                return pipe.mapn(platformEdge, platformSurface, il(lc), il(lci), il(rci), il(rc))
                    (function(e, s, lc, lic, ric, rc)
                        local sizeL = assembleSize(l, li, lc, lic)
                        local sizeR = assembleSize(ri, r, ric, rc)
                        local sizeS = assembleSize(li, ri, lic, ric)
                        return {
                            station.newModel(s .. "_br.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS, false, false)),
                            station.newModel(s .. "_tl.mdl", tZ, fitModel(3.4, 5, platformZ, sizeS, true, true)),
                            station.newModel(e .. "_br.mdl", tZ, fitModel(0.8, 5, platformZ, sizeL, false, false)),
                            station.newModel(e .. "_tl.mdl", tZ, fitModel(0.8, 5, platformZ, sizeL, true, true)),
                            station.newModel(e .. "_bl.mdl", tZ, fitModel(0.8, 5, platformZ, sizeR, false, true)),
                            station.newModel(e .. "_tr.mdl", tZ, fitModel(0.8, 5, platformZ, sizeR, true, false))
                        }
                    end)
            end)
            + (noEquipement and {} or pipe.mapn(func.seq(1, #lp), l, r)(function(i, l, r)
                local lci, rci = retriveBiLatCoords(10, equalizeArcs(l, r))
                return pipe.mapn(func.seq(2, #lci - 1), func.range(lci, 2, #lci - 1), func.range(rci, 2, #rci - 1))
                    (function(j, lc, rc)
                        return
                        (j == 3 or (j % 3 == 0 and (j - 3) % 6 == 0) or (j - 3) % (floor(#lci * 0.5)) == 0) and {}
                            or {
                                station.newModel(j % 3 ~= 0 and "platform_chair.mdl" or "platform_trash.mdl",
                                    quat.byVec(coor.xyz(0, i == 1 and 1 or -1, 0), l:tangent(l:rad(lc))):mRot(),
                                    coor.trans(lc:avg(rc)))
                            }
                    end)
            end))
            + (roofLength == 0 and {} or pipe.mapn(func.seq(1, #lp), lp, rp, lpi, rpi)(function(i, l, r, li, ri)
                local lc, rc, lci, rci = retriveBiLatCoords(10, equalizeArcs(l, r, li, ri))
                local roofSurface = pipe.new * pipe.rep(#lci - 2)("platform_roof_top") / "platform_roof_extremity"
                local roofEdge = pipe.new * pipe.rep(#lci - 2)("platform_roof_edge") / "platform_roof_corner"
                return pipe.mapn(roofEdge, roofSurface, il(lc), il(lci), il(rci), il(rc))
                    (function(e, s, lc, lic, ric, rc)
                        local sizeL = assembleSize(l, li, lc, lic)
                        local sizeR = assembleSize(ri, r, ric, rc)
                        local sizeS = assembleSize(li, ri, lic, ric)
                        local vecPo = lc.i:avg(rc.i) - lc.s:avg(rc.s)
                        return {
                            station.newModel(s .. "_br.mdl", tZ, fitModel(3, 10, platformZ, sizeS, false, false)),
                            station.newModel(s .. "_tl.mdl", tZ, fitModel(3, 10, platformZ, sizeS, true, true)),
                            station.newModel(e .. "_br.mdl", tZ, fitModel(1, 10, platformZ, sizeL, false, false)),
                            station.newModel(e .. "_tl.mdl", tZ, fitModel(1, 10, platformZ, sizeL, true, true)),
                            station.newModel(e .. "_br.mdl", tZ, coor.flipX(), fitModel(1, 10, platformZ, sizeR, false, true)),
                            station.newModel(e .. "_tl.mdl", tZ, coor.flipX(), fitModel(1, 10, platformZ, sizeR, true, false)),
                            station.newModel("platform_roof_pole.mdl", tZ, coor.flipY(),
                                coor.scaleY(vecPo:length() / 10), quat.byVec(coor.xyz(0, i == 1 and 5 or -5, 0), vecPo):mRot(),
                                coor.trans(lc.i:avg(rc.i, lc.s, rc.s)), coor.transZ(-platformZ))
                        }
                    end)
            end)
        )
        return newModels * pipe.flatten() * pipe.flatten()
    end
end

ust.generateTerrain = function()
    local il = pipe.interlace({"i", "s"})
    return function(arcL, arcR)
        local l, r = arcL()(function(l) return l + 5 end)(-0.5), arcR()(function(l) return l + 5 end)(0.5)
        return pipe.new
            * pipe.mapn(l, r)(function(l, r)
                local lc, rc = retriveBiLatCoords(5, equalizeArcs(l, r))
                return pipe.mapn(il(lc), il(rc))
                    (function(lc, rc)
                        local size = assembleSize(l, r, lc, rc, 0)
                        return pipe.new / size.lt / size.lb / size.rb / size.rt
                            * pipe.map(coor.vec2Tuple)
                            * ((size.lb - size.lt):cross(size.rb - size.lb).z > 0 and pipe.noop() or pipe.rev())
                    end)
            end)
            * pipe.flatten()
    end
end


return ust
