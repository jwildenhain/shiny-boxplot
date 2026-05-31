# Release Notes - BoxPlotR v2.0.0 (Modernized)

We are proud to announce the official release of **BoxPlotR v2.0.0**. This milestone release fully modernizes the classic 13-year-old BoxPlotR codebase, bringing state-of-the-art **ggplot2 integration**, a **Model Context Protocol (MCP) server** for AI coding assistants, robust statistical overlays, and strict reactive stability.

---

## 🌟 What's New in v2.0.0

### 📊 1. Modern ggplot2 Rendering Engine
* **ggplot2 Integration**: Introduced a brand-new **Modern (ggplot2)** plotting engine, allowing users to toggle between Base R vector plots and modern ggplot2 layouts.
* **Premium Theme Presets**: Added professional journal-style preset themes, including **Nature**, **Science**, **The Economist**, and the **Financial Times (FT)**, making plot export ready for publication.
* **Smart Grid Customization**: Users can now selectively toggle background grid lines on both axis orientations (`x`, `y`, or `both`) to optimize scannability.

### 📐 2. High-Fidelity Overlays & Notch Fixes
* **Advanced Point Arrangements**: Seamlessly overlay individual data points using **normal**, **jittered**, or high-fidelity **beeswarm** point arrangements.
* **Sample Means & Confidence Intervals**: Added the option to compute and display sample means as red diamonds, complete with customizable confidence interval error bars (83%, 90%, or 95%).
* **Safe Logarithmic Scale Support**: Fixed a critical R layout flare-up distortion on logarithmic scales. Non-standard aesthetics (such as `notchlower` and `notchupper` under base R custom whisker calculations) are now manually pre-transformed (`log10(pmax(1e-10, val))`) to ensure flawless vector rendering.

### 🔌 3. Model Context Protocol (MCP) Server Integration
* **Dynamic AI Assistance**: Native Python implementation of an **MCP server** (`boxplotr_mcp_server.py`) working over line-by-line standard input/output (`stdio`).
* **Structured JSON Schema Specification**: Implements a clean, nested schema layout (`data_config`, `visualization`, `styling`, `overlays`, `output_path`) for robust code validation while preserving full flat-argument backward compatibility.
* **Verified Local Testing**: The Shiny application's **FAQ tab** has been expanded with clear command-line minified JSON-RPC testing sequences.

### 🔒 4. Stability, Safety, & Formats
* **Zero-Length Reactive Protection**: Integrated safe input validators at the top of the reactive engine, completely resolving the infamous Shiny `argument is of length zero` startup crash during transitions.
* **Native Excel Support**: Seamlessly parse, upload, and visualize modern `.xlsx` sheets without requiring external server conversions.
* **Automated Unit Testing**: Implemented a comprehensive `testthat` verification suite (`tests/test_ggplot_boxplot.R`) covering ggplot2 layouts, notch safety, and overlays under linear and log scales.

---

## 🚀 Getting Started with testing the MCP Server

You can execute the newly-documented, fully-validated test sequence directly from your terminal to verify standard I/O (NDJSON) plotting:

```bash
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "generate_boxplot", "arguments": {"data_config": {"values": "SampleA,SampleB\n12.5,8.9\n14.2,10.1\n15.8,11.5\n13.1,9.4"}, "visualization": {"plot_type": "boxplot", "plot_engine": "ggplot2", "style_guide": "economist", "orientation": "vertical", "log_scale": false}, "styling": {"title": "Comparison of Sample A and Sample B", "xlab": "Group", "ylab": "Value", "colors": ["#0ea5e9", "#ef4444"], "add_grid": "y"}, "overlays": {"show_points": true, "point_type": "jittered", "point_size": 1.2, "point_transparency": 30, "add_means": true, "notch": true}, "output_path": "assets/mcp_test_plot.png"}}}' | python3 boxplotr_mcp_server.py
```

This will output a successful JSON-RPC response confirming that the output image is generated at `assets/mcp_test_plot.png`!
