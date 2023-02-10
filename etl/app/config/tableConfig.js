// IMPORTANT - Copy any changes to the "app/server/app/config/tableConfig.js" file
export const tableConfig = {
  actions: {
    tableName: 'actions',
    idColumn: 'objectid',
    columns: [
      { name: 'objectid', alias: 'objectId', skipIndex: true },
      { name: 'actionagency', alias: 'actionAgency' },
      { name: 'actionid', alias: 'actionId' },
      { name: 'actionname', alias: 'actionName' },
      { name: 'actiontype', alias: 'actionType', skipIndex: true },
      { name: 'assessmentunitid', alias: 'assessmentUnitId' },
      { name: 'assessmentunitname', alias: 'assessmentUnitName' },
      {
        name: 'completiondate',
        alias: 'completionDate',
        lowParam: 'completionDateLo',
        highParam: 'completionDateHi',
        type: 'timestamptz',
        indexOrder: 'desc',
      },
      { name: 'includeinmeasure', alias: 'includeInMeasure' },
      { name: 'inindiancountry', alias: 'inIndianCountry' },
      {
        name: 'locationdescription',
        alias: 'locationDescription',
        skipIndex: true,
      },
      { name: 'organizationid', alias: 'organizationId' },
      { name: 'organizationname', alias: 'organizationName' },
      { name: 'organizationtype', alias: 'organizationType', skipIndex: true },
      { name: 'parameter', alias: 'parameter' },
      { name: 'region', alias: 'region' },
      { name: 'state', alias: 'state' },
      {
        name: 'watersize',
        alias: 'waterSize',
        type: 'numeric',
        skipIndex: true,
      },
      { name: 'watersizeunits', alias: 'waterSizeUnits', skipIndex: true },
      { name: 'watertype', alias: 'waterType' },
    ],
  },
  assessments: {
    tableName: 'assessments',
    idColumn: 'objectid',
    columns: [
      { name: 'objectid', alias: 'objectId', skipIndex: true },
      {
        name: 'alternatelistingidentifier',
        alias: 'alternateListingIdentifier',
      },
      { name: 'assessmentbasis', alias: 'assessmentBasis' },
      {
        name: 'assessmentdate',
        alias: 'assessmentDate',
        lowParam: 'assessmentDateLo',
        highParam: 'assessmentDateHi',
        type: 'timestamptz',
        indexOrder: 'desc',
      },
      { name: 'assessmentmethods', alias: 'assessmentMethods' },
      { name: 'assessmenttypes', alias: 'assessmentTypes' },
      { name: 'assessmentunitid', alias: 'assessmentUnitId' },
      { name: 'assessmentunitname', alias: 'assessmentUnitName' },
      { name: 'assessmentunitstatus', alias: 'assessmentUnitStatus' },
      { name: 'associatedactionagency', alias: 'associatedActionAgency' },
      { name: 'associatedactionid', alias: 'associatedActionId' },
      { name: 'associatedactionname', alias: 'associatedActionName' },
      { name: 'associatedactionstatus', alias: 'associatedActionStatus' },
      {
        name: 'associatedactiontype',
        alias: 'associatedActionType',
        type: 'numeric',
      },
      {
        name: 'consentdecreecycle',
        alias: 'consentDecreeCycle',
        lowParam: 'consentDecreeCycleLo',
        highParam: 'consentDecreeCycleHi',
        type: 'numeric',
        indexOrder: 'desc',
      },
      { name: 'cwa303dpriorityranking', alias: 'cwa303dPriorityRanking' },
      {
        name: 'cycleexpectedtoattain',
        alias: 'cycleExpectedToAttain',
        lowParam: 'cycleExpectedToAttainLo',
        highParam: 'cycleExpectedToAttainHi',
        type: 'numeric',
        indexOrder: 'desc',
      },
      {
        name: 'cyclefirstlisted',
        alias: 'cycleFirstListed',
        lowParam: 'cycleFirstListedLo',
        highParam: 'cycleFirstListedHi',
        type: 'numeric',
        indexOrder: 'desc',
      },
      {
        name: 'cyclelastassessed',
        alias: 'cycleLastAssessed',
        lowParam: 'cycleLastAssessedLo',
        highParam: 'cycleLastAssessedHi',
        type: 'numeric',
        indexOrder: 'desc',
      },
      {
        name: 'cyclescheduledfortmdl',
        alias: 'cycleScheduledForTmdl',
        lowParam: 'cycleScheduledForTmdlLo',
        highParam: 'cycleScheduledForTmdlHi',
        type: 'numeric',
        indexOrder: 'desc',
      },
      { name: 'delisted', alias: 'delisted' },
      { name: 'delistedreason', alias: 'delistedReason' },
      { name: 'epaircategory', alias: 'epaIrCategory' },
      {
        name: 'locationdescription',
        alias: 'locationDescription',
        skipIndex: true,
      },
      {
        name: 'monitoringenddate',
        alias: 'monitoringEndDate',
        lowParam: 'monitoringEndDateLo',
        highParam: 'monitoringEndDateHi',
        type: 'timestamptz',
        indexOrder: 'desc',
      },
      {
        name: 'monitoringstartdate',
        alias: 'monitoringStartDate',
        lowParam: 'monitoringStartDateLo',
        highParam: 'monitoringStartDateHi',
        type: 'timestamptz',
        indexOrder: 'desc',
      },
      { name: 'organizationid', alias: 'organizationId' },
      { name: 'organizationname', alias: 'organizationName' },
      { name: 'organizationtype', alias: 'organizationType', skipIndex: true },
      { name: 'overallstatus', alias: 'overallStatus' },
      { name: 'parameterattainment', alias: 'parameterAttainment' },
      { name: 'parametergroup', alias: 'parameterGroup' },
      {
        name: 'parameterircategory',
        alias: 'parameterIrCategory',
        type: 'numeric',
      },
      { name: 'parametername', alias: 'parameterName' },
      {
        name: 'parameterstateircategory',
        alias: 'parameterStateIrCategory',
        type: 'numeric',
      },
      { name: 'parameterstatus', alias: 'parameterStatus' },
      { name: 'pollutantindicator', alias: 'pollutantIndicator' },
      { name: 'region', alias: 'region' },
      {
        name: 'reportingcycle',
        alias: 'reportingCycle',
        default: 'latest',
        type: 'numeric',
        indexOrder: 'desc',
      },
      {
        name: 'seasonenddate',
        alias: 'seasonEndDate',
        lowParam: 'seasonEndDateLo',
        highParam: 'seasonEndDateHi',
        type: 'timestamptz',
        indexOrder: 'desc',
      },
      {
        name: 'seasonstartdate',
        alias: 'seasonStartDate',
        lowParam: 'seasonStartDateLo',
        highParam: 'seasonStartDateHi',
        type: 'timestamptz',
        indexOrder: 'desc',
      },
      { name: 'sizesource', alias: 'sizeSource', skipIndex: true },
      { name: 'sourcescale', alias: 'sourceScale', skipIndex: true },
      { name: 'state', alias: 'state' },
      { name: 'stateircategory', alias: 'stateIrCategory' },
      { name: 'useclassname', alias: 'useClassName' },
      { name: 'usegroup', alias: 'useGroup' },
      { name: 'useircategory', alias: 'useIrCategory', type: 'numeric' },
      { name: 'usename', alias: 'useName' },
      {
        name: 'usestateircategory',
        alias: 'useStateIrCategory',
        type: 'numeric',
      },
      { name: 'usesupport', alias: 'useSupport' },
      { name: 'vision303dpriority', alias: 'vision303dPriority' },
      {
        name: 'watersize',
        alias: 'waterSize',
        type: 'numeric',
        skipIndex: true,
      },
      { name: 'watersizeunits', alias: 'waterSizeUnits', skipIndex: true },
      { name: 'watertype', alias: 'waterType' },
    ],
  },
  assessmentUnits: {
    tableName: 'assessment_units',
    idColumn: 'objectid',
    columns: [
      { name: 'objectid', alias: 'objectid', skipIndex: true },
      { name: 'assessmentunitid', alias: 'assessmentUnitId' },
      { name: 'assessmentunitname', alias: 'assessmentUnitName' },
      { name: 'assessmentunitstatus', alias: 'assessmentUnitStatus' },
      {
        name: 'locationdescription',
        alias: 'locationDescription',
        skipIndex: true,
      },
      { name: 'locationtext', alias: 'locationText' },
      { name: 'locationtypecode', alias: 'locationTypeCode', skipIndex: true },
      { name: 'organizationid', alias: 'organizationId' },
      { name: 'organizationname', alias: 'organizationName' },
      { name: 'organizationtype', alias: 'organizationType', skipIndex: true },
      { name: 'region', alias: 'region' },
      {
        name: 'reportingcycle',
        alias: 'reportingCycle',
        default: 'latest',
        type: 'numeric',
        indexOrder: 'desc',
      },
      { name: 'sizesource', alias: 'sizeSource', skipIndex: true },
      { name: 'sourcescale', alias: 'sourceScale', skipIndex: true },
      { name: 'state', alias: 'state' },
      { name: 'useclassname', alias: 'useClassName' },
      {
        name: 'watersize',
        alias: 'waterSize',
        type: 'numeric',
        skipIndex: true,
      },
      { name: 'watersizeunits', alias: 'waterSizeUnits', skipIndex: true },
      { name: 'watertype', alias: 'waterType' },
    ],
  },
  assessmentUnitsMonitoringLocations: {
    tableName: 'assessment_units_monitoring_locations',
    idColumn: 'objectid',
    columns: [
      { name: 'objectid', alias: 'objectId', skipIndex: true },
      { name: 'assessmentunitid', alias: 'assessmentUnitId' },
      { name: 'assessmentunitname', alias: 'assessmentUnitName' },
      { name: 'assessmentunitstatus', alias: 'assessmentUnitStatus' },
      {
        name: 'locationdescription',
        alias: 'locationDescription',
        skipIndex: true,
      },
      {
        name: 'monitoringlocationdatalink',
        alias: 'monitoringLocationDataLink',
        skipIndex: true,
      },
      { name: 'monitoringlocationid', alias: 'monitoringLocationId' },
      { name: 'monitoringlocationorgid', alias: 'monitoringLocationOrgId' },
      { name: 'organizationid', alias: 'organizationId' },
      { name: 'organizationname', alias: 'organizationName' },
      { name: 'organizationtype', alias: 'organizationType', skipIndex: true },
      { name: 'region', alias: 'region' },
      {
        name: 'reportingcycle',
        alias: 'reportingCycle',
        default: 'latest',
        type: 'numeric',
        indexOrder: 'desc',
      },
      { name: 'sizesource', alias: 'sizeSource', skipIndex: true },
      { name: 'sourcescale', alias: 'sourceScale', skipIndex: true },
      { name: 'state', alias: 'state' },
      { name: 'useclassname', alias: 'useClassName' },
      {
        name: 'watersize',
        alias: 'waterSize',
        type: 'numeric',
        skipIndex: true,
      },
      { name: 'watersizeunits', alias: 'waterSizeUnits', skipIndex: true },
      { name: 'watertype', alias: 'waterType' },
    ],
  },
  catchmentCorrespondence: {
    tableName: 'catchment_correspondence',
    idColumn: 'objectid',
    columns: [
      { name: 'objectid', alias: 'objectId', skipIndex: true },
      { name: 'assessmentunitid', alias: 'assessmentUnitId' },
      { name: 'assessmentunitname', alias: 'assessmentUnitName' },
      {
        name: 'catchmentnhdplusid',
        alias: 'catchmentNhdPlusId',
        type: 'numeric',
      },
      { name: 'organizationid', alias: 'organizationId' },
      { name: 'organizationname', alias: 'organizationName' },
      { name: 'organizationtype', alias: 'organizationType', skipIndex: true },
      { name: 'region', alias: 'region' },
      {
        name: 'reportingcycle',
        alias: 'reportingCycle',
        default: 'latest',
        type: 'numeric',
        indexOrder: 'desc',
      },
      { name: 'state', alias: 'state' },
    ],
  },
  sources: {
    tableName: 'sources',
    idColumn: 'objectid',
    columns: [
      { name: 'objectid', alias: 'objectId', skipIndex: true },
      { name: 'assessmentunitid', alias: 'assessmentUnitId' },
      { name: 'assessmentunitname', alias: 'assessmentUnitName' },
      { name: 'causename', alias: 'causeName' },
      { name: 'confirmed', alias: 'confirmed' },
      { name: 'epaircategory', alias: 'epaIrCategory' },
      {
        name: 'locationdescription',
        alias: 'locationDescription',
        skipIndex: true,
      },
      { name: 'organizationid', alias: 'organizationId' },
      { name: 'organizationname', alias: 'organizationName' },
      { name: 'organizationtype', alias: 'organizationType', skipIndex: true },
      { name: 'overallstatus', alias: 'overallStatus' },
      { name: 'parametergroup', alias: 'parameterGroup' },
      { name: 'region', alias: 'region' },
      {
        name: 'reportingcycle',
        alias: 'reportingCycle',
        default: 'latest',
        type: 'numeric',
        indexOrder: 'desc',
      },
      { name: 'sourcename', alias: 'sourceName' },
      { name: 'state', alias: 'state' },
      { name: 'stateircategory', alias: 'stateIrCategory' },
      {
        name: 'watersize',
        alias: 'waterSize',
        type: 'numeric',
        skipIndex: true,
      },
      { name: 'watersizeunits', alias: 'waterSizeUnits', skipIndex: true },
      { name: 'watertype', alias: 'waterType' },
    ],
  },
  tmdl: {
    tableName: 'tmdl',
    idColumn: 'objectid',
    columns: [
      { name: 'objectid', alias: 'objectId', skipIndex: true },
      { name: 'actionagency', alias: 'actionAgency' },
      { name: 'actionid', alias: 'actionId' },
      { name: 'actionname', alias: 'actionName' },
      { name: 'addressedparameter', alias: 'addressedParameter' },
      { name: 'assessmentunitid', alias: 'assessmentUnitId' },
      { name: 'assessmentunitname', alias: 'assessmentUnitName' },
      {
        name: 'completiondate',
        alias: 'completionDate',
        lowParam: 'completionDateLo',
        highParam: 'completionDateHi',
        type: 'timestamptz',
        indexOrder: 'desc',
      },
      { name: 'explicitmarginofsafety', alias: 'explicitMarginOfSafety' },
      {
        name: 'fiscalyearestablished',
        alias: 'fiscalYearEstablished',
        lowParam: 'fiscalYearEstablishedLo',
        highParam: 'fiscalYearEstablishedHi',
        indexOrder: 'desc',
      },
      { name: 'implicitmarginofsafety', alias: 'implicitMarginOfSafety' },
      { name: 'includeinmeasure', alias: 'includeInMeasure' },
      { name: 'inindiancountry', alias: 'inIndianCountry' },
      {
        name: 'loadallocation',
        alias: 'loadAllocation',
        type: 'numeric',
        skipIndex: true,
      },
      {
        name: 'loadallocationunits',
        alias: 'loadAllocationUnits',
        skipIndex: true,
      },
      {
        name: 'locationdescription',
        alias: 'locationDescription',
        skipIndex: true,
      },
      { name: 'npdesidentifier', alias: 'npdesIdentifier' },
      { name: 'organizationid', alias: 'organizationId' },
      { name: 'organizationname', alias: 'organizationName' },
      { name: 'organizationtype', alias: 'organizationType', skipIndex: true },
      { name: 'otheridentifier', alias: 'otherIdentifier' },
      { name: 'pollutant', alias: 'pollutant' },
      { name: 'region', alias: 'region' },
      {
        name: 'reportingcycle',
        alias: 'reportingCycle',
        default: 'latest',
        type: 'numeric',
        indexOrder: 'desc',
      },
      { name: 'sourcetype', alias: 'sourceType' },
      { name: 'state', alias: 'state' },
      {
        name: 'tmdldate',
        alias: 'tmdlDate',
        lowParam: 'tmdlDateLo',
        highParam: 'tmdlDateHi',
        type: 'timestamptz',
        indexOrder: 'desc',
      },
      {
        name: 'wasteloadallocation',
        alias: 'wasteLoadAllocation',
        type: 'numeric',
        skipIndex: true,
      },
      {
        name: 'watersize',
        alias: 'waterSize',
        type: 'numeric',
        skipIndex: true,
      },
      { name: 'watersizeunits', alias: 'waterSizeUnits', skipIndex: true },
      { name: 'watertype', alias: 'waterType' },
    ],
  },
};