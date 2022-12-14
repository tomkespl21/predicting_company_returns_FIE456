########################################################
########## BiG Data FIE456 final project ###############
########################################################

# we will try to use machine learning algorithms 
# to predict whether stock returns of companies 
# are going to be positive or negative 
# additionally whether the volatility is high 
# squared return is basically a measure (the simplest measure) of volatility

# this supposedly gives useful information if we need money in near future 


rm(list=ls())

#libraries 
library(tidyverse)
library(lubridate)  # ymd function 
library(corrplot) 
library(factoextra) # pca - fviz_eigen function
library(caret)      # machine learning algos
library(kknn)
library(nnet)
library(randomForest)
library(gbm)
library(kernlab)
library(klaR)
library(pROC)
library(stargazer)

data <- read_csv("data.csv")


################ Data Manipulations #########################################

# create returns for 
# compare compustat ratios to industry ratios ?? 
# is accounting data unusual for your industry


##### do we have book/market ratio ?? 

## create lag variables and 

data <- 
   data %>% 
   rename(SP500 = Price.x,
          gold = Price.y,
          oil = DCOILWTICO) %>% 
   arrange(PERMNO,DATE) %>% 
   filter(revtq>0) %>% 
   mutate(SP500return = SP500/lag(SP500)-1,
          marketdiff = RET-SP500return,
          oilreturn = oil/lag(oil)-1,
          goldreturn = gold/lag(gold)-1,
          MV         = PRC * SHROUT,
          EV         = MV-chq+dlcq,
          BM         = atq / MV,
          ROA        = ibcomq / atq,
          EFFratio   = EV/revtq,
          return1 = lag(RET,n=1),
          return2 = lag(RET,n=2),
          return3 = lag(RET,n=3),
          eps1  = lag(epsfiq, n=1),
          eps2  = lag(epsfiq, n=2),
          vol     = lag(VOL,n=1),
          BM1     = lag(BM,n=1),
          BM2     = lag(BM,n=2),
          ROA1    = lag(ROA,n=1),
          EFFratio1 = as.numeric(lag(EFFratio,n=1)),
          EFFratio2 = as.numeric(lag(EFFratio,n=2)),
          oilprice  = lag(oil, n=1),
          policy    = lag(GEPUCURRENT, n=1),
          growth  = lag(growth_rate, n=1),
          bbkm    = lag(BBKMGDP, n=1),
          unrate  = lag(UNRATE, n=1),
          Yield   = lag(yield, n=1),
          cbyield = lag(cbyield, n=1),
          Spread  = lag(spread, n=1),
          USDEUR  = lag(usdeur, n=1),
          YENUSD  = lag(yenusd, n=1),
          VIX     = lag(vix, n=1),
          FED     = lag(FEDFUNDS, n=1),
          TED     = lag(TEDRATE, n=1),
          SP      = lag(SP500, n=1),
          SPreturn1 = lag(SP500return,n=1),
          SPreturn2 = lag(SP500return,n=2),
          Oilreturn1 = lag(oilreturn,n=1),
          Oilreturn2 = lag(oilreturn,n=2),
          Goldreturn1 = lag(goldreturn,n=1),
          Goldreturn2 = lag(goldreturn,n=2),
          Marketdiff1 = lag(marketdiff,n=1),
          Marketdiff2 = lag(marketdiff,n=2)) %>% 
   dplyr::select(-c(2:4,6:51)) %>% 
             drop_na()



# why not running statistical significance tests 
# to choose the variables ? 
# First of all, "adding or removing variables based on their significance" 
# is not a good practice!
# As the name suggests, significance testing is about testing a hypothesis,
# it is not a tool for optimizing anything, and 
# by using it for the variable selection you assume some kind of optimization problem.


##create dependent variables 

data <- 
   data %>% 
   mutate(RET_squared = as.numeric(RET^2),
          y1 = as.factor(ifelse(RET>0,1,0)),
          y2 = as.factor(ifelse(RET_squared >0.01,1,0)))

           

# check for na in data
anyNA(data)
          
          
          
################## split into training set and test set #######################

# splitting by time makes more sense, 
# because training all algorithm on future data and 
# for classifying something in the past does not make sense

training <- data[data$DATE<=as.Date("2017-12-31"),] # 70 %   
testing <-  data[data$DATE>as.Date("2017-12-31"),]  # 30 %   
          
# Checking distribution in original data and partitioned data
prop.table(table(training$y1)) * 100
prop.table(table(testing$y1)) * 100
prop.table(table(data$y1)) * 100

prop.table(table(training$y2)) * 100
prop.table(table(testing$y2)) * 100
prop.table(table(data$y2)) * 100


# which variables to use for "training" and "testing" 
train1 <- training[,c(3:34,36)] 
train2 <- training[,c(3:34,37)]




############### correlation plot ###########################

df <- data[,2:34]

cor_ma <- cor(df)

