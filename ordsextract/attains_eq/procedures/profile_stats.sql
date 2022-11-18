CREATE OR REPLACE PROCEDURE attains_eq.profile_stats(
    p_offset                  IN  VARCHAR2 DEFAULT NULL
   ,p_limit                   IN  VARCHAR2 DEFAULT NULL
   ,f                         IN  VARCHAR2 DEFAULT NULL
   ,api_key                   IN  VARCHAR2 DEFAULT NULL
)
AUTHID CURRENT_USER
AS
   boo_mute                       BOOLEAN := FALSE;

   FUNCTION table_count(
      p_in IN VARCHAR2
   ) RETURN VARCHAR2
   AS
      int_count PLS_INTEGER;
   BEGIN
      EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM attains_app.' || p_in || ' a'
      INTO int_count;
      
      RETURN TO_CHAR(int_count);
      
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '"error"';

   END table_count;

   FUNCTION refresh_date(
      p_in IN VARCHAR2
   ) RETURN VARCHAR2
   AS
      dat_refresh DATE;
   BEGIN
      SELECT a.last_refresh_date INTO dat_refresh FROM all_mviews a 
      WHERE a.owner = 'ATTAINS_APP' AND a.mview_name = p_in;
      
      RETURN '"' || TO_CHAR(
          TO_TIMESTAMP(dat_refresh)
         ,'YYYY-MM-DD"T"HH24:MI:SS.FF2TZR'
      ) || '"';
   
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN '"error"';
         
      WHEN OTHERS
      THEN
         RAISE;
         
   END refresh_date;
   
BEGIN

   -----------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   -----------------------------------------------------------------------------

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
      HTP.PRN('{"name":"profile_stats","records":[');
      
   END IF;

   -----------------------------------------------------------------------------
   -- Step 50
   -- Loop through the streams
   ----------------------------------------------------------------------------- 
   IF NOT boo_mute
   THEN
      HTP.PRN('{');
      HTP.PRN('"name":"profile_actions"');
      HTP.PRN(',"count":' || table_count('PROFILE_ACTIONS'));
      HTP.PRN(',"last_refresh":' || refresh_date('PROFILE_ACTIONS'));
      HTP.PRN('},');
      
      HTP.PRN('{');
      HTP.PRN('"name":"profile_assessments"');
      HTP.PRN(',"count":' || table_count('PROFILE_ASSESSMENTS'));
      HTP.PRN(',"last_refresh":' || refresh_date('PROFILE_ASSESSMENTS'));
      HTP.PRN('},');

      HTP.PRN('{');
      HTP.PRN('"name":"profile_assessment_units"');
      HTP.PRN(',"count":' || table_count('PROFILE_ASSESSMENT_UNITS'));
      HTP.PRN(',"last_refresh":' || refresh_date('PROFILE_ASSESSMENT_UNITS'));
      HTP.PRN('},');
      
      HTP.PRN('{');
      HTP.PRN('"name":"profile_assessment_units_monitoring_locations"');
      HTP.PRN(',"count":' || table_count('PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS'));
      HTP.PRN(',"last_refresh":' || refresh_date('PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS'));
      HTP.PRN('},');

      HTP.PRN('{');
      HTP.PRN('"name":"profile_catchment_correspondence"');
      HTP.PRN(',"count":' || table_count('PROFILE_CATCHMENT_CORRESPONDENCE'));
      HTP.PRN(',"last_refresh":' || refresh_date('PROFILE_CATCHMENT_CORRESPONDENCE'));
      HTP.PRN('},');

      HTP.PRN('{');
      HTP.PRN('"name":"profile_sources"');
      HTP.PRN(',"count":' || table_count('PROFILE_SOURCES'));
      HTP.PRN(',"last_refresh":' || refresh_date('PROFILE_SOURCES'));
      HTP.PRN('},');

      HTP.PRN('{');
      HTP.PRN('"name":"profile_tmdl"');
      HTP.PRN(',"count":' || table_count('PROFILE_TMDL'));
      HTP.PRN(',"last_refresh":' || refresh_date('PROFILE_TMDL'));
      HTP.PRN('}');
      
   END IF;
      
   -----------------------------------------------------------------------------
   -- Step 60
   -- Close the response
   -----------------------------------------------------------------------------
   IF NOT boo_mute
   THEN
      HTP.PRN(']');

      HTP.PRN('}');
        
   END IF;
   
END profile_stats;
/

GRANT EXECUTE ON attains_eq.profile_stats TO attains_eq_rest;

