import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const GameState = {
  player: { x: 0, z: 5, vx: 0, vz: 0, speed: 0.15, heldItems: [], maxCapacity: 10, cash: 500, mixer: null, currentAction: 'idle', group: null },
  store: { x: 0, z: 0, width: 14, length: 14 },
  shelves: {
    mobile: { x: 4, z: -2, type: 'MOBILE', stock: 0, maxStock: 15, unlocked: true, model: null },
    laptop: { x: -4, z: -2, type: 'LAPTOP', stock: 0, maxStock: 10, unlocked: true, model: null },
    tv: { x: 0, z: -5, type: 'TV', stock: 0, maxStock: 5, unlocked: true, model: null }
  },
  counters: { supplyBench: { x: -6, z: -6 }, register: { x: 0, z: 3 } },
  traffic: [],
  pedestrians: [],
  customers: [],
  activeCustomer: null,
  isHaggling: false,
  hagglePrice: 0,
  haggleItem: null,
  haggleCustomer: null,
  keys: {},
  mixers: [],
  clock: null
};

const ASSETS = {
  CITY: './assets/city/city.gltf',
  PLAYER: './assets/players/player.gltf',
  CAR: './assets/vehicles/car.gltf',
  PHONE: './assets/devices/phone.gltf',
  LAPTOP: './assets/devices/laptop.gltf',
  TV: './assets/devices/tv.gltf'
};

const PRICES = { MOBILE: 99, LAPTOP: 599, TV: 899 };

let scene, camera, renderer, clock;
const loader = new GLTFLoader();

const keys = {};
document.addEventListener('keydown', (e) => { keys[e.code] = true; });
document.addEventListener('keyup', (e) => { keys[e.code] = false; });

function init() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x87CEEB);
  scene.fog = new THREE.Fog(0x87CEEB, 50, 150);

  camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 500);
  camera.position.set(GameState.player.x + 12, 15, GameState.player.z + 12);
  camera.lookAt(GameState.player.x, 0, GameState.player.z);

  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(window.devicePixelRatio);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.2;
  document.body.appendChild(renderer.domElement);

  clock = new THREE.Clock();
  GameState.clock = clock;

  const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
  scene.add(ambientLight);

  const dirLight = new THREE.DirectionalLight(0xffffff, 1.0);
  dirLight.position.set(30, 40, 20);
  dirLight.castShadow = true;
  dirLight.shadow.mapSize.width = 2048;
  dirLight.shadow.mapSize.height = 2048;
  dirLight.shadow.camera.near = 0.5;
  dirLight.shadow.camera.far = 200;
  dirLight.shadow.camera.left = -60;
  dirLight.shadow.camera.right = 60;
  dirLight.shadow.camera.top = 60;
  dirLight.shadow.camera.bottom = -60;
  scene.add(dirLight);

  const hemiLight = new THREE.HemisphereLight(0x87CEEB, 0x556B2F, 0.4);
  scene.add(hemiLight);

  createHUD();
  loadAllAssets();

  window.addEventListener('resize', onWindowResize);
  renderer.setAnimationLoop(animate);
}

function onWindowResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}

function createHUD() {
  const hud = document.createElement('div');
  hud.id = 'game-hud';
  hud.style.cssText = `
    position: fixed; top: 16px; left: 16px; z-index: 1000;
    font-family: 'Courier New', monospace; color: #e0e0e0;
    background: rgba(10, 10, 30, 0.85); padding: 16px 20px;
    border-radius: 8px; border: 1px solid rgba(100, 200, 255, 0.3);
    backdrop-filter: blur(8px); min-width: 220px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.5);
  `;
  hud.innerHTML = `
    <div style="font-size:14px;font-weight:bold;color:#64c8ff;margin-bottom:8px;border-bottom:1px solid rgba(100,200,255,0.2);padding-bottom:6px;">TECH STORE TYCOON</div>
    <div id="hud-cash" style="font-size:13px;margin-bottom:4px;">Cash: $500</div>
    <div id="hud-inventory" style="font-size:13px;margin-bottom:4px;">Backpack: 0 / 10</div>
    <div id="hud-stock" style="font-size:11px;color:#aaa;margin-top:8px;border-top:1px solid rgba(100,200,255,0.15);padding-top:6px;">
      <div>Mobile Shelf: 0 / 15</div>
      <div>Laptop Shelf: 0 / 10</div>
      <div>TV Shelf: 0 / 5</div>
    </div>
    <div id="hud-controls" style="font-size:10px;color:#777;margin-top:10px;border-top:1px solid rgba(100,200,255,0.1);padding-top:6px;">
      WASD/Arrows: Move<br>
      [E] Pickup at Supply<br>
      [F] Stock Shelf<br>
      [Y] Accept Offer<br>
      [N] Reject Offer
    </div>
  `;
  document.body.appendChild(hud);

  const haggleOverlay = document.createElement('div');
  haggleOverlay.id = 'haggle-overlay';
  haggleOverlay.style.cssText = `
    display: none; position: fixed; top: 50%; left: 50%;
    transform: translate(-50%, -50%); z-index: 2000;
    font-family: 'Courier New', monospace; color: #fff;
    background: rgba(10, 10, 40, 0.95); padding: 30px 40px;
    border-radius: 12px; border: 2px solid #64c8ff;
    text-align: center; box-shadow: 0 0 40px rgba(100,200,255,0.3);
    min-width: 320px;
  `;
  haggleOverlay.innerHTML = `
    <div style="font-size:18px;font-weight:bold;color:#64c8ff;margin-bottom:16px;">NEGOTIATION</div>
    <div id="haggle-text" style="font-size:15px;margin-bottom:20px;">Customer offers $0!</div>
    <div style="font-size:13px;">
      <span style="color:#4caf50;margin-right:20px;">[Y] Accept</span>
      <span style="color:#f44336;">[N] Reject</span>
    </div>
  `;
  document.body.appendChild(haggleOverlay);
}

