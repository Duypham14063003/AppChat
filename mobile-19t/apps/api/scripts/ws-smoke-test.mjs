/**
 * WebSocket smoke-test script
 * Usage:  node scripts/ws-smoke-test.mjs [ACCESS_TOKEN]
 *
 * Tests:
 *   1. Connect to ws://localhost:3000/ws
 *   2. Auth with JWT
 *   3. Heartbeat (ping/pong)
 *   4. Send a message (if CONV_ID env is set)
 */

import WebSocket from 'ws';
import { randomUUID } from 'crypto';

const WS_URL = process.env.WS_URL || 'ws://localhost:3002/ws';
const TOKEN = process.argv[2] || process.env.ACCESS_TOKEN;
const CONV_ID = process.env.CONV_ID; // optional — for send_message test

if (!TOKEN) {
  console.error('Usage: node scripts/ws-smoke-test.mjs <ACCESS_TOKEN>');
  console.error('  or set ACCESS_TOKEN env var');
  process.exit(1);
}

const log = (tag, ...args) => console.log(`[${tag}]`, ...args);
const results = { connect: false, auth: false, heartbeat: false, send: null };

const ws = new WebSocket(WS_URL);
let authDone = false;

ws.on('open', () => {
  log('CONNECT', `Connected to ${WS_URL}`);
  results.connect = true;

  // Send auth
  ws.send(JSON.stringify({ event: 'auth', data: { token: TOKEN } }));
  log('AUTH', 'Sent auth event');
});

ws.on('message', (raw) => {
  const msg = JSON.parse(raw.toString());
  log('MSG', JSON.stringify(msg, null, 2));

  if (msg.event === 'auth_success') {
    results.auth = true;
    log('AUTH', `Authenticated as ${msg.data.userId}`);
    authDone = true;

    // Test send_message if CONV_ID provided
    if (CONV_ID) {
      const msgId = randomUUID();
      const payload = {
        event: 'send_message',
        data: {
          id: msgId,
          conv_id: CONV_ID,
          type: 'text',
          content: `Smoke test at ${new Date().toISOString()}`,
        },
        id: `req-${msgId}`,
      };
      ws.send(JSON.stringify(payload));
      log('SEND', 'Sent test message');
    }
  }

  if (msg.event === 'auth_error') {
    log('AUTH', `FAILED: ${msg.data.message}`);
    ws.close();
  }

  if (msg.event === 'message_ack') {
    results.send = true;
    log('SEND', `Message ACK received — id: ${msg.data.id}, status: ${msg.data.status}`);
  }

  if (msg.event === 'error') {
    log('ERROR', `${msg.data.code}: ${msg.data.message}`);
    if (msg.event === 'send_message') results.send = false;
  }
});

ws.on('ping', () => {
  log('HEARTBEAT', 'Received ping from server');
  results.heartbeat = true;
});

ws.on('pong', () => {
  log('HEARTBEAT', 'Received pong');
});

ws.on('close', (code, reason) => {
  log('CLOSE', `code=${code} reason=${reason.toString()}`);
  printResults();
});

ws.on('error', (err) => {
  log('ERROR', err.message);
  if (err.code) log('ERROR', `code: ${err.code}`);
  if (err.code === 'ECONNREFUSED') {
    log('ERROR', 'Is the API server running? (npm start dev)');
  }
  printResults();
  process.exit(1);
});

// Send a client-side ping after auth to verify connection is alive
setTimeout(() => {
  if (ws.readyState === WebSocket.OPEN) {
    ws.ping();
    log('HEARTBEAT', 'Sent client ping');
  }
}, 3000);

// Auto-close after timeout
const TIMEOUT = CONV_ID ? 10000 : 6000;
setTimeout(() => {
  log('DONE', 'Timeout reached, closing');
  ws.close();
}, TIMEOUT);

function printResults() {
  console.log('\n--- Results ---');
  console.log(`  Connect:   ${results.connect ? 'PASS' : 'FAIL'}`);
  console.log(`  Auth:      ${results.auth ? 'PASS' : 'FAIL'}`);
  console.log(`  Heartbeat: ${results.heartbeat ? 'PASS' : '(server pings every 30s — use longer timeout to verify)'}`);
  if (CONV_ID) {
    console.log(`  Send msg:  ${results.send === true ? 'PASS' : results.send === false ? 'FAIL' : 'NO RESPONSE'}`);
  } else {
    console.log(`  Send msg:  SKIPPED (set CONV_ID env to test)`);
  }
  console.log('');
}
