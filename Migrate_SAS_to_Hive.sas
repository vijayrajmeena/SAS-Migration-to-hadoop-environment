
**********############################################################**********;
*  Begin Macro Migrate_SAS_to_Hive
**********############################################################**********;
%MACRO Migrate_SAS_to_Hive(Control_File_Location);
 
 
 
    /*   STARTING MACRO BUILDER SESSION...   */
 
 
 
    **********############################################################**********;
    *  Begin Macro customized_partitioned_columns
    **********############################################################**********;
    %MACRO customized_partitioned_columns;
		,'2013Plus' as fiscal_yr
    %MEND;
    **********############################################################**********;
    *  End Macro customized_partitioned_columns
    **********############################################################**********;
 
 
 
    **********############################################################**********;
    *  Begin Macro import_SAS_To_Hive_Guide
    **********############################################################**********;
    %MACRO import_SAS_To_Hive_Guide(sheetName);
     %timer;
     PROC IMPORT OUT      = SAS_To_Hive_Guide_&sheetName.
                 DATAFILE = "&Control_File_Location."
                 DBMS     = XLSX REPLACE;
                 SHEET    = "&sheetName.";
     RUN;
     %timer;
    %MEND import_SAS_To_Hive_Guide;
    **********############################################################**********;
    *  End Macro import_SAS_To_Hive_Guide
    **********############################################################**********;
  
 
 
    **********############################################################**********;
    *  Begin Macro store_all_observations
    **********############################################################**********;
    %MACRO store_all_observations(variable, dataset, separation);
     %GLOBAL &dataset.;
     PROC SQL NOPRINT;
        SELECT &variable. INTO :&dataset. SEPARATED BY &separation.
        FROM &dataset.
        WHERE &variable. IS NOT MISSING;
     QUIT;
    %MEND store_all_observations;
    **********############################################################**********;
    *  End Macro store_all_observations
    **********############################################################**********;
  
  
  
    **********############################################################**********;
    *  Begin Macro store_all_observations_w_quotes
    **********############################################################**********;
    %MACRO store_all_observations_w_quotes(variable, dataset, separation);
     %GLOBAL &dataset.;
     PROC SQL NOPRINT;
        SELECT DISTINCT CAT("'",STRIP(&variable.),"'") INTO :&dataset. SEPARATED BY &separation.
        FROM &dataset.
        WHERE &variable. IS NOT MISSING;
     QUIT;
    %MEND store_all_observations_w_quotes;
    **********############################################################**********;
    *  End Macro store_all_observations_w_quotes
    **********############################################################**********;
 
 
 
    **********############################################################**********;
    *  Begin Macro filter_dataset_name
    **********############################################################**********;
    %MACRO filter_dataset_name;
        WHERE UPCASE(MEMNAME) eq "&source."
		AND   UPCASE(MEMNAME) CONTAINS "_&year_to_migrate."
		;
    %MEND filter_dataset_name;
    **********############################################################**********;
    *  End Macro filter_dataset_name
    **********############################################################**********;
 

	 **********############################################################**********;
    *  Begin Macro filter_dataset_name_all
    **********############################################################**********;
    %MACRO filter_dataset_name_all;
        WHERE UPCASE(MEMNAME) eq "&source."
		AND   UPCASE(MEMNAME) CONTAINS '2013PLUS'
