// Shared setup for the resilience tests: a raw unread-socket stall and a cheap
// pool-backed probe, both driving the local server over plain TCP/HTTP.
import net from 'node:net';

// These tests drive the app directly, never BrowserSync or any
// other proxy, so they don't read SERVER_URL.
const PORT = Number(process.env.PORT) || 3001;
const HOST = 'localhost';
const BASE_URL = `http://${HOST}:${PORT}`;
export { HOST, PORT, BASE_URL };
export const POOL_MAX = Number.parseInt(process.env.DB_POOL_MAX, 10) || 10;
export const IDLE =
  Number.parseInt(process.env.STREAM_IDLE_TIMEOUT, 10) || 10000;

export const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Three states * all columns is tens of MB, far past the socket buffers, so a
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

// A cheap, pool-backed request; blocks (and so returns false) while the pool is
// exhausted, succeeds once a client is freed
export async function poolQuerySucceeds(timeoutMs) {
  try {
    const res = await fetch(
      `${BASE_URL}/api/attains/sources/count?confirmed=Y&format=tsv`,
      { signal: AbortSignal.timeout(timeoutMs) },
    );
    return res.status === 200;
  } catch {
    return false;
  }
}

// Open a connection, send the request, and never read the response: the unread
// socket backs up, the server blocks writing, and its pooled client stays held.
// Returns the socket so the caller can tear it down (destroy, or resetAndDestroy
// for an abrupt RST).
export function startStall() {
  const socket = net.connect(PORT, HOST, () => socket.write(stallRequest));
  socket.on('error', () => {}); // Ignore the reset when the server tears us down
  return socket;
}
