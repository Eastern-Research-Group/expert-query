// Exercises streaming clients that stop reading mid-download and never close the
// socket (zero-window half-open: no FIN, no RST). Such a client pins the pooled
// DB client feeding its response, so STREAM_IDLE_TIMEOUT must reap it. Unset that
// on the server to watch this fail -- the held connections are never reclaimed.
//
// The stall is a raw TCP socket that sends the request and then never reads the
// response: its receive window fills, the server blocks mid-write, and the cursor
// stays suspended holding a pooled client. No proxy or container needed -- an
// unread socket is the whole mechanism.
import net from 'node:net';

const SERVER_URL = process.env.SERVER_URL ?? 'http://localhost:3001';
const { hostname: HOST, port: URL_PORT } = new URL(SERVER_URL);
const PORT = Number(URL_PORT) || 80;
const POOL_MAX = Number.parseInt(process.env.DB_POOL_MAX, 10) || 10;
const IDLE = Number.parseInt(process.env.STREAM_IDLE_TIMEOUT, 10) || 10000;

// One state * all columns is tens of MB -- far past the socket buffers, so a
// client that never reads blocks the server mid-stream and the cursor stays
// suspended holding its pooled client. (Only the first few MB are ever sent; the
// rest waits behind the stalled window.) A response small enough to fit those
// buffers would drain, finish, and release the client before the stall mattered.
const stallBody = JSON.stringify({
  filters: { state: ['AZ', 'OH', 'CA'] },
  options: { format: 'csv' },
  columns: [
    'objectId',
    'region',
    'state',
    'organizationType',
    'organizationId',
    'organizationName',
    'waterType',
    'reportingCycle',
    'cycleLastAssessed',
    'cycleStatus',
    'assessmentUnitId',
    'assessmentUnitName',
    'assessmentUnitStatus',
    'overallStatus',
    'epaIrCategory',
    'stateIrCategory',
    'useGroup',
    'useName',
    'useClassName',
    'useSupport',
    'useIrCategory',
    'useStateIrCategory',
    'monitoringStartDate',
    'monitoringEndDate',
    'assessmentDate',
    'assessmentTypes',
    'assessmentMethods',
    'assessmentBasis',
    'assessmentParameterAgency',
    'assessmentUseAgency',
    'parameterGroup',
    'parameterName',
    'parameterStatus',
    'parameterAttainment',
    'parameterIrCategory',
    'parameterStateIrCategory',
    'delisted',
    'delistedReason',
    'pollutantIndicator',
    'cycleFirstListed',
    'alternateListingIdentifier',
    'vision303dPriority',
    'cwa303dPriorityRanking',
    'cycleScheduledForTmdl',
    'cycleExpectedToAttain',
    'consentDecreeCycle',
    'cycleId',
    'seasonStartDate',
    'seasonEndDate',
    'associatedActionId',
    'associatedActionName',
    'associatedActionType',
    'associatedActionStatus',
    'associatedActionAgency',
    'locationDescription',
    'sizeSource',
    'sourceScale',
    'waterSize',
    'waterSizeUnits',
  ],
});

const stallRequest =
  'POST /api/attains/assessments HTTP/1.1\r\n' +
  `Host: ${HOST}:${PORT}\r\n` +
  'Content-Type: application/json\r\n' +
  `Content-Length: ${Buffer.byteLength(stallBody)}\r\n` +
  '\r\n' +
  stallBody;

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// a cheap, pool-backed request; blocks (and so returns false) while the pool is
// exhausted, succeeds once a client is freed
async function poolQuerySucceeds(timeoutMs) {
  try {
    const res = await fetch(
      `${SERVER_URL}/api/attains/sources/count?confirmed=Y&format=tsv`,
      { signal: AbortSignal.timeout(timeoutMs) },
    );
    return res.status === 200;
  } catch {
    return false;
  }
}

const stalls = [];

// open a connection, send the request, and never read the response: the unread
// socket backs up, the server blocks writing, and its pooled client stays held
// until STREAM_IDLE_TIMEOUT reaps the response.
function startStall() {
  const socket = net.connect(PORT, HOST, () => socket.write(stallRequest));
  socket.on('error', () => {}); // ignore the reset when the server reaps us
  stalls.push(socket);
}

beforeAll(async () => {
  if (!(await poolQuerySucceeds(5000))) {
    throw new Error(
      `App not reachable at ${SERVER_URL}. Start the server first.`,
    );
  }
});

afterAll(() => {
  for (const socket of stalls) socket.destroy();
});

test(
  'STREAM_IDLE_TIMEOUT reaps stalled streaming connections and frees the pool',
  async () => {
    // exhaust the pool with POOL_MAX half-open streaming downloads
    for (let i = 0; i < POOL_MAX; i++) startStall();
    await delay(5000); // let them reach createStream and hold a pooled client

    // precondition: the pool is exhausted, so a normal query can't proceed
    expect(await poolQuerySucceeds(4000)).toBe(false);

    // wait past the idle timeout for the fix to reap the stalls
    await delay(IDLE + 5000);

    // the pool recovered -> a normal query succeeds. WITHOUT the fix
    // (STREAM_IDLE_TIMEOUT unset/0 on the server) it stays exhausted and this
    // fails -- which is how you confirm the test reproduces the leak.
    expect(await poolQuerySucceeds(15000)).toBe(true);
  },
  IDLE + 60000,
);
