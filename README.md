shiny-boxplot
=============

This is the repository for the tool presented in "BoxPlotR: a web tool for generation of box plots" (Spitzer at al. 2014).

Installation
------------

Before running the app you will need to have R and RStudio installed (tested with R 3.0.2 and RStudio 0.97.449).

- Please run these lines in R:
  - install.packages("shiny")
  - install.packages("devtools")
  - devtools::install_github("shiny-incubator","rstudio")
  - install.packages("beeswarm")
  - install.packages("vioplot")
  - install.packages("beanplot")
  - install.packages("RColorBrewer")

- Then start the app:
  - shiny::runGitHub("shiny-boxplot", "jwildenhain")

Your web browser will open the web app.
