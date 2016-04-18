library(ggplot2)

restart <- read.csv("./restart.csv", header=TRUE, stringsAsFactors = FALSE)

restart$corr_ts <- as.POSIXct(paste(gsub("\\.0",".1",restart$srv_ts),"00",sep=""), format = "%Y-%m-%d %H:%M:%S.%OS%z")


restart$corr_ts[is.na(restart$corr_ts)] <- as.POSIXct("01-01-2000 13:00:00",format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")

#startDate <- as.POSIXct("14-04-2016 13:00:00",format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")
#endDate <- as.POSIXct("18-04-2016 13:00:00",format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")

startDate <- min(restart$corr_ts)
endDate <- max(restart$corr_ts)

hours <- floor(difftime(endDate,startDate,units="hours")) + 1

bins <- data.frame(tm=vector(mode="character", length=hours), occ=vector(mode="integer", length=hours), stringsAsFactors = FALSE)

timeNow <- startDate
index <- 1

while (index <= hours)
{
  bins$occ[index] <- sum(restart$corr_ts<=timeNow & restart$corr_ts > (timeNow-3600))
  bins$tm[index] <- strftime(timeNow,format="%d:%m_%H")
  timeNow <- timeNow + 3600
  index <- index + 1
}


pl <- ggplot(bins, aes(x=tm,y=occ) ) + geom_bar(stat="identity") + theme(axis.text.x = element_text(angle = -90, hjust = 1))

print(pl)

