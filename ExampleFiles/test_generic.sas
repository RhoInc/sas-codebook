*--------------------------------------------------------------------------------;
*---------- tell SAS where macros live ----------;
*--------------------------------------------------------------------------------;

%let macpath = H:\GitHub\sas-codebook;

options sasautos=("&macpath" "&macpath\HelperMacros" sasautos);



*--------------------------------------------------------------------------------;
*---------- call the macro ----------;
*--------------------------------------------------------------------------------;

%let pdfpath = H:\GraphicsGroup\Repository\dev\projects\165\gists;

%codebook_generic
   (data=sashelp.cars
   ,pdfpath=&pdfpath
   );