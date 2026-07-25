import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="client-search"
export default class extends Controller {
  static targets = ["select"]
  static values = {
    findUrl: String,
    showUrl: String
  }

  connect() {
    this.tomSelect = new TomSelect(this.selectTarget, {
      valueField: 'uuid',
      labelField: 'first_name',
      searchField: [ 'first_name', 'last_name', 'mobile_number' ],

      load: (query, callback) => {
        const url = `${this.findUrlValue}?q=${encodeURIComponent(query)}`

        fetch(url)
          .then(response => response.json())
          .then(json => {
            callback(json)
          })
      },

      onItemAdd: (uuid) => {
        this.element.innerHTML = ''
        this.element.ariaBusy = 'true'
        window.location.href = `${this.showUrlValue}?uuid=${uuid}`
      },

      render: {
        item: function(data, escape) {
          return `<div>${escape(data.first_name)} ${escape(data.last_name)} (${escape(data.mobile_number)})</div>`
        },
        option: function(data, escape) {
          return `<div>${escape(data.first_name)} ${escape(data.last_name)} (${escape(data.mobile_number)})</div>`
        }
      }
    })

    this.tomSelect.focus()

    // Turbo snapshots the page for later back/forward restores via
    // turbo:before-cache, which fires earlier than disconnect() ever does.
    // Tear down here too so the cached snapshot is always the plain
    // <select>, not TomSelect's mutated .ts-wrapper markup.
    this.beforeCacheHandler = () => this.#teardown()
    document.addEventListener('turbo:before-cache', this.beforeCacheHandler)
  }

  disconnect() {
    document.removeEventListener('turbo:before-cache', this.beforeCacheHandler)
    this.#teardown()
  }

  #teardown() {
    if (this.tomSelect) {
      this.tomSelect.destroy()
      this.tomSelect = null
    }
  }
}
