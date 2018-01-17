local coor = require "ustation/coor"

local buildingList = {
    "main_building_size1.mdl",
    "main_building_size2.mdl",
    "main_building_size4.mdl",
    "main_building_size5.mdl",
}

local bZ = 0.8
local buildingParamsList = {
    {
        entry = {
            coor.xyz(-8, 1.5, -bZ),
            coor.xyz(-8, -1.5, -bZ)
        },
        platform = {
            coor.xyz(5, 1.5, 0),
            coor.xyz(5, -1.5, 0)
        },
        pass = {
            coor.xyz(1, 0, -bZ)
        },
        street = coor.xyz(-12 + 2, 0, 0),
        halfWidth = 9,
        xOffset = 5.3
    },
    {
        entry = {
            coor.xyz(-8, 1.5, -bZ),
            coor.xyz(-8, -1.5, -bZ)
        },
        platform = {
            coor.xyz(5, 1.5, 0),
            coor.xyz(5, -1.5, 0)
        },
        pass = {
            coor.xyz(0, 0, 0)
        },
        street = coor.xyz(-12 + 2, 0, 0),
        halfWidth = 15.5,
        xOffset = 5.3
    },
    {
        entry = {
            coor.xyz(-8, 1.5, -bZ),
            coor.xyz(-8, -1.5, -bZ)
        },
        platform = {
            coor.xyz(5, 1.8, 0),
            coor.xyz(5, -1.8, 0)
        },
        pass = {
            coor.xyz(0, 0, 0)
        },
        street = coor.xyz(-12 + 2, 0, 0),
        halfWidth = 22.5,
        xOffset = 5.3
    },
    {
        entry = {
            coor.xyz(-8, 1.5, -bZ),
            coor.xyz(-8, -1.5, -bZ)
        },
        platform = {
            coor.xyz(5, 1.8, 0),
            coor.xyz(5, -1.8, 0)
        },
        pass = {
            coor.xyz(0, 0, 0)
        },
        street = coor.xyz(-12 + 2, 0, 0),
        halfWidth = 30,
        xOffset = 5.3
    }
}

return {buildingList, buildingParamsList}