*--------------------------------------------------------------------------------;
*---------- tell SAS where macros live ----------;
*--------------------------------------------------------------------------------;

%let macpath1 = H:\GitHub\sas-codebook;
%let macpath2 = H:\GitHub\sas-codebook\HelperMacros;

options sasautos=("&macpath1" "&macpath2" sasautos);



*--------------------------------------------------------------------------------;
*---------- call the macro ----------;
*--------------------------------------------------------------------------------;

%let pdfpath = H:\GraphicsGroup\Repository\dev\projects\165\gists;

%codebook_generic
   (data=sashelp.cars
   ,pdfpath=&pdfpath
   );