# SAS-Migration-to-hadoop-environment
A script to migrate historical SAS data sets to Hadoop. The main components will add attributes to the dataset from the dataset name to use for partitioning in Hadoop. Tables with the same layout should be added as one data table in Hadoop.

Follow the "SAS_To_Hive_Guide - Copy.xlsx"
and do the requiered modification!
How to use the macro (Migrate_SAS_to_Hive.sas):
Step 1: Update macro statement %filter_dataset_name
Step 2: Update macro statement %customized_partitioned_columns


Notes:
Data_Path is the path to store summary and comparison report for tieout
How to use the macros (Summarize_dollar_amounts.sas and
Compare_all_data.sas):
Step 1: Update macro statement %filter_dataset_name
Step 2: Update macro statement %get_partition_field
Step 3: Update field(s) for key word: customize

