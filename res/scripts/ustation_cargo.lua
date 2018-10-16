local func = require "ustation/func"
local coor = require "ustation/coor"
local arc = require "ustation/coorarc"
local line = require "ustation/coorline"
local quat = require "ustation/quaternion"
local station = require "ustation/stationlib"
local pipe = require "ustation/pipe"
local ust = require "ustation/ustation"

local math = math
local pi = math.pi
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local pow = math.pow
local e = math.exp(1)

local il = pipe.interlace({"s", "i"})

ust.unitLane = function(f, t) return ((t - f):length2() > 1e-2 and (t - f):length2() < 562500) and station.newModel("ust/cargo_lane.mdl", ust.mRot(t - f), coor.trans(f)) or nil end

ust.generateEdgesTerminal = function(edges, isLeft, arcPacker)
    local arcs = arcPacker()()()
    local eInf, eSup = table.unpack(arcs * pipe.map2(isLeft and {pipe.noop(), pipe.noop()} or {arc.rev, arc.rev}, function(a, op) return op(a) end) * pipe.map(ust.generateArc))
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
            edge = pipe.new / eInf / eSup + arcs * pipe.mapFlatten(ust.generateArcExt) * function(ls) return {ls[2]} end,
            snap = pipe.new / {false, false} / {false, false} / {false, true}
        }
end

local retriveLanes = function(config)
    return 
    (config.isCargo and "ust/terminal_cargo_lane.mdl" or "ust/terminal_lane.mdl"),
    (config.isCargo and "ust/standard_cargo_lane.mdl" or "ust/standard_lane.mdl")
end

ust.generateTerminals = function(config)
    local platformZ = config.hPlatform + 0.53
    local edgeRule = config.isTerminal and function(edges) return #edges * 8 - 12 end or function(edges) return #edges * 8 - 16 end
    local terminalLane, standardLane = retriveLanes(config)
    return function(edges, terminals, terminalsGroup, arcs, enablers)
        local lc, rc, c = arcs.lane.lc, arcs.lane.rc, arcs.lane.c
        local newTerminals = pipe.new
            * pipe.mapn(il(lc), il(rc))(function(lc, rc)
                return {
                    l = station.newModel(enablers[1] and terminalLane or standardLane, ust.mRot(lc.s - lc.i), coor.trans(lc.i)),
                    r = station.newModel(enablers[2] and terminalLane or standardLane, ust.mRot(rc.i - rc.s), coor.trans(rc.s)),
                    link = (lc.s:avg(lc.i) - rc.s:avg(rc.i)):length() > 0.5 and station.newModel(standardLane, ust.mRot(lc.s:avg(lc.i) - rc.s:avg(rc.i)), coor.trans(rc.i:avg(rc.s)))
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
            + func.map(
            (enablers[1] and enablers[2]) and {
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[1]) * pipe.map(function(s) return {s - 1 + #terminals, 0} end),
                    fVehicleNodeOverride = function(n) return #edges * n - n * 2 end
                },
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[2]) * pipe.map(function(s) return {s - 1 + #terminals + #newTerminals[1], 0} end),
                    fVehicleNodeOverride = function(n) return #edges * n - n + 1 end
                }
            } or enablers[1] and {
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[1]) * pipe.map(function(s) return {s - 1 + #terminals, 0} end),
                    fVehicleNodeOverride = function(n) return #edges * n - n end
                }
            } or enablers[2] and {
                {
                    terminals = pipe.new * func.seq(1, #newTerminals[2]) * pipe.map(function(s) return {s - 1 + #terminals + #newTerminals[1], 0} end),
                    fVehicleNodeOverride = function(n) return #edges * n - n + 1 end
                }
            } or {}, function(t)
                return {
                    terminals = t.terminals,
                    vehicleNodeOverride = t.fVehicleNodeOverride(config.isTerminal and 6 or 8)
                }
            end
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

ust.generateModels = function(fitModel, config)
    local tZ = coor.transZ(config.hPlatform - 1.4)
    local platformZ = config.hPlatform + 0.53
    
    local buildSurface = buildSurface(fitModel, platformZ, tZ)
    local retriveModels = retriveModels(fitModel, platformZ, tZ)
    
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
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(c - 1)(config.models.surface)) or (ls * pipe.rev() + ls) end)
        
        local platformSurfaceEx = pipe.new
            * pipe.rep(c - 2)(config.models.surface)
            / config.models.extremity
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(c - 1)(config.models.surface)) or (ls * pipe.rev() + ls) end)
        
        local platformEdgeO = pipe.new
            * pipe.rep(c - 2)(config.models.edge)
            / config.models.corner
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(c - 1)(config.models.edge)) or (ls * pipe.rev() + ls) end)
        
        local platformEdgeL, platformEdgeR = edgeBuilder(platformEdgeO, c)
        
        local roofSurface = pipe.new
            * pipe.rep(pc - 2)(config.models.roofTop)
            / config.models.roofExtremity
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(c - 1)(config.models.roofTop)) or (ls * pipe.rev() + ls) end)
        
        local roofEdge = pipe.new
            * pipe.rep(pc - 2)(config.models.roofEdge)
            / config.models.roofCorner
            * (function(ls) return config.isTerminal and (ls * pipe.rev() + pipe.rep(c - 1)(config.models.roofEdge)) or (ls * pipe.rev() + ls) end)
        
        local newModels = pipe.mapn(
            func.seq(1, 2 * c - 2),
            platformEdgeL,
            platformEdgeR,
            platformSurface,
            platformSurfaceEx,
            il(lc), il(rc), il(lic), il(ric)
        )(retriveModels(c, c, c, 0.8))
        
        return (pipe.new / newModels) * pipe.flatten() * pipe.flatten()
    end
