#!/usr/bin/env Rscript

library(ggplot2)
#library(reshape2)
library(data.table)
#library(Hmisc)

###################
# Functions
###################

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

###################
# Constants
###################

measures <- c("rssi","temp","humidity","pm25", "pm10","no2a","no2b")


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

putMsg("Start calculating",major=TRUE,localStart = NULL)
totalStart <- start_time

putMsg("Reading data",major=FALSE)

## Create WHERE condition
whereCondition <- "AND"

if(is.na(endDate)  && is.na(startDate) ){
  # no WHERE condition
  whereCondition <- paste(whereCondition,"TRUE")
}else{
  if ( !is.na(startDate) ){
    whereCondition <- paste(whereCondition, " srv_ts >= '",startDate,"'",sep="")
  }
  if ( !is.na(startDate) && !is.na(endDate) ){
    whereCondition <- paste(whereCondition, "AND")
  }
  if ( !is.na(endDate) ){
    whereCondition <- paste(whereCondition, " srv_ts <= '",endDate,"'",sep="")
  }
}


## Read data from tunnel to server
query <- paste("select * from measures where id > 100",whereCondition)
command <- paste("psql -h localhost -p 9330 -U postgres -d airq  -A -F',' -c \"", query, "\" | grep -v 'rows)' > ./all.csv", sep="")

system(command)

## Parse data from DB
all <- read.csv("./all.csv", header=TRUE, stringsAsFactors = FALSE)

putMsg("Done reading data",major=TRUE,localStart = start_time)
putMsg("Calculating time frame")

## Adapt date format

all$tr_ts <- paste(gsub("\\.[0-9]*","",all$srv_ts),"00",sep="")
all$corr_ts <- as.POSIXct(all$tr_ts, format = "%Y-%m-%d %H:%M:%S%z")
stopifnot(sum(is.na(all$corr_ts))== 0)

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

## remove unnecessary columns and create data table
sensorData <- data.table(all[c("id","corr_ts","message", measures)],key="id")

## reduce dataset to time interval (step redundant since we query only for this range
sensorData <- sensorData[corr_ts>=startDate & corr_ts<=endDate,]

## calculate sensor ids
sensorData$id <-as.factor(sensorData$id)

idsInRange <- sensorData[,id,by = id]$id

putMsg(paste("Available sensor ids:",paste(idsInRange,sep="",collapse=",")))

## create data structure to calculate quantities per hour

hours <- floor(difftime(endDate,startDate,units="hours")) + 1

datatypes <- c("Full data", "Partial data", "Startup")

len <- length(datatypes) * as.integer(hours) * nlevels(idsInRange)

bins <- data.frame(tm=.POSIXct(character(len)),
                   id=integer(len),
                   datapoints=integer(len),
                   datatype=character(len),
                   stringsAsFactors = FALSE)


