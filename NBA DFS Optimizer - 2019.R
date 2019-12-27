library(XLConnect)
library(xlsx)
library(lpSolve)
library(lpSolveAPI)
library(data.table)
library(plyr)
library(gridExtra)
library(beepr)
library(doSNOW)
library(parallel)
library(future)

setwd("C:/Users/daviesb/Desktop/R/NBA")

numSimulations <- 100000
minSalary <- 58500

### read in raw data and convert numbers to numeric
raw_data <- read.xlsx2("C:\\Users\\daviesb\\Desktop\\NBA\\2019-2020\\uploadR.xlsx", sheetIndex = 1, stringsAsFactors = FALSE)
rowCount <- nrow(raw_data)
raw_data$Salary <- as.numeric(as.character(raw_data$Salary))
raw_data$Proj <- as.numeric(as.character(raw_data$Proj))
raw_data$SD <- as.numeric(as.character(raw_data$SD))

### calculate new Proj and SD to be used in log normal distribution in loop below
raw_data_calc <- raw_data
raw_data_calc$Proj <- log( raw_data$Proj^2 / sqrt (raw_data$SD^2 + raw_data$Proj^2))
raw_data_calc$SD <- sqrt( log( 1 + raw_data$SD^2 / raw_data$Proj^2))
raw_data_calc <- na.omit(raw_data_calc)
raw_data <- subset(raw_data, raw_data$Name %in% raw_data_calc$Name)


### establish constraints for optimization
dir <- c('<=', '<=', '<=', '<=', '<=', '<=', '>=', '=')
rhs <- c(2, 2, 2, 2, 1, 60000, minSalary, 9)


### create cluster for parallelization
numClusters <- as.numeric(availableCores())-2
c1 <- makeCluster(numClusters)
registerDoSNOW(c1)


numBatches <- ceiling(numSimulations / 5000)


### processing time of loop
ptm <- proc.time()[3]

for (i in 1:numBatches) {
  
  ### optimization loop
  data_loop <- foreach (i=1:(numSimulations/numBatches), .combine = "rbind", .packages = "lpSolve", .inorder = FALSE) %dopar% {
    sim_data <- rlnorm(nrow(raw_data_calc), meanlog = raw_data_calc$Proj, sdlog = raw_data_calc$SD) ### generate random data based on inputs
    df <- cbind(raw_data_calc[,1:4], raw_data$SD, sim_data, 1)
    mm <- cbind(model.matrix(as.formula("sim_data~Pos"), df)[,2:5], ifelse(df$Pos == "C", 1, 0), df$Salary, df$Salary, df$`1`)
    colnames(mm) <- c("pf", "pg", "sf", "sg", "c", "salary", "salary", "pCount")
    mm <- t(mm)
    obj <- df[,6]
    lp <- lp(direction = 'max',
             objective.in = obj,
             all.bin = TRUE,
             const.rhs = rhs,
             const.dir = dir,
             const.mat = mm)
    df$selected <- lp$solution
    lineup <- cbind(df[df$selected == 1, c("Name", "Pos", "Salary")], df[df$selected == 1, 5:6])
    lineup$Pos <- factor(lineup$Pos, levels = c("PG", "SG", "SF", "PF", "C"))
    lineup <- lineup[order(lineup$Pos, -lineup$Salary), ]
    lineup_t <- as.data.frame(t(lineup[1]), stringsAsFactors = FALSE)
    lineup_t$Salary <- sum(lineup$Salary)
    lineup_t$PTS <- sum(lineup$sim_data)
    lineup_t$SD <- lineup$Salary %*% lineup$`raw_data$SD`/ sum(lineup$Salary) ### calculate weighted average of SD for winning lineup
    lineup_t <- as.matrix(lineup_t)
    return(lineup_t)
  }
  
  if (i == 1){
    data_loop_final <- data_loop
    print(paste0("Batch ", i, " of ", numBatches, " took ", round((proc.time()[3] - ptm)/60, 2), " minutes"))
    print(paste0("Estimated time to completion: ", round((proc.time()[3] - ptm)/60, 2) * numBatches, " minutes"))
  }
  else {
    data_loop_final <- rbind(data_loop_final, data_loop)
    print(paste0("Batch ", i, " of ", numBatches, " completed after ", round((proc.time()[3] - ptm)/60, 2), " minutes"))
  }
}

