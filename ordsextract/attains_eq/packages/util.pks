CREATE OR REPLACE PACKAGE attains_eq.util
AUTHID CURRENT_USER
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION str2integer(
      pin  IN  VARCHAR2
   ) RETURN PLS_INTEGER;
   
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

END util;
/

GRANT EXECUTE ON attains_eq.util TO public;

