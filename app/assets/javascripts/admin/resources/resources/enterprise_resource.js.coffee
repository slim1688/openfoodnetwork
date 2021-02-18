angular.module("admin.resources").factory 'EnterpriseResource', ($resource) ->
  ignoredAttrs = ->
    ["$$hashKey", "producer", "package", "producerError", "packageError", "status"]

  $resource('/admin/enterprises/:id/:action.json', {}, {
    'index':
      method: 'GET'
      isArray: true
    'update':
      method: 'PUT'
    'removeLogo':
      url: '/api/enterprises/:id/logo.json'
      method: 'DELETE'
    'removePromoImage':
      url: '/api/enterprises/:id/promo_image.json'
      method: 'DELETE'
    'removeTermsAndConditions':
      url: '/api/enterprises/:id/terms_and_conditions.json'
      method: 'DELETE'
  })
