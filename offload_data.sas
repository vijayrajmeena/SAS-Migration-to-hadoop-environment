 
**********************************************************************
*   Please update macro &Control_File_Location.
**********************************************************************;
%LET Control_File_Location = /sasnas/ovations/fic/phi2/inf/Control_File/SAS_To_Hive_Guide.xlsx;
 
**********************************************************************
*   Set up environments
**********************************************************************;
OPTIONS SASTRACE=',,,d' SASTRACELOC=SASLOG NOSTSUFFIX;
%get_system_credentials(SOURCE="hadoop", ENVIR="&env.");
 
**********************************************************************
*   Import Excel file in order to get the value for &prj.
**********************************************************************;
PROC IMPORT OUT      = SAS_To_Hive_Guide_Set_Up
            DATAFILE = "&Control_File_Location."
            DBMS     = XLSX REPLACE;
            SHEET    = 'Set_Up';
RUN;
 
**********************************************************************
*   Get the value for &prj.
**********************************************************************;
DATA _NULL_;
    SET SAS_To_Hive_Guide_Set_Up;
    IF _N_ = 1 THEN DO;
        CALL SYMPUTX('prj', LOWCASE(Project));
    END;
RUN;
 
***********************************************************************************************
*   A call to macro %Migrate_SAS_to_Hive.
***********************************************************************************************;
%include "/hpsasfin/&env./users/&userid./projects/hdp/mig/&prj./macros/Migrate_SAS_to_Hive.sas";
 
**********************************************************************
*   Derive Dates
**********************************************************************;
DATA _NULL_;
 CALL SYMPUTX('START_TIME',DATETIME());
RUN;
 
******************************************************************************************
*   Pass the Control_File's path to macro %Migrate_SAS_to_Hive
******************************************************************************************;
%Migrate_SAS_to_Hive(&Control_File_Location.);
  
********************************************************************************
*   DISPLAY RUN TIMES
********************************************************************************;
DATA _NULL_;
 START_TIME = &START_TIME.;
 END_TIME = DATETIME();
 ELAPSED = END_TIME - START_TIME;
 PUT 'NOTE:      Start Time (HH:MM) = ' START_TIME TIMEAMPM8.;
 PUT 'NOTE:        End Time (HH:MM) = ' END_TIME TIMEAMPM8.;
 PUT 'NOTE: Elapsed Time (HH:MM:SS) = ' ELAPSED TIME.;
RUN;
  
**********************************************************************
**********************************************************************
*   END OF PROGRAM
**********************************************************************
**********************************************************************;

