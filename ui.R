shinyUI(fluidPage(
  titlePanel("BoxPlotR: a web-tool for generation of box plots"),
  tags$head(
    tags$style(HTML(
      "
      @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400",
      ";500;600;700&display=swap');
      body, h1, h2, h3, h4, h5, h6, .shiny-text-output, label {
        font-family: 'Inter', sans-serif !important;
      }
      body { background-color: #f3f4f6; }
      label.radio { display: inline-block; }
      .radio input[type=\"radio\"] { float: none; }
      select {
        max-width: 200px; border-radius: 6px; border: 1px solid #d1d5db;
        padding: 4px;
      }
      textarea {
        width: 100%; max-width: 100%; display: block; border-radius: 6px;
        border: 1px solid #d1d5db; box-sizing: border-box; margin-bottom: 10px;
        font-family: 'Courier New', Courier, monospace; white-space: pre;
        overflow-x: auto;
      }
      .jslider { max-width: 200px; }

      /* Glassmorphism Sidebar */
      .well {
        max-width: 330px;
        background: rgba(255, 255, 255, 0.6) !important;
        backdrop-filter: blur(12px) !important;
        -webkit-backdrop-filter: blur(12px) !important;
        border: 1px solid rgba(255, 255, 255, 0.6) !important;
        border-radius: 16px !important;
        box-shadow: 0 10px 25px rgba(0, 0, 0, 0.05) !important;
      }
      .span4 { max-width: 330px; }

      /* Accent Colors - Ocean Blue */
      .nav-tabs > li.active > a, .nav-tabs > li.active > a:focus,
      .nav-tabs > li.active > a:hover {
        color: #fff !important; background-color: #0c4a6e !important;
        border-radius: 8px 8px 0 0; border: none !important;
      }
      .nav-tabs > li > a { color: #475569 !important; font-weight: 500; }
      .btn-default {
        background-color: #e0f2fe !important; color: #0369a1 !important;
        border: 1px solid #bae6fd !important; border-radius: 6px !important;
        transition: all 0.2s ease; font-weight: 600; margin-bottom: 5px;
      }
      .btn-default:hover {
        background-color: #0ea5e9 !important; color: white !important;
        box-shadow: 0 4px 12px rgba(14, 165, 233, 0.3) !important;
      }

      /* Card Layout for Plots */
      .plot-card {
        background: #ffffff; border-radius: 16px; padding: 20px;
        box-shadow: 0 10px 25px rgba(0,0,0,0.06); margin-top: 15px;
        margin-bottom: 25px; border: 1px solid #e5e7eb;
      }
      .table-card {
        background: #ffffff; border-radius: 12px; padding: 15px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.05); border: 1px solid #e5e7eb;
      }
      .controls-row {
        display: flex; gap: 10px; margin-top: 15px; flex-wrap: wrap;
      }
    "
    ))
  ),
  sidebarLayout(
    sidebarPanel(
      conditionalPanel(
        condition = "input.tabs1=='About'",
        h4("Introduction")
      ),
      conditionalPanel(
        condition = "input.tabs1=='Data upload'",
        h4("Enter data"),
        radioButtons(
          "dataInput", "",
          list("Load sample data" = 1, "Upload file" = 2, "Paste data" = 3)
        ),
        conditionalPanel(
          condition = "input.dataInput=='1'",
          h5("Load sample data:"),
          radioButtons(
            "sampleData", "Load sample data",
            list(
              "Example 1 (100,76,16,76,41 data points)" = 1,
              "Example 2 (3 columns with 100 data points)" = 2,
              "Example 3 (Log scale, Excel format)" = 3
            )
          )
        ),
        conditionalPanel(
          condition = "input.dataInput=='2'",
          h5("Upload data file: "),
          fileInput(
            "upload", "", multiple = FALSE,
            accept = c(
              "text/csv", "text/comma-separated-values",
              "text/tab-separated-values", "text/plain",
              ".csv", ".tsv", ".xls", ".xlsx"
            )
          ),
          radioButtons(
            "fileSepDF", "Delimiter (ignored for Excel files):",
            list("Comma" = 1, "Tab" = 2, "Semicolon" = 3)
          ),
          HTML(paste(
            "<p>Supports .csv, .tab, .txt, .xls, and .xlsx. ",
            "Data in <a href=\"http://en.wikipedia.org/wiki/",
            "Delimiter-separated_values\">delimited text files </a> can be ",
            "separated by comma, tab or semicolon. Excel files will be read ",
            "automatically from the first sheet. </p>",
            sep = ""
          ))
        ),
        conditionalPanel(
          condition = "input.dataInput=='3'",
          h5("Paste data below:"),
          tags$textarea(id = "myData", rows = 10, cols = 5, ""),
          actionButton("clearText_button", "Clear data"),
          radioButtons(
            "fileSepP", "Separator:",
            list("Comma" = 1, "Tab" = 2, "Semicolon" = 3)
          )
        )
      ),
      conditionalPanel(
        condition = "input.tabs1=='Data visualization'",
        radioButtons("plotType", "", list("Boxplot" = 0, "Other" = 1)),
        conditionalPanel(
          condition = "input.plotType=='1'",
          radioButtons(
            "otherPlotType", "",
            list("Violin plot" = 0, "Bean plot" = 1)
          ),
          HTML(paste(
            "<p style=\"color:#808080\">Violin plots are generated with the ",
            "<a href=\"https://cran.r-project.org/web/packages/vioplot/",
            "index.html\">vioplot package</a>. Bean plots are generated ",
            "with the <a href=\"https://cran.r-project.org/web/packages/",
            "beanplot/index.html\">beanplot package</a>.</p>",
            sep = ""
          )),
          textInput(
            "myOtherPlotColours", "Colour(s):",
            value = c("light grey, white")
          ),
          conditionalPanel(
            condition = "input.otherPlotType=='0'",
            helpText("Colour of the 'violin area'"),
            textInput("violinBorder", "Border colour:", value = c("grey"))
          ),
          conditionalPanel(
            condition = "input.otherPlotType=='1'",
            helpText(paste(
              "up to 4 colours can be specified: area of the beans, lines ",
              "inside the bean, lines outside the bean, and average line ",
              "per bean",
              sep = ""
            )),
            textInput("beanBorder", "Border colour:", value = c("grey")),
            radioButtons(
              "beanPlotMedianMean", "Display: ",
              list("Median" = 0, "Mean" = 1)
            )
          )
        ),
        h4("Plot options"),
        checkboxInput("plotDataPoints", "Minimum number of data points", FALSE),
        conditionalPanel(
          condition = "input.plotDataPoints",
          numericInput(
            "nrOfDataPoints", "Data point limit: ",
            value = 5, min = 5
          )
        ),
        checkboxInput("showDataPoints", "Add data points", FALSE),
        conditionalPanel(
          condition = "input.showDataPoints",
          radioButtons(
            "datapointType", "",
            list("Default" = 0, "Bee swarm" = 1, "Jittered" = 2)
          ),
          sliderInput(
            "pointTransparency", "Transparency of data points",
            min = 0, max = 99, value = 50
          ),
          sliderInput(
            "pointSize", "Size of data points",
            min = 1, max = 20, value = 10
          ),
          HTML(paste(
            "<p style=\"color:#808080\">Using the <a href=\"http://www.",
            "cbs.dtu.dk/~eklund/beeswarm/\">beeswarm package</a>.</p>",
            sep = ""
          )),
          textInput("pointColors", "Colour(s):", value = c("black"))
        ),
        checkboxInput("showNrOfPoints", "Display number of data points", FALSE),
        conditionalPanel(
          condition = "input.plotType=='0'",
          checkboxInput(
            "whiskerDefinition", "Definition of whisker extent", FALSE
          ),
          conditionalPanel(
            condition = "input.whiskerDefinition",
            radioButtons(
              "whiskerType", "",
              list("Tukey" = 0, "Spear" = 1, "Altman" = 2)
            ),
            HTML(paste(
              "<p style=\"color:#808080\">Tukey - whiskers extend to data ",
              "points that are less than 1.5 x <a href=\"http://en.wikipedia.",
              "org/wiki/Interquartile_range\">IQR</a> away from 1st/3rd ",
              "<a href=:\"http://en.wikipedia.org/wiki/Quartile\">quartile",
              "</a>; Spear - whiskers extend to minimum and maximum values; ",
              "Altman - whiskers extend to 5th and 95th percentile ",
              "(use only if n>40)</p>",
              sep = ""
            ))
          ),
          checkboxInput("addMeans", "Add sample means", FALSE),
          conditionalPanel(
            condition = "input.addMeans",
            checkboxInput(
              "addMeanCI", "Add confidence intervals of means", FALSE
            ),
            conditionalPanel(
              condition = "input.addMeanCI",
              radioButtons(
                "meanCI", "Define confidence interval of means:",
                list("83%" = 83, "90%" = 90, "95%" = 95)
              )
            )
          ),
          checkboxInput("myVarwidth", "Variable width boxes", FALSE),
          helpText(paste(
            "Widths of boxes are proportional to square-roots of the ",
            "number of observations.",
            sep = ""
          )),
          checkboxInput("myNotch", "Add notches", FALSE),
          HTML(paste(
            "<p style=\"color:#808080\">+/-1.58*<a href=\"http://en.wikipedia.",
            "org/wiki/Interquartile_range\">IQR</a>/sqrt(n) - gives roughly ",
            "95% confidence that two medians differ (Chambers et al., 1983)",
            "</p>",
            sep = ""
          )),
          conditionalPanel(
            condition = "input.myNotch",
            HTML(paste(
              "<p>The notches are defined as +/-1.58*<a href=\"http://en.",
              "wikipedia.org/wiki/Interquartile_range\">IQR</a>/sqrt(n) and ",
              "represent the 95% <a href=\"http://en.wikipedia.org/wiki/",
              "Confidence_interval\">confidence interval</a> for each median. ",
              "Non-overlapping notches give roughly 95% confidence that two ",
              "medians differ, ie, in 19 out of 20 cases the population ",
              "medians (estimated based on the samples) are in fact ",
              "different (Chambers et al., 1983).</p>",
              sep = ""
            ))
          ),
          textInput("myColours", "Colour(s):", value = c("light grey, white")),
          helpText(paste(
            "Colours in HEX format can be chosen on ",
            "http://colorbrewer2.org/",
            sep = ""
          ))
        ),
        checkboxInput("labelsTitle", "Modify labels and title", FALSE),
        conditionalPanel(
          condition = "input.labelsTitle",
          checkboxInput("xaxisLabelAngle", "Rotate sample names", FALSE),
          textInput("myXlab", "X-axis label:", value = c("")),
          textInput("myYlab", "Y-axis label:", value = c("")),
          textInput("myTitle", "Boxplot title:", value = c("")),
          textInput("mySubtitle", "Boxplot subtitle:", value = c(""))
        ),
        checkboxInput("plotSize", "Adjust plot size", FALSE),
        conditionalPanel(
          condition = "input.plotSize",
          numericInput("myHeight", "Plot height:", value = 550),
          numericInput("myWidth", "Plot width:", value = 750)
        ),
        checkboxInput("fontSizes", "Change font sizes", FALSE),
        conditionalPanel(
          condition = "input.fontSizes",
          numericInput("cexTitle", "Title font size:", value = 14),
          numericInput("cexAxislabel", "Axis label size:", value = 14),
          numericInput("cexAxis", "Axis font size:", value = 12)
        ),
        h5("Orientation of box plots:"),
        radioButtons(
          "myOrientation", "",
          list("Vertical" = 0, "Horizontal" = 1)
        ),
        conditionalPanel(
          condition = "input.myOrientation=='0'",
          h5("Y-axis range (eg., '0,10'):"),
          textInput("ylimit", "", value = "")
        ),
        conditionalPanel(
          condition = "input.myOrientation=='1'",
          h5("X-axis range (eg., '0,10'):"),
          textInput("xlimit", "", value = "")
        ),
        checkboxInput(
          "logScale", "Change to log scale (only for data >0)", FALSE
        ),
        h5("Add grid: "),
        radioButtons(
          "addGrid", "",
          list("None" = 0, "X & Y" = 1, "X only" = 2, "Y only" = 3)
        )
      )
    ),
    mainPanel(
      tabsetPanel(
        tabPanel(
          "About",
          HTML(paste(
            "<br><p>This application was developed with Nature Methods and ",
            "you can find the publication <a href=\"http://www.nature.com/",
            "nmeth/journal/v11/n2/full/nmeth.2811.html\">here</a>. ",
            "The BoxPlotR has also been mentioned in this <a href=\"http://",
            "www.nature.com/nmeth/journal/v11/n2/full/nmeth.2837.html\">",
            "editorial</a> and this <a href=\"http://blogs.nature.com/",
            "methagora/2014/01/bring-on-the-box-plots-boxplotr.html\">",
            "blog entry</a>. Nature methods also dedicated a <a href=\"",
            "http://www.nature.com/nmeth/journal/v11/n2/full/nmeth.2807.html\"",
            ">Points of View</a> and a <a href=\"http://www.nature.com/nmeth/",
            "journal/v11/n2/full/nmeth.2813.html\">Points of Significance",
            "</a> column to box plots. We hope that you find the <a href= ",
            "\"http://www.nature.com/nmeth/journal/v11/n2/full/nmeth.2811.html",
            "\">BoxPlotR</a> useful and we welcome suggestions for ",
            "additional features by our users. </p>",
            sep = ""
          )),
          h5("Support BoxPlotR"),
          HTML(paste(
            "<p>Please consider supporting the development and maintenance ",
            "of BoxPlotR with a <a href=\"https://www.paypal.com/pools/c/",
            "9oezkBOeV3\" target=\"_blank\">donation</a>.</p>",
            sep = ""
          )),
          h5("Software references"),
          HTML(paste(
            "<p>R Development Core Team. <i><a href=\"http://www.r-project.",
            "org/\">R</a>: A Language and Environment for Statistical ",
            "Computing.</i> R Foundation for Statistical Computing, Vienna ",
            "(2013) <br> RStudio and Inc. <i><a href=\"http://www.rstudio.com/",
            "shiny/\">shiny</a>: Web Application Framework for R.</i> R ",
            "package version 0.5.0 (2013) <br> Adler, D. <i><a href=\"http://",
            "cran.r-project.org/web/packages/vioplot/index.html\">vioplot",
            "</a>: Violin plot.</i> R package version 0.2 (2005)<br> Eklund, ",
            "A. <i><a href=\"http://cran.r-project.org/web/packages/beeswarm/",
            "index.html\"> beeswarm</a>: The bee swarm plot, an alternative ",
            "to stripchart.</i> R package version 0.1.5 (2012)<br> Kampstra, ",
            "P. <i><a href=\"http://cran.r-project.org/web/packages/beanplot/",
            "index.html\">Beanplot</a>: A Boxplot Alternative for Visual ",
            "Comparison of Distributions.</i> Journal of Statistical ",
            "Software, Code Snippets 28(1). 1-9 (2008) <br> Neuwirth, E. ",
            "<i><a href=\"http://cran.r-project.org/web/packages/RColorBrewer/",
            "index.html\">RColorBrewer</a>: ColorBrewer palettes.</i> R ",
            "package version 1.0-5. (2011)</p>",
            sep = ""
          )),
          h6(paste(
            "This application was created by the Tyers and Rappsilber labs. ",
            "Please send bugs and feature requests to Michaela Spitzer ",
            "(michaela.spitzer(at)gmail.com) and Jan Wildenhain ",
            "(jan.wildenhain(at)gmail.com). This application uses the shiny ",
            "package from RStudio.",
            sep = ""
          ))
        ),
        tabPanel(
          "Data upload",
          tableOutput("filetable"),
          h6("This application was created by the Tyers and Rappsilber labs.")
        ),
        tabPanel(
          "Data visualization",
          div(
            class = "controls-row",
            downloadButton("downloadPlotEPS", "Download eps-file"),
            downloadButton("downloadPlotPDF", "Download pdf-file"),
            downloadButton("downloadPlotSVG", "Download svg-file")
          ),
          div(
            class = "plot-card",
            plotOutput("boxPlot", height = "100%", width = "100%")
          ),
          div(
            class = "table-card",
            h4("Box plot statistics"),
            tableOutput("boxplotStatsTable")
          ),
          br(),
          h6("This application was created by the Tyers and Rappsilber labs.")
        ),
        tabPanel(
          "Figure legend template",
          h5("Box plot description for figure legend:"),
          textOutput("FigureLegend"),
          h5("Further information to be added to the figure legend:"),
          p("What do the box plots show, explain colours if used."),
          downloadButton(
            "downloadBoxplotData", "Download box plot data as .CSV file"
          ),
          h6("This application was created by the Tyers and Rappsilber labs.")
        ),
        tabPanel(
          "News",
          h5("April 16, 2026"),
          HTML("<p>Number of sessions increased to 50.</p>"),
          h5("April 8, 2026"),
          HTML(paste(
            "<p>The shiny server backend has been updated. The number of ",
            "concurrent sessions has been limited to 15 and the session ",
            "idle timeout set to 10 minutes. We are currently reworking ",
            "the code to support the latest R and shiny versions.</p>",
            sep = ""
          )),
          h5("January 17, 2021"),
          HTML(paste(
            "<p>There are several recent updates. The jitter of points is ",
            "now consistent for all samples. When data points are added to ",
            "the plot, the size can now be modified with sliders.</p>",
            sep = ""
          ))
        ),
        tabPanel(
          "FAQ",
          h5("Q: I have trouble editing the graphic files."),
          p(paste(
            "A: For EPS files make sure to 'ungroup' all objects so they ",
            "can be edited independently. In Adobe Illustrator you will ",
            "also need to use the 'release compound path' command.",
            sep = ""
          )),
          h5("Q: I would like to run BoxPlotR locally."),
          HTML(paste(
            "<p>A: We provide a pre-configured Docker image. First, ensure ",
            "you have <a href=\"https://docs.docker.com/get-docker/\">",
            "Docker installed</a>. Then, run: <br><br> ",
            "<code>docker build -t boxplotr .</code> <br> ",
            "<code>docker run -d -p 3838:3838 boxplotr</code></p>",
            sep = ""
          ))
        ),
        id = "tabs1"
      )
    )
  )
))
