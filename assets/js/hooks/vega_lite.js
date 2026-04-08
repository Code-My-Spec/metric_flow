import vegaEmbed from "../../vendor/vega-embed.js"

const VegaLite = {
  mounted() {
    this.renderChart()
    this.handleEvent("update-chart", ({spec}) => {
      this.el.dataset.spec = JSON.stringify(spec)
      this.renderChart()
    })

    // Re-render on container resize so the chart fills available space
    this.resizeObserver = new ResizeObserver(() => {
      if (this._resizeTimer) clearTimeout(this._resizeTimer)
      this._resizeTimer = setTimeout(() => this.renderChart(), 150)
    })
    this.resizeObserver.observe(this.el)
  },
  updated() {
    this.renderChart()
  },
  destroyed() {
    if (this.view) this.view.finalize()
    if (this.resizeObserver) this.resizeObserver.disconnect()
    if (this._resizeTimer) clearTimeout(this._resizeTimer)
  },
  renderChart() {
    const specStr = this.el.dataset.spec
    if (!specStr) return
    const spec = JSON.parse(specStr)

    // Use container dimensions so the chart resizes with panels
    spec.width = "container"
    spec.height = "container"

    vegaEmbed(this.el, spec, {
      actions: false,
      renderer: "svg",
      ast: true
    })
      .then(result => { this.view = result.view })
      .catch(err => console.error("VegaLite render error:", err))
  }
}

export { VegaLite }
