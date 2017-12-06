local func = require "ustation/func"
local pipe = require "ustation/pipe"
local coor = require "ustation/coor"

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

stationlib.joinEdges = function(edges)
    local function average(op1, op2) return (op1 + op2) * 0.5, (op1 + op2) * 0.5 end
    local fst = function(l) return l[1][1] end
    local lst = function(l) return l[#l][2] end
    local rev = function(l) return pipe.new
        * func.map(l, function(e)
            local f, t, vf, vt = table.unpack(e)
            return {t, f, -vt, -vf}
        end)
        * pipe.rev()
    end
    local joinEdge = function(l, r)
        local newL = l + {}
        local newR = r + {}
        newL[#l][2], newR[1][1] = average(newL[#l][2], newR[1][1])
        newL[#l][4], newR[1][3] = average(newL[#l][4], newR[1][3])
        return {newL, newR}
    end
    local connect = function(l, r)
        local pattern = {
            {fst, fst, function() return rev(l), r end},
            {fst, lst, function() return rev(l), rev(r) end},
            {lst, fst, function() return l, r end},
            {lst, lst, function() return l, rev(r) end}
        }
        return pipe.new
            * func.map(pattern, function(fns)
                local pl, pr, fadj = table.unpack(fns)
                return (pl(l) - pr(r)):length2() < 0.01
                    and joinEdge(fadj())
                    or nil
            end)
            * pipe.filter(pipe.noop())
            * function(ls) return #ls == 0 and {l, r} or ls[1] end
    end
    
    local function join(result, fst, snd, ...)
        local function fn(...)
            local newEdges = connect(fst.edge, snd.edge)
            return join(
                result / (func.with(fst, {edge = newEdges[1]})),
                func.with(snd, {edge = newEdges[2]}),
                ...
        )
        end
        return snd and fn(...) or result / fst
    end
    
    return #edges > 1 and join(pipe.new, table.unpack(edges)) or edges
end

stationlib.mergeEdges = function(edges)
    return {
        edge = func.mapFlatten(edges, pipe.select("edge")),
        snap = func.mapFlatten(edges, pipe.select("snap")),
    }
end

stationlib.fusionEdges = function(edges)
    local function transpose(result, ls, ...)
        return ls
            and (result
            and transpose(result * pipe.map2(ls, function(current, new) return current / new end),
                ...)
            or transpose(ls * pipe.map(function(_) return pipe.new end), ls, ...)
            )
            or result
    end
    return #edges > 0
        and transpose(nil, table.unpack(edges))
        * pipe.map(stationlib.joinEdges)
        * function(ls) return transpose(nil, table.unpack(ls)) end
        or {}
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

return stationlib