function updateHUD() {
  const cashEl = document.getElementById('hud-cash');
  const invEl = document.getElementById('hud-inventory');
  const stockEl = document.getElementById('hud-stock');
  if (cashEl) cashEl.textContent = `Cash: $${GameState.player.cash}`;
  if (invEl) invEl.textContent = `Backpack: ${GameState.player.heldItems.length} / ${GameState.player.maxCapacity}`;
  if (stockEl) {
    stockEl.innerHTML = `
      <div>Mobile Shelf: ${GameState.shelves.mobile.stock} / ${GameState.shelves.mobile.maxStock}</div>
      <div>Laptop Shelf: ${GameState.shelves.laptop.stock} / ${GameState.shelves.laptop.maxStock}</div>
      <div>TV Shelf: ${GameState.shelves.tv.stock} / ${GameState.shelves.tv.maxStock}</div>
    `;
  }
}

function loadAllAssets() {
  const promises = [];

  promises.push(loadGLTF(ASSETS.CITY).then((gltf) => {
    const city = gltf.scene;
    city.traverse((child) => {
      if (child.isMesh) {
        child.castShadow = true;
        child.receiveShadow = true;
      }
    });
    scene.add(city);
  }).catch(() => {
    console.warn('City asset not found, generating procedural city');
    generateProceduralCity();
  }));

  promises.push(loadGLTF(ASSETS.PLAYER).then((gltf) => {
    const playerGroup = gltf.scene;
    playerGroup.position.set(GameState.player.x, 0, GameState.player.z);
    playerGroup.traverse((child) => {
      if (child.isMesh) {
        child.castShadow = true;
        child.receiveShadow = true;
      }
    });
    scene.add(playerGroup);
    GameState.player.group = playerGroup;

    if (gltf.animations && gltf.animations.length > 0) {
      const mixer = new THREE.AnimationMixer(playerGroup);
      GameState.player.mixer = mixer;
      GameState.mixers.push(mixer);

      const clips = {};
      gltf.animations.forEach((clip) => {
        clips[clip.name] = mixer.clipAction(clip);
      });

      if (clips['idle']) {
        clips['idle'].play();
        GameState.player.clips = clips;
        GameState.player.currentAction = 'idle';
      } else if (gltf.animations[0]) {
        const fallback = mixer.clipAction(gltf.animations[0]);
        fallback.play();
        GameState.player.clips = { idle: fallback };
        GameState.player.currentAction = 'idle';
      }
    }
  }).catch(() => {
    console.warn('Player asset not found, generating placeholder');
    generatePlaceholderPlayer();
  }));

  promises.push(loadGLTF(ASSETS.CAR).then((gltf) => {
    GameState.carTemplate = gltf;
  }).catch(() => {
    console.warn('Car asset not found');
  }));

  promises.push(loadGLTF(ASSETS.PHONE).then((gltf) => {
    GameState.phoneTemplate = gltf;
  }).catch(() => {
    console.warn('Phone asset not found');
  }));

  promises.push(loadGLTF(ASSETS.LAPTOP).then((gltf) => {
    GameState.laptopTemplate = gltf;
  }).catch(() => {
    console.warn('Laptop asset not found');
  }));

  promises.push(loadGLTF(ASSETS.TV).then((gltf) => {
    GameState.tvTemplate = gltf;
  }).catch(() => {
    console.warn('TV asset not found');
  }));

  Promise.all(promises).then(() => {
    spawnTraffic();
    spawnPedestrians();
    generateStoreInterior();
    updateHUD();
  });
}

function loadGLTF(url) {
  return new Promise((resolve, reject) => {
    loader.load(url, resolve, undefined, reject);
  });
}

function cloneGltf(template) {
  if (!template) return null;
  const clone = template.scene.clone(true);
  clone.traverse((child) => {
    if (child.isMesh) {
      child.castShadow = true;
      child.receiveShadow = true;
    }
  });
  return clone;
}

