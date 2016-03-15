*--------------------------------------------------------------------------------;
*---------- tell SAS where the macros live ----------;
*--------------------------------------------------------------------------------;

%let macpath = H:\GitHub\sas-codebook;

options sasautos=("&macpath\Macros" sasautos);



*--------------------------------------------------------------------------------;
*---------- call the macro ----------;
*--------------------------------------------------------------------------------;

libname examples "H:\GitHub\sas-codebook\ExampleFiles";

%codebook_generic(data=examples.cars)
