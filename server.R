options(shiny.maxRequestSize = 200 * 1024^2)

# Pre-load example datasets so they don't hit the disk constantly
sample_data_1_cache <- read.table(
  "Boxplot_testData2.csv",
  sep = ",", header = TRUE, fill = TRUE,
  check.names = FALSE
)
sample_data_2_cache <- read.table(
  "Boxplot_testData.txt",
  sep = ",", header = TRUE,
  check.names = FALSE
)
sample_data_3_cache <- as.data.frame(
  readxl::read_excel("Boxplot_testData3.xlsx")
)

# Helper function to prevent redundant color parsing
parse_colours <- function(col_strings) {
  my_colours <- gsub("\\s", "", strsplit(col_strings, ",")[[1]])
  my_colours <- gsub("0x", "#", my_colours)
  return(my_colours)
}

shinyServer(function(input, output, session) {
  library(RColorBrewer)
  library(beeswarm)
  library(vioplot)
  source("MyVioplot.R")
  library(beanplot)
  library(readxl)
  source("boxplot_stats_Function.R")
  source("BoxPlotR_functions.R")

  observe({
    if (input$clearText_button == 0) {
      return()
    }
    isolate({
      updateTextInput(session, "myData", label = ",", value = "")
    })
  })

  # *** Read in data matrix ***
  data_m <- reactive({
    if (input$dataInput == 1) {
      if (input$sampleData == 1) {
        data <- sample_data_1_cache
      } else if (input$sampleData == 2) {
        data <- sample_data_2_cache
      } else {
        data <- sample_data_3_cache
      }
    } else if (input$dataInput == 2) {
      in_file <- input$upload
      # Avoid error message while file is not uploaded yet
      if (is.null(input$upload)) {
        return(NULL)
      }
      # Get the separator and extension
      ext <- tolower(tools::file_ext(in_file$name))

      if (ext %in% c("xls", "xlsx")) {
        data <- as.data.frame(readxl::read_excel(in_file$datapath))
      } else {
        my_sep <- switch(input$fileSepDF,
          "1" = ",",
          "2" = "\t",
          "3" = ";",
          "4" = ""
        )
        data <- read.table(
          in_file$datapath,
          sep = my_sep, header = TRUE, fill = TRUE,
          check.names = FALSE
        )
      }
    } else {
      # For special case when last column has empty entries in some rows
      if (is.null(input$myData) || input$myData == "") {
        return(NULL)
      }
      my_sep <- switch(input$fileSepP,
        "1" = ",",
        "2" = "\t",
        "3" = ";"
      )
      data <- read.table(
        text = input$myData, sep = my_sep, header = TRUE, fill = TRUE,
        check.names = FALSE
      )
    }
    return(data)
  })

  # *** The plot dimensions ***
  height_size <- reactive({
    input$myHeight
  })
  width_size <- reactive({
    input$myWidth
  })

  # *** Determine extent of whisker range ***
  # whiskerDefinition 0 - Tukey (default), 1 - Spear (min/max, range=0),
  # 2 - Altman (5% and 95% quantiles)
  my_range <- reactive({
    if (input$whiskerType == 0) {
      my_range <- c(-1.5)
    } else if (input$whiskerType == 1) {
      my_range <- c(0)
    } else if (input$whiskerType == 2) {
      my_range <- c(5)
    }
    return(my_range)
  })

  # *** Get boxplot statistics ***
  boxplot_stats <- reactive({
    if (is.null(data_m())) {
      return(NULL)
    }
    return(boxplot(data_m(), na.rm = TRUE, range = my_range(), plot = FALSE))
  })

  # *** Helper function for stats table ***
  get_stats_matrix <- function(data, stats, add_means) {
    stats_matrix <- rbind(
      as.matrix(stats$stats[c(5, 4, 3, 2, 1), ]),
      stats$n
    )

    if (add_means) {
      stats_matrix <- rbind(stats_matrix, colMeans(data, na.rm = TRUE))
      rownames(stats_matrix) <- c(
        "Upper whisker", "3rd quartile", "Median", "1st quartile",
        "Lower whisker", "Nr. of data points", "Mean"
      )
    } else {
      rownames(stats_matrix) <- c(
        "Upper whisker", "3rd quartile", "Median", "1st quartile",
        "Lower whisker", "Nr. of data points"
      )
    }
    colnames(stats_matrix) <- colnames(data)
    return(stats_matrix)
  }

  # *** Helper function for figure legend ***
  generate_figure_legend <- function(stats, plot_type, other_plot_type,
                                     whisker_type, add_means, add_mean_ci,
                                     mean_ci_val, my_varwidth,
                                     bean_plot_center_type) {
    fl <- "Center lines show the medians; "

    if (plot_type == "0") { # Boxplot
      fl <- paste0(
        fl,
        "box limits indicate the 25th and 75th percentiles ",
        "as determined by R software"
      )

      if (whisker_type == 0) {
        fl <- paste0(
          fl,
          "; whiskers extend 1.5 times the interquartile range ",
          "from the 25th and 75th percentiles, outliers are ",
          "represented by dots"
        )
      } else if (whisker_type == 1) {
        fl <- paste0(fl, "; whiskers extend to minimum and maximum values")
      } else {
        fl <- paste0(
          fl,
          "; whiskers extend to 5th and 95th percentiles, ",
          "outliers are represented by dots"
        )
      }

      if (add_means) {
        fl <- paste0(fl, "; crosses represent sample means")
        if (add_mean_ci) {
          fl <- paste0(
            fl, "; bars indicate ", mean_ci_val,
            "% confidence intervals of the means"
          )
        }
      }

      if (my_varwidth) {
        fl <- paste0(
          fl, "; width of the boxes is proportional to the square root ",
          "of the sample size"
        )
      }
    } else {
      if (other_plot_type == "0") { # Violin plot
        fl <- paste0(
          "White circles show the medians; box limits indicate the 25th ",
          "and 75th percentiles; whiskers extend 1.5 times the interquartile ",
          "range; polygons represent density estimates."
        )
      } else { # Bean plot
        center_label <- if (bean_plot_center_type == 0) "median" else "mean"
        fl <- paste0(
          "Black lines show the ", center_label,
          "s; white lines represent individual data points; ",
          "polygons represent density estimates."
        )
      }
    }

    fl <- paste0(
      fl, ". n = ",
      paste(stats$n, collapse = ", "),
      " sample points."
    )
    return(fl)
  }

  # *** Generate the box plot ***
  generate_box_plot <- function(plot_data) {
    par(mar = c(5, 8, 4, 2))

    nr_of_samples <- ncol(plot_data)

    plot_data_m <- plot_data
    not_plot_points <- seq_len(nr_of_samples)
    plot_points <- integer(0)

    if (input$plotDataPoints) {
      nr_needed <- as.numeric(input$nrOfDataPoints)
      not_plot_points <- integer(0)
      for (i in seq_len(nr_of_samples)) {
        if (sum(!is.na(plot_data[[i]])) < nr_needed) {
          plot_data_m[[i]] <- NA
          plot_points <- c(plot_points, i)
        } else {
          not_plot_points <- c(not_plot_points, i)
        }
      }
    }

    my_colours <- parse_colours(input$myColours)
    my_colours_2 <- parse_colours(input$myOtherPlotColours)
    point_colors <- parse_colours(input$pointColors)

    # Replicate colors if only one is provided
    if (length(my_colours) == 1) {
      my_colours <- rep(my_colours, nr_of_samples)
    }
    if (length(my_colours_2) == 1) {
      my_colours_2 <- rep(my_colours_2, nr_of_samples)
    }
    if (length(point_colors) == 1) {
      point_colors <- rep(point_colors, nr_of_samples)
    }

    point_t <- 1 - (input$pointTransparency / 100)
    point_c <- NA
    if (point_t < 1) {
      point_c <- rgb(
        t(col2rgb(point_colors)),
        alpha = 255 * point_t,
        maxColorValue = 255
      )
    } else {
      point_c <- point_colors
    }

    my_orientation <- (input$myOrientation == 1)
    my_varwidth <- (input$myVarwidth == TRUE)
    my_notch <- (input$myNotch == TRUE)
    my_log <- ""
    xmin <- NA
    xmax <- NA
    ymin <- NA
    ymax <- NA

    if (input$logScale == TRUE) {
      my_log <- if (my_orientation) "x" else "y"
    }

    if (input$ylimit != "" && !my_orientation) {
      ymin <- as.numeric(gsub("\\s", "", strsplit(input$ylimit, ",")[[1]][1]))
      ymax <- as.numeric(gsub("\\s", "", strsplit(input$ylimit, ",")[[1]][2]))
    }
    if (input$xlimit != "" && my_orientation) {
      xmin <- as.numeric(gsub("\\s", "", strsplit(input$xlimit, ",")[[1]][1]))
      xmax <- as.numeric(gsub("\\s", "", strsplit(input$xlimit, ",")[[1]][2]))
    }

    # Calculate a shared default range for consistent axes across plot types
    shared_lim <- if (all(is.na(plot_data))) {
      NULL
    } else {
      r <- range(plot_data, na.rm = TRUE)
      if (input$showNrOfPoints) {
        if (input$logScale == TRUE && length(r[r > 0]) > 0) {
          # Log scale requires multiplicative expansion to prevent negatives
          c(r[1], r[2] * (10^(diff(log10(r[r > 0])) * 0.15)))
        } else {
          # Expand top geometrically to make space for data counts
          padding <- diff(r) * 0.15
          c(r[1] - (diff(r) * 0.04), r[2] + padding)
        }
      } else {
        r
      }
    }

    vals_lim <- if (!my_orientation && input$ylimit != "") {
      c(ymin, ymax)
    } else if (my_orientation && input$xlimit != "") {
      c(xmin, xmax)
    } else {
      shared_lim
    }

    xaxis_label_angle <- if (input$xaxisLabelAngle) 2 else 1
    par(las = xaxis_label_angle)

    if (input$plotType == "0") { # Boxplot
      boxplot(
        plot_data_m,
        main = input$myTitle,
        sub = input$mySubtitle,
        xlab = input$myXlab,
        ylab = input$myYlab,
        col = my_colours,
        horizontal = my_orientation,
        varwidth = my_varwidth,
        notch = my_notch,
        outline = !input$showDataPoints,
        range = my_range(),
        log = my_log,
        ylim = vals_lim,
        las = xaxis_label_angle,
        frame.plot = FALSE,
        # Font sizes
        cex.main = input$cexTitle / 10,
        cex.lab = input$cexAxislabel / 10,
        cex.axis = input$cexAxis / 10
      )
    } else {
      if (input$otherPlotType == "0") { # Violin plot
        if (length(not_plot_points) > 0) {
          vioplot(
            as.list(data.frame(plot_data_m)),
            col = my_colours_2,
            horizontal = my_orientation,
            border = input$violinBorder,
            cex.axis = input$cexAxis / 10,
            ylim = vals_lim,
            names = colnames(plot_data_m),
            log = my_log
          )
        } else {
          plot(
            1,
            type = "n", axes = FALSE, xlab = "", ylab = "",
            xlim = if (my_orientation) {
              shared_lim
            } else {
              c(0.5, nr_of_samples + 0.5)
            },
            ylim = if (!my_orientation) {
              shared_lim
            } else {
              c(0.5, nr_of_samples + 0.5)
            }
          )
          axis(if (my_orientation) 1 else 2, cex.axis = input$cexAxis / 10)
          axis(
            if (my_orientation) 2 else 1,
            at = seq_len(nr_of_samples),
            labels = colnames(plot_data),
            cex.axis = input$cexAxis / 10
          )
        }
        title(
          main = input$myTitle,
          sub = input$mySubtitle,
          xlab = input$myXlab,
          ylab = input$myYlab,
          cex.main = input$cexTitle / 10,
          cex.lab = input$cexAxislabel / 10
        )
      } else { # Bean plot
        my_beanplot_center <- if (input$beanPlotMedianMean == 0) {
          "median"
        } else {
          "mean"
        }
        if (length(not_plot_points) > 0) {
          beanplot(
            data.frame(plot_data_m[, not_plot_points, drop = FALSE]),
            at = not_plot_points,
            xlim = c(0.5, nr_of_samples + 0.5),
            ylim = vals_lim,
            col = if (length(my_colours_2) > 1) {
              as.list(my_colours_2)
            } else {
              my_colours_2
            },
            horizontal = my_orientation,
            border = input$beanBorder,
            what = c(1, 1, 1, as.logical(as.numeric(input$beanPlotMedianMean))),
            cex.axis = input$cexAxis / 10,
            overallline = my_beanplot_center,
            names = colnames(plot_data)[not_plot_points],
            frame.plot = FALSE,
            log = my_log
          )
          axis(
            if (my_orientation) 2 else 1,
            at = seq_len(nr_of_samples),
            labels = colnames(plot_data),
            cex.axis = input$cexAxis / 10
          )
        } else {
          plot(
            1,
            type = "n", axes = FALSE, xlab = "", ylab = "",
            xlim = if (my_orientation) {
              shared_lim
            } else {
              c(0.5, nr_of_samples + 0.5)
            },
            ylim = if (!my_orientation) {
              shared_lim
            } else {
              c(0.5, nr_of_samples + 0.5)
            }
          )
          axis(if (my_orientation) 1 else 2, cex.axis = input$cexAxis / 10)
          axis(
            if (my_orientation) 2 else 1,
            at = seq_len(nr_of_samples),
            labels = colnames(plot_data),
            cex.axis = input$cexAxis / 10
          )
        }
        title(
          main = input$myTitle,
          sub = input$mySubtitle,
          xlab = input$myXlab,
          ylab = input$myYlab,
          cex.main = input$cexTitle / 10,
          cex.lab = input$cexAxislabel / 10
        )
      }
    }

    # Add grid
    if (input$addGrid == 1) {
      grid()
    } else if (input$addGrid == 2) {
      grid(nx = NULL, ny = NA)
    } else if (input$addGrid == 3) {
      grid(nx = NA, ny = NULL)
    }

    # Samples means
    if (input$addMeans && input$plotType == "0") {
      boxplot_means <- colMeans(plot_data, na.rm = TRUE)
      if (my_orientation) {
        points(boxplot_means, seq_along(boxplot_means), pch = 18, col = "red")
      } else {
        points(seq_along(boxplot_means), boxplot_means, pch = 18, col = "red")
      }

      # Add CI of means
      if (input$addMeanCI) {
        for (i in seq_along(plot_data)) {
          my_sample <- na.omit(plot_data[[i]])
          n <- length(my_sample)
          if (n > 1) {
            standard_error <- sd(my_sample) / sqrt(n)
            ci_level <- as.numeric(input$meanCI) / 100
            t_value <- qt((1 + ci_level) / 2, df = n - 1)
            margin_error <- t_value * standard_error
            lower_ci <- boxplot_means[i] - margin_error
            upper_ci <- boxplot_means[i] + margin_error

            if (my_orientation) {
              lines(c(lower_ci, upper_ci), c(i, i), col = "red", lwd = 2)
              lines(
                c(lower_ci, lower_ci), c(i - 0.1, i + 0.1),
                col = "red", lwd = 2
              )
              lines(
                c(upper_ci, upper_ci), c(i - 0.1, i + 0.1),
                col = "red", lwd = 2
              )
            } else {
              lines(c(i, i), c(lower_ci, upper_ci), col = "red", lwd = 2)
              lines(
                c(i - 0.1, i + 0.1), c(lower_ci, lower_ci),
                col = "red", lwd = 2
              )
              lines(
                c(i - 0.1, i + 0.1), c(upper_ci, upper_ci),
                col = "red", lwd = 2
              )
            }
          }
        }
      }
    }

    # Add numbers of data points
    if (input$showNrOfPoints) {
      nr_points <- boxplot_stats()$n
      if (my_orientation) {
        pos_x <- if (input$logScale == TRUE) 10^par("usr")[2] else par("usr")[2]
        text(
          x = pos_x,
          y = seq_along(nr_points),
          labels = nr_points,
          pos = 2
        )
      } else {
        pos_y <- if (input$logScale == TRUE) 10^par("usr")[4] else par("usr")[4]
        text(
          x = seq_along(nr_points),
          y = pos_y,
          labels = nr_points,
          pos = 1
        )
      }
    }

    # Add data points if selected or if forced by plotDataPoints limit
    if (input$showDataPoints || length(plot_points) > 0) {
      plot_data_points <- plot_data
      if (!input$showDataPoints && length(plot_points) > 0) {
        # Only plot points for samples below the limit
        plot_data_points[, not_plot_points] <- NA
      }

      if (input$datapointType == 1) { # Bee swarm
        beeswarm(
          plot_data_points,
          add = TRUE,
          col = point_c,
          horizontal = my_orientation,
          cex = input$pointSize / 10,
          pch = 16
        )
      } else { # Jittered or Default
        jittered.points(
          plot_data_points,
          my_orientation,
          input$datapointType,
          point_colors,
          input$pointTransparency,
          input$pointSize / 10
        )
      }
    }
  }

  ## *** Data in table ***
  output$filetable <- renderTable({
    if (is.null(data_m())) {
      return(NULL)
    }
    if (nrow(data_m()) < 500) {
      return(data_m())
    } else {
      return(data_m()[1:100, ])
    }
  })

  # *** Boxplot (using 'generate_box_plot'-function) ***
  output$boxPlot <- renderPlot(
    {
      if (is.null(data_m())) {
        return(NULL)
      }
      generate_box_plot(data_m())
    },
    height = function() {
      input$myHeight
    },
    width = function() {
      input$myWidth
    }
  )

  ## *** Download EPS file ***
  output$downloadPlotEPS <- downloadHandler(
    filename = function() {
      "Boxplot.eps"
    },
    content = function(file) {
      postscript(
        file,
        horizontal = FALSE, onefile = FALSE, paper = "special",
        width = input$myWidth / 72, height = input$myHeight / 72
      )
      generate_box_plot(data_m())
      dev.off()
    },
    contentType = "application/postscript"
  )

  ## *** Download PDF file ***
  output$downloadPlotPDF <- downloadHandler(
    filename = function() {
      "Boxplot.pdf"
    },
    content = function(file) {
      pdf(file, width = input$myWidth / 72, height = input$myHeight / 72)
      generate_box_plot(data_m())
      dev.off()
    },
    contentType = "application/pdf"
  )

  ## *** Download SVG file ***
  output$downloadPlotSVG <- downloadHandler(
    filename = function() {
      "Boxplot.svg"
    },
    content = function(file) {
      svg(file, width = input$myWidth / 72, height = input$myHeight / 72)
      generate_box_plot(data_m())
      dev.off()
    },
    contentType = "image/svg"
  )

  # *** Output boxplot statistics in table below plot ***
  output$boxplotStatsTable <- renderTable(
    {
      if (is.null(data_m()) || is.null(boxplot_stats())) {
        return(NULL)
      }
      get_stats_matrix(data_m(), boxplot_stats(), input$addMeans)
    },
    rownames = TRUE
  )

  # *** Print figure legend ***
  output$FigureLegend <- renderPrint({
    if (is.null(data_m()) || is.null(boxplot_stats())) {
      return(invisible())
    }
    fl <- generate_figure_legend(
      stats = boxplot_stats(),
      plot_type = input$plotType,
      other_plot_type = input$otherPlotType,
      whisker_type = input$whiskerType,
      add_means = input$addMeans,
      add_mean_ci = input$addMeanCI,
      mean_ci_val = input$meanCI,
      my_varwidth = input$myVarwidth,
      bean_plot_center_type = input$beanPlotMedianMean
    )
    cat(fl, "\n")
  })


  # *** Download boxplot data in csv format ***
  output$downloadBoxplotData <- downloadHandler(
    filename = function() {
      "BoxplotData.csv"
    },
    content = function(file) {
      write.csv(data_m(), file, row.names = FALSE)
    }
  )
})