function generateProceduralCity() {
  const groundGeo = new THREE.PlaneGeometry(200, 200);
  const groundMat = new THREE.MeshStandardMaterial({ color: 0x3a7d44 });
  const ground = new THREE.Mesh(groundGeo, groundMat);
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -0.05;
  ground.receiveShadow = true;
  scene.add(ground);

  const roadMat = new THREE.MeshStandardMaterial({ color: 0x333333 });
  const sidewalkMat = new THREE.MeshStandardMaterial({ color: 0x999999 });

  const roads = [
    { x: 0, z: 12, w: 80, h: 8 },
    { x: 0, z: -12, w: 80, h: 8 },
    { x: 25, z: 0, w: 8, h: 40 },
    { x: -25, z: 0, w: 8, h: 40 },
  ];

  roads.forEach((r) => {
    const roadGeo = new THREE.BoxGeometry(r.w, 0.05, r.h);
    const road = new THREE.Mesh(roadGeo, roadMat);
    road.position.set(r.x, 0, r.z);
    road.receiveShadow = true;
    scene.add(road);

    const sidewalkGeo = new THREE.BoxGeometry(r.w + 4, 0.15, r.h + 4);
    const sidewalk = new THREE.Mesh(sidewalkGeo, sidewalkMat);
    sidewalk.position.set(r.x, 0.05, r.z);
    sidewalk.receiveShadow = true;
    scene.add(sidewalk);
  });

  const buildingColors = [0x8B4513, 0xA0522D, 0x696969, 0x708090, 0x2F4F4F, 0x4A4A8A, 0x8A4A4A];
  const buildingPositions = [
    { x: 20, z: 25 }, { x: -20, z: 25 }, { x: 35, z: 25 },
    { x: -35, z: 25 }, { x: 20, z: -25 }, { x: -20, z: -25 },
    { x: 35, z: -25 }, { x: -35, z: -25 }, { x: 20, z: 0 },
    { x: -20, z: 0 }, { x: 35, z: 0 }, { x: -35, z: 0 },
    { x: 45, z: 25 }, { x: -45, z: 25 }, { x: 45, z: -25 },
    { x: -45, z: -25 }
  ];

  buildingPositions.forEach((pos, i) => {
    const w = 6 + Math.random() * 8;
    const h = 8 + Math.random() * 20;
    const d = 6 + Math.random() * 8;
    const color = buildingColors[i % buildingColors.length];

    const bldgGeo = new THREE.BoxGeometry(w, h, d);
    const bldgMat = new THREE.MeshStandardMaterial({ color });
    const bldg = new THREE.Mesh(bldgGeo, bldgMat);
    bldg.position.set(pos.x, h / 2, pos.z);
    bldg.castShadow = true;
    bldg.receiveShadow = true;
    scene.add(bldg);

    for (let wy = 2; wy < h - 1; wy += 3) {
      for (let wx = -w / 3; wx <= w / 3; wx += w / 3) {
        const winGeo = new THREE.PlaneGeometry(1.2, 1.5);
        const winMat = new THREE.MeshStandardMaterial({
          color: Math.random() > 0.3 ? 0xFFEE88 : 0x334455,
          emissive: Math.random() > 0.3 ? 0xFFEE88 : 0x000000,
          emissiveIntensity: 0.3
        });
        const win = new THREE.Mesh(winGeo, winMat);
        win.position.set(pos.x + wx, wy, pos.z + d / 2 + 0.01);
        scene.add(win);
      }
    }
  });

  const storeGeo = new THREE.BoxGeometry(GameState.store.width, 6, GameState.store.length);
  const storeMat = new THREE.MeshStandardMaterial({ color: 0x2C3E50 });
  const store = new THREE.Mesh(storeGeo, storeMat);
  store.position.set(GameState.store.x, 3, GameState.store.z);
  store.castShadow = true;
  store.receiveShadow = true;
  scene.add(store);

  const signGeo = new THREE.BoxGeometry(8, 1.5, 0.3);
  const signMat = new THREE.MeshStandardMaterial({ color: 0x1a1a2e, emissive: 0x4488ff, emissiveIntensity: 0.5 });
  const sign = new THREE.Mesh(signGeo, signMat);
  sign.position.set(0, 6.5, GameState.store.length / 2 + 0.2);
  scene.add(sign);
}

function generatePlaceholderPlayer() {
  const group = new THREE.Group();
  const bodyGeo = new THREE.CapsuleGeometry(0.3, 1.0, 4, 8);
  const bodyMat = new THREE.MeshStandardMaterial({ color: 0x2196F3 });
  const body = new THREE.Mesh(bodyGeo, bodyMat);
  body.position.y = 1.0;
  body.castShadow = true;
  group.add(body);

  const headGeo = new THREE.SphereGeometry(0.25, 8, 8);
  const headMat = new THREE.MeshStandardMaterial({ color: 0xFFDBB5 });
  const head = new THREE.Mesh(headGeo, headMat);
  head.position.y = 1.85;
  head.castShadow = true;
  group.add(head);

  const backGeo = new THREE.BoxGeometry(0.5, 0.6, 0.3);
  const backMat = new THREE.MeshStandardMaterial({ color: 0x333333 });
  const back = new THREE.Mesh(backGeo, backMat);
  back.position.set(0, 1.2, -0.35);
  back.castShadow = true;
  group.add(back);

  group.position.set(GameState.player.x, 0, GameState.player.z);
  scene.add(group);
  GameState.player.group = group;

  const mixer = new THREE.AnimationMixer(group);
  GameState.player.mixer = mixer;
  GameState.mixers.push(mixer);

  const idleClip = new THREE.AnimationClip('idle', 1, [
    new THREE.VectorKeyframeTrack('.position', [0, 0.5, 1], [0, 1.0, 0, 0, 1.05, 0, 0, 1.0, 0])
  ]);
  const idleAction = mixer.clipAction(idleClip);
  idleAction.play();
  GameState.player.clips = { idle: idleAction };
  GameState.player.currentAction = 'idle';
}

