#!/usr/bin/env python3
import sys
import json
import os
import subprocess
import tempfile

def log(msg):
    sys.stderr.write(f"LOG: {msg}\n")
    sys.stderr.flush()

def generate_plot(arguments):
    # Extract nested sections (supporting the new JSON Schema spec)
    data_config = arguments.get("data_config", {})
    visualization = arguments.get("visualization", {})
    styling = arguments.get("styling", {})
    overlays = arguments.get("overlays", {})
    
    # Fallback to old flat structure if present (for backward compatibility)
    data_str = data_config.get("values", arguments.get("data", ""))
    output_path = arguments.get("output_path", "")
    
    plot_type = visualization.get("plot_type", arguments.get("plot_type", "boxplot"))
    plot_engine = visualization.get("plot_engine", arguments.get("plot_engine", "classic"))
    style_guide = visualization.get("style_guide", arguments.get("style_guide", "none"))
    orientation = visualization.get("orientation", arguments.get("orientation", "vertical"))
    log_scale = visualization.get("log_scale", arguments.get("log_scale", False))
    
    title = styling.get("title", arguments.get("title", ""))
    subtitle = styling.get("subtitle", arguments.get("subtitle", ""))
    xlab = styling.get("xlab", arguments.get("xlab", ""))
    ylab = styling.get("ylab", arguments.get("ylab", ""))
    colors = styling.get("colors", arguments.get("colors", []))
    add_grid = styling.get("add_grid", arguments.get("add_grid", "none"))
    
    show_points = overlays.get("show_points", arguments.get("show_points", False))
    point_type = overlays.get("point_type", arguments.get("point_type", "jittered"))
    point_size = overlays.get("point_size", arguments.get("point_size", 1.0))
    point_transparency = overlays.get("point_transparency", arguments.get("point_transparency", 50))
    add_means = overlays.get("add_means", arguments.get("add_means", False))
    add_mean_ci = overlays.get("add_mean_ci", arguments.get("add_mean_ci", False))
    mean_ci_level = overlays.get("mean_ci_level", arguments.get("mean_ci_level", 95))
    varwidth = overlays.get("varwidth", arguments.get("varwidth", False))
    notch = overlays.get("notch", arguments.get("notch", False))
    
    # Validation
    if not data_str:
        raise ValueError("Missing 'data' or 'data_config.values' argument")
    if not output_path:
        raise ValueError("Missing 'output_path' argument")
        
    # Resolve absolute paths
    output_path = os.path.abspath(output_path)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # Create R list for colors
    if colors:
        colors_r = "c(" + ", ".join(f'"{c}"' for c in colors) + ")"
    else:
        colors_r = "NULL"
        
    # R Template code supporting both Classic R and ggplot2 along with style guides
    r_code_template = """
source("/home/jw/Source/BoxPlotR.shiny/BoxPlotR_functions.R")
source("/home/jw/Source/BoxPlotR.shiny/boxplot_stats_Function.R")
library(beeswarm)
library(vioplot)
library(beanplot)
library(sm)

# Load data
data_str <- __DATA_STR__
plot_data <- read.csv(text = data_str, header = TRUE, check.names = FALSE)
plot_data_m <- as.matrix(plot_data)

# Colors
my_colours <- __COLORS_R__
if (is.null(my_colours) || length(my_colours) < ncol(plot_data)) {
  library(RColorBrewer)
  my_colours <- brewer.pal(max(3, ncol(plot_data)), "Pastel1")[1:ncol(plot_data)]
}

my_orientation <- __ORIENTATION__
my_log_val <- __LOG_SCALE__

if ("__PLOT_ENGINE__" == "ggplot2") {
  library(ggplot2)
  
  # Convert plot_data to long format
  df_long <- data.frame(
    Value = unlist(plot_data, use.names = FALSE),
    Group = rep(colnames(plot_data), each = nrow(plot_data))
  )
  df_long <- na.omit(df_long)
  df_long$Group <- factor(df_long$Group, levels = colnames(plot_data))
  
  # Prepare recycled colors vector
  plot_colours <- rep(my_colours, length.out = ncol(plot_data))
  
  if ("__PLOT_TYPE__" == "boxplot") {
    # Calculate boxplot stats using overridden boxplot()
    bp_stats <- boxplot(plot_data, range = 1.5, plot = FALSE)
    
    notchlower_val <- bp_stats$conf[1, ]
    notchupper_val <- bp_stats$conf[2, ]
    if (my_log_val) {
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
        varwidth = __VARWIDTH__,
        notch = __NOTCH__,
        width = 0.6
      ))
      
    # Identify outliers matching the calculated whiskers
    df_outliers <- df_long
    df_outliers$ymin <- df_stats$ymin[match(df_outliers$Group, df_stats$Group)]
    df_outliers$ymax <- df_stats$ymax[match(df_outliers$Group, df_stats$Group)]
    df_outliers <- df_outliers[df_outliers$Value < df_outliers$ymin | df_outliers$Value > df_outliers$ymax, ]
    
    if (!__SHOW_POINTS__ && nrow(df_outliers) > 0) {
      p <- p + geom_point(
        data = df_outliers,
        aes(x = Group, y = Value),
        color = "black",
        size = 1.5,
        shape = 19,
        inherit.aes = FALSE
      )
    }
  } else if ("__PLOT_TYPE__" == "violin") {
    p <- ggplot(df_long, aes(x = Group, y = Value, fill = Group)) +
      geom_violin(color = "black", width = 0.8)
  } else if ("__PLOT_TYPE__" == "beanplot") {
    p <- ggplot(df_long, aes(x = Group, y = Value, fill = Group)) +
      geom_violin(color = "black", width = 0.8, alpha = 0.7) +
      stat_summary(
        fun = "median",
        geom = "crossbar",
        width = 0.4,
        color = "black",
        middle.linewidth = 0.8
      ) +
      geom_segment(
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
  
  # Apply colors
  p <- p + scale_fill_manual(values = plot_colours)
  
  # Points overlay
  if (__SHOW_POINTS__) {
    pt_trans <- 1 - (__POINT_TRANSPARENCY__ / 100)
    pt_sz <- __POINT_SIZE__
    pt_col <- "#334155"
    points_data <- if ("__PLOT_TYPE__" == "boxplot") df_long else NULL
    points_aes <- if ("__PLOT_TYPE__" == "boxplot") aes(y = Value) else NULL
    
    if ("__POINT_TYPE__" == "beeswarm" || "__POINT_TYPE__" == "jittered") {
      p <- p + geom_jitter(
        data = points_data,
        mapping = points_aes,
        width = if ("__POINT_TYPE__" == "beeswarm") 0.05 else 0.2,
        height = 0,
        color = pt_col, size = pt_sz, alpha = pt_trans
      )
    } else {
      p <- p + geom_point(
        data = points_data,
        mapping = points_aes,
        position = position_nudge(x = 0),
        color = pt_col, size = pt_sz, alpha = pt_trans
      )
    }
  }
  
  # Add means
  if (__ADD_MEANS__ && "__PLOT_TYPE__" == "boxplot") {
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
    if (__ADD_MEAN_CI__) {
      ci_fun <- function(x) {
        n <- sum(!is.na(x))
        if (n <= 1) return(c(ymin = NA, ymax = NA))
        se <- sd(x, na.rm = TRUE) / sqrt(n)
        ci_level <- __MEAN_CI_LEVEL__ / 100
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
  
  # Log scale
  if (my_log_val) {
    p <- p + scale_y_log10()
  }
  
  # Labels
  p <- p + labs(
    title = "__TITLE__",
    subtitle = "__SUBTITLE__",
    x = "__XLAB__",
    y = "__YLAB__"
  )
  
  # Orientation / flipped coordinates
  if (my_orientation) {
    p <- p + coord_flip()
  }
  
  # Resolve style guide defaults for ggplot
  style_font <- "Inter"
  bg_fill <- "white"
  panel_bg_fill <- "white"
  grid_color <- "#e2e8f0"
  axis_line_color <- "#475569"
  plot_title_hjust <- 0.5
  
  if ("__STYLE_GUIDE__" == "nature") {
    style_font <- "sans"
  } else if ("__STYLE_GUIDE__" == "science") {
    style_font <- "serif"
  } else if ("__STYLE_GUIDE__" == "economist") {
    style_font <- "sans"
    bg_fill <- "#e4eef2"
    panel_bg_fill <- "#e4eef2"
    grid_color <- "white"
    axis_line_color <- "#1e293b"
    plot_title_hjust <- 0
  } else if ("__STYLE_GUIDE__" == "ft") {
    style_font <- "serif"
    bg_fill <- "#fff1e5"
    panel_bg_fill <- "#fff1e5"
    grid_color <- "#e2d6ca"
    axis_line_color <- "#1e293b"
    plot_title_hjust <- 0
  }
  
  # Theme minimal base
  p <- p + theme_minimal(base_family = style_font) +
    theme(
      plot.title = element_text(size = 14, face = "bold", hjust = plot_title_hjust),
      plot.subtitle = element_text(size = 11, hjust = plot_title_hjust, color = "#475569"),
      axis.title.x = element_text(size = 12),
      axis.title.y = element_text(size = 12),
      axis.text = element_text(size = 10),
      legend.position = "none",
      panel.background = element_rect(fill = panel_bg_fill, color = NA),
      plot.background = element_rect(fill = bg_fill, color = NA),
      axis.line = element_line(color = axis_line_color, linewidth = 0.6),
      axis.ticks = element_line(color = axis_line_color, linewidth = 0.6)
    )
    
  # Gridlines
  if ("__ADD_GRID__" == "none") {
    p <- p + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())
  } else if ("__ADD_GRID__" == "x") {
    p <- p + theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(), panel.grid.major.x = element_line(color = grid_color))
  } else if ("__ADD_GRID__" == "y") {
    p <- p + theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(), panel.grid.major.y = element_line(color = grid_color))
  } else {
    p <- p + theme(
      panel.grid.major = element_line(color = grid_color),
      panel.grid.minor = element_blank()
    )
  }
  
  # Print / Save plot
  png("__OUTPUT_PATH__", width = 800, height = 600, res = 120)
  print(p)
  dev.off()
  
} else {
  # Classic Base R drawing code with style guides
  bg_fill <- "white"
  style_font <- ""
  
  if ("__STYLE_GUIDE__" == "nature") {
    style_font <- "sans"
  } else if ("__STYLE_GUIDE__" == "science") {
    style_font <- "serif"
  } else if ("__STYLE_GUIDE__" == "economist") {
    style_font <- "sans"
    bg_fill <- "#e4eef2"
  } else if ("__STYLE_GUIDE__" == "ft") {
    style_font <- "serif"
    bg_fill <- "#fff1e5"
  }
  
  my_log <- if (my_log_val) (if (my_orientation) "x" else "y") else ""

  # Ranges
  r <- range(plot_data, na.rm = TRUE)
  if (my_log_val) {
    shared_lim <- c(r[1], r[2] * (10^(diff(log10(r[r > 0])) * 0.15)))
  } else {
    padding <- diff(r) * 0.15
    shared_lim <- c(r[1] - (diff(r) * 0.04), r[2] + padding)
  }
  
  png("__OUTPUT_PATH__", width = 800, height = 600, res = 120)
  par(bg = bg_fill, family = style_font)
  par(mar = c(5, 5, 4, 2) + 0.1)
  
  # Drawing
  if ("__PLOT_TYPE__" == "boxplot") {
    boxplot(
      plot_data,
      main = "__TITLE__",
      sub = "__SUBTITLE__",
      xlab = "__XLAB__",
      ylab = "__YLAB__",
      col = my_colours,
      horizontal = my_orientation,
      varwidth = __VARWIDTH__,
      notch = __NOTCH__,
      outline = __OUTLINE__,
      range = 1.5,
      log = my_log,
      ylim = if (!my_orientation) shared_lim else NULL,
      xlim = if (my_orientation) shared_lim else NULL,
      frame.plot = FALSE
    )
  } else if ("__PLOT_TYPE__" == "violin") {
    vioplot(
      as.list(plot_data),
      col = my_colours,
      horizontal = my_orientation,
      border = "black",
      ylim = shared_lim,
      names = colnames(plot_data),
      log = my_log
    )
    title(
      main = "__TITLE__",
      sub = "__SUBTITLE__",
      xlab = "__XLAB__",
      ylab = "__YLAB__"
    )
  } else if ("__PLOT_TYPE__" == "beanplot") {
    beanplot(
      plot_data,
      xlim = c(0.5, ncol(plot_data) + 0.5),
      ylim = shared_lim,
      col = as.list(my_colours),
      horizontal = my_orientation,
      border = "black",
      names = colnames(plot_data),
      frame.plot = FALSE,
      log = my_log
    )
    title(
      main = "__TITLE__",
      sub = "__SUBTITLE__",
      xlab = "__XLAB__",
      ylab = "__YLAB__"
    )
  }
  
  # Add grid
  if ("__ADD_GRID__" == "both") {
    grid()
  } else if ("__ADD_GRID__" == "x") {
    grid(nx = NULL, ny = NA)
  } else if ("__ADD_GRID__" == "y") {
    grid(nx = NA, ny = NULL)
  }
  
  # Add data points
  if (__SHOW_POINTS__) {
    point_style <- if ("__POINT_TYPE__" == "jittered") 2 else if ("__POINT_TYPE__" == "beeswarm") 1 else 0
    if (point_style == 1) {
      beeswarm(
        plot_data,
        add = TRUE,
        col = "#334155",
        horizontal = my_orientation,
        cex = __POINT_SIZE__,
        pch = 16
      )
    } else {
      jittered_points(
        plot_data_m,
        my_horizontal = my_orientation,
        point_type = point_style,
        point_colors = rep("#334155", ncol(plot_data)),
        point_transparency = __POINT_TRANSPARENCY__,
        point_size = __POINT_SIZE__
      )
    }
  }
  
  # Add means
  if (__ADD_MEANS__ && "__PLOT_TYPE__" == "boxplot") {
    boxplot_means <- colMeans(plot_data, na.rm = TRUE)
    if (my_orientation) {
      points(boxplot_means, seq_along(boxplot_means), pch = 18, col = "red", cex = 1.5)
    } else {
      points(seq_along(boxplot_means), boxplot_means, pch = 18, col = "red", cex = 1.5)
    }
    
    if (__ADD_MEAN_CI__) {
      for (i in seq_along(plot_data)) {
        my_sample <- na.omit(plot_data[[i]])
        n <- length(my_sample)
        if (n > 1) {
          standard_error <- sd(my_sample) / sqrt(n)
          ci_level <- __MEAN_CI_LEVEL__ / 100
          t_value <- qt((1 + ci_level) / 2, df = n - 1)
          margin_error <- t_value * standard_error
          lower_ci <- boxplot_means[i] - margin_error
          upper_ci <- boxplot_means[i] + margin_error
  
          if (my_orientation) {
            lines(c(lower_ci, upper_ci), c(i, i), col = "red", lwd = 2)
            lines(c(lower_ci, lower_ci), c(i - 0.1, i + 0.1), col = "red", lwd = 2)
            lines(c(upper_ci, upper_ci), c(i - 0.1, i + 0.1), col = "red", lwd = 2)
          } else {
            lines(c(i, i), c(lower_ci, upper_ci), col = "red", lwd = 2)
            lines(c(i - 0.1, i + 0.1), c(lower_ci, lower_ci), col = "red", lwd = 2)
            lines(c(i - 0.1, i + 0.1), c(upper_ci, upper_ci), col = "red", lwd = 2)
          }
        }
      }
    }
  }
  
  dev.off()
}
"""

    r_code = r_code_template
    r_code = r_code.replace("__DATA_STR__", json.dumps(data_str))
    r_code = r_code.replace("__COLORS_R__", colors_r)
    r_code = r_code.replace("__ORIENTATION__", "TRUE" if orientation == "horizontal" else "FALSE")
    r_code = r_code.replace("__LOG_SCALE__", "TRUE" if log_scale else "FALSE")
    r_code = r_code.replace("__OUTPUT_PATH__", output_path)
    r_code = r_code.replace("__PLOT_TYPE__", plot_type)
    r_code = r_code.replace("__TITLE__", title)
    r_code = r_code.replace("__SUBTITLE__", subtitle)
    r_code = r_code.replace("__XLAB__", xlab)
    r_code = r_code.replace("__YLAB__", ylab)
    r_code = r_code.replace("__VARWIDTH__", "TRUE" if varwidth else "FALSE")
    r_code = r_code.replace("__NOTCH__", "TRUE" if notch else "FALSE")
    r_code = r_code.replace("__OUTLINE__", "FALSE" if show_points else "TRUE")
    r_code = r_code.replace("__ADD_GRID__", add_grid)
    r_code = r_code.replace("__SHOW_POINTS__", "TRUE" if show_points else "FALSE")
    r_code = r_code.replace("__POINT_TYPE__", point_type)
    r_code = r_code.replace("__POINT_SIZE__", str(point_size))
    r_code = r_code.replace("__POINT_TRANSPARENCY__", str(point_transparency))
    r_code = r_code.replace("__ADD_MEANS__", "TRUE" if add_means else "FALSE")
    r_code = r_code.replace("__ADD_MEAN_CI__", "TRUE" if add_mean_ci else "FALSE")
    r_code = r_code.replace("__MEAN_CI_LEVEL__", str(mean_ci_level))
    
    r_code = r_code.replace("__PLOT_ENGINE__", plot_engine)
    r_code = r_code.replace("__STYLE_GUIDE__", style_guide)

    with tempfile.NamedTemporaryFile(suffix=".R", mode="w", delete=False) as f:
        f.write(r_code)
        temp_script_path = f.name
        
    try:
        log(f"Running Rscript on {temp_script_path}")
        result = subprocess.run(
            ["Rscript", temp_script_path],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            log(f"Rscript failed: {result.stderr}")
            raise RuntimeError(f"R plotting failed: {result.stderr}")
        log(f"Plot successfully generated and saved to {output_path}")
        return output_path
    finally:
        if os.path.exists(temp_script_path):
            os.remove(temp_script_path)

def main():
    log("BoxPlotR MCP Server starting...")
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            
            message = json.loads(line)
            method = message.get("method")
            msg_id = message.get("id")
            
            if method == "initialize":
                response = {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {
                            "tools": {}
                        },
                        "serverInfo": {
                            "name": "boxplotr-mcp-server",
                            "version": "1.0.0"
                        }
                    }
                }
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()
                
            elif method == "notifications/initialized":
                pass
                
            elif method == "tools/list":
                response = {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "tools": [
                            {
                                "name": "generate_boxplot",
                                "description": "Generates a highly-customizable box plot, violin plot, or bean plot using the BoxPlotR backend and saves it as an image.",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "data_config": {
                                            "type": "object",
                                            "description": "Input data configurations",
                                            "properties": {
                                                "values": {
                                                    "type": "string",
                                                    "description": "The input data as CSV or TSV string where columns represent different samples/conditions"
                                                }
                                            },
                                            "required": ["values"]
                                        },
                                        "visualization": {
                                            "type": "object",
                                            "description": "Plot rendering and engine structural parameters",
                                            "properties": {
                                                "plot_type": {
                                                    "type": "string",
                                                    "enum": ["boxplot", "violin", "beanplot"],
                                                    "description": "The type of plot to generate"
                                                },
                                                "plot_engine": {
                                                    "type": "string",
                                                    "enum": ["classic", "ggplot2"],
                                                    "description": "Plotting engine: 'classic' for Base R or 'ggplot2' for modern rendering (default: classic)"
                                                },
                                                "style_guide": {
                                                    "type": "string",
                                                    "enum": ["none", "nature", "science", "economist", "ft"],
                                                    "description": "Visual preset style guide: 'none', 'nature', 'science', 'economist', or 'ft' (default: none)"
                                                },
                                                "orientation": {
                                                    "type": "string",
                                                    "enum": ["vertical", "horizontal"],
                                                    "description": "Orientation of the plot (default: vertical)"
                                                },
                                                "log_scale": {
                                                    "type": "boolean",
                                                    "description": "Whether to use a logarithmic scale (log10) for the numeric axis"
                                                }
                                            },
                                            "required": ["plot_type"]
                                        },
                                        "styling": {
                                            "type": "object",
                                            "description": "Custom aesthetic and text properties",
                                            "properties": {
                                                "title": { "type": "string", "description": "Main title of the plot" },
                                                "subtitle": { "type": "string", "description": "Subtitle of the plot" },
                                                "xlab": { "type": "string", "description": "X-axis label" },
                                                "ylab": { "type": "string", "description": "Y-axis label" },
                                                "colors": {
                                                    "type": "array",
                                                    "items": { "type": "string" },
                                                    "description": "Array of HEX colors for each sample/condition"
                                                },
                                                "add_grid": {
                                                    "type": "string",
                                                    "enum": ["none", "both", "x", "y"],
                                                    "description": "Background grid: 'none', 'both', 'x', or 'y' (default: none)"
                                                }
                                            }
                                        },
                                        "overlays": {
                                            "type": "object",
                                            "description": "Raw data point and statistical overlay properties",
                                            "properties": {
                                                "show_points": { "type": "boolean", "description": "Whether to display individual data points on top of the plot" },
                                                "point_type": {
                                                    "type": "string",
                                                    "enum": ["normal", "jittered", "beeswarm"],
                                                    "description": "The arrangement style for data points (default: jittered)"
                                                },
                                                "point_size": { "type": "number", "description": "Size factor of the plotted data points (e.g. 1.0)" },
                                                "point_transparency": { "type": "number", "description": "Transparency level of the plotted points from 0 to 100 (default: 50)" },
                                                "add_means": { "type": "boolean", "description": "For boxplots, whether to plot the mean of each sample as a red diamond" },
                                                "add_mean_ci": { "type": "boolean", "description": "For boxplots, whether to add confidence intervals for the sample means" },
                                                "mean_ci_level": {
                                                    "type": "integer",
                                                    "enum": [83, 90, 95],
                                                    "description": "The confidence level percentage for the means CI (default: 95)"
                                                },
                                                "varwidth": { "type": "boolean", "description": "For boxplots, whether box widths should be proportional to square-roots of observations counts" },
                                                "notch": { "type": "boolean", "description": "For boxplots, whether to add notches showing 95% CI of medians" }
                                            }
                                        },
                                        "output_path": {
                                            "type": "string",
                                            "description": "Absolute path where the resulting PNG plot image should be saved"
                                        }
                                    },
                                    "required": ["data_config", "visualization", "output_path"]
                                }
                            }
                        ]
                    }
                }
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()
                
            elif method == "notifications/initialized":
                pass
                
            elif method == "tools/call":
                params = message.get("params", {})
                tool_name = params.get("name")
                arguments = params.get("arguments", {})
                
                if tool_name == "generate_boxplot":
                    try:
                        out_path = generate_plot(arguments)
                        response = {
                            "jsonrpc": "2.0",
                            "id": msg_id,
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": f"Success! BoxPlotR generated the plot successfully and saved it to: {out_path}"
                                    }
                                ],
                                "isError": False
                            }
                        }
                    except Exception as e:
                        response = {
                            "jsonrpc": "2.0",
                            "id": msg_id,
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": f"Error generating plot: {str(e)}"
                                    }
                                ],
                                "isError": True
                            }
                        }
                    sys.stdout.write(json.dumps(response) + "\n")
                    sys.stdout.flush()
            else:
                if msg_id is not None:
                    response = {
                        "jsonrpc": "2.0",
                        "id": msg_id,
                        "error": {
                            "code": -32601,
                            "message": f"Method not found: {method}"
                        }
                    }
                    sys.stdout.write(json.dumps(response) + "\n")
                    sys.stdout.flush()
        except Exception as e:
            log(f"Unhandled error in loop: {str(e)}")

if __name__ == "__main__":
    main()
