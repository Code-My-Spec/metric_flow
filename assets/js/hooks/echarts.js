import * as echarts from "echarts"

const ECharts = {
  mounted() {
    this._lastOption = this.el.dataset.option
    this.renderChart()

    // Re-render on container resize so the chart fills available space
    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart && this.el.clientWidth > 0) {
        this.chart.resize()
      }
    })
    this.resizeObserver.observe(this.el)
  },
  updated() {
    // Only re-render when the option actually changed, not on every DOM patch
    const currentOption = this.el.dataset.option
    if (currentOption !== this._lastOption) {
      this._lastOption = currentOption
      this.renderChart()
    }
  },
  destroyed() {
    if (this.chart) this.chart.dispose()
    if (this.resizeObserver) this.resizeObserver.disconnect()
  },
  renderChart() {
    const optionStr = this.el.dataset.option
    if (!optionStr) return

    // Skip render if container has no width (e.g. a hidden panel)
    if (this.el.clientWidth === 0) return

    const option = JSON.parse(optionStr)

    if (!this.chart) {
      this.chart = echarts.init(this.el)
    }

    // `true` (notMerge) replaces the option outright rather than merging
    // with whatever series/axes the previous option left behind.
    this.chart.setOption(option, true)
  }
}

export { ECharts }
