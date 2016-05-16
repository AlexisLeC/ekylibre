{ deu: {
  i18n: {
    dir: 'ltr',
    iso2: 'de',
    name: 'Deutsch',
    plural: {
      keys: [:one, :other],
      rule: ->(n) { n == 1 ? :one : :other }
    }
  },
  date: {
    order: [:day, :month, :year]
  }
} }
