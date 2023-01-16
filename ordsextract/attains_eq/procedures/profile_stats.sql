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
   str_table_found                VARCHAR2(4000 Char);
   str_mview_found                VARCHAR2(4000 Char);
   str_staleness                  VARCHAR2(4000 Char);
   str_last_refresh_date          VARCHAR2(4000 Char);
   str_last_refresh_end_time      VARCHAR2(4000 Char);
   str_last_refresh_type          VARCHAR2(4000 Char);
   str_last_refresh_elapsed       VARCHAR2(4000 Char);
   str_fresh_stats                VARCHAR2(4000 Char);
   
   PROCEDURE json_profile(
       p_owner                   IN  VARCHAR2
      ,p_mview_name              IN  VARCHAR2
      ,out_mview_found           OUT VARCHAR2
      ,out_staleness             OUT VARCHAR2
      ,out_last_refresh_date     OUT VARCHAR2
      ,out_last_refresh_end_time OUT VARCHAR2
      ,out_last_refresh_type     OUT VARCHAR2
      ,out_last_refresh_elapsed  OUT VARCHAR2
      ,out_table_found           OUT VARCHAR2
      ,out_num_rows              OUT VARCHAR2
      ,out_last_analyzed         OUT VARCHAR2
      ,out_fresh_stats           OUT VARCHAR2
   )
   AS
      dat_last_refresh_date     TIMESTAMP;
      dat_last_refresh_end_time TIMESTAMP;
      inv_last_refresh_elapsed  INTERVAL DAY TO SECOND;
      boo_mview_found           BOOLEAN;
      boo_table_found           BOOLEAN;
      int_num_rows              PLS_INTEGER;
      dat_last_analyzed         TIMESTAMP;
   
   BEGIN
      util.all_mviews(
          p_owner                   => p_owner
         ,p_mview_name              => p_mview_name
         ,out_mview_found           => boo_mview_found
         ,out_staleness             => out_staleness
         ,out_last_refresh_date     => dat_last_refresh_date
         ,out_last_refresh_end_time => dat_last_refresh_end_time
         ,out_last_refresh_type     => out_last_refresh_type
         ,out_last_refresh_elapsed  => inv_last_refresh_elapsed
      );
      
      IF boo_mview_found
      THEN
         out_mview_found := 'true';
         
      ELSE
         out_mview_found := 'false';
      
      END IF;
      
      IF out_staleness IS NOT NULL
      THEN
         out_staleness := '"' || out_staleness || '"';
      
      ELSE
         out_staleness := 'null';
         
      END IF;
      
      IF dat_last_refresh_date IS NOT NULL
      THEN
         out_last_refresh_date := '"' || TO_CHAR(
             dat_last_refresh_date
            ,'YYYY-MM-DD"T"HH24:MI:SS.FF2TZR'
         ) || '"';
         
      ELSE
         out_last_refresh_date := 'null';
         
      END IF;
      
      IF dat_last_refresh_end_time IS NOT NULL
      THEN
         out_last_refresh_end_time := '"' || TO_CHAR(
             dat_last_refresh_end_time
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
      
      IF inv_last_refresh_elapsed IS NOT NULL
      THEN
         out_last_refresh_elapsed := '"' || TO_CHAR(
            EXTRACT(DAY FROM inv_last_refresh_elapsed) * 24 + EXTRACT(HOUR FROM inv_last_refresh_elapsed)
         ) || ':' || TO_CHAR(
            EXTRACT(MINUTE FROM inv_last_refresh_elapsed), 'fm00' 
         ) || '"';
         
      ELSE
         out_last_refresh_elapsed := 'null';
         
      END IF;
      
      util.all_tables(
          p_owner           => p_owner
         ,p_table_name      => p_mview_name
         ,out_table_found   => boo_table_found
         ,out_num_rows      => int_num_rows
         ,out_last_analyzed => dat_last_analyzed
      );
      
      IF boo_table_found
      THEN
         out_table_found := 'true';
         
      ELSE
         out_table_found := 'false';
      
      END IF;
   
      IF int_num_rows IS NOT NULL
      THEN
         out_num_rows    := TO_CHAR(int_num_rows);
         
      ELSE
         out_num_rows    := 'null';
         
      END IF;
      
      IF dat_last_analyzed IS NOT NULL
      THEN
         out_last_analyzed := '"' || TO_CHAR(
             dat_last_analyzed
            ,'YYYY-MM-DD"T"HH24:MI:SS.FF2TZR'
         ) || '"';
         
      ELSE
         out_last_analyzed := 'null';
      
      END IF;
      
      IF  dat_last_refresh_end_time IS NOT NULL
      AND dat_last_analyzed IS NOT NULL
      THEN
         IF dat_last_analyzed > dat_last_refresh_end_time
         THEN
            out_fresh_stats := 'true';
            
         ELSE
            out_fresh_stats := 'false';
         
         END IF;
         
      ELSE
         out_fresh_stats := 'false';
         
      END IF;
   
   END json_profile;

BEGIN

   -----------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   -----------------------------------------------------------------------------

   -----------------------------------------------------------------------------
   -- Step 20
   -- Do the header verification check
   -----------------------------------------------------------------------------
   IF NOT attains_eq.header_check(api_key)
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
      HTP.PRN('{"name":"profile_stats"');
      HTP.PRN(',"status":' || util.go_nogo());
      HTP.PRN(',"details":[');
      
   END IF;

   -----------------------------------------------------------------------------
   -- Step 50
   -- Loop through the streams
   -----------------------------------------------------------------------------
   FOR i IN 1 .. util.ary_profiles.COUNT
   LOOP
      json_profile(
          p_owner                   => 'ATTAINS_APP'
         ,p_mview_name              => util.ary_profiles(i)
         ,out_mview_found           => str_mview_found
         ,out_staleness             => str_staleness
         ,out_last_refresh_date     => str_last_refresh_date
         ,out_last_refresh_end_time => str_last_refresh_end_time
         ,out_last_refresh_type     => str_last_refresh_type
         ,out_last_refresh_elapsed  => str_last_refresh_elapsed
         ,out_table_found           => str_table_found
         ,out_num_rows              => str_num_rows
         ,out_last_analyzed         => str_last_analyzed
         ,out_fresh_stats           => str_fresh_stats
      );
      IF NOT boo_mute
      THEN
         HTP.PRN('{');
         HTP.PRN('"name":"attains_app.' || LOWER(util.ary_profiles(i)) || '"');
         HTP.PRN(',"table_found":' || str_table_found);
         HTP.PRN(',"mview_found":' || str_mview_found);
         HTP.PRN(',"staleness":' || str_staleness);
         HTP.PRN(',"last_refresh_date":' || str_last_refresh_date);
         HTP.PRN(',"last_refresh_end_time":' || str_last_refresh_end_time);
         HTP.PRN(',"last_refresh_type":' || str_last_refresh_type);
         HTP.PRN(',"last_refresh_elapsed":' || str_last_refresh_elapsed);
         HTP.PRN(',"num_rows":' || str_num_rows);
         HTP.PRN(',"last_analyzed":' || str_last_analyzed);
         HTP.PRN(',"fresh_stats":' || str_fresh_stats);
         HTP.PRN('}');
         
         IF i < util.ary_profiles.COUNT
         THEN
            HTP.PRN(',');
            
         END IF;

      END IF;
      
   END LOOP;
      
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

