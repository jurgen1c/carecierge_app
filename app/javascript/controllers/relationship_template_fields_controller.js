import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "group"]
  static values = { defaultType: String }

  connect() {
    this.update()
  }

  update() {
    const selectedType = this.typeTarget.value
    const availableTypes = this.groupTargets.map((group) => group.dataset.relationshipTemplateFieldsTypeValue)
    const defaultType = availableTypes.includes(this.defaultTypeValue) ? this.defaultTypeValue : null
    const activeType = [selectedType, defaultType, availableTypes[0]].find((type) => availableTypes.includes(type))

    this.groupTargets.forEach((group) => {
      const inactive = group.dataset.relationshipTemplateFieldsTypeValue !== activeType

      group.hidden = inactive
      group.disabled = inactive
    })
  }
}
