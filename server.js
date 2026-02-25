const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { exec } = require('node:child_process');
const { WebSocketServer } = require('ws');
const chokidar = require('chokidar');

const PORT = 3456;
const PUBLIC_DIR = path.join(__dirname, 'public');
const CONFIG_FILE = path.join(__dirname, 'config.json');
const STATUS_DIR = path.join(__dirname, 'status');
const PID_FILE = path.join(__dirname, '.server.pid');

const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function setCorsHeaders(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function serveStatic(req, res) {
  let filePath = path.join(PUBLIC_DIR, req.url === '/' ? 'index.html' : req.url);
  filePath = path.normalize(filePath);

  // Prevent directory traversal
  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  const ext = path.extname(filePath);
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not Found');
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks).toString()));
    req.on('error', reject);
  });
}

function jsonResponse(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

async function handlePostConfig(req, res) {
  const body = await readBody(req);
  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    jsonResponse(res, 400, { error: 'Invalid JSON' });
    return;
  }

  if (!parsed.linkedin_url) {
    jsonResponse(res, 400, { error: 'Missing required field: linkedin_url' });
    return;
  }

  const config = {
    linkedin_url: parsed.linkedin_url,
    style_preference: parsed.style_preference || 'Minimal',
    documents_path: parsed.documents_path || '~/Documents',
    documents_prompt: parsed.documents_prompt || '',
  };

  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
  jsonResponse(res, 200, config);
}

function handleGetConfig(req, res) {
  try {
    const data = fs.readFileSync(CONFIG_FILE, 'utf-8');
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(data);
  } catch {
    jsonResponse(res, 404, { error: 'Config not set' });
  }
}

const LAUNCH_SCRIPT = path.join(__dirname, 'launch.sh');
const UNDO_SCRIPT = path.join(__dirname, 'output', 'documents-report', 'undo.sh');

function handlePostLaunch(req, res) {
  // Check that config exists
  if (!fs.existsSync(CONFIG_FILE)) {
    jsonResponse(res, 400, { error: 'config not set' });
    return;
  }

  // Fire and forget — spawn launch.sh as a detached child process
  const child = exec(`bash "${LAUNCH_SCRIPT}"`, { cwd: __dirname });
  child.stdout.on('data', (data) => console.log(`[launch] ${data.toString().trimEnd()}`));
  child.stderr.on('data', (data) => console.error(`[launch] ${data.toString().trimEnd()}`));
  child.on('error', (err) => console.error(`[launch] error: ${err.message}`));

  jsonResponse(res, 200, { status: 'launching' });
}

function handlePostUndoDocuments(req, res) {
  if (!fs.existsSync(UNDO_SCRIPT)) {
    jsonResponse(res, 404, { error: 'No changes to undo' });
    return;
  }

  exec(`bash "${UNDO_SCRIPT}"`, (err, stdout, stderr) => {
    if (err) {
      console.error(`[undo] error: ${err.message}`);
      if (stderr) console.error(`[undo] stderr: ${stderr.trimEnd()}`);
      jsonResponse(res, 500, { error: 'Undo failed', details: stderr || err.message });
      return;
    }
    if (stdout) console.log(`[undo] ${stdout.trimEnd()}`);
    jsonResponse(res, 200, { status: 'restored' });
  });
}

function handlePostCreateSampleDocs(req, res) {
  const sampleDir = path.join(require('os').homedir(), 'Documents');
  const script = path.join(__dirname, 'create-test-folder.sh');

  if (!fs.existsSync(script)) {
    jsonResponse(res, 404, { error: 'Sample docs script not found' });
    return;
  }

  exec(`bash "${script}"`, (err, stdout, stderr) => {
    if (err) {
      console.error(`[sample-docs] error: ${err.message}`);
      jsonResponse(res, 500, { error: 'Failed to create sample docs', details: stderr || err.message });
      return;
    }
    if (stdout) console.log(`[sample-docs] ${stdout.trimEnd()}`);
    jsonResponse(res, 200, { status: 'created', path: '~/Documents' });
  });
}

function handlePostStop(req, res) {
  // [c]laude trick: regex [c]laude matches "claude" but the literal [c]laude
  // in the process list doesn't match the regex, preventing self-matching.
  exec('pkill -f "[c]laude.*dangerously-skip-permissions"', (err) => {
    // pkill exit code 1 = no processes matched
    if (err && err.code !== 1) {
      console.error(`[stop] error: ${err.message}`);
      jsonResponse(res, 500, { error: 'Failed to stop processes' });
      return;
    }
    const killed = !err;
    console.log(killed ? '[stop] Killed claude processes' : '[stop] No claude processes found');
    jsonResponse(res, 200, { status: 'stopped', killed });
  });
}

const server = http.createServer(async (req, res) => {
  setCorsHeaders(res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    jsonResponse(res, 200, { status: 'ok' });
    return;
  }

  if (req.method === 'POST' && req.url === '/config') {
    await handlePostConfig(req, res);
    return;
  }

  if (req.method === 'GET' && req.url === '/config') {
    handleGetConfig(req, res);
    return;
  }

  if (req.method === 'POST' && req.url === '/launch') {
    handlePostLaunch(req, res);
    return;
  }

  if (req.method === 'POST' && req.url === '/stop') {
    handlePostStop(req, res);
    return;
  }

  if (req.method === 'POST' && req.url === '/undo/documents') {
    handlePostUndoDocuments(req, res);
    return;
  }

  if (req.method === 'POST' && req.url === '/create-sample-docs') {
    handlePostCreateSampleDocs(req, res);
    return;
  }

  // Static file serving for all other GET requests
  if (req.method === 'GET') {
    serveStatic(req, res);
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

// WebSocket server on /ws path
const wss = new WebSocketServer({ noServer: true });

wss.on('connection', (ws) => {
  console.log('WebSocket client connected');
  ws.on('close', () => console.log('WebSocket client disconnected'));
});

server.on('upgrade', (req, socket, head) => {
  if (req.url === '/ws') {
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  } else {
    socket.destroy();
  }
});

// File watcher for status/*.json → WebSocket broadcast
function broadcastStatus(filePath) {
  if (path.extname(filePath) !== '.json') return;
  const fullPath = path.resolve(filePath);
  const filename = path.basename(fullPath, '.json');
  let data;
  try {
    data = JSON.parse(fs.readFileSync(fullPath, 'utf-8'));
  } catch {
    return; // Ignore partial writes or invalid JSON
  }
  const message = JSON.stringify({ type: 'status', mission: filename, data });
  wss.clients.forEach((client) => {
    if (client.readyState === 1) { // WebSocket.OPEN
      client.send(message);
    }
  });
}

const statusWatcher = chokidar.watch(STATUS_DIR, {
  ignoreInitial: true,
});

statusWatcher.on('add', broadcastStatus);
statusWatcher.on('change', broadcastStatus);

server.listen(PORT, () => {
  fs.writeFileSync(PID_FILE, String(process.pid));
  console.log(`Feel the AGI server running on http://localhost:${PORT}`);
});

// Graceful shutdown
function shutdown() {
  console.log('\nShutting down...');
  try { fs.unlinkSync(PID_FILE); } catch {}
  statusWatcher.close();
  wss.clients.forEach((client) => client.close());
  wss.close();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 3000);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
