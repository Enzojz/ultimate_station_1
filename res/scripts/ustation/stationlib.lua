local func = require "ustation/func"
local pipe = require "ustation/pipe"
local coor = require "ustation/coor"

local abs = math.abs

local stationlib = {
    platformWidth = 5,
    trackWidth = 5,
    segmentLength = 20,
    infi = 1e8
}

stationlib.newModel = function(m, ...)
    return {
        id = m,
        transf = coor.mul(...)
    }
end

local snapNodes = function(edges)
    return edges
        * pipe.mapFlatten(pipe.select("snap"))
        * pipe.flatten()
        * function(ls) return ls * pipe.zip(func.seq(0, #ls - 1), {"snap", "index"}) end
        * pipe.filter(pipe.select("snap"))
        * pipe.map(pipe.select("index"))
end

stationlib.prepareEdges = function(edges)
    return {
        edges = edges * pipe.mapFlatten(pipe.select("edge")) * pipe.map(pipe.map(coor.vec2Tuple)) * coor.make,
        snapNodes = snapNodes(edges)
    }
end

stationlib.mergeEdges = function(edges)
    return {
        edge = func.mapFlatten(edges, pipe.select("edge")),
        snap = func.mapFlatten(edges, pipe.select("snap")),
    }
end

stationlib.basePt = pipe.new * {
    coor.xyz(-0.5, -0.5, 0),
    coor.xyz(0.5, -0.5, 0),
    coor.xyz(0.5, 0.5, 0),
    coor.xyz(-0.5, 0.5, 0)
}

stationlib.surfaceOf = function(size, center, ...)
    local tr = {...}
    return stationlib.basePt
        * pipe.map(function(f) return (f .. coor.scale(size) * coor.trans(center)) end)
        * pipe.map(function(f) return func.fold(tr, f, function(v, m) return v .. m end) end)
        * pipe.map(function(v) return v:toTuple() end)
end

local applyResult = function(mpt, mvec, mirrored)
    mirrored = mirrored or false
    return function(result)
        local mapEdgeList = function(edgeList)
            return func.with(edgeList, {edges = func.map(edgeList.edges, coor.applyEdge(mpt, mvec))})
        end
        
        local mapModel = function(model) return func.with(model, {transf = model.transf * mpt}) end
        
        local mapTerrainList = function(ta)
            local mapTerrain = function(t) return (coor.tuple2Vec(t) .. mpt):toTuple() end
            local mapFaces = function(faces) return (mirrored and func.rev or func.nop)(func.map(faces, mapTerrain)) end
            return func.with(ta, {faces = func.map(ta.faces, mapFaces)})
        end
        
        local mapGroundFaces = function(gf)
            return func.with(gf, {face = func.map(mirrored and func.rev(gf.face) or gf.face, function(f) return (coor.tuple2Vec(f) .. mpt):toTuple() end)})
        end
        
        return func.with(result,
            {
                edgeLists = result.edgeLists and func.map(result.edgeLists, mapEdgeList) or {},
                models = result.models and func.map(result.models, mapModel) or {},
                terrainAlignmentLists = result.terrainAlignmentLists and func.map(result.terrainAlignmentLists, mapTerrainList) or {},
                groundFaces = result.groundFaces and func.map(result.groundFaces, mapGroundFaces) or {}
            })
    end
end

stationlib.setRotation = function(rad)
    return function(result)
        local mr = coor.rotZ(rad)
        return applyResult(mr, mr)(result)
    end
end

stationlib.setSlope = function(slope)
    return function(result)
        local mr = coor.rotX(math.atan(slope * 0.001))
        return applyResult(mr, mr)(result)
    end
end

stationlib.setHeight = function(dHeight)
    return function(result)
        local mz = coor.transZ(dHeight)
        return applyResult(mz, coor.I())(result)
    end
end

stationlib.setMirror = function(isMirror)
    return function(result)
        local mf = isMirror and coor.flipX() or coor.I()
        return applyResult(mf, mf, isMirror)(result)
    end
end

stationlib.cleanPoly = function(poly)
    return pipe.new * poly
    * function(p) return ((p[2] - p[1]):cross(p[3] - p[2]).z > 0 and pipe.noop() or pipe.rev())(poly) end
    * function(p) return #p == 4 and abs((p[1] - p[2]):cross(p[3] - p[2]).z) < 0.1 and {p[1], p[3], p[4]} or p end
    * function(p) return #p == 4 and abs((p[2] - p[3]):cross(p[4] - p[3]).z) < 0.1 and {p[1], p[2], p[4]} or p end
    * function(p) return #p == 4 and abs((p[3] - p[4]):cross(p[1] - p[4]).z) < 0.1 and {p[1], p[2], p[3]} or p end
    * function(p) return #p == 4 and abs((p[4] - p[1]):cross(p[2] - p[1]).z) < 0.1 and {p[2], p[3], p[4]} or p end
    * function(p) return #p == 3 and abs((p[1] - p[2]):cross(p[3] - p[2]).z) < 0.1 and nil or p end
end

stationlib.finalizePoly = function(poly)
    return pipe.new * poly
    * stationlib.cleanPoly
    * pipe.map(coor.vec2Tuple)
end

stationlib.mergePoly = function(...)
    local polys = pipe.new * {...}
    local p = {
        equal = polys * pipe.map(pipe.select("equal", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
        less = polys * pipe.map(pipe.select("less", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
        greater = polys * pipe.map(pipe.select("greater", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
        slot = polys * pipe.map(pipe.select("slot", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
        platform = polys * pipe.map(pipe.select("platform", {})) * pipe.filter(pipe.noop()) * pipe.flatten(),
    }
    
    return
        function(profile)
            profile = profile or {}
            
            return pipe.new * {
                {
                    type = "LESS",
                    faces = p.less,
                    slopeLow = profile.less or 0.75,
                    slopeHigh = profile.less or 0.75,
                },
                {
                    type = "GREATER",
                    faces = p.greater,
                    slopeLow = profile.greater or 0.75,
                    slopeHigh = profile.greater or 0.75,
                },
                {
                    type = "EQUAL",
                    faces = p.equal,
                    slopeLow = profile.equal or 0.75,
                    slopeHigh = profile.equal or 0.755,
                },
                {
                    type = "LESS",
                    faces = p.slot,
                    slopeLow = profile.slot or stationlib.infi,
                    slopeHigh = profile.slot or stationlib.infi,
                },
                {
                    type = "GREATER",
                    faces = p.platform,
                    slopeLow = profile.platform or stationlib.infi,
                    slopeHigh = profile.platform or stationlib.infi,
                },
            }
            * pipe.filter(function(e) return #e.faces > 0 end)
        end
end

return stationlib
