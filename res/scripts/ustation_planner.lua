local func = require "ustation/func"
local coor = require "ustation/coor"
local arc = require "ustation/coorarc"
local line = require "ustation/coorline"
local quat = require "ustation/quaternion"
local station = require "ustation/stationlib"
local pipe = require "ustation/pipe"
local ust = require "ustation"
local ustm = require "ustation_menu"
local livetext = require "ustation_livetext"

local ustp = {}

local unpack = table.unpack
local ma = math
local abs = ma.abs
local ceil = ma.ceil
local floor = ma.floor
local pi = ma.pi
local atan = ma.atan
local pow = ma.pow
local cos = ma.cos
local sin = ma.sin
local asin = ma.asin
local min = ma.min
local atan2 = ma.atan2


ustp.arcPacker = function(length, slope, ratio)
    return function(radiusA, oA, radiusB, oB)
        local initRadA = (radiusA > 0 and pi or 0)
        local initRadB = (radiusB > 0 and pi or 0)
        return function(xDr0)
            local xDr0 = xDr0 or 0
            return function(z)
                local z = z or 0
                return function(lengthOverride)
                    local l = lengthOverride and lengthOverride(length) or length
                    return function(xDr)
                        local dr = xDr0 + (xDr or 0)
                        local arA = arc.byOR(oA + coor.xyz(0, 0, z), abs(radiusA - dr))
                        local arB = arc.byOR(oB + coor.xyz(0, 0, z), abs(radiusB - dr))
                        local radA = (radiusA > 0 and 1 or -1) * (l * ratio) / arA.r
                        local radB = (radiusB > 0 and 1 or -1) * (l * (1 - ratio)) / arB.r
                        return pipe.new
                            / arA:withLimits({
                                sup = initRadA - radA,
                                inf = initRadA,
                                slope = -slope
                            })
                            / arB:withLimits({
                                inf = initRadB,
                                sup = initRadB + radB,
                                slope = slope
                            })
                    end
                end
            end
        end
    end
end

local arcGen = function(p, o, m)
    local _, r, _ = coor.decomposite(m)
    local dRad = atan2(r[5], r[1])
    return {
        l = p.l(-o),
        r = p.r(o) * pipe.map(function(rx) return rx:withLimits({o = rx.o .. m, sup = rx.sup - dRad, inf = rx.inf - dRad}) end)
    } 
end

local mc = function(lc, rc) return func.map2(lc, rc, function(l, r) return l:avg(r) end) end

