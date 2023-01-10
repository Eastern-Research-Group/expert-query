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

END util;
/

