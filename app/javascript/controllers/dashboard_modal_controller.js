import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["previewDialog", "previewImage", "previewCaption"]

  open(event) {
    const dialog = document.getElementById(event.params.dialogId)
    if (!dialog || typeof dialog.showModal !== "function") return

    dialog.showModal()
  }

  openImage(event) {
    if (!this.hasPreviewDialogTarget || !this.hasPreviewImageTarget) return

    const dialog = this.previewDialogTarget
    const image = this.previewImageTarget
    const caption = this.hasPreviewCaptionTarget ? this.previewCaptionTarget : null

    image.src = event.params.imageUrl || ""
    image.alt = event.params.imageAlt || "Alert snapshot"

    if (caption) {
      caption.textContent = event.params.caption || ""
      caption.classList.toggle("hidden", caption.textContent.trim().length === 0)
    }

    if (typeof dialog.showModal !== "function") return
    dialog.showModal()
  }

  close(event) {
    const dialog = event.target.closest("dialog")
    if (!dialog) return

    dialog.close()
  }

  backdropClose(event) {
    if (event.target.nodeName !== "DIALOG") return
    event.target.close()
  }
}
