shiny-boxplot
=============

Please findd the source code for the tool presented in BoxplotR: a web-tool for generation of box plots (Spitzer at al. 2014).

installation
------------

Before running the app you will need to have R and RStudio installed (tested with R 3.0.2 and RStudio 0.97.449).

- Please run those lines in R:
  - install.packages("shiny")
  - install.packages("devtools")
  - devtools::install_github("shiny-incubator","rstudio")
  - install.packages("beeswarm")
  - install.packages("vioplot")
  - install.packages("beanplot")

- Run the tool:
  - shiny::runGitHub("shiny-boxplot", "jwildenhain")

Your web browser will open the web app.