end

ust.build = function(config, fitModel, entries, generateEdges)
    local generateEdges = config.isTerminal and ust.generateEdgesTerminal or ust.generateEdges
    local generateModels = ust.generateModels(fitModel, config)
    local generateModelsDual = ust.generateModelsDual(fitModel, config)
    local generateTerminals = ust.generateTerminals(config)
    local generateTerminalsDual = ust.generateTerminalsDual(config)
    local generateFences = ust.generateFences(fitModel, config)
    local generateTerrain = ust.generateTerrain(config)
    local generateTerrainDual = ust.generateTerrainDual(config)
    local generateTrackTerrain = ust.generateTrackTerrain(config)
    local buildTerminal = ust.buildTerminal(fitModel, config)
    local function build(edges, terminals, terminalsGroup, models, terrain, gr, ...)
        local isLeftmost = #models == 0
        local isRightmost = #{...} == 0
        
        local models, terrain = table.unpack((isLeftmost and config.isTerminal) and {buildTerminal({gr, ...})} or {models, terrain})
        
        if (gr == nil) then
            local buildEntryPath = entries * pipe.map(pipe.select("access")) * pipe.flatten()
            local buildFace = entries * pipe.map(pipe.select("terrain")) * pipe.flatten()
            local buildAccessRoad = entries * pipe.map(pipe.select("street")) * pipe.flatten()
            local buildLanes = entries * pipe.map(pipe.select("lane")) * pipe.flatten()
            return edges, buildAccessRoad, terminals, terminalsGroup,
                (models + buildEntryPath + buildLanes) * pipe.filter(pipe.noop()),
                terrain + buildFace
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

ust.entryConfig = function(config, allArcs, arcCoords, ignoreMain)
    local isLeftTrack = allArcs[1].isTrack
    local isRightTrack = allArcs[#allArcs].isTrack
    local withoutMainLeft = function(i) return
        (not config.isTerminal and isLeftTrack)
            or ignoreMain
            or (not config.entries.main.isLeft)
            or (not config.entries.main.model)
            or config.entries.main.pos + 2 ~= i
    end
    local withoutMainRight = function(i) return
        (not config.isTerminal and isRightTrack)
            or ignoreMain 
            or config.entries.main.isLeft
            or (not config.entries.main.model)
            or config.entries.main.pos + 2 ~= i
    end
    return {
        main = (not config.isTerminal and isLeftTrack) and {pos = false, model = false} or config.entries.main,
        street = {
            func.mapi(config.entries.street[1], function(t, i) return t and withoutMainLeft(i) and not isLeftTrack end),
            func.mapi(config.entries.street[2], function(t, i) return t and withoutMainRight(i) and not isRightTrack end),
        },
        underground = {
            func.mapi(config.entries.underground[1], function(t, i) return
                (t or (isLeftTrack and config.entries.street[1][i])) and withoutMainLeft(i) end),
            func.mapi(config.entries.underground[2], function(t, i) return
                (t or (isRightTrack and config.entries.street[2][i])) and withoutMainRight(i) end)
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

return ust