function generateStoreInterior() {
  const shelfGeo = new THREE.BoxGeometry(3, 2, 0.8);
  const shelfMat = new THREE.MeshStandardMaterial({ color: 0x5D4E37 });

  Object.entries(GameState.shelves).forEach(([key, shelf]) => {
    const mesh = new THREE.Mesh(shelfGeo, shelfMat);
    mesh.position.set(shelf.x, 1, shelf.z);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    scene.add(mesh);
    shelf.model = mesh;

    const labelGeo = new THREE.PlaneGeometry(2, 0.5);
    const canvas = document.createElement('canvas');
    canvas.width = 256;
    canvas.height = 64;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, 256, 64);
    ctx.fillStyle = '#64c8ff';
    ctx.font = 'bold 28px Courier New';
    ctx.textAlign = 'center';
    ctx.fillText(key.toUpperCase(), 128, 42);
    const labelTexture = new THREE.CanvasTexture(canvas);
    const labelMat = new THREE.MeshStandardMaterial({ map: labelTexture, emissive: 0x222244, emissiveIntensity: 0.3 });
    const label = new THREE.Mesh(labelGeo, labelMat);
    label.position.set(shelf.x, 2.3, shelf.z + 0.5);
    scene.add(label);
  });

  const counterGeo = new THREE.BoxGeometry(4, 1.2, 1.5);
  const counterMat = new THREE.MeshStandardMaterial({ color: 0x4A3728 });

  const supplyCounter = new THREE.Mesh(counterGeo, counterMat);
  supplyCounter.position.set(GameState.counters.supplyBench.x, 0.6, GameState.counters.supplyBench.z);
  supplyCounter.castShadow = true;
  supplyCounter.receiveShadow = true;
  scene.add(supplyCounter);

  const registerCounter = new THREE.Mesh(counterGeo, counterMat);
  registerCounter.position.set(GameState.counters.register.x, 0.6, GameState.counters.register.z);
  registerCounter.castShadow = true;
  registerCounter.receiveShadow = true;
  scene.add(registerCounter);

  const registerGeo = new THREE.BoxGeometry(0.6, 0.4, 0.5);
  const registerMat = new THREE.MeshStandardMaterial({ color: 0x222222, emissive: 0x00ff00, emissiveIntensity: 0.1 });
  const registerMesh = new THREE.Mesh(registerGeo, registerMat);
  registerMesh.position.set(GameState.counters.register.x, 1.4, GameState.counters.register.z);
  registerMesh.castShadow = true;
  scene.add(registerMesh);

  const floorGeo = new THREE.PlaneGeometry(GameState.store.width, GameState.store.length);
  const floorMat = new THREE.MeshStandardMaterial({ color: 0x8B7D6B });
  const floor = new THREE.Mesh(floorGeo, floorMat);
  floor.rotation.x = -Math.PI / 2;
  floor.position.y = 0.01;
  floor.receiveShadow = true;
  scene.add(floor);

  spawnTraffic();
  spawnPedestrians();
}

function spawnTraffic() {
  const carModels = ['sedan', 'suv', 'taxi', 'van'];
  const trafficRoutes = [
    { start: { x: -40, z: 12 }, end: { x: 40, z: 12 }, axis: 'x', speed: 0.08 },
    { start: { x: 40, z: 12 }, end: { x: -40, z: 12 }, axis: 'x', speed: 0.07 },
    { start: { x: 25, z: 30 }, end: { x: 25, z: -30 }, axis: 'z', speed: 0.06 },
    { start: { x: -25, z: -30 }, end: { x: -25, z: 30 }, axis: 'z', speed: 0.09 },
  ];

  for (let i = 0; i < 4; i++) {
    const route = trafficRoutes[i];
    let carGroup;

    if (GameState.carTemplate) {
      carGroup = cloneGltf(GameState.carTemplate);
    } else {
      carGroup = createPlaceholderCar(carModels[i]);
    }

    carGroup.position.set(route.start.x, 0, route.start.z);

    if (route.axis === 'z') {
      carGroup.rotation.y = Math.PI / 2;
    }

    scene.add(carGroup);

    GameState.traffic.push({
      mesh: carGroup,
      route: route,
      progress: Math.random(),
      speed: route.speed + (Math.random() * 0.02 - 0.01),
      stopped: false,
    });
  }
}

function createPlaceholderCar(type) {
  const group = new THREE.Group();
  const colors = { sedan: 0x2196F3, suv: 0x4CAF50, taxi: 0xFFEB3B, van: 0xFF9800 };
  const color = colors[type] || 0x999999;

  const bodyGeo = new THREE.BoxGeometry(2, 0.8, 4);
  const bodyMat = new THREE.MeshStandardMaterial({ color });
  const body = new THREE.Mesh(bodyGeo, bodyMat);
  body.position.y = 0.6;
  body.castShadow = true;
  group.add(body);

  const cabinGeo = new THREE.BoxGeometry(1.6, 0.7, 2);
  const cabinMat = new THREE.MeshStandardMaterial({ color: 0x333333 });
  const cabin = new THREE.Mesh(cabinGeo, cabinMat);
  cabin.position.y = 1.35;
  cabin.position.z = -0.3;
  cabin.castShadow = true;
  group.add(cabin);

  const wheelGeo = new THREE.CylinderGeometry(0.25, 0.25, 0.2, 8);
  const wheelMat = new THREE.MeshStandardMaterial({ color: 0x111111 });
  const wheelPositions = [
    { x: -0.9, y: 0.25, z: 1.2 },
    { x: 0.9, y: 0.25, z: 1.2 },
    { x: -0.9, y: 0.25, z: -1.2 },
    { x: 0.9, y: 0.25, z: -1.2 }
  ];
  wheelPositions.forEach((wp) => {
    const wheel = new THREE.Mesh(wheelGeo, wheelMat);
    wheel.position.set(wp.x, wp.y, wp.z);
    wheel.rotation.z = Math.PI / 2;
    group.add(wheel);
  });

  return group;
}

