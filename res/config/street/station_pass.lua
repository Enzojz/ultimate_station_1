function data()
    return {
        numLanes = 0,
        streetWidth = 3.0,
        sidewalkWidth = 3.0,
        sidewalkHeight = .0,
        yearFrom = 1925,
        yearTo = 0,
        upgrade = true,
        country = false,
        speed = 30.0,
        type = "station new small",
        name = _("Small street"),
        desc = _("Two-lane street with a speed limit of %2%"),
        materials = {
            streetPaving = {
                name = "street/new_small_paving.mtl",
                size = { 6.0, 6.0 }
            },		
            --streetBorder = {
                --name = "street/new_small_border.mtl",
                --size = { 1.5, 0.625 }
            
            --},			
            streetLane = {
                name = "street/new_small_lane.mtl",
                size = { 3.0, 3.0 }
            },
            streetStripe = {
    
            },
            streetStripeMedian = {
    
            },
            streetBus = {
            
            },
            streetTram = {
                name = "street/new_medium_tram.mtl",
                size = { 2.0, 2.0 }
            },
            crossingLane = {
                name = "street/new_small_lane.mtl",
                size = { 3.0, 3.0 }
            },
            crossingBus = {
                name = ""		
            },
            crossingTram = {
                name = "street/new_medium_tram.mtl",
                size = { 2.0, 2.0 }
            },
            crossingCrosswalk = {
                name = ""		
            },
            sidewalkPaving = {
                name = "street/new_small_paving.mtl",
                size = { 6.0, 6.0 }
            },
            sidewalkLane = {	
    
            },
            --sidewalkBorderInner = {
                --name = "street/new_medium_sidewalk_border_inner.mtl",		
                --size = { 3, 0.6 }
            --},
            sidewalkBorderOuter = {
                name = "street/new_small_sidewalk_border_outer.mtl",		
                size = { 16.0, 0.3 }
            },
            sidewalkCurb = {
                name = "street/new_medium_sidewalk_curb.mtl",
                size = { 3, .3 }
            },
            sidewalkWall = {
                name = "street/new_medium_sidewalk_wall.mtl",
                size = { .3, .3 }
            },
            catenary = {
                name = "street/tram_cable.mtl"
            }
        },
        assets = {
            {
                name = "asset/lamp_new.mdl",
                offset = 5.0,
                distance = 12.0,
                prob = 1.0,
                offsetOrth = 0.1,
                randRot = false,
                oneSideOnly = true,
                alignToElevation = false,
                avoidFaceEdges = false,
                placeOnBridge = true,
            }, 
            {
                name = "asset/hydrant_new.mdl",
                offset = 20.0,
                distance = 70.0,
                prob = 1.0,
                offsetOrth = 0.2,
                randRot = false,
                oneSideOnly = false,
                alignToElevation = true,
                avoidFaceEdges = false,
            }, 
        },
        catenary = {
            pole = {
                name = "asset/tram_pole.mdl",
                assets = { "asset/tram_pole_light.mdl" }  
            },
            poleCrossbar = {
                name = "asset/tram_pole_crossbar.mdl",
                assets = { "asset/tram_pole_light.mdl" }  
            },
            poleDoubleCrossbar = {
                name = "asset/tram_pole_double_crossbar.mdl",
                assets = { "asset/tram_pole_light.mdl" }  
            },
            isolatorStraight = "asset/cable_isolator.mdl",
            isolatorCurve = "asset/cable_isolator.mdl",
            junction = "asset/cable_junction.mdl"
        },
        signalAssetName = "asset/ampel.mdl",
        cost = 32.0,
    }
    end
    