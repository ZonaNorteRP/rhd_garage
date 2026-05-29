if not lib.checkDependency('ox_lib', '3.23.1') then error('This resource requires ox_lib version 3.23.1') end

--- callback
lib.callback.register('rhd_garage:server:payImpound', function(src, plate)
    local vehicle = fw.gpvbp(plate)
    if not vehicle or vehicle.state ~= 0 then return false end
    
    local price = vehicle.depotprice
    if price <= 0 then
        local model = vehicle.model
        local sharedVeh = fw.gsv(model)
        local vehicleClass = sharedVeh and sharedVeh.class or 1 -- Fallback to 1 (Sedans)
        price = Config.ImpoundPrice[vehicleClass] or 15000
    end

    if fw.rm(src, 'cash', price) then
        return true
    end
    if fw.rm(src, 'bank', price) then
        return true
    end
    return false
end)

lib.callback.register('rhd_garage:server:payRename', function(src, plate)
    if fw.rm(src, 'cash', Config.changeNamePrice) then
        return true
    end
    return false
end)

lib.callback.register('rhd_garage:server:payKeys', function(src, plate)
    if fw.rm(src, 'cash', Config.GiveKeys.price) then
        return true
    end
    return false
end)

lib.callback.register('rhd_garage:server:payFine', function(src, amount)
    if fw.rm(src, 'cash', amount) then
        return true
    end
    if fw.rm(src, 'bank', amount) then
        return true
    end
    return false
end)

-- Callback para pagar a taxa de desmanche
lib.callback.register('rhd_garage:server:payChopFee', function(src, plate)
    local identifier = fw.gi(src)
    if not identifier then return false end

    local vehicle = MySQL.single.await("SELECT chop_fee, citizenid FROM player_vehicles WHERE plate = ? OR fakeplate = ?", {plate, plate})
    if not vehicle or vehicle.citizenid ~= identifier or vehicle.chop_fee <= 0 then return false end

    local price = vehicle.chop_fee
    if fw.rm(src, 'cash', price) or fw.rm(src, 'bank', price) then
        MySQL.update.await("UPDATE player_vehicles SET chop_fee = 0 WHERE plate = ? OR fakeplate = ?", {plate, plate})
        return true
    end
    return false
end)

-- Export para desmanche ou outros sistemas bloquearem o veículo
exports('SetVehicleChopFee', function(plate, fee)
    plate = utils.string.trim(plate)
    MySQL.update.await('UPDATE player_vehicles SET chop_fee = ? WHERE plate = ? OR fakeplate = ?', {fee, plate, plate})
    print(('[rhd_garage] Veículo %s bloqueado com taxa de desmanche: %s'):format(plate, fee))
end)

lib.callback.register('rhd_garage:cb_server:getvehowner', function (src, plate, shared, pleaseUpdate)
    return fw.gvobp(src, plate, {
        owner = shared
    }, pleaseUpdate)
end)

lib.callback.register('rhd_garage:cb_server:getvehiclePropByPlate', function (_, plate)
    return fw.gpvbp(plate)
end)

lib.callback.register('rhd_garage:cb_server:getVehicleList', function(src, garage, impound, shared)
    return fw.gpvbg(src, garage, {
        impound = impound,
        shared = shared,
        minimal = true
    })
end)

lib.callback.register('rhd_garage:cb_server:getVehicleExtendedData', function(_, plate)
    return fw.gmdbp(plate)
end)

lib.callback.register("rhd_garage:cb_server:swapGarage", function (source, clientData)
    local identifier = fw.gi(source)
    if not identifier then return false end

    -- Security check: Verify ownership
    local results = MySQL.single.await("SELECT citizenid FROM player_vehicles WHERE plate = ? OR fakeplate = ?", {clientData.plate, clientData.plate})
    if results and results.citizenid == identifier then
        return fw.svg(clientData.newgarage, clientData.plate)
    end
    return false
end)

lib.callback.register("rhd_garage:cb_server:transferVehicle", function (src, clientData)
    if src == clientData.targetSrc then
        return false, locale("notify.error.cannot_transfer_to_myself")
    end

    local tid = clientData.targetSrc

    if not fw.rm(src, "cash", clientData.price) then
        return false, locale("notify.error.need_money", lib.math.groupdigits(clientData.price, '.'))
    end

    print("Transfer vehicle from " .. fw.gn(src) .. " to " .. fw.gn(tid))
    print("Plate: " .. clientData.plate)
    local success = fw.uvo(src, tid, clientData.plate)
    if success then utils.notify(tid, locale("notify.success.transferveh.target", fw.gn(src), clientData.garage), "success") end
    return success, locale("notify.success.transferveh.source", fw.gn(tid))
end)

