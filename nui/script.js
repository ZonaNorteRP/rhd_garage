const app = document.getElementById('app');
const vehicleList = document.getElementById('vehicle-list');
const spawnBtn = document.getElementById('spawn-btn');
const transferBtn = document.getElementById('transfer-btn');
const renameBtn = document.getElementById('rename-btn');
const keysBtn = document.getElementById('keys-btn');

let currentVehicles = [];
let selectedIndex = -1;
let currentGarage = "";

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === "open") {
        currentVehicles = data.vehicles || [];
        currentGarage = data.garage || "GARAGEM";
        document.getElementById('garage-name').innerText = currentGarage.toUpperCase();
        renderVehicleList();
        app.style.display = 'flex';
        selectedIndex = -1;
        updatePreview();
    } else if (data.action === "close") {
        closeUI();
    }
});

function renderVehicleList() {
    vehicleList.innerHTML = '';
    
    if (currentVehicles.length === 0) {
        vehicleList.innerHTML = '<div style="grid-column: 1/-1; color: var(--muted); text-align: center; padding: 20px;">Nenhum veículo encontrado.</div>';
        return;
    }

    currentVehicles.forEach((veh, index) => {
        const card = document.createElement('div');
        card.className = `vehicle-card ${selectedIndex === index ? 'selected' : ''}`;
        card.innerHTML = `
            <div class="card-icon"><i class="fas fa-${veh.icon || 'car'}"></i></div>
            <div class="card-name">${veh.name}</div>
            <div class="card-plate">${veh.plate}</div>
        `;
        
        card.onclick = () => {
            selectedIndex = index;
            renderVehicleList();
            updatePreview();
        };
        
        vehicleList.appendChild(card);
    });
}

function updatePreview() {
    const veh = currentVehicles[selectedIndex];
    const previewName = document.getElementById('preview-name');
    const previewPlate = document.getElementById('preview-plate');
    const previewIcon = document.getElementById('preview-icon');
    
    const fuelVal = document.getElementById('fuel-val');
    const fuelBar = document.getElementById('fuel-bar');
    const engineVal = document.getElementById('engine-val');
    const engineBar = document.getElementById('engine-bar');
    const bodyVal = document.getElementById('body-val');
    const bodyBar = document.getElementById('body-bar');

    if (veh) {
        previewName.innerText = veh.name;
        previewPlate.innerText = veh.plate;
        previewIcon.className = `fas fa-${veh.icon || 'car'}`;
        
        fuelVal.innerText = `${Math.floor(veh.fuel)}%`;
        fuelBar.style.width = `${veh.fuel}%`;
        
        engineVal.innerText = `${Math.floor(veh.engine / 10)}%`;
        engineBar.style.width = `${veh.engine / 10}%`;
        
        bodyVal.innerText = `${Math.floor(veh.body / 10)}%`;
        bodyBar.style.width = `${veh.body / 10}%`;

        spawnBtn.disabled = veh.disabled || false;
        if (veh.chop_fee > 0) {
            spawnBtn.innerHTML = '<i class="fas fa-hammer"></i> TAXA DESMANCHE (R$' + veh.chop_fee + ')';
        } else if (veh.impound) {
            spawnBtn.innerHTML = '<i class="fas fa-hand-holding-dollar"></i> PAGAR PÁTIO';
        } else if (veh.isOut) {
            spawnBtn.innerHTML = '<i class="fas fa-location-dot"></i> LOCALIZAR';
        } else {
            spawnBtn.innerHTML = '<i class="fas fa-sign-out-alt"></i> RETIRAR VEÍCULO';
        }
        
        transferBtn.disabled = false;
        renameBtn.disabled = false;
        keysBtn.disabled = false;
    } else {
        previewName.innerText = "Escolha um Veículo";
        previewPlate.innerText = "SEM PLACA";
        previewIcon.className = "fas fa-car";
        
        fuelVal.innerText = "0%";
        fuelBar.style.width = "0%";
        engineVal.innerText = "0%";
        engineBar.style.width = "0%";
        bodyVal.innerText = "0%";
        bodyBar.style.width = "0%";

        spawnBtn.disabled = true;
        transferBtn.disabled = true;
        renameBtn.disabled = true;
        keysBtn.disabled = true;
    }
}

function closeUI() {
    app.style.display = 'none';
    const resourceName = GetParentResourceName ? GetParentResourceName() : "rhd_garage";
    fetch(`https://${resourceName}/close`, {
        method: 'POST',
        body: JSON.stringify({})
    }).catch(e => {}); 
}

document.getElementById('close-btn').onclick = closeUI;

spawnBtn.onclick = () => {
    if (selectedIndex === -1) return;
    const veh = currentVehicles[selectedIndex];
    post('spawnVehicle', { plate: veh.realPlate || veh.plate, impound: veh.impound });
};

transferBtn.onclick = () => {
    if (selectedIndex === -1) return;
    post('transferVehicle', { plate: currentVehicles[selectedIndex].realPlate || currentVehicles[selectedIndex].plate });
};

renameBtn.onclick = () => {
    if (selectedIndex === -1) return;
    post('renameVehicle', { plate: currentVehicles[selectedIndex].realPlate || currentVehicles[selectedIndex].plate });
};

keysBtn.onclick = () => {
    if (selectedIndex === -1) return;
    post('copyKeys', { plate: currentVehicles[selectedIndex].realPlate || currentVehicles[selectedIndex].plate });
};

function post(endpoint, data) {
    app.style.display = 'none'; // Close UI when action taken
    const resourceName = GetParentResourceName ? GetParentResourceName() : "rhd_garage";
    fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data)
    });
}

document.onkeyup = function (data) {
    if (data.which == 27) { // Escape
        closeUI();
    }
};
