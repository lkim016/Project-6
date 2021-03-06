### Project 6
## Lori Kim

setwd("/Volumes/LEXAR/DATA SCIENCE/Projects/Project 7")

#install.packages("dplyr")
#install.packages("rlang")
#install.packages("mice")

library(rlang)
library(readxl)
library(dplyr)
library(ggplot2)
library(data.table)
library(tidyr)
library(randomForest)
library(pls)
library(plm)
library(foreign)
library(zoo)
library(forecast)
library(tseries)
library(ggplot2)
library(stringr)
library(caret)
library(MASS)
library(glmnet)

select = dplyr::select # clash of function with MASS package

bank = read_excel("W03b_wdi.xlsx")

# Main Problem: identify what is the strongest correlated variable and make a prediction
# Process:

# project purpose -> predict the main goal indicator:
# poverty gap at $3.2 a day (2011 PPP, %; code: SI.POV.LMIC.GP)
# for those countries that have available data in 2012
# PPP = purchasing power parity -> one popular metric for comparing economic productivity and standards of living between countries and across time
  
# analyze indicators
  
# subset by main goal indicator, train data = 1981-2012 (32 yrs), test data = 2013-2016 (4 yrs)
resp = "SI.POV.LMIC.GP"
yrs = 1981:2017
wdi.bank = bank %>%
  select(one_of(c("Country Name","Country Code", "Indicator Name", "Indicator Code", yrs)))
yrs = paste("x", yrs, sep = "")
colnames(wdi.bank) = c("country.name","country.code","indicator.name","indicator.code", yrs) # renaming the cols

# filter out regions, non-country data rows
rm.regions = c("ARB","CEB","CSS","EAP","EAR","EAS","ECA","ECS","EUU","HIC","HPC","IBD","IBT","IDA","IDX",
          "LAC","LCN","LDC","LIC","LMC","LMY","MEA","MIC","MNA","NAC","OED","OSS","PRE","PSS","PST",
          "SAS","SSA","SSF","SST","TEA","TEC","TLA","TMN","TSA","UMC","WLD")


ppp3.2 = wdi.bank %>% filter(!country.code %in% rm.regions) # filtered regions and years df
low.ppp = ppp3.2 %>% filter(indicator.code %in% resp) # filter by poverty gap at $3.20 / day
ppp12 = low.ppp %>% filter(!x2012 %in% NA) # get only the 2012 data that is !NA
ppp12.list = ppp12$country.code %>% table() %>% names() # pull the list of the countries that have the 2012 data in SI.POV.LMIC.GP
wdi.bank.pov = wdi.bank %>% filter(country.code %in% ppp12.list) # filter main data with the countries in 2012 list
# transposing indicator names with years
wdi.bank.povt=dcast(melt(as.data.table(wdi.bank.pov), id.vars = c("country.name", 
               "country.code","indicator.name", "indicator.code")), 
               country.name + country.code + variable ~ indicator.code, value.var = "value")

# Calculating missing values percentage
missing <- wdi.bank.povt %>% summarize_all(funs(sum(is.na(.))/n()))
missing <- gather(missing, key="feature", value="missing_pct")
good.var <- filter(missing, missing_pct<0.25) # gathering the columns with NA < 0.25

# filtering the main dataset to only have the good variable columns
final.povt = wdi.bank.povt %>% select(one_of(c(good.var$feature, resp)))
final.povt$variable = as.numeric(gsub("x", "", paste(final.povt$variable)) ) # changing variable (year) to number

# filter data w/ countries that have poverty > 25
# choose sample throughout the poverty range using quantiles
summary(ppp12$x2012)
max.pov = ppp12 %>% filter(x2012 == 58) # Congo
third.q.pov = ppp12 %>% filter(x2012 == 4.3) # Peru
med.pov = ppp12 %>% filter(x2012 == 1 & country.name == "Latvia") # Latvia
first.q.pov = ppp12 %>% filter(x2012 == 0.2 & country.name == "Thailand") # Thailand
min.pov = ppp12 %>% filter(x2012 == 0 & country.name == "Belarus") # Belarus

