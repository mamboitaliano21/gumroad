# frozen_string_literal: true

# Replaces browser-side Stripe.js with a mock that avoids hitting Stripe's CDN
# and API, eliminating rate-limit flakiness from 65 parallel CI shards.
module StripeJsMock
  CARD_NUMBER_TO_TOKEN = {
    "4242424242424242": "tok_visa",
    "4000002500003155": "tok_threeDSecure2Required",
    "4000003560000123": "tok_visa",
    "4000003560000263": "tok_visa",
    "5555555555554444": "tok_mastercard",
    "378282246310005": "tok_amex",
    "6011111111111117": "tok_discover",
    "3056930009020004": "tok_diners",
    "3566002020360505": "tok_jcb",
    "5200828282828210": "tok_mastercard_debit",
    "4000056655665556": "tok_visa_debit",
    "4000000000009995": "tok_visa_chargeDeclined",
    "4000000000000069": "tok_chargeDeclinedExpiredCard",
    "4000000000000127": "tok_visa_chargeDeclinedProcessingError",
    "4000000000000101": "tok_cvcCheckFail",
    "4000000000009235": "tok_radarBlock",
    "4000000000000341": "tok_visa_chargeCustomerFail",
    "4100000000000019": "tok_createDispute",
    "4000000000000077": "tok_bypassPending",
    "4000000000003220": "tok_threeDSecure2Required",
    "4000003800000446": "tok_avsUnchecked",
    "4000000000000028": "tok_avsZipFail"
}.freeze

  SCA_CARDS = ["4000002500003155", "4000003800000446", "4000000000003220"].freeze

  MOCK_SCRIPT = <<~'JSEOF'
    (function() {
      if (window.__STRIPE_MOCK_INSTALLED) return;
      window.__STRIPE_MOCK_INSTALLED = true;

      var __mockCardNumber = '';
      var __mockCardExpiry = '';
      var __mockCardCvc = '';
      var __mockCardZip = '';

      function MockCardElement() {
        this._mounted = false;
        this._listeners = {};
      }

      MockCardElement.prototype.mount = function(el) {
        this._mounted = true;
        var container = typeof el === 'string' ? document.querySelector(el) : el;
        if (!container) return;

        container.innerHTML =
          '<div data-stripe-mock="true" style="display:flex;gap:4px;flex:1">' +
            '<input name="cardnumber" aria-label="Card number" placeholder="Card number" autocomplete="cc-number" style="flex:2;min-width:0" />' +
            '<input name="exp-date" aria-label="MM / YY" placeholder="MM / YY" autocomplete="cc-exp" style="flex:1;min-width:0" />' +
            '<input name="cvc" aria-label="CVC" placeholder="CVC" autocomplete="cc-csc" style="flex:1;min-width:0" />' +
            '<input name="postal" aria-label="ZIP" placeholder="ZIP" autocomplete="postal-code" style="flex:1;min-width:0" />' +
          '</div>';

        var self = this;
        var inputs = container.querySelectorAll('input');
        var fireChange = function() {
          var complete = __mockCardNumber.length >= 15 && __mockCardExpiry.length >= 4 && __mockCardCvc.length >= 3;
          self._emit('change', { complete: complete, error: null, empty: !__mockCardNumber });
        };

        inputs[0].addEventListener('input', function(e) { __mockCardNumber = e.target.value.replace(/\s/g, ''); fireChange(); });
        inputs[1].addEventListener('input', function(e) { __mockCardExpiry = e.target.value.replace(/[^0-9]/g, ''); fireChange(); });
        inputs[2].addEventListener('input', function(e) { __mockCardCvc = e.target.value; fireChange(); });
        inputs[3].addEventListener('input', function(e) { __mockCardZip = e.target.value; });

        var element = this;
        setTimeout(function() { element._emit('ready', element); }, 0);
      };

      MockCardElement.prototype.unmount = function() { this._mounted = false; };
      MockCardElement.prototype.destroy = function() { this._mounted = false; };
      MockCardElement.prototype.on = function(event, handler) {
        if (!this._listeners[event]) this._listeners[event] = [];
        this._listeners[event].push(handler);
      };
      MockCardElement.prototype.off = function(event, handler) {
        if (!this._listeners[event]) return;
        this._listeners[event] = this._listeners[event].filter(function(h) { return h !== handler; });
      };
      MockCardElement.prototype._emit = function(event) {
        var args = Array.prototype.slice.call(arguments, 1);
        (this._listeners[event] || []).forEach(function(h) { h.apply(null, args); });
      };
      MockCardElement.prototype.update = function() {};
      MockCardElement.prototype.focus = function() {};
      MockCardElement.prototype.blur = function() {};
      MockCardElement.prototype.clear = function() {
        __mockCardNumber = ''; __mockCardExpiry = ''; __mockCardCvc = ''; __mockCardZip = '';
      };

      var CARD_TOKENS = {"4242424242424242": "tok_visa", "4000002500003155": "tok_threeDSecure2Required", "4000003560000123": "tok_visa", "4000003560000263": "tok_visa", "5555555555554444": "tok_mastercard", "378282246310005": "tok_amex", "6011111111111117": "tok_discover", "3056930009020004": "tok_diners", "3566002020360505": "tok_jcb", "5200828282828210": "tok_mastercard_debit", "4000056655665556": "tok_visa_debit", "4000000000009995": "tok_visa_chargeDeclined", "4000000000000069": "tok_chargeDeclinedExpiredCard", "4000000000000127": "tok_visa_chargeDeclinedProcessingError", "4000000000000101": "tok_cvcCheckFail", "4000000000009235": "tok_radarBlock", "4000000000000341": "tok_visa_chargeCustomerFail", "4100000000000019": "tok_createDispute", "4000000000000077": "tok_bypassPending", "4000000000003220": "tok_threeDSecure2Required", "4000003800000446": "tok_avsUnchecked", "4000000000000028": "tok_avsZipFail"};
      var SCA_CARDS = ["4000002500003155", "4000003800000446", "4000000000003220"];

      function createPaymentMethodFromServer(cardNumber) {
        var token = CARD_TOKENS[cardNumber] || 'tok_visa';
        var csrfToken = '';
        try { csrfToken = document.querySelector('meta[name=csrf-token]').content; } catch(e) {}

        return fetch('/test_support/stripe/create_payment_method', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken },
          body: JSON.stringify({ token: token })
        })
        .then(function(r) { return r.json(); })
        .then(function(data) {
          if (data.error) {
            return { error: { type: 'card_error', message: data.error.message } };
          }
          return {
            paymentMethod: {
              id: data.id,
              card: data.card,
              billing_details: { address: { postal_code: __mockCardZip } }
            }
          };
        });
      }

      function makeMockStripe(publicKey, opts) {
        return {
          elements: function(options) {
            return {
              create: function(type, opts) { return new MockCardElement(); },
              update: function() {},
              getElement: function(type) { return null; },
              fetchUpdates: function() { return Promise.resolve({}); }
            };
          },
          paymentRequest: function(options) {
            return {
              canMakePayment: function() { return Promise.resolve(null); },
              show: function() {},
              abort: function() {},
              update: function() {},
              on: function() {},
              off: function() {}
            };
          },
          createPaymentMethod: function(params) {
            return createPaymentMethodFromServer(__mockCardNumber);
          },
          createToken: function(card, data) {
            var token = CARD_TOKENS[__mockCardNumber] || 'tok_visa';
            return Promise.resolve({
              token: { id: token, card: { last4: __mockCardNumber.slice(-4), brand: 'visa' } }
            });
          },
          confirmCardPayment: function(clientSecret, data) {
            if (SCA_CARDS.indexOf(__mockCardNumber) !== -1) {
              return new Promise(function(resolve) { showMockScaFrame(resolve); });
            }
            return Promise.resolve({ paymentIntent: { status: 'succeeded' } });
          },
          confirmCardSetup: function(clientSecret, data) {
            if (SCA_CARDS.indexOf(__mockCardNumber) !== -1) {
              return new Promise(function(resolve) { showMockScaFrame(resolve); });
            }
            return Promise.resolve({ setupIntent: { status: 'succeeded' } });
          },
          retrievePaymentIntent: function() {
            return Promise.resolve({ paymentIntent: null });
          },
          handleCardAction: function(clientSecret) {
            return Promise.resolve({ paymentIntent: { status: 'succeeded' } });
          }
        };
      }

      function showMockScaFrame(resolve) {
        var outerFrame = document.createElement('iframe');
        outerFrame.style.cssText = 'position:fixed;top:0;left:0;width:400px;height:400px;z-index:99999;border:2px solid #ccc;background:#fff;';
        outerFrame.srcdoc = '<html><body></body></html>';
        document.body.appendChild(outerFrame);
        outerFrame.setAttribute('src', 'https://js.stripe.com/v3/three-ds-2-challenge-mock');

        setTimeout(function() {
          try {
            var outerDoc = outerFrame.contentDocument;
            var innerFrame = outerDoc.createElement('iframe');
            innerFrame.name = 'challengeFrame';
            innerFrame.style.cssText = 'width:100%;height:100%;border:none;';
            outerDoc.body.appendChild(innerFrame);

            var innerDoc = innerFrame.contentDocument;
            innerDoc.open();
            innerDoc.write('<button>Complete</button><button>Fail</button>');
            innerDoc.close();

            innerDoc.querySelectorAll('button').forEach(function(btn) {
              btn.addEventListener('click', function() {
                var isComplete = btn.textContent === 'Complete';
                outerFrame.remove();
                if (isComplete) {
                  resolve({ paymentIntent: { status: 'succeeded' }, setupIntent: { status: 'succeeded' } });
                } else {
                  resolve({ error: { type: 'card_error', message: 'We are unable to authenticate your payment method. Please choose a different payment method and try again.' } });
                }
              });
            });
          } catch(e) { console.error('SCA mock error:', e); }
        }, 100);
      }

      window.Stripe = makeMockStripe;
    })();
  JSEOF

  def self.inject(page)
    identifier = page.driver.browser.execute_cdp(
      "Page.addScriptToEvaluateOnNewDocument",
      source: MOCK_SCRIPT
    ).fetch("identifier")

    begin
      page.execute_script(MOCK_SCRIPT)
    rescue StandardError
      # Page not loaded yet, CDP script will run on next navigation
    end

    identifier
  end

  def self.clear(page, identifier)
    return unless identifier

    page.driver.browser.execute_cdp(
      "Page.removeScriptToEvaluateOnNewDocument",
      identifier: identifier
    )
  rescue StandardError
    # Browser may already be closed
  end
end

RSpec.configure do |config|
  config.before(:each, js: true) do
    @stripe_mock_identifier = StripeJsMock.inject(page)
  end

  config.after(:each, js: true) do
    StripeJsMock.clear(page, @stripe_mock_identifier)
  end
end
