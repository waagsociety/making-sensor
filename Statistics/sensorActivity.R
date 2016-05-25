#!/usr/bin/env Rscript

library(ggplot2)
#library(reshape2)
library(data.table)

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
  startDate <- readline(prompt="Enter first day (ex:18-04-2016, \"\" for earliest available day) ")
  if (startDate == ""){
    startDate <- NA
  }
}

if( ! is.na(startDate) ){
  startDate <- as.POSIXct(startDate,format = "%d-%m-%Y", tz = "Europe/Amsterdam")
}

if (!exists("endDate")){
  endDate <- readline(prompt="Enter last day (ex:18-04-2016, \"\" for most recent available day) ")
  
  if (endDate == ""){
    endDate <- NA
  }
}

if( ! is.na(endDate) ){
  endDate <- as.POSIXct(endDate,format = "%d-%m-%Y", tz = "Europe/Amsterdam") + 60 * 60 * 24 - 1
}

stopifnot( (endDate >= startDate) || is.na(endDate)  || is.na(startDate) )


if ( interactive == 'y' ){
  writeLines("\nStarting program")
  start <- proc.time()
}

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

if ( interactive == 'y' ){
  writeLines("\nDone reading data file")
  writeLines(paste("Elapsed secs:", (proc.time()-start)["elapsed"],"\n"))
}

## Adapt date format

all$tr_ts <- paste(gsub("\\.[0-9]*","",all$srv_ts),"00",sep="")
all$corr_ts <- as.POSIXct(all$tr_ts, format = "%Y-%m-%d %H:%M:%S%z")
stopifnot(sum(is.na(all$corr_ts))== 0)

## Limit pm to positive values, set -1 as invalid
all$pm25[all$pm25 < 0] <- -1
all$pm10[all$pm10 < 0] <- -1

## uniform empty messages
all$message[is.na(all$message) | all$message==""] <- NA

## calculate start and end date with rounding
startDate <- trunc(min(all$corr_ts), units = "days")
endDate <- trunc(max(all$corr_ts), units = "days") + 60 * 60 * 24 -1

if ( interactive == 'y' ){
  start <- proc.time()
}


## remove unnecessary columns and create data table
sensorData <- data.table(all[c("id","corr_ts","message", measures)],key="id")

## reduce dataset to time interval (step redundant since we query only for this range
sensorData <- sensorData[corr_ts>=startDate & corr_ts<=endDate,]

## calculate sensor ids
sensorData$id <-as.factor(sensorData$id)

idsInRange <- sensorData[,id,by = id]$id

if ( interactive == 'y' ){
  writeLines("\nAvailable sensor ids:")
  print(idsInRange)
}

## create data structure to calculate quantities per hour

hours <- floor(difftime(endDate,startDate,units="hours")) + 1

datatypes <- c("Full data", "Partial data", "Startup")

len <- length(datatypes) * as.integer(hours) * nlevels(idsInRange)

bins <- data.frame(tm=.POSIXct(character(len)),
                   id=integer(len),
                   datapoints=integer(len),
                   datatype=character(len),
                   stringsAsFactors = FALSE)

if ( interactive == 'y' ){
  writeLines(paste("\nDone calculating time frame, hours: ",hours))
  writeLines(sprintf("Time interval for plotting from %s to %s",
                     as.character(startDate,format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam"),
                     as.character(endDate,format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")))
  writeLines(paste("Elapsed secs:", (proc.time()-start)["elapsed"],"\n"))
  start <- proc.time()
}

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

if ( interactive == 'y' ){
  writeLines("\nDone calculating graph data")
  writeLines(paste("Elapsed secs:", (proc.time()-start)["elapsed"],"\n"))
  start <- proc.time()
}

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
#pl <- ggplot(bins, aes(x=tm,y=datapoints, fill=factor(datatype)) ) + geom_bar(position="dodge",stat="identity") +
#  scale_fill_discrete(name="Type of msg", labels=c("Data", "Startup")) +
#  scale_fill_discrete(name="Restart") +
#  scale_color_discrete("Restart") +

#n <- readline(prompt="Enter sensor number: ")
#n <- as.integer(n)

normalFactor <- 100
validData <- sensorData[!s_startup,]

for (i in 1:length(measures))
{
  maat <- median(validData[,measures[i],with=FALSE][[1]])
  
#  inData <- validData[abs(get(measures[i])) <= abs(maat*normalFactor),]
  for ( id_index in 1: nlevels(idsInRange) )
  {
    if ( perSensor == 'y' ){
      ## select only a particular sensor
      currentID <- levels(idsInRange)[id_index]
      selectID <- (validData$id == currentID)
    }else{
      ## vectors are initialized to FALSE, this includes all the rows
      currentID <- "all"
      selectID <- !(vector(mode = "logical",length = nrow(validData)))
    }

    if ( toFile != 'y' ){
      readline(prompt=paste("Press enter to see ",measures[i]," for sensor: ",currentID,sep=""))
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

if ( toFile == 'y' ){
  garbage <- dev.off()
}

if ( interactive == 'y' ){
  writeLines("\nProgram done")
  writeLines(paste("Elapsed secs:", (proc.time()-start)["elapsed"],"\n"))
}