function spawnPedestrians() {
  const pedestrianWaypoints = [
    { x: -20, z: 8 }, { x: -10, z: 8 }, { x: 10, z: 8 }, { x: 20, z: 8 },
    { x: 20, z: -8 }, { x: 10, z: -8 }, { x: -10, z: -8 }, { x: -20, z: -8 },
    { x: -20, z: 18 }, { x: 20, z: 18 }, { x: -20, z: -18 }, { x: 20, z: -18 },
  ];

  for (let i = 0; i < 5; i++) {
    const group = createPlaceholderPedestrian();
    const startIdx = Math.floor(Math.random() * pedestrianWaypoints.length);
    const startWP = pedestrianWaypoints[startIdx];
    group.position.set(startWP.x + Math.random() * 4, 0, startWP.z + Math.random() * 4);
    scene.add(group);

    const endIdx = (startIdx + 2 + Math.floor(Math.random() * 3)) % pedestrianWaypoints.length;

    const mixer = new THREE.AnimationMixer(group);
    GameState.mixers.push(mixer);

    GameState.pedestrians.push({
      mesh: group,
      waypoints: pedestrianWaypoints,
      currentTarget: endIdx,
      startX: startWP.x,
      startZ: startWP.z,
      speed: 0.02 + Math.random() * 0.02,
      mixer: mixer,
    });
  }
}

function createPlaceholderPedestrian() {
  const group = new THREE.Group();
  const shirtColors = [0xE91E63, 0x9C27B0, 0x3F51B5, 0x009688, 0xFF5722, 0x795548];
  const color = shirtColors[Math.floor(Math.random() * shirtColors.length)];

  const bodyGeo = new THREE.CapsuleGeometry(0.25, 0.8, 4, 8);
  const bodyMat = new THREE.MeshStandardMaterial({ color });
  const body = new THREE.Mesh(bodyGeo, bodyMat);
  body.position.y = 0.9;
  body.castShadow = true;
  group.add(body);

  const headGeo = new THREE.SphereGeometry(0.2, 8, 8);
  const headMat = new THREE.MeshStandardMaterial({ color: 0xFFDBB5 });
  const head = new THREE.Mesh(headGeo, headMat);
  head.position.y = 1.6;
  head.castShadow = true;
  group.add(head);

  return group;
}

function createPlaceholderCustomer() {
  const group = new THREE.Group();
  const shirtColors = [0xD32F2F, 0x1976D2, 0x388E3C, 0xF57C00, 0x7B1FA2, 0x00796B];
  const color = shirtColors[Math.floor(Math.random() * shirtColors.length)];

  const bodyGeo = new THREE.CapsuleGeometry(0.25, 0.8, 4, 8);
  const bodyMat = new THREE.MeshStandardMaterial({ color });
  const body = new THREE.Mesh(bodyGeo, bodyMat);
  body.position.y = 0.9;
  body.castShadow = true;
  group.add(body);

  const headGeo = new THREE.SphereGeometry(0.2, 8, 8);
  const headMat = new THREE.MeshStandardMaterial({ color: 0xFFDBB5 });
  const head = new THREE.Mesh(headGeo, headMat);
  head.position.y = 1.6;
  head.castShadow = true;
  group.add(head);

  return group;
}

function cloneProductMesh(type) {
  let template = null;
  if (type === 'MOBILE') template = GameState.phoneTemplate;
  else if (type === 'LAPTOP') template = GameState.laptopTemplate;
  else if (type === 'TV') template = GameState.tvTemplate;

  if (template) {
    return cloneGltf(template);
  }

  return createPlaceholderProduct(type);
}

function createPlaceholderProduct(type) {
  const group = new THREE.Group();
  let geo, mat, scale;

  if (type === 'MOBILE') {
    geo = new THREE.BoxGeometry(0.15, 0.3, 0.02);
    mat = new THREE.MeshStandardMaterial({ color: 0x111111, emissive: 0x222244, emissiveIntensity: 0.2 });
    scale = 0.4;
  } else if (type === 'LAPTOP') {
    geo = new THREE.BoxGeometry(0.5, 0.35, 0.03);
    mat = new THREE.MeshStandardMaterial({ color: 0xCCCCCC });
    scale = 0.6;
    const mesh = new THREE.Mesh(geo, mat);
    mesh.castShadow = true;
    group.add(mesh);

    const screenGeo = new THREE.PlaneGeometry(0.42, 0.26);
    const screenMat = new THREE.MeshStandardMaterial({ color: 0x333333, emissive: 0x4488ff, emissiveIntensity: 0.3 });
    const screen = new THREE.Mesh(screenGeo, screenMat);
    screen.position.set(0, 0.18, 0.02);
    screen.rotation.x = -0.2;
    group.add(screen);
    return group;
  } else if (type === 'TV') {
    geo = new THREE.BoxGeometry(0.8, 0.5, 0.04);
    mat = new THREE.MeshStandardMaterial({ color: 0x111111 });
    scale = 0.7;
  }

  const mesh = new THREE.Mesh(geo, mat);
  mesh.castShadow = true;
  group.add(mesh);

  if (type === 'TV') {
    const screenGeo = new THREE.PlaneGeometry(0.72, 0.42);
    const screenMat = new THREE.MeshStandardMaterial({ color: 0x222222, emissive: 0x224488, emissiveIntensity: 0.4 });
    const screen = new THREE.Mesh(screenGeo, screenMat);
    screen.position.z = 0.025;
    group.add(screen);
  }

  if (scale) group.scale.setScalar(scale);
  return group;
}

