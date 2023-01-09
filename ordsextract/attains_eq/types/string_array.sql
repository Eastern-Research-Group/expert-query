CREATE OR REPLACE TYPE attains_eq.string_array
AS VARRAY(1000) OF VARCHAR2(4000 Char);

GRANT EXECUTE ON attains_eq.string_array TO PUBLIC;

