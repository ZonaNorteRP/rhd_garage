local VehicleShow = nil
local Deformation = require 'modules.deformation'
local ActiveGarageData = nil
local ActiveVehList = {}

local function swapEnabled(from)
    if GarageZone[from] then
        local fromJob = GarageZone[from]['job']
        local fromGang = GarageZone[from]['gang']
        
        if GarageZone[from]['vehicles'] and #GarageZone[from]['vehicles'] > 0 then
            return false
        end
        return not (fromJob or fromGang)
    else
        return false
    end

end

local function canSwapVehicle(to)
    local toJob = GarageZone[to]['job']
    local toGang = GarageZone[to]['gang']
    
    if GarageZone[to]['vehicles'] and #GarageZone[to]['vehicles'] > 0 then
        return false
    end
    
    return not (toJob or toGang)
end

local isSpawning = false

--- Spawn Vehicle
---@param data GarageVehicleData
local function spawnvehicle(data)
    LocalPlayer.state:set('garageBusy', true)
    if isSpawning then
        utils.notify('Aguarde enquanto o veículo está sendo spawnado.', 'error')
        return
    end

    isSpawning = true

    local success, errorMsg = pcall(function()
        local vehData = {
            model = data.model,
            plate = data.plate,
        }
        
        if data.plate then
            local callbackData = lib.callback.await('rhd_garage:cb_server:getvehiclePropByPlate', false, data.plate)
            if not callbackData then
                error('Failed to load vehicle data with number plate ' .. data.plate)
            end
            for key, value in pairs(callbackData) do
                vehData[key] = value
            end
        end

        if Config.InDevelopment then
            print(json.encode(data))
        end
        
        local vehEntity
        utils.createPlyVeh(vehData.model, data.coords, function(veh) vehEntity = veh end, true, vehData.mods)
        
        SetVehicleOnGroundProperly(vehEntity)

        if (not vehData.mods or json.encode(vehData.mods) == "[]") and
            (not data.prop or json.encode(data.prop) == "[]") and
            data.plate then
            SetVehicleNumberPlateText(vehEntity, data.plate)
            TriggerEvent("vehiclekeys:client:SetOwner", data.plate)
        end

        SetVehicleEngineHealth(vehEntity, (vehData.engine or 1000) + 0.0)
        SetVehicleBodyHealth(vehEntity, (vehData.body or 1000) + 0.0)
        utils.setFuel(vehEntity, vehData.fuel or 100)
        
        if vehData.deformation or data.deformation then
            Deformation.set(vehEntity, vehData.deformation or data.deformation)
        end

        while not vehEntity do
            Wait(100)
        end

        Entity(vehEntity).state:set('vehlabel', vehData.vehicle_name or data.vehicle_name)
        
        TriggerServerEvent("rhd_garage:server:updateState", {
            plate = vehData.plate or data.plate,
            state = 0,
            garage = vehData.garage or data.garage
        })

        if Config.SpawnInVehicle then
            TaskWarpPedIntoVehicle(cache.ped, vehEntity, -1)
        end

        if GetResourceState('mri_Qcarkeys') == 'started' and Config.GiveKeys.onspawn then
            local plate = utils.string.trim(vehData.plate or data.plate)
            exports.mri_Qcarkeys:GiveKeyItem(plate)
        end
        
        if Config.GiveKeys.tempkeys then
            TriggerEvent("vehiclekeys:client:SetOwner", utils.string.trim(vehData.plate or data.plate))
        end

        if not data.plate then
            local plate = GetVehicleNumberPlateText(vehEntity)
            TriggerEvent("vehiclekeys:client:SetOwner", plate)
        end

        lib.progressCircle({
            duration = 3000,
            position = 'bottom',
            label = 'Estacionando veículo...',
            useWhileDead = false,
            canCancel = false,
            disable = {
                move = false,
                car = false,
                combat = true,
                sprint = true,
            }
        })

    end)

    isSpawning = false
    LocalPlayer.state:set('garageBusy', false)
    if not success then
        utils.notify('Erro ao spawnar veículo: ' .. (errorMsg or 'desconhecido'), 'error')
    end
end

local function getVehMetadata(data)
    local fuel = data.fuel
    local body = data.body
    local engine = data.engine
    return {
        {label = '⛽ Combustível', value = math.floor(fuel) .. '%', progress = math.floor(fuel), colorScheme = utils.getColorLevel(math.floor(fuel))},
        {label = '🧰 Lataria', value = math.floor(body / 10) .. '%', progress = math.floor(body / 10), colorScheme = utils.getColorLevel(math.floor(body / 10))},
        {label = '🔧 Motor', value = math.floor(engine / 10) .. '%', progress = math.floor(engine / 10), colorScheme = utils.getColorLevel(math.floor(engine / 10))}
    }
