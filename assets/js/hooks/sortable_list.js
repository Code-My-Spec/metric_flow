const SortableList = {
  mounted() {
    this.draggedIndex = null

    this.el.addEventListener("dragstart", (e) => {
      const card = e.target.closest("[data-role='visualization-card']")
      if (!card) return
      this.draggedIndex = Array.from(this.el.children).indexOf(card)
      e.dataTransfer.effectAllowed = "move"
      card.classList.add("opacity-50")
    })

    this.el.addEventListener("dragend", (e) => {
      const card = e.target.closest("[data-role='visualization-card']")
      if (card) card.classList.remove("opacity-50")
      this.draggedIndex = null
    })

    this.el.addEventListener("dragover", (e) => {
      if (this.draggedIndex === null) return
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
    })

    this.el.addEventListener("drop", (e) => {
      if (this.draggedIndex === null) return
      e.preventDefault()

      const card = e.target.closest("[data-role='visualization-card']")
      if (!card) return

      const targetIndex = Array.from(this.el.children).indexOf(card)
      if (targetIndex === -1 || targetIndex === this.draggedIndex) return

      this.pushEvent("reorder_visualizations", {from: this.draggedIndex, to: targetIndex})
    })
  }
}

export {SortableList}
