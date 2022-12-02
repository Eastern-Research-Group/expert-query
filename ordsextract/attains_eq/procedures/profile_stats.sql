CREATE OR REPLACE PROCEDURE attains_eq.profile_stats(
    p_offset                  IN  VARCHAR2 DEFAULT NULL
   ,p_limit                   IN  VARCHAR2 DEFAULT NULL
   ,f                         IN  VARCHAR2 DEFAULT NULL
   ,api_key                   IN  VARCHAR2 DEFAULT NULL
)
AUTHID CURRENT_USER
AS
   boo_mute                       BOOLEAN := FALSE;
   str_num_rows                   VARCHAR2(4000 Char);
   str_last_analyzed              VARCHAR2(4000 Char);
   str_staleness                  VARCHAR2(4000 Char);
   str_last_refresh_date          VARCHAR2(4000 Char);
   str_last_refresh_end_time      VARCHAR2(4000 Char);
   str_last_refresh_type          VARCHAR2(4000 Char);

   PROCEDURE all_tables(
       p_in              IN  VARCHAR2
      ,out_num_rows      OUT VARCHAR2
      ,out_last_analyzed OUT VARCHAR2
   )
   AS
      int_num_rows      INTEGER;
      dat_last_analyzed DATE;
      
   BEGIN
      SELECT
       a.num_rows
      ,a.last_analyzed 
      INTO 
       int_num_rows
      ,dat_last_analyzed 
      FROM 
      all_tables a 
      WHERE 
          a.owner = 'ATTAINS_APP' 
      AND a.table_name = p_in;
      
      IF int_num_rows IS NOT NULL
      THEN
         out_num_rows      := TO_CHAR(int_num_rows);
         
      ELSE
         out_num_rows      := 'null';
         
      END IF;
      
      IF dat_last_analyzed IS NOT NULL
      THEN
         out_last_analyzed := '"' || TO_CHAR(
             TO_TIMESTAMP(dat_last_analyzed)
            ,'YYYY-MM-DD"T"HH24:MI:SS.FF2TZR'
         ) || '"';
         
      ELSE
         out_last_analyzed := 'null';
      
      END IF;
         
   EXCEPTION
      WHEN OTHERS
      THEN
         out_num_rows      := '"err"';
         out_last_analyzed := '"err"';
         RETURN;

   END all_tables;

   PROCEDURE all_mviews(
       p_in                      IN  VARCHAR2
      ,out_staleness             OUT VARCHAR2
      ,out_last_refresh_date     OUT VARCHAR2
      ,out_last_refresh_end_time OUT VARCHAR2
      ,out_last_refresh_type     OUT VARCHAR2
   )
   AS
      dat_last_refresh_date     DATE;
      dat_last_refresh_end_time DATE;
      
   BEGIN
      SELECT
       a.staleness 
      ,a.last_refresh_date 
      ,a.last_refresh_end_time
      ,a.last_refresh_type
      INTO 
       out_staleness
      ,dat_last_refresh_date
      ,dat_last_refresh_end_time
      ,out_last_refresh_type
      FROM 
      all_mviews a 
      WHERE 
          a.owner = 'ATTAINS_APP'
      AND a.mview_name = p_in;
      
      IF out_staleness IS NOT NULL
      THEN
         out_staleness := '"' || out_staleness || '"';
      
      ELSE
         out_staleness := 'null';
         
      END IF;
      
      IF dat_last_refresh_date IS NOT NULL
      THEN
         out_last_refresh_date := '"' || TO_CHAR(
             TO_TIMESTAMP(dat_last_refresh_date)
            ,'YYYY-MM-DD"T"HH24:MI:SS.FF2TZR'
         ) || '"';
         
      ELSE
         out_last_refresh_date := 'null';
         
      END IF;
      
      IF dat_last_refresh_end_time IS NOT NULL
      THEN
         out_last_refresh_end_time := '"' || TO_CHAR(
             TO_TIMESTAMP(dat_last_refresh_end_time)
            ,'YYYY-MM-DD"T"HH24:MI:SS.FF2TZR'
         ) || '"';
         
      ELSE
         out_last_refresh_end_time := 'null';
      
      END IF;
      
      IF out_last_refresh_type IS NOT NULL
      THEN
         out_last_refresh_type := '"' || out_last_refresh_type || '"';
         
      ELSE
         out_last_refresh_type := 'null';
         
      END IF;
   
   EXCEPTION
      WHEN OTHERS
      THEN
         out_staleness             := '"err"';
         out_last_refresh_date     := '"err"';
         out_last_refresh_end_time := '"err"';
         out_last_refresh_type     := '"err"';
         RETURN;
         
   END all_mviews;
   
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
   all_tables(
       p_in                      => 'PROFILE_ACTIONS'
      ,out_num_rows              => str_num_rows
      ,out_last_analyzed         => str_last_analyzed
   );
   all_mviews(
       p_in                      => 'PROFILE_ACTIONS'
      ,out_staleness             => str_staleness
      ,out_last_refresh_date     => str_last_refresh_date
      ,out_last_refresh_end_time => str_last_refresh_end_time
      ,out_last_refresh_type     => str_last_refresh_type
   );
   IF NOT boo_mute
   THEN
      HTP.PRN('{');
      HTP.PRN('"name":"profile_actions"');
      HTP.PRN(',"staleness":' || str_staleness);
      HTP.PRN(',"last_refresh_date":' || str_last_refresh_date);
      HTP.PRN(',"last_refresh_end_time":' || str_last_refresh_end_time);
      HTP.PRN(',"last_refresh_type":' || str_last_refresh_type);
      HTP.PRN(',"num_rows":' || str_num_rows);
      HTP.PRN(',"last_analyzed":' || str_last_analyzed);
      HTP.PRN('},');
   
   END IF;
      
   all_tables(
       p_in                      => 'PROFILE_ASSESSMENTS'
      ,out_num_rows              => str_num_rows
      ,out_last_analyzed         => str_last_analyzed
   );
   all_mviews(
       p_in                      => 'PROFILE_ASSESSMENTS'
      ,out_staleness             => str_staleness
      ,out_last_refresh_date     => str_last_refresh_date
      ,out_last_refresh_end_time => str_last_refresh_end_time
      ,out_last_refresh_type     => str_last_refresh_type
   );
   IF NOT boo_mute
   THEN
      HTP.PRN('{');
      HTP.PRN('"name":"profile_assessments"');
      HTP.PRN(',"staleness":' || str_staleness);
      HTP.PRN(',"last_refresh_date":' || str_last_refresh_date);
      HTP.PRN(',"last_refresh_end_time":' || str_last_refresh_end_time);
      HTP.PRN(',"last_refresh_type":' || str_last_refresh_type);
      HTP.PRN(',"num_rows":' || str_num_rows);
      HTP.PRN(',"last_analyzed":' || str_last_analyzed);
      HTP.PRN('},');
   
   END IF;
   
   all_tables(
       p_in                      => 'PROFILE_ASSESSMENT_UNITS'
      ,out_num_rows              => str_num_rows
      ,out_last_analyzed         => str_last_analyzed
   );
   all_mviews(
       p_in                      => 'PROFILE_ASSESSMENT_UNITS'
      ,out_staleness             => str_staleness
      ,out_last_refresh_date     => str_last_refresh_date
      ,out_last_refresh_end_time => str_last_refresh_end_time
      ,out_last_refresh_type     => str_last_refresh_type
   );
   IF NOT boo_mute
   THEN
      HTP.PRN('{');
      HTP.PRN('"name":"profile_assessment_units"');
      HTP.PRN(',"staleness":' || str_staleness);
      HTP.PRN(',"last_refresh_date":' || str_last_refresh_date);
      HTP.PRN(',"last_refresh_end_time":' || str_last_refresh_end_time);
      HTP.PRN(',"last_refresh_type":' || str_last_refresh_type);
      HTP.PRN(',"num_rows":' || str_num_rows);
      HTP.PRN(',"last_analyzed":' || str_last_analyzed);
      HTP.PRN('},');
   
   END IF;
   
   all_tables(
       p_in                      => 'PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS'
      ,out_num_rows              => str_num_rows
      ,out_last_analyzed         => str_last_analyzed
   );
   all_mviews(
       p_in                      => 'PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS'
      ,out_staleness             => str_staleness
      ,out_last_refresh_date     => str_last_refresh_date
      ,out_last_refresh_end_time => str_last_refresh_end_time
      ,out_last_refresh_type     => str_last_refresh_type
   );
   IF NOT boo_mute
   THEN   
      HTP.PRN('{');
      HTP.PRN('"name":"profile_assessment_units_monitoring_locations"');
      HTP.PRN(',"staleness":' || str_staleness);
      HTP.PRN(',"last_refresh_date":' || str_last_refresh_date);
      HTP.PRN(',"last_refresh_end_time":' || str_last_refresh_end_time);
      HTP.PRN(',"last_refresh_type":' || str_last_refresh_type);
      HTP.PRN(',"num_rows":' || str_num_rows);
      HTP.PRN(',"last_analyzed":' || str_last_analyzed);
      HTP.PRN('},');
   
   END IF;
   
   all_tables(
       p_in                      => 'PROFILE_CATCHMENT_CORRESPONDENCE'
      ,out_num_rows              => str_num_rows
      ,out_last_analyzed         => str_last_analyzed
   );
   all_mviews(
       p_in                      => 'PROFILE_CATCHMENT_CORRESPONDENCE'
      ,out_staleness             => str_staleness
      ,out_last_refresh_date     => str_last_refresh_date
      ,out_last_refresh_end_time => str_last_refresh_end_time
      ,out_last_refresh_type     => str_last_refresh_type
   );
   IF NOT boo_mute
   THEN
      HTP.PRN('{');
      HTP.PRN('"name":"profile_catchment_correspondence"');
      HTP.PRN(',"staleness":' || str_staleness);
      HTP.PRN(',"last_refresh_date":' || str_last_refresh_date);
      HTP.PRN(',"last_refresh_end_time":' || str_last_refresh_end_time);
      HTP.PRN(',"last_refresh_type":' || str_last_refresh_type);
      HTP.PRN(',"num_rows":' || str_num_rows);
      HTP.PRN(',"last_analyzed":' || str_last_analyzed);
      HTP.PRN('},');
   
   END IF;
   
   all_tables(
       p_in                      => 'PROFILE_SOURCES'
      ,out_num_rows              => str_num_rows
      ,out_last_analyzed         => str_last_analyzed
   );
   all_mviews(
       p_in                      => 'PROFILE_SOURCES'
      ,out_staleness             => str_staleness
      ,out_last_refresh_date     => str_last_refresh_date
      ,out_last_refresh_end_time => str_last_refresh_end_time
      ,out_last_refresh_type     => str_last_refresh_type
   );
   IF NOT boo_mute
   THEN
      HTP.PRN('{');
      HTP.PRN('"name":"profile_sources"');
      HTP.PRN(',"staleness":' || str_staleness);
      HTP.PRN(',"last_refresh_date":' || str_last_refresh_date);
      HTP.PRN(',"last_refresh_end_time":' || str_last_refresh_end_time);
      HTP.PRN(',"last_refresh_type":' || str_last_refresh_type);
      HTP.PRN(',"num_rows":' || str_num_rows);
      HTP.PRN(',"last_analyzed":' || str_last_analyzed);
      HTP.PRN('},');
   
   END IF;

   all_tables(
       p_in                      => 'PROFILE_TMDL'
      ,out_num_rows              => str_num_rows
      ,out_last_analyzed         => str_last_analyzed
   );
   all_mviews(
       p_in                      => 'PROFILE_TMDL'
      ,out_staleness             => str_staleness
      ,out_last_refresh_date     => str_last_refresh_date
      ,out_last_refresh_end_time => str_last_refresh_end_time
      ,out_last_refresh_type     => str_last_refresh_type
   );
   IF NOT boo_mute
   THEN
      HTP.PRN('{');
      HTP.PRN('"name":"profile_tmdl"');
      HTP.PRN(',"staleness":' || str_staleness);
      HTP.PRN(',"last_refresh_date":' || str_last_refresh_date);
      HTP.PRN(',"last_refresh_end_time":' || str_last_refresh_end_time);
      HTP.PRN(',"last_refresh_type":' || str_last_refresh_type);
      HTP.PRN(',"num_rows":' || str_num_rows);
      HTP.PRN(',"last_analyzed":' || str_last_analyzed);
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