end

--- Get available spawn point
---@param points table
---@param ignoreDist boolean?
---@param defaultCoords vector4?
---@return vector4?
local function getAvailableSP(points, ignoreDist, defaultCoords)
    if type(points) ~= "table" and ignoreDist then
        return points
    end
    assert(
        type(points) == "table" and points[1], 'Invalid "points" parameter: Expected a non-empty array table.'
    )
    for k, v in pairs(points) do
        local sp = vec(v.x, v.y, v.z, v.w)
        local vehEntity = lib.getClosestVehicle(sp.xyz, 2.0, true)
        
        if ignoreDist and not vehEntity then
            return sp
        end
        
        local dist = #(defaultCoords.xyz - sp.xyz)
        if dist < 2.0 and not vehEntity then
            return sp
        end
    end
end

--- Open Garage
---@param data GarageVehicleData
local function openMenu(data)
    if LocalPlayer.state.garageBusy then return end
    if not data then return end
    data.type = data.type or "car"
    
    ActiveGarageData = data -- Store for callbacks

    local pool = GetGamePool('CVehicle')
    local vehiclePool = {}
    for i = 1, #pool do
        local v = pool[i]
        if DoesEntityExist(v) then
            vehiclePool[utils.getPlate(v)] = v
        end
    end

    local vehicles = {}
    
    -- Handle service vehicles
    if data.vehicles then
        for i = 1, #data.vehicles do
            local v = data.vehicles[i]
            local vehModel = v
            local vehName = GetLabelText(GetDisplayNameFromVehicleModel(v))
            
            vehicles[#vehicles+1] = {
                name = vehName,
                plate = "SERVIÇO",
                realPlate = "SERVICE_" .. i, -- Temp unique key
                fuel = 100,
                engine = 1000,
                body = 1000,
                icon = 'car',
                disabled = false,
                impound = false,
                originalData = {
                    model = vehModel,
                    garage = data.garage,
                    vehName = vehName,
                    impound = false,
                    shared = data.shared,
                    engine = 1000,
                    fuel = 100,
                    body = 1000,
                }
            }
        end
    end

    -- Handle owned vehicles
    local vehData = lib.callback.await('rhd_garage:cb_server:getVehicleList', false, data.garage, data.impound, data.shared)
    
    if vehData then
        for i = 1, #vehData do
            local vd = vehData[i]
            local vehModel = vd.model
            local plate = utils.string.trim(vd.plate)
            local gState = vd.state
            local fakeplate = vd.fakeplate and utils.string.trim(vd.fakeplate)
            local engine = vd.engine
            local body = vd.body
            local fuel = vd.fuel
            local dp = vd.depotprice
            
            local vehName = vd.vehicle_name or fw.gvn(vehModel)
            local customvehName = CNV[plate] and CNV[plate].name
            local vehlabel = customvehName or vehName
            
            local disabled = false
            local impound = false
            
            local displayPlate = fakeplate or plate
            
            local vehicleClass = GetVehicleClassFromName(vehModel)
            local vehicleType = utils.getCategoryByClass(vehicleClass)
            
            if lib.table.contains(data.type, vehicleType) then
                local icon = Config.Icons[vehicleClass] or 'car'
                local ImpoundPrice = dp > 0 and dp or Config.ImpoundPrice[vehicleClass]
                local isOut = vd.isOut
                
                if gState == 0 and not isOut then
                    impound = true
                end
                
                vehicles[#vehicles+1] = {
                    name = vehlabel,
                    plate = displayPlate,
                    realPlate = plate,
                    fuel = fuel,
                    engine = engine,
                    body = body,
                    icon = icon,
                    model = vehModel,
                    disabled = disabled,
                    impound = impound,
                    isOut = isOut,
                    depotprice = ImpoundPrice,
                    chop_fee = vd.chop_fee or 0,
                    vehicle = vd.vehicle,
                    originalData = {
                        prop = vd.vehicle,
                        engine = engine,
                        fuel = fuel,
                        body = body,
                        model = vehModel,
                        plate = plate,
                        garage = data.garage,
                        vehName = vehlabel,
                        impound = impound,
                        isOut = isOut,
                        shared = data.shared,
                        deformation = vd.deformation,
                        depotprice = ImpoundPrice,
                        icon = icon
                    }
                }
            end
        end
    end

    if #vehicles < 1 then
        utils.notify(locale('garage.no_vehicles'):upper(), 'info')
        return
    end

    ActiveVehList = vehicles
    
    SendNUIMessage({
        action = "open",
        garage = data.garage,
        vehicles = vehicles
    })
    SetNuiFocus(true, true)
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    ActiveGarageData = nil
    ActiveVehList = {}
    cb('ok')
