describe 'StripeElements Service', ->
  $httpBackend = $q = $rootScope = StripeElements = null
  StripeMock = { createToken: null }
  CardMock = { some: "card" }

  beforeEach ->
    module 'Darkswarm'
    module ($provide) ->
      $provide.value "railsFlash", null
      null

    inject (_StripeElements_, _$httpBackend_, _$q_, _$rootScope_) ->
      $httpBackend = _$httpBackend_
      StripeElements = _StripeElements_
      $q = _$q_
      $rootScope = _$rootScope_

  describe "requestToken", ->
    secrets = {}
    submit = null
    response = null

    beforeEach inject ($window) ->
      StripeElements.stripe = StripeMock
      StripeElements.card = CardMock

    describe "with satifactory data", ->
      beforeEach ->
        submit = jasmine.createSpy()
        response = { token: { id: "token", card: { brand: 'MasterCard', last4: "5678", exp_month: 10, exp_year: 2099 } } }
        StripeMock.createToken = => $q.when(response)

      it "saves the response data to secrets, and submits the form", ->
        StripeElements.requestToken(secrets, submit)
        $rootScope.$digest() # required for #then to by called
        expect(secrets.token).toEqual "token"
        expect(secrets.cc_type).toEqual "master"
        expect(submit).toHaveBeenCalled()

    describe "with unsatifactory data", ->
      beforeEach ->
        submit = jasmine.createSpy()
        response = { token: {id: "token" }, error: { message: 'There was a problem' } }
        StripeMock.createToken = => $q.when(response)

      it "doesn't submit the form, shows an error message instead", inject (Loading, RailsFlashLoader) ->
        spyOn(Loading, "clear")
        spyOn(RailsFlashLoader, "loadFlash")
        spyOn(Bugsnag, "notify")
        StripeElements.requestToken(secrets, submit).then (data) ->
          expect(submit).not.toHaveBeenCalled()
          expect(Loading.clear).toHaveBeenCalled()
          expect(RailsFlashLoader.loadFlash).toHaveBeenCalledWith({error: "Error: There was a problem"})
          expect(Bugsnag.notify).toHaveBeenCalled()

  describe 'mapTokenApiCardBrand', ->
    it "maps the brand returned by Stripe's tokenAPI to that required by activemerchant", ->
      expect(StripeElements.mapTokenApiCardBrand('MasterCard')).toEqual "master"
      expect(StripeElements.mapTokenApiCardBrand('Visa')).toEqual "visa"
      expect(StripeElements.mapTokenApiCardBrand('American Express')).toEqual "american_express"
      expect(StripeElements.mapTokenApiCardBrand('Discover')).toEqual "discover"
      expect(StripeElements.mapTokenApiCardBrand('JCB')).toEqual "jcb"
      expect(StripeElements.mapTokenApiCardBrand('Diners Club')).toEqual "diners_club"

  describe 'mapPaymentMethodsApiCardBrand', ->
    it "maps the brand returned by Stripe's paymentMethodsAPI to that required by activemerchant", ->
      expect(StripeElements.mapPaymentMethodsApiCardBrand('mastercard')).toEqual "master"
      expect(StripeElements.mapPaymentMethodsApiCardBrand('amex')).toEqual "american_express"
      expect(StripeElements.mapPaymentMethodsApiCardBrand('diners')).toEqual "diners_club"
      expect(StripeElements.mapPaymentMethodsApiCardBrand('visa')).toEqual "visa"
