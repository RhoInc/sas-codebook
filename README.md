# sas-codebook

This repo contains SAS<sup>&reg;</sup> code for producing a PDF summary of each variable in a dataset. Each variable summary is confined to a 1" tall strip, allowing for 9 variables to be summarized on a page. Metadata is provided for each variable in bold text. This metadata uncludes the variable's name, label, type, and (if applicable) format. Below the metadata are the number of non-missing values, the number of missing values, and the number of unique values.

Continuous variables are summarized graphically using a combination histogram/boxplot. Continuous variables are also summarized tabularly using the mean, standard deviation, min, max, median, and quartiles.
![sas-codebook continuous example](https://github.com/RhoInc/sas-codebook/blob/master/Continuous.PNG)
Categorical variables are summarized graphically using horizontal bar charts (or dot plots). Categorical variables are also summarized tabularly using counts and percents. 
![sas-codebook categorical example](https://github.com/RhoInc/sas-codebook/blob/master/Categorical.PNG)
