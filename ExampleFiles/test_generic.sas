*---------- tell SAS where you put everything ----------;

%let zippath = H:\GitHub\sas-codebook;
options sasautos=("&zippath\Macros" sasautos);
libname examples "&zippath\ExampleFiles";

*---------- run the macro on the local copy of the CARS dataset ----------;

%codebook_generic(data=examples.cars)
