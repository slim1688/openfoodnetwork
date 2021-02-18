window.Darkswarm = angular.module("Darkswarm", [
  'ngResource',
  'mm.foundation',
  'LocalStorageModule',
  'infinite-scroll',
  'angular-flash.service',
  'templates',
  'ngSanitize',
  'ngAnimate',
  'uiGmapgoogle-maps',
  'duScroll',
  'angularFileUpload',
  'angularSlideables'
]).config ($httpProvider, $tooltipProvider, $locationProvider, $anchorScrollProvider) ->
  $httpProvider.defaults.headers['common']['X-Requested-With'] = 'XMLHttpRequest'
  $httpProvider.defaults.headers.common['Accept'] = "application/json, text/javascript, */*"

  # We manually handle our scrolling
  $anchorScrollProvider.disableAutoScrolling()
