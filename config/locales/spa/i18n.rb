# -*- coding: utf-8 -*-
{ spa: {
  i18n: {
    dir: 'ltr',
    iso2: 'es',
    name: 'Español',
    plural: {
      keys: [:one, :other],
      rule: ->(n) { n == 1 ? :one : :other }
    }
  },
  date: {
    order: [:day, :month, :year]
  }
} }
