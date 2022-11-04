CREATE OR REPLACE PROCEDURE attains_eq.profile_catchment_correspondence(
    p_offset                  IN  VARCHAR2 DEFAULT NULL
   ,p_limit                   IN  VARCHAR2 DEFAULT NULL
   ,f                         IN  VARCHAR2 DEFAULT NULL
   ,api_key                   IN  VARCHAR2 DEFAULT NULL
)
AUTHID CURRENT_USER
AS
   boo_mute                       BOOLEAN := true;
   
   int_offset                     PLS_INTEGER;
   int_limit                      PLS_INTEGER;
   boo_comma                      BOOLEAN;
   str_slug                       VARCHAR2(4000);
   
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
      
   END IF;
   
   -----------------------------------------------------------------------------
   -- Step 20
   -- Write the header
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      OWA_UTIL.MIME_HEADER('application/json',FALSE);
      OWA_UTIL.HTTP_HEADER_CLOSE;
      
   END IF;
   
   -----------------------------------------------------------------------------
   -- Step 30
   -- Generate the header and start the output
   -----------------------------------------------------------------------------

   -----------------------------------------------------------------------------
   -- Step 40
   -- Generate the header and start the output
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      HTP.PRN('{"name":"profile_catchment_correspondence","records":[');
      
   END IF;

   -----------------------------------------------------------------------------
   -- Step 110
   -- Loop through the streams
   -----------------------------------------------------------------------------
   boo_comma := FALSE;
   
   FOR json IN ( 
      SELECT  
      JSON_OBJECT(
          KEY 'objectid'            VALUE a.objectid
         ,KEY 'state'               VALUE a.state
         ,KEY 'region'              VALUE a.region
         ,KEY 'organizationid'      VALUE a.organizationid
         ,KEY 'organizationname'    VALUE a.organizationname
         ,KEY 'organizationtype'    VALUE a.organizationtype
         ,KEY 'reportingcycle'      VALUE a.reportingcycle
         ,KEY 'assessmentunitid'    VALUE a.assessmentunitid
         ,KEY 'assessmentunitname'  VALUE a.assessmentunitname
         ,KEY 'catchmentnhdplusid'  VALUE a.catchmentnhdplusid
      ) AS jout
      FROM
      attains_app.profile_catchment_correspondence a
      WHERE
          (int_offset IS NULL OR a.objectid >  int_offset)
      AND (int_limit  IS NULL OR a.objectid <= int_limit)
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
      dbms_output.put_line(to_char(substr(json.jout,1,4000)) || CHR(13));
      attains_eq.util.clob2htp(
          p_input => json.jout
         ,p_mute  => boo_mute
      );
      
   END LOOP;
   
   -----------------------------------------------------------------------------
   -- Step 110
   -- Close the response
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      HTP.PRN('],');
      
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
   
END profile_catchment_correspondence;
/
