##################
################## log normal distribution
##################

library(XLConnect)
library(xlsx)
library(lpSolve)
library(lpSolveAPI)
library(data.table)
library(plyr)
library(gridExtra)
# library(eeptools)
library(beepr)

setwd("C:/Users/daviesb/Desktop/R/NBA")

numSimulations <- 10000
tenPercent <- numSimulations/10

### read in raw data and convert numbers to numeric
raw_data <- read.xlsx2("uploadR_log.xlsx", sheetIndex = 1, stringsAsFactors = FALSE)
rowCount <- nrow(raw_data)
### following lines only necessary due to 2018 scoring change (scores from only 8 of 9 players count)
raw_data[rowCount+1,] <- c("min PG", "PG", 3500, 0, 0)
raw_data[rowCount+2,] <- c("min SG", "SG", 3500, 0, 0)
raw_data[rowCount+3,] <- c("min SF", "SF", 3500, 0, 0)
raw_data[rowCount+4,] <- c("min PF", "PF", 3500, 0, 0)
raw_data[rowCount+5,] <- c("min C", "C", 3500, 0, 0)
#convert to numeric
raw_data$Salary <- as.numeric(as.character(raw_data$Salary))
raw_data$Proj <- as.numeric(as.character(raw_data$Proj))
raw_data$SD <- as.numeric(as.character(raw_data$SD))


### create data frame to hold each iteration of the optimization output from loop below
data_1 <- matrix(ncol = 11, nrow = numSimulations)
colnames(data_1) <- c("PG1", "PG2", "SG1", "SG2", "SF1", "SF2", "PF1", "PF2", "C", "FP", "Salary")
compTable <- as.data.frame(matrix(ncol = 5, nrow = 1))
colnames(compTable) <- c("PG", "SG", "SF", "PF", "C")
compTable[1,] <- c(2, 2, 2, 2, 1)

### establish constraints for optimization
dir <- c('<=', '<=', '<=', '<=', '<=', '<=', '=')
rhs <- c(2, 2, 2, 2, 1, 56500, 8)


### processing time of loop
ptm <- proc.time()[3]

### optimization loop
for (i in 1:numSimulations){
  sim_data <- rlnorm(nrow(raw_data), meanlog = as.numeric(as.character(raw_data$Proj)), sdlog = as.numeric(as.character(raw_data$SD))) ### generate random data based on inputs
  df <- cbind(raw_data[,1:4], sim_data, 1)
  mm <- cbind(model.matrix(as.formula("sim_data~Pos"), df)[,2:5], ifelse(df$Pos == "C", 1, 0), df$Salary, df$`1`)
  colnames(mm) <- c("pf", "pg", "sf", "sg", "c", "salary", "pCount")
  mm <- t(mm)
  obj <- df[,5]
  lp <- lp(direction = 'max',
           objective.in = obj,
           all.bin = TRUE,
           const.rhs = rhs,
           const.dir = dir,
           const.mat = mm)
  df$selected <- lp$solution
  lineup <- cbind(df[df$selected == 1, c("Name", "Pos", "Salary")], df[df$selected == 1, 5])
  lineup$Pos <- factor(lineup$Pos, levels = c("PG", "SG", "SF", "PF", "C"))
  colnames(lineup)[4] <- "sim_data"
  tableCheck <- table(lineup$Pos)
  check <- as.data.frame(compTable == tableCheck)
  missingPos <- names(check)[which(check == FALSE, arr.ind=T)[, "col"]]
  addon <- df[df$Pos==missingPos & df$selected==0 & df$Salary <= 60000-sum(lineup$Salary), c("Name", "Pos", "Salary", "sim_data")]
  addon <- addon[which.max(addon$sim_data),]
  lineup <- rbind(lineup, addon)
  lineup <- lineup[order(lineup$Pos, -lineup$Salary), ]
  data_1[i,1] <- lineup[1,1]
  data_1[i,2] <- lineup[2,1]
  data_1[i,3] <- lineup[3,1]
  data_1[i,4] <- lineup[4,1]
  data_1[i,5] <- lineup[5,1]
  data_1[i,6] <- lineup[6,1]
  data_1[i,7] <- lineup[7,1]
  data_1[i,8] <- lineup[8,1]
  data_1[i,9] <- lineup[9,1]
  data_1[i,10] <- sum(lineup[,4])
  data_1[i,11] <- sum(lineup$Salary)
  if (i %% tenPercent == 0){
    print(paste0("Sim is ",i/numSimulations*100,"% done... ", round( (proc.time()[3] - ptm) / 60, digits = 1), " minutes have passed"))
  }
}



data <- data.frame(data_1)
proc.time() - ptm
head(data)









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
lineupSheet <- XLConnect::loadWorkbook("C:/Users/daviesb/Desktop/R/NBA/LineupTool.xlsx")
setStyleAction(lineupSheet, XLC$"STYLE_ACTION.NONE")
writeWorksheet(lineupSheet, countsExcel, sheet = "Sheet1", header = TRUE, startCol = 2, startRow = 23)
writeWorksheet(lineupSheet, countsAll, sheet = "Sheet1", header = TRUE, startCol = 18)
writeWorksheet(lineupSheet, combinations, sheet = "Combos", header = TRUE)
setForceFormulaRecalculation(lineupSheet, sheet = "Sheet1", value = TRUE)
XLConnect::saveWorkbook(lineupSheet)

write.csv(countsExcel, "counts_log.csv", row.names = FALSE)
write.csv(counts, "counts_log_dupes.csv", row.names = FALSE)
write.csv(all_counts, "counts_log_all.csv", row.names = FALSE)


# write.csv(countsExcel, "counts1.csv", row.names = FALSE)
# write.csv(countsAll, "counts2.csv", row.names = FALSE)
# write.csv(combinations, "counts3.csv", row.names = FALSE)




closeAllConnections()
beep()



# countsExcel$concat <- paste(countsExcel$PG1, countsExcel$PG2,countsExcel$SG1,countsExcel$SG2,countsExcel$SF1,
#                             countsExcel$SF2,countsExcel$PF1,countsExcel$PF2,countsExcel$C, sep = "")
# 
# dMatrix <- matrix(nrow = 1001, ncol = 1001)
# 
# for(i in 1:1000) {
#   
#   for(j in 1:1000) {
#     
#     dMatrix[i,j]  <- grepl(countsExcel$PG1[i], countsExcel$concat[j]) +
#       grepl(countsExcel$PG2[i], countsExcel$concat[j]) +
#       grepl(countsExcel$SG1[i], countsExcel$concat[j]) +
#       grepl(countsExcel$SG2[i], countsExcel$concat[j]) +
#       grepl(countsExcel$SF1[i], countsExcel$concat[j]) +
#       grepl(countsExcel$SF2[i], countsExcel$concat[j]) +
#       grepl(countsExcel$PF1[i], countsExcel$concat[j]) +
#       grepl(countsExcel$PF2[i], countsExcel$concat[j]) +
#       grepl(countsExcel$C[i], countsExcel$concat[j])
#   }
# }
# 
# for(i in 1:nrow(dMatrix)-1) {
#   dMatrix[1001,i] <- mean(dMatrix[1:1000,i])
# }
# for(i in 1:ncol(dMatrix)-1) {
#   dMatrix[i,1001] <- mean(dMatrix[i,1:1000])
# }
# 
# 
# write.csv(dMatrix, "dMatrix.csv", row.names = TRUE)
# 