# full plot 
corrplot(cor_ma,tl.cex=0.4,tl.offset = 0.3)

# function for corr plot of only high correlated variables 
corr_simple <- function(data=df,sig=0.5){
   #convert data to numeric in order to run correlations
   #convert to factor first to keep the integrity of the data - each value will become a number rather than turn into NA
   df_cor <- data %>% mutate_if(is.character, as.factor)
   df_cor <- df_cor %>% mutate_if(is.factor, as.numeric)
   #run a correlation and drop the insignificant ones
   corr <- cor(df_cor)
   #prepare to drop duplicates and correlations of 1     
   corr[lower.tri(corr,diag=TRUE)] <- NA 
   #drop perfect correlations
   corr[corr == 1] <- NA 
   #turn into a 3-column table
   corr <- as.data.frame(as.table(corr))
   #remove the NA values from above 
   corr <- na.omit(corr) 
   #select significant values  
   corr <- subset(corr, abs(Freq) > sig) 
   #sort by highest correlation
   corr <- corr[order(-abs(corr$Freq)),] 
   #print table
   print(corr)
   #turn corr back into matrix in order to plot with corrplot
   mtx_corr <- reshape2::acast(corr, Var1~Var2, value.var="Freq")
   
   #plot correlations visually
   corrplot(mtx_corr, is.corr=FALSE, tl.col="black", na.label=" ")
}


# plot with variables of high correlation 
corr_simple(df,0.6)



# based on this plot we excluded variables that were extremely highly correlated
# for obvious reasons and probably dont give useful extra information 

# There are three main reasons why you would remove highly correlated features:
# Make the learning algorithm faster
# Decrease harmful bias , overfitting 
# interpretability of your model

##################### pca plots ##########################################


# there are several reasons why you want to use PCA:
# 1. Removes correlated features. 
# 2. Improves machine learning algorithm performance. 
# 3. Reduce overfitting
# 4. maybe smallers run-time 


# change factor variable to numeric
df2 <- train1

df2$y1=as.numeric(df2$y1)
class(df2$y1)

pca = prcomp(df2,scale = T)

fviz_eig(pca,title="",addlabels=T)
fviz_pca_var(pca,title="", geom = c("point","text"),repel=T)
fviz_pca_var(pca,title="", geom = c("point"),repel=T)


##### summary statistics

summary(data)

# company data summary statistics
data %>% 
   dplyr::select(2,6,8,9,11,12) %>% 
   as.matrix() %>% 
   stargazer(data, type = 'latex', header = FALSE, summary = TRUE,
             title = 'Summary statistics',
             summary.stat = c('n', 'min', 'mean', 'max', 'sd'))

# macro data
data %>% 
   dplyr::select(14:26, 27, 29, 31, 33) %>% 
   as.matrix() %>% 
   stargazer(data, type = 'latex', header = FALSE, summary = TRUE,
             title = 'Summary statistics',
             summary.stat = c('n', 'min', 'mean', 'max', 'sd'))




stargazer(data)



######################## models ##########################################


# pcacomp for number of pcs considered, "cv" for cross validtion 
trctrl = trainControl(method = "cv",
                      number=5,
                      #preProcOptions = list(pcaComp=6),
                      verboseIter = TRUE) 



# knn algorithm 
grid <- expand.grid(kmax = c(9,15,21,25,31),            # allows to test a range of k values
                    distance = c(1,2,3,4),        # allows to test a range of minkowski distances
                    kernel = c("rectangular",
                               "gaussian",
                               "optimal",
                               "epanechnikov"))   # different weighting types in kkn 




# knn fit for returns:
knnfit1 = train(y1~., data = train1,
                      method = "kknn",
                      trControl=trctrl,
                      preProcess=c("center","scale"),
                      #tuneLength=3)
                      tuneGrid=grid)



# knn fit for volatility
knnfit2 = train(y2~., data = train2,
                method = "kknn",
                trControl=trctrl,
                preProcess=c("center","scale"),
                #tuneLength=3)
                tuneGrid=grid)

ggplot(knnfit2)



nnet_grid <- expand.grid(decay = c(0.5, 0.1, 1e-2, 1e-3), 
                         size = c(1,5, 10, 20),
                         bag = TRUE)

# neural network for returns 
set.seed(42)
nnfit1 <- train(y1 ~ ., 
                     data = train1, 
                     method = "avNNet", 
                     preProcess=c("center","scale"),
                     trControl = trctrl,
                     na.action = na.omit,
                     tuneGrid = nnet_grid,
                     #tuneLength = 5,
                     trace = FALSE)
set.seed(42)
nnfit2 <- train(y2 ~ ., 
                data = train2, 
                method = "avNNet", 
                trControl = trctrl,
                preProcess=c("center","scale"),
                na.action = na.omit,
                tuneGrid = nnet_grid,
                #tuneLength = 5,
                trace = FALSE)



