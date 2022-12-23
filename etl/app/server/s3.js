import AWS from 'aws-sdk';
import axios from 'axios';
import { mkdirSync, writeFileSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import path, { resolve } from 'node:path';
import { setTimeout } from 'timers/promises';
import { getEnvironment } from './utilities/environment.js';
import { logger as log } from './utilities/logger.js';
import { fileURLToPath } from 'url';
import { endConnPool, startConnPool, updateEtlStatus } from './database.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const environment = getEnvironment();

// Loads etl config from private S3 bucket
export async function loadConfig() {
  // NOTE: static content files found in `etl/app/content-private/` directory
  const filenames = [
    'config.json',
    'services.json',
    'domainValueMappings.json',
  ];

  try {
    // setup private s3 bucket
    let s3;
    if (!environment.isLocal) {
      const config = new AWS.Config({
        accessKeyId: process.env.CF_S3_PRIV_ACCESS_KEY,
        secretAccessKey: process.env.CF_S3_PRIV_SECRET_KEY,
        region: process.env.CF_S3_PRIV_REGION,
      });
      AWS.config.update(config);

      s3 = new AWS.S3({ apiVersion: '2006-03-01' });
    }

    const promises = filenames.map((filename) => {
      // local development: read files directly from disk
      // Cloud.gov: fetch files from the public s3 bucket
      return environment.isLocal
        ? readFile(resolve(__dirname, '../content-private', filename), 'utf8')
        : s3
            .getObject({
              Bucket: process.env.CF_S3_PRIV_BUCKET_ID,
              Key: `content-private/${filename}`,
            })
            .promise();
    });

    const stringsOrResponses = await Promise.all(promises);

    // convert to json
    const parsedData = stringsOrResponses.map((stringOrResponse) =>
      environment.isLocal
        ? JSON.parse(stringOrResponse)
        : JSON.parse(stringOrResponse.Body.toString('utf-8')),
    );

    return {
      config: parsedData[0],
      services: parsedData[1],
      domainValueMappings: parsedData[2],
    };
  } catch (err) {
    log.warn('Error loading config from private S3 bucket');
  }
}

// Uploads file to public S3 bucket
export async function uploadFilePublic(
  filePath,
  fileToUpload,
  subFolder = 'content-etl',
) {
  try {
    // local development: write files directly to disk on the client app side
    // Cloud.gov: upload files to the public s3 bucket
    if (environment.isLocal) {
      const subFolderPath = resolve(
        __dirname,
        `../../../app/server/app/${subFolder}`,
      );

      // create the sub folder if it doesn't already exist
      mkdirSync(subFolderPath, { recursive: true });

      // write the file
      writeFileSync(`${subFolderPath}/${filePath}`, fileToUpload);
    } else {
      // setup public s3 bucket
      const config = new AWS.Config({
        accessKeyId: process.env.CF_S3_PUB_ACCESS_KEY,
        secretAccessKey: process.env.CF_S3_PUB_SECRET_KEY,
        region: process.env.CF_S3_PUB_REGION,
      });
      AWS.config.update(config);

      const s3 = new AWS.S3({ apiVersion: '2006-03-01' });

      // upload the file
      await s3
        .upload({
          Bucket: process.env.CF_S3_PUB_BUCKET_ID,
          Key: `${subFolder}/${filePath}`,
          ACL: 'public-read',
          ContentType: 'application/json',
          Body: fileToUpload,
        })
        .promise();
    }
  } catch (err) {
    log.warn(`Error saving "${filePath}" to public S3 bucket`);
  }
}

// Retries an HTTP request in response to a failure
async function retryRequest(serviceName, count, s3Config, callback) {
  log.info(`Non-200 response returned from ${serviceName} service, retrying`);
  if (count < s3Config.config.retryLimit) {
    await setTimeout(s3Config.config.retryIntervalSeconds * 1000);
    return callback(s3Config, count + 1);
  } else {
    throw new Error(`Sync ${serviceName} retry count exceeded`);
  }
}

// Sync the domain values corresponding to a single domain name
function fetchSingleDomain(name, mapping) {
  return async function (s3Config, retryCount = 0) {
    try {
      const res = await axios.get(
        `${s3Config.services.domainValues}?domainName=${mapping.domainName}`,
        { timeout: s3Config.config.webServiceTimeout },
      );

      if (res.status !== 200) {
        return await retryRequest(
          `Domain Values (${mapping.domainName})`,
          retryCount,
          s3Config,
          fetchSingleDomain(name, mapping),
        );
      }

      // Filter out specific values from the result
      let filteredData = res.data;
      if ('filters' in mapping) {
        mapping.filters.forEach(([field, filter]) => {
          filteredData = filteredData.filter((domainValue) => {
            if (Array.isArray(filter)) {
              return !filter.includes(domainValue[field]);
            } else {
              return filter !== domainValue[field];
            }
          });
        });
      }

      const valuesAdded = new Set();
      let values = filteredData
        .map((value) => {
          return {
            label: value[mapping.labelField ?? 'name'],
            value: value[mapping.valueField ?? 'code'],
            // Optional context field
            ...(mapping.contextField && {
              context: value[mapping.contextField],
            }),
          };
        })
        .filter((item) => {
          return valuesAdded.has(item.value)
            ? false
            : valuesAdded.add(item.value);
        });

      const output = {};
      output[name] = values;
      await uploadFilePublic(
        `${name}.json`,
        JSON.stringify(output),
        'content-etl/domainValues',
      );
    } catch (errOuter) {
      try {
        return await retryRequest(
          `Domain Values (${mapping.domainName})`,
          retryCount,
          s3Config,
          fetchSingleDomain(name, mapping),
        );
      } catch (err) {
        log.warn(`Sync Domain Values (${mapping.domainName}) failed! ${err}`);
        throw err;
      }
    }
  };
}

export async function syncDomainValues(s3Config) {
  const pool = startConnPool();
  await updateEtlStatus(pool, 'domain_values', 'running');

  try {
    const fetchPromises = [];
    fetchPromises.push(fetchStateValues(s3Config));

    Object.entries(s3Config.domainValueMappings).forEach(([name, mapping]) => {
      fetchPromises.push(fetchSingleDomain(name, mapping)(s3Config));
    });

    await Promise.all(fetchPromises);
    const filenames = [
      'state.json',
      ...Object.keys(s3Config.domainValueMappings).map(
        (domain) => `${domain}.json`,
      ),
    ];
    await uploadFilePublic(
      'index.json',
      JSON.stringify(filenames),
      'content-etl/domainValues',
    );

    await updateEtlStatus(pool, 'domain_values', 'success');
  } catch (err) {
    console.error(`Sync Domain Values failed! ${err}`);
    await updateEtlStatus(pool, 'domain_values', 'failed');
  } finally {
    endConnPool(pool);
  }
}

// Sync state codes and labels from the states service
async function fetchStateValues(s3Config, retryCount = 0) {
  try {
    const res = await axios.get(s3Config.services.stateCodes, {
      timeout: s3Config.config.webServiceTimeout,
    });

    if (res.status !== 200) {
      return await retryRequest(
        'States',
        retryCount,
        s3Config,
        fetchStateValues,
      );
    }

    const valuesAdded = new Set();
    const states = res.data.data
      .map((state) => {
        return {
          label: state.name,
          value: state.code,
        };
      })
      .filter((item) => {
        return valuesAdded.has(item.value)
          ? false
          : valuesAdded.add(item.value);
      });

    const output = {};
    output.state = states;
    await uploadFilePublic(
      'state.json',
      JSON.stringify(output),
      'content-etl/domainValues',
    );
  } catch (errOuter) {
    try {
      return await retryRequest(
        'States',
        retryCount,
        s3Config,
        fetchStateValues,
      );
    } catch (err) {
      log.warn(`Sync States failed! ${err}`);
    }
  }
}

export async function syncGlossary(s3Config, retryCount = 0) {
  const pool = startConnPool();
  await updateEtlStatus(pool, 'glossary', 'running');

  try {
    // query the glossary service
    const res = await axios.get(s3Config.services.glossaryURL, {
      headers: {
        authorization: `basic ${process.env.GLOSSARY_AUTH}`,
      },
      timeout: s3Config.config.webServiceTimeout,
    });

    // check response, retry on failure
    if (res.status !== 200) {
      return await retryRequest('Glossary', retryCount, s3Config, syncGlossary);
    }

    // build the glossary json output
    const terms = [];
    res.data.forEach((term) => {
      if (term.ActiveStatus === 'Deleted') return;

      let definition = '';
      let definitionHtml = '';
      term.Attributes.forEach((attr) => {
        if (attr.Name === 'Def1') definition = attr.Value;
        if (attr.Name === 'Editorial Note') definitionHtml = attr.Value;
      });

      terms.push({
        term: term.Name,
        definition,
        definitionHtml,
      });
    });

    // upload the glossary.json file
    await uploadFilePublic('glossary.json', JSON.stringify(terms));

    await updateEtlStatus(pool, 'glossary', 'success');
  } catch (errOuter) {
    try {
      return await retryRequest('Glossary', retryCount, s3Config, syncGlossary);
    } catch (err) {
      log.warn(`Sync Glossary failed! ${err}`);
      await updateEtlStatus(pool, 'glossary', 'failed');
    }
  } finally {
    endConnPool(pool);
  }
}