function playerSwitchAnimation(targetAction) {
  const player = GameState.player;
  if (!player.mixer || !player.clips) return;
  if (player.currentAction === targetAction) return;

  const currentClip = player.clips[player.currentAction];
  const targetClip = player.clips[targetAction];

  if (targetClip) {
    if (currentClip) {
      currentClip.fadeOut(0.2);
    }
    targetClip.reset().fadeIn(0.2).play();
    player.currentAction = targetAction;
  }
}

function updatePlayer(delta) {
  let moveX = 0;
  let moveZ = 0;

  if (keys['KeyW'] || keys['ArrowUp']) moveZ = -1;
  if (keys['KeyS'] || keys['ArrowDown']) moveZ = 1;
  if (keys['KeyA'] || keys['ArrowLeft']) moveX = -1;
  if (keys['KeyD'] || keys['ArrowRight']) moveX = 1;

  const len = Math.sqrt(moveX * moveX + moveZ * moveZ);
  if (len > 0) {
    moveX /= len;
    moveZ /= len;
  }

  GameState.player.vx = moveX * GameState.player.speed;
  GameState.player.vz = moveZ * GameState.player.speed;

  const newX = GameState.player.x + GameState.player.vx;
  const newZ = GameState.player.z + GameState.player.vz;

  const cityMin = -50;
  const cityMax = 50;
  GameState.player.x = Math.max(cityMin, Math.min(cityMax, newX));
  GameState.player.z = Math.max(cityMin, Math.min(cityMax, newZ));

  if (GameState.player.group) {
    GameState.player.group.position.x = GameState.player.x;
    GameState.player.group.position.z = GameState.player.z;

    if (len > 0) {
      const angle = Math.atan2(moveX, moveZ);
      GameState.player.group.rotation.y = angle;
    }
  }

  if (len > 0) {
    playerSwitchAnimation('walk');
  } else {
    playerSwitchAnimation('idle');
  }

  if (keys['KeyE']) {
    keys['KeyE'] = false;
    pickupFromSupplyBench();
  }

  if (keys['KeyF']) {
    keys['KeyF'] = false;
    stockShelf();
  }

  updateHaggleInput();
}

function pickupFromSupplyBench() {
  const player = GameState.player;
  const bench = GameState.counters.supplyBench;
  const dx = player.x - bench.x;
  const dz = player.z - bench.z;
  const dist = Math.sqrt(dx * dx + dz * dz);

  if (dist > 3) return;
  if (player.heldItems.length >= player.maxCapacity) return;

  const types = ['MOBILE', 'LAPTOP', 'TV'];
  const type = types[Math.floor(Math.random() * types.length)];

  const product = cloneProductMesh(type);
  if (!product) return;

  const slotIndex = player.heldItems.length;
  product.position.set(0, 1.2 + slotIndex * 0.35, -0.35);
  product.scale.setScalar(0.5);

  if (player.group) {
    player.group.add(product);
  }

  player.heldItems.push({ type, mesh: product });
  updateHUD();
}

function stockShelf() {
  const player = GameState.player;
  if (player.heldItems.length === 0) return;

  const shelfEntries = Object.entries(GameState.shelves);
  for (const [key, shelf] of shelfEntries) {
    const dx = player.x - shelf.x;
    const dz = player.z - shelf.z;
    const dist = Math.sqrt(dx * dx + dz * dz);

    if (dist > 3) continue;
    if (shelf.stock >= shelf.maxStock) continue;

    const itemIndex = player.heldItems.findIndex((item) => item.type === shelf.type);
    if (itemIndex === -1) continue;

    const item = player.heldItems[itemIndex];
    if (item.mesh && item.mesh.parent) {
      item.mesh.parent.remove(item.mesh);
    }

    const shelfSlot = shelf.stock;
    const offsetX = (shelfSlot % 5) * 0.5 - 1.0;
    const offsetY = Math.floor(shelfSlot / 5) * 0.3;

    const displayProduct = cloneProductMesh(shelf.type);
    if (displayProduct) {
      displayProduct.position.set(shelf.x + offsetX, 1.0 + offsetY, shelf.z);
      displayProduct.scale.setScalar(0.4);
      scene.add(displayProduct);
    }

    player.heldItems.splice(itemIndex, 1);
    repositionHeldItems();
    shelf.stock++;
    updateHUD();
    return;
  }
}

