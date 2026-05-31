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
  if (is.null(col_strings) || length(col_strings) == 0 || col_strings == "") {
    return(c("grey"))
  }
  my_colours <- gsub("\\s", "", strsplit(col_strings, ",")[[1]])
  my_colours <- gsub("0x", "#", my_colours)
  if (length(my_colours) == 0) {
    return(c("grey"))
  }
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

  # *** Preset Style Guides Observer ***
  observeEvent(input$styleGuide, {
    if (input$styleGuide == "none") {
      return()
    }
    
    # 1. Nature Journal
    if (input$styleGuide == "nature") {
      updateTextInput(session, "myColours", value = "light grey, white")
      updateTextInput(session, "myOtherPlotColours", value = "light grey, white")
      updateRadioButtons(session, "addGrid", selected = "0")
      updateCheckboxInput(session, "fontSizes", value = TRUE)
      updateNumericInput(session, "cexTitle", value = 14)
      updateNumericInput(session, "cexAxislabel", value = 12)
      updateNumericInput(session, "cexAxis", value = 10)
      updateTextInput(session, "violinBorder", value = "grey")
      updateTextInput(session, "beanBorder", value = "grey")
      updateTextInput(session, "pointColors", value = "black")
    }
    # 2. Science Journal
    else if (input$styleGuide == "science") {
      updateTextInput(session, "myColours", value = "#0A2540, #FF6B6B, #4D96FF, #6BCB77, #F9D976")
      updateTextInput(session, "myOtherPlotColours", value = "#0A2540, #FF6B6B, #4D96FF")
      updateRadioButtons(session, "addGrid", selected = "0")
      updateCheckboxInput(session, "fontSizes", value = TRUE)
      updateNumericInput(session, "cexTitle", value = 14)
      updateNumericInput(session, "cexAxislabel", value = 12)
      updateNumericInput(session, "cexAxis", value = 10)
      updateTextInput(session, "violinBorder", value = "black")
      updateTextInput(session, "beanBorder", value = "black")
      updateTextInput(session, "pointColors", value = "black")
    }
    # 3. The Economist
    else if (input$styleGuide == "economist") {
      updateTextInput(session, "myColours", value = "#005A9C, #7D7D7D, #E50011, #FFD100, #00A4E4")
      updateTextInput(session, "myOtherPlotColours", value = "#005A9C, #7D7D7D, #E50011")
      updateRadioButtons(session, "addGrid", selected = "3") # Y only
      updateCheckboxInput(session, "fontSizes", value = TRUE)
      updateNumericInput(session, "cexTitle", value = 16)
      updateNumericInput(session, "cexAxislabel", value = 12)
      updateNumericInput(session, "cexAxis", value = 11)
      updateTextInput(session, "violinBorder", value = "white")
      updateTextInput(session, "beanBorder", value = "white")
      updateTextInput(session, "pointColors", value = "#E50011")
    }
    # 4. Financial Times
    else if (input$styleGuide == "ft") {
      updateTextInput(session, "myColours", value = "#0F5499, #990F3D, #3F3F3F, #D9A752, #5C88BF")
      updateTextInput(session, "myOtherPlotColours", value = "#0F5499, #990F3D, #3F3F3F")
      updateRadioButtons(session, "addGrid", selected = "3") # Y only
      updateCheckboxInput(session, "fontSizes", value = TRUE)
      updateNumericInput(session, "cexTitle", value = 16)
      updateNumericInput(session, "cexAxislabel", value = 12)
      updateNumericInput(session, "cexAxis", value = 11)
      updateTextInput(session, "violinBorder", value = "#1e293b")
      updateTextInput(session, "beanBorder", value = "#1e293b")
      updateTextInput(session, "pointColors", value = "#990F3D")
    }
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
    # Safe input resolvers to prevent "argument is of length zero" or NULL crashes during reactive updates
    plot_engine <- if (is.null(input$plotEngine) || length(input$plotEngine) == 0) "classic" else input$plotEngine
    plot_type <- if (is.null(input$plotType) || length(input$plotType) == 0) "0" else input$plotType
    other_plot_type <- if (is.null(input$otherPlotType) || length(input$otherPlotType) == 0) "0" else input$otherPlotType
    bean_plot_median_mean <- if (is.null(input$beanPlotMedianMean) || length(input$beanPlotMedianMean) == 0) 0 else as.numeric(input$beanPlotMedianMean)
    my_varwidth <- if (is.null(input$myVarwidth) || length(input$myVarwidth) == 0) FALSE else (input$myVarwidth == TRUE)
    my_notch <- if (is.null(input$myNotch) || length(input$myNotch) == 0) FALSE else (input$myNotch == TRUE)
    show_data_points <- if (is.null(input$showDataPoints) || length(input$showDataPoints) == 0) FALSE else (input$showDataPoints == TRUE)
    datapoint_type <- if (is.null(input$datapointType) || length(input$datapointType) == 0) 0 else as.numeric(input$datapointType)
    add_means <- if (is.null(input$addMeans) || length(input$addMeans) == 0) FALSE else (input$addMeans == TRUE)
    add_mean_ci <- if (is.null(input$addMeanCI) || length(input$addMeanCI) == 0) FALSE else (input$addMeanCI == TRUE)
    mean_ci <- if (is.null(input$meanCI) || length(input$meanCI) == 0) 95 else as.numeric(input$meanCI)
    log_scale <- if (is.null(input$logScale) || length(input$logScale) == 0) FALSE else (input$logScale == TRUE)
    my_orientation <- if (is.null(input$myOrientation) || length(input$myOrientation) == 0) FALSE else (input$myOrientation == 1)
    add_grid <- if (is.null(input$addGrid) || length(input$addGrid) == 0) 0 else as.numeric(input$addGrid)
    show_nr_of_points <- if (is.null(input$showNrOfPoints) || length(input$showNrOfPoints) == 0) FALSE else (input$showNrOfPoints == TRUE)
    style_guide <- if (is.null(input$styleGuide) || length(input$styleGuide) == 0) "none" else input$styleGuide
    plot_data_points <- if (is.null(input$plotDataPoints) || length(input$plotDataPoints) == 0) FALSE else (input$plotDataPoints == TRUE)
    nr_of_data_points <- if (is.null(input$nrOfDataPoints) || length(input$nrOfDataPoints) == 0) 5 else as.numeric(input$nrOfDataPoints)
    xaxis_label_angle <- if (is.null(input$xaxisLabelAngle) || length(input$xaxisLabelAngle) == 0) FALSE else (input$xaxisLabelAngle == TRUE)
    
    cex_title <- if (is.null(input$cexTitle) || length(input$cexTitle) == 0) 14 else as.numeric(input$cexTitle)
    cex_axislabel <- if (is.null(input$cexAxislabel) || length(input$cexAxislabel) == 0) 14 else as.numeric(input$cexAxislabel)
    cex_axis <- if (is.null(input$cexAxis) || length(input$cexAxis) == 0) 12 else as.numeric(input$cexAxis)
    
    my_title <- if (is.null(input$myTitle) || length(input$myTitle) == 0) "" else input$myTitle
    my_subtitle <- if (is.null(input$mySubtitle) || length(input$mySubtitle) == 0) "" else input$mySubtitle
    my_xlab <- if (is.null(input$myXlab) || length(input$myXlab) == 0) "" else input$myXlab
    my_ylab <- if (is.null(input$myYlab) || length(input$myYlab) == 0) "" else input$myYlab
    
    ylimit_val <- if (is.null(input$ylimit) || length(input$ylimit) == 0) "" else input$ylimit
    xlimit_val <- if (is.null(input$xlimit) || length(input$xlimit) == 0) "" else input$xlimit
    
    my_colours_val <- if (is.null(input$myColours) || length(input$myColours) == 0) "light grey, white" else input$myColours
    my_other_colours_val <- if (is.null(input$myOtherPlotColours) || length(input$myOtherPlotColours) == 0) "light grey, white" else input$myOtherPlotColours
    point_colors_val <- if (is.null(input$pointColors) || length(input$pointColors) == 0) "black" else input$pointColors
    
    violin_border <- if (is.null(input$violinBorder) || length(input$violinBorder) == 0) "grey" else input$violinBorder
    bean_border <- if (is.null(input$beanBorder) || length(input$beanBorder) == 0) "grey" else input$beanBorder
    
    point_transparency <- if (is.null(input$pointTransparency) || length(input$pointTransparency) == 0) 50 else as.numeric(input$pointTransparency)
    point_size <- if (is.null(input$pointSize) || length(input$pointSize) == 0) 10 else as.numeric(input$pointSize)

    if (plot_engine == "ggplot") {
      library(ggplot2)
      
      # Convert plot_data to long format
      df_long <- data.frame(
        Value = unlist(plot_data, use.names = FALSE),
        Group = rep(colnames(plot_data), each = nrow(plot_data))
      )
      df_long <- na.omit(df_long)
      
      # Make sure Group is a factor with original order
      df_long$Group <- factor(df_long$Group, levels = colnames(plot_data))
      
      # Parse colours
      my_colours <- parse_colours(my_colours_val)
      my_colours_2 <- parse_colours(my_other_colours_val)
      point_colors <- parse_colours(point_colors_val)
      
      nr_of_samples <- ncol(plot_data)
      # Always recycle color vectors to match exact number of samples so ggplot manual scale never errors
      my_colours <- rep(my_colours, length.out = nr_of_samples)
      my_colours_2 <- rep(my_colours_2, length.out = nr_of_samples)
      point_colors <- rep(point_colors, length.out = nr_of_samples)
      
      plot_colours <- if (plot_type == "0") my_colours else my_colours_2
      
      # Initialize ggplot and Plot Types
      if (plot_type == "0") { # Boxplot
        # Get natively calculated boxplot statistics matching the whiskerType (Tukey, Spear, Altman)
        bp_stats <- boxplot_stats()
        
        notchlower_val <- bp_stats$conf[1, ]
        notchupper_val <- bp_stats$conf[2, ]
        if (log_scale) {
          # Safely transform to log10 space since scale_y_log10 doesn't automatically transform custom aesthetics
          notchlower_val <- log10(pmax(1e-10, notchlower_val))
          notchupper_val <- log10(pmax(1e-10, notchupper_val))
        }
        
        df_stats <- data.frame(
          Group = factor(bp_stats$names, levels = colnames(plot_data)),
          ymin = bp_stats$stats[1, ],
          lower = bp_stats$stats[2, ],
          middle = bp_stats$stats[3, ],
          upper = bp_stats$stats[4, ],
          ymax = bp_stats$stats[5, ],
          notchlower = notchlower_val,
          notchupper = notchupper_val,
          fill = bp_stats$names
        )
        
        p <- ggplot(df_stats, aes(x = Group, fill = Group)) +
          suppressWarnings(geom_boxplot(
            aes(
              ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax,
              notchlower = notchlower, notchupper = notchupper
            ),
            stat = "identity",
            varwidth = my_varwidth,
            notch = my_notch,
            width = 0.6
          ))
        
        # Identify outliers matching the calculated whiskers
        df_outliers <- df_long
        df_outliers$ymin <- df_stats$ymin[match(df_outliers$Group, df_stats$Group)]
        df_outliers$ymax <- df_stats$ymax[match(df_outliers$Group, df_stats$Group)]
        df_outliers <- df_outliers[df_outliers$Value < df_outliers$ymin | df_outliers$Value > df_outliers$ymax, ]
        
        # Overlay outliers if they are NOT already showing all points
        if (!show_data_points && nrow(df_outliers) > 0) {
          p <- p + geom_point(
            data = df_outliers,
            aes(x = Group, y = Value),
            color = "black",
            size = 1.5,
            shape = 19,
            inherit.aes = FALSE
          )
        }
      } else {
        # Initialize ggplot for Violin/Bean plot
        p <- ggplot(df_long, aes(x = Group, y = Value, fill = Group))
        
        if (other_plot_type == "0") { # Violin
          p <- p + geom_violin(
            color = violin_border,
            width = 0.8
          )
        } else { # Beanplot
          p <- p + geom_violin(
            color = bean_border,
            width = 0.8,
            alpha = 0.7
          )
          
          # Median/Mean crossbar
          center_fun <- if (bean_plot_median_mean == 0) "median" else "mean"
          p <- p + stat_summary(
            fun = center_fun,
            geom = "crossbar",
            width = 0.4,
            color = "black",
            middle.linewidth = 0.8
          )
          
          # Add individual horizontal data line segments inside the bean density shape
          p <- p + geom_segment(
            aes(
              x = as.numeric(Group) - 0.15,
              xend = as.numeric(Group) + 0.15,
              y = Value,
              yend = Value
            ),
            color = "#1e293b",
            linewidth = 0.4,
            alpha = 0.4
          )
        }
      }
      
      # Apply custom fill colors
      p <- p + scale_fill_manual(values = plot_colours)
      
      # Data points overlay
      if (show_data_points) {
        pt_trans <- 1 - (point_transparency / 100)
        pt_sz <- point_size / 10
        pt_col <- point_colors[1]
        
        # Specify data and mapping for Boxplot type since p uses df_stats as default
        points_data <- if (plot_type == "0") df_long else NULL
        points_aes <- if (plot_type == "0") aes(y = Value) else NULL
        
        if (datapoint_type == 1) { # Beeswarm / Minimal jitter
          p <- p + geom_jitter(
            data = points_data,
            mapping = points_aes,
            width = 0.05, height = 0,
            color = pt_col, size = pt_sz, alpha = pt_trans
          )
        } else if (datapoint_type == 2) { # Jittered
          p <- p + geom_jitter(
            data = points_data,
            mapping = points_aes,
            width = 0.2, height = 0,
            color = pt_col, size = pt_sz, alpha = pt_trans
          )
        } else { # Normal/Centered stripchart
          p <- p + geom_point(
            data = points_data,
            mapping = points_aes,
            position = position_nudge(x = 0),
            color = pt_col, size = pt_sz, alpha = pt_trans
          )
        }
      }
      
      # Means and CIs for Boxplot
      if (add_means && plot_type == "0") {
        p <- p + stat_summary(
          data = df_long,
          aes(x = Group, y = Value),
          fun = mean,
          geom = "point",
          shape = 18,
          size = 4,
          color = "red",
          inherit.aes = FALSE
        )
        
        if (add_mean_ci) {
          ci_fun <- function(x) {
            n <- sum(!is.na(x))
            if (n <= 1) return(c(ymin = NA, ymax = NA))
            se <- sd(x, na.rm = TRUE) / sqrt(n)
            ci_level <- mean_ci / 100
            t_val <- qt((1 + ci_level) / 2, df = n - 1)
            me <- t_val * se
            m <- mean(x, na.rm = TRUE)
            c(ymin = m - me, ymax = m + me)
          }
          p <- p + stat_summary(
            data = df_long,
            aes(x = Group, y = Value),
            fun.data = ci_fun,
            geom = "errorbar",
            width = 0.2,
            color = "red",
            linewidth = 0.8,
            inherit.aes = FALSE
          )
        }
      }
      
      # Log Scale
      if (log_scale) {
        p <- p + scale_y_log10()
      }
      
      # Labels & Font sizes
      p <- p + labs(
        title = my_title,
        subtitle = my_subtitle,
        x = my_xlab,
        y = my_ylab
      )
      
      # Resolve Y limits
      ymin <- NA
      ymax <- NA
      xmin <- NA
      xmax <- NA
      
      if (ylimit_val != "" && !my_orientation) {
        ymin <- as.numeric(gsub("\\s", "", strsplit(ylimit_val, ",")[[1]][1]))
        ymax <- as.numeric(gsub("\\s", "", strsplit(ylimit_val, ",")[[1]][2]))
      }
      if (xlimit_val != "" && my_orientation) {
        xmin <- as.numeric(gsub("\\s", "", strsplit(xlimit_val, ",")[[1]][1]))
        xmax <- as.numeric(gsub("\\s", "", strsplit(xlimit_val, ",")[[1]][2]))
      }
      
      lims <- if (!my_orientation && !is.na(ymin)) {
        c(ymin, ymax)
      } else if (my_orientation && !is.na(xmin)) {
        c(xmin, xmax)
      } else {
        NULL
      }
      
      if (my_orientation) {
        p <- p + coord_flip(ylim = lims)
      } else {
        if (!is.null(lims)) {
          p <- p + coord_cartesian(ylim = lims)
        }
      }
      
      # Resolve style guide defaults for ggplot
      style_font <- "Inter"
      bg_fill <- "white"
      panel_bg_fill <- "white"
      grid_color <- "#e2e8f0"
      axis_line_color <- "#475569"
      plot_title_hjust <- 0.5
      
      if (style_guide == "nature") {
        style_font <- "sans"
      } else if (style_guide == "science") {
        style_font <- "serif"
      } else if (style_guide == "economist") {
        style_font <- "sans"
        bg_fill <- "#e4eef2"
        panel_bg_fill <- "#e4eef2"
        grid_color <- "white"
        axis_line_color <- "#1e293b"
        plot_title_hjust <- 0
      } else if (style_guide == "ft") {
        style_font <- "serif"
        bg_fill <- "#fff1e5"
        panel_bg_fill <- "#fff1e5"
        grid_color <- "#e2d6ca"
        axis_line_color <- "#1e293b"
        plot_title_hjust <- 0
      }

      # Theme
      p <- p + theme_minimal(base_family = style_font) +
        theme(
          plot.title = element_text(size = cex_title * 1.5, face = "bold", hjust = plot_title_hjust),
          plot.subtitle = element_text(size = cex_title * 1.1, hjust = plot_title_hjust, color = "#475569"),
          axis.title.x = element_text(size = cex_axislabel * 1.2),
          axis.title.y = element_text(size = cex_axislabel * 1.2),
          axis.text = element_text(size = cex_axis * 1.1),
          legend.position = "none",
          panel.background = element_rect(fill = panel_bg_fill, color = NA),
          plot.background = element_rect(fill = bg_fill, color = NA),
          axis.line = element_line(color = axis_line_color, linewidth = 0.6),
          axis.ticks = element_line(color = axis_line_color, linewidth = 0.6)
        )
        
      # Gridlines
      if (add_grid == 0) {
        p <- p + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())
      } else if (add_grid == 2) { # X only (perpendicular to X)
        p <- p + theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(), panel.grid.major.x = element_line(color = grid_color))
      } else if (add_grid == 3) { # Y only (perpendicular to Y)
        p <- p + theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(), panel.grid.major.y = element_line(color = grid_color))
      } else {
        p <- p + theme(
          panel.grid.major = element_line(color = grid_color),
          panel.grid.minor = element_blank()
        )
      }
      
      # Display N count text at top/right if requested
      if (show_nr_of_points) {
        # Calculate stats for the labels
        nr_points <- sapply(plot_data, function(x) sum(!is.na(x)))
        df_labels <- data.frame(
          Group = factor(colnames(plot_data), levels = colnames(plot_data)),
          y_pos = if (log_scale) {
            10^(log10(max(plot_data, na.rm = TRUE)) + 0.1)
          } else {
            max(plot_data, na.rm = TRUE) * 1.05
          },
          label = paste0("n=", nr_points)
        )
        
        # Overlay standard text labels
        p <- p + geom_text(
          data = df_labels,
          aes(x = Group, y = y_pos, label = label),
          inherit.aes = FALSE,
          size = cex_axis * 0.35,
          color = "#475569",
          vjust = 0
        )
      }
      
      print(p)
      return()
    }

    # Resolve style guide defaults for Classic R
    bg_fill <- "white"
    style_font <- ""
    
    if (style_guide == "nature") {
      style_font <- "sans"
    } else if (style_guide == "science") {
      style_font <- "serif"
    } else if (style_guide == "economist") {
      style_font <- "sans"
      bg_fill <- "#e4eef2"
    } else if (style_guide == "ft") {
      style_font <- "serif"
      bg_fill <- "#fff1e5"
    }
    
    if (style_font != "") {
      par(mar = c(5, 8, 4, 2), bg = bg_fill, family = style_font)
    } else {
      par(mar = c(5, 8, 4, 2), bg = bg_fill)
    }

    nr_of_samples <- ncol(plot_data)

    plot_data_m <- plot_data
    not_plot_points <- seq_len(nr_of_samples)
    plot_points <- integer(0)

    if (plot_data_points) {
      nr_needed <- nr_of_data_points
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

    my_colours <- parse_colours(my_colours_val)
    my_colours_2 <- parse_colours(my_other_colours_val)
    point_colors <- parse_colours(point_colors_val)

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

    point_t <- 1 - (point_transparency / 100)
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

    my_log <- ""
    xmin <- NA
    xmax <- NA
    ymin <- NA
    ymax <- NA

    if (log_scale) {
      my_log <- if (my_orientation) "x" else "y"
    }

    if (ylimit_val != "" && !my_orientation) {
      ymin <- as.numeric(gsub("\\s", "", strsplit(ylimit_val, ",")[[1]][1]))
      ymax <- as.numeric(gsub("\\s", "", strsplit(ylimit_val, ",")[[1]][2]))
    }
    if (xlimit_val != "" && my_orientation) {
      xmin <- as.numeric(gsub("\\s", "", strsplit(xlimit_val, ",")[[1]][1]))
      xmax <- as.numeric(gsub("\\s", "", strsplit(xlimit_val, ",")[[1]][2]))
    }

    # Calculate a shared default range for consistent axes across plot types
    shared_lim <- if (all(is.na(plot_data))) {
      NULL
    } else {
      r <- range(plot_data, na.rm = TRUE)
      if (show_nr_of_points) {
        if (log_scale && length(r[r > 0]) > 0) {
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

    vals_lim <- if (!my_orientation && ylimit_val != "") {
      c(ymin, ymax)
    } else if (my_orientation && xlimit_val != "") {
      c(xmin, xmax)
    } else {
      shared_lim
    }

    par(las = if (xaxis_label_angle) 2 else 1)

    if (plot_type == "0") { # Boxplot
      boxplot(
        plot_data_m,
        main = my_title,
        sub = my_subtitle,
        xlab = my_xlab,
        ylab = my_ylab,
        col = my_colours,
        horizontal = my_orientation,
        varwidth = my_varwidth,
        notch = my_notch,
        outline = !show_data_points,
        range = my_range(),
        log = my_log,
        ylim = vals_lim,
        las = if (xaxis_label_angle) 2 else 1,
        frame.plot = FALSE,
        # Font sizes
        cex.main = cex_title / 10,
        cex.lab = cex_axislabel / 10,
        cex.axis = cex_axis / 10
      )
    } else {
      if (other_plot_type == "0") { # Violin plot
        if (length(not_plot_points) > 0) {
          vioplot(
            as.list(data.frame(plot_data_m)),
            col = my_colours_2,
            horizontal = my_orientation,
            border = violin_border,
            cex.axis = cex_axis / 10,
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
          axis(if (my_orientation) 1 else 2, cex.axis = cex_axis / 10)
          axis(
            if (my_orientation) 2 else 1,
            at = seq_len(nr_of_samples),
            labels = colnames(plot_data),
            cex.axis = cex_axis / 10
          )
        }
        title(
          main = my_title,
          sub = my_subtitle,
          xlab = my_xlab,
          ylab = my_ylab,
          cex.main = cex_title / 10,
          cex.lab = cex_axislabel / 10
        )
      } else { # Bean plot
        my_beanplot_center <- if (bean_plot_median_mean == 0) {
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
            border = bean_border,
            what = c(1, 1, 1, as.logical(bean_plot_median_mean)),
            cex.axis = cex_axis / 10,
            overallline = my_beanplot_center,
            names = colnames(plot_data)[not_plot_points],
            frame.plot = FALSE,
            log = my_log
          )
          axis(
            if (my_orientation) 2 else 1,
            at = seq_len(nr_of_samples),
            labels = colnames(plot_data),
            cex.axis = cex_axis / 10
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
          axis(if (my_orientation) 1 else 2, cex.axis = cex_axis / 10)
          axis(
            if (my_orientation) 2 else 1,
            at = seq_len(nr_of_samples),
            labels = colnames(plot_data),
            cex.axis = cex_axis / 10
          )
        }
        title(
          main = my_title,
          sub = my_subtitle,
          xlab = my_xlab,
          ylab = my_ylab,
          cex.main = cex_title / 10,
          cex.lab = cex_axislabel / 10
        )
      }
    }

    # Add grid
    if (add_grid == 1) {
      grid()
    } else if (add_grid == 2) {
      grid(nx = NULL, ny = NA)
    } else if (add_grid == 3) {
      grid(nx = NA, ny = NULL)
    }

    # Samples means
    if (add_means && plot_type == "0") {
      boxplot_means <- colMeans(plot_data, na.rm = TRUE)
      if (my_orientation) {
        points(boxplot_means, seq_along(boxplot_means), pch = 18, col = "red")
      } else {
        points(seq_along(boxplot_means), boxplot_means, pch = 18, col = "red")
      }

      # Add CI of means
      if (add_mean_ci) {
        for (i in seq_along(plot_data)) {
          my_sample <- na.omit(plot_data[[i]])
          n <- length(my_sample)
          if (n > 1) {
            standard_error <- sd(my_sample) / sqrt(n)
            ci_level <- mean_ci / 100
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
    if (show_nr_of_points) {
      nr_points <- boxplot_stats()$n
      if (my_orientation) {
        pos_x <- if (log_scale) 10^par("usr")[2] else par("usr")[2]
        text(
          x = pos_x,
          y = seq_along(nr_points),
          labels = nr_points,
          pos = 2
        )
      } else {
        pos_y <- if (log_scale) 10^par("usr")[4] else par("usr")[4]
        text(
          x = seq_along(nr_points),
          y = pos_y,
          labels = nr_points,
          pos = 1
        )
      }
    }

    # Add data points if selected or if forced by plotDataPoints limit
    if (show_data_points || length(plot_points) > 0) {
      plot_data_points <- plot_data
      if (!show_data_points && length(plot_points) > 0) {
        # Only plot points for samples below the limit
        plot_data_points[, not_plot_points] <- NA
      }

      if (datapoint_type == 1) { # Bee swarm
        beeswarm(
          plot_data_points,
          add = TRUE,
          col = point_c,
          horizontal = my_orientation,
          cex = point_size / 10,
          pch = 16
        )
      } else { # Jittered or Default
        jittered_points(
          plot_data_points,
          my_orientation,
          datapoint_type,
          point_colors,
          point_transparency,
          point_size / 10
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
