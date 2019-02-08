local func = require "ustation/func"
local coor = require "ustation/coor"
local arc = require "ustation/coorarc"
local line = require "ustation/coorline"
local quat = require "ustation/quaternion"
local station = require "ustation/stationlib"
local pipe = require "ustation/pipe"
local livetext = require "ustation_livetext"

local dump = require "luadump"

local ustr = {}

local unpack = table.unpack
local math = math
local pi = math.pi
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local pow = math.pow
local e = math.exp(1)

local il = pipe.interlace({"s", "i"})

local ust = require "ustation"

local flip = function(c) return {s = c.i, i = c.s} end

local retrivePlatformModels = function(fitModel, platformZ, tZ)
    return function(c, ccl, ccr, w)
        return function(i, el, er, s, sx, edgeL, edgeR, surfaceL, surfaceR, stairL, stairR)
            local opFn = i >= c and pipe.noop() or flip
            local edgeL = opFn(edgeL)
            local edgeR = opFn(edgeR)
            local surfaceL = opFn(surfaceL)
            local surfaceR = opFn(surfaceR)
            local stairL = opFn(stairL)
            local stairR = opFn(stairR)
            
            local sizeLe = ust.assembleSize(edgeL, surfaceL)
            local sizeRe = ust.assembleSize(surfaceR, edgeR)
            
            local surface = pipe.exec * function()
                if (stairL.i and stairR.i and stairL.s and stairR.s and (s ~= sx)) then
                    local sizeLs = ust.assembleSize(surfaceL, stairL)
                    local sizeRs = ust.assembleSize(stairR, surfaceR)
                    local sizeC = ust.assembleSize(stairL, stairR)
                    
                    return pipe.new
                        / station.newModel(sx .. "_br.mdl", tZ, fitModel(2, 5, platformZ, sizeLs, false, false))
                        / station.newModel(sx .. "_tl.mdl", tZ, fitModel(2, 5, platformZ, sizeLs, true, true))
                        / station.newModel(sx .. "_br.mdl", tZ, fitModel(2, 5, platformZ, sizeRs, false, false))
                        / station.newModel(sx .. "_tl.mdl", tZ, fitModel(2, 5, platformZ, sizeRs, true, true))
                        / station.newModel(s .. "_br.mdl", tZ, fitModel(2, 5, platformZ, sizeC, false, false))
                        / station.newModel(s .. "_tl.mdl", tZ, fitModel(2, 5, platformZ, sizeC, true, true))
                else
                    local sizeC = ust.assembleSize(surfaceL, surfaceR)
                    
                    return pipe.new
                        / station.newModel(s .. "_br.mdl", tZ, fitModel(2, 5, platformZ, sizeC, false, false))
                        / station.newModel(s .. "_tl.mdl", tZ, fitModel(2, 5, platformZ, sizeC, true, true))
                end
            end
            return surface
                / station.newModel(el .. "_br.mdl", tZ, fitModel(w, 5, platformZ, sizeLe, false, false))
                / station.newModel(el .. "_tl.mdl", tZ, fitModel(w, 5, platformZ, sizeLe, true, true))
                / station.newModel(er .. "_bl.mdl", tZ, fitModel(w, 5, platformZ, sizeRe, false, true))
                / station.newModel(er .. "_tr.mdl", tZ, fitModel(w, 5, platformZ, sizeRe, true, false))
        end
    end
end

local retriveModels = function(fitModel, platformZ, tZ)
    return function(c, ccl, ccr, w)
        local buildSurface = ust.buildSurface(fitModel, platformZ, tZ)(c, 5 - w * 2)
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