ustp.coordGen = {
    track = function(config)
        local refZ = config.hPlatform + 0.53
        return function(arc)
            local left = arc(0.5 * config.tW)
            local right = arc(-0.5 * config.tW)
            local general = {
                l = left(refZ)(),
                r = right(refZ)()
            }
            
            local arcs = {
                edge = arcGen(general, 0, coor.I())
            }
            local lcc, rcc, cc = ust.biLatCoords(5)(arcs.edge.l, arcs.edge.r)
            
            return {
                [1] = arc,
                left = left,
                right = right,
                edge = func.with(arcs.edge, {lc = lcc, rc = rcc, mc = mc(lcc, rcc), c = cc}),
                isTrack = true
            }
        end
    end,
    platform = function(config)
        local refZ = config.hPlatform + 0.53
        return function(arcL, arcR, m, transf)
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
            
            local arcs = {
                platform = {
                    lane = arcGen(lane, config.size.lane, m),
                    laneEdge = arcGen(lane, config.size.laneEdge, m),
                    edge = arcGen(general, config.size.edge, m),
                    surface = arcGen(general, config.size.surface, m),
                    access = arcGen(general, config.size.access, m),
                },
                roof = {
                    edge = arcGen(roof, config.size.roof.edge, m),
                    surface = arcGen(roof, config.size.roof.surface, m)
                },
                terrain = arcGen(terrain, config.size.terrain, m),
                track = arcGen(general, -0.5 * config.tW, m)
            }
            
            local lc, rc, lec, rec, c = ust.biLatCoords(5)(arcs.platform.lane.l, arcs.platform.lane.r, arcs.platform.laneEdge.l, arcs.platform.laneEdge.r)
            local lsc, rsc, lac, rac, lsuc, rsuc, ltc, rtc, ltrc, rtrc, sc =
                ust.biLatCoords(5)(
                    arcs.platform.edge.l,
                    arcs.platform.edge.r,
                    arcs.platform.access.l,
                    arcs.platform.access.r,
                    arcs.platform.surface.l,
                    arcs.platform.surface.r,
                    arcs.terrain.l,
                    arcs.terrain.r,
                    arcs.track.l,
                    arcs.track.r
            )
            local lcc, rcc, cc = ust.biLatCoords(10)(arcs.platform.edge.l, arcs.platform.edge.r)
            local lpc, rpc, lpic, rpic, pc = ust.biLatCoords(5)(arcs.roof.edge.l, arcs.roof.edge.r, arcs.roof.surface.l, arcs.roof.surface.r)
            local lppc, rppc, ppc = ust.biLatCoords(10)(arcs.roof.edge.l, arcs.roof.edge.r)
            
            local lpcc, rpcc, mpcc = table.unpack(
                pipe.new
                * pipe.mapn(lsuc, rsuc)(function(lc, rc)
                    local vec = (rc - lc)
                    local width = vec:length()
                    vec = vec:normalized() * 0.5 * (width >= 3 and 2 or width >= 2 and (width - 1) or width >= 0.5 and 0.5 or false)
                    local mc = lc:avg(rc)
                    return vec and {mc - vec, mc + vec, mc} or {false, false, mc}
                end
                )
                * pipe.fold({pipe.new, pipe.new, pipe.new}, function(r, c) return {r[1] / c[1], r[2] / c[2], r[3] / c[3]} end)
            )
            return {
                [1] = arcL,
                [2] = arcR,
                transf = transf,
                platform = {
                    lane = func.with(arcs.platform.lane, {lc = lc, rc = rc, mc = mc(lc, rc), c = c}),
                    laneEdge = func.with(arcs.platform.laneEdge, {lc = lec, rc = rec, mc = mc(lec, rec), c = c}),
                    surface = func.with(arcs.platform.surface, {lc = lsuc, rc = rsuc, mc = mpcc, c = sc}),
                    stair = func.with(arcs.platform.surface, {lc = lpcc, rc = rpcc, mc = mpcc, c = sc}),
                    edge = func.with(arcs.platform.edge, {lc = lsc, rc = rsc, mc = mc(lsc, rsc), c = sc}),
                    access = func.with(arcs.platform.access, {lc = lac, rc = rac, mc = mc(lac, rac), c = sc}),
                    chair = func.with(arcs.platform.edge, {lc = lcc, rc = rcc, mc = mc(lcc, rcc), c = cc}),
                },
                roof = {
                    edge = func.with(arcs.roof.edge, {lc = lpc, rc = rpc, mc = mc(lpc, rpc), c = pc}),
                    surface = func.with(arcs.roof.surface, {lc = lpic, rc = rpic, mc = mc(lpic, rpic), c = pc}),
                    pole = func.with(arcs.roof.edge, {lc = lppc, rc = rppc, mc = mc(lppc, rppc), c = ppc})
                },
                track = func.with(arcs.track, {lc = ltrc, rc = rtrc, mc = mc(ltrc, rtrc), c = pc}),
                terrain = func.with(arcs.terrain, {lc = ltc, rc = rtc, mc = mc(ltc, rtc), c = sc}),
                hasLower = (sc - 5 - floor(sc * 0.5) > 0) and (c - 5 - floor(c * 0.5) > 0),
                hasUpper = (sc + 5 + floor(sc * 0.5) <= #lsc) and (c + 5 + floor(c * 0.5) <= #lc),
                isPlatform = true
            }
        end
    end
}

local cov = function(m)
    return func.seqMap({0, 3}, function(r)
        return func.seqMap({1, 4}, function(c)
            return m[r * 4 + c]
        end)
    end)
end

ustp.profile = function(config)
    return {
        track = function(fm, tm, i)
            local f, radius, f2, radius2, length, slope, transf = ustp.solve(fm, tm)
            
            local r1 = f * radius
            local r2 = f2 and radius2 and f2 * radius2 or f * radius
            
            return func.with(ustp.coordGen.track(config)
                (ustp.arcPacker(length, slope, 0.5)(r1, coor.xyz(r1, 0, 0), r2, coor.xyz(r2, 0, 0))),
                {
                    number = i,
                    transf = transf,
                    fm = fm,
                    tm = tm
                })
        end,
        platform = function(tl, tr)
            local vecL, rotL, _ = coor.decomposite(tl.transf)
            local vecR, rotR, _ = coor.decomposite(tr.transf)
            local iRot = coor.inv(cov(rotL))
            local m = iRot * rotR * coor.trans((vecR - vecL) .. iRot)
            return ustp.coordGen.platform(config)(tl.right, tr.left, m, tl.transf)
        end
    }
end

ustp.findMarkers = function(group)
    return pipe.new
        * game.interface.getEntities({pos = {0, 0}, radius = 900000})
        * pipe.map(game.interface.getEntity)
        * pipe.filter(function(data) return data.fileName and string.match(data.fileName, "utimate_station_planner.con") and data.params and data.params.group == group end)
        * pipe.sort(function(x, y) return x.dateBuilt.year < y.dateBuilt.year or x.dateBuilt.month < y.dateBuilt.month or x.dateBuilt.day < y.dateBuilt.day or x.id < y.id end)
end

local findPreviewsByMarker = function(pos, r)
    return function(con)
        return function(params)
            return pipe.new
                * game.interface.getEntities({pos = {pos.x, pos.y}, radius = r})
                * pipe.map(game.interface.getEntity)
                * pipe.filter(function(data) return data.fileName and string.match(data.fileName, con) and data.params.showPreview and data.params.overrideGr == params.overrideGr end)
        end
    end
end

ustp.displace = function(config, trackCoords)
    local tc = trackCoords * pipe.filter(pipe.noop())
    local disp =
        config.pattern and config.pattern.m and trackCoords[config.pattern.m]
        or tc[(pipe.new
        / function() return 1 end
        / function() return ceil(#tc * 0.5) end
        / function() return #tc end
        * pipe.select(config.varRefPos + 2))()]
    return station.setTransform(coor.trans(-disp))
end

ustp.updatePreview = function(params, config, arcPacker, buildStation)
    local nbTracks = ustm.trackNumberList[params.nbTracks + 1]
    
    local track, platform, entry, trackCoords =
        buildStation(nbTracks,
            arcPacker,
            config,
            params.hasLeftPlatform == 0,
            params.hasRightPlatform == 0,
            ust.buildPreview
    )
    local radius2String = function(r) return abs(r) > 1e6 and (r > 0 and "+∞" or "-∞") or tostring(floor(r * 10) * 0.1) end
    local fPos = function(w) return coor.transX(-0.5 * w) * coor.rotX(-pi * 0.5) * coor.rotZ(pi * 0.5) * coor.transZ(3) end
    local rtext = livetext(7, 0)(
        config.r
        and ("R" .. radius2String(config.r))
        or ("R" .. radius2String(config.rA) .. " / " .. radius2String(config.rB))
    )(fPos)
    local ltext = livetext(7, -1)("L" .. tostring(floor(config.length * 10) * 0.1))(fPos)
    local stext = livetext(7, -2)("S" .. tostring(floor(config.slope * 10000) * 0.1) .. "‰")(fPos)
    return pipe.new * {
        models = pipe.new + ltext + rtext + stext,
        terrainAlignmentLists = {{type = "EQUAL", faces = {}}},
        groundFaces = track
        * pipe.map(pipe.select("equal"))
        * pipe.filter(pipe.noop())
        * pipe.flatten()
        * pipe.map(function(f) return {
            {face = f, modes = {{type = "FILL", key = "fill_red"}}},
        } end)
        * pipe.flatten()
        + platform
        * pipe.map(pipe.select("equal"))
        * pipe.filter(pipe.noop())
        * pipe.flatten()
        * pipe.map(function(f) return {
            {face = f, modes = {{type = "FILL", key = "fill_blue"}}},
        } end)
        * pipe.flatten()
        +
        (
        entry * pipe.map(pipe.map(pipe.select("equal")))
        + entry * pipe.map(pipe.map(pipe.select("slot")))
        )
        * pipe.flatten()
        * pipe.filter(pipe.noop())
        * pipe.flatten()
        * pipe.map(function(f) return {
            {face = f, modes = {{type = "FILL", key = "fill_yellow"}}},
        } end)
        * pipe.flatten()
    }
    * ustp.displace(config, trackCoords)
end

local retriveInfo = function(info)
    if (info) then
        return {
            length = tonumber(info:match("L(%d+)")),
            radius = tonumber(info:match("R(%d+)")),
            lengthRoundoff = tonumber(info:match("Lr(%d+)")),
            radiusRoundoff = tonumber(info:match("Rr(%d+)")),
            pattern = info:match("([TPt]+)")
        }
    else
        return {}
    end
end

local findCircle = function(posS, posE, vecS, vecE)
    local lnPS = line.byVecPt(vecS .. coor.rotZ(0.5 * pi), posS)
    local lnPE = line.byVecPt(vecE .. coor.rotZ(0.5 * pi), posE)
    local o = lnPS - lnPE
    local vecOS = o - posS
    local vecOE = o - posE
    local radius = vecOS:length()
    local rad = asin(vecOS:normalized():cross(vecOE:normalized()))
    local length = abs(rad * radius)
    local ar = arc.byOR(o, radius)
    local f = rad > 0 and 1 or -1
    return ar, f, length
end

local solve = function(s, e)
    local posS, rotS, _ = coor.decomposite(s.transf)
    local posE, rotE, _ = coor.decomposite(e.transf)
    local vecS = coor.xyz(1, 0, 0) .. rotS
    local vecE = coor.xyz(1, 0, 0) .. rotE
    local lnS = line.byVecPt(vecS, posS)
    local lnE = line.byVecPt(vecE, posE)
    local m = (posE + posS) * 0.5
    local vecES = posE - posS
    local x = lnS - lnE
    
    if (x) then
        local vecXS = x - posS
        local vecXE = x - posE
        
        local u = vecXS:length()
        local v = vecXE:length()
        
        local co = vecXS:normalized():dot(vecXE:normalized())
        
        local function retrive(y, cond, coorX, coorY)
            local lnX = line.byVecPt(vecXS:withZ(0) .. coor.rotZ(pi * 0.5), posS)
            local lnY = line.byVecPt(vecXE:withZ(0) .. coor.rotZ(pi * 0.5), posE)
            local function work(f, t, level)
                local solution = pipe.new
                    * func.seq(0, 100)
                    * pipe.map(function(p) return {x = f + (t - f) * 0.01 * p, p = p} end)
                    * pipe.map(function(v) return {x = v.x, y = y(v.x), p = v.p} end)
                    * pipe.filter(cond)
                    * pipe.map(function(va)
                        local x = coorX(va)
                        local y = coorY(va)
                        local vecXY = (y - x):normalized()
                        local m = x + vecXY * va.x
                        local lnM = line.byVecPt(vecXY:withZ(0) .. coor.rotZ(pi * 0.5), m)
                        local oX = lnM - lnX
                        local oY = lnM - lnY
                        if (oX and oY) then
                            local vecOX = (posS - oX):normalized()
                            local vecOY = (posE - oY):normalized()
                            local vecOM = (m - oX):normalized()
                            local rX = (oX - posS):length()
                            local rY = (oY - posE):length()
                            local sinX = vecOX:cross(vecOM)
                            local sinY = vecOM:cross(vecOY)
                            local radX = asin(sinX)
                            local radY = asin(sinY)
                            local lX = abs(rX * radX)
                            local lY = abs(rY * radY)
                            local length = lX + lY
                            return {
                                m = m:withZ((posE.z - posS.z) * lX / length + posS.z),
                                vecX = (x - m):normalized(),
                                vecY = (y - m):normalized(),
                                length = length,
                                r = abs(lX - lY),
                                p = va.p
                            }
                        else
                            return nil
                        end
                    end)
                    * pipe.filter(pipe.noop())
                    * pipe.min(function(l, r) return l.r < r.r end)
                
                if (level > 0) then
                    return work(f + (t - f) * 0.01 * (solution.p - 1), f + (t - f) * 0.01 * (solution.p + 1), level - 1)
                else
                    local ar1, f1, length1 = findCircle(posS, solution.m, vecS, solution.vecX:withZ(0))
                    local ar2, f2, length2 = findCircle(solution.m, posE, solution.vecY:withZ(0), vecE)
                    return
                        f1, ar1.r,
                        f2, ar2.r,
                        func.min({length1, length2}) * 2 - 10, (posE.z - posS.z) / solution.length,
                        quat.byVec(coor.xyz(0, 1, 0), (solution.vecX):withZ(0)):mRot() * coor.trans(solution.m), m, vecES
                end
            end
            return work(0, u, 4)
        end
        
        if (vecXE:dot(vecE) > 0 and vecXS:dot(vecS) > 0) then
            if abs(vecXS:length() / vecXE:length() - 1) < 0.005 then
                local ar, f, length = findCircle(posS, posE, vecS, vecE)
                return
                    f, ar.r,
                    nil, nil,
                    length - 10, (posE.z - posS.z) / length,
                    quat.byVec(coor.xyz(f, 0, 0), (m - x):withZ(0)):mRot() * coor.trans(arc.ptByPt(ar, m):withZ(m.z)), m, vecES
            else
                return retrive(
                    function(x) return 0.5 * (u * u + v * v - 2 * u * x - 2 * u * v * co + 2 * v * x * co) / (v + x - u * co + x * co) end,
                    function(va) return va.y >= 0 and va.y <= v and va.x >= 0 and va.x <= u end,
                    function(va) return (posS + vecXS * (va.x / u)) end,
                    function(va) return (posE + vecXE * (va.y / v)) end
            )
            end
        elseif ((vecXE:dot(vecE) < 0 and vecXS:dot(vecS) > 0)) then
            return retrive(
                function(x) return 0.5 * (-u * u - v * v + 2 * u * x + 2 * u * v * co - 2 * v * x * co) / (v - x - u * co + x * co) end,
                function(va) return va.y >= 0 and va.x >= 0 and va.x < u end,
                function(va) return (posS + vecXS * (va.x / u)) end,
                function(va) return (posE - vecXE * (va.y / v)) end
        )
        elseif ((vecXS:dot(vecS) < 0 and vecXE:dot(vecE) > 0)) then
            return retrive(
                function(x) return 0.5 * (u * u + v * v + 2 * u * x - 2 * u * v * co - 2 * v * x * co) / (v + x - u * co - x * co) end,
                function(va) return va.y >= 0 and va.y <= v and va.x >= 0 end,
                function(va) return (posS - vecXS * (va.x / u)) end,
                function(va) return (posE + vecXE * (va.y / v)) end
        )
        end
    else
        local lnPenE = line.byVecPt(lnS:vector():withZ(0) .. coor.rotZ(0.5 * pi), posE)
        local posP = lnPenE - lnS
        local vecEP = posE - posP
        if (vecEP:length() < 1e-5) then
            local radius = ust.infi
            local o = posS + (lnPenE:vector():normalized() * radius)
            local ar = arc.byOR(o, radius)
            local length = vecES:length()
            local f = 1
            return
                f, radius,
                nil, nil,
                length - 10, (posE.z - posS.z) / length,
                quat.byVec(coor.xyz(1, 0, 0), (o - m):normalized():withZ(0)):mRot() * coor.trans(arc.ptByPt(ar, m):withZ(m.z)), m, vecES
        else
            local mRot = quat.byVec(vecS, vecES:normalized()):mRot()
            local vecT = vecES .. mRot
            local lnT = line.byVecPt(vecT, m)
            local ar1, f1, length1 = findCircle(posS, m, vecS, -vecT)
            local ar2, f2, length2 = findCircle(m, posE, vecT, vecE)
            return
                f1, ar1.r,
                f2, ar2.r,
                (length1 + length2) - 10, (posS.z - posE.z) / (length1 + length2),
                quat.byVec(coor.xyz(0, 1, 0), (vecT):withZ(0)):mRot() * coor.trans(m), m, vecES
        end
    end
end

ustp.solve = solve

local retriveParams = function(markers)
    local s, e = unpack(markers)
    local f, radius, f2, radius2, length, slope, transf, m, vecES = solve(s, e)
    local findPreviewsByMarker = findPreviewsByMarker(m, vecES:length())
    local con = (f2 and radius2) and "utimate_station_double_curvature.con" or "utimate_station.con"
    return findPreviewsByMarker(con), con, f, radius, f2, radius2, length, slope, transf
end

local refineParams = function(params, markers)
    local info = retriveInfo(
        markers
        * pipe.filter(function(m) return string.find(m.name, "#", 0, true) == 1, 1 end)
        * pipe.map(pipe.select("name")) * pipe.select(1)
    )
    local findPreviewsByMarker, con, f, radius, f2, radius2, length, slope, transf = retriveParams(markers)
    
    local length = (info.length and params.lengthOverride == 1 and info.length < length) and info.length or length
    local length = info.lengthRoundoff and (length > info.lengthRoundoff and (floor(length / info.lengthRoundoff) * info.lengthRoundoff) or info.lengthRoundoff) or length
    local length = length < 30 and 30 or length
    local radius = info.radius or radius
    local radius = info.radiusRoundoff and ceil(radius / info.radiusRoundoff) * info.radiusRoundoff or radius
    local radius2 = radius2 and (info.radiusRoundoff and ceil(radius2 / info.radiusRoundoff) * info.radiusRoundoff or radius2)
    
    local patternRef = info.pattern and
        pipe.new
        * func.seq(1, info.pattern:len())
        * pipe.map(function(i) return info.pattern:sub(i, i) end)
        * pipe.fold(pipe.new, function(r, c)
            if (c == "P") then
                return r[#r].t and r / {t = false, r = false} or r
            else
                return r / {t = true, r = (c == "t")}
            end
        end)
        or pipe.new * {}
    local pattern = patternRef * pipe.map(pipe.select("t"))
    local middlePos = patternRef * pipe.map(pipe.select("r")) * pipe.zip(func.seq(1, #patternRef)) * pipe.filter(pipe.select(1))
    
    return findPreviewsByMarker, "station/rail/" .. con, f * radius, f2 and f2 * radius2 or nil, length, slope, transf, pattern, #middlePos > 0 and middlePos[1][2]
end

local findPreviewInstance = function(params)
    return pipe.new
        * game.interface.getEntities({pos = {0, 0}, radius = 900000})
        * pipe.map(game.interface.getEntity)
        * pipe.filter(function(data) return data.params and data.params.seed == params.seed end)
end

ustp.updatePlanner = function(params, markers, config)
    if (params.override == 1) then
        local findPreviewsByMarker, con, radius, radius2, length, slope, transf, pattern, middlePos = refineParams(params, markers)
        local overrideParams = radius2 and {
            radiusA = radius,
            radiusB = radius2,
            length = params.lengthOverride > 0 and length,
            slope = params.slopeOverride > 0 and slope,
            pattern = {p = pattern, m = middlePos},
            varRefTrack = true
        } or {
            radius = radius,
            length = params.lengthOverride > 0 and length,
            slope = params.slopeOverride > 0 and slope,
            pattern = {p = pattern, m = middlePos},
            varRefTrack = true
        }
        
        local pre = findPreviewsByMarker(params)
        local previewParams = func.with(station.pureParams(params),
            {
                showPreview = true,
                overrideParams = overrideParams
            })
        
        local _ = pre * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
        
        local id = game.interface.buildConstruction(
            con,
            previewParams,
            transf
        )
        game.interface.setPlayer(id, game.interface.getPlayer())
    
    else
        local pre = #markers == 2 and retriveParams(markers)(params) or findPreviewInstance(params)
        if (params.override == 2) then
            if (#pre == 1) then
                local _ = markers * pipe.map(function(m) return m.id end) * pipe.forEach(game.interface.bulldoze)
                game.interface.upgradeConstruction(
                    pre[1].id,
                    pre[1].fileName,
                    func.with(station.pureParams(pre[1].params),
                        {
                            override = 2,
                            showPreview = false,
                            isBuild = true,
                            stationName = pre[1].name
                        })
            )
            end
        elseif (params.override == 3) then
            local _ = pre * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
        end
    end
    
    return {
        models = {
            {
                id = "asset/icon/marker_question.mdl",
                transf = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
            }
        },
        cost = 0,
        bulldozeCost = 0,
        maintenanceCost = 0,
        terrainAlignmentLists = {{type = "EQUAL", faces = {}}}
    }
end


return ustp
