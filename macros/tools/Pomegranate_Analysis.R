library(tidyverse) # install.packages("tidyverse")
library(ggpubr) # install.packages("ggpubr")

voxelSizeZ <- 0.05633 # microns/voxel

nuclearResults <- read.csv(file.choose(), header = TRUE)
wholecellResults <- read.csv(file.choose(), header = TRUE)

combinedResults <- rbind(nuclearResults, wholecellResults)
summaryResults <- combinedResults %>%
  mutate(Integrated_Density = Mean * Area) %>%
  group_by(Object_ID, Data_Type) %>% 
  summarise(Volume_microns3 = sum(Area * voxelSizeZ),
            Vol_Integrated_Density = sum(Integrated_Density),
            Intensity_per_Vol = sum(Integrated_Density)/Volume_microns3)

A <- ggplot(data = summaryResults) +
        geom_point(aes(x = Vol_Integrated_Density, 
                       y = Volume_microns3, 
                       color = Data_Type)) +
        labs(x = "Integrated Density (a.u.)", 
             y = "Volume (cubic microns)",
             color = "Class") +
        scale_color_manual(values = c("red", "black")) +
        theme_bw()

B <- ggplot(data = summaryResults) +
        geom_point(aes(x = Data_Type, y = Intensity_per_Vol),
                   size = 2) +
        geom_line(aes(x = Data_Type, y = Intensity_per_Vol, group = Object_ID),
                  alpha = 0.2) +
        labs(x = "Region", 
             y = "Mean Intensity per Voxel (a.u.)") +
        theme_bw()

# Volume Histogram
C <- ggplot() +
        geom_histogram(data = filter(summaryResults, Data_Type == "Whole_Cell"),
                       aes(x = Volume_microns3, y = ..count.., fill = "Whole Cell"),
                       alpha = 0.5,
                       color = "black",
                       bins = 50) +
        geom_histogram(data = filter(summaryResults, Data_Type == "Nucleus"),
                       aes(x = Volume_microns3, y = ..count.., fill = "Nucleus"),
                       alpha = 0.5,
                       color = "black",
                       bins = 50) +
        labs(x = "Volume (cubic microns)", 
             y = "Count",
             fill = "Class") +
        scale_fill_manual(values = c("red", "black")) +
        theme_bw()

# Intensity Histogram
D <- ggplot() +
        geom_histogram(data = filter(summaryResults, Data_Type == "Whole_Cell"),
                       aes(x = Intensity_per_Vol, y = ..count.., fill = "Whole Cell"),
                       alpha = 0.5,
                       color = "black",
                       bins = 50) +
        geom_histogram(data = filter(summaryResults, Data_Type == "Nucleus"),
                       aes(x = Intensity_per_Vol, y = ..count.., fill = "Nucleus"),
                       alpha = 0.5,
                       color = "black",
                       bins = 50) +
        labs(x = "Mean Intensity per Voxel (a.u.)", 
             y = "Count",
             fill = "Class") +
        scale_fill_manual(values = c("red", "black")) +
        theme_bw()

ggarrange(A,B, ncol = 2)
ggarrange(C,D, ncol = 2)