rfgrid <- expand.grid(.mtry=c(1,4,7,10,13,15,18,23,28,33,38,43,50))

# random forest fit for return
set.seed(42)
rffit1 <- train(y1 ~ ., 
                 data = train1, 
                 method = "rf", 
                 trControl = trctrl,
                 preProcess=c("center","scale"),
                 na.action = na.omit,
                 tuneGrid=rfgrid,
                 #tuneLength=4,
                 trace = FALSE)

ggplot(rffit1)

 
 # random forest fit for volatility
set.seed(42)
rffit2 <- train(y2 ~ ., 
                 data = train2, 
                 method = "rf", 
                 trControl = trctrl,
                 preProcess=c("center","scale"),
                 na.action = na.omit,
                tuneGrid = rfgrid,
                 #tuneLength=4,
                 trace = FALSE)

ggplot(rffit2)
 
 


                        
                       # 

# extreme boosting machines 
xgbfit1 <- train(y1 ~ .,
                       data = train1,
                       method = "xgbTree",
                       trControl = trctrl,
                       preProc = c("center", "scale"),
                       tuneLength = 4)
#  
 xgbfit2 <- train(y2 ~ .,
                data = train2,
                       method = "xgbTree",
                       trControl = trctrl,
                       preProc = c("center", "scale"),
                       tuneLength = 4)
 
 
# what is n.minobsinnode for ?
# At each step of the GBM algorithm, a new decision tree is constructed.
# The question when growing a decision tree is 'when to stop?'.
# The furthest you can go is to split each node
# until there is only 1 observation in each terminal node -> n.minnobsinnode = 1 
# The default for the R GBM package is 10.
# Generally, results are not very sensitive to this parameter and given the stochastic nature of GBM performance it might actually be difficult to determine exactly what value is 'the best'. The interaction depth, shrinkage and number of trees will all be much more significant in general.
# This is why we gonna take n = 10 


# Package GBM uses interaction.depth parameter as a number of splits
#it has to perform on a tree


 
 
 




##################### Predictions on test set #########################

knnpredict1 <- predict(knnfit1,newdata=testing)
confusionMatrix(knnpredict1, testing$y1)

knnpredict2 <- predict(knnfit2,newdata=testing)
confusionMatrix(knnpredict2, testing$y2)

nnpredict1 <- predict(nnfit1,newdata=testing)
confusionMatrix(nnpredict1, testing$y1)

nnpredict2 <- predict(nnfit2,newdata=testing)
confusionMatrix(nnpredict2, testing$y2)

rfpredict1 <- predict(rffit1,newdata=testing)
confusionMatrix(rfpredict1, testing$y1)

rfpredict2 <- predict(rffit2,newdata=testing)
confusionMatrix(rfpredict2, testing$y2)

xgbpredict1 <- predict(xgbfit1,newdata=testing)
confusionMatrix(xgbpredict1, testing$y1)

xgbpredict2 <- predict(xgbfit2,newdata=testing)
confusionMatrix(xgbpredict2, testing$y2)

# trading strategy

Indicator <- ifelse(xgbpredict1==1 & xgbpredict2==1,1,0)


## ROC 

# We can also plot a ROC curve, in which the True Positive rate (sensitivity)
# is plotted against the True Negative rate(specificity).
# This is good for evaluating whether your model is both correctly predicting
# which are and are not positive sentiment (not just one or the other).

 
# 
# #Draw the ROC curve 
knn.probs2 <- predict(knnfit2,testing,type="prob")
knn.roc.score2 <- roc(response=testing$y2,predictor=knn.probs2[,2])
plot(knn.roc.score2)

nn.probs2 <- predict(nnfit2,testing,type="prob")
nn.roc.score2 <- roc(response=testing$y2,predictor=nn.probs2[,2])
plot(nn.roc.score2)

rf.probs2 <- predict(rffit2,testing,type="prob")
rf.roc.score <- roc(response=testing$y2,predictor=rf.probs2[,2])
plot(rf.roc.score)

gbm.probs2 <- predict(gbmfit2,testing,type="prob")
gbm.roc.score <- roc(response=testing$y2,predictor=gbm.probs2[,2])
plot(gbm.roc.score)

knn.probs1 <- predict(knnfit1,testing,type="prob")
knn.roc.score1 <- roc(response=testing$y1,predictor=knn.probs1[,2])
plot(knn.roc.score1)

nn.probs1 <- predict(nnfit1,testing,type="prob")
nn.roc.score1 <- roc(response=testing$y1,predictor=nn.probs1[,2])
plot(nn.roc.score1)

rf.probs1 <- predict(rffit1,testing,type="prob")
rf.roc.score1 <- roc(response=testing$y1,predictor=rf.probs1[,2])
plot(rf.roc.score1)

gbm.probs1 <- predict(gbmfit1,testing,type="prob")
gbm.roc.score1 <- roc(response=testing$y1,predictor=gbm.probs1[,2])
plot(gbm.roc.score1)



