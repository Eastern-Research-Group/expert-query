import log4js from 'log4js';

log4js.configure({
  appenders: {
    stdout: { type: 'stdout', layout: { type: 'messagePassThrough' } },
    stdoutFilter: {
      type: 'logLevelFilter',
      appender: 'stdout',
      level: 'TRACE',
      maxLevel: 'WARN',
    },
    stderr: { type: 'stderr', layout: { type: 'messagePassThrough' } },
    stderrFilter: {
      type: 'logLevelFilter',
      appender: 'stderr',
      level: 'ERROR',
      maxLevel: 'FATAL',
    },
  },
  categories: {
    default: { appenders: ['stderrFilter', 'stdoutFilter'], level: 'all' },
  },
});

export const logger = log4js.getLogger();

if (process.env.LOGGER_LEVEL)
  logger.level = process.env.LOGGER_LEVEL.toUpperCase();
else logger.level = 'INFO'; //default level

logger.info('LOGGER_LEVEL = ' + logger.level);