function repositionHeldItems() {
  const player = GameState.player;
  player.heldItems.forEach((item, i) => {
    if (item.mesh) {
      item.mesh.position.set(0, 1.2 + i * 0.35, -0.35);
    }
  });
}

function spawnCustomer() {
  if (GameState.customers.length >= 5) return;

  const shelfWithStock = Object.entries(GameState.shelves).find(([k, s]) => s.stock > 0);
  if (!shelfWithStock) return;

  const [targetShelfKey, targetShelf] = shelfWithStock;
  const customerMesh = createPlaceholderCustomer();

  const spawnSide = Math.random() > 0.5 ? 1 : -1;
  const spawnX = spawnSide * (GameState.store.width / 2 + 2);
  const spawnZ = GameState.store.length / 2;
  customerMesh.position.set(spawnX, 0, spawnZ);
  scene.add(customerMesh);

  const mixer = new THREE.AnimationMixer(customerMesh);
  GameState.mixers.push(mixer);

  const customer = {
    mesh: customerMesh,
    state: 'entering',
    targetShelfKey: targetShelfKey,
    targetShelf: targetShelf,
    targetX: targetShelf.x,
    targetZ: targetShelf.z + 2,
    registerX: GameState.counters.register.x,
    registerZ: GameState.counters.register.z + 2,
    exitX: spawnX,
    exitZ: GameState.store.length / 2 + 5,
    speed: 0.03,
    mixer: mixer,
    waitingAtRegister: false,
    itemMesh: null,
    hasItem: false,
  };

  GameState.customers.push(customer);
}

function updateCustomers(delta) {
  const doorX = 0;
  const doorZ = GameState.store.length / 2;

  if (Math.random() < 0.003) {
    spawnCustomer();
  }

  for (let i = GameState.customers.length - 1; i >= 0; i--) {
    const c = GameState.customers[i];
    if (!c.mesh) continue;

    const dx = c.mesh.position.x - c.targetX;
    const dz = c.mesh.position.z - c.targetZ;
    const dist = Math.sqrt(dx * dx + dz * dz);

    switch (c.state) {
      case 'entering': {
        c.targetX = doorX;
        c.targetZ = doorZ - 2;
        if (dist < 0.5) {
          c.state = 'walking_to_shelf';
          c.targetX = c.targetShelf.x;
          c.targetZ = c.targetShelf.z + 2;
        }
        break;
      }
      case 'walking_to_shelf': {
        if (dist < 0.5) {
          c.targetX = c.registerX;
          c.targetZ = c.registerZ;
          c.state = 'walking_to_register';

          const productMesh = cloneProductMesh(c.targetShelf.type);
          if (productMesh) {
            productMesh.position.set(0, 1.0, 0);
            productMesh.scale.setScalar(0.3);
            c.mesh.add(productMesh);
            c.itemMesh = productMesh;
            c.hasItem = true;
          }
        }
        break;
      }
      case 'walking_to_register': {
        if (dist < 1.0) {
          c.state = 'waiting_at_register';
          c.waitingAtRegister = true;
          c.targetX = c.mesh.position.x;
          c.targetZ = c.mesh.position.z;

          if (!GameState.activeCustomer) {
            GameState.activeCustomer = c;
            startHaggling(c);
          }
        }
        break;
      }
      case 'leaving': {
        c.targetX = c.exitX;
        c.targetZ = c.exitZ;
        if (dist < 1.0) {
          scene.remove(c.mesh);
          GameState.customers.splice(i, 1);
          if (GameState.activeCustomer === c) {
            GameState.activeCustomer = null;
          }
          continue;
        }
        break;
      }
    }

    if (c.state !== 'waiting_at_register') {
      const moveDirX = c.targetX - c.mesh.position.x;
      const moveDirZ = c.targetZ - c.mesh.position.z;
      const moveLen = Math.sqrt(moveDirX * moveDirX + moveDirZ * moveDirZ);
      if (moveLen > 0.1) {
        c.mesh.position.x += (moveDirX / moveLen) * c.speed;
        c.mesh.position.z += (moveDirZ / moveLen) * c.speed;
        c.mesh.rotation.y = Math.atan2(moveDirX, moveDirZ);
      }
    }
  }
}

function startHaggling(customer) {
  if (GameState.isHaggling) return;

  const itemType = customer.targetShelf.type;
  const basePrice = PRICES[itemType];
  const modifier = 0.70 + Math.random() * 0.60;
  const offerPrice = Math.round(basePrice * modifier);

  GameState.isHaggling = true;
  GameState.hagglePrice = offerPrice;
  GameState.haggleItem = itemType;
  GameState.haggleCustomer = customer;

  const overlay = document.getElementById('haggle-overlay');
  const text = document.getElementById('haggle-text');
  if (overlay && text) {
    text.textContent = `Customer offers $${offerPrice} for a ${itemType}!`;
    overlay.style.display = 'block';
  }
}

function updateHaggleInput() {
  if (!GameState.isHaggling) return;

  if (keys['KeyY']) {
    keys['KeyY'] = false;
    acceptHaggle();
  }

  if (keys['KeyN']) {
    keys['KeyN'] = false;
    rejectHaggle();
  }
}

