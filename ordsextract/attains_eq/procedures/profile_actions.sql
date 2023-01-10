CREATE OR REPLACE PROCEDURE attains_eq.profile_actions(
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
   int_offset                     PLS_INTEGER;
   int_offsetend                  PLS_INTEGER;
   int_limit                      PLS_INTEGER;
   boo_comma                      BOOLEAN;
   str_slug                       VARCHAR2(4000 Char);
   str_sql                        VARCHAR2(32000 Char);
   curs_ref                       SYS_REFCURSOR;
   num_curid                      NUMBER;
   int_dummy                      PLS_INTEGER;

   TYPE rec_json IS RECORD(
      results CLOB
   );
   TYPE tbl_json IS TABLE OF rec_json
   INDEX BY PLS_INTEGER;
   ary_json tbl_json;
   
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

   int_offset := util.str2integer(p_offset);
   int_limit  := util.str2integer(p_limit);

   IF  int_offset IS NOT NULL
   AND int_limit IS NOT NULL
   THEN
      int_offsetend := int_offset + int_limit;
      
   ELSE
      IF int_limit IS NULL
      THEN
         int_limit     := 5000;
         int_offsetend := 5000;
         
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
      HTP.PRN('{"name":"profile_actions","records":[');
      
   END IF;
   
   -----------------------------------------------------------------------------
   -- Step 50
   -- Generate the SQL
   -----------------------------------------------------------------------------
   str_sql := 'SELECT '
           || 'JSON_OBJECT( '
           || '    KEY ''objectid''                    VALUE a.objectid '
           || '   ,KEY ''state''                       VALUE a.state '
           || '   ,KEY ''region''                      VALUE a.region '
           || '   ,KEY ''organizationid''              VALUE a.organizationid '
           || '   ,KEY ''organizationname''            VALUE a.organizationname '
           || '   ,KEY ''organizationtype''            VALUE a.organizationtype '
           || '   ,KEY ''assessmentunitid''            VALUE a.assessmentunitid '
           || '   ,KEY ''assessmentunitname''          VALUE a.assessmentunitname '
           || '   ,KEY ''actionid''                    VALUE a.actionid '
           || '   ,KEY ''actionname''                  VALUE a.actionname '
           || '   ,KEY ''completiondate''              VALUE a.completiondate '
           || '   ,KEY ''parameter''                   VALUE a.parameter '
           || '   ,KEY ''locationdescription''         VALUE a.locationdescription '
           || '   ,KEY ''actiontype''                  VALUE a.actiontype '
           || '   ,KEY ''watertype''                   VALUE a.watertype '
           || '   ,KEY ''watersize''                   VALUE a.watersize '
           || '   ,KEY ''watersizeunits''              VALUE a.watersizeunits '
           || '   ,KEY ''actionagency''                VALUE a.actionagency '
           || '   ,KEY ''inindiancountry''             VALUE a.inindiancountry '
           || '   ,KEY ''includeinmeasure''            VALUE a.includeinmeasure '
           || '   RETURNING CLOB '         
           || ') AS jout '
           || 'FROM ( '
           || '   SELECT '
           || '    CAST(aa.row_id AS INTEGER) AS objectid '
           || '   ,aa.state '
           || '   ,aa.region '
           || '   ,aa.organizationid '
           || '   ,aa.organizationname '
           || '   ,aa.organizationtype '
           || '   ,aa.assessmentunitid '
           || '   ,aa.assessmentunitname '
           || '   ,aa.actionid '
           || '   ,aa.actionname '
           || '   ,aa.completiondate '
           || '   ,aa.parameter '
           || '   ,aa.locationdescription '
           || '   ,aa.actiontype '
           || '   ,aa.watertype '
           || '   ,aa.watersize '
           || '   ,aa.watersizeunits '
           || '   ,aa.actionagency '
           || '   ,aa.inindiancountry '
           || '   ,aa.includeinmeasure '
           || '   FROM '
           || '   attains_app.profile_actions aa '
           || '   WHERE ';

   IF ary_states IS NOT NULL
   OR ary_orgids IS NOT NULL
   THEN
      str_sql := str_sql
              || '    1 = 1 ';

      IF ary_states IS NOT NULL
      THEN
         str_sql := str_sql        
                 || 'AND aa.state IN (' || util.arystr2in(ary_states) || ') ';
                 
      END IF;
      
      IF ary_orgids IS NOT NULL
      THEN
         str_sql := str_sql        
                 || 'AND aa.organizationid IN (' || util.arystr2in(ary_orgids) || ') ';
                 
      END IF;
              
      str_sql := str_sql 
              || 'OFFSET :p03 ROWS FETCH NEXT :p04 ROWS ONLY '
              || ') a';
     
      num_curid := DBMS_SQL.OPEN_CURSOR;
      DBMS_SQL.PARSE(num_curid,str_sql,DBMS_SQL.NATIVE);

      DBMS_SQL.BIND_VARIABLE(num_curid,'p03',int_offset);
      DBMS_SQL.BIND_VARIABLE(num_curid,'p04',int_limit);
      int_dummy := DBMS_SQL.EXECUTE(num_curid);    
      curs_ref := DBMS_SQL.TO_REFCURSOR(num_curid);
   
   ELSE
      str_sql := str_sql
              || '    aa.row_id >  :p01 '
              || 'AND aa.row_id <= :p02 '
              || ') a';

      OPEN curs_ref FOR str_sql USING int_offset,int_offsetend;

   END IF;
   
   -----------------------------------------------------------------------------
   -- Step 60
   -- Loop through the records
   -----------------------------------------------------------------------------
   boo_comma := FALSE;
   
   LOOP
      FETCH curs_ref BULK COLLECT INTO ary_json LIMIT 10000;
      
      FOR i IN 1 .. ary_json.COUNT
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
             p_input => ary_json(i).results
            ,p_mute  => boo_mute
         );
         
      END LOOP;
      
      EXIT WHEN curs_ref%NOTFOUND;
      
   END LOOP;
   
   CLOSE curs_ref;
      
   -----------------------------------------------------------------------------
   -- Step 70
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
   
END profile_actions;
/

GRANT EXECUTE ON attains_eq.profile_actions TO attains_eq_rest;

