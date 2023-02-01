CREATE OR REPLACE PACKAGE BODY attains_eq.util
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION str2integer(
      pin  IN  VARCHAR2
   ) RETURN PLS_INTEGER DETERMINISTIC
   AS
     int_out PLS_INTEGER;
     
   BEGIN
      int_out := TO_NUMBER(pin);
      RETURN int_out;
      
   EXCEPTION
      WHEN VALUE_ERROR
      THEN
         RETURN NULL;
      
      WHEN OTHERS
      THEN
         RAISE;
         
   END str2integer;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION str2arystr(
      pin  IN  VARCHAR2
   ) RETURN attains_eq.string_array DETERMINISTIC
   AS
      aryout attains_eq.string_array;

   BEGIN
      IF pin IS NULL
      THEN
         RETURN NULL;
         
      END IF;
 
      aryout := gz_split(pin,',');
      
      IF aryout.COUNT = 0
      THEN
         aryout := NULL;
         
      END IF;
      
      RETURN aryout;
   
   END str2arystr;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION arystr2str(
      pin  IN  attains_eq.string_array
   ) RETURN VARCHAR2 DETERMINISTIC
   AS
     str_out   VARCHAR2(32000 Char);
     boo_comma BOOLEAN;

   BEGIN
      IF pin IS NULL
      THEN
         RETURN NULL;
         
      END IF;
      
      boo_comma := FALSE;
      FOR i IN 1 .. pin.COUNT
      LOOP
         IF boo_comma
         THEN
            str_out := str_out || ',';
         
         ELSE
            boo_comma := TRUE;

         END IF;
         
         str_out := str_out || pin(i);

      END LOOP;
      
      RETURN str_out;
   
   END arystr2str;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION arystr2in(
      pin  IN  attains_eq.string_array
   ) RETURN VARCHAR2 DETERMINISTIC
   AS
     str_out   VARCHAR2(32000 Char);
     boo_comma BOOLEAN;

   BEGIN
      IF pin IS NULL
      THEN
         RETURN NULL;
         
      END IF;
      
      boo_comma := FALSE;
      FOR i IN 1 .. pin.COUNT
      LOOP
         IF boo_comma
         THEN
            str_out := str_out || ',';
         
         ELSE
            boo_comma := TRUE;

         END IF;
         
         str_out := str_out || DBMS_ASSERT.ENQUOTE_LITERAL(pin(i));

      END LOOP;
      
      RETURN str_out;
   
   END arystr2in;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION str2aryint(
      pin  IN  VARCHAR2
   ) RETURN attains_eq.integer_array DETERMINISTIC
   AS
      arystr attains_eq.string_array;
      aryout attains_eq.integer_array;
      int_counter PLS_INTEGER;
      int_val     INTEGER; 

   BEGIN
      IF pin IS NULL
      THEN
         RETURN NULL;
         
      END IF;
      
      aryout := attains_eq.integer_array();
      arystr := gz_split(pin,',');
      
      int_counter := 0;
      FOR i IN 1 .. arystr.COUNT
      LOOP
         int_val := str2integer(arystr(i));

         IF int_val IS NOT NULL
         THEN
            int_counter := int_counter + 1;
            aryout.EXTEND();
            aryout(int_counter) := int_val;
         
         END IF;
      
      END LOOP; 

      IF aryout.COUNT = 0
      THEN
         aryout := NULL;
         
      END IF;
      
      RETURN aryout;   
   
   END str2aryint;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION aryint2str(
      pin  IN  attains_eq.integer_array
   ) RETURN VARCHAR2 DETERMINISTIC
   AS
     str_out   VARCHAR2(32000 Char);
     boo_comma BOOLEAN;

   BEGIN
      IF pin IS NULL
      THEN
         RETURN NULL;
         
      END IF;
      
      boo_comma := FALSE;
      FOR i IN 1 .. pin.COUNT
      LOOP
         IF boo_comma
         THEN
            str_out := str_out || ',';
         
         ELSE
            boo_comma := TRUE;

         END IF;
         
         str_out := str_out || TO_CHAR(pin(i));

      END LOOP;
      
      RETURN str_out;
   
   END aryint2str;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str              IN VARCHAR2
      ,p_regex            IN VARCHAR2
      ,p_match            IN VARCHAR2 DEFAULT NULL
      ,p_end              IN NUMBER   DEFAULT 0
      ,p_trim             IN VARCHAR2 DEFAULT 'FALSE'
   ) RETURN attains_eq.string_array DETERMINISTIC 
   AS
      int_delim      PLS_INTEGER;
      int_position   PLS_INTEGER := 1;
      int_counter    PLS_INTEGER := 1;
      ary_output     attains_eq.string_array;
      num_end        NUMBER := p_end;
      str_trim       VARCHAR2(5 Char) := UPPER(p_trim);
      
      FUNCTION trim_varray(
         p_input            IN attains_eq.string_array
      ) RETURN attains_eq.string_array
      AS
         ary_output attains_eq.string_array := attains_eq.string_array();
         int_index  PLS_INTEGER := 1;
         str_check  VARCHAR2(4000 Char);
         
      BEGIN

         --------------------------------------------------------------------------
         -- Step 10
         -- Exit if input is empty
         --------------------------------------------------------------------------
         IF p_input IS NULL
         OR p_input.COUNT = 0
         THEN
            RETURN ary_output;
            
         END IF;

         --------------------------------------------------------------------------
         -- Step 20
         -- Trim the strings removing anything utterly trimmed away
         --------------------------------------------------------------------------
         FOR i IN 1 .. p_input.COUNT
         LOOP
            str_check := TRIM(p_input(i));
            
            IF str_check IS NULL
            OR str_check = ''
            THEN
               NULL;
               
            ELSE
               ary_output.EXTEND(1);
               ary_output(int_index) := str_check;
               int_index := int_index + 1;
               
            END IF;

         END LOOP;

         --------------------------------------------------------------------------
         -- Step 10
         -- Return the results
         --------------------------------------------------------------------------
         RETURN ary_output;

      END trim_varray;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Create the output array and check parameters
      --------------------------------------------------------------------------
      ary_output := attains_eq.string_array();

      IF str_trim IS NULL
      THEN
         str_trim := 'FALSE';
         
      ELSIF str_trim NOT IN ('TRUE','FALSE')
      THEN
         RAISE_APPLICATION_ERROR(-20001,'boolean error');
         
      END IF;

      IF num_end IS NULL
      THEN
         num_end := 0;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Exit early if input is empty
      --------------------------------------------------------------------------
      IF p_str IS NULL
      OR p_str = ''
      THEN
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Account for weird instance of pure character breaking
      --------------------------------------------------------------------------
      IF p_regex IS NULL
      OR p_regex = ''
      THEN
         FOR i IN 1 .. LENGTH(p_str)
         LOOP
            ary_output.EXTEND(1);
            ary_output(i) := SUBSTR(p_str,i,1);
            
         END LOOP;
         
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 40
      -- Break string using the usual REGEXP functions
      --------------------------------------------------------------------------
      LOOP
         EXIT WHEN int_position = 0;
         int_delim  := REGEXP_INSTR(p_str,p_regex,int_position,1,0,p_match);
         
         IF  int_delim = 0
         THEN
            -- no more matches found
            ary_output.EXTEND(1);
            ary_output(int_counter) := SUBSTR(p_str,int_position);
            int_position  := 0;
            
         ELSE
            IF int_counter = num_end
            THEN
               -- take the rest as is
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position);
               int_position  := 0;
               
            ELSE
               --dbms_output.put_line(ary_output.COUNT);
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position,int_delim-int_position);
               int_counter := int_counter + 1;
               int_position := REGEXP_INSTR(p_str,p_regex,int_position,1,1,p_match);
               
            END IF;
            
         END IF;
         
      END LOOP;

      --------------------------------------------------------------------------
      -- Step 50
      -- Trim results if so desired
      --------------------------------------------------------------------------
      IF str_trim = 'TRUE'
      THEN
         RETURN trim_varray(
            p_input => ary_output
         );
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 60
      -- Cough out the results
      --------------------------------------------------------------------------
      RETURN ary_output;
      
   END gz_split;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE clob2htp(
       p_input            IN  CLOB
      ,p_string_size      IN  NUMBER   DEFAULT 32000
      ,p_breaking_chars   IN  VARCHAR2 DEFAULT NULL
      ,p_breaking_delim   IN  VARCHAR2 DEFAULT ','
      ,p_mute             IN  BOOLEAN  DEFAULT FALSE
   )
   AS
      ary_chars  attains_eq.string_array;
      int_index  PLS_INTEGER := 1;
      int_offset PLS_INTEGER := 1;
      int_cutoff PLS_INTEGER;
      str_line   VARCHAR2(32000 Char);
      
   BEGIN
   
      IF p_mute
      THEN
         RETURN;
         
      END IF;

      IF p_string_size > 32000
      THEN
         RAISE_APPLICATION_ERROR(
             -20001
            ,'VARCHAR2.HTP.P size maxes out at 32000 characters'
         );
         
      END IF;

      IF p_breaking_chars IS NOT NULL
      THEN
          ary_chars := gz_split(
              p_str   => p_breaking_chars
             ,p_regex => p_breaking_delim
             ,p_trim  => 'FALSE'
          );
          
      END IF;

      WHILE DBMS_LOB.SUBSTR(p_input,p_string_size,int_offset) IS NOT NULL
      LOOP
         str_line := TO_CHAR(DBMS_LOB.SUBSTR(p_input,p_string_size,int_offset));

         IF p_breaking_chars IS NULL
         THEN
            int_cutoff := p_string_size;

         ELSE
            int_cutoff := 0;
            
            FOR i IN 1 .. ary_chars.COUNT
            LOOP
               int_cutoff := INSTR(str_line,ary_chars(i),-1);

               IF int_cutoff > 0
               THEN
                  EXIT;
                  
               END IF;

            END LOOP;

            IF  int_cutoff = 0
            THEN
               IF LENGTH(str_line) >= p_string_size
               THEN
                  RAISE_APPLICATION_ERROR(
                      -20001
                     ,'unable to break CLOB on given breaking characters'
                  );
                  
               ELSE
                  int_cutoff := LENGTH(str_line);
                  
               END IF;

            END IF;

         END IF;

         -- THIS MUST BE HTP.PRN, do not use HTP.P!!!!!
         HTP.PRN(SUBSTR(str_line,1,int_cutoff));
         
         --dbms_output.put_line(SUBSTR(str_line,1,int_cutoff));
         int_index  := int_index + 1;
         int_offset := int_offset + int_cutoff;

      END LOOP;

   END clob2htp;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE all_tables(
       p_owner                   IN  VARCHAR2
      ,p_table_name              IN  VARCHAR2
      ,out_table_found           OUT BOOLEAN
      ,out_num_rows              OUT INTEGER
      ,out_last_analyzed         OUT TIMESTAMP
   )
   AS
   BEGIN
      SELECT
       a.num_rows
      ,a.last_analyzed 
      INTO 
       out_num_rows
      ,out_last_analyzed 
      FROM 
      all_tables a 
      WHERE 
          a.owner      = p_owner 
      AND a.table_name = p_table_name;
      
      out_table_found := TRUE;
 
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         out_table_found := FALSE;
         RETURN;
      WHEN OTHERS
      THEN
         RETURN;

   END all_tables;

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
   )
   AS
   BEGIN
      SELECT
       a.staleness 
      ,a.last_refresh_date 
      ,a.last_refresh_end_time
      ,a.last_refresh_type
      INTO 
       out_staleness
      ,out_last_refresh_date
      ,out_last_refresh_end_time
      ,out_last_refresh_type
      FROM 
      all_mviews a 
      WHERE 
          a.owner      = p_owner
      AND a.mview_name = p_mview_name;
      
      out_mview_found := TRUE;
      
      IF  out_last_refresh_date IS NOT NULL
      AND out_last_refresh_end_time IS NOT NULL
      THEN
         out_last_refresh_elapsed := out_last_refresh_end_time - out_last_refresh_date;
         
      END IF;

   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         out_mview_found := FALSE;
         RETURN;
      
      WHEN OTHERS
      THEN
         RETURN;
         
   END all_mviews;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION go_nogo(
      f                          IN  VARCHAR2 DEFAULT 'JSON'
   )
   RETURN CLOB
   AS
      str_extract_tag           VARCHAR2(4000 Char);
      str_start_day             VARCHAR2(4000 Char);
      str_stop_day              VARCHAr2(4000 Char);
      boo_valid                 BOOLEAN;         
      int_num_rows              INTEGER;
      dat_last_analyzed         DATE;
      str_staleness             VARCHAR2(4000 Char);
      dat_last_refresh_date     DATE;
      dat_last_refresh_end_time DATE;
      str_last_refresh_type     VARCHAR2(400 Char);
      inv_last_refresh_elapsed  INTERVAL DAY TO SECOND;
      inv_largest_refresh       INTERVAL DAY TO SECOND;
      dat_refresh_start         TIMESTAMP;
      dat_refresh_stop          TIMESTAMP;
      boo_table_found           BOOLEAN;
      boo_mview_found           BOOLEAN;
      ary_problems              attains_eq.string_array := attains_eq.string_array();
      int_index                 PLS_INTEGER := 1;
      str_results               VARCHAR2(4000 Char);
      
      FUNCTION get_hours(
         p_in   IN  INTERVAL DAY TO SECOND
      ) RETURN INTEGER
      AS
      BEGIN
         RETURN EXTRACT(DAY FROM (p_in)) * 24 + EXTRACT(HOUR FROM (p_in));

      END get_hours;
      
   BEGIN
   
      boo_valid := TRUE;
   
      -- Examine each materialized view
      FOR i IN 1 .. util.ary_profiles.COUNT
      LOOP
         all_tables(
             p_owner                   => 'ATTAINS_APP'
            ,p_table_name              => util.ary_profiles(i)
            ,out_table_found           => boo_table_found
            ,out_num_rows              => int_num_rows
            ,out_last_analyzed         => dat_last_analyzed
         );
         all_mviews(
             p_owner                   => 'ATTAINS_APP'
            ,p_mview_name              => util.ary_profiles(i)
            ,out_mview_found           => boo_mview_found
            ,out_staleness             => str_staleness
            ,out_last_refresh_date     => dat_last_refresh_date
            ,out_last_refresh_end_time => dat_last_refresh_end_time
            ,out_last_refresh_type     => str_last_refresh_type
            ,out_last_refresh_elapsed  => inv_last_refresh_elapsed
         );
         
         IF NOT boo_table_found
         THEN
            ary_problems.EXTEND();
            ary_problems(int_index) := util.ary_profiles(i) || ' not found in table metadata.';
            int_index := int_index + 1;
            boo_valid := FALSE;
            
         ELSE
            IF NOT boo_mview_found
            THEN
               ary_problems.EXTEND();
               ary_problems(int_index) := util.ary_profiles(i) || ' not found in mview metadata.';
               int_index := int_index + 1;
               boo_valid := FALSE;
               
            ELSE        
               IF str_last_refresh_type IS NULL
               THEN
                  ary_problems.EXTEND();
                  ary_problems(int_index) := util.ary_profiles(i) || ' has no refresh status.';
                  int_index := int_index + 1;
                  boo_valid := FALSE;
                  
               ELSIF str_last_refresh_type != 'COMPLETE'
               THEN
                  ary_problems.EXTEND();
                  ary_problems(int_index) := util.ary_profiles(i) || ' is marked ' || str_last_refresh_type || '.';
                  int_index := int_index + 1;
                  boo_valid := FALSE;
                  
               END IF;
               
            END IF;
            
         END IF;
         
         IF dat_last_refresh_date IS NOT NULL
         THEN
            IF dat_refresh_start IS NULL
            THEN
               dat_refresh_start := dat_last_refresh_date;
               
            ELSE
               IF dat_last_refresh_date < dat_refresh_start
               THEN
                  dat_refresh_start := dat_last_refresh_date;
                  
               END IF;
            
            END IF;
         
         END IF;
         
         IF dat_last_refresh_end_time IS NOT NULL
         THEN
            IF dat_refresh_stop IS NULL
            THEN
               dat_refresh_stop := dat_last_refresh_end_time;
               
            ELSE
               IF dat_last_refresh_end_time > dat_refresh_stop
               THEN
                  dat_refresh_stop := dat_last_refresh_end_time;
                  
               END IF;
            
            END IF;
         
         END IF;
         
         IF inv_last_refresh_elapsed IS NOT NULL
         THEN
            IF inv_largest_refresh IS NULL
            THEN
               inv_largest_refresh := inv_last_refresh_elapsed;
               
            ELSE
               IF inv_last_refresh_elapsed > inv_largest_refresh
               THEN
                  inv_largest_refresh := inv_last_refresh_elapsed;
                  
               END IF;
            
            END IF;
         
         END IF;
      
      END LOOP;
      
      IF dat_refresh_stop - dat_refresh_start > gonogo_hour_interval
      THEN
         ary_problems.EXTEND();
         ary_problems(int_index) := 'refresh spans larger than ' || TO_CHAR(get_hours(gonogo_hour_interval)) || ' hours.';
         int_index := int_index + 1;
         boo_valid := FALSE;
                  
      END IF;
      
      IF boo_valid
      THEN
         str_start_day := TO_CHAR(dat_refresh_start,'DD');
         str_stop_day  := TO_CHAR(dat_refresh_stop, 'DD');
         
         str_extract_tag := str_start_day || '/' || str_stop_day;
      
      END IF;
      
      IF f = 'VALS'
      THEN
         str_results := '';
         
         IF boo_valid
         THEN
            str_results := str_results || 'go';
            
         ELSE
            str_results := str_results || 'nogo';
         
         END IF;
         
         IF str_extract_tag IS NOT NULL
         THEN
            str_results := str_results || ' ' || str_extract_tag;
            
         END IF;
          
      ELSE
         str_results := '{"ready":';
         
         IF boo_valid
         THEN
            str_results := str_results || '"go"';
            
         ELSE
            str_results := str_results || '"nogo"';
         
         END IF;
         
         str_results := str_results || ',"tag":';
         
         IF str_extract_tag IS NOT NULL
         THEN
            str_results := str_results || '"' || str_extract_tag || '"';
            
         ELSE
            str_results := str_results || 'null';
         
         END IF;
         
         str_results := str_results || ',"problems":';
         
         IF ary_problems IS NULL
         OR ary_problems.COUNT = 0
         THEN
            str_results := str_results || '[]';
            
         ELSE
            str_results := str_results || '[';
            
            FOR i IN 1 .. ary_problems.COUNT
            LOOP
               str_results := str_results || '"' || ary_problems(i) || '"';
               
               IF i < ary_problems.COUNT
               THEN
                  str_results := str_results || ',';
               
               END IF;
         
            END LOOP;
            
            str_results := str_results || ']';
            
         END IF;
         
         str_results := str_results || '}';
         
      END IF;
      
      RETURN str_results;
   
   END go_nogo;

END util;
/

