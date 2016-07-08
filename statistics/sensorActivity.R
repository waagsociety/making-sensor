#!/usr/bin/env Rscript

library(ggplot2)
library(scales)
#library(reshape2)
library(data.table)
library(Hmisc)

###################
# Constants
###################

measures <- c("rssi","temp","humidity","pm25", "pm10","no2a","no2b")
LSB <- 0.0001875
FontSize <- 7

GGDFile <- "./GGD.csv"
AlphaSensefile <- "./NO2_AlphaSenseparameters.csv"

###################
# Functions
###################

alphaSenseNo2 <- function(OP1,OP2,WE_zero_total,Aux_zero_total,WE_sens_total){
  
  ((OP1*LSB - WE_zero_total) - (OP2*LSB - Aux_zero_total))/WE_sens_total
}

linearmodel <- function(x,y,t,h,a0,a1,b,c,d){
  a0 + a1*x + b*y + c*t + d*h
}


putMsg <- function(msg,major=FALSE,localStart=NULL){
  if (major){
    writeLines("\n***************************************************")
    writeLines(paste(msg))
    if(!is.null(localStart)){
      writeLines(sprintf("Elapsed secs: %s", round(as.numeric((proc.time()-localStart)[3]),2)))
    }
    writeLines("***************************************************\n")
    assign("start_time", proc.time(), envir = .GlobalEnv)
    
  }else{
    writeLines(paste("## ",msg))
  }
}

limitOutOfRangeData <- function(data,column){
  normalFactor <- 5
  center <- median(data[,column,with=FALSE][[1]])
  #extent <- abs(mad(validData[,measures[i],with=FALSE][[1]],na.rm = TRUE)) * normalFactor
  extent <- normalFactor * abs(center)
  
  outliers <- (data[,column,with=FALSE] < (center - extent))[,1]
  
  if( sum(outliers) > 0){
    putMsg(paste("WARNING:", round(sum(outliers)/nrow(data)*100,digits=3),"% values lowen than", center,"-",extent,"for measure",column))
    # data[outliers,column := center-extent, with=FALSE]
  }
  
  outliers <- (data[,column,with=FALSE] > (center + extent))[,1]
  
  if( sum(outliers) > 0){
    putMsg(paste("WARNING:", round(sum(outliers)/nrow(data)*100,digits=3),"% values higher than", center,"+", extent,"for measure",column))
    # data[outliers,column := center + extent, with=FALSE]
  }

  return(data)
}

###################
# Inputs parameters
###################

args = commandArgs(trailingOnly=TRUE)

if (length(args) == 0) {
 # execute interactively
  if( !interactive()){
    stop("This is not an interactive session",call.=FALSE)
  }
  if (exists("startDate")){
    rm("startDate")
  }
  if (exists("endDate")){
    rm("endDate")
  }
  interactive <- 'y'

} else if (length(args)==3) {
  # default output file
  startDate <- args[1]
  endDate <- args[2]
  interactive <- args[3]
}else{
  stop(paste("Wrong number of arguments:",args), call.=FALSE)
}

if ( interactive == 'y' ){
  toFile <- readline(prompt="Output to file[y/N] ? ")
}else{
  toFile <- 'y'  
}

if ( interactive == 'y' ){
  perSensor <- readline(prompt="Separate sensors [y/N] ? ")
}else{
  perSensor <- 'n'  
}

## Read date range for graphics

if (!exists("startDate")){
  startDate <- readline(prompt="Enter first day (ex:18-04-2016 <14:00>, \"\" for earliest available day) ")
  if (startDate == ""){
    startDate <- NA
  }
}

if( ! is.na(startDate) ){
  mydate <- as.POSIXct(startDate,format = "%d-%m-%Y %H:%M", tz = "Europe/Amsterdam")
  if( is.na(mydate)){
    mydate <- as.POSIXct(startDate,format = "%d-%m-%Y", tz = "Europe/Amsterdam")
  }
  startDate <- mydate
}

