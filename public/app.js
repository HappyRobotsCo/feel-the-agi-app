// Feel the AGI — Dashboard SPA

(function () {
  'use strict';

  // ── DOM References ──────────────────────────────────────────
  const linkedinInput = document.getElementById('linkedin-url');
  const styleSelect = document.getElementById('style-select');
  const statusWebsite = document.getElementById('status-website');
  const launchBtn = document.getElementById('launch-btn');
  const stateSetup = document.getElementById('state-setup');
  const stateRunning = document.getElementById('state-running');
  const stateComplete = document.getElementById('state-complete');

  // ── Card Readiness Tracking ────────────────────────────────
  const cardReady = { website: false, email: true, documents: true };

  function updateLaunchButton() {
    const allReady = cardReady.website && cardReady.email && cardReady.documents;
    launchBtn.disabled = !allReady;
  }

  // ── LinkedIn URL Validation ─────────────────────────────────
  const LINKEDIN_PATTERN = /linkedin\.com\/in\/.+/i;

  function validateLinkedIn(value) {
    const trimmed = value.trim();
    if (!trimmed) {
      linkedinInput.classList.remove('valid', 'invalid');
      setCardStatus(statusWebsite, false);
      return;
    }
    const isValid = LINKEDIN_PATTERN.test(trimmed);
    linkedinInput.classList.toggle('valid', isValid);
    linkedinInput.classList.toggle('invalid', !isValid);
    setCardStatus(statusWebsite, isValid);
  }

  function setCardStatus(statusEl, ready) {
    const dot = statusEl.querySelector('.status-dot');
    const text = statusEl.querySelector('.status-text');
    if (ready) {
      statusEl.classList.add('ready');
      text.textContent = 'Ready';
    } else {
      statusEl.classList.remove('ready');
      text.textContent = 'Pending';
    }

    // Track readiness for launch button
    if (statusEl === statusWebsite) cardReady.website = ready;
    else if (statusEl === statusEmail) cardReady.email = ready;
    else if (statusEl === statusDocuments) cardReady.documents = ready;
    updateLaunchButton();
  }

  // ── localStorage Persistence ────────────────────────────────
  const STORAGE_KEYS = {
    linkedinUrl: 'fta_linkedin_url',
    stylePreference: 'fta_style_preference',
    documentsPath: 'fta_documents_path',
    documentsPrompt: 'fta_documents_prompt',
  };

  function loadSavedValues() {
    const savedUrl = localStorage.getItem(STORAGE_KEYS.linkedinUrl);
    if (savedUrl !== null) {
      linkedinInput.value = savedUrl;
    }
    // Always validate current value (covers HTML defaults and saved values)
    validateLinkedIn(linkedinInput.value);

    const savedStyle = localStorage.getItem(STORAGE_KEYS.stylePreference);
    if (savedStyle !== null) {
      styleSelect.value = savedStyle;
    }

    // Card 3: documents path + prompt (loaded here for persistence, Card 3 is auto-ready)
    const documentsPath = document.getElementById('documents-path');
    const savedPath = localStorage.getItem(STORAGE_KEYS.documentsPath);
    if (savedPath !== null && documentsPath) {
      documentsPath.value = savedPath;
    }

    const documentsPrompt = document.getElementById('documents-prompt');
    const savedPrompt = localStorage.getItem(STORAGE_KEYS.documentsPrompt);
    if (savedPrompt !== null && documentsPrompt) {
      documentsPrompt.value = savedPrompt;
    }
  }

  function bindPersistence() {
    linkedinInput.addEventListener('input', function () {
      localStorage.setItem(STORAGE_KEYS.linkedinUrl, linkedinInput.value);
      validateLinkedIn(linkedinInput.value);
    });

    styleSelect.addEventListener('change', function () {
      localStorage.setItem(STORAGE_KEYS.stylePreference, styleSelect.value);
    });

    // Card 3: persist documents path + prompt on input
    const documentsPath = document.getElementById('documents-path');
    if (documentsPath) {
      documentsPath.addEventListener('input', function () {
        localStorage.setItem(STORAGE_KEYS.documentsPath, documentsPath.value);
      });
    }
    const documentsPrompt = document.getElementById('documents-prompt');
    if (documentsPrompt) {
      documentsPrompt.addEventListener('input', function () {
        localStorage.setItem(STORAGE_KEYS.documentsPrompt, documentsPrompt.value);
      });
    }
  }

  // ── Copy to Clipboard ───────────────────────────────────────
  const copyBtn = document.getElementById('copy-btn');
  const setupCommand = document.getElementById('setup-command');

  if (copyBtn && setupCommand) {
    copyBtn.addEventListener('click', function () {
      navigator.clipboard.writeText(setupCommand.textContent).then(function () {
        copyBtn.textContent = 'Copied!';
        setTimeout(function () {
          copyBtn.textContent = 'Copy';
        }, 2000);
      });
    });
  }

  // ── Card 2: Email (auto-ready — Gmail auth handled by MCP at runtime) ──
  const statusEmail = document.getElementById('status-email');

  const terminalSetup = document.getElementById('terminal-setup');
  const serverStatus = document.getElementById('server-status');

  let serverDetected = false;

  // Server health polling — transitions UI when server is detected
  function pollHealth() {
    fetch('/health')
      .then(function (res) {
        if (res.ok) {
          if (!serverDetected) {
            serverDetected = true;
            // Hide terminal setup, show server connected status
            terminalSetup.classList.add('hidden');
            serverStatus.classList.add('visible');
          }
        }
      })
      .catch(function () {
        if (serverDetected) {
          serverDetected = false;
          // Show terminal setup again, hide server status
          terminalSetup.classList.remove('hidden');
          serverStatus.classList.remove('visible');
        }
      });
  }

  // Start health polling
  setInterval(pollHealth, 2000);
  pollHealth(); // immediate first check

  // ── Card 2 & 3: Auto-Ready ─────────────────────────────────
  setCardStatus(statusEmail, true);
  const statusDocuments = document.getElementById('status-documents');
  setCardStatus(statusDocuments, true);

  // ── Live Preview ─────────────────────────────────────────────
  const livePreview = document.getElementById('live-preview');
  const previewPlaceholder = document.getElementById('preview-placeholder');
  const previewIframe = document.getElementById('preview-iframe');
  const runningLayout = document.querySelector('.running-layout');
  var previewPollingInterval = null;
  var previewDetected = false;

  function pollPreview() {
    if (previewDetected) return;
    fetch('http://localhost:3000', { mode: 'no-cors' })
      .then(function () {
        // no-cors fetch resolves with opaque response on success — means server is up
        previewDetected = true;
        showPreview();
      })
      .catch(function () {
        // Server not available yet — keep polling
      });
  }

  function showPreview() {
    livePreview.classList.add('visible');
    runningLayout.classList.add('has-preview');
    previewPlaceholder.classList.add('hidden');
    previewIframe.classList.add('loaded');
    previewIframe.src = 'http://localhost:3000';
    addLogEntry('website', 'Live preview available at localhost:3000');
    addTimelineEvent('website', 'Website preview is live');
    stopPreviewPolling();
  }

  function startPreviewPolling() {
    if (previewPollingInterval) return;
    previewDetected = false;
    livePreview.classList.add('visible');
    runningLayout.classList.add('has-preview');
    previewPollingInterval = setInterval(pollPreview, 2000);
    pollPreview(); // immediate first check
  }

  function stopPreviewPolling() {
    if (previewPollingInterval) {
      clearInterval(previewPollingInterval);
      previewPollingInterval = null;
    }
  }

  // ── Running State: DOM References ──────────────────────────
  const stopBtn = document.getElementById('stop-btn');
  const logWebsite = document.getElementById('log-website');
  const logEmail = document.getElementById('log-email');
  const logDocuments = document.getElementById('log-documents');
  const badgeWebsite = document.getElementById('badge-website');
  const badgeEmail = document.getElementById('badge-email');
  const badgeDocuments = document.getElementById('badge-documents');
  const timeline = document.getElementById('timeline');

  const logs = { website: logWebsite, email: logEmail, documents: logDocuments };
  const badges = { website: badgeWebsite, email: badgeEmail, documents: badgeDocuments };

  // ── Running State: Activity Log ───────────────────────────
  function formatTime(date) {
    return date.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
  }

  function addLogEntry(mission, text) {
    var logEl = logs[mission];
    if (!logEl) return;
    var entry = document.createElement('div');
    entry.className = 'log-entry';
    var time = document.createElement('span');
    time.className = 'log-time';
    time.textContent = formatTime(new Date());
    entry.appendChild(time);
    entry.appendChild(document.createTextNode(text));
    logEl.appendChild(entry);
    logEl.scrollTop = logEl.scrollHeight;
  }

  // ── Running State: Timeline ────────────────────────────────
  function addTimelineEvent(mission, text) {
    var emptyMsg = timeline.querySelector('.timeline-empty');
    if (emptyMsg) emptyMsg.remove();

    var event = document.createElement('div');
    event.className = 'timeline-event';

    var timeEl = document.createElement('span');
    timeEl.className = 'timeline-time';
    timeEl.textContent = formatTime(new Date());

    var missionEl = document.createElement('span');
    missionEl.className = 'timeline-mission mission-' + mission;
    var missionNames = { website: 'Build', email: 'Email', documents: 'Docs' };
    missionEl.textContent = missionNames[mission] || mission;

    var textEl = document.createElement('span');
    textEl.className = 'timeline-text';
    textEl.textContent = text;

    event.appendChild(timeEl);
    event.appendChild(missionEl);
    event.appendChild(textEl);
    timeline.appendChild(event);
    timeline.scrollTop = timeline.scrollHeight;
  }

  // ── Running State: Badge Updates ───────────────────────────
  function setMissionComplete(mission) {
    var badge = badges[mission];
    if (!badge) return;
    badge.textContent = 'Complete';
    badge.classList.remove('badge-running');
    badge.classList.add('badge-complete');
  }

  // ── Running State: Transition Helper ──────────────────────
  function transitionToRunning() {
    stateSetup.classList.remove('active');
    stateRunning.classList.add('active');
    // Add "Waiting for updates..." to empty timeline
    var emptyMsg = document.createElement('div');
    emptyMsg.className = 'timeline-empty';
    emptyMsg.textContent = 'Waiting for agent updates...';
    timeline.appendChild(emptyMsg);
    // Start WebSocket connection for live status updates
    connectWebSocket();
    // Start polling for live website preview at localhost:3000
    startPreviewPolling();
  }

  // ── Launch Button ──────────────────────────────────────────
  launchBtn.addEventListener('click', function () {
    if (launchBtn.disabled) return;
    launchBtn.disabled = true;
    launchBtn.textContent = 'Saving config...';

    var config = {
      linkedin_url: linkedinInput.value.trim(),
      style_preference: styleSelect.value,
      documents_path: (document.getElementById('documents-path').value.trim() || '~/Documents'),
      documents_prompt: (document.getElementById('documents-prompt').value || ''),
    };

    // Save config first, then launch
    fetch('/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(config),
    })
      .then(function (res) {
        if (!res.ok) throw new Error('Config save failed');
        launchBtn.textContent = 'Launching...';
        return fetch('/launch', { method: 'POST' });
      })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data.status === 'launching') {
          transitionToRunning();
        } else {
          launchBtn.textContent = 'Launch All Agents';
          launchBtn.disabled = false;
        }
      })
      .catch(function () {
        launchBtn.textContent = 'Launch All Agents';
        launchBtn.disabled = false;
      });
  });

  // ── Stop Button ────────────────────────────────────────────
  stopBtn.addEventListener('click', function () {
    stopBtn.disabled = true;
    stopBtn.textContent = 'Stopping...';

    fetch('/stop', { method: 'POST' })
      .then(function (res) { return res.json(); })
      .then(function () {
        stopBtn.textContent = 'Stopped';
        addTimelineEvent('website', 'All agents stopped by user');
      })
      .catch(function () {
        stopBtn.disabled = false;
        stopBtn.textContent = 'Stop All';
      });
  });

  // ── WebSocket Client ─────────────────────────────────────────
  var ws = null;
  var wsReconnectInterval = null;
  var lastDetail = { website: null, email: null, documents: null };

  function connectWebSocket() {
    if (ws && ws.readyState <= 1) return; // CONNECTING or OPEN

    var protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    ws = new WebSocket(protocol + '//' + location.host + '/ws');

    ws.onopen = function () {
      console.log('[ws] connected');
      addLogEntry('website', 'Connected to coordination server');
      addLogEntry('email', 'Connected to coordination server');
      addLogEntry('documents', 'Connected to coordination server');
    };

    ws.onmessage = function (event) {
      var msg;
      try { msg = JSON.parse(event.data); } catch { return; }
      if (msg.type !== 'status' || !msg.mission || !msg.data) return;

      var mission = msg.mission;
      var data = msg.data;

      // Only log new detail text (status files are rewritten on each update)
      if (data.detail && data.detail !== lastDetail[mission]) {
        lastDetail[mission] = data.detail;
        addLogEntry(mission, data.detail);
        addTimelineEvent(mission, data.detail);
      }

      // Log new milestones
      if (data.milestones && data.milestones.length) {
        var latest = data.milestones[data.milestones.length - 1];
        if (latest && latest.event && latest.event !== lastDetail[mission]) {
          addLogEntry(mission, latest.event);
        }
      }

      // Store latest status data for complete state rendering
      lastStatusData[mission] = data;

      // Complete state
      if (data.stage === 'complete') {
        setMissionComplete(mission);
        completedMissions[mission] = true;
        if (checkAllComplete()) {
          // Small delay to let the user see the final "Complete" badges
          setTimeout(transitionToComplete, 1500);
        }
      }
    };

    ws.onclose = function () {
      console.log('[ws] disconnected');
      ws = null;
      scheduleReconnect();
    };

    ws.onerror = function () {
      // onclose fires after onerror, so reconnect is handled there
    };
  }

  function scheduleReconnect() {
    if (wsReconnectInterval) return;
    wsReconnectInterval = setInterval(function () {
      if (stateRunning.classList.contains('active')) {
        connectWebSocket();
      } else {
        clearInterval(wsReconnectInterval);
        wsReconnectInterval = null;
      }
    }, 2000);
  }

  function disconnectWebSocket() {
    if (wsReconnectInterval) {
      clearInterval(wsReconnectInterval);
      wsReconnectInterval = null;
    }
    if (ws) {
      ws.close();
      ws = null;
    }
    stopPreviewPolling();
  }

  // ── Complete State ───────────────────────────────────────────
  var completedMissions = { website: false, email: false, documents: false };
  var lastStatusData = { website: null, email: null, documents: null };

  function checkAllComplete() {
    return completedMissions.website && completedMissions.email && completedMissions.documents;
  }

  function transitionToComplete() {
    disconnectWebSocket();
    stateRunning.classList.remove('active');
    stateComplete.classList.add('active');

    // Populate result summaries from last status data
    renderWebsiteResult();
    renderEmailResult();
    renderDocumentsResult();

    // Copy timeline events from running state to complete state
    var completeTimeline = document.getElementById('complete-timeline');
    var runningEvents = timeline.querySelectorAll('.timeline-event');
    runningEvents.forEach(function (ev) {
      completeTimeline.appendChild(ev.cloneNode(true));
    });
    completeTimeline.scrollTop = completeTimeline.scrollHeight;
  }

  function renderWebsiteResult() {
    var summary = document.getElementById('result-website-summary');
    var iframe = document.getElementById('result-iframe');
    var data = lastStatusData.website;
    if (data && data.detail) {
      summary.textContent = data.detail;
    }
    if (previewDetected) {
      iframe.src = 'http://localhost:3000';
    }
  }

  function renderEmailResult() {
    var summary = document.getElementById('result-email-summary');
    var statsEl = document.getElementById('result-email-stats');
    var urgentEl = document.getElementById('result-email-urgent');
    var data = lastStatusData.email;

    if (!data) return;
    if (data.detail) summary.textContent = data.detail;

    // Render stats from artifacts if available
    if (data.artifacts && data.artifacts.stats) {
      var stats = data.artifacts.stats;
      Object.keys(stats).forEach(function (key) {
        var row = document.createElement('div');
        row.className = 'stat-row';
        row.innerHTML = '<span class="stat-label">' + escapeHtml(key) + '</span><span class="stat-value">' + escapeHtml(String(stats[key])) + '</span>';
        statsEl.appendChild(row);
      });
    }

    // Render urgent emails if available
    if (data.artifacts && data.artifacts.urgent && data.artifacts.urgent.length) {
      data.artifacts.urgent.forEach(function (item) {
        var el = document.createElement('div');
        el.className = 'urgent-item';
        var header = document.createElement('div');
        header.className = 'urgent-header';
        header.innerHTML = '<span>' + escapeHtml(item.subject || 'Urgent Email') + '</span><span class="urgent-toggle">&#9660;</span>';
        header.addEventListener('click', function () {
          el.classList.toggle('expanded');
        });
        var body = document.createElement('div');
        body.className = 'urgent-body';
        body.innerHTML = '<p>' + escapeHtml(item.summary || '') + '</p>';
        if (item.draft) {
          body.innerHTML += '<p class="draft-label">Draft Reply</p><div class="draft-text">' + escapeHtml(item.draft) + '</div>';
        }
        el.appendChild(header);
        el.appendChild(body);
        urgentEl.appendChild(el);
      });
    }
  }

  function renderDocumentsResult() {
    var summary = document.getElementById('result-documents-summary');
    var statsEl = document.getElementById('result-documents-stats');
    var data = lastStatusData.documents;

    if (!data) return;
    if (data.detail) summary.textContent = data.detail;

    // Render stats from artifacts if available
    if (data.artifacts && data.artifacts.stats) {
      var stats = data.artifacts.stats;
      Object.keys(stats).forEach(function (key) {
        var row = document.createElement('div');
        row.className = 'stat-row';
        row.innerHTML = '<span class="stat-label">' + escapeHtml(key) + '</span><span class="stat-value">' + escapeHtml(String(stats[key])) + '</span>';
        statsEl.appendChild(row);
      });
    }
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // Undo button
  var undoBtn = document.getElementById('undo-btn');
  var undoStatus = document.getElementById('undo-status');

  undoBtn.addEventListener('click', function () {
    undoBtn.disabled = true;
    undoBtn.textContent = 'Undoing...';
    undoStatus.textContent = '';
    undoStatus.className = 'undo-status';

    fetch('/undo/documents', { method: 'POST' })
      .then(function (res) { return res.json().then(function (data) { return { ok: res.ok, data: data }; }); })
      .then(function (result) {
        if (result.ok) {
          undoBtn.textContent = 'Changes Undone';
          undoStatus.textContent = 'All document changes have been restored.';
          undoStatus.className = 'undo-status success';
        } else {
          undoBtn.disabled = false;
          undoBtn.textContent = 'Undo All Changes';
          undoStatus.textContent = result.data.error || 'Undo failed.';
          undoStatus.className = 'undo-status error';
        }
      })
      .catch(function () {
        undoBtn.disabled = false;
        undoBtn.textContent = 'Undo All Changes';
        undoStatus.textContent = 'Network error — could not reach server.';
        undoStatus.className = 'undo-status error';
      });
  });

  // ── Init ────────────────────────────────────────────────────
  loadSavedValues();
  bindPersistence();
})();