# combine the countries with poverty as a list into a df
sample.list = rbind(max.pov, third.q.pov)
sample.list = rbind(sample.list, med.pov)
sample.list = rbind(sample.list, first.q.pov)
sample.list = rbind(sample.list, min.pov)
list = sample.list$country.name

######## THIS IS THE WHOLE IMPUTATION AND VARIABLE PROCESS CHECKING FOR THE 5 COUNTRIES with HIGHEST POVERTY
# imputation / extrapolation (linear extrapolation)
# I impute the NAs with the mean of the columns so that I don't shift the standard deviation

#### CONGO
num = final.povt %>% filter(country.name == list[1]) %>%
  select(-one_of(c("country.name", "country.code", "variable")))
info = final.povt %>% filter(country.name == list[1]) %>%
  select(one_of(c("country.code", "variable")))

impute = function(df) {
  means = colMeans(num, na.rm = T)
  for (j in 1:ncol(df))
    set(df, which(is.na(df[[j]])), j, means[j])
}

impute(num)

data = cbind(info, num)
tr.data = data %>% filter(variable %in% 1981:2012)
tst.data = data %>% filter(variable %in% 2013:2016)


#### PERU
num = final.povt %>% filter(country.name == list[2]) %>%
  select(-one_of(c("country.name", "country.code", "variable")))
info = final.povt %>% filter(country.name == list[2]) %>%
  select(one_of(c("country.code", "variable")))

impute = function(df) {
  means = colMeans(num, na.rm = T)
  for (j in 1:ncol(df))
    set(df, which(is.na(df[[j]])), j, means[j])
}

impute(num)

data = cbind(info, num)
tr.data1 = data %>% filter(variable %in% 1981:2012)
tst.data1 = data %>% filter(variable %in% 2013:2016)

tr.data = rbind(tr.data,tr.data1)
tst.data = rbind(tst.data,tst.data1)

#### LATVIA
num = final.povt %>% filter(country.name == list[3]) %>%
  select(-one_of(c("country.name", "country.code", "variable")))
info = final.povt %>% filter(country.name == list[3]) %>%
  select(one_of(c("country.code", "variable")))

impute = function(df) {
  means = colMeans(num, na.rm = T)
  for (j in 1:ncol(df))
    set(df, which(is.na(df[[j]])), j, means[j])
}

impute(num)

data = cbind(info, num)
tr.data1 = data %>% filter(variable %in% 1981:2012)
tst.data1 = data %>% filter(variable %in% 2013:2016)

tr.data = rbind(tr.data,tr.data1)
tst.data = rbind(tst.data,tst.data1)

#### THAILAND
num = final.povt %>% filter(country.name == list[4]) %>%
  select(-one_of(c("country.name", "country.code", "variable")))
info = final.povt %>% filter(country.name == list[4]) %>%
  select(one_of(c("country.code", "variable")))

impute = function(df) {
  means = colMeans(num, na.rm = T)
  for (j in 1:ncol(df))
    set(df, which(is.na(df[[j]])), j, means[j])
}

impute(num)

data = cbind(info, num)
tr.data1 = data %>% filter(variable %in% 1981:2012)
tst.data1 = data %>% filter(variable %in% 2013:2016)

tr.data = rbind(tr.data,tr.data1)
tst.data = rbind(tst.data,tst.data1)

#### BELARUS
num = final.povt %>% filter(country.name == list[5]) %>%
  select(-one_of(c("country.name", "country.code", "variable")))
info = final.povt %>% filter(country.name == list[5]) %>%
  select(one_of(c("country.code", "variable")))

impute = function(df) {
  means = colMeans(num, na.rm = T)
  for (j in 1:ncol(df))
    set(df, which(is.na(df[[j]])), j, means[j])
}

impute(num)

data = cbind(info, num)
tr.data1 = data %>% filter(variable %in% 1981:2012)
tst.data1 = data %>% filter(variable %in% 2013:2016)

tr.data = rbind(tr.data,tr.data1)
tst.data = rbind(tst.data,tst.data1)

