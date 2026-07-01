import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "group"]

  connect() {
    this.update()
  }

  update() {
    const selectedType = this.typeTarget.value

    this.groupTargets.forEach((group) => {
      const inactive = group.dataset.relationshipTemplateFieldsTypeValue !== selectedType

      group.hidden = inactive
      group.disabled = inactive
    })
  }
}
