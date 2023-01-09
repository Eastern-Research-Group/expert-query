CREATE OR REPLACE PROCEDURE attains_eq.profile_assessment_units(
    p_state                   IN  VARCHAR2 DEFAULT NULL
   ,p_organizationid          IN  VARCHAR2 DEFAULT NULL
   ,p_reportingcycle          IN  VARCHAR2 DEFAULT NULL
   ,p_offset                  IN  VARCHAR2 DEFAULT NULL
   ,p_limit                   IN  VARCHAR2 DEFAULT NULL
   ,f                         IN  VARCHAR2 DEFAULT NULL
   ,api_key                   IN  VARCHAR2 DEFAULT NULL
)
AUTHID CURRENT_USER
AS
   boo_mute                       BOOLEAN := FALSE;
   ary_states                     attains_eq.string_array;
   ary_orgids                     attains_eq.string_array;
   ary_cycles                     attains_eq.integer_array;
   int_offset                     PLS_INTEGER;
   int_limit                      PLS_INTEGER;
   boo_comma                      BOOLEAN;
   str_slug                       VARCHAR2(4000 Char);
   
BEGIN

   -----------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   -----------------------------------------------------------------------------
   IF p_state IS NOT NULL
   THEN
      ary_states := util.str2arystr(p_state);
      
   END IF;
   
   IF p_organizationid IS NOT NULL
   THEN
      ary_orgids := util.str2arystr(p_organizationid);
      
   END IF;
   
   IF p_reportingcycle IS NOT NULL
   THEN
      ary_cycles := util.str2aryint(p_reportingcycle);
      
   END IF;
   
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
   -- Prepare for the loop
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      HTP.PRN('{"name":"profile_assessment_units","records":[');
      
   END IF;

   -----------------------------------------------------------------------------
   -- Step 50
   -- Loop through the records
   -----------------------------------------------------------------------------
   boo_comma := FALSE;
   
   IF ary_states IS NOT NULL
   OR ary_orgids IS NOT NULL
   OR ary_cycles IS NOT NULL
   THEN
      FOR json_rec IN ( 
         SELECT 
         JSON_OBJECT(
             KEY 'objectid'                    VALUE a.objectid
            ,KEY 'state'                       VALUE a.state
            ,KEY 'region'                      VALUE a.region
            ,KEY 'organizationid'              VALUE a.organizationid
            ,KEY 'organizationname'            VALUE a.organizationname
            ,KEY 'organizationtype'            VALUE a.organizationtype
            ,KEY 'reportingcycle'              VALUE a.reportingcycle
            ,KEY 'assessmentunitid'            VALUE a.assessmentunitid
            ,KEY 'assessmentunitname'          VALUE a.assessmentunitname
            ,KEY 'locationdescription'         VALUE a.locationdescription
            ,KEY 'watertype'                   VALUE a.watertype
            ,KEY 'watersize'                   VALUE a.watersize
            ,KEY 'watersizeunits'              VALUE a.watersizeunits
            ,KEY 'assessmentunitstate'         VALUE a.assessmentunitstatus
            ,KEY 'useclassname'                VALUE a.useclassname
            ,KEY 'sizesource'                  VALUE a.sizesource
            ,KEY 'sourcescale'                 VALUE a.sourcescale
            ,KEY 'locationtypecode'            VALUE a.locationtypecode
            ,KEY 'locationtext'                VALUE a.locationtext
         ) AS jout
         FROM (
            SELECT
             CAST(rownum AS INTEGER) AS objectid
            ,aa.state
            ,aa.region
            ,aa.organizationid
            ,aa.organizationname
            ,aa.organizationtype
            ,aa.reportingcycle
            ,aa.assessmentunitid
            ,aa.assessmentunitname
            ,aa.locationdescription
            ,aa.watertype
            ,aa.watersize
            ,aa.watersizeunits
            ,aa.assessmentunitstatus
            ,aa.useclassname
            ,aa.sizesource
            ,aa.sourcescale
            ,aa.locationtypecode
            ,aa.locationtext
            FROM
            attains_app.profile_assessment_units aa
            WHERE
                ( ary_states IS NULL OR aa.state          IN (SELECT column_value FROM TABLE(ary_states)) )
            AND ( ary_orgids IS NULL OR aa.organizationid IN (SELECT column_value FROM TABLE(ary_orgids)) )
            AND ( ary_cycles IS NULL OR aa.reportingcycle IN (SELECT column_value FROM TABLE(ary_cycles)) )
            ORDER BY
            aa.row_id
            OFFSET int_offset ROWS FETCH NEXT int_limit ROWS ONLY
         ) a
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
      
   ELSE
      FOR json_rec IN ( 
         SELECT /*+ INDEX(PROFILE_ASSESSMENT_UNITS_UX1) NO_PARALLEL(a) */ 
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
            ,KEY 'locationdescription'         VALUE a.locationdescription
            ,KEY 'watertype'                   VALUE a.watertype
            ,KEY 'watersize'                   VALUE a.watersize
            ,KEY 'watersizeunits'              VALUE a.watersizeunits
            ,KEY 'assessmentunitstate'         VALUE a.assessmentunitstatus
            ,KEY 'useclassname'                VALUE a.useclassname
            ,KEY 'sizesource'                  VALUE a.sizesource
            ,KEY 'sourcescale'                 VALUE a.sourcescale
            ,KEY 'locationtypecode'            VALUE a.locationtypecode
            ,KEY 'locationtext'                VALUE a.locationtext
         ) AS jout
         FROM
         attains_app.profile_assessment_units a
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
   
   END IF;
      
   -----------------------------------------------------------------------------
   -- Step 60
   -- Close the response
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      HTP.PRN(']');

      IF ary_states IS NULL
      THEN
         str_slug := 'null';
         
      ELSE
         str_slug := '"' || util.arystr2str(ary_states) || '"';
         
      END IF;
      HTP.PRN(',"state":' || str_slug);

      IF ary_orgids IS NULL
      THEN
         str_slug := 'null';
         
      ELSE
         str_slug := '"' || util.arystr2str(ary_orgids) || '"';
         
      END IF;
      HTP.PRN(',"organizationid":' || str_slug);
      
      IF ary_cycles IS NULL
      THEN
         str_slug := 'null';
         
      ELSE
         str_slug := '"' || util.aryint2str(ary_cycles) || '"';
         
      END IF;
      HTP.PRN(',"reportingcycle":' || str_slug);
      
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
   
END profile_assessment_units;
/

GRANT EXECUTE ON attains_eq.profile_assessment_units TO attains_eq_rest;