stopCluster(c1)
print(paste0(numSimulations, " simulations took ", round((proc.time()[3] - ptm)/60, 2), " minutes"))



colnames(data_loop_final) <- c("PG1", "PG2", "SG1", "SG2", "SF1", "SF2", "PF1", "PF2", "C", "Salary", "PTS", "SD")
data <- as.data.frame(data_loop_final, stringsAsFactors = FALSE)
rownames(data) <- NULL
head(data)
data$SD <- as.numeric(data$SD)
data$PTS <- as.numeric(data$PTS)




### find lineups that appear more than once
counts <- ddply(data,.(PG1, PG2, SG1, SG2, SF1, SF2, PF1, PF2, C),nrow)
colnames(counts)[10] <- "Frequency"
all_counts <- counts[order(-counts$Frequency),] # used later to print ALL lineups
counts <- subset(counts, Frequency > 1)
counts <- counts[order(-counts$Frequency),]
View(counts)

### write all output to "Lineup_temp" excel file
#write.xlsx2(data, "Lineup_temp.xlsx", row.names = FALSE)
#writeWorksheetToFile(file = "Lineup_temp.xlsx", data = counts, sheet = "Frequency")
#writeWorksheetToFile(file = "Lineup_temp.xlsx", data = raw_data, sheet = "Input")


############################## top players

PG1 <- count(data$PG1)
PG2 <- count(data$PG2)
PG <- ddply(rbind(PG1, PG2), .(x), summarize, sum_count = sum(freq))
PG <- PG[order(-PG$sum_count),]
PG <- PG[1:20,]
colnames(PG) <- c("PG", "Freq")
countsPG <- PG ### for LineupTool later in script
countsPG$Freq <- PG$Freq/numSimulations ### for LineupTool later in script
PG$Freq <- PG$Freq*100/numSimulations
PG$Freq <- paste(round(PG$Freq, digits = 1), "%", sep = "")

SG1 <- count(data$SG1)
SG2 <- count(data$SG2)
SG <- ddply(rbind(SG1, SG2), .(x), summarize, sum_count = sum(freq))
SG <- SG[order(-SG$sum_count),]
SG <- SG[1:20,]
colnames(SG) <- c("SG", "Freq")
countsSG <- SG ### for LineupTool later in script
countsSG$Freq <- SG$Freq/numSimulations ### for LineupTool later in script
SG$Freq <- SG$Freq*100/numSimulations
SG$Freq <- paste(round(SG$Freq, digits = 1), "%", sep = "")

SF1 <- count(data$SF1)
SF2 <- count(data$SF2)
SF <- ddply(rbind(SF1, SF2), .(x), summarize, sum_count = sum(freq))
SF <- SF[order(-SF$sum_count),]
SF <- SF[1:20,]
colnames(SF) <- c("SF", "Freq")
countsSF <- SF ### for LineupTool later in script
countsSF$Freq <- SF$Freq/numSimulations ### for LineupTool later in script
SF$Freq <- SF$Freq*100/numSimulations
SF$Freq <- paste(round(SF$Freq, digits = 1), "%", sep = "")

PF1 <- count(data$PF1)
PF2 <- count(data$PF2)
PF <- ddply(rbind(PF1, PF2), .(x), summarize, sum_count = sum(freq))
PF <- PF[order(-PF$sum_count),]
PF <- PF[1:20,]
colnames(PF) <- c("PF", "Freq")
countsPF <- PF ### for LineupTool later in script
countsPF$Freq <- PF$Freq/numSimulations ### for LineupTool later in script
PF$Freq <- PF$Freq*100/numSimulations
PF$Freq <- paste(round(PF$Freq, digits = 1), "%", sep = "")

