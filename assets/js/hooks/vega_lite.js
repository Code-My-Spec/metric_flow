import vegaEmbed from "../../vendor/vega-embed.js"

const VegaLite = {
  mounted() {
    this._lastSpec = this.el.dataset.spec
    this.renderChart()
    this.handleEvent("update-chart", ({spec}) => {
      this.el.dataset.spec = JSON.stringify(spec)
      this._lastSpec = this.el.dataset.spec
      this.renderChart()
    })

    // Re-render on container resize so the chart fills available space
    this.resizeObserver = new ResizeObserver(() => {
      if (this._resizeTimer) clearTimeout(this._resizeTimer)
      this._resizeTimer = setTimeout(() => {
        // Only re-render if container has real dimensions
        if (this.el.clientWidth > 0) {
          this.renderChart()
        }
      }, 250)
    })
    this.resizeObserver.observe(this.el)
  },
  updated() {
    // Only re-render when the spec actually changed, not on every DOM patch
    const currentSpec = this.el.dataset.spec
    if (currentSpec !== this._lastSpec) {
      this._lastSpec = currentSpec
      this.renderChart()
    }
  },
  destroyed() {
    if (this.view) this.view.finalize()
    if (this.resizeObserver) this.resizeObserver.disconnect()
    if (this._resizeTimer) clearTimeout(this._resizeTimer)
  },
  renderChart() {
    const specStr = this.el.dataset.spec
    if (!specStr) return

    // Skip render if container has no width (height may be 0 for auto-sized containers)
    if (this.el.clientWidth === 0) return

    const spec = JSON.parse(specStr)

    // Strip layers with empty data to prevent infinite extent warnings
    if (spec.layer) {
      spec.layer = spec.layer.filter(l =>
        !l.data || !l.data.values || l.data.values.length > 0
      )
      if (spec.layer.length === 0) return
    }

    // Skip render if spec has no data to display
    if (!this._hasData(spec)) return

    // Use container width so the chart resizes with panels.
    // Keep the spec's own height (don't override to "container" which
    // requires the container to have an explicit height set).
    spec.width = "container"

    vegaEmbed(this.el, spec, {
      actions: false,
      renderer: "svg",
      ast: true
    })
      .then(result => { this.view = result.view })
      .catch(err => console.error("VegaLite render error:", err))
  },
  _hasData(spec) {
    if (spec.data && spec.data.url) return true
    if (spec.data && spec.data.values && spec.data.values.length > 0) return true
    if (spec.layer) {
      return spec.layer.some(l =>
        (l.data && l.data.values && l.data.values.length > 0) ||
        (l.data && l.data.url)
      )
    }
    return false
  }
}

export { VegaLite }
