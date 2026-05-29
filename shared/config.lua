Config = {}

-- Load garage and vehicle data from JSON files
GarageZone = lib.loadJson('data.garages') ---@type table<string, GarageData>
CNV = lib.loadJson('data.vehiclesname') ---@type table<string, CustomName>

Config.Target = 'ox'           -- ox / qb
Config.RadialMenu = 'ox'       --- ox / qb / rhd
Config.FuelScript = 'cdn-fuel' --- rhd_fuel / ox_fuel / LegacyFuel / ps-fuel / cdn-fuel
Config.changeNamePrice = 15000 --- price for changing the name of the vehicle in the garage
Config.SpawnInVehicle = false  --- change this to true if you want the player to immediately enter the vehicle when the vehicle is taken out of the garage
Config.VehiclesInAllGarages = true --- Opção ZAP: deixe true para todos os veículos do player aparecerem em todas as garagens
Config.DisableVehicleCamera = false --- Desativa a movimentação de câmera ao puxar o veículo
Config.LocateVehicleOutGarage = true --- Opção ZAP: encontrar veículos fora da garagem

--- Additional: (Requires ox_target or qb-target resource)
Config.UseJobVechileShop = false --- Change this to false if you do not want to use the work vehicle shop system from rhd
Config.UsePoliceImpound = true  --- change it to false if you don't want to use the police impound system from rhd

Config.InDevelopment = true     --- Turn this off when you have finished setting up this garage

-- Vehicle transfer settings
Config.TransferVehicle = {
    enable = true,  --- Enable or disable vehicle transfer functionality
    price = 100     --- Price for transferring a vehicle
}

-- Garage swap settings
Config.SwapGarage = {
    enable = true,  --- Enable or disable garage swapping functionality
    price = 500     --- Price for swapping garages
}

Config.GiveKeys = {
    tempkeys = false, -- true se você quiser dar chaves temporárias quando spawnar o veículo
    enable = true,
    onspawn = true, --- Opção ZAP: deixe true para seu player ganhar do nada uma chave do carro quando spawnar o veículo e remover quando ele guardar (ao invés dele ter que ir comprar em um chaveiro uma cópia)
    price = 500
}

-- Icon animation settings
Config.IconAnimation = "fade" --- Animation type for icons

-- Icons for different vehicle types
Config.Icons = {
    [0] = "car-side",       -- Compacts
    [1] = "car",            -- Sedans
    [2] = "car-rear",       -- SUVs
    [3] = "car",            -- Coupes
    [4] = "car-side",       -- Muscle
    [5] = "car",            -- Sports Classics
    [6] = "car",            -- Sports
    [7] = "car",            -- Super
    [8] = "motorcycle",     -- Motorcycles
    [9] = "truck-pickup",   -- Off-road
    [10] = "truck",         -- Industrial
    [11] = "truck",         -- Utility
    [12] = "van-shuttle",   -- Vans
    [13] = "bicycle",       -- Cycles
    [14] = "ship",          -- Boats
    [15] = "helicopter",    -- Helicopters
    [16] = "plane",         -- Planes
    [17] = "bus",           -- Service
    [18] = "ambulance",     -- Emergency
    [19] = "shield-halved", -- Military
    [20] = "truck-front",   -- Commercial
    [21] = "train",         -- Trains
}

-- Prices for impounding different vehicle types
Config.ImpoundPrice = {
    [0] = 15000,  --- Price for compact cars
    [1] = 15000,  --- Price for sedans
    [2] = 15000,  --- Price for SUVs
    [3] = 15000,  --- Price for coupes
    [4] = 15000,  --- Price for muscle cars
    [5] = 15000,  --- Price for sports classics
    [6] = 15000,  --- Price for sports cars
    [7] = 15000,  --- Price for super cars
    [8] = 15000,  --- Price for motorcycles
    [9] = 15000,  --- Price for off-road vehicles
    [10] = 15000, --- Price for industrial vehicles
    [11] = 15000, --- Price for utility vehicles
    [12] = 15000, --- Price for vans
    [13] = 15000, --- Price for cycles
    [14] = 15000, --- Price for boats
    [15] = 15000, --- Price for helicopters
    [16] = 15000, --- Price for planes
    [17] = 15000, --- Price for service vehicles
    [18] = 0,     --- Price for emergency vehicles
    [19] = 15000, --- Price for military vehicles
    [20] = 15000, --- Price for commercial vehicles
    [21] = 0      --- Price for trains (not applicable)
}

-- Police impound settings
Config.PoliceImpound = {
    Target = {
        groups = {
            police = 0  --- Groups allowed to access police impound
        }
    },
    location = {
        [1] = {
            blip = {
                enable = true,       --- Enable or disable the blip on the map
                sprite = 473,        --- Sprite ID for the blip
                colour = 40          --- Colour ID for the blip
            },
            label = "Pátio do Detran",  --- Label for the police impound location
            zones = {
                points = {
                    vec3(824.69000244141, -1334.0200195312, 26.0),  --- Coordinates for the impound zone
                    vec3(831.70001220703, -1337.2700195312, 26.0),
                    vec3(831.73999023438, -1354.0300292969, 26.0),
                    vec3(832.10998535156, -1355.4799804688, 26.0),
                    vec3(824.72998046875, -1352.0400390625, 26.0),
                },
                thickness = 4.0,  --- Thickness of the zone boundaries
            },
        }
    }
}

-- Job vehicle shop settings
Config.JobVehicleShop = {
    {
        job = 'police',  --- Job associated with the vehicle shop
        label = 'Police Vehicle Shop',  --- Label for the vehicle shop
        ped = {
            model = 'csb_trafficwarden',  --- Pedestrian model for the shop
            coords = vec(457.9160, -1026.4635, 28.4376, 57.2678)  --- Coordinates for the shop
        },
        spawn = vec(443.9391, -1021.4270, 28.2857, 92.6928),  --- Coordinates where vehicles spawn
        vehicle = {
            police = {
                price = 500,  --- Price for the police vehicle
                label = 'Police 1',  --- Label for the vehicle
                prefixPlate = 'POL',  --- Prefix for the vehicle plate
                forRank = {
                    [0] = true,  --- Rank 0 can access this vehicle
                    [1] = true,  --- Rank 1 can access this vehicle
                    [2] = true   --- Rank 2 can access this vehicle
                }
            },
            police2 = {
                price = 500,  --- Price for the second police vehicle
                label = 'Police 2',  --- Label for the second vehicle
                prefixPlate = 'POL',  --- Prefix for the vehicle plate
                forRank = {
                    [0] = true,  --- Rank 0 can access this vehicle
                    [1] = true,  --- Rank 1 can access this vehicle
                    [2] = true   --- Rank 2 can access this vehicle
                }
            }
        },
    }
}

--- Do not modify this section
Config.HouseGarages = {}
