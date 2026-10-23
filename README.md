# Payment Tracker

A privacy-focused, local-first payment tracking application for iOS that helps users manage personal and business finances.

## Features
- **Smart Tracking**: Import validated bank transaction messages through a user-configured iOS Shortcuts Message automation. Transactions save immediately as Uncategorized, without a category prompt.
- **Duplicate Protection**: Normalized message fingerprints prevent the same SMS being saved twice when multiple automations pass it through.
- **Payment Methods**: Recognizes Card, UPI, Cash, and bank transfer where the message indicates a method.
- **Editable Categories**: Add, rename, and remove categories; existing assignments are updated safely.
- **Analytics**: Colorful charts with date ranges, vendor/person search, and category-to-method or method-to-category breakdowns.
- **Face ID**: Require Face ID or the device passcode to open transaction data.
- **Settings**: Configure DropSplit name/UPI, default dashboard range, display currency, and split notifications in Payment Tracker settings or the iPhone Settings app.
- **DropSplit**: Send transaction split requests to another Payment Tracker user through AirDrop, open a prefilled UPI payment, and keep a running balance per person.
- **Local-First**: Transactions and split balances stay on each device. Cloud sync is not implemented.
- **Billing Filter**: Mark imported credit-card bill payments so they stay out of regular spending totals and charts.

## Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Database**: SwiftData (Local persistence)
- **Sync**: CloudKit (Planned)

## Project Structure
- `Sources/Models`: Data models for Payments and Splits.
- `Sources/Views`: SwiftUI views for Dashboard and Analytics.
- `Sources/ViewModels`: Logic for handling transactions.
- `Sources/Services`: Services for SMS scanning and data processing.

## Importing payment messages on iPhone
iOS does not let ordinary apps read the Messages inbox. Create a Personal Automation in Shortcuts with the **Message** trigger, select **Run Immediately**, and pass Shortcut Input to Payment Tracker's **Import Payment Message** action. Enable **Allow Running When Locked** in the shortcut's Info → Privacy options when available. The importer validates that the text contains a completed bank/payment event, saves it as Uncategorized, and uses the import time. The same message will only be saved once, even if more than one automation passes it in. Review transactions later in the app and mark credit-card bill payments from the edit screen. Reversals are treated as income and remain uncategorized. iOS controls automation execution and may delay or prevent a run in some conditions.

## DropSplit MVP
Open **Split payment** from a transaction, add the people sharing it, then AirDrop each person their request. Set your name and UPI ID once in **Settings**. The other person must have Payment Tracker installed and open the received `dropsplit://` link; the request is then added to their **Splits** list and a local notification is requested. Their app can open an installed UPI app with the accumulated amount filled in, or they can mark the balance paid manually. Importing a UPI SMS with an exact matching balance can offer a confirmation button; it never clears a split automatically.

Each phone keeps its own status. AirDrop carries the original request only, so a later “paid” change does not sync to the other phone. UPI payment still requires the payer to review the recipient and amount in their UPI app and authorize it there. iOS notifications depend on the recipient granting notification permission.

## App settings
Open the gear in Payment Tracker to configure your DropSplit name and UPI ID, the default dashboard date range, display currency, and DropSplit notifications. The same preferences are available under **iPhone Settings → Apps → Payment Tracker**. Existing DropSplit profile values are retained. Currency changes formatting only; values are not converted, and UPI payments remain in INR. Face ID or the device passcode remains required to protect app data.