if (!exists("endDate")){
  endDate <- readline(prompt="Enter last day (ex:18-04-2016 <14:00>, \"\" for most recent available day) ")
  
  if (endDate == ""){
    endDate <- NA
  }
}

if( ! is.na(endDate) ){
  mydate <- as.POSIXct(endDate,format = "%d-%m-%Y %H:%M", tz = "Europe/Amsterdam")
  if( is.na(mydate)){
    mydate <- as.POSIXct(endDate,format = "%d-%m-%Y", tz = "Europe/Amsterdam") + (60*60*24 - 1)
  }
  endDate <- mydate
}

stopifnot( (endDate >= startDate) || is.na(endDate)  || is.na(startDate) )

#######################################################
## Start program after determining options
#######################################################

putMsg("Start calculating",major=TRUE,localStart = NULL)
totalStart <- start_time

putMsg("Reading data",major=FALSE)

## Create WHERE condition
whereCondition <- "AND"
MY_TZ <- base::format(Sys.time(), format="%Z")

if(is.na(endDate)  && is.na(startDate) ){
  # no WHERE condition
  whereCondition <- paste(whereCondition,"TRUE")
}else{
  if ( !is.na(startDate) ){
    whereCondition <- paste(whereCondition, " srv_ts >= '",startDate," ",MY_TZ,"'",sep="")
  }
  if ( !is.na(startDate) && !is.na(endDate) ){
    whereCondition <- paste(whereCondition, "AND")
  }
  if ( !is.na(endDate) ){
    whereCondition <- paste(whereCondition, " srv_ts <= '",endDate," ",MY_TZ,"'",sep="")
  }
}


## Read data from tunnel to server
query <- paste("select * from measures where id > 100",whereCondition)
psql_command <- "PGPASSWORD=postgres psql -h localhost -p 9730 -U postgres -d airq"

command <- paste(psql_command," -A -F',' -c \"", query, "\" | grep -v 'rows)' > ./all.csv", sep="")
system(command)

command <- paste(psql_command," -c 'COPY sensorparameters TO stdout WITH (FORMAT CSV, HEADER);' > ./sensorparameters.csv", sep="")
system(command)

## Parse data from DB
all <- read.csv("./all.csv", header=TRUE, stringsAsFactors = FALSE)
## Adapt date format
all$tr_ts <- paste(gsub("\\.[0-9]*","",all$srv_ts),"00",sep="")
all$corr_ts <- as.POSIXct(all$tr_ts, format = "%Y-%m-%d %H:%M:%S%z")
stopifnot(sum(is.na(all$corr_ts))== 0)

calibrationData <- read.csv(AlphaSensefile, header=TRUE, stringsAsFactors = FALSE)

# Alphasense parameters Kit,id,ISB_serial_num,WE_zero_Electro,WE_zero_total,Aux_zero_Electro,Aux_zero_total,WE_sens_Electro,WE_sens_Total
calibrationData <- data.table(calibrationData[,c("id","WE_zero_total","Aux_zero_total","WE_sens_total")])
calibrationData$id <- as.factor(calibrationData$id)
setkey(calibrationData,id)

# KNMI parameters
sensorparameters <- read.csv("./sensorparameters.csv", header=TRUE, stringsAsFactors = FALSE)
sensorparameters$id <- as.factor(sensorparameters$id)
sensorparameters <- data.table(sensorparameters,key="id")

putMsg("Done reading data",major=TRUE,localStart = start_time)
putMsg("Calculating time frame")

## uniform empty messages
all$message[is.na(all$message) | all$message==""] <- NA

# ## calculate start and end date with rounding
# endDate <- trunc(max(all$corr_ts), units = "days") + 60 * 60 * 24 -1
if( is.na(startDate)){
  startDate <- min(all$corr_ts)
}

if( is.na(endDate)){
  endDate <- max(all$corr_ts)
}