end)

local function getVehFromList(plate)
    for i=1, #ActiveVehList do
        if (ActiveVehList[i].realPlate or ActiveVehList[i].plate) == plate then
            return ActiveVehList[i]
        end
    end
    return nil
end

RegisterNUICallback('spawnVehicle', function(data, cb)
    local veh = getVehFromList(data.plate)
    if not veh then return cb('error') end

    SetNuiFocus(false, false)
    
    local d = veh.originalData
    
    -- Fetch extended data if not present (optimization)
    if not d.prop or not d.deformation then
        local extended = lib.callback.await('rhd_garage:cb_server:getVehicleExtendedData', false, d.plate)
        if extended then
            d.prop = extended.prop
            d.deformation = extended.deformation
        end
    end

    local defaultcoords = vec(GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.5), GetEntityHeading(cache.ped) + 90)
    
    if ActiveGarageData.spawnpoint then
        defaultcoords = getAvailableSP(ActiveGarageData.spawnpoint, ActiveGarageData.ignoreDist, defaultcoords)
    end
    
    if not defaultcoords then
        utils.notify(locale('notify.error.no_parking_spot'), 'error', 8000)
        return cb('ok')
    end
    
    local vehInArea = lib.getClosestVehicle(defaultcoords.xyz)
    if DoesEntityExist(vehInArea) then 
        utils.notify(locale('notify.error.no_parking_spot'), 'error') 
        return cb('ok')
    end

    d.coords = defaultcoords

    if veh.chop_fee > 0 then
        local alert = lib.alertDialog({
            header = 'Veículo Bloqueado',
            content = 'Este veículo foi marcado como desmanchado. Para liberá-lo, você deve pagar uma taxa de liberação de R$' .. veh.chop_fee .. '.',
            centered = true,
            cancel = true,
            labels = { confirm = 'Pagar Taxa', cancel = 'Voltar' }
        })
        
        if alert == "confirm" then
            local success = lib.callback.await('rhd_garage:server:payChopFee', false, veh.realPlate or veh.plate)
            if success then
                utils.notify("Taxa de desmanche paga com sucesso! Veículo liberado.", "success")
                spawnvehicle(d)
            else
                utils.notify("Você não possui dinheiro suficiente para pagar a taxa.", "error")
            end
        end
    elseif veh.impound then
        utils.createMenu({
            id = 'pay_methode',
            title = locale('context.insurance.pay_methode_header'):upper(),
            options = {
                {
                    title = locale('context.insurance.pay_methode_cash_title'):upper(),
                    icon = 'dollar-sign',
                    description = locale('context.insurance.pay_methode_cash_desc'),
                    onSelect = function()
                        local success = lib.callback.await('rhd_garage:server:payImpound', false, veh.realPlate or veh.plate)
                        if success then
                            utils.notify(locale('garage.success_pay_impound'), 'success')
                            spawnvehicle(d)
                        end
                    end
                },
                {
                    title = locale('context.insurance.pay_methode_bank_title'):upper(),
                    icon = 'fab fa-cc-mastercard',
                    description = locale('context.insurance.pay_methode_bank_desc'),
                    onSelect = function()
                        if fw.gm('bank') < veh.depotprice then return utils.notify(locale('notify.error.not_enough_bank'), 'error') end
                        local success = lib.callback.await('rhd_garage:cb_server:removeMoney', false, 'bank', veh.depotprice)
                        if success then
                            utils.notify(locale('garage.success_pay_impound'), 'success')
                            spawnvehicle(d)
                        end
                    end
                }
            }
        })
    elseif veh.isOut then
        vehFunc.tvbp(d.plate, d.garage, true)
        utils.notify(locale('notify.success.locate_vehicle'), 'success')
    else
        spawnvehicle(d)
    end
    
    cb('ok')
end)

RegisterNUICallback('transferVehicle', function(data, cb)
    local veh = getVehFromList(data.plate)
    if not veh or not Config.TransferVehicle.enable then return cb('error') end
    
    SetNuiFocus(false, false)
    
    local transferInput = lib.inputDialog(veh.name, {
        {type = 'number', label = 'Player Id', required = true},
    })
    
    if transferInput then
        local clData = {
            targetSrc = transferInput[1],
            plate = veh.realPlate or veh.plate,
            price = Config.TransferVehicle.price,
            garage = ActiveGarageData.garage
        }
        lib.callback('rhd_garage:cb_server:transferVehicle', false, function(success, information)
            if not success then return utils.notify(information, "error") end
            utils.notify(information, "success")
        end, clData)
    end
    
    cb('ok')
end)

