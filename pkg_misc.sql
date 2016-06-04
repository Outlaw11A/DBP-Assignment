CREATE OR REPLACE PACKAGE pkg_misc AS
    PROCEDURE show_file(p_location VARCHAR2, p_file VARCHAR2);
    PROCEDURE clear_file(p_location VARCHAR2, p_file VARCHAR2);
    PROCEDURE delete_file(p_location VARCHAR2, p_file VARCHAR2);
END pkg_misc;

CREATE OR REPLACE PACKAGE BODY pkg_misc as
  PROCEDURE show_file(p_location VARCHAR2, p_file VARCHAR2) IS
    openFile utl_file.file_type := utl_file.fopen(p_location, p_file, 'R');
    line VARCHAR2(2000);
    BEGIN
      LOOP
        utl_file.get_line(openFile, line);
        dbms_output.put_line(line);
      END LOOP;
      EXCEPTION
        WHEN OTHERS THEN utl_file.fclose(openFile);
    END;

  PROCEDURE clear_file(p_location VARCHAR2, p_file VARCHAR2) IS
    v_file utl_file.file_type;
    BEGIN
      v_file := utl_file.fopen(p_location, p_file, 'W');
      utl_file.put_line(v_file, '');
      utl_file.fclose(v_file);
    END;

  PROCEDURE delete_file(p_location VARCHAR2, p_file VARCHAR2) IS
    BEGIN
      utl_file.fremove(p_location, p_file);
    END;

END pkg_misc;