C1 <- count(data$C)
C <- C1[order(-C1$freq),]
colnames(C) <- c("x", "sum_count")
C <- C[1:20,]
colnames(C) <- c("C", "Freq")
countsC <- C ### for LineupTool later in script
countsC$Freq <- C$Freq/numSimulations ### for LineupTool later in script
C$Freq <- C$Freq*100/numSimulations
C$Freq <- paste(round(C$Freq, digits = 1), "%", sep = "")

all <- cbind(PG,SG,SF,PF,C)
rownames(all) <- NULL
# View(all)


countsAll <- cbind(countsPG, countsSG, countsSF, countsPF, countsC)





today <- paste0(format(Sys.Date(), "%Y"), "_", format(Sys.Date(), "%m"), "_", format(Sys.Date(), "%d"))
bbm <- read.xlsx2(file = paste0("C:/Users/daviesb/Desktop/NBA/2019-2020/BBM/DFS_", today, ".xls"), stringsAsFactors=FALSE, sheetIndex = 1)
bbm$Price <- as.numeric(bbm$Price)
bbm <- bbm[,-c(1:3)]




# prep raw_data data frame for exporting Value to PDF
raw_data$Value <- round(raw_data$Proj*1000 / raw_data$Salary, digits = 1)

PG <- raw_data[raw_data$Pos == "PG",c(1,6)]
PG <- PG[order(-PG$Value),]
PG <- PG[1:20,]
colnames(PG) <- c("PG", "Value")

SG <- raw_data[raw_data$Pos == "SG",c(1,6)]
SG <- SG[order(-SG$Value),]
SG <- SG[1:20,]
colnames(SG) <- c("SG", "Value")

SF <- raw_data[raw_data$Pos == "SF",c(1,6)]
SF <- SF[order(-SF$Value),]
SF <- SF[1:20,]
colnames(SF) <- c("SF", "Value")

PF <- raw_data[raw_data$Pos == "PF",c(1,6)]
PF <- PF[order(-PF$Value),]
PF <- PF[1:20,]
colnames(PF) <- c("PF", "Value")

C <- raw_data[raw_data$Pos == "C",c(1,6)]
C <- C[order(-C$Value),]
C <- C[1:20,]
colnames(C) <- c("C", "Value")

Value <- cbind(PG, SG, SF, PF, C)
rownames(Value) <- NULL

# View(Value)


if(nrow(counts) > 20) {
  counts_t20 <- counts[1:20,]
  counts_t40 <- counts[21:40,]
  counts_t60 <- counts[41:60,]
  counts_t80 <- counts[61:80,]
  counts_t100 <- counts[81:100,]
}

### export everything to PDF
pdf("DFS Output_log.pdf", height=7, width=18)
plot(grid.table(all))
plot(grid.table(Value))
plot(grid.table(counts_t20))
plot(grid.table(counts_t40))
plot(grid.table(counts_t60))
plot(grid.table(counts_t80))
plot(grid.table(counts_t100))
plot(grid.table(cores))
dev.off()
shell.exec("DFS Output_log.pdf")


countsExcel <- counts[1:2000,]

top_players <- raw_data$Name[1:7]
combinations <- t(as.data.frame(as.matrix(combn(top_players, 4))))


### open existing Excel lineup tool, write new data
lineupSheet <- XLConnect::loadWorkbook("C:/Users/daviesb/Desktop/NBA/2019-2020/LineupTool/LineupTool.xlsx")
setStyleAction(lineupSheet, XLC$"STYLE_ACTION.NONE")
writeWorksheet(lineupSheet, countsExcel, sheet = "Sheet1", header = TRUE, startCol = 2, startRow = 23)
writeWorksheet(lineupSheet, countsAll, sheet = "Sheet1", header = TRUE, startCol = 18)
writeWorksheet(lineupSheet, combinations, sheet = "Combos", header = TRUE)
writeWorksheet(lineupSheet, bbm, sheet = "Sheet2", startCol = 3, startRow = 1)
setForceFormulaRecalculation(lineupSheet, sheet = "Sheet1", value = TRUE)
XLConnect::saveWorkbook(lineupSheet)

# write.csv(countsExcel, "counts_log.csv", row.names = FALSE)
# write.csv(counts, "counts_log_dupes.csv", row.names = FALSE)
# write.csv(all_counts, "counts_log_all.csv", row.names = FALSE)