function acceptHaggle() {
  const price = GameState.hagglePrice;
  const customer = GameState.haggleCustomer;

  GameState.player.cash += price;
  GameState.shelves[customer.targetShelfKey].stock = Math.max(0, GameState.shelves[customer.targetShelfKey].stock - 1);

  if (customer.itemMesh) {
    customer.mesh.remove(customer.itemMesh);
    customer.itemMesh = null;
    customer.hasItem = false;
  }

  customer.state = 'leaving';
  customer.targetX = customer.exitX;
  customer.targetZ = customer.exitZ;

  GameState.isHaggling = false;
  GameState.hagglePrice = 0;
  GameState.haggleItem = null;
  GameState.haggleCustomer = null;
  GameState.activeCustomer = null;

  const overlay = document.getElementById('haggle-overlay');
  if (overlay) overlay.style.display = 'none';

  const registerShelfCustomers = GameState.customers.filter((c) => c.state === 'waiting_at_register' && c !== customer);
  if (registerShelfCustomers.length > 0) {
    const next = registerShelfCustomers[0];
    GameState.activeCustomer = next;
    startHaggling(next);
  }

  updateHUD();
}

function rejectHaggle() {
  const customer = GameState.haggleCustomer;

  if (customer.itemMesh) {
    customer.mesh.remove(customer.itemMesh);
    customer.itemMesh = null;
    customer.hasItem = false;
  }

  customer.state = 'leaving';
  customer.targetX = customer.exitX;
  customer.targetZ = customer.exitZ;

  GameState.isHaggling = false;
  GameState.hagglePrice = 0;
  GameState.haggleItem = null;
  GameState.haggleCustomer = null;
  GameState.activeCustomer = null;

  const overlay = document.getElementById('haggle-overlay');
  if (overlay) overlay.style.display = 'none';

  const registerShelfCustomers = GameState.customers.filter((c) => c.state === 'waiting_at_register' && c !== customer);
  if (registerShelfCustomers.length > 0) {
    const next = registerShelfCustomers[0];
    GameState.activeCustomer = next;
    startHaggling(next);
  }

  updateHUD();
}

function updateTraffic(delta) {
  const playerX = GameState.player.x;
  const playerZ = GameState.player.z;

  GameState.traffic.forEach((t) => {
    if (t.stopped) {
      const dx = t.mesh.position.x - playerX;
      const dz = t.mesh.position.z - playerZ;
      const dist = Math.sqrt(dx * dx + dz * dz);
      if (dist > 5) {
        t.stopped = false;
      }
      return;
    }

    const route = t.route;
    t.progress += t.speed * delta * 60;

    if (t.progress >= 1) {
      t.progress = 0;
    }

    const lerpX = route.start.x + (route.end.x - route.start.x) * t.progress;
    const lerpZ = route.start.z + (route.end.z - route.start.z) * t.progress;
    t.mesh.position.x = lerpX;
    t.mesh.position.z = lerpZ;

    if (route.axis === 'x') {
      t.mesh.rotation.y = route.end.x > route.start.x ? 0 : Math.PI;
    } else {
      t.mesh.rotation.y = route.end.z > route.start.z ? Math.PI / 2 : -Math.PI / 2;
    }

    const carDx = t.mesh.position.x - playerX;
    const carDz = t.mesh.position.z - playerZ;
    const carDist = Math.sqrt(carDx * carDx + carDz * carDz);
    if (carDist < 4) {
      const storeMinX = GameState.store.x - GameState.store.width / 2;
      const storeMaxX = GameState.store.x + GameState.store.width / 2;
      const storeMinZ = GameState.store.z - GameState.store.length / 2;
      const storeMaxZ = GameState.store.z + GameState.store.length / 2;
      const nearStore = (
        playerX >= storeMinX - 3 && playerX <= storeMaxX + 3 &&
        playerZ >= storeMinZ - 3 && playerZ <= storeMaxZ + 3
      );
      if (nearStore) {
        t.stopped = true;
      }
    }
  });
}

function updatePedestrians(delta) {
  GameState.pedestrians.forEach((p) => {
    const target = p.waypoints[p.currentTarget];
    const dx = target.x - p.mesh.position.x;
    const dz = target.z - p.mesh.position.z;
    const dist = Math.sqrt(dx * dx + dz * dz);

    if (dist < 0.5) {
      p.currentTarget = (p.currentTarget + 1) % p.waypoints.length;
      return;
    }

    const moveX = (dx / dist) * p.speed;
    const moveZ = (dz / dist) * p.speed;
    p.mesh.position.x += moveX;
    p.mesh.position.z += moveZ;
    p.mesh.rotation.y = Math.atan2(dx, dz);
  });
}

function updateCamera() {
  const targetX = GameState.player.x + 12;
  const targetY = 15;
  const targetZ = GameState.player.z + 12;

  camera.position.x += (targetX - camera.position.x) * 0.05;
  camera.position.y += (targetY - camera.position.y) * 0.05;
  camera.position.z += (targetZ - camera.position.z) * 0.05;

  camera.lookAt(GameState.player.x, 1, GameState.player.z);
}

function animate() {
  const delta = clock.getDelta();

  updatePlayer(delta);
  updateCamera();
  updateTraffic(delta);
  updatePedestrians(delta);
  updateCustomers(delta);

  GameState.mixers.forEach((mixer) => {
    mixer.update(delta);
  });

  renderer.render(scene, camera);
}

init();
