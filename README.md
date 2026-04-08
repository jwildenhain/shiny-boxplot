BoxPlotR
========

This is the repository for the Shiny application presented in "BoxPlotR: a web tool for generation of box plots" (Spitzer at al. 2014).

Installation
------------

You have two options for running shiny-boxplot:

1)  Launch directly from R and GitHub:

-   Before running the app you will need to have the latest versions of R and RStudio installed.

-   Launch the R console

-   Please run these lines in R:

    -   install.packages("shiny")
    -   install.packages("beeswarm")
    -   install.packages("vioplot")
    -   install.packages("beanplot")
    -   install.packages("RColorBrewer")

- Then start the app:
  - shiny::runGitHub("BoxPlotR.shiny", "jwildenhain")

Your web browser will open the web app.

2)  Install the shiny-server and implement shiny-boxplot as a web application and service:

-   In Ubuntu Modern Versions
    -   sudo apt-get install gdebi-core
    -   Visit <https://posit.co/download/shiny-server/> to find the URL for the latest Shiny Server release.
    -   wget <URL_FOR_LATEST_SHINY_SERVER.deb>
    -   sudo gdebi <DOWNLOADED_FILE.deb>
	- edit: /opt/shiny-server/config/default.config in a text editor
	  - Change these lines to suit your environment
	  - listen **SHINY_PORT**; (change **SHINY_PORT** to match the port you want)
	  - site_dir **SHINY_APP_HOME**; (change **SHINY_APP_HOME** to the location for your shiny apps)
	- make sure **SHINY_PORT** is open on your firewall
	- Go to your **SHINY_APP_HOME**
	  - cd **SHINY_APP_HOME**
	    -   Get the latest shiny-boxplot code from github:
        -   wget <https://github.com/jwildenhain/BoxPlotR.shiny/archive/master.zip>
	  - unzip master.zip
	  - mv BoxPlotR.shiny-master BoxPlotR.shiny
	- Restart shiny-server service:
	  - sudo service shiny-server restart

You should now be able to access shiny-boxplot at: http://YOURSITE:**SHINY_PORT**/BoxPlotR.shiny

3)  Run using Docker (Recommended isolated deployment):

-   You can deploy the fully-configured Docker version natively without installing anything onto the host running system architecture:

```bash
docker build -t boxplotr .
docker run -d -p 3838:3838 boxplotr
```
-   Then access the app via a web browser at: `http://localhost:3838`
