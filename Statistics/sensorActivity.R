library(ggplot2)
library(reshape2)

writeLines("Starting program")

system("psql -h localhost -p 9330 -U postgres -d airq  -A -F',' -c 'select * from measures where id > 100' | grep -v 'rows)' > ./all.csv")

start <- proc.time()

all <- read.csv("./all.csv", header=TRUE, stringsAsFactors = FALSE)

writeLines("Done reading data file")
writeLines(paste("Elapsed secs:", (proc.time()-start)["elapsed"],"\n"))
start <- proc.time()


all$tr_ts <- paste(gsub("\\.[0-9]*","",all$srv_ts),"00",sep="")

all$corr_ts <- as.POSIXct(all$tr_ts, format = "%Y-%m-%d %H:%M:%S%z")

#all$corr_ts <- as.POSIXct(paste(all$srv_ts,"00",sep=""), format = "%Y-%m-%d %H:%M:%S.%OS%z")

fout <- all[is.na(all$corr_ts),c("srv_ts","tr_ts","corr_ts")]

stopifnot(sum(is.na(all$corr_ts))== 0)

#all$corr_ts[is.na(all$corr_ts)] <- as.POSIXct("01-01-2000 13:00:00",format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")

#startDate <- as.POSIXct("14-04-2016 13:00:00",format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")
#endDate <- as.POSIXct("18-04-2016 13:00:00",format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Amsterdam")

endDate <- trunc(max(all$corr_ts), units = "days") + 60 * 60 * 24

n <- readline(prompt="Enter time range: last n days (0 for all) ")

n <- as.integer(n)

if ( n == 0){
  startDate <- trunc(min(all$corr_ts), units = "days")  
}else{
  startDate <- endDate - n * 60 * 60 * 24
}

hours <- floor(difftime(endDate,startDate,units="hours")) + 1

bins <- data.frame(tm=vector(mode="character", length=3*hours), data=vector(mode="integer", length=3*hours), type=vector(mode="character", length=3*hours),
                   stringsAsFactors = FALSE)

writeLines(paste("Done calculating time frame, hours: ",hours))
writeLines(paste("Elapsed secs:", (proc.time()-start)["elapsed"],"\n"))
start <- proc.time()

timeNow <- startDate
index <- 1

s_data <- ( all$message == "" & ! is.na(all$temp) )
s_emptydata <- ( all$message == "" &  is.na(all$temp) )
s_startup <- ( all$message != "" )

stopifnot( sum(s_data) + sum (s_emptydata) + sum(s_startup) == nrow(all))

while (index < 3*hours)
{
  candidates <- all$corr_ts<=timeNow & all$corr_ts > (timeNow-3600)
  
  bins$data[index] <- sum( candidates & s_data )
  bins$data[index+1] <- sum( candidates & s_emptydata )
  bins$data[index+2] <- sum( candidates & s_startup )
  
  bins$type[index] <- "data"
  bins$type[index+1] <- "empty data"
  bins$type[index+2] <- "startup"
  
#  if (timeNow == trunc(timeNow, units = "days"))
#  {
    time_s <- strftime(timeNow,format="%d:%m %H")
    bins$tm[index] <- time_s
    bins$tm[index+1] <- time_s
    bins$tm[index+2] <- time_s
#  }else{
#    bins$tm[index] <- strftime(timeNow,format="%H")
#    bins$tm[index+1] <- strftime(timeNow,format="%H")
#  }
  
  timeNow <- timeNow + 3600
  index <- index + 3
}

writeLines("Done calculating graph data")
writeLines(paste("Elapsed secs:", (proc.time()-start)["elapsed"],"\n"))
start <- proc.time()

pl <- ggplot(bins, aes(x=tm,y=data, fill=factor(type)) ) + geom_bar(position="dodge",stat="identity") +
#  scale_fill_discrete(name="Type of msg", labels=c("Data", "Startup")) +
#  scale_fill_discrete(name="Restart") +
#  scale_color_discrete("Restart") +
  xlab("Time") +
  ylab(paste("Nr of sensor msg at",format(Sys.time(), "%a %b %d %X %Y"),sep=" ")) +
  theme(axis.text.x = element_text(angle = -90, hjust = 1))

print(pl)