putMsg(paste("Done calculating time frame, hours: ",hours),major=TRUE,localStart = start_time)
putMsg(sprintf("Time interval for plotting: from %s to %s",
               as.character(startDate,format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam"),
               as.character(endDate,format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")))
putMsg("Calculating sensor activity")

timeNow <- startDate
index <- 1


s_fulldata <- (rowSums(is.na(sensorData[,measures,with=FALSE])) == 0)
s_partialdata <- (is.na(sensorData$message) & rowSums(is.na(sensorData[,measures,with=FALSE])) > 0)
s_startup <- (!is.na(sensorData$message))

stopifnot( sum(s_fulldata) + sum (s_partialdata) + sum(s_startup) == nrow(sensorData))

while (index <= (len-(length(datatypes)*nlevels(idsInRange)) + 1))
{
  candidates <- sensorData$corr_ts<(timeNow+3600) & sensorData$corr_ts >= timeNow
  
  for ( id_index in 1: nlevels(idsInRange) )
  {
    currentID <- levels(idsInRange)[id_index]
    idcandidates <- candidates & (sensorData$id == currentID)

    ## calculate the datatype quantities per id
    bins$datapoints[index] <- sum( idcandidates & s_fulldata )
    bins$datapoints[index+1] <- sum( idcandidates & s_partialdata )
    bins$datapoints[index+2] <- sum( idcandidates & s_startup )
    

    for ( inner_index in 0:(length(datatypes)-1) )
    {
      ## assign current id and time to the previous datatype quantities, with their type assigned
      bins$datatype[index+inner_index] <- datatypes[inner_index+1]
      bins$tm[index+inner_index] <- timeNow
      bins$id[index+inner_index] <- currentID
    }
    index <- index + 3  
  }
  
  timeNow <- timeNow + 3600
  
}

putMsg("Done calculating sensor activity",major=TRUE,localStart = start_time)
putMsg("Generating activity graphs")

if ( toFile == 'y' ){
  title <- paste("Report at ", Sys.time(),  sprintf(" from %s to %s",
                                                    as.character(startDate,format = "%d-%m-%Y", tz = "Europe/Amsterdam"),
                                                    as.character(endDate,format = "%d-%m-%Y", tz = "Europe/Amsterdam")),".pdf", sep="")
  title <- gsub(":","_",title)
  dir <- "/Users/SB/Downloads/"
  pdf(file=paste(dir,title,sep=""),title=title,paper="a4r",width=14)
}


for (i in 1:length(datatypes))
{
  currentBin <- bins[bins$datatype == datatypes[i],]
  
  for ( id_index in 1: nlevels(idsInRange) )
  {
    if ( perSensor == 'y' ){
      ## select only a particular sensor
      currentID <- levels(idsInRange)[id_index]
      selectID <- (currentBin$id == currentID)
    }else{
      ## vectors are initialized to FALSE, this includes all the rows
      currentID <- "all"
      selectID <- !(vector(mode = "logical",length = nrow(currentBin)))
    }
    
    if ( toFile != 'y' ){
      readline(prompt=paste("Press enter to see ",datatypes[i]," for sensor: ",currentID,sep=""))
    }
    
    pl <- ggplot(data=currentBin[selectID,], aes(x=tm, y=datapoints, group=id, colour=id)) + 
      geom_line() +
      xlab("Time") +
      ylab(paste("Nr of",datatypes[i],"sensor msg")) +
      theme(axis.text.x = element_text(angle = -90, hjust = 1))
    
    print(pl)
    
    if ( perSensor != 'y' ){
      ## we do not need to loop to plot separate sensors
      break
    }
    
  }
  
}

putMsg("Done generating activity graphs",major=TRUE,localStart = start_time)
putMsg("Generating sensor measure graphs")

normalFactor <- 50
validData <- sensorData[!s_startup,]

for (i in 1:length(measures))
{
  center <- median(validData[,measures[i],with=FALSE][[1]])
  #extent <- abs(mad(validData[,measures[i],with=FALSE][[1]],na.rm = TRUE)) * normalFactor
  extent <- abs(center)
  
  outIds <- unique(validData[(get(measures[i]) < (center - extent)) | (get(measures[i]) > (center + extent)),id])
  
  if (length(outIds) > 0){
    putMsg(paste("SKIPPING: Out of range sensor ids:",paste(outIds,sep="",collapse=","),"for measure",measures[i]))
  }
  usableIDs <- idsInRange[! idsInRange %in% outIds]

  for ( id_index in 1: nlevels(usableIDs) )
  {
    
    if ( perSensor == 'y' ){
      ## select only a particular sensor
      currentID <- levels(usableIDs)[id_index]
      selectID <- (validData$id == currentID)
    }else{
      currentID <- usableIDs
      selectID <- validData$id %in% usableIDs
    }

    if ( toFile != 'y' ){
      readline(prompt=paste("Press enter to see ",measures[i]," for sensor: ",as.character(currentID),sep=""))
    }
    
    pl <- ggplot(data=validData[selectID,], aes_string(x="corr_ts", y=measures[i], group="id", colour="id")) + 
      geom_line() +
      xlab("Time") +
      theme(axis.text.x = element_text(angle = -90, hjust = 1))
      
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


putMsg(sprintf("Calculating correlation with slots of %d min with at least %d samples for a SE of %f and corr of %f",
                     TIMESLOT_MIN,ACCEPTABLE_SAMPLE_NR,ACCEPTABLE_SE,TARGET_CORR))

for (i in 1:length(measures))
{
  ## Initialize matrix for every measure
  corr_matrix <- matrix(0,nrow=nlevels(idsInRange),ncol=nlevels(idsInRange)+1,byrow=FALSE)
  ## Consider only measurements that are present (all sensors)
  valid_measures <- as.logical(!is.na(validData[,measures[i],with=FALSE]))
  
  for ( id1_index in 1: (nlevels(idsInRange) -1))
  {
    ## select only a particular sensor
    firstID <- levels(idsInRange)[id1_index]
    firstSelection <- (validData$id == firstID) & valid_measures
    
    corr_matrix[id1_index,1] <- firstID
    corr_matrix[id1_index,id1_index+1] <- 1

    ## This is useful only at the last iteration
    if(id1_index == (nlevels(idsInRange) -1)){
      corr_matrix[id1_index+1,1] <- firstID
      corr_matrix[id1_index+1,id1_index+2] <- 1
    }
    
    for ( id2_index in (id1_index+1): nlevels(idsInRange) ){
      ## select only a particular sensor
      secondID <- levels(idsInRange)[id2_index]
      secondSelection <- (validData$id == secondID) & valid_measures

#       if ( interactive == 'y' ){
#         writeLines(paste("Correlating", firstID,"with",secondID,"for",measures[i]))
#       }
      
      
#       if( (sum(firstSelection) < ACCEPTABLE_SAMPLE_NR) || (sum(secondSelection) < ACCEPTABLE_SAMPLE_NR ) ){
#         if ( interactive == 'y' ){
#           if( (sum(firstSelection) < ACCEPTABLE_SAMPLE_NR) && (sum(secondSelection) < ACCEPTABLE_SAMPLE_NR ) ){
#             msg <- paste("Not enough samples for sensor", firstID,"and",secondID,"for",measures[i])
#           }else if (sum(firstSelection) < ACCEPTABLE_SAMPLE_NR){
#             msg <- paste("Not enough samples for sensor", firstID,"for",measures[i])
#           }else{
#             msg <- paste("Not enough samples for sensor", secondID,"for",measures[i])
#           }
#           writeLines(msg)
#         }
#         next
#       }
      
      startCorrTime <- trunc(max(min(validData$corr_ts[firstSelection]),min(validData$corr_ts[secondSelection])),units = "mins")
      endCorrTime <- trunc(min(max(validData$corr_ts[firstSelection]),max(validData$corr_ts[secondSelection])),units = "mins") + 60

      # if( startCorrTime + MIN_CORR_SPAN > endCorrTime){
      if( startCorrTime >= endCorrTime){
        putMsg(paste("SKIPPING: No overlap time for ", firstID," with ",secondID," for ",measures[i], sep=""))
        next
      }
      
      # Calculate nr of time slots for cross-correlation, add 1 if it is not an exact multiple
      nr_mins <- as.integer(difftime(endCorrTime,startCorrTime,units="mins"))
      
      toAdd <- sum( ! (nr_mins %% TIMESLOT_MIN == 0))
      
      len <- nr_mins %/% TIMESLOT_MIN + toAdd
      
      ## temporary data structure to hold the averages of the sensor measurements
      corr_data <- data.frame(tm=.POSIXct(character(len)),
                              id1_data=numeric(len),
                              id2_data=numeric(len)
                              )
      

      timeNow <- startCorrTime
      
      # calculate averages
      for ( min_slot in 1: (nr_mins %/% TIMESLOT_MIN + toAdd) ){

        candidates <- validData$corr_ts<(timeNow+(60*TIMESLOT_MIN)) & validData$corr_ts >= timeNow
        first_corr_data <- validData[firstSelection&candidates,measures[i],with=FALSE]
        second_corr_data <- validData[secondSelection&candidates,measures[i],with=FALSE]

        corr_data$tm[min_slot] <- timeNow
        
        corr_data$id1_data[min_slot] <- mean(first_corr_data[[1]])
        corr_data$id2_data[min_slot] <- mean(second_corr_data[[1]])
        
        timeNow <- timeNow + 60*TIMESLOT_MIN
      }
      
      if( sum(!is.na(corr_data[,2])) < ACCEPTABLE_SAMPLE_NR || sum(!is.na(corr_data[,3])) < ACCEPTABLE_SAMPLE_NR ){
        if ( interactive == 'y' ){
          putMsg(paste("WARNING: Not enough samples for", firstID,
                       "(",sum(!is.na(corr_data[,2])),")",
                       "with", secondID,
                       "(",sum(!is.na(corr_data[,3])),")",
                       "for",measures[i]))
        }
        #next
      }
      ## check we have pairs to correlate as well as standard deviation FOR PAIRS since we are doing pairwise complete obs
      if( sum(!is.na(corr_data[,3]) & !is.na(corr_data[,2])) == 0 ||
          sd(corr_data[!is.na(corr_data[,3]),2],na.rm = TRUE) == 0 || 
         sd(corr_data[!is.na(corr_data[,2]),3],na.rm = TRUE) == 0){
        
        putMsg(paste("WARNING: Cross correlation cannot be computed, setting to -1. Measure:",measures[i],"Overapping samples:",
                     sum(!is.na(corr_data[,3]) & !is.na(corr_data[,2])),
                     "\n\tsensor: ",firstID, "sd", sd(corr_data[!is.na(corr_data[,3]),2],na.rm = TRUE),
                     "\n\tsensor:", secondID, "sd", sd(corr_data[!is.na(corr_data[,2]),3],na.rm = TRUE)))
        
        corr_matrix[id1_index,1+id2_index] <- -1
        corr_matrix[id2_index,1+id1_index] <- -1
        
      }else{
        
        corr_result <- cor(corr_data[,2:3], method = "pearson", use = "pairwise.complete.obs")
        corr_matrix[id1_index,1+id2_index] <- corr_result[1,2]
        corr_matrix[id2_index,1+id1_index] <- corr_result[1,2]
        
      }
      
      stopifnot(sum(is.na(corr_matrix)) == 0)
    }
  }
  corr_DF <- data.frame(corr_matrix,stringsAsFactors = FALSE)
    
  colnames(corr_DF) <- c("id",as.character(idsInRange))
  corr_toDisplay <- melt(corr_DF,"id",2:ncol(corr_DF))
  
  corr_toDisplay$value <- as.numeric(as.character(corr_toDisplay$value))
    
  if ( toFile != 'y' ){
    readline(prompt=paste("Press enter to see correlation for ",measures[i]," for all sensors",sep=""))
  }
  
  pl <- ggplot(data=corr_toDisplay, aes(x=variable, y=value, group=id,colour=id)) + 
    geom_line() +
    xlab("sensor nr") +
    ylab(paste(measures[i],"correlation")) +
    coord_cartesian(ylim = c(-1, 1)) 
  
  print(pl)
    
}

if ( toFile == 'y' ){
  garbage <- dev.off()
}

putMsg("Done generating sensor measure cross-correlation",major=TRUE,localStart = start_time)

putMsg("Program done",major=TRUE,localStart = totalStart)
