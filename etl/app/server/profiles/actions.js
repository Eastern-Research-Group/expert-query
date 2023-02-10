import { extract as innerExtract } from './materializedViewsExtract.js';
import pgPromise from 'pg-promise';

const pgp = pgPromise({ capSQL: true });

/*
## Exports
*/

// Properties

export const tableName = 'actions';
const indexTableName = tableName.replaceAll('_', '');

export const createQuery = `CREATE TABLE IF NOT EXISTS ${tableName}
  (
    objectid INTEGER PRIMARY KEY,
    state VARCHAR(4000),
    region VARCHAR(2),
    organizationid VARCHAR(30) NOT NULL,
    organizationname VARCHAR(150) NOT NULL,
    organizationtype VARCHAR(30) NOT NULL,
    assessmentunitid VARCHAR(50) NOT NULL,
    assessmentunitname VARCHAR(255) NOT NULL,
    actionid VARCHAR(45) NOT NULL,
    actionname VARCHAR(255) NOT NULL,
    completiondate DATE,
    parameter VARCHAR(240) NOT NULL,
    locationdescription VARCHAR(2000) NOT NULL,
    actiontype VARCHAR(50) NOT NULL,
    watertype VARCHAR(40) NOT NULL,
    watersize NUMERIC(18,4) NOT NULL,
    watersizeunits VARCHAR(15) NOT NULL,
    actionagency VARCHAR(10) NOT NULL,
    inindiancountry VARCHAR(1),
    includeinmeasure VARCHAR(1)
  )`;

export const createIndexes = `
  CREATE INDEX IF NOT EXISTS ${indexTableName}_actionagency_asc
    ON ${tableName} USING btree
    (actionagency COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_actionid_asc
    ON ${tableName} USING btree
    (actionid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_actionname_asc
    ON ${tableName} USING btree
    (actionname COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_assessmentunitid_asc
    ON ${tableName} USING btree
    (assessmentunitid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_assessmentunitname_asc
    ON ${tableName} USING btree
    (assessmentunitname COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_completiondate_desc
    ON ${tableName} USING btree
    (completiondate DESC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_includeinmeasure_asc
    ON ${tableName} USING btree
    (includeinmeasure COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_inindiancountry_asc
    ON ${tableName} USING btree
    (inindiancountry COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_organizationid_asc
    ON ${tableName} USING btree
    (organizationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_organizationname_asc
    ON ${tableName} USING btree
    (organizationname COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_parameter_asc
    ON ${tableName} USING btree
    (parameter COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_region_asc
    ON ${tableName} USING btree
    (region COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_state_asc
    ON ${tableName} USING btree
    (state COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;

  CREATE INDEX IF NOT EXISTS ${indexTableName}_watertype_asc
    ON ${tableName} USING btree
    (watertype COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
  COMMIT;
`;

const insertColumns = new pgp.helpers.ColumnSet([
  { name: 'objectid' },
  { name: 'actionagency' },
  { name: 'actionid' },
  { name: 'actionname' },
  { name: 'actiontype' },
  { name: 'assessmentunitid' },
  { name: 'assessmentunitname' },
  { name: 'completiondate' },
  { name: 'includeinmeasure' },
  { name: 'inindiancountry' },
  { name: 'locationdescription' },
  { name: 'organizationid' },
  { name: 'organizationname' },
  { name: 'organizationtype' },
  { name: 'parameter' },
  { name: 'region' },
  { name: 'state' },
  { name: 'watersize' },
  { name: 'watersizeunits' },
  { name: 'watertype' },
]);

// Methods

export async function extract(s3Config, next = 0, retryCount = 0) {
  return await innerExtract('profile_actions', s3Config, next, retryCount);
}

export async function transform(data, first) {
  const rows = [];
  data.forEach((datum) => {
    rows.push({
      objectid: datum.objectid,
      actionagency: datum.actionagency,
      actionid: datum.actionid,
      actionname: datum.actionname,
      actiontype: datum.actiontype,
      assessmentunitid: datum.assessmentunitid,
      assessmentunitname: datum.assessmentunitname,
      completiondate: datum.completiondate,
      includeinmeasure: datum.includeinmeasure,
      inindiancountry: datum.inindiancountry,
      locationdescription: datum.locationdescription,
      organizationid: datum.organizationid,
      organizationname: datum.organizationname,
      organizationtype: datum.organizationtype,
      parameter: datum.parameter,
      region: datum.region,
      state: datum.state,
      watersize: datum.watersize,
      watersizeunits: datum.watersizeunits,
      watertype: datum.watertype,
    });
  });
  return pgp.helpers.insert(rows, insertColumns, tableName);
}