/*		AND */
/*		(*/
/*		UPCASE(MEMNAME) LIKE '%CLPB%'*/
/*		OR UPCASE(MEMNAME) LIKE '%CLPD%'*/
/*		OR UPCASE(MEMNAME) LIKE '%CLPN%'*/
/*		)*/
        ;
    %MEND filter_dataset_name_all;
    **********############################################################**********;
    *  End Macro filter_dataset_name_all
    **********############################################################**********;
 
 
    **********############################################################**********;
    *  Begin Macro hive_creation_and_insertion
    **********############################################################**********;
    %MACRO hive_creation_and_insertion(source_dataset, year_to_migrate);
        OPTIONS NONOTES;
        ***************************************************************************
        *   Truncate dataset name to make sure that after we prepend 'STG_' to it,
        *   the new name will not exceed 32 characters
        ***************************************************************************;
        DATA _NULL_;
            IF LENGTH("&source_dataset") >=29 THEN DO;
                STG_source_dataset = SUBSTR("&source_dataset.", LENGTH("&source_dataset.")-27, 28);
                CALL SYMPUT('STG_source_dataset', CAT('STG_', STG_source_dataset));
            END;
            ELSE DO;
                CALL SYMPUT('STG_source_dataset', CAT('STG_', "&source_dataset."));
            END;
        RUN;
 
        ***************************************************************************
        *   Create customized macros &RUN_NUMBER. and &YEAR_MONTH. for later use.
        ***************************************************************************;
		/*
		DATA _NULL_;
            SECTIONCOUNT = COUNTW("&source_dataset.",'_');
            RUN_NUMBER = SUBSTR(SCAN("&source_dataset.",SECTIONCOUNT,'_'),4,2);
            YEAR_MONTH = SCAN("&source_dataset.",SECTIONCOUNT-1,'_');
            CALL SYMPUTX('RUN_NUMBER', RUN_NUMBER);
            CALL SYMPUTX('YEAR_MONTH', YEAR_MONTH);
        RUN;
 		*/
        ********************************************************************************
        *  Create SOURCE_DATASET that stores information from &SAS_Lib..&dataset.
        ********************************************************************************;
        PROC CONTENTS DATA=&SAS_Lib..&source_dataset. OUT=SOURCE_DATASET NOPRINT;
        RUN;
 
        ********************************************************************************
        *  Create a DISTINCT dataset that only has one variable: NAME
        ********************************************************************************;
        PROC SQL;
            CREATE TABLE SOURCE_DATASET_SELECTED AS
                SELECT DISTINCT UPCASE(NAME) AS NAME
                FROM SOURCE_DATASET;
        QUIT;
 
        ********************************************************************************
        *   Store all observations from SOURCE_DATASET_SELECTED dataset
        *   into macro &SOURCE_DATASET_SELECTED.
        ********************************************************************************;
        %store_all_observations_w_quotes(NAME, SOURCE_DATASET_SELECTED, ',');
 
        ********************************************************************************
        *  Create a dataset that contains mismatched variables.
        ********************************************************************************;
        PROC SQL;
            CREATE TABLE DATASET_ANALYSIS_4 AS
                SELECT NAME,
                       TYPE,
                       UNIQUE_ID
                FROM DATASET_ANALYSIS_2
                WHERE UPCASE(NAME) NOT IN (&SOURCE_DATASET_SELECTED.);
        QUIT;
  
        ********************************************************************************
        *  Store all observations from DATASET_ANALYSIS_4 dataset
        *  into macro &DATASET_ANALYSIS_4.
        ********************************************************************************;
        %store_all_observations_w_quotes(NAME, DATASET_ANALYSIS_4, ',');
  
        *************************************************************************************
        *  Update DATASET_ANALYSIS_4 to add either '.' or ' ' to the mismatched variables.
        *************************************************************************************;
        DATA DATASET_ANALYSIS_4;
            SET DATASET_ANALYSIS_4;
            IF TYPE = 1 THEN DO;
                NAME = CAT("."," ", "AS", " " ,NAME);
            END;
            ELSE DO;
                NAME = CAT("' '"," ", "AS", " " ,NAME);
            END;
        RUN;
 
        ********************************************************************************
        *  Count the number of observations then store it into macro &nobs.
        ********************************************************************************;
        DATA _NULL_;
            DSID = OPEN('DATASET_ANALYSIS_4');
            OBSCOUNT = ATTRN(DSID,'nlobs');
            RC = CLOSE(DSID);
            CALL SYMPUTX('nobs', OBSCOUNT);
        RUN;
 
        ********************************************************************************
        *  Create a dataset that has all of the variables needed for the insertion
        ********************************************************************************;
        PROC SQL;
            CREATE TABLE DATASET_ANALYSIS_5 AS
                SELECT NAME,
                       UNIQUE_ID
                FROM DATASET_ANALYSIS_2
                /*   If there is nothing in &DATASET_ANALYSIS_4. meaning that
                     there are no differences between the datasets to compare   */
                %IF &nobs. = 0 %THEN %DO;
                    /*   We do nothing here   */
                %END;
                %ELSE %DO;
                    WHERE NAME NOT IN (&DATASET_ANALYSIS_4.);
                %END;
        QUIT;
  
        ********************************************************************************
        *  Merge DATASET_ANALYSIS_4 and DATASET_ANALYSIS_5 into DATASET_ANALYSIS_6
        ********************************************************************************;
        DATA DATASET_ANALYSIS_6(KEEP=NAME UNIQUE_ID);
            SET DATASET_ANALYSIS_5
                DATASET_ANALYSIS_4;
        RUN;
  
        ********************************************************************************
        *  Sort dataset DATASET_ANALYSIS_6 by UNIQUE_ID
        ********************************************************************************;
        PROC SORT DATA=DATASET_ANALYSIS_6;
            BY UNIQUE_ID;
        RUN;
  
        ********************************************************************************
        *   Store all observations from DATASET_ANALYSIS_6 dataset
        *   into macro &DATASET_ANALYSIS_6.
        ********************************************************************************;
        %store_all_observations(NAME, DATASET_ANALYSIS_6, ',');
 
 
 
        /*   STEP 2: CREATING AN EMPTY STAGING TABLE IN HIVE   */
 
 
 
        ********************************************************************************
        *  Delete the staging table if already exists THEN create a new staging table
        ********************************************************************************;
        %IF %SYSFUNC(EXIST(&Hive_Lib..&STG_source_dataset.)) %THEN %DO;
            PROC SQL;
                DROP TABLE &Hive_Lib..&STG_source_dataset.;
            QUIT;
        %END;
  
        PROC SQL;
         CONNECT TO HADOOP (USER="&userid." PASSWORD="&spwd." SERVER=&server.
                            PORT=&port. SCHEMA=DEFAULT SUBPROTOCOL=hive2 CFG="&f360cfg.");
         EXECUTE
            (CREATE TABLE IF NOT EXISTS &Hive_Lib..&STG_source_dataset.
                (&DATASET_ANALYSIS_3.,
                 &PARTITION_COLUMNS_W_STRING.
                )
                ROW FORMAT DELIMITED
                /*FIELDS TERMINATED BY '|' ESCAPED BY '\\'*/
                STORED AS TEXTFILE
                TBLPROPERTIES ('SAS OS Name'='Linux'
                               ,'SAS Version'='9.04.01M1P12042013'
                               &TBLPROPERTIES_FIELDS.)
            )BY HADOOP;
         DISCONNECT FROM HADOOP;
        QUIT;
 
 
 
        /*   STEP 3: INSERTING DATA FROM SAS TO HIVE STAGING TABLE   */
 
 
 
        ***************************************************************************
        *  Insert existing dataset from SAS library into staging table in Hive
        ***************************************************************************;
        PROC SQL NOWARN;
            INSERT INTO &Hive_Lib..&STG_source_dataset.
            SELECT &DATASET_ANALYSIS_6.
                   %customized_partitioned_columns
            FROM &SAS_Lib..&source_dataset.;
        QUIT;
        OPTIONS NOTES;
 
 
 
        /*   STEP 4: INSERTING DATA FROM STAGING TABLE TO FINAL TABLE IN HIVE   */
 
 
 
        ***************************************************************************
        *  Insert staging table to final table in Hive
        ***************************************************************************;
        PROC SQL;
            CONNECT TO HADOOP (USER="&userid." PASSWORD="&spwd." SERVER=&server.
                               PORT=&port. SCHEMA=DEFAULT SUBPROTOCOL=hive2 CFG="&f360cfg");
            EXECUTE (SET hive.exec.dynamic.partition=TRUE) BY HADOOP;
 
            EXECUTE (SET hive.exec.dynamic.partition.mode=NONSTRICT) BY HADOOP;
 
            EXECUTE (INSERT INTO TABLE &Hive_Lib..&Hive_Final_Table_Name.
                     PARTITION (&PARTITION_COLUMNS.)
                     SELECT *
                     FROM &Hive_Lib..&STG_source_dataset.) BY HADOOP;
            DISCONNECT FROM HADOOP;
        QUIT;
 
        *************************************************************************************
        *  Drop staging table when we finish migrating everything from staging to final table
        *  <   Only drop IF the flag macro &CleanUp_Stage. is Y   >
        *************************************************************************************;
		/*
		%IF &CleanUp_Stage. = Y %THEN %DO;
            PROC SQL;
                DROP TABLE &Hive_Lib..&STG_source_dataset.;
            QUIT;
        %END;
 		*/
        ******************************************************************************************
        *   Send an email confirmation when the process is done for each dataset migrated from SAS
        ******************************************************************************************;
		%send_email(process = Hadoop - &Project. - Migration - Group: [&source.],
                    tolist  = &tolist.,
                    msg     = %bquote(<br><font color=blue>Hadoop &Project. Migration has completed
                                      <br><br>for SAS dataset: [&source_dataset.].</font>)
                    );
        %timer(reset);
	%MEND;
    **********############################################################**********;
    *  End Macro hive_creation_and_insertion
    **********############################################################**********;
 
 
 
    **********############################################################**********;
    *  Begin Macro Process_Source_Dataset
    **********############################################################**********;
    %MACRO Process_Source_Dataset(source,
                                  year_to_migrate,
                                  Project,
                                  Hive_Final_Table_Name);
        ********************************************************************************
        *   Get a list of all partition columns
        ********************************************************************************;
        PROC SQL;
            CREATE TABLE PARTITION_COLUMNS AS
                SELECT 
					DISTINCT
						UPCASE(Partition_Column)       AS Partition_Column,
                    	Partition_TBLPROPERTIES_Format AS Partition_TBLPROPERTIES_Format
                FROM SAS_TO_HIVE_GUIDE_STAGING_N_DATA
                WHERE UPCASE(SAS_Source_Dataset) = %UPCASE("&source.");
        QUIT;
 
        ********************************************************************************
        *   Store all observations from PARTITION_COLUMNS dataset
        *   into macro &PARTITION_COLUMNS.
        ********************************************************************************;
        %store_all_observations(Partition_Column, PARTITION_COLUMNS, ",");
 
        ********************************************************************************
        *   Create a dataset that stores Partition_Column concatenating with 'STRING'
        ********************************************************************************;
        DATA PARTITION_COLUMNS_W_STRING(KEEP=Partition_Column_W_String);
            SET PARTITION_COLUMNS;
            Partition_Column_W_String = CAT(Partition_Column, ' ', 'STRING');
        RUN;
 
        ********************************************************************************
        *   Store all observations from PARTITION_COLUMNS_W_STRING dataset
        *   into macro &PARTITION_COLUMNS_W_STRING.
        ********************************************************************************;
        %store_all_observations(Partition_Column_W_String, PARTITION_COLUMNS_W_STRING, ",");
 
        ********************************************************************************
        *  Create LIBINFO and FICH_DSN datasets that store information from &SAS_Lib.
        ********************************************************************************;
        %libinfo(&SAS_Lib.);
  
        ***************************************************************************
        *  Collect all variables across &source. 
        ***************************************************************************;
        DATA DATASET_ANALYSIS_1(KEEP=NAME TYPE FORMAT LENGTH);
            SET FICH_DSN;
            IF PRXMATCH("/MMDD|MMYY|YYDD|YYMM|DDMM|DDYY|DATE|TIME/", UPCASE(FORMAT)) THEN DO;
            END;
            ELSE DO;
                FORMAT = '';
            END;
            NAME = LOWCASE(NAME);
            %filter_dataset_name_all
        RUN;
 
        ***************************************************************************
        *  Remove duplicates and sort DATASET_ANALYSIS_1 by NAME and TYPE
        ***************************************************************************;
        PROC SORT DATA = DATASET_ANALYSIS_1 OUT=DATASET_ANALYSIS_1_TEMP NODUPKEY;
            BY NAME TYPE;
        RUN;
 
        ***************************************************************************
        *  Exclude those partition columns from DATASET_ANALYSIS_1
        ***************************************************************************;
        PROC SQL;
            CREATE TABLE DATASET_ANALYSIS_1 AS
                SELECT *
                FROM DATASET_ANALYSIS_1_TEMP
                WHERE UPCASE(NAME) NOT IN (SELECT Partition_Column
                                           FROM PARTITION_COLUMNS);
        QUIT;
 
        ***************************************************************************
        *  Data type conversion from SAS to Hive
        ***************************************************************************;
        DATA DATASET_ANALYSIS_2;
            SET DATASET_ANALYSIS_1;
            FORMAT HIVE_DATA_TYPE $20.;
            /*   Here, the UNIQUE_ID is used to keep the variables in order and 
                 consistent across all datasets within a group.   */
            UNIQUE_ID + 1;
            IF TYPE = 1 THEN DO;
                IF PRXMATCH("/MMDD|MMYY|YYDD|YYMM|DDMM|DDYY|DATE|TIME/", UPCASE(FORMAT)) THEN DO;
                    HIVE_DATA_TYPE = 'STRING';
                    IF PRXMATCH("/DATETIME/", UPCASE(FORMAT)) THEN DO;
                        TBLPROPERTIES_FORMAT = CAT(",'SASFMT:", UPCASE(STRIP(NAME)), "'='", "DATETIME(25.6)'");
                    END;
                    ELSE IF PRXMATCH("/TIME/", UPCASE(FORMAT)) THEN DO;
                        TBLPROPERTIES_FORMAT = CAT(",'SASFMT:", UPCASE(STRIP(NAME)), "'='", "TIME(25.6)'");
                    END;
                    ELSE DO;
                        TBLPROPERTIES_FORMAT = CAT(",'SASFMT:", UPCASE(STRIP(NAME)), "'='", "DATE(9.0)'");
                    END;
                END;
                ELSE DO;
                    HIVE_DATA_TYPE = 'DOUBLE';
                END;
            END;
            ELSE IF TYPE = 2 THEN DO;
                HIVE_DATA_TYPE = "VARCHAR" || "(" || CAT(LENGTH) || ")";
            END;
        RUN;
 
        ***************************************************************************
        *   Create a DISTINCT dataset that has TBLPROPERTIES FORMAT from
        *   DATASET_ANALYSIS_2 for Hive data types
        ***************************************************************************;
        PROC SQL;
            CREATE TABLE TBLPROPERTIES_FIELD_1 AS
                SELECT DISTINCT TBLPROPERTIES_FORMAT
                FROM DATASET_ANALYSIS_2
                WHERE TBLPROPERTIES_FORMAT IS NOT MISSING;
        QUIT;
 
        ***************************************************************************
        *   Put Partition field(s) into the right TBLPROPERTIES FORMAT
        ***************************************************************************;
        DATA TBLPROPERTIES_FIELD_2(KEEP=TBLPROPERTIES_FORMAT);
            SET PARTITION_COLUMNS;
            TBLPROPERTIES_FORMAT = CAT(",'SASFMT:", STRIP(Partition_Column), "'='"
                                       ,STRIP(Partition_TBLPROPERTIES_Format), "'");
        RUN;
 
        ***************************************************************************
        *   Merge two datasets (Hive data types and partition fields) together
        ***************************************************************************;
        DATA TBLPROPERTIES_FIELDS;
            SET TBLPROPERTIES_FIELD_1
                TBLPROPERTIES_FIELD_2;
        RUN;
 
        ***************************************************************************
        *   Store all observations from TBLPROPERTIES_FIELDS dataset
        *   into macro &TBLPROPERTIES_FIELDS.
        ***************************************************************************;
        %store_all_observations(TBLPROPERTIES_FORMAT, TBLPROPERTIES_FIELDS, " ");
 
        ***************************************************************************
        *  Create a dataset that stores info that will be fed into the process
        *  of creating staging and final tables.
        ***************************************************************************;
        DATA DATASET_ANALYSIS_3(KEEP=HIVE_DATA_TYPE_CAT);
            SET DATASET_ANALYSIS_2;
            HIVE_DATA_TYPE_CAT = CAT(NAME, ' ', HIVE_DATA_TYPE);
        RUN;
  
        ********************************************************************************
        *   Store all observations from DATASET_ANALYSIS_3 dataset
        *   into macro &DATASET_ANALYSIS_3.
        ********************************************************************************;
        %store_all_observations(HIVE_DATA_TYPE_CAT, DATASET_ANALYSIS_3, ',');
 
        ***************************************************************************
        *  Create a list of all datasets to migrate from SAS
        ***************************************************************************;
        DATA LIBINFO;
            SET LIBINFO;
            %filter_dataset_name
        RUN;
 
 
 
        /*   STEP 1: CREATING A FINAL TABLE IN HIVE   */
 
 
 
        ***************************************************************************
        *  Create a final table in Hive
        ***************************************************************************;
        PROC SQL;
         CONNECT TO HADOOP (USER="&userid." PASSWORD="&spwd." SERVER=&server.
                            PORT=&port. SCHEMA=DEFAULT SUBPROTOCOL=hive2 CFG="&f360cfg.");
         EXECUTE
            (CREATE TABLE IF NOT EXISTS &Hive_Lib..&Hive_Final_Table_Name.
                (&DATASET_ANALYSIS_3.) 
                PARTITIONED BY (&PARTITION_COLUMNS_W_STRING.)
                STORED AS ORC
                TBLPROPERTIES ("orc.compress"="SNAPPY"
                               ,'SAS OS Name'='Linux'
                               ,'SAS Version'='9.04.01M1P12042013'
                               &TBLPROPERTIES_FIELDS.)
            ) BY HADOOP;
         DISCONNECT FROM HADOOP;
        QUIT;
 
 
 
        /*   STEP 2 - 4   */
 
 
 
        ********************************************************************************
        *   Step 2: Creating an empty staging table in Hive
        *   Step 3: Inserting data from SAS to Hive staging table
        *   Step 4: Inserting data from staging table to final table in Hive
        ********************************************************************************;
        DATA _NULL_;
            SET LIBINFO;
            CALL EXECUTE('%nrstr(%hive_creation_and_insertion('||STRIP(memname)||',
                                                              '||"&year_to_migrate."||'));');
        RUN;
    %MEND;
    **********############################################################**********;
    *  End Macro Process_Source_Dataset
    **********############################################################**********;
 
 
 
    /*   ...ENDING MACRO BUILDER SESSION   */
 
 
 
    ********************************************************************************
    *   Import Excel spreadsheets into WORK DATASETS
    ********************************************************************************;
    %import_SAS_To_Hive_Guide(Set_Up);
    %import_SAS_To_Hive_Guide(Staging_N_Data);
 
    ********************************************************************************
    *   Get the needed values from SAS_TO_HIVE_GUIDE_SET_UP
    ********************************************************************************;
    DATA _NULL_;
        SET SAS_To_Hive_Guide_Set_Up;
        IF _N_ = 1 THEN DO;
            CALL SYMPUTX('server',        STRIP(Server));
            CALL SYMPUTX('port',          STRIP(Port));
            CALL SYMPUTX('f360cfg',       STRIP(f360cfg));
            CALL SYMPUTX('SAS_Lib',       STRIP(UPCASE(SAS_Lib)));
            CALL SYMPUTX('Hive_Lib',      STRIP(UPCASE(Hive_Lib)));
            CALL SYMPUTX('Project',       STRIP(UPCASE(Project)));
            CALL SYMPUTX('CleanUp_Stage', STRIP(UPCASE(CleanUp_Stage)));
        END;
    RUN;
 
    **********************************************************************
    *   Get a list of email(s)
    **********************************************************************;
	
    PROC SQL NOPRINT;
        SELECT DISTINCT CAT("'",STRIP(Email_List),"'") INTO :tolist SEPARATED BY " "
        FROM SAS_To_Hive_Guide_Set_Up
        WHERE Email_List IS NOT MISSING;
    QUIT;
 	
    ********************************************************************************
    *   Set up Libname
    ********************************************************************************;
    LIBNAME &Hive_Lib. HADOOP SERVER=&server. PORT=&port. SCHEMA=&Hive_Lib.
        USER="&userid" PASSWORD="&spwd" SUBPROTOCOL=hive2 CFG="&f360cfg.";
    %timer;
 
    ********************************************************************************
    *   Create a list of all SAS_Source_Dataset to migrate from SAS
    ********************************************************************************;
    PROC SQL;
        CREATE TABLE DATASET_TO_MIGRATE AS
            SELECT DISTINCT UPCASE(SAS_Source_Dataset)    AS SAS_Source_Dataset,
                            Year_To_Migrate               AS Year_To_Migrate,
                            UPCASE(Hive_Final_Table_Name) AS Hive_Final_Table_Name
        FROM SAS_TO_HIVE_GUIDE_STAGING_N_DATA
        WHERE SAS_Source_Dataset IS NOT MISSING 	
		AND Hive_Final_Table_Name IS NOT MISSING;
    QUIT;
 
    ********************************************************************************
    *   Run all Source_Table observations from DATASET_TO_MIGRATE
    ********************************************************************************;
    DATA _NULL_;
        SET DATASET_TO_MIGRATE;
        CALL EXECUTE('%nrstr(%Process_Source_Dataset('||STRIP(SAS_Source_Dataset)||',
                                                     '||STRIP(Year_To_Migrate)||',
                                                     '||"'"||"&Project."||"'"||',
                                                     '||STRIP(Hive_Final_Table_Name)||'));');
    RUN;
%MEND Migrate_SAS_to_Hive;
**********############################################################**********;
*  End Macro Migrate_SAS_to_Hive
**********############################################################**********;