ustr.generateModels = function(fitModel, config)
    local tZ = coor.transZ(config.hPlatform - 1.4)-- 1.4 = model height
    local platformZ = config.hPlatform + 0.53
    
    local buildSurface = ust.buildSurface(fitModel, platformZ, tZ)
    local retriveModels = retriveModels(fitModel, platformZ, tZ)
    local retrivePlatformModels = retrivePlatformModels(fitModel, platformZ, tZ)
    local buildPoles = ust.buildPoles(config, platformZ, tZ)
    local buildChairs = ust.buildChairs(config, platformZ, tZ)
    
    return function(arcs, edgeBuilder)
        local edgeBuilder = edgeBuilder or function(platformEdgeO, _) return platformEdgeO, platformEdgeO end
        
        local platformSurface = pipe.new
            * pipe.rep(arcs.platform.surface.c - 2)(config.models.surface)
            * pipe.mapi(function(p, i) return (i == (arcs.platform.surface.c > 5 and 4 or 2) or (i == floor(arcs.platform.surface.c * 0.5) + 4) and (arcs.hasLower or arcs.hasUpper)) and config.models.stair or config.models.surface end)
            / config.models.extremity
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(arcs.platform.surface.c - 1)(config.models.surface)) or (ls * pipe.rev() + ls) end)
        
        local platformSurfaceEx = pipe.new
            * pipe.rep(arcs.platform.surface.c - 2)(config.models.surface)
            / config.models.extremity
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(arcs.platform.surface.c - 1)(config.models.surface)) or (ls * pipe.rev() + ls) end)
        
        local platformEdgeO = pipe.new
            * pipe.rep(arcs.platform.edge.c - 2)(config.models.edge)
            / config.models.corner
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(arcs.platform.edge.c - 1)(config.models.edge)) or (ls * pipe.rev() + ls) end)
        
        local platformEdgeL, platformEdgeR = edgeBuilder(platformEdgeO, arcs.platform.edge.c)
        
        local roofSurface = pipe.new
            * pipe.rep(arcs.roof.surface.c - 2)(config.models.roofTop)
            / config.models.roofExtremity
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(arcs.roof.surface.c - 1)(config.models.roofTop)) or (ls * pipe.rev() + ls) end)
        
        local roofEdge = pipe.new
            * pipe.rep(arcs.roof.edge.c - 2)(config.models.roofEdge)
            / config.models.roofCorner
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(arcs.roof.edge.c - 1)(config.models.roofEdge)) or (ls * pipe.rev() + ls) end)
        
        local newModels = pipe.mapn(
            func.seq(1, 2 * arcs.platform.surface.c - 2),
            platformEdgeL,
            platformEdgeR,
            platformSurface,
            platformSurfaceEx,
            il(arcs.platform.edge.lc),
            il(arcs.platform.edge.rc),
            il(arcs.platform.surface.lc),
            il(arcs.platform.surface.rc),
            il(arcs.platform.stair.lc),
            il(arcs.platform.stair.rc)
        )(retrivePlatformModels(
            arcs.platform.surface.c,
            arcs.platform.surface.c,
            arcs.platform.surface.c,
            config.width.edge)
        )
        local chairs = buildChairs(
            arcs.platform.chair.lc,
            arcs.platform.chair.rc,
            arcs.platform.chair.mc,
            arcs.platform.chair.c,
            1, 2 * arcs.platform.chair.c - 1)
        
        local newRoof = config.roofLength == 0
            and {}
            or pipe.new * pipe.mapn(
                func.seq(1, 2 * arcs.roof.surface.c - 2),
                roofEdge,
                roofEdge,
                roofSurface,
                roofSurface,
                il(arcs.roof.edge.lc),
                il(arcs.roof.edge.rc),
                il(arcs.roof.surface.lc),
                il(arcs.roof.surface.rc)
            )(retriveModels(
                arcs.roof.edge.c,
                arcs.roof.edge.c,
                arcs.roof.edge.c,
                config.width.roof.edge))
            /
            buildPoles(
                arcs.roof.pole.mc,
                arcs.roof.pole.c,
                1,
                arcs.roof.pole.c * 2 - 1
        )
        return (pipe.new / newModels / newRoof / chairs) * pipe.flatten() * pipe.flatten()
    end
end


