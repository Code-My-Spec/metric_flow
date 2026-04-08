/**
 * ResizablePanel hook — adds drag-to-resize on a handle element.
 *
 * Usage: add phx-hook="ResizablePanel" to the drag handle div.
 *
 * data-target: CSS selector for the panel to resize
 * data-direction: "left" (resize from right edge) or "right" (resize from left edge)
 * data-min-width: minimum width in px (default 200)
 * data-max-width: maximum width in px (default 600)
 */
const ResizablePanel = {
  mounted() {
    this.target = document.querySelector(this.el.dataset.target)
    this.direction = this.el.dataset.direction || "left"
    this.minWidth = parseInt(this.el.dataset.minWidth || "200", 10)
    this.maxWidth = parseInt(this.el.dataset.maxWidth || "600", 10)
    this.dragging = false

    this.onMouseDown = (e) => {
      e.preventDefault()
      this.dragging = true
      this.startX = e.clientX
      this.startWidth = this.target ? this.target.offsetWidth : 0
      document.body.style.cursor = "col-resize"
      document.body.style.userSelect = "none"
    }

    this.onMouseMove = (e) => {
      if (!this.dragging || !this.target) return
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
