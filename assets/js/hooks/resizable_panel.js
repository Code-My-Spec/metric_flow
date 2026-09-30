/**
 * ResizablePanel hook — adds drag-to-resize on a handle element.
 *
 * Usage: add phx-hook="ResizablePanel" to the drag handle div.
 *
 * data-target: CSS selector for the panel to resize
 * data-direction: "left"/"right" resize width (from the right/left edge);
 *   "bottom" resizes height (dragging down grows the panel)
 * data-min-width / data-max-width: width bounds in px (default 200 / 600)
 * data-min-height / data-max-height: height bounds in px (default 200 / 900)
 */
const ResizablePanel = {
  mounted() {
    this.target = document.querySelector(this.el.dataset.target)
    this.direction = this.el.dataset.direction || "left"
    this.vertical = this.direction === "bottom"
    this.minWidth = parseInt(this.el.dataset.minWidth || "200", 10)
    this.maxWidth = parseInt(this.el.dataset.maxWidth || "600", 10)
    this.minHeight = parseInt(this.el.dataset.minHeight || "200", 10)
    this.maxHeight = parseInt(this.el.dataset.maxHeight || "900", 10)
    this.dragging = false

    this.onMouseDown = (e) => {
      e.preventDefault()
      this.dragging = true
      this.startX = e.clientX
      this.startY = e.clientY
      this.startWidth = this.target ? this.target.offsetWidth : 0
      this.startHeight = this.target ? this.target.offsetHeight : 0
      document.body.style.cursor = this.vertical ? "row-resize" : "col-resize"
      document.body.style.userSelect = "none"
    }

    this.onMouseMove = (e) => {
      if (!this.dragging || !this.target) return

      if (this.vertical) {
        const dy = e.clientY - this.startY
        const newHeight = Math.max(this.minHeight, Math.min(this.maxHeight, this.startHeight + dy))
        this.target.style.height = `${newHeight}px`
        return
      }

      const dx = e.clientX - this.startX
      let newWidth
      if (this.direction === "left") {
        newWidth = this.startWidth + dx
      } else {
        newWidth = this.startWidth - dx
      }
      newWidth = Math.max(this.minWidth, Math.min(this.maxWidth, newWidth))
      this.target.style.width = `${newWidth}px`
    }

    this.onMouseUp = () => {
      if (!this.dragging) return
      this.dragging = false
      document.body.style.cursor = ""
      document.body.style.userSelect = ""
    }

    this.el.addEventListener("mousedown", this.onMouseDown)
    document.addEventListener("mousemove", this.onMouseMove)
    document.addEventListener("mouseup", this.onMouseUp)
  },

  updated() {
    this.target = document.querySelector(this.el.dataset.target)
  },

  destroyed() {
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup", this.onMouseUp)
  }
}

export { ResizablePanel }