## Open file if writing to file
if ( toFile == 'y' ){
  title <- paste("Report at ", Sys.time(),  sprintf(" from %s to %s",
                                                    as.character(startDate,format = "%d-%m-%Y", tz = "Europe/Amsterdam"),
                                                    as.character(endDate,format = "%d-%m-%Y", tz = "Europe/Amsterdam")),".pdf", sep="")
  title <- gsub(":","_",title)
  dir <- "/Users/SB/Downloads/"
  pdf(file=paste(dir,title,sep=""),title=title,paper="a4r",width=14)
}

## remove unnecessary columns and create data table
sensorData <- data.table(all[c("id","corr_ts","message", measures)],key="id")

## reduce dataset to time interval (step redundant since we query only for this range
sensorData <- sensorData[corr_ts>=startDate & corr_ts<=endDate,]

## calculate sensor ids
sensorData$id <-as.factor(sensorData$id)

idsInRange <- sensorData[,id,by = id]$id

putMsg(paste("Available sensor ids:",paste(idsInRange,sep="",collapse=",")))

hours <- floor(difftime(endDate,startDate,units="hours")) + 1

putMsg(paste("Done calculating time frame, hours: ",hours),major=TRUE,localStart = start_time)
putMsg(sprintf("Time interval for plotting: from %s to %s",
               as.character(startDate,format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam"),
               as.character(endDate,format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")))

putMsg("Calculating hourly sensor activity and temp, humidity, no2, pm 2.5 and pm 10")

## create data structure to calculate quantities per hour

len <- as.integer(hours) * nlevels(idsInRange)

bins <- data.frame(tm=.POSIXct(character(len)),
                   id=factor(idsInRange),
                   integer(len),
                   integer(len),
                   integer(len),
                   numeric(len),
                   numeric(len),
                   numeric(len),
                   numeric(len),
                   numeric(len),
                   numeric(len),
                   stringsAsFactors = FALSE)


timeNow <- startDate
index <- 1


s_fulldata <- (rowSums(is.na(sensorData[,measures,with=FALSE])) == 0)
s_partialdata <- (is.na(sensorData$message) & rowSums(is.na(sensorData[,measures,with=FALSE])) > 0)
s_startup <- (!is.na(sensorData$message))

stopifnot( sum(s_fulldata) + sum (s_partialdata) + sum(s_startup) == nrow(sensorData))

dataTypes <- c("Full data", "Partial data", "Startup")

names(bins)[3:5] <- dataTypes

names(bins)[6] <- "no2a_mean"
names(bins)[7] <- "no2b_mean"
names(bins)[8] <- "pm25_mean"
names(bins)[9] <- "pm10_mean"
names(bins)[10] <- "temp_mean"
names(bins)[11] <- "rh_mean"

joint1 <- data.table(id=idsInRange,key="id")


## Loop to calculate activities per hourly time slot
for (index in seq(1, len, by = nlevels(idsInRange))){
  candidates <- sensorData$corr_ts<(timeNow+3600) & sensorData$corr_ts >= timeNow
  
  joint2 <- data.table(sensorData[candidates&s_fulldata,lapply(.SD,length),by=id,.SDcols="id"],key="id")
  joint3 <- data.table(sensorData[candidates&s_partialdata,lapply(.SD,length),by=id,.SDcols="id"],key="id")
  joint4 <- data.table(sensorData[candidates&s_startup,lapply(.SD,length),by=id,.SDcols="id"],key="id")
  
  joint5 <- data.table(sensorData[candidates&s_fulldata,lapply(.SD,mean),by=id,.SDcols=c("no2a","no2b","pm25","pm10","temp","humidity")],key="id")
  
  
  bins$tm[index:(index+nlevels(idsInRange)-1)] <- timeNow
  bins[index:(index+nlevels(idsInRange)-1),2:ncol(bins)] <- joint2[joint3[joint4[joint5[joint1]]]]

  timeNow <- timeNow + 3600
}

bins[is.na(bins)] <- 0

putMsg("Done calculating sensor activity",major=TRUE,localStart = start_time)
putMsg("Generating activity graphs")

for ( id_index in 1: nlevels(idsInRange) )
{
  if ( perSensor == 'y' ){
    ## select only a particular sensor
    currentID <- levels(idsInRange)[id_index]
    selectID <- (bins$id == currentID)
  }else{
    ## vectors are initialized to FALSE, this includes all the rows
    currentID <- "all"
    selectID <- !(vector(mode = "logical",length = nrow(bins)))
  }
  
  for (i in 1:length(dataTypes))
  {
    
    if ( toFile != 'y' ){
      readline(prompt=paste("Press enter to see ",dataTypes[i]," for sensor: ",currentID,sep=""))
    }
    
    pl <- ggplot(data=bins[selectID,], aes(x=tm, y=bins[selectID,dataTypes[i]], group=id, colour=id)) + 
      geom_line() +
      xlab("Time") +
      ylab(paste("Nr of",dataTypes[i],"sensor msg")) +
      theme(axis.text.x = element_text(size=FontSize,angle = -90, hjust = 1)) +
      scale_x_datetime(breaks = date_breaks("1 hour"))
    
    print(pl)
    
  }
  if ( perSensor != 'y' ){
    ## we do not need to loop to plot separate sensors
    break
  }
  
}

putMsg("Done generating activity graphs",major=TRUE,localStart = start_time)

putMsg("Calculating NO2 and PM concentrations")


calcConc <- data.table(bins[,c("tm","id","no2a_mean","no2b_mean","pm25_mean","pm10_mean","temp_mean","rh_mean")],key="id")

calcConc <- calcConc[calibrationData[sensorparameters]]

calcConc$alpha_no2conc <- alphaSenseNo2(calcConc$no2a_mean,calcConc$no2b_mean,calcConc$WE_zero_total,calcConc$Aux_zero_total,calcConc$WE_sens_total)

calcConc$knmi_no2conc <- linearmodel(calcConc$no2a_mean,calcConc$no2b_mean,calcConc$temp_mean,calcConc$rh_mean,
                                     calcConc$no2_offset,calcConc$no2_no2a_coeff,calcConc$no2_no2b_coeff,calcConc$no2_t_coeff,calcConc$no2_rh_coeff)

calcConc$knmi_pm25conc <- linearmodel(calcConc$pm25_mean,calcConc$pm10_mean,calcConc$temp_mean,calcConc$rh_mean,
                                      calcConc$pm25_offset,calcConc$pm25_pm25_coeff,calcConc$pm25_pm10_coeff,calcConc$pm25_t_coeff,calcConc$pm25_rh_coeff)

calcConc$knmi_pm10conc <- linearmodel(calcConc$pm10_mean,calcConc$pm25_mean,calcConc$temp_mean,calcConc$rh_mean,
                           calcConc$pm10_offset,calcConc$pm10_pm10_coeff,calcConc$pm10_pm25_coeff,calcConc$pm10_t_coeff,calcConc$pm10_rh_coeff)

calcConc$tm <- format(calcConc$tm, tz="Etc/GMT-1",usetz=FALSE)

concCols <- c("tm","id","alpha_no2conc","knmi_no2conc","knmi_pm25conc","knmi_pm10conc","temp_mean","rh_mean")

write.csv(calcConc[,concCols,with=FALSE],GGDFile,row.names = FALSE)

putMsg("Done calculating NO2 and PM concentrations",major=TRUE,localStart = start_time)

putMsg("Generating concentration graphs")

for ( id_index in 1: nlevels(idsInRange) )
{
  
  if ( perSensor == 'y' ){
    ## select only a particular sensor
    currentID <- levels(idsInRange)[id_index]
    selectID <- (calcConc$id == currentID)
  }else{
    currentID <- idsInRange
    selectID <- calcConc$id %in% idsInRange
  }
  
  for (i in 3:length(concCols)){
    
    if (sum(!is.na(calcConc[selectID,get(concCols[i])])) == 0){
      putMsg(paste("WARNING: No ",concCols[i]," data for sensor id(s):",paste(currentID,sep="",collapse=",")))
      next
    }
    if ( toFile != 'y' ){
      readline(prompt=paste("Press enter to see ",concCols[i]," concentration for sensor: ",paste(currentID,sep="",collapse=","),sep=""))
    }
    
    pl <- ggplot(data=calcConc[selectID,], aes_string(x="tm", y=concCols[i], group="id", colour="id")) + 
      geom_line() +
      xlab("Time") +
      theme(axis.text.x = element_text(size=FontSize,angle = -90, hjust = 1))
    
    print(pl)
  }
  
  if ( perSensor != 'y' ){
    ## we do not need to loop to plot separate sensors
    break
  }
  
}

putMsg("Done generating concentration graphs",major=TRUE,localStart = start_time)

putMsg("Generating sensor measure graphs")


validData <- sensorData[!s_startup,]

for (i in 1:length(measures))
{
  
  inRangeData <- limitOutOfRangeData(validData,measures[i])
  
  for ( id_index in 1: nlevels(idsInRange) )
  {
    
    if ( perSensor == 'y' ){
      ## select only a particular sensor
      currentID <- levels(idsInRange)[id_index]
      selectID <- (inRangeData$id == currentID)
    }else{
      currentID <- idsInRange
      selectID <- inRangeData$id %in% idsInRange
    }
  
#   if (length(outIds) > 0){
#     putMsg(paste("SKIPPING: Out of range sensor ids:",paste(outIds,sep="",collapse=","),"for measure",measures[i]))
#   }
#   usableIDs <- idsInRange[! idsInRange %in% outIds]

    if (sum(!is.na(inRangeData[selectID,get(measures[i])])) == 0){
      putMsg(paste("WARNING: No valid data for sensor id(s):",paste(currentID,sep="",collapse=","),"for measure",measures[i]))
      next
    }
    if ( toFile != 'y' ){
      readline(prompt=paste("Press enter to see ",measures[i]," for sensor: ",paste(currentID,sep="",collapse=","),sep=""))
    }
    
    pl <- ggplot(data=inRangeData[selectID,], aes_string(x="corr_ts", y=measures[i], group="id", colour="id")) + 
      geom_line() +
      xlab("Time") +
      theme(axis.text.x = element_text(size=FontSize,angle = -90, hjust = 1))
      
    print(pl)
    
    if ( perSensor != 'y' ){
      ## we do not need to loop to plot separate sensors
      break
    }
  }
}

putMsg("Done generating sensor measure graphs",major=TRUE,localStart = start_time)

putMsg("Generating sensor measure cross-correlation")

## calculate cross-correlations
## reference: http://www.minerazzi.com/tutorials/a-tutorial-on-standard-errors.pdf

ACCEPTABLE_SE <- 0.05
TARGET_CORR <- 0.75
ACCEPTABLE_SAMPLE_NR <- ceiling( 2 + ( 1-TARGET_CORR^2 )/ ACCEPTABLE_SE^2 )

#slots <- c(5,10,15,20,25,30,60)
#TIMESLOT_MIN <- slots[max(which(slots < as.integer(hours)*60/ACCEPTABLE_SAMPLE_NR/10))]
TIMESLOT_MIN <- 5

MIN_CORR_SPAN <- TIMESLOT_MIN * ACCEPTABLE_SAMPLE_NR


startCorrTime <- trunc(min(validData$corr_ts),units = "mins")
endCorrTime <- trunc(max(validData$corr_ts),units = "mins") + 60

if( startCorrTime >= endCorrTime){
  putMsg("SKIPPING: No overlap time for cross-correlation")
}else{

  # Calculate nr of time slots for cross-correlation, add 1 if it is not an exact multiple
  nr_mins <- as.integer(difftime(endCorrTime,startCorrTime,units="mins"))
  
  toAdd <- sum( ! (nr_mins %% TIMESLOT_MIN == 0))
  
  len <- nr_mins %/% TIMESLOT_MIN + toAdd
  
  putMsg(sprintf("Calculating correlation with slots of %d min with at least %d samples for a SE of %f and corr of %f",
                 TIMESLOT_MIN,ACCEPTABLE_SAMPLE_NR,ACCEPTABLE_SE,TARGET_CORR))
  putMsg(sprintf("Time period from %s to %s, time slots: %d",
                 startCorrTime,endCorrTime,len))
  
  
  ## temporary data structure to hold the averages of the sensor measurements
  corr_data <- data.frame(tm=.POSIXct(character(len*nlevels(idsInRange))),
                          id=factor(idsInRange),
                          matrix(NA,nrow=len*nlevels(idsInRange),ncol=length(measures),byrow=FALSE))
  
  colnames(corr_data)[-1] <- c("id",measures)
  
  timeNow <- startCorrTime
  
  # calculate averages
  for ( min_slot in seq(1, (nr_mins %/% TIMESLOT_MIN + toAdd)*nlevels(idsInRange), by = nlevels(idsInRange)) ){
    
    candidates <- validData$corr_ts<(timeNow+(60*TIMESLOT_MIN)) & validData$corr_ts >= timeNow
    
    
    joint2 <- data.table(validData[candidates,lapply(.SD,mean),by=id,.SDcols=measures],key="id")
    
    corr_data$tm[min_slot:(min_slot+nlevels(idsInRange)-1)] <- timeNow
    corr_data[min_slot:(min_slot+nlevels(idsInRange)-1),-1] <- joint2[joint1]
    
    timeNow <- timeNow + 60*TIMESLOT_MIN
  }

  ## add no2 diff for correlation
  corr_data$no2diff <- corr_data$no2a - corr_data$no2b
  
  extMeasures <- c(measures,"no2diff")
  
  for (i in 1:length(extMeasures)) {
    
    ## Initialize matrix for every measure
    corr_matrix <- rcorr(as.matrix(dcast(corr_data,tm~id,value.var=extMeasures[i])[,2:(nlevels(idsInRange)+1)]),type = "pearson")
    
    notEnoughSamples <- which(corr_matrix$n < ACCEPTABLE_SAMPLE_NR & lower.tri(corr_matrix$n,diag=FALSE),arr.ind=TRUE)

    if( length(notEnoughSamples) > 0 ){
      putMsg(paste("WARNING: Not enough samples for",extMeasures[i],"for sensors:", 
                     paste(row.names(corr_matrix$r)[notEnoughSamples[,1]],
                           colnames(corr_matrix$r)[notEnoughSamples[,2]],sep=",")))
    }
    
    notEnoughConfidence <- which(corr_matrix$P > ACCEPTABLE_SE & lower.tri(corr_matrix$P,diag=FALSE),arr.ind=TRUE)
    
    if( length(notEnoughConfidence) > 0 ){
      putMsg(paste("WARNING: Not enough confidence for",extMeasures[i],"for sensors:", 
                   paste(row.names(corr_matrix$P)[notEnoughConfidence[,1]],
                         colnames(corr_matrix$P)[notEnoughConfidence[,2]],sep=",")))
    }
    
    
    corr_matrix$r[is.na(corr_matrix$r)] <- -1
    
    stopifnot(sum(is.na(corr_matrix$r)) == 0)
    
    corr_DF <- data.frame(id=idsInRange,corr_matrix$r,stringsAsFactors = FALSE)
      
    colnames(corr_DF) <- c("id",as.character(idsInRange))
    corr_toDisplay <- melt(corr_DF,"id",2:ncol(corr_DF))
    
    corr_toDisplay$value <- as.numeric(as.character(corr_toDisplay$value))
      
    if ( toFile != 'y' ){
      readline(prompt=paste("Press enter to see correlation for ",extMeasures[i]," for all sensors",sep=""))
    }
    
    pl <- ggplot(data=corr_toDisplay, aes(x=variable, y=value, group=id,colour=id)) + 
      geom_line() +
      xlab("sensor nr") +
      ylab(paste(extMeasures[i],"correlation")) +
      coord_cartesian(ylim = c(-1, 1)) 
    
    print(pl)
      
  }
}

if ( toFile == 'y' ){
  garbage <- dev.off()
}

putMsg("Done generating sensor measure cross-correlation",major=TRUE,localStart = start_time)


putMsg("Program done",major=TRUE,localStart = totalStart)