RegisterNUICallback('renameVehicle', function(data, cb)
    local veh = getVehFromList(data.plate)
    if not veh then return cb('error') end
    
    SetNuiFocus(false, false)
    
    local input = lib.inputDialog(veh.name, {
        {type = 'input', label = '', placeholder = locale('input.garage.change_veh_name'), required = true, max = 20},
    })
    
    if input then
        if fw.gm('cash') < Config.changeNamePrice then return utils.notify(locale('notify.error.not_enough_cash'), 'error') end
        
        local success = lib.callback.await('rhd_garage:server:payRename', false, veh.realPlate or veh.plate)
        if success then
            CNV[veh.realPlate or veh.plate] = { name = input[1] }
            TriggerServerEvent('rhd_garage:server:saveCustomVehicleName', CNV)
        end
    end
    
    cb('ok')
end)

RegisterNUICallback('copyKeys', function(data, cb)
    local veh = getVehFromList(data.plate)
    if not veh then return cb('error') end
    
    SetNuiFocus(false, false)
    
    local input = lib.alertDialog({
        header = 'Criar cópia de chave',
        content = 'Você deseja copiar a chave do seu veículo por R$' .. Config.GiveKeys.price .. '?',
        centered = true,
        cancel = true
    }) == "confirm"
    
    if input then
        if fw.gm('cash') < Config.GiveKeys.price then return utils.notify('Você não possui dinheiro suficiente na carteira.', 'error') end
        
        local success = lib.callback.await('rhd_garage:server:payKeys', false, veh.realPlate or veh.plate)
        if success then
            exports.mri_Qcarkeys:GiveKeyItem(veh.realPlate or veh.plate)
        end
    end
    
    cb('ok')
end)


--- Store Vehicle To Garage
---@param data GarageVehicleData
local function storeVeh(data)
    local myCoords = GetEntityCoords(cache.ped)
    local vehicle = cache.vehicle or lib.getClosestVehicle(myCoords)
    
    local vehicleClass = GetVehicleClass(vehicle)
    local vehicleType = utils.getCategoryByClass(vehicleClass)
    
    if not vehicle then return
        utils.notify(locale('notify.error.not_veh_exist'), 'error')
    end
    
    if not lib.table.contains(data.type, vehicleType) then return
        utils.notify(locale('notify.info.invalid_veh_classs', data.garage))
    end

    if data.impound then return
        utils.notify("Você não pode guardar veículos no pátio.", 'error')
    end
    
    local prop = vehFunc.gvp(vehicle)
    local plate = prop and utils.string.trim(prop.plate) or data.plate
    local shared = data.shared
    local deformation = Deformation.get(vehicle)
    local fuel = utils.getFuel(vehicle)
    local engine = GetVehicleEngineHealth(vehicle)
    local body = GetVehicleBodyHealth(vehicle)
    local model = prop.model
    
    local isOwned = lib.callback.await('rhd_garage:cb_server:getvehowner', false, plate, shared, {
        mods = prop,
        deformation = deformation,
        fuel = fuel,
        engine = engine,
        body = body,
        vehicle_name = Entity(vehicle).state.vehlabel
    })
    
    if not isOwned and not data.vehicles then return
        utils.notify(locale('notify.error.not_owned'), 'error')
    end
    if isOwned and data.vehicles then return
        utils.notify(locale('notify.error.is_service_garage'), 'error')
    end

    if cache.vehicle and cache.seat == -1 then
        TaskLeaveAnyVehicle(cache.ped, true, 0)
        Wait(1000)
    end
    if DoesEntityExist(vehicle) then
        if GetResourceState('mri_Qcarkeys') == 'started' and Config.GiveKeys.onspawn then
            exports.mri_Qcarkeys:RemoveKeyItem(plate)
        end
        
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        local veh = NetworkGetEntityFromNetworkId(netId)
        SetNetworkIdCanMigrate(netId, true)
        if veh and DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
        
        if vehicle and DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
        
        TriggerServerEvent('rhd_garage:server:updateState', {plate = plate, state = 1, garage = data.garage})
        utils.notify(locale('notify.success.store_veh'), 'success')
    end
end

--- exports
exports('openMenu', openMenu)
exports('storeVehicle', storeVeh)
