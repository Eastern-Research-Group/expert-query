// A streaming client that stops reading mid-download and never closes the socket
// (zero-window half-open: no FIN, no RST) pins the pooled DB client feeding its
// response. Nothing at the socket level ever fires, so STREAM_IDLE_TIMEOUT is the
// only thing that can reap it. Unset that on the server to watch this fail; the
// held connections are never reclaimed.
import {
  BASE_URL,
  IDLE,
  POOL_MAX,
  delay,
  poolQuerySucceeds,
  startStall,
} from './support.js';

const stalls = [];

beforeAll(async () => {
  if (!(await poolQuerySucceeds(5000))) {
    throw new Error(
      `App not reachable at ${BASE_URL}. Start the server first.`,
    );
  }
});

afterAll(() => {
  for (const socket of stalls) socket.destroy();
});

test(
  'STREAM_IDLE_TIMEOUT reaps stalled streaming connections and frees the pool',
  async () => {
    // Exhaust the pool with POOL_MAX half-open streaming downloads
    for (let i = 0; i < POOL_MAX; i++) stalls.push(startStall());
    await delay(5000); // Let them reach createStream and hold a pooled client

    // Precondition: the pool is exhausted, so a normal query can't proceed
    expect(await poolQuerySucceeds(4000)).toBe(false);

    // Wait past the idle timeout for the fix to reap the stalls
    await delay(IDLE + 5000);

    // The pool recovered, so a normal query succeeds. Without the fix
    // (STREAM_IDLE_TIMEOUT unset or 0 on the server) it stays exhausted and this
    // fails, which is how you confirm the test reproduces the leak.
    expect(await poolQuerySucceeds(15000)).toBe(true);
  },
  IDLE + 60000,
);
