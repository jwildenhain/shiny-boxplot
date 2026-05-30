# Specifies the arrangement of data points (normal or jittered).
# point_type: 0 = normal, 2 = jittered
jittered_points <- function(data_matrix, my_horizontal = FALSE, point_type,
                            point_colors, point_transparency, point_size) {
  # normal boxplots
  if (my_horizontal) {
    for (i in seq_len(ncol(data_matrix))) {
      alpha_val <- 255 * (point_transparency / 100)
      col_rgb <- rgb(
        t(col2rgb(point_colors[i])),
        maxColorValue = 255,
        alpha = alpha_val
      )
      if (point_type == 0) {
        points(
          data_matrix[, i],
          rep(i, nrow(data_matrix)),
          col = col_rgb,
          pch = 16,
          cex = point_size
        )
      } else {
        points(
          data_matrix[, i],
          jitter(rep(i, nrow(data_matrix)), amount = 0.25),
          col = col_rgb,
          pch = 16,
          cex = point_size
        )
      }
    }
  } else {
    # horizontal boxplots
    for (i in seq_len(ncol(data_matrix))) {
      alpha_val <- 255 * (point_transparency / 100)
      col_rgb <- rgb(
        t(col2rgb(point_colors[i])),
        maxColorValue = 255,
        alpha = alpha_val
      )
      if (point_type == 0) {
        points(
          rep(i, nrow(data_matrix)),
          data_matrix[, i],
          col = col_rgb,
          pch = 16,
          cex = point_size
        )
      } else {
        points(
          jitter(rep(i, nrow(data_matrix)), amount = 0.25),
          data_matrix[, i],
          col = col_rgb,
          pch = 16,
          cex = point_size
        )
      }
    }
  }
}
