CREATE OR REPLACE FUNCTION header_check(
   p_api_key  IN VARCHAR2 DEFAULT NULL
) RETURN BOOLEAN
AS
   str_service_header VARCHAR2(4000 Char);
   str_header_value   VARCHAR2(4000 Char);

BEGIN

   SELECT
   a.header_value
   INTO
   str_header_value
   FROM
   attains_eq.header_authorization a;
   
   IF p_api_key IS NOT NULL
   THEN
      str_service_header := p_api_key;
      
   ELSE
      str_service_header := OWA_UTIL.GET_CGI_ENV('Api-Key');
      
   END IF;
   
   IF str_service_header IS NULL
   THEN
      RETURN FALSE;
      
   ELSIF str_service_header = str_header_value
   THEN
      RETURN TRUE;
      
   ELSE
      RETURN FALSE;
      
   END IF;

END header_check;
