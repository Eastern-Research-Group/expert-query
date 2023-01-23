CREATE OR REPLACE PACKAGE attains_eq.util
AUTHID CURRENT_USER
AS

   ary_profiles attains_eq.string_array := attains_eq.string_array(
       'PROFILE_ACTIONS'
      ,'PROFILE_ASSESSMENTS'
      ,'PROFILE_ASSESSMENT_UNITS'
      ,'PROFILE_ASSESSMENT_UNITS_MONITORING_LOCATIONS'
      ,'PROFILE_CATCHMENT_CORRESPONDENCE'
      ,'PROFILE_SOURCES'
      ,'PROFILE_TMDL'
   );

   gonogo_hour_interval INTERVAL DAY TO SECOND := INTERVAL '36' HOUR;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION str2integer(
      pin  IN  VARCHAR2
   ) RETURN PLS_INTEGER DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION str2arystr(
      pin  IN  VARCHAR2
   ) RETURN attains_eq.string_array DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION arystr2str(
      pin  IN  attains_eq.string_array
   ) RETURN VARCHAR2 DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION arystr2in(
      pin  IN  attains_eq.string_array
   ) RETURN VARCHAR2 DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION str2aryint(
      pin  IN  VARCHAR2
   ) RETURN attains_eq.integer_array DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION aryint2str(
      pin  IN  attains_eq.integer_array
   ) RETURN VARCHAR2 DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str              IN VARCHAR2
      ,p_regex            IN VARCHAR2
      ,p_match            IN VARCHAR2 DEFAULT NULL
      ,p_end              IN NUMBER   DEFAULT 0
      ,p_trim             IN VARCHAR2 DEFAULT 'FALSE'
   ) RETURN attains_eq.string_array DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE clob2htp(
       p_input            IN  CLOB
      ,p_string_size      IN  NUMBER   DEFAULT 32000
      ,p_breaking_chars   IN  VARCHAR2 DEFAULT NULL
      ,p_breaking_delim   IN  VARCHAR2 DEFAULT ','
      ,p_mute             IN  BOOLEAN  DEFAULT FALSE
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE all_tables(
       p_owner                   IN  VARCHAR2
      ,p_table_name              IN  VARCHAR2
      ,out_table_found           OUT BOOLEAN
      ,out_num_rows              OUT INTEGER
      ,out_last_analyzed         OUT TIMESTAMP
   );

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE all_mviews(
       p_owner                   IN  VARCHAR2
      ,p_mview_name              IN  VARCHAR2
      ,out_mview_found           OUT BOOLEAN
      ,out_staleness             OUT VARCHAR2
      ,out_last_refresh_date     OUT TIMESTAMP
      ,out_last_refresh_end_time OUT TIMESTAMP
      ,out_last_refresh_type     OUT VARCHAR2
      ,out_last_refresh_elapsed  OUT INTERVAL DAY TO SECOND
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION go_nogo(
      f                          IN  VARCHAR2 DEFAULT 'JSON'
   )
   RETURN CLOB;

END util;
/

GRANT EXECUTE ON attains_eq.util TO public;

