# Payment Tracker Privacy Policy (draft)

**Last updated:** 24 October 2026

**Privacy contact:** abhyudoychaki@gmail.com

This draft describes the current local-first implementation. Review it against the final release build before making it public or submitting the app. Publish it at a stable HTTPS URL and use that URL in App Store Connect.

## Information the app handles

Payment Tracker stores transaction details such as amount, transaction time, merchant or person description, category, payment method, and whether a transaction is a card bill payment. When you import a message with an iOS Shortcuts automation, the app parses the text on your device. It stores the parsed transaction description and a one-way SHA-256 fingerprint of the normalized message to prevent duplicate imports; it does not store the full original message body.

For DropSplit, the app stores split amounts and status on the device. If you choose to share a request, it includes the sender name and UPI ID, recipient name, transaction description/category/payment method, transaction and split amounts, and request date. The iOS share sheet sends this request to the destination you choose. The receiving phone stores its own copy. Later settlement changes are not synchronized.

## Where information is stored and shared

Transaction and split records are stored locally using Apple SwiftData. The current app has no account service, app server, cloud synchronization service, advertising SDK, or analytics SDK. iOS device backups may include app data according to the settings on your device.

Payment Tracker does not access the Messages database. Message imports happen only through an automation you configure in Apple Shortcuts. Face ID or device passcode checks are performed by iOS LocalAuthentication; the app receives an authentication result and does not access or store biometric data.

When you share a DropSplit request, information is sent to the recipient or other destination you select in the iOS share sheet. Opening a UPI payment link hands the request to a compatible UPI app; you review and authorize any payment in that app. Payment Tracker does not process payments. Local notifications are created on your device when enabled and permitted by iOS.

## Retention and deletion

Records remain on your device until you remove them using available in-app controls or remove Payment Tracker and its local data from the device. If device backup is enabled, backup retention is managed by Apple and your device settings. A recipient’s copy of a DropSplit request is controlled by that recipient.

## Children and changes

Payment Tracker is a personal finance utility and is not designed to collect information from children. This policy may be updated when app behavior changes; the updated date will be shown above.

## Contact

For privacy questions or requests, contact **abhyudoychaki@gmail.com**.