# write.csv(countsExcel, "counts1.csv", row.names = FALSE)
# write.csv(countsAll, "counts2.csv", row.names = FALSE)
# write.csv(combinations, "counts3.csv", row.names = FALSE)


















PG1 <- count(data$PG1)
PG2 <- count(data$PG2)
PG <- ddply(rbind(PG1, PG2), .(x), summarize, sum_count = sum(freq))
PG <- PG[order(-PG$sum_count),]
colnames(PG) <- c("PG", "Freq")
countsPG <- PG ### for LineupTool later in script
countsPG$Freq <- PG$Freq/numSimulations ### for LineupTool later in script
PG$Freq <- PG$Freq*100/numSimulations
PG$Freq <- paste(round(PG$Freq, digits = 1), "%", sep = "")

SG1 <- count(data$SG1)
SG2 <- count(data$SG2)
SG <- ddply(rbind(SG1, SG2), .(x), summarize, sum_count = sum(freq))
SG <- SG[order(-SG$sum_count),]
colnames(SG) <- c("SG", "Freq")
countsSG <- SG ### for LineupTool later in script
countsSG$Freq <- SG$Freq/numSimulations ### for LineupTool later in script
SG$Freq <- SG$Freq*100/numSimulations
SG$Freq <- paste(round(SG$Freq, digits = 1), "%", sep = "")

SF1 <- count(data$SF1)
SF2 <- count(data$SF2)
SF <- ddply(rbind(SF1, SF2), .(x), summarize, sum_count = sum(freq))
SF <- SF[order(-SF$sum_count),]
colnames(SF) <- c("SF", "Freq")
countsSF <- SF ### for LineupTool later in script
countsSF$Freq <- SF$Freq/numSimulations ### for LineupTool later in script
SF$Freq <- SF$Freq*100/numSimulations
SF$Freq <- paste(round(SF$Freq, digits = 1), "%", sep = "")

PF1 <- count(data$PF1)
PF2 <- count(data$PF2)
PF <- ddply(rbind(PF1, PF2), .(x), summarize, sum_count = sum(freq))
PF <- PF[order(-PF$sum_count),]
colnames(PF) <- c("PF", "Freq")
countsPF <- PF ### for LineupTool later in script
countsPF$Freq <- PF$Freq/numSimulations ### for LineupTool later in script
PF$Freq <- PF$Freq*100/numSimulations
PF$Freq <- paste(round(PF$Freq, digits = 1), "%", sep = "")

C1 <- count(data$C)
C <- C1[order(-C1$freq),]
colnames(C) <- c("x", "sum_count")
colnames(C) <- c("C", "Freq")
countsC <- C ### for LineupTool later in script
countsC$Freq <- C$Freq/numSimulations ### for LineupTool later in script
C$Freq <- C$Freq*100/numSimulations
C$Freq <- paste(round(C$Freq, digits = 1), "%", sep = "")



len <- max(nrow(PG), nrow(SG), nrow(SF), nrow(PF), nrow(C))
PG[nrow(PG)+(len - nrow(PG)+1),] <- NA
SG[nrow(SG)+(len - nrow(SG)+1),] <- NA
SF[nrow(SF)+(len - nrow(SF)+1),] <- NA
PF[nrow(PF)+(len - nrow(PF)+1),] <- NA
C[nrow(C)+(len - nrow(C)+1),] <- NA
Value_total <- cbind(PG, SG, SF, PF, C)
rownames(Value_total) <- NULL



temp <- data[order(-data$PTS),]
temp <- temp[1:500000,]
write.csv(temp, file = paste0("C:\\Users\\daviesb\\Desktop\\NBA\\2019-2020\\Testing\\", today, ".csv"), row.names = FALSE)
# write.csv(Value_total, "C:\\Users\\daviesb\\Desktop\\NBA\\2019-2020\\Testing\\11.03 Vals.csv", row.names = FALSE)
# write.csv(counts, "C:\\Users\\daviesb\\Desktop\\NBA\\2019-2020\\Testing\\Counts 11.03.2019.csv", row.names = FALSE)












closeAllConnections()
beep()