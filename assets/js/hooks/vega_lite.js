import vegaEmbed from "vega-embed"

const VegaLite = {
  mounted() {
    this.renderChart()
    this.handleEvent("update-chart", ({spec}) => {
      this.el.dataset.spec = JSON.stringify(spec)
      this.renderChart()
    })
  },
  destroyed() {
    if (this.view) this.view.finalize()
  },
  renderChart() {
    const specStr = this.el.dataset.spec
    if (!specStr) return
    const spec = JSON.parse(specStr)
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
