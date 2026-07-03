import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "group"]
  static values = { fallbackType: String }

  connect() {
    this.update()
  }

  update() {
    const selectedType = this.typeTarget.value
    const availableTypes = this.groupTargets.map((group) => group.dataset.relationshipTemplateFieldsTypeValue)
    const activeType = availableTypes.includes(selectedType) ? selectedType : this.fallbackTypeValue

    this.groupTargets.forEach((group) => {
      const inactive = group.dataset.relationshipTemplateFieldsTypeValue !== activeType

      group.hidden = inactive
      group.disabled = inactive
    })
  }
}
