import { Stripe } from "@stripe/stripe-js";

declare global {
  interface Window {
    __gumroadStripeTestCard?: { number: string; zipCode: string | null };
  }
}

type StripeCreatePaymentMethod = (...args: unknown[]) => unknown;

type TestCard = {
  paymentMethodId: string;
  country: string;
  brand?: string;
  funding?: string;
};

const TEST_CARDS: Record<string, TestCard> = {
  "4242424242424242": { paymentMethodId: "pm_card_visa", country: "US" },
  "4000002500003155": { paymentMethodId: "pm_card_threeDSecure2Required", country: "US" },
  "4000003560000123": { paymentMethodId: "pm_card_indiaRecurringMandateSetupAndRenewalsSuccess", country: "IN" },
  "4000003560000263": { paymentMethodId: "pm_card_indiaRecurringPaymentFailureCanceledMandate", country: "IN" },
  "4000000000000069": { paymentMethodId: "pm_card_chargeDeclinedExpiredCard", country: "US" },
  "4000000000009995": { paymentMethodId: "pm_card_chargeDeclinedInsufficientFunds", country: "US" },
  "4000000000000127": { paymentMethodId: "pm_card_chargeDeclinedIncorrectCvc", country: "US" },
  "4000000000000119": { paymentMethodId: "pm_card_chargeDeclinedProcessingError", country: "US" },
  "4000000000000002": { paymentMethodId: "pm_card_chargeDeclined", country: "US" },
  "4000000000000341": { paymentMethodId: "pm_card_chargeDeclined", country: "US" },
};

const COUNTRY_BY_ISO_NUMERIC: Record<string, string> = {
  "036": "AU",
  "040": "AT",
  "124": "CA",
  "158": "TW",
  "203": "CZ",
  "356": "IN",
  "380": "IT",
  "428": "LV",
  "484": "MX",
  "702": "SG",
};

const getTestCard = (number: string): TestCard => {
  const configured = TEST_CARDS[number];
  if (configured) return configured;

  return { paymentMethodId: "pm_card_visa", country: COUNTRY_BY_ISO_NUMERIC[number.slice(6, 9)] ?? "US" };
};

const getBillingDetails = (params: unknown) => {
  if (typeof params !== "object" || params === null || !("billing_details" in params)) return null;
  const { billing_details } = params as { billing_details?: unknown };
  return typeof billing_details === "object" && billing_details !== null ? billing_details : null;
};

const getBillingEmail = (params: unknown) => {
  const billingDetails = getBillingDetails(params);
  if (!billingDetails || !("email" in billingDetails)) return null;
  return typeof billingDetails.email === "string" ? billingDetails.email : null;
};

const getBillingPostalCode = (params: unknown, zipCode: string | null) => {
  if (zipCode) return zipCode;

  const billingDetails = getBillingDetails(params);
  if (!billingDetails || !("address" in billingDetails)) return null;
  const { address } = billingDetails;
  if (typeof address !== "object" || address === null || !("postal_code" in address)) return null;
  return typeof address.postal_code === "string" ? address.postal_code : null;
};

const buildMockPaymentMethodResponse = (params: unknown, card: { number: string; zipCode: string | null }) => {
  const testCard = getTestCard(card.number);
  const last4 = card.number.slice(-4).padStart(4, "0");
  const expYear = new Date().getFullYear() + 1;
  const brand = testCard.brand ?? "visa";

  return {
    paymentMethod: {
      id: testCard.paymentMethodId,
      object: "payment_method",
      type: "card",
      billing_details: {
        address: {
          city: null,
          country: null,
          line1: null,
          line2: null,
          postal_code: getBillingPostalCode(params, card.zipCode),
          state: null,
        },
        email: getBillingEmail(params),
        name: null,
        phone: null,
      },
      card: {
        brand,
        checks: { address_line1_check: null, address_postal_code_check: null, cvc_check: null },
        country: testCard.country,
        exp_month: 12,
        exp_year: expYear,
        fingerprint: `mock_${card.number}`,
        funding: testCard.funding ?? "credit",
        generated_from: null,
        last4,
        networks: { available: [brand], preferred: null },
        three_d_secure_usage: { supported: true },
        wallet: null,
      },
      created: Math.floor(Date.now() / 1000),
      customer: null,
      livemode: false,
      metadata: {},
    },
  };
};

export const mockStripePaymentMethodsForTests = (stripe: Stripe): Stripe => {
  if (process.env.NODE_ENV !== "test") return stripe;

  const originalCreatePaymentMethod = (
    stripe as unknown as { createPaymentMethod: StripeCreatePaymentMethod }
  ).createPaymentMethod.bind(stripe);

  return new Proxy(stripe, {
    get(target, property, receiver) {
      if (property === "createPaymentMethod") {
        return (params: unknown, ...rest: unknown[]) => {
          const testCard = window.__gumroadStripeTestCard;
          if (!testCard?.number) return originalCreatePaymentMethod(params, ...rest);

          return Promise.resolve(buildMockPaymentMethodResponse(params, testCard));
        };
      }

      const value = Reflect.get(target, property, receiver);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });
};
