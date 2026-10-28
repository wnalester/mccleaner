# Security Architecture - McCleaner.app (macOS)
Local app; licence via McCleanerPaymentBackend (Stripe). Distribution via mccleaner.tech.
Trust boundary = anything leaving the user's browser/machine; all secrets stay server-side/local. Fail closed on verification errors.
