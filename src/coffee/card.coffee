require 'jquery.payment'

$ = jQuery
$.card = {}
$.card.fn = {}
$.fn.card = (opts) ->
  $.card.fn.construct.apply(this, opts)

class Card
  template: """
  <div class="card-container">
      <div class="card">
          <div class="front">
                  <div class="logo visa">visa</div>
                  <div class="logo mastercard">MasterCard</div>
                  <div class="logo amex"></div>
                  <div class="logo discover">discover</div>
              <div class="lower">
                  <div class="shiny"></div>
                  <div class="cvc display">••••</div>
                  <div class="number display">•••• •••• •••• ••••</div>
                  <div class="name display">Full name</div>
                  <div class="expiry display">••/••</div>
              </div>
          </div>
          <div class="back">
              <div class="bar"></div>
              <div class="cvc display">•••</div>
              <div class="shiny"></div>
          </div>
      </div>
  </div>
  """
  cardTypes: [
    'maestro',
    'dinersclub',
    'laser',
    'jcb',
    'unionpay',
    'discover',
    'mastercard',
    'amex',
    'visa'
  ]
  defaults:
    formatting: true
    formSelectors:
      numberInput: 'input[name="number"]'
      expiryInput: 'input[name="expiry"]'
      cvcInput: 'input[name="cvc"]'
      nameInput: 'input[name="name"]'
    cardSelectors:
      cardContainer: '.card-container'
      card: '.card'
      numberDisplay: '.number'
      expiryDisplay: '.expiry'
      cvcDisplay: '.cvc'
      nameDisplay: '.name'

  constructor: (el, opts) ->
    @options = $.extend({}, @defaults, opts)
    @$el = if $(el).is('form') then $(el) else $(el).find 'form'

    unless @options.container
      console.log "Please provide a container"
      return

    @$container = $(@options.container)

    @render()
    @attachHandlers()

  render: () ->
    @$container.append(@template)

    $.each @options.cardSelectors, (name, selector) =>
      this["$#{name}"] = @$container.find(selector)

    $.each @options.formSelectors, (name, selector) =>
      this["$#{name}"] = @options[name] || @$el.find(selector)

    if @options.formatting
      @$numberInput.payment('formatCardNumber')
      @$expiryInput.payment('formatCardExpiry')
      @$cvcInput.payment('formatCardCVC')

    if @options.width
      baseWidth = parseInt @$cardContainer.css('width')
      @$cardContainer.css "transform", "scale(#{@options.width / baseWidth})"

    # safari can't handle transparent radial gradient right now
    if navigator and navigator.userAgent
      ua = navigator.userAgent.toLowerCase()
      if ua.indexOf('safari') != -1 and ua.indexOf('chrome') == -1
        @$card.addClass 'no-radial-gradient'

  attachHandlers: () ->
    @$numberInput
      .bindVal(
        @$numberDisplay,
        {
          fill: false,
          filters: validToggler('validateCardNumber')
        }
      )
      .on 'payment.cardType', @handle('setCardType')

    @$expiryInput
      .bindVal(
        @$expiryDisplay,
        {
          filters: [
            (val) -> val.replace /(\s+)/g, '',
            validToggler 'validateCardExpiry'
          ]
        }
      )
      .on 'keydown', @handle('captureTab')

    @$cvcInput
      .bindVal(@$cvcDisplay, validToggler 'validateCardCVC' )
      .on('focus', @handle('flipCard'))
      .on('blur', @handle('flipCard'))

    @$nameInput
      .bindVal @$nameDisplay, { fill: false  }

  handle: (fn) ->
    (e) =>
      $el = $(e.currentTarget)
      args = Array.prototype.slice.call arguments
      args.unshift $el
      @handlers[fn].apply this, args

  handlers:
    setCardType: ($el, e, cardType) ->
      unless @$card.hasClass(cardType)

        @$card.removeClass('unknown')
        @$card.removeClass(@cardTypes.join(' '))

        @$card.addClass(cardType)
        @$card.toggleClass('identified', cardType isnt 'unknown')

    flipCard: ($el, e) ->
      @$card.toggleClass('flipped')

    captureTab: ($el, e) ->
      keyCode = e.keyCode or e.which
      return if keyCode != 9 or e.shiftKey
      val = $el.payment('cardExpiryVal')
      return unless val.month or val.year
      e.preventDefault() if !$.payment.validateCardExpiry(val.month, val.year)

  $.fn.bindVal = (out, opts={}) ->
    opts.fill = opts.fill || false
    opts.filters = opts.filters || []
    opts.filters = [opts.filters] unless opts.filters instanceof Array

    $el = $(this)
    outDefaults = (out.eq(i).text() for o, i in out)

    $el.on 'focus', () ->
      out.addClass 'focused'

    $el.on 'blur', () ->
      out.removeClass 'focused'

    $el.on 'keyup', (e) ->
      val = $el.val()

      for filter in opts.filters
        val = filter(val, $el, out)

      for o, i in out
        if opts.fill
          outVal = val + outDefaults[i].substring(val.length)
        else
          outVal = val or outDefaults[i]

        out.eq(i).text(outVal)

    $el

  validToggler = (validatorName) ->
    return (val, $in, $out) ->
      $out.toggleClass('valid', $.payment[validatorName](val))
      val

$.fn.extend card: (option, args...) ->
  @each ->
    $this = $(this)
    data = $this.data('card')

    if !data
      $this.data 'card', (data = new Card(this, option))
    if typeof option == 'string'
      data[option].apply(data, args)
