# sas-codebook

This repo contains a SAS macro which provides a PDF summary of each variable in a dataset. Each variable summary is confined to a 1" tall strip. Metadata is provided for each variable in bold text. This metadata uncludes the variable's name, label, type, and (if applicable) format. Below the metadata are the number of non-missing values, the number of missing values, and the number of unique values.

Continuous variables are summarized graphically using a combination histogram/boxplot. Continuous variables are also summarized tabularly using the mean, standard deviation, min, max, median, and quartiles.
![continuous strip](https://github.com/RhoInc/sas-codebook/blob/master/Continuous.PNG)
Categorical variables are summarized graphically using horizontal bar charts (or dot plots). Categorical variables are also summarized tabularly using counts and precents. 
![categorical strip](https://github.com/RhoInc/sas-codebook/blob/master/Categorical.PNG)

