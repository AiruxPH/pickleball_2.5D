const emulatorHost = process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '127.0.0.1:9000';
const namespace = 'pickleball-simulator';
const roomCode = 'RULETEST';
const hostUid = 'rules-host';
const clientUid = 'rules-client';

function databaseUrl(path, uid) {
  const auth = encodeURIComponent(JSON.stringify({ uid, token: {} }));
  return `http://${emulatorHost}/${path}.json?ns=${namespace}&auth_variable_override=${auth}`;
}

async function request(label, method, path, uid, body) {
  const response = await fetch(databaseUrl(path, uid), {
    method,
    headers: { 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${label}: ${response.status} ${await response.text()}`);
  }
  console.log(`PASS ${label}`);
}

await request('host meta create', 'PUT', `onlineRooms/${roomCode}/meta`, hostUid, {
  hostUid,
  sessionId: roomCode,
  status: 'lobby',
  format: 'singles',
  createdAt: 1,
  updatedAt: 1,
});
await request('host lobby/member write', 'PATCH', `onlineRooms/${roomCode}`, hostUid, {
  lobby: {
    id: roomCode,
    type: 'online',
    format: 'singles',
    slots: [
      { id: 'p1', name: 'PLAYER 1', team: 1, type: 'human', isReady: false },
      { id: 'p2', name: 'PLAYER 2', team: 2, type: 'human', isReady: false },
    ],
  },
  members: { [hostUid]: { role: 'host', slot: 0, online: true, joinedAt: 1 } },
});
await request('challenger room read', 'GET', `onlineRooms/${roomCode}`, clientUid);
await request('challenger member write', 'PUT', `onlineRooms/${roomCode}/members/${clientUid}`, clientUid, {
  role: 'client',
  slot: 1,
  online: true,
  joinedAt: 1,
});
await request('challenger ready action', 'PUT', `onlineRooms/${roomCode}/actions/test`, clientUid, {
  type: 'toggleReady',
  slotId: 'p2',
  uid: clientUid,
  createdAt: 1,
});
await request('host action cleanup', 'DELETE', `onlineRooms/${roomCode}/actions/test`, hostUid);
await request('challenger ready state', 'PUT', `onlineRooms/${roomCode}/ready/${clientUid}`, clientUid, true);
await request('host snapshot write', 'PUT', `onlineRooms/${roomCode}/snapshot`, hostUid, {
  ball: { x: 0, y: 1, z: 2 },
  p1: { x: 0, y: 0, z: 1 },
  p2: { x: 0, y: 0, z: -1 },
  pScore: 0,
  aScore: 0,
  srvNum: 1,
  isPSrv: true,
  srvPri: true,
  gState: 'rally',
  ts: 1,
});
await request('host start write', 'PATCH', `onlineRooms/${roomCode}`, hostUid, {
  start: { mode: 'singles', startedAt: 1 },
  'meta/status': 'inGame',
});