# cleaning NAs again
missing <- tr.data %>% summarize_all(funs(sum(is.na(.))/n())) # "TX.VAL.AGRI.ZS.UN" "TX.VAL.FOOD.ZS.UN" "TX.VAL.MANF.ZS.UN" "TX.VAL.MMTL.ZS.UN"
missing <- gather(missing, key="feature", value="missing_pct")
good.var <- filter(missing, missing_pct == 0) # gathering the columns with NA = 0
tr.data = tr.data %>% select(one_of(c(good.var$feature)))

# cleaning collinear variables
data = tr.data[,3:ncol(tr.data)]
data = data %>% select(-one_of(c("EG.ELC.NUCL.ZS")))
cor = cor(data)

#clean NAs in correlation matrix
val.na = c()
i = 0
for(row in 1:nrow(cor)) {
  for(col in 1:ncol(cor)) {
    if(is.na(cor[row,col])) {
      val.na[i] = col
      i = i + 1
    }
  }
}

# cor[,3] # remove EG.ELC.NUCL.ZS, it's causing NA

# clean NAs for correlation matrix
high.cor = findCorrelation(cor, cutoff = 0.9, verbose = F, names = TRUE, exact = FALSE)
high.cor = high.cor[high.cor != resp]
tr.data = tr.data %>% select(-one_of(c(high.cor)))

# stepwise from MASS
fit = lm(SI.POV.LMIC.GP ~ . -country.code, data = tr.data)
step = stepAIC(fit, trace = FALSE)
step$anova # lowest AIC are BN.FIN.TOTL.CD, TX.VAL.TRVL.ZS.WT, NE.GDI.STKB.CN, NE.GDI.STKB.CD, SP.POP.3034.MA.5Y

# LASSO: https://www.r-bloggers.com/ridge-regression-and-the-lasso/
fit = lm(SI.POV.LMIC.GP ~. -country.code-variable-SE.SEC.AGES-EG.ELC.NUCL.ZS, data = tr.data)
coef(fit)

x = model.matrix(SI.POV.LMIC.GP ~ . -country.code-variable-SE.SEC.AGES-EG.ELC.NUCL.ZS, data = tr.data)[,-1]
y = tr.data$SI.POV.LMIC.GP

ytest = y[1:nrow(tst.data)]

z = model.matrix(SI.POV.LMIC.GP ~ . -country.code-variable-SE.SEC.AGES-EG.ELC.NUCL.ZS, data = tst.data)[,-1]
lambda = 10^seq(10, -2, length = 100)

ridge.mod <- glmnet(x, y, alpha = 0, lambda = lambda)
predict(ridge.mod, s = 0, exact = F, type = 'coefficients')

# find the best lambda from our list via cross-validation
cv.out <- cv.glmnet(x, y, alpha = 0)

# checking Ridge
bestlam <- cv.out$lambda.min

# make predictions
ridge.pred <- predict(ridge.mod, s = bestlam, newx = x[1:nrow(tst.data),])
s.pred <- predict(fit, newdata = tst.data)
# check MSE
mean((s.pred-ytest)^2)
mean((ridge.pred-ytest)^2)

# a look at the coefficients
out = glmnet(x[1:nrow(tr.data),],y[1:nrow(tr.data)],alpha = 0)
predict(ridge.mod, type = "coefficients", s = bestlam)[1:6,]

# lasso
lasso.mod <- glmnet(x[1:nrow(tr.data),], y[1:nrow(tr.data)], alpha = 1, lambda = lambda)
lasso.pred <- predict(lasso.mod, s = bestlam, newx = x[1:nrow(tst.data),])
mean((lasso.pred-ytest)^2)

predict(lasso.mod, type = 'coefficients', s = bestlam)[1:6,]

fit1 = lm(SI.POV.LMIC.GP ~ AG.LND.ARBL.HA + AG.LND.ARBL.ZS + AG.PRD.CROP.XD + AG.YLD.CREL.KG + BG.GSR.NFSV.GD.ZS , data = tr.data)
summary(fit1)

# 5 best variables
# AG.LND.ARBL.HA = Arable land (hectares)
# AG.LND.ARBL.ZS = Arable land (% of land area)
# AG.PRD.CROP.XD = Crop production index (2004-2006 = 100)
# AG.YLD.CREL.KG = Cereal yield (kg per hectare)
# BG.GSR.NFSV.GD.ZS = Trade in services (% of GDP)





