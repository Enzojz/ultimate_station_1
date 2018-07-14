local func = require "ustation/func"
local coor = require "ustation/coor"
local line = require "ustation/coorline"
local station = require "ustation/stationlib"
local pipe = require "ustation/pipe"
local ust = require "ustation"

local ma = math

local abs = ma.abs
local ceil = ma.ceil
local floor = ma.floor
local pi = ma.pi
local atan = ma.atan
local pow = ma.pow
local cos = ma.cos
local sin = ma.sin
local min = ma.min
local e = ma.exp(1)
local log = ma.log
local log10 = log(10)

local il = pipe.interlace({"s", "i"})


local buildUndergroundEntry = function(config, entryConfig)
    local allArcs = entryConfig.allArcs

    local arcCoords = pipe.new 
        * {ust.trackGrouping(pipe.new, table.unpack(allArcs))}
        * pipe.map(pipe.filter(function(a) return #a > 1 end))
        * pipe.filter(function(g) return #g > 0 end)
        * pipe.map(function(g)
            if (#g == 1) then return g else
                local arcL, arcR = table.unpack(g)
                local coords = {
                    l = {
                        lc = arcL.platform.lc,
                        rc = arcR.platform.rc * pipe.range(1, arcL.platform.common) + arcL.platform.rc * pipe.range(arcL.platform.common + 1, #arcL.platform.rc),
                    },
                    r = {
                        lc = arcL.platform.lc * pipe.range(1, arcR.platform.common) + arcR.platform.lc * pipe.range(arcR.platform.common + 1, #arcR.platform.lc),
                        rc = arcR.platform.rc
                    }
                }
                local mc = function(lc, rc) return func.map2(lc, rc, function(l, r) return l:avg(r) end) end
                
                return {
                    {
                        platform = func.with(coords.l, {mc = mc(coords.l.lc, coords.l.rc), c = arcL.platform.c}),
                        hasLower = arcL.hasLower,
                        hasUpper = arcL.hasUpper,
                    },
                    {
                        platform = func.with(coords.r, {mc = mc(coords.r.lc, coords.r.rc), c = arcR.platform.c}),
                        hasLower = arcR.hasLower,
                        hasUpper = arcR.hasUpper,
                    }
                }
            end
        end)
        * pipe.flatten()

    local transZ = coor.transZ(-config.hPlatform - 0.53 - 7.5)
    
    local idxPt = allArcs
        * pipe.zip(func.seq(1, #allArcs), {"p", "i"})
        * pipe.filter(function(a) return #(a.p) > 1 end)
        * pipe.map(pipe.select("i"))
    
    local fst = func.min(idxPt, function(l, r) return l < r end)
    local lst = func.max(idxPt, function(l, r) return l < r end)
    
    local accessBuilder = function()
        local transZ = coor.transZ(-config.hPlatform - 0.53)
        return pipe.new
            * {arcCoords[1], arcCoords[#arcCoords]}
            * pipe.mapi(function(p, i)
                local enabler = entryConfig.underground[i]
                local pl = p.platform
                local lpt = pipe.new
                    / (p.hasLower and pl.lc[pl.c - 2 - floor(pl.c * 0.5)])
                    / pl.lc[pl.c]
                    / (p.hasUpper and pl.lc[pl.c + 2 + floor(pl.c * 0.5)])
                
                local rpt = pipe.new
                    / (p.hasLower and pl.rc[pl.c - 2 - floor(pl.c * 0.5)])
                    / pl.rc[pl.c]
                    / (p.hasUpper and pl.rc[pl.c + 2 + floor(pl.c * 0.5)])
                return pipe.mapn(lpt, rpt, enabler)(function(l, r, e)
                    return l and r and e and {pt = (i == 1 and l or r) .. transZ, vec = (i == 1 and (l - r) or (r - l)):withZ(0):normalized()}
                end)
            end)
            * function(ls) return func.map({1, 2, 3}, function(i) return ls * pipe.map(pipe.select(i)) end) end
            * pipe.map(function(ls)
                return pipe.new
                    / (
                    ls[1] and station.newModel(config.models.underground,
                        coor.rotZ(-0.5 * pi),
                        coor.transX(fst == 1 and -0.5 or (fst - 1) * config.wTrack),
                        ust.mRot(ls[1].vec),
                        coor.trans(ls[1].pt)
                    ))
                    / (ls[2] and station.newModel(config.models.underground,
                        coor.rotZ(-0.5 * pi),
                        coor.transX(#allArcs == lst and -0.5 or -0.5 + (#allArcs - lst) * config.wTrack),
                        ust.mRot(ls[2].vec),
                        coor.trans(ls[2].pt)
                    ))
                    * pipe.filter(pipe.noop())
            end)
            * pipe.flatten()
            * pipe.filter(pipe.noop())
    end
    
    local terrainBuilder = function()
        return pipe.new
            * {arcCoords[1], arcCoords[#arcCoords]}
            * pipe.mapi(function(p, i)
                local enabler = entryConfig.underground[i]
                local pl = p.platform
                local lpt = pipe.new
                    / (p.hasLower and pl.lc[pl.c - 2 - floor(pl.c * 0.5)])
                    / pl.lc[pl.c]
                    / (p.hasUpper and pl.lc[pl.c + 2 + floor(pl.c * 0.5)])
                
                local rpt = pipe.new
                    / (p.hasLower and pl.rc[pl.c - 2 - floor(pl.c * 0.5)])
                    / pl.rc[pl.c]
                    / (p.hasUpper and pl.rc[pl.c + 2 + floor(pl.c * 0.5)])
                
                return pipe.mapn(lpt, rpt, enabler)(function(l, r, e)
                    return l and r and e and {pt = (i == 1 and l or r) .. transZ, vec = (i == 1 and (l - r) or (r - l)):withZ(0):normalized()}
                end)
            end)
            * function(ls) return func.map({1, 2, 3}, function(i) return ls * pipe.map(pipe.select(i)) end) end
            * pipe.map(function(ls)
                local vec1 = ls[1] and (ls[1].vec .. coor.rotZ(0.5 * pi)) * 4
                local vec2 = ls[2] and (ls[2].vec .. coor.rotZ(0.5 * pi)) * 4
                
                return pipe.new
                    / (
                    ls[1] and
                    {
                        ls[1].pt + vec1 + ls[1].vec * ((fst - 1) * config.wTrack - 2),
                        ls[1].pt - vec1 + ls[1].vec * ((fst - 1) * config.wTrack - 2),
                        ls[1].pt - vec1 + ls[1].vec * ((fst - 1) * config.wTrack + 18),
                        ls[1].pt + vec1 + ls[1].vec * ((fst - 1) * config.wTrack + 18)
                    })
                    / (ls[2] and {
                        ls[2].pt + vec2 + ls[2].vec * ((#allArcs - lst) * config.wTrack - 2),
                        ls[2].pt - vec2 + ls[2].vec * ((#allArcs - lst) * config.wTrack - 2),
                        ls[2].pt - vec2 + ls[2].vec * ((#allArcs - lst) * config.wTrack + 18),
                        ls[2].pt + vec2 + ls[2].vec * ((#allArcs - lst) * config.wTrack + 18)
                    })
                    * pipe.filter(pipe.noop())
            end)
            * pipe.flatten()
            * function(f)
                return pipe.new /
                    {
                        less = f * pipe.map(pipe.map(function(c) return c .. coor.transZ(0.53 + 7.5) end)) * pipe.map(station.finalizePoly),
                        slot = f * pipe.map(station.finalizePoly),
                        greater = f * pipe.map(station.finalizePoly)
                    }
            end
    end
    
    local streetBuilder = function()
        return pipe.new
            * {arcCoords[1], arcCoords[#arcCoords]}
            * pipe.mapi(function(p, i)
                local enabler = entryConfig.underground[i]
                
                local pl = p.platform
                local lpt = pipe.new
                    / (p.hasLower and pl.lc[pl.c - 2 - floor(pl.c * 0.5)])
                    / pl.lc[pl.c]
                    / (p.hasUpper and pl.lc[pl.c + 2 + floor(pl.c * 0.5)])
                
                local rpt = pipe.new
                    / (p.hasLower and pl.rc[pl.c - 2 - floor(pl.c * 0.5)])
                    / pl.rc[pl.c]
                    / (p.hasUpper and pl.rc[pl.c + 2 + floor(pl.c * 0.5)])
                
                return pipe.mapn(lpt, rpt, enabler)(function(l, r, e)
                    return l and r and {pt = l:avg(r) .. transZ, vec = (i == 1 and (l - r) or (r - l)):withZ(0) * 0.5, enabled = e}
                end)
            end)
            * function(ls) return func.map({1, 2, 3}, function(i) return ls * pipe.map(pipe.select(i)) end) end
            * pipe.map(pipe.filter(pipe.noop()))
            * pipe.filter(function(ls) return #ls > 0 end)
            * pipe.map(function(ls)
                local underground = pipe.new
                    / (ls[1] and ls[1].enabled and {
                        ls[1].pt,
                        ls[1].pt + (fst == 1
                        and ls[1].vec + ls[1].vec:normalized() * (-0.5)
                        or ls[1].vec + ls[1].vec:normalized() * (-0.5 + (fst - 1) * config.wTrack)),
                        ls[1].vec,
                        ls[1].vec,
                    })
                    / (ls[2] and ls[2].enabled and {
                        ls[2].pt,
                        ls[2].pt + (#allArcs == lst
                        and ls[2].vec + ls[2].vec:normalized() * (-0.5)
                        or ls[2].vec + ls[2].vec:normalized() * (-0.5 + (#allArcs - lst) * config.wTrack)),
                        ls[2].vec,
                        ls[2].vec,
                    })
                    / (((ls[1] and ls[1].enabled) or (ls[2] and ls[2].enabled)) and #arcCoords > 1 and ((ls[1].pt - ls[2].pt):length() > 1e-6) and
                    {
                        ls[1].pt,
                        ls[2].pt,
                        -ls[1].vec,
                        ls[2].vec,
                    }
                )

                local surface = underground
                    * pipe.range(1, 2)
                    * pipe.filter(pipe.noop())
                    * pipe.map(function(e) return {e[2], e[2] + e[3]:normalized() * 8, e[3], e[3]} end)
                    * pipe.range(i == 1 and 2 or 1, 2)
                
                return {
                    underground = underground * pipe.filter(pipe.noop()),
                    surface = surface,
                    surface2 = surface * pipe.map(function(e) return {e[2], e[2] + e[3]:normalized() * 10, e[3], e[3]} end)
                }
            end)
            * function(ls)
                local ug = ls * pipe.map(function(ls) return {
                    edge = ls.underground,
                    snap = pipe.new * pipe.rep(#ls.underground)({false, false})
                } end)
                local su = ls * pipe.map(function(ls) return {
                    edge = ls.surface,
                    snap = pipe.new * pipe.rep(#ls.surface)({false, false})
                } end)
                
                local su2 = ls * pipe.map(function(ls) return {
                    edge = ls.surface2,
                    snap = pipe.new * pipe.rep(#ls.surface2)({false, true})
                } end)

                
                return
                    {
                        pipe.new * {ug * station.mergeEdges} * station.prepareEdges * pipe.with(
                            {
                                type = "STREET",
                                edgeType = "TUNNEL",
                                edgeTypeName = "ust_void.lua",
                                params =
                                {
                                    type = "ust_pass.lua",
                                    tramTrackType = "NO"
                                }
                            }
                        ),
                        pipe.new * {su * station.mergeEdges} * station.prepareEdges * pipe.with(
                            {
                                type = "STREET",
                                alignTerrain = false,
                                params =
                                {
                                    type = "ust_pass.lua",
                                    tramTrackType = "NO"
                                }
                            }
                        ),
                        pipe.new * {su2 * station.mergeEdges} * station.prepareEdges * pipe.with(
                            {
                                type = "STREET",
                                alignTerrain = false,
                                params =
                                {
                                    type = "ust_pass_2.lua",
                                    tramTrackType = "NO"
                                }
                            }
                    )
                    }
            end
    end
    
    local laneBuilder = function()
        local function strCoor(l, r, b)
            local vec = (r - l):withZ(0):normalized() * 1.5 .. coor.rotZ(0.5 * pi)
            local ref = l:avg(r) .. transZ
            return {
                ust.unitLane(ref - vec, b),
                ust.unitLane(ref + vec, ref - vec),
            }
        end
        
        return pipe.new
            * {arcCoords[1], arcCoords[#arcCoords]}
            * pipe.map(function(p)
                local pl, la = p.platform, p.lane
                local fplc = floor(pl.c * 0.5)
                return pipe.new
                    / (p.hasUpper and (entryConfig.underground[1][3] or entryConfig.underground[2][3]) and strCoor(
                        pl.lc[pl.c + 2 + fplc],
                        pl.rc[pl.c + 2 + fplc],
                        pl.mc[pl.c + 3 + fplc] - coor.xyz(0, 0, 3.5)
                    ))
                    / (p.hasLower and (entryConfig.underground[1][1] or entryConfig.underground[2][1]) and strCoor(
                        pl.rc[pl.c - 2 - fplc],
                        pl.lc[pl.c - 2 - fplc],
                        pl.mc[pl.c - 3 - fplc] - coor.xyz(0, 0, 3.5)
                    ))
                    / ((entryConfig.underground[1][2] or entryConfig.underground[2][2]) and strCoor(
                        pl.lc[pl.c],
                        pl.rc[pl.c],
                        pl.mc[pl.c + 2] - coor.xyz(0, 0, 3.5)
                    ))
                    / ((entryConfig.underground[1][2] or entryConfig.underground[2][2]) and strCoor(
                        pl.rc[pl.c],
                        pl.lc[pl.c],
                        pl.mc[pl.c - 2] - coor.xyz(0, 0, 3.5)
                    ))
                    * pipe.filter(pipe.noop())
            end)
            * pipe.flatten()
            * pipe.flatten()
    end
    
    return {
        access = accessBuilder(),
        lane = laneBuilder(),
        terrain = terrainBuilder(),
        street = streetBuilder()
    }
end

local buildSecondEntrySlope = function(config, entryConfig)
    local allArcs = entryConfig.allArcs
    local arcCoords = entryConfig.arcCoords
    local tZ = coor.transZ(-config.hPlatform - 0.53)
    
    local fenceFilter = function(isLeft, isTrack)
        local pl = isLeft and arcCoords[1].platform or arcCoords[#arcCoords].platform
        local co = isLeft and pl.lc or pl.rc
        local cfg = entryConfig.street[isLeft and 1 or 2]
        local void = pipe.new
            / (cfg[1] and {co[pl.c - floor(pl.c * 0.5) - 3], co[pl.c - floor(pl.c * 0.5) - 4]})
            / (cfg[2] and {co[pl.c], co[pl.c + 1]})
            / (cfg[3] and {co[pl.c + floor(pl.c * 0.5) + 3], co[pl.c + floor(pl.c * 0.5) + 4]})
            * pipe.filter(pipe.noop())

        local checkCross = function(l, r, p) 
            local x = line.byPtPt(l, r) - line.byVecPt((l - r) .. coor.rotZ(0.5 * pi), p)
            return (x - l):dot(x - r) < 0
         end

        local checker = function(p)
            return #func.filter(void, function(v) return checkCross(v[1], v[2]:avg(v[1]), p) end) == 0
        end
        
        return isTrack and function(_) return true end or function(c)
            if c.i then
                return checker(c.i) and checker(c.s)
            else
                return checker(c)
            end
        end
    end
    
    local edgeBuilder = function(isLeftmost, isRightmost)
        return function(platformEdgeO, c)
            local fc = floor(c * 0.5)
            
            local enabler = func.map({
                {entryConfig.street[1][1] and c - fc - 4, entryConfig.street[1][2] and c, entryConfig.street[1][3] and c + fc + 3},
                {entryConfig.street[2][1] and c - fc - 4, entryConfig.street[2][2] and c, entryConfig.street[2][3] and c + fc + 3},
            }, pipe.filter(pipe.noop()))
            
            local platformEdgeL = isLeftmost and platformEdgeO * pipe.mapi(function(e, i) return func.contains(enabler[1], i) and i ~= 1 and i ~= #platformEdgeO and config.models.edgeOpen or e end) or platformEdgeO
            local platformEdgeR = isRightmost and platformEdgeO * pipe.mapi(function(e, i) return func.contains(enabler[2], i) and i ~= 1 and i ~= #platformEdgeO and config.models.edgeOpen or e end) or platformEdgeO
            return platformEdgeL, platformEdgeR
        end
    end
    
    local sizeBuilder = function(p, i)
        local pl = p.platform
        local ac = p.access
        local l, r = i == 1 and pl.lc or pl.rc, i == 1 and ac.lc or ac.rc
        local fplc, facc = floor(pl.c * 0.5), floor(ac.c * 0.5)
        local enabler = entryConfig.street[i]
        
        return pipe.new
            / (p.hasLower and enabler[1] and
            {
                ust.assembleSize(
                    {i = l[pl.c - 4 - fplc], s = l[pl.c - 3 - fplc]},
                    {i = r[ac.c - 4 - facc], s = r[ac.c - 3 - facc]}
                ),
                ust.assembleSize(
                    {i = l[pl.c - 5 - fplc], s = l[pl.c - 4 - fplc]},
                    {i = r[ac.c - 5 - facc], s = r[ac.c - 4 - facc]}
            )
            })
            / (enabler[2] and {
                ust.assembleSize(
                    {i = l[pl.c + 1], s = l[pl.c]},
                    {i = r[ac.c + 1], s = r[ac.c]}
                ),
                ust.assembleSize(
                    {i = l[pl.c + 2], s = l[pl.c + 1]},
                    {i = r[ac.c + 2], s = r[ac.c + 1]}
            )
            })
            / (p.hasUpper and enabler[3] and
            {
                ust.assembleSize(
                    {i = l[pl.c + 4 + fplc], s = l[pl.c + 3 + fplc]},
                    {i = r[ac.c + 4 + facc], s = r[ac.c + 3 + facc]}
                ),
                ust.assembleSize(
                    {i = l[pl.c + 5 + fplc], s = l[pl.c + 4 + fplc]},
                    {i = r[ac.c + 5 + facc], s = r[ac.c + 4 + facc]}
            )
            })
    
    end
    
    local accessBuilder = function()
        local platformZ = config.hPlatform + 0.53
        local tZ = coor.transZ(config.hPlatform - 1.4)
        local fitModel = config.slope == 0 and ust.fitModel2D or ust.fitModel
        return pipe.new
            * {arcCoords[1], arcCoords[#arcCoords]}
            * pipe.mapi(sizeBuilder)
            * pipe.mapi(function(sizes, i)
                return sizes
                    * pipe.filter(pipe.noop())
                    * pipe.mapi(function(sizes, i)
                        local isLeftmost = i == 0
                        return func.map2({config.models.access .. "_upper", config.models.access .. "_lower"}, sizes, function(s, size)
                            return {
                                station.newModel(s .. (isLeftmost and "_br.mdl" or "_bl.mdl"),
                                    coor.transZ(-1.93) * coor.scaleZ(platformZ / 1.93) * coor.transZ(1.93), tZ,
                                    fitModel(3.75, 5, platformZ, size, false, not isLeftmost)
                                ),
                                station.newModel(s .. (isLeftmost and "_tl.mdl" or "_tr.mdl"),
                                    coor.transZ(-1.93) * coor.scaleZ(platformZ / 1.93) * coor.transZ(1.93), tZ,
                                    fitModel(3.75, 5, platformZ, size, true, isLeftmost)
                            )
                            }
                        end)
                    end)
            end)
            * pipe.flatten()
            * pipe.flatten()
            * pipe.flatten()
    end
    
    local terrainBuilder = function()
        return pipe.new
            / {
                equal = pipe.new
                * {arcCoords[1], arcCoords[#arcCoords]}
                * pipe.mapi(sizeBuilder)
                * pipe.map(function(sizes)
                    return sizes
                        * pipe.filter(pipe.noop())
                        * pipe.map(pipe.map(function(size)
                            return pipe.new / (size.lt .. tZ) / (size.lb .. tZ) / (size.rb .. tZ) / (size.rt .. tZ) * station.finalizePoly end))
                end)
                * pipe.flatten()
                * pipe.flatten()
            }
    end
    
    local streetBuilder = function()
        return pipe.new
            * {arcCoords[1], arcCoords[#arcCoords]}
            * pipe.mapi(function(p, i)
                local ac = p.access
                local pl = p.platform
                
                local outer, inner = i == 1 and ac.lc or ac.rc, i == 1 and pl.lc or pl.rc
                
                return func.map2({
                    p.hasLower and {
                        pt = outer[ac.c - 4 - floor(ac.c * 0.5)] .. tZ,
                        vec = (outer[pl.c - 4 - floor(pl.c * 0.5)] - inner[ac.c - 4 - floor(ac.c * 0.5)]):withZ(0):normalized()},
                    {
                        pt = outer[ac.c + 1] .. tZ,
                        vec = (outer[ac.c + 1] - inner[pl.c + 1]):withZ(0):normalized()},
                    p.hasUpper and {
                        pt = outer[ac.c + 4 + floor(ac.c * 0.5)] .. tZ,
                        vec = (outer[pl.c + 4 + floor(pl.c * 0.5)] - inner[ac.c + 4 + floor(ac.c * 0.5)]):withZ(0):normalized()}
                }, entryConfig.street[i], function(r, e) return e and r end)
            end)
            * pipe.flatten()
            * pipe.filter(pipe.noop())
            * pipe.map(function(l)
                return {
                    edge = pipe.new / {l.pt, l.pt + l.vec * 10, l.vec, l.vec},
                    snap = pipe.new / {false, true}
                }
            end)
            * function(ls) return {pipe.new
                * {ls * station.mergeEdges}
                * station.prepareEdges
                * pipe.with({
                    type = "STREET",
                    params =
                    {
                        type = "ust_entry.lua",
                        tramTrackType = "NO"
                    }
                }
            )
            }
            end
    end
    
    local laneBuilder = function()
        local transZ = coor.transZ(-config.hPlatform - 0.53 - 7.5)
        return pipe.new
            * {arcCoords[1], arcCoords[#arcCoords]}
            * pipe.mapi(function(p, i)
                local su = p.surface
                local la = p.lane
                local ac = p.access
                local pl = p.platform
                local l = i == 1 and su.lc or su.rc
                local r = i == 1 and la.lc or la.rc
                local s = i == 1 and ac.lc or ac.rc
                local t = i == 1 and pl.lc or pl.rc
                local fsuc, flac, facc, fplc = floor(su.c * 0.5), floor(la.c * 0.5), floor(ac.c * 0.5), floor(pl.c * 0.5)
                local enabler = entryConfig.street[i]
                return pipe.new
                    / (p.hasLower and enabler[1] and {
                        ac = l[su.c - 4 - fsuc]:avg(l[su.c - 3 - fsuc]):avg(l[su.c - 3 - fsuc]),
                        pt = {
                            r[la.c - 3 - flac]:avg(r[la.c - 4 - flac])
                        },
                        st = {
                            e = s[ac.c - 4 - facc] / 6 + s[ac.c - 5 - facc] / 2 + t[pl.c - 4 - fplc] / 12 + t[pl.c - 5 - fplc] / 4,
                            pt = s[ac.c - 4 - facc],
                            vec = (s[ac.c - 4 - facc] - l[su.c - 4 - fsuc]):withZ(0):normalized()
                        }
                    })
                    / (enabler[2] and {
                        ac = l[su.c]:avg(l[su.c + 1]):avg(l[su.c]),
                        pt = {
                            r[la.c],
                            r[la.c + 1]:avg(r[la.c])
                        },
                        st = {
                            e = s[ac.c + 1] / 6 + s[ac.c + 2] / 2 + t[pl.c + 1] / 12 + t[pl.c + 2] / 4,
                            pt = s[ac.c + 1],
                            vec = (s[ac.c + 1] - l[su.c + 1]):withZ(0):normalized()
                        }
                    })
                    / (p.hasUpper and enabler[3] and {
                        ac = l[su.c + 4 + fsuc]:avg(l[su.c + 3 + fsuc]):avg(l[su.c + 3 + fsuc]),
                        pt = {
                            r[la.c + 3 + flac]:avg(r[la.c + 4 + flac])
                        },
                        st = {
                            e = s[ac.c + 4 + facc] / 6 + s[ac.c + 5 + facc] / 2 + t[pl.c + 4 + fplc] / 12 + t[pl.c + 5 + fplc] / 4,
                            pt = s[ac.c + 4 + facc],
                            vec = (s[ac.c + 4 + facc] - l[su.c + 4 + fsuc]):withZ(0):normalized()
                        }
                    })
            end)
            * pipe.mapi(function(sizes, i)
                return
                    sizes
                    * pipe.filter(pipe.noop())
                    * pipe.mapi(function(sizes, i)
                        local isLeftmost = i == 0
                        return func.map(sizes.pt, function(p)
                            return station.newModel("ust/person_lane.mdl", ust.mRot(sizes.ac - p), coor.trans(p))
                        end)
                    end)
                    +
                    sizes
                    * pipe.filter(pipe.noop())
                    * pipe.mapi(function(sizes, i)
                        local p = sizes.st.pt .. coor.transZ(-config.hPlatform - 0.53)
                        local e = sizes.st.e .. coor.transZ(-config.hPlatform - 0.53 + 0.05)
                        local v = sizes.st.vec
                        local pt1 = p + (v .. coor.rotZ(0.5 * pi)) * 3
                        local pt2 = p + (v .. coor.rotZ(-0.5 * pi)) * 3
                        return {
                            station.newModel("ust/person_lane.mdl", ust.mRot(e - pt1), coor.trans(pt1)),
                            station.newModel("ust/person_lane.mdl", ust.mRot(e - pt2), coor.trans(pt2))
                        }
                    end)
            end)
            * pipe.flatten()
            * pipe.flatten()
    end
    
    return {
        access = accessBuilder(),
        lane = laneBuilder(),
        terrain = terrainBuilder(),
        street = streetBuilder(),
        edgeBuilder = edgeBuilder,
        fenceFilter = fenceFilter
    }
end

local buildEntry = function(config, entryConfig, retriveRef)
    local allArcs = entryConfig.allArcs
    local gArcs = pipe.new * {ust.trackGrouping(pipe.new, table.unpack(allArcs))}
    
    local arcCoords = gArcs
        * pipe.map(pipe.filter(function(a) return #a > 1 end))
        * pipe.filter(function(g) return #g == 1 end)
        * pipe.flatten()
    
    local mixedCoords =
        gArcs
        * pipe.map(pipe.filter(function(a) return #a > 1 end))
        * pipe.filter(function(g) return #g > 1 end)
        * (function(ls) return table.unpack(ls) end)
    
    local retriveRef = retriveRef or function()
        local refArc = #arcCoords > 0 and arcCoords[1] or mixedCoords[1]
        
        local pl, la, su = refArc.platform, refArc.lane, refArc.surface
        local f = pipe.exec * function()
            if (entryConfig.main.pos == 0 or not entryConfig.main.model) then
                return function(set) return set.c end
            elseif (entryConfig.main.pos < 0) then
                return function(set) return set.c - 3 - floor(set.c * 0.5) end
            else
                return function(set) return set.c + 3 + floor(set.c * 0.5) end
            end
        end
        local refPt = la.lc[f(la)]
        return refPt, ust.mRot((su.lc[f(su)] - pl.lc[f(pl)]):normalized()), la.lc[f(la)], pl.lc[f(pl)]:avg(pl.rc[f(pl)])
    end
    
    local refPt, refMRot, cpt, cupt = retriveRef()
    
    local laneBuilder = function()
        local function retrive(pl, la)
            local flac = floor(la.c * 0.5)
            local fplc = floor(pl.c * 0.5)
            local ref = {
                n = pl.c > 5 and {l = la.c - 2, p = pl.c - 4} or {l = la.c - 1, p = pl.c - 2},
                p = pl.c > 5 and {l = la.c + 2, p = pl.c + 4} or {l = la.c + 1, p = pl.c + 2}
            }
            return flac, fplc, ref
        end
        
        local fn = function(p)
            local pl, la = p.platform, p.lane
            local flac, fplc, ref = retrive(pl, la)
            
            return pipe.new / ust.unitLane(la.mc[ref.n.l - 2]:avg(la.mc[ref.n.l - 3]), pl.mc[ref.n.p]) /
                ust.unitLane(la.mc[ref.p.l + 2]:avg(la.mc[ref.p.l + 3]), pl.mc[ref.p.p]) +
                (p.hasLower
                and {ust.unitLane(la.mc[la.c - 5 - flac]:avg(la.mc[la.c - 4 - flac]), pl.mc[pl.c - 4 - fplc])}
                or
                {})
                + (p.hasUpper
                and {ust.unitLane(la.mc[la.c + 5 + flac]:avg(la.mc[la.c + 4 + flac]), pl.mc[pl.c + 4 + fplc])} or
                {})
                + func.map(
                    il(func.range(pl.mc, pl.c - 3, pl.c + 3)),
                    function(c)
                        local b = c.i
                        local t = c.s
                        local vec = t - b
                        return station.newModel("ust/person_lane.mdl", ust.mRot(vec), coor.trans(b), coor.transZ(-3.5))
                    end
        )
        end
        
        local fn2 = function()
            local l, r = table.unpack(mixedCoords)
            local function seperated(p)
                local pl, la = p.platformO, p.lane
                local flac, fplc, ref = retrive(pl, la)
                
                return pipe.new + ((pl.intersection < (ref.n.l - 2)) and {ust.unitLane(la.mc[ref.n.l - 2]:avg(la.mc[ref.n.l - 3]), pl.mc[ref.n.p])} or {}) +
                    ((pl.intersection < (ref.p.l + 2)) and {ust.unitLane(la.mc[ref.p.l + 2]:avg(la.mc[ref.p.l + 3]), pl.mc[ref.p.p])} or {}) +
                    (p.hasLower and (pl.intersection < (pl.c - 4 - fplc)) and
                    {
                        ust.unitLane(la.mc[la.c - 5 - flac]:avg(la.mc[la.c - 4 - flac]), pl.mc[pl.c - 4 - fplc])
                    } or
                    {})
                    +
                    (p.hasUpper and (pl.intersection < (pl.c + 4 + fplc)) and
                    {
                        ust.unitLane(la.mc[la.c + 5 + flac]:avg(la.mc[la.c + 4 + flac]), pl.mc[pl.c + 4 + fplc])
                    } or
                    {})
                    +
                    ((pl.intersection < pl.c + 3) and
                    func.map(
                        il(func.range(pl.mc, func.max({pl.intersection, pl.c - 3}), pl.c + 3)),
                        function(c)
                            local b = c.i
                            local t = c.s
                            local vec = t - b
                            return station.newModel("ust/person_lane.mdl", ust.mRot(vec), coor.trans(b), coor.transZ(-3.5))
                        end
                    ) or
                    {})
            end
            
            local combined = function()
                local pl = {mc = func.map2(l.platformO.lc, r.platformO.rc, function(l, r) return l:avg(r) end), c = l.platformO.c, intersection = l.platformO.intersection}
                local la = {mc = func.map2(l.lane.lc, r.lane.rc, function(l, r) return l:avg(r) end), c = l.lane.c, intersection = l.lane.intersection}
                local flac, fplc, ref = retrive(pl, la)
                
                return pipe.new + ((pl.intersection > (ref.n.l - 2)) and {ust.unitLane(la.mc[ref.n.l - 2]:avg(la.mc[ref.n.l - 3]), pl.mc[ref.n.p])} or {}) +
                    ((pl.intersection > (ref.p.l + 2)) and {ust.unitLane(la.mc[ref.p.l + 2]:avg(la.mc[ref.p.l + 3]), pl.mc[ref.p.p])} or {}) +
                    (l.hasLower and (pl.intersection > (pl.c - 4 - fplc)) and
                    {
                        ust.unitLane(la.mc[la.c - 5 - flac]:avg(la.mc[la.c - 4 - flac]), pl.mc[pl.c - 4 - fplc])
                    } or
                    {})
                    +
                    (l.hasUpper and (pl.intersection > (pl.c + 4 + fplc)) and
                    {
                        ust.unitLane(la.mc[la.c + 5 + flac]:avg(la.mc[la.c + 4 + flac]), pl.mc[pl.c + 4 + fplc])
                    } or
                    {})
                    +
                    ((pl.intersection > pl.c - 3) and
                    func.map(
                        il(func.range(pl.mc, pl.c - 3, func.min({pl.intersection, pl.c + 3}))),
                        function(c)
                            local b = c.i
                            local t = c.s
                            local vec = t - b
                            return station.newModel("ust/person_lane.mdl", ust.mRot(vec), coor.trans(b), coor.transZ(-3.5))
                        end
                    ) or
                    {})
                    +
                    ((pl.intersection > pl.c - 3) and (pl.intersection < pl.c + 3) and {
                        station.newModel("ust/person_lane.mdl", ust.mRot(l.platformO.mc[pl.intersection] - pl.mc[pl.intersection]), coor.trans(pl.mc[pl.intersection]), coor.transZ(-3.5)),
                        station.newModel("ust/person_lane.mdl", ust.mRot(r.platformO.mc[pl.intersection] - pl.mc[pl.intersection]), coor.trans(pl.mc[pl.intersection]), coor.transZ(-3.5))
                    } or {})
            end
            
            return seperated(l) + seperated(r) + combined()
        end
        
        return arcCoords
            * pipe.map(fn)
            * pipe.flatten()
            + (mixedCoords and (pipe.exec * fn2) or {})
            +
            gArcs
            * pipe.map(pipe.filter(function(a) return #a > 1 end))
            * pipe.filter(function(g) return #g > 0 end)
            * pipe.map(function(g)
                if (#g == 1) then
                    local f = function(p)
                        local pl = p.platform
                        local fplc = floor(pl.c * 0.5)
                        return pipe.new / (pl.mc[pl.c] + coor.xyz(0, 0, -3.5)) /
                            (p.hasUpper and pl.mc[pl.c + 3 + fplc] - coor.xyz(0, 0, 3.5)) /
                            (p.hasLower and pl.mc[pl.c - 3 - fplc] - coor.xyz(0, 0, 3.5))
                    end
                    return {f(g[1])}
                else
                    local function retrive(pl, la)
                        local flac = floor(la.c * 0.5)
                        local fplc = floor(pl.c * 0.5)
                        local ref = {
                            n = pl.c > 5 and {l = la.c - 2, p = pl.c - 4} or {l = la.c - 1, p = pl.c - 2},
                            p = pl.c > 5 and {l = la.c + 2, p = pl.c + 4} or {l = la.c + 1, p = pl.c + 2}
                        }
                        return flac, fplc, ref
                    end
                    local function x(p)
                        local pl, la = p.platformO, p.lane
                        local flac, fplc, ref = retrive(pl, la)
                        return pipe.new
                            / (pl.intersection < (ref.n.l - 2) and (pl.mc[pl.c] + coor.xyz(0, 0, -3.5)))
                            / (p.hasUpper and (pl.intersection < (pl.c + 4 + fplc)) and pl.mc[pl.c + 3 + fplc] - coor.xyz(0, 0, 3.5))
                            / (p.hasLower and (pl.intersection < (pl.c - 4 - fplc)) and pl.mc[pl.c - 3 - fplc] - coor.xyz(0, 0, 3.5))
                    end
                    local combined = function(l, r)
                        local pl = {mc = func.map2(l.platformO.lc, r.platformO.rc, function(l, r) return l:avg(r) end), c = l.platformO.c, intersection = l.platformO.intersection}
                        local la = {mc = func.map2(l.lane.lc, r.lane.rc, function(l, r) return l:avg(r) end), c = l.lane.c, intersection = l.lane.intersection}
                        local flac, fplc, ref = retrive(pl, la)
                        
                        return pipe.new
                            / (pl.intersection > (ref.n.l - 2) and (pl.mc[pl.c] + coor.xyz(0, 0, -3.5)))
                            / (l.hasUpper and (pl.intersection > (pl.c + 4 + fplc)) and pl.mc[pl.c + 3 + fplc] - coor.xyz(0, 0, 3.5))
                            / (l.hasLower and (pl.intersection > (pl.c - 4 - fplc)) and pl.mc[pl.c - 3 - fplc] - coor.xyz(0, 0, 3.5))
                    end
                    return {x(g[1]), x(g[2]), combined(table.unpack(g))}
                end
            end)
            * pipe.flatten()
            * (function(ls) return {ls * pipe.map(pipe.select(1)), ls * pipe.map(pipe.select(2)), ls * pipe.map(pipe.select(3))} end)
            * pipe.map(pipe.filter(pipe.noop()))
            * pipe.map(pipe.interlace({"l", "r"}))
            * pipe.map(pipe.map(function(pt) return station.newModel("ust/person_lane.mdl", ust.mRot((pt.l - pt.r)), coor.trans(pt.r)) end))
            * pipe.flatten()
    end
    
    local accessBuilder = function()
        local mx = coor.transX(-config.buildingParams.xOffset) * refMRot * coor.trans(refPt)
        local m = coor.rotX(atan(-config.slope)) * mx
        return pipe.new *
            func.map(config.buildingParams.platform, function(p) return ust.unitLane(p .. m, cpt) end)
            + func.map(config.buildingParams.entry, function(p) return ust.unitLane(p .. m, coor.xyz(-10, p.y > 0 and 4.5 or -4.5, -0.8) .. mx) end)
            + func.map(config.buildingParams.pass, function(p) return ust.unitLane(p .. m, cupt - coor.xyz(0, 0, 3.5)) end)
            + {station.newModel(entryConfig.main.model, coor.rotZ(-pi * 0.5), m, coor.transZ(-0.78))}
    end
    
    local streetBuilder = function()
        local mVe = refMRot
        local mPt = coor.transX(-config.buildingParams.xOffset) * mVe * coor.trans(refPt)
        local mainAccess = {
            edge = pipe.new /
            {
            (config.buildingParams.street .. mPt):withZ(refPt.z - 0.8),
                ((config.buildingParams.street - coor.xyz(20, 0, 0)) .. mPt):withZ(refPt.z - 0.8),
                coor.xyz(-1, 0, 0) .. mVe,
                coor.xyz(-1, 0, 0) .. mVe
            },
            snap = pipe.new / {false, true}
        }
        
        return pipe.new /
            (pipe.new * {mainAccess} * station.prepareEdges *
            pipe.with(
                {
                    type = "STREET",
                    params = {
                        type = "station_new_small.lua",
                        tramTrackType = "NO"
                    }
                }
    ))
    end
    
    local terrainBuilder = function()
        local z = -0.8
        local mRot = coor.rotX(atan(-config.slope))
        local mX = coor.transX(-config.buildingParams.xOffset) * refMRot * coor.trans(refPt)
        local xMin = config.buildingParams.street.x
        local xMax = config.buildingParams.xOffset
        local yMin = -config.buildingParams.halfWidth
        local yMax = config.buildingParams.halfWidth
        return pipe.new
            / {
                equal = pipe.new
                / {
                    coor.xyz(config.buildingParams.entry[1].x, yMin, z) .. mRot * mX,
                    coor.xyz(xMax, yMin, z) .. mRot * mX,
                    coor.xyz(xMax, yMax, z) .. mRot * mX,
                    coor.xyz(config.buildingParams.entry[1].x, yMax, z) .. mRot * mX
                }
                / {
                    coor.xyz(config.buildingParams.street.x, yMin, z) .. mX,
                    coor.xyz(config.buildingParams.entry[1].x, yMin, z) .. mRot * mX,
                    coor.xyz(config.buildingParams.entry[1].x, yMax, z) .. mRot * mX,
                    coor.xyz(config.buildingParams.street.x, yMax, z) .. mX
                }
                * pipe.map(station.finalizePoly)
            }
    end
    
    local hasMain = entryConfig.main.model
    
    return {
        access = hasMain and accessBuilder() or {},
        lane = laneBuilder(),
        terrain = hasMain and terrainBuilder() or {},
        street = hasMain and streetBuilder() or {}
    }
end

ust.preBuild = function(totalTracks, nbTransitTracks, posTransitTracks, ignoreFst, ignoreLst)
    local function preBuild(nbTracks, result)
        local p = false
        local t = true
        local transitSeq = pipe.new * pipe.rep(nbTransitTracks)(t)
        if (nbTracks == 0) then
            local result = ignoreLst and result or (result[#result] and (result / p) or result)
            if (#transitSeq > 0) then
                if (posTransitTracks == 1) then
                    result = result + transitSeq
                else
                    local idx = result * pipe.zip(func.seq(1, #result), {"t", "i"}) * pipe.filter(function(p) return not p.t end) * pipe.map(pipe.select("i"))
                    result = result * pipe.range(1, idx[ceil(#idx * 0.5)]) + transitSeq + result * pipe.range(idx[ceil(#idx * 0.5)] + 1, #result)
                end
            end
            return result
        elseif (nbTracks == totalTracks and ignoreFst) then
            return preBuild(nbTracks - 1, result / t / p)
        elseif (nbTracks == totalTracks and not ignoreFst) then
            return preBuild(nbTracks - 1, result / p / t)
        elseif (nbTracks == 1 and ignoreLst) then
            return preBuild(nbTracks - 1, ((not result) or result[#result]) and (result / p / t) or (result / t))
        elseif (nbTracks == 1 and not ignoreLst) then
            return preBuild(nbTracks - 1, result / t / p)
        else
            return preBuild(nbTracks - 2, result / t / p / t)
        end
    end
    return preBuild
end

return {
    buildEntry = buildEntry,
    buildSecondEntrySlope = buildSecondEntrySlope,
    buildUndergroundEntry = buildUndergroundEntry
}
