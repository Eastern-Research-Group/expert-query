// Resilience lane: separate roots + plain node env; never runs in `npm test`.
export default {
  setupFiles: ['./jest_setup.js'],
  roots: ['tests/resilience'],
  testEnvironment: 'node',
  transform: {},
};