lib.callback.register('rhd_garage:cb_server:getVehicleInfoByPlate', function (_, plate)
    return fw.gpvbp(plate)
end)

--- Event
RegisterNetEvent("rhd_garage:server:removeTemp", function ( data )
    if GetInvokingResource() then return end
    local player = exports.qbx_core:GetPlayer(source)
    local citizenid = player.PlayerData.citizenid
    if tempVehicle[citizenid] == data.model then
        tempVehicle[citizenid] = nil
    end
end)

lib.addCommand('removeTemp', {
    help = 'Recuperar garagem de player',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID do player', type = 'number' }
    }
}, function(source, args)
    if args.id then
        local player = exports.qbx_core:GetPlayer(tonumber(args.id))
        local citizenid = player.PlayerData.citizenid
        tempVehicle[citizenid] = nil
        lib.notify(tonumber(args.id), {description = "Seus veículos de aluguel foram recuperados.", type = "success", duration = 10000})
        lib.notify(source, {description = "Garagem recuperada do id: " .. args.id .. " cidadão: " .. citizenid .. " de nome " .. player.PlayerData.name .. ".", type = "success", duration = 10000})
    else
        lib.notify(source, {description = "ID inválido.", type = "error", duration = 10000})
    end
end)

RegisterNetEvent("rhd_garage:server:updateState", function ( data )
    local src = source
    if GetInvokingResource() then return end
    if not data or not data.plate then return end

    local identifier = fw.gi(src)
    if not identifier then return end

    -- Security check: Verify ownership before updating state
    local results = MySQL.single.await("SELECT citizenid FROM player_vehicles WHERE plate = ? OR fakeplate = ?", {data.plate, data.plate})
    if results and results.citizenid == identifier then
        fw.uvs(data.plate, data.state, data.garage)
    else
        -- If it's a service vehicle (no owner in DB), we might allow it or handle differently
        -- For now, if no owner found, we check if it was a service vehicle (this logic depends on how service vehs are handled)
        if not results then
            -- Allow update for vehicles not in player_vehicles (possibly service vehicles)
            fw.uvs(data.plate, data.state, data.garage)
        else
            lib.print.warn(("[rhd_garage] Player %s attempted to update state of vehicle %s they don't own!"):format(src, data.plate))
        end
    end
end)

RegisterNetEvent("rhd_garage:server:saveGarageZone", function(fileData)
    local src = source
    if GetInvokingResource() then return end
    
    -- Admin check for saving zones
    if not fw.gp(src) or not (QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')) then
        return lib.print.warn(("[rhd_garage] Non-admin player %s tried to save garage zones!"):format(src))
    end

    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return storage.SaveGarage(fileData)
end)

RegisterNetEvent("rhd_garage:server:saveCustomVehicleName", function (fileData)
    local src = source
    if GetInvokingResource() then return end
    
    -- Ideally we should verify every name change in fileData, but since it's a global table, 
    -- we at least check if the player is sending a valid structure.
    -- For better security, name changes should be per-vehicle.
    
    if type(fileData) ~= "table" or type(fileData) == "nil" then return end
    return storage.SaveVehicleName(fileData)
end)

local vehicleSpawnCooldown = {}

lib.callback.register('rhd_garage:server:spawnVehicle', function(source, model, coords, props)
    local playerId = source
    local plate = props and props.plate

    -- Security Check: Verify ownership if a plate is provided
    if plate then
        local identifier = fw.gi(playerId)
        local results = MySQL.single.await("SELECT citizenid FROM player_vehicles WHERE plate = ? OR fakeplate = ?", {plate, plate})
        if results and results.citizenid ~= identifier then
            lib.print.warn(("[rhd_garage] Player %s attempted to spawn vehicle %s they don't own!"):format(playerId, plate))
            return false
        end
    end

    if vehicleSpawnCooldown[playerId] then
        return false
    end

    vehicleSpawnCooldown[playerId] = true

    local netid, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = coords,
        warp = false,
        props = props
    })

    SetTimeout(3000, function()
        vehicleSpawnCooldown[playerId] = nil
    end)

    return netid
end)

--- exports
exports("Garage", function ()
    return GarageZone
end)
