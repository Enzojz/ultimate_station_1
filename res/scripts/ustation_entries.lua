local func = require "ustation/func"
local coor = require "ustation/coor"
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
    local arcCoords = entryConfig.arcCoords
    local transZ = coor.transZ(-config.hPlatform - 0.53 - 7.5)
    
    local idxPt = allArcs
        * pipe.zip(func.seq(1, #allArcs), {"p", "i"})
        * pipe.filter(function(a) return #(a.p) == 2 end)
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
                    ls[1] and station.newModel("underground_entry.mdl",
                        coor.rotZ(-0.5 * pi),
                        coor.transX(fst == 1 and -0.5 or (fst - 1) * config.wTrack),
                        ust.mRot(ls[1].vec),
                        coor.trans(ls[1].pt)
                    ))
                    / (ls[2] and station.newModel("underground_entry.mdl",
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
                        ls[1].pt - vec1 + ls[1].vec * ((fst - 1) * config.wTrack + 15),
                        ls[1].pt + vec1 + ls[1].vec * ((fst - 1) * config.wTrack + 15)
                    })
                    / (ls[2] and {
                        ls[2].pt + vec2 + ls[2].vec * ((#allArcs - lst) * config.wTrack - 2),
                        ls[2].pt - vec2 + ls[2].vec * ((#allArcs - lst) * config.wTrack - 2),
                        ls[2].pt - vec2 + ls[2].vec * ((#allArcs - lst) * config.wTrack + 15),
                        ls[2].pt + vec2 + ls[2].vec * ((#allArcs - lst) * config.wTrack + 15)
                    })
                    * pipe.filter(pipe.noop())
            end)
            * pipe.flatten()
            * function(f)
                return pipe.new /
                    {
                        less = f * pipe.map(pipe.map(function(c) return c .. coor.transZ(0.53 + 7.5) end)) * pipe.map(station.finalizePoly),
                        slot = f * pipe.map(station.finalizePoly)
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
                    / (((ls[1] and ls[1].enabled) or (ls[2] and ls[2].enabled)) and #arcCoords > 1 and
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
                                    type = "station_pass.lua",
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
                                    type = "station_pass.lua",
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
                                    type = "station_pass_2.lua",
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
                        pl.lc[pl.c + 3 + fplc]:avg(pl.rc[pl.c + 3 + fplc]) - coor.xyz(0, 0, 3.5)
                    ))
                    / (p.hasLower and (entryConfig.underground[1][1] or entryConfig.underground[2][1]) and strCoor(
                        pl.rc[pl.c - 2 - fplc],
                        pl.lc[pl.c - 2 - fplc],
                        pl.lc[pl.c - 3 - fplc]:avg(pl.rc[pl.c - 3 - fplc]) - coor.xyz(0, 0, 3.5)
                    ))
                    / ((entryConfig.underground[1][2] or entryConfig.underground[2][2]) and strCoor(
                        pl.lc[pl.c],
                        pl.rc[pl.c],
                        pl.lc[pl.c + 2]:avg(pl.rc[pl.c + 2]) - coor.xyz(0, 0, 3.5)
                    ))
                    / ((entryConfig.underground[1][2] or entryConfig.underground[2][2]) and strCoor(
                        pl.rc[pl.c],
                        pl.lc[pl.c],
                        pl.lc[pl.c - 2]:avg(pl.rc[pl.c - 2]) - coor.xyz(0, 0, 3.5)
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

        local checker = function(p)
            return #func.filter(void, function(v) return (p - v[1]):dot(p - v[2]:avg(v[1])) < 0 end) == 0
        end
        
        return isTrack and function(_) return true end or function(c)
            if c.i then
                return c.i and checker(c.i) and checker(c.s)
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
            
            local platformEdgeL = isLeftmost and platformEdgeO * pipe.mapi(function(e, i) return func.contains(enabler[1], i) and i ~= 1 and i ~= #platformEdgeO and "platform_edge_open" or e end) or platformEdgeO
            local platformEdgeR = isRightmost and platformEdgeO * pipe.mapi(function(e, i) return func.contains(enabler[2], i) and i ~= 1 and i ~= #platformEdgeO and "platform_edge_open" or e end) or platformEdgeO
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
                        return func.map2({"platform_access_t_upper", "platform_access_t_lower"}, sizes, function(s, size)
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
                        type = "station_entry.lua",
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
                return sizes
                    * pipe.filter(pipe.noop())
                    * pipe.mapi(function(sizes, i)
                        local isLeftmost = i == 0
                        return func.map(sizes.pt, function(p)
                            return station.newModel("person_lane.mdl", ust.mRot(sizes.ac - p), coor.trans(p))
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
                            station.newModel("person_lane.mdl", ust.mRot(e - pt1), coor.trans(pt1)),
                            station.newModel("person_lane.mdl", ust.mRot(e - pt2), coor.trans(pt2))
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

local buildEntry = function(config, entryConfig)
    local allArcs = entryConfig.allArcs
    local arcCoords = entryConfig.arcCoords
    
    local function retriveRef()
        local pl, la = arcCoords[1].platform, arcCoords[1].lane
        if (entryConfig.main.pos == 0 or not entryConfig.main.model) then
            local refPt = la.lc[la.c]
            return refPt,
                la.l[1]:rad(refPt) - la.l[1]:rad(la.lc[la.c]),
                la.rc[la.c],
                pl.lc[pl.c]:avg(pl.rc[pl.c])
        elseif (entryConfig.main.pos < 0) then
            local refPt = la.lc[floor(la.c * 0.6)]
            return refPt,
                la.l[1]:rad(refPt) - la.l[1]:rad(la.lc[la.c]),
                la.rc[floor(la.c * 0.6)],
                pl.lc[pl.c - 3 - floor(pl.c * 0.5)]:avg(pl.rc[pl.c - 3 - floor(pl.c * 0.5)])
        else
            local refPt = la.lc[ceil(la.c * 1.4)]
            return refPt,
                la.l[2]:rad(refPt) - la.l[1]:rad(la.lc[la.c]),
                la.rc[ceil(la.c * 1.4)],
                pl.lc[pl.c + 3 + floor(pl.c * 0.5)]:avg(pl.rc[pl.c + 3 + floor(pl.c * 0.5)])
        end
    end
    
    local refPt, refVec, cpt, cupt = retriveRef()
    
    local laneBuilder = function()
        return arcCoords
            * pipe.map(function(p)
                local pl, la = p.platform, p.lane
                local flac = floor(la.c * 0.5)
                local fplc = floor(pl.c * 0.5)
                local ref = {
                    n = pl.c > 5 and {l = la.c - 2, p = pl.c - 4} or {l = la.c - 1, p = pl.c - 2},
                    p = pl.c > 5 and {l = la.c + 2, p = pl.c + 4} or {l = la.c + 1, p = pl.c + 2}
                }
                return pipe.new
                    / ust.unitLane(la.lc[ref.n.l - 2]:avg(la.rc[ref.n.l - 2], la.lc[ref.n.l - 3], la.rc[ref.n.l - 3]), pl.lc[ref.n.p]:avg(pl.rc[ref.n.p]))
                    / ust.unitLane(la.lc[ref.p.l + 2]:avg(la.rc[ref.p.l + 2], la.lc[ref.p.l + 3], la.rc[ref.p.l + 3]), pl.lc[ref.p.p]:avg(pl.rc[ref.p.p]))
                    +
                    (p.hasLower and {
                        ust.unitLane(la.lc[la.c - 5 - flac]:avg(la.rc[la.c - 5 - flac], la.rc[la.c - 4 - flac], la.lc[la.c - 4 - flac]), pl.lc[pl.c - 4 - fplc]:avg(pl.rc[pl.c - 4 - fplc]))
                    } or {})
                    +
                    (p.hasUpper and {
                        ust.unitLane(la.lc[la.c + 5 + flac]:avg(la.rc[la.c + 5 + flac], la.rc[la.c + 4 + flac], la.lc[la.c + 4 + flac]), pl.lc[pl.c + 4 + fplc]:avg(pl.rc[pl.c + 4 + fplc]))
                    } or {})
                    + func.map2(il(func.range(pl.lc, pl.c - 3, pl.c + 3)), il(func.range(pl.rc, pl.c - 3, pl.c + 3)), function(lc, rc)
                        local b = lc.i:avg(rc.i)
                        local t = lc.s:avg(rc.s)
                        local vec = t - b
                        return station.newModel("person_lane.mdl", ust.mRot(vec), coor.trans(b), coor.transZ(-3.5))
                    end)
            end)
            * pipe.flatten()
            +
            arcCoords
            * pipe.map(function(p)
                local pl, la = p.platform, p.lane
                local fplc = floor(pl.c * 0.5)
                return pipe.new
                    / (pl.lc[pl.c]:avg(pl.rc[pl.c]) + coor.xyz(0, 0, -3.5))
                    / (p.hasUpper and pl.lc[pl.c + 3 + fplc]:avg(pl.rc[pl.c + 3 + fplc]) - coor.xyz(0, 0, 3.5))
                    / (p.hasLower and pl.lc[pl.c - 3 - fplc]:avg(pl.rc[pl.c - 3 - fplc]) - coor.xyz(0, 0, 3.5))
            end)
            * (function(ls) return {ls * pipe.map(pipe.select(1)), ls * pipe.map(pipe.select(2)), ls * pipe.map(pipe.select(3))} end)
            * pipe.map(pipe.filter(pipe.noop()))
            * pipe.map(pipe.interlace({"l", "r"}))
            * pipe.map(pipe.map(function(pt) return station.newModel("person_lane.mdl", ust.mRot((pt.l - pt.r)), coor.trans(pt.r)) end))
            * pipe.flatten()
    end
    
    local accessBuilder = function()
        local mx = coor.transX(-config.buildingParams.xOffset) * coor.rotZ(refVec) * coor.trans(refPt)
        local m = coor.rotX(atan(-config.slope)) * mx
        return
            pipe.new
            * func.map(config.buildingParams.platform, function(p) return ust.unitLane(p .. m, cpt) end)
            + func.map(config.buildingParams.entry, function(p) return ust.unitLane(p .. m, coor.xyz(-10, p.y > 0 and 4.5 or -4.5, -0.8) .. mx) end)
            + func.map(config.buildingParams.pass, function(p) return ust.unitLane(p .. m, cupt - coor.xyz(0, 0, 3.5)) end)
            + {station.newModel(entryConfig.main.model, coor.rotZ(-pi * 0.5), m, coor.transZ(-0.78))}
    end
    
    local streetBuilder = function()
        local mVe = coor.rotZ(refVec)
        local mPt = coor.transX(-config.buildingParams.xOffset) * mVe * coor.trans(refPt)
        local mainAccess = {
            edge = pipe.new / {
            (config.buildingParams.street .. mPt):withZ(refPt.z - 0.8),
                ((config.buildingParams.street - coor.xyz(20, 0, 0)) .. mPt):withZ(refPt.z - 0.8),
                coor.xyz(-1, 0, 0) .. mVe,
                coor.xyz(-1, 0, 0) .. mVe
            },
            snap = pipe.new / {false, true}
        }
        
        return pipe.new
            / (pipe.new
            * {mainAccess}
            * station.prepareEdges
            * pipe.with(
                {
                    type = "STREET",
                    params =
                    {
                        type = "station_new_small.lua",
                        tramTrackType = "NO"
                    }
                })
    )
    end
    
    local terrainBuilder = function()
        local z = -0.8
        local mRot = coor.rotX(atan(-config.slope))
        local mX = coor.transX(-config.buildingParams.xOffset) * coor.rotZ(refVec) * coor.trans(refPt)
        local xMin = config.buildingParams.street.x
        local xMax = config.buildingParams.xOffset
        local yMin = -config.buildingParams.halfWidth
        local yMax = config.buildingParams.halfWidth
        return pipe.new / {
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

return {
    buildEntry = buildEntry,
    buildSecondEntrySlope = buildSecondEntrySlope,
    buildUndergroundEntry = buildUndergroundEntry
}