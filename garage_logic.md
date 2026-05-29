# Guia de Lógica: rhd_garage

Este documento explica o funcionamento técnico da garagem para auxiliar na criação de scripts similares.

---

## 💾 1. Veículos no SQL (Persistência)

Os veículos são carregados da tabela `player_vehicles` (base Qbox/QBCore). 

- **Propriedades**: Salvas em uma coluna JSON (geralmente `mods` ou `vehicle`). Contêm cores, upgrades e cosméticos.
- **Estado (`state`)**: 
  - `1`: Na garagem.
  - `0`: Fora da garagem ou apreendido.
- **Localização**: O script armazena o nome da garagem (`garage`) na tabela para saber onde o veículo foi guardado por último.

---

## 🔑 2. Sistema de Chaves

A garagem utiliza integração com `mri_Qcarkeys` (permanente) e `vehiclekeys` (temporária).

- **Ao Spawnar**:
  1. O script verifica se o jogador já possui a chave permanente do veículo.
  2. Se não possuir, ele pode dar o item de chave (`GiveKeyItem`).
  3. Se configurado, ele define o jogador como dono temporário via `vehiclekeys:client:SetOwner`.
- **Ao Guardar**: O script pode remover o item da chave para evitar acúmulo no inventário.

---

## 🚀 3. Fluxo de Spawn de Veículos

Quando o jogador clica em "Retirar" na NUI:

1. **Seleção**: O cliente identifica o modelo e a placa.
2. **Ponto de Spawn**: O script procura um `spawnpoint` livre próximo. Se todos estiverem ocupados, o spawn falha.
3. **Criação da Entidade**: 
   - O veículo é spawnado via `qbx.spawnVehicle` (lado servidor) ou `CreateVehicle` (lado cliente).
   - As propriedades (cores/mods) são aplicadas imediatamente usando `lib.setVehicleProperties`.
4. **Status do Motor/Tanque**: `SetVehicleEngineHealth` e `SetVehicleFuelLevel` são definidos com base nos dados salvos no banco.
5. **Registro de Estado**: O servidor atualiza o `state` para `0` no banco e define a garagem atual.

---

## 🚗 4. Spawn com Chaves (Lógica Combinada)

Para garantir que o veículo spawne pronto para uso:

```lua
-- Exemplo simplificado da lógica interna
local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, true, false)
lib.setVehicleProperties(veh, props)
SetVehicleNumberPlateText(veh, plate)

-- Dar chaves imediatamente
TriggerEvent("vehiclekeys:client:SetOwner", plate)
if Config.GiveKeyItem then
    exports.mri_Qcarkeys:GiveKeyItem(plate)
end
```

---

## 🛠️ 5. Principais Callbacks e Funções

- **`getVehicleList`**: Busca todos os veículos do jogador no banco de dados filtrados pela garagem.
- **`updateState`**: Sincroniza o status do veículo (dentro/fora) entre cliente, servidor e banco.
- **`getvehowner`**: Verifica se quem está tentando guardar o carro é realmente o dono ou tem permissão.