ustr.generateModelsDual = function(fitModel, config)
    local tZ = coor.transZ(config.hPlatform - 1.4)
    local platformZ = config.hPlatform + 0.53
    
    local buildSurface = ust.buildSurface(fitModel, platformZ, tZ)
    local retriveModels = retriveModels(fitModel, platformZ, tZ)
    
    local buildPoles = ust.buildPoles(config, platformZ, tZ)
    local buildChairs = ust.buildChairs(config, platformZ, tZ)
    
    return function(arcsL, arcsR, edgeBuilder)
        local edgeBuilder = edgeBuilder or function(platformEdgeO, _) return platformEdgeO, platformEdgeO end
        
        local platformModels = function()
            local intersection = arcsL.platform.edge.intersection
            local commonLength = arcsL.platform.edge.common
            
            local function modelSeq(arcs, isLeft)
                local c = arcs.platform.surface.c
                
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
                local lc, rc, lic, ric, c = arcsL.platform.edge.lc, arcsR.platform.edge.rc, arcsL.platform.surface.lc, arcsR.platform.surface.rc, arcsL.platform.surface.c
                return pipe.mapn(
                    func.seq(1, intersection - 1),
                    models.l.platformEdgeL,
                    models.r.platformEdgeR,
                    models.l.platformSurface,
                    models.l.platformSurfaceEx,
                    il(lc), il(rc), il(lic), il(ric)
                )(retriveModels(c, c, c, config.width.edge))
            end
            
            local function middlePart()
                local lc, rc, c = arcsL.platform.edge.rc, arcsR.platform.edge.lc, arcsL.platform.surface.c
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
                local lc, rc, lic, ric, c = arcsL.platform.edge.lc, arcsL.platform.edge.rc, arcsL.platform.surface.lc, arcsL.platform.surface.rc, arcsL.platform.surface.c
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
                return pipe.new + fn(intersection, #models.l.platformEdgeL)(retriveModels(c, c, commonLength, config.width.edge))
            end
            
            local function rightPart()
                local lc, rc, lic, ric, c = arcsR.platform.edge.lc, arcsR.platform.edge.rc, arcsR.platform.surface.lc, arcsR.platform.surface.rc, arcsR.platform.surface.c
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
                return pipe.new + fn(intersection, #models.r.platformEdgeL)(retriveModels(c, commonLength, c, config.width.edge))
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
                )(retriveModels(c, c, c, config.width.roof.edge))
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
                return pipe.new + fn(intersection, commonLength)(buildSurface(commonLength, config.width.roof.surface))
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
                return pipe.new + fn(intersection, #models.l.roofEdge)(retriveModels(c, c, commonLength, config.width.roof.edge))
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
                return pipe.new + fn(intersection, #models.r.roofEdge)(retriveModels(c, commonLength, c, config.width.roof.edge))
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
            + buildChairs(arcsL.platform.chair.lc, arcsL.platform.chair.rc, arcsL.platform.chair.mc, arcsL.platform.chair.c, arcsL.platform.chair.intersection, arcsL.platform.chair.c * 2 - 1)
            + buildChairs(arcsR.platform.chair.lc, arcsR.platform.chair.rc, arcsR.platform.chair.mc, arcsR.platform.chair.c, arcsR.platform.chair.intersection, arcsR.platform.chair.c * 2 - 1)
            + buildChairs(
                pipe.range(1, pipe.min()({#arcsL.platform.chair.lc, #arcsR.platform.chair.lc}))(arcsL.platform.chair.lc),
                pipe.range(1, pipe.min()({#arcsL.platform.chair.rc, #arcsR.platform.chair.rc}))(arcsR.platform.chair.rc),
                pipe.mapn(
                    pipe.range(1, pipe.min()({#arcsL.platform.chair.mc, #arcsR.platform.chair.mc}))(arcsL.platform.chair.mc),
                    pipe.range(1, pipe.min()({#arcsL.platform.chair.mc, #arcsR.platform.chair.mc}))(arcsR.platform.chair.mc)
                )
                (function(l, r) return l:avg(r) end),
                pipe.min()({arcsL.platform.chair.c, arcsR.platform.chair.c}), 1, arcsL.platform.chair.intersection)
        
        return (platformModels() + (config.roofLength == 0 and {} or roofModels()) + chairs) * pipe.flatten()
    end
end

local mc = function(lc, rc) return func.map2(lc, rc, function(l, r) return l:avg(r) end) end

ustr.build = function(config, fitModel, entries, generateEdges)
    local generateEdges = config.isTerminal and ust.generateEdgesTerminal or ust.generateEdges
    local generateModels = ustr.generateModels(fitModel, config)
    local generateModelsDual = ustr.generateModelsDual(fitModel, config)
    local generateTerminals = ust.generateTerminals(config)
    local generateTerminalsDual = ust.generateTerminalsDual(config)
    local generateFences = ust.generateFences(fitModel, config)
    local generateTerrain = ust.generateTerrain(config)
    local generateTerrainDual = ust.generateTerrainDual(config)
    local generateTrackTerrain = ust.generateTrackTerrain(config)
    local generateHole = ust.generateHole(config)
    local buildTerminal = ust.buildTerminal(fitModel, config)
    local function build(edges, terminals, terminalsGroup, models, terrain, hole, gr, ...)
        local isLeftmost = #models == 0
        local isRightmost = #{...} == 0
        
        local models, terrain = unpack((isLeftmost and config.isTerminal) and {buildTerminal({gr, ...})} or {models, terrain})
        
        if (gr == nil) then
            local buildEntryPath = entries * pipe.map(pipe.select("access")) * pipe.flatten()
            local buildFace = entries * pipe.map(pipe.select("terrain")) * pipe.flatten()
            local buildAccessRoad = entries * pipe.map(pipe.select("street")) * pipe.flatten()
            local buildLanes = entries * pipe.map(pipe.select("lane")) * pipe.flatten()
            return edges, buildAccessRoad, terminals, terminalsGroup,
                (models + buildEntryPath + buildLanes) * pipe.filter(pipe.noop()),
                terrain + buildFace, hole
        elseif (#gr == 3 and gr[1].isTrack and gr[2].isPlatform and gr[3].isTrack) then
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
                hole + generateHole(gr[2]),
                ...)
        elseif (#gr == 2 and gr[1].isTrack and gr[2].isPlatform) then
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
                hole + generateHole(gr[2]),
                ...)
        elseif (#gr == 2 and gr[1].isPlatform and gr[2].isTrack) then
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
                hole + generateHole(gr[1]),
                ...)
        elseif (#gr == 1 and gr[1].isPlatform) then
            local terminals, terminalsGroup = generateTerminals(edges, terminals, terminalsGroup, gr[1], {false, false})
            return build(edges,
                terminals,
                terminalsGroup,
                models
                + generateModels(gr[1], entries[3].edgeBuilder(isLeftmost, isRightmost))
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, false, entries[3].fenceFilter) or {})
                + (config.rightFences and isRightmost and generateFences(gr[1][1], false, false, entries[3].fenceFilter) or {}),
                terrain + generateTerrain(gr[1]),
                hole + generateHole(gr[1]),
                ...)
        elseif (#gr == 2 and gr[1].isPlatform and gr[2].isPlatform) then
            local terminals, terminalsGroup = generateTerminalsDual(edges, terminals, terminalsGroup, gr[1], gr[2], {false, false})
            return build(edges,
                terminals,
                terminalsGroup,
                models
                + generateModelsDual(gr[1], gr[2], entries[3].edgeBuilder(isLeftmost, isRightmost))
                + (config.leftFences and isLeftmost and generateFences(gr[1][1], true, false, entries[3].fenceFilter) or {})
                + (config.rightFences and isRightmost and generateFences(gr[2][2], false, false, entries[3].fenceFilter) or {}),
                terrain + generateTerrainDual(gr[1], gr[2]),
                hole + generateHole(gr[1]) + generateHole(gr[2]),
                ...)
        elseif (#gr == 3 and gr[1].isPlatform and gr[2].isPlatform and gr[3].isTrack) then
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
                hole + generateHole(gr[1]) + generateHole(gr[2]),
                ...)
        elseif (#gr == 4 and gr[1].isTrack and gr[2].isPlatform and gr[3].isPlatform and gr[4].isTrack) then
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
                hole + generateHole(gr[2]) + generateHole(gr[3]),
                ...)
        else
            local edges = generateEdges(edges, false, gr[1][1])
            return build(edges,
                terminals,
                terminalsGroup,
                models,
                terrain + generateTrackTerrain(gr[1][1]),
                hole,
                ...)
        end
    end
    return build
end

return func.with(ust, ustr)
