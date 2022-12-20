CREATE OR REPLACE PROCEDURE attains_eq.profile_tmdl(
    p_offset                  IN  VARCHAR2 DEFAULT NULL
   ,p_limit                   IN  VARCHAR2 DEFAULT NULL
   ,f                         IN  VARCHAR2 DEFAULT NULL
   ,api_key                   IN  VARCHAR2 DEFAULT NULL
)
AUTHID CURRENT_USER
AS
   boo_mute                       BOOLEAN := FALSE;
   
   int_offset                     PLS_INTEGER;
   int_limit                      PLS_INTEGER;
   boo_comma                      BOOLEAN;
   str_slug                       VARCHAR2(4000 Char);
   
BEGIN

   -----------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   -----------------------------------------------------------------------------
   int_offset := util.str2integer(p_offset);
   int_limit  := util.str2integer(p_limit);

   IF  int_offset IS NOT NULL
   AND int_limit IS NOT NULL
   THEN
      int_limit := int_offset + int_limit;
      
   ELSE
      IF int_limit IS NULL
      THEN
         int_limit := 10000;
         
      END IF;
      
      IF int_offset IS NULL
      THEN
         int_offset := 0;

      END IF;
   
   END IF;
   
   IF f = 'MUTE'
   THEN
      boo_mute := TRUE;
      
   END IF;
   
   -----------------------------------------------------------------------------
   -- Step 20
   -- Do the header verification check
   -----------------------------------------------------------------------------
   IF NOT attains_eq.header_check()
   THEN
      OWA_UTIL.MIME_HEADER('test/html',FALSE);
      OWA_UTIL.STATUS_LINE(401,'Unauthorized',FALSE);
      OWA_UTIL.HTTP_HEADER_CLOSE;
      RETURN;
      
   END IF;
   
   -----------------------------------------------------------------------------
   -- Step 30
   -- Write the header
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      OWA_UTIL.MIME_HEADER('application/json',FALSE);
      OWA_UTIL.HTTP_HEADER_CLOSE;
      
   END IF;
   
   -----------------------------------------------------------------------------
   -- Step 40
   -- Generate the header and start the output
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      HTP.PRN('{"name":"profile_tmdl","records":[');
      
   END IF;

   -----------------------------------------------------------------------------
   -- Step 50
   -- Loop through the records
   -----------------------------------------------------------------------------
   boo_comma := FALSE;
   
   FOR json_rec IN ( 
      SELECT /*+ INDEX(PROFILE_TMDL_UX1) NO_PARALLEL(a) */ 
      JSON_OBJECT(
          KEY 'objectid'                    VALUE CAST(a.row_id AS INTEGER)
         ,KEY 'state'                       VALUE a.state
         ,KEY 'region'                      VALUE a.region
         ,KEY 'organizationid'              VALUE a.organizationid
         ,KEY 'organizationname'            VALUE a.organizationname
         ,KEY 'organizationtype'            VALUE a.organizationtype
         ,KEY 'reportingcycle'              VALUE a.reportingcycle
         ,KEY 'assessmentunitid'            VALUE a.assessmentunitid
         ,KEY 'assessmentunitname'          VALUE a.assessmentunitname
         ,KEY 'actionid'                    VALUE a.actionid 
         ,KEY 'actionname'                  VALUE a.actionname
         ,KEY 'completiondate'              VALUE a.completiondate
         ,KEY 'tmdldate'                    VALUE a.tmdldate
         ,KEY 'fiscalyearestablished'       VALUE a.fiscalyearestablished
         ,KEY 'pollutant'                   VALUE a.pollutant
         ,KEY 'sourcetype'                  VALUE a.sourcetype
         ,KEY 'addressedparameter'          VALUE a.addressedparameter
         ,KEY 'locationdescription'         VALUE a.locationdescription
         ,KEY 'watertype'                   VALUE a.watertype
         ,KEY 'watersize'                   VALUE a.watersize
         ,KEY 'watersizeunits'              VALUE a.watersizeunits
         ,KEY 'actionagency'                VALUE a.actionagency
         ,KEY 'loadallocation'              VALUE a.loadallocation
         ,KEY 'loadallocationunits'         VALUE a.loadallocationunits
         ,KEY 'explicitmarginofsafety'      VALUE a.explicitmarginofsafety
         ,KEY 'implicitmarginofsafety'      VALUE a.implicitmarginofsafety
         ,KEY 'tmdlendpoint'                VALUE a.tmdlendpoint
         ,KEY 'npdesidentifier'             VALUE a.npdesidentifier
         ,KEY 'otheridentifier'             VALUE a.otheridentifier
         ,KEY 'wasteloadallocation'         VALUE a.wasteloadallocation
         ,KEY 'inindiancountry'             VALUE a.inindiancountry
         ,KEY 'includeinmeasure'            VALUE a.includeinmeasure
      ) AS jout
      FROM
      attains_app.profile_tmdl a
      WHERE
          a.row_id >  int_offset
      AND a.row_id <= int_limit
   )
   LOOP
      
      IF boo_comma
      THEN
         IF NOT boo_mute
         THEN
            HTP.PRN(',');
         
         END IF;

      ELSE
         boo_comma := TRUE;
         
      END IF;

      attains_eq.util.clob2htp(
          p_input => json_rec.jout
         ,p_mute  => boo_mute
      );
      
   END LOOP;
      
   -----------------------------------------------------------------------------
   -- Step 60
   -- Close the response
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      HTP.PRN(']');
      
      IF int_offset IS NULL
      THEN
         str_slug := 'null';
         
      ELSE
         str_slug := TO_CHAR(int_offset);
         
      END IF;
      HTP.PRN(',"offset":' || str_slug);
      
      IF int_limit IS NULL
      THEN
         str_slug := 'null';
         
      ELSE
         str_slug := TO_CHAR(int_limit);
         
      END IF;
      HTP.PRN(',"limit":' || str_slug); 

      HTP.PRN('}');
   
   END IF;
   
END profile_tmdl;
/

GRANT EXECUTE ON attains_eq.profile_tmdl TO attains_eq_rest;

