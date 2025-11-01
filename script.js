const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
const fileInput = document.getElementById('fileInput');
const coordTable = document.getElementById('coordTable');

let img = null;
let selectedPoint = 'topHead';
let points = {
  topHead: null,
  bottomHead: null,
  eyes: null,
  nose: null
};

// Radio buttons
document.querySelectorAll('input[name="point"]').forEach(radio => {
  radio.addEventListener('change', e => selectedPoint = e.target.value);
});

// Caricamento immagine
fileInput.addEventListener('change', e => {
  const file = e.target.files[0];
  if (!file) return;
  const url = URL.createObjectURL(file);
  img = new Image();
  img.onload = () => {
    resizeCanvas();
    draw();
    URL.revokeObjectURL(url);
    window.addEventListener('resize', resizeCanvas);
  };
  img.src = url;
});

// Adatta il canvas alla finestra
function resizeCanvas() {
  if (!img) return;
  const container = document.getElementById('canvasContainer');
  const maxWidth = container.clientWidth;
  const ratio = img.width / img.height;
  canvas.width = maxWidth;
  canvas.height = maxWidth / ratio;
  draw();
}

// Click sul canvas
canvas.addEventListener('click', e => {
  if (!img) return;
  const rect = canvas.getBoundingClientRect();
  const x = e.clientX - rect.left;
  const y = e.clientY - rect.top;
  const imgX = Math.round((x / canvas.width) * img.width);
  const imgY = Math.round((y / canvas.height) * img.height);
  points[selectedPoint] = { x: imgX, y: imgY };
  draw();
  updateTable();
});

function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  if (img) ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  Object.entries(points).forEach(([key, p]) => {
    if (!p) return;
    const cx = (p.x / img.width) * canvas.width;
    const cy = (p.y / img.height) * canvas.height;
    ctx.beginPath();
    ctx.arc(cx, cy, 5, 0, Math.PI * 2);
    ctx.fillStyle = colorForKey(key);
    ctx.fill();
  });
}

function colorForKey(k) {
  return {
    topHead: 'red',
    bottomHead: 'orange',
    eyes: 'green',
    nose: 'blue'
  }[k] || 'black';
}

function updateTable() {
  coordTable.innerHTML = '';
  for (const [key, p] of Object.entries(points)) {
    const tr = document.createElement('tr');
    const label = labelForKey(key);
    const x = p ? p.x : '';
    const y = p ? p.y : '';
    tr.innerHTML = `<td>${label}</td><td>${x}</td><td>${y}</td>
                    <td><button onclick=\"clearPoint('${key}')\">X</button></td>`;
    coordTable.appendChild(tr);
  }
}

function labelForKey(k) {
  return {
    topHead: 'Parte alta della testa',
    bottomHead: 'Parte bassa della testa',
    eyes: 'Posizione degli occhi',
    nose: 'Posizione del naso'
  }[k];
}

window.clearPoint = function(k) {
  points[k] = null;
  draw();
  updateTable();
};

document.getElementById('clearAll').addEventListener('click', () => {
  for (const k in points) points[k] = null;
  draw();
  updateTable();
});

document.getElementById('exportJSON').addEventListener('click', () => {
  const data = {
    topHeadY: points.topHead ? points.topHead.y : null,
    bottomHeadY: points.bottomHead ? points.bottomHead.y : null,
    eyesY: points.eyes ? points.eyes.y : null,
    noseX: points.nose ? points.nose.x : null
  };
  download('image-map.json', JSON.stringify(data, null, 2));
});

document.getElementById('exportCSV').addEventListener('click', () => {
  const rows = [
    ['Campo', 'Valore'],
    ['Parte alta della testa - Y', points.topHead ? points.topHead.y : ''],
    ['Parte bassa della testa - Y', points.bottomHead ? points.bottomHead.y : ''],
    ['Posizione degli occhi - Y', points.eyes ? points.eyes.y : ''],
    ['Posizione del naso - X', points.nose ? points.nose.x : '']
  ];
  const csv = rows.map(r => r.map(v => `"${v}"`).join(',')).join('\n');
  download('image-map.csv', csv);
});

function download(name, content) {
  const blob = new Blob([content], { type: 'text/plain' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
}
