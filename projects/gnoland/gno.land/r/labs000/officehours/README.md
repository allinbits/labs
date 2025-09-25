# Office Hours Realm 

Welcome! This realm hosts a simple, recurring **online office hours**
session with an option for anyone to **propose topics**

Below is everything you need to view the next session, subscribe to the calendar,
and (optionally) submit a proposal.

------------------------------------------------------------------------

## TL;DR

-   **See next session & propose a topic:** just open the realm's page
    (the default view shows a flyer + proposal form).
-   **Subscribe to the calendar (ICS):** Use the "Download Calendar" button to add this event to your calendar app.
-   **See current config as JSON:** add `?format=json` to the URL.
-   **Pick a specific date:** use the 'Next date' link to view a future date`?date=YYYY-MM-DD`.
-   **Pre-fill a proposal confirmation (from an external form):** add
    `?topic=<CID>&date=YYYY-MM-DD&description=...`.

> Time is handled in **UTC** internally. Dates you pass via `?date=` use
> the `YYYY-MM-DD` format.

------------------------------------------------------------------------

## 1) Viewing the Next Session

Open the realm without any query parameters:

-   You'll see a flyer for the **next scheduled session** (computed from
    the configured weekday and start hour).
-   If a session on that computed date was **cancelled**, the status
    will show as **cancelled**.
-   A **proposal form** appears beneath the flyer so you can suggest a
    discussion topic.

**Optional controls via URL query:**

-   **Pick a date explicitly:**\
    `?date=2025-10-08`\
    The flyer will render for the chosen date at the configured start
    hour (UTC).

------------------------------------------------------------------------

## 2) Subscribing to the Weekly Calendar (ICS)

Subscribe to a recurring ICS feed that mirrors the office hours
schedule:

-   **URL:** use the "Download Calendar" button on the page.
-   Your calendar app will receive a weekly event series with:
    -   The configured **weekday** and **start time (UTC)**
    -   The configured **duration**
    -   Any configured **exception dates** (cancelled sessions) as
        **EXDATE** entries
    -   A bounded range (from the realm's `publishedAt` to a future
        "until" date)

> Tip: If your calendar supports **webcal://**, use the host/URL shown
> on the page. Otherwise, paste the `https://...&render=calendar` link
> directly into your calendar app's "Add by URL" feature.

------------------------------------------------------------------------

## 3) Proposing a Topic

There are **two** easy paths: in-page or via a confirmation link.

### A) In-page proposal form (easiest)

1.  Open the main page (no special query needed).
2.  Fill **Description**.
3.  The **date** will default to the shown session (or choose another
    date via the date radio).
4.  Submit per the instructions shown (wallet button or CLI).

### B) Pre-filled confirmation page (direct link)

If you already know the **topic CID** and date, open a URL like:

    ?topic=<CID>&date=YYYY-MM-DD&description=Your%20short%20pitch

This renders a **confirmation page** with: - The parameters you passed -
A **TxLink button** for Adena Wallet (experimental) - A ready-to-copy
**gnokey CLI command**

> If **description** or **date** is missing/invalid, you'll see a
> caution. Fix the query string and reload.

------------------------------------------------------------------------

## 4) Submitting the Proposal Transaction

### Option 1: Adena Wallet (TxLink button)

-   On the confirmation page, click **"Post Topic"** to open Adena with
    the transaction pre-filled.\
    *Note: Adena support is experimental. Feedback welcome!*

### Option 2: gnokey CLI

Copy the generated command from the confirmation page and replace
`ADDRESS` with your account:

``` bash
gnokey maketx call   -pkgpath "<REALM_PKG_PATH>"   -func "PostTopic"   -args "<CID>"   -args "YYYY-MM-DD"   -args "Your short pitch"   -gas-fee 1000000ugnot   -gas-wanted 5000000   -send ""   -broadcast   -chainid "<CHAIN_ID>"   -remote "tcp://0.0.0.0:26657"   ADDRESS
```

**Parameters** - `CID` --- a **CIDv1** string for the topic object (the
realm validates this). - `YYYY-MM-DD` --- the session date you're
targeting (UTC date). - `description` --- a short explanation or
request.

On success, the realm emits an `officehours-topic` event with your topic
details.

------------------------------------------------------------------------

## 5) Reading the Current Configuration (JSON)

For transparency or integration, add `?format=json` to view the
**current configuration** snapshot:

-   `eventTitle`, `eventDescription`
-   `eventDayOfWeek`, `eventStartHour`, `eventDurationMinutes`
-   `cancelledDates` (list of `YYYY-MM-DD`)
-   `admin` (address of the updating realm)
-   `sequence` (monotonic version number)

Example:

    ?format=json

------------------------------------------------------------------------

## 6) Time & Cancellation Behavior

-   **Time zone:** All session times are computed in **UTC**.
-   **Next session:** If no `?date` is given, the realm picks the
    **next** occurrence of the configured weekday at the configured
    hour.
-   **Cancellation list:** If a computed or selected date appears in
    `cancelledDates`, the session status changes to **EventCancelled**.

------------------------------------------------------------------------

## 7) Troubleshooting

-   **"Invalid date format"** when proposing?\
    Use `YYYY-MM-DD` (e.g., `2025-10-08`).

-   **Proposal form isn't showing?**\
    If the page is rendering a **confirmation** (`?topic=...`) or
    **calendar** (`?render=calendar`) view, the form may not display.
    Remove those query params.

-   **Adena not opening or failing?**\
    Use the **CLI** command shown on the confirmation page.

-   **Calendar not updating?**\
    Some calendar apps cache ICS feeds. Try re-subscribe, or wait for
    the app's refresh interval.

------------------------------------------------------------------------

## 8) For Admins (Realm Owner Only)

> Skip this section if you're just attending or proposing topics.

Only the **admin** (the realm recorded in `officeHours.admin`) can
change configuration. Attempts by others will fail with **"access
denied: only admin can update office hours"**.

### Update keys & expected values

  --------------------------------------------------------------------------------------
Key                      Value format                  Notes
  ------------------------ ----------------------------- -------------------------------
`admin`                  address string                Transfer admin if needed

`eventTitle`             string                        Display name of the session

`eventDescription`       string                        Short description

`eventDayOfWeek`         Sunday\|Monday...\|Saturday   Case-insensitive

`eventStartHour`         `0..23`                       UTC hour

`eventDurationMinutes`   integer `> 0`                 Session length

`cancelledDate`          `YYYY-MM-DD`                  Adds a single cancelled date
--------------------------------------------------------------------------------------

### Calling `Update(...)`

-   The function expects **key/value pairs**:
    `Update(cur, "key1", "val1", "key2", "val2", ...)`
-   On every successful call, **sequence** increments.

**Examples**

-   Set title & weekday:

        Update(cur, "eventTitle", "Office Hours", "eventDayOfWeek", "Wednesday")

-   Set start to 10:00 UTC and 60-minute duration:

        Update(cur, "eventStartHour", "10", "eventDurationMinutes", "60")

-   Cancel a specific date:

        Update(cur, "cancelledDate", "2025-10-08")

-   Transfer admin:

        Update(cur, "admin", "<NEW_ADMIN_ADDRESS>")

> **Note:** Only the keys listed above are valid. Invalid keys or
> malformed values will panic with a helpful message.

------------------------------------------------------------------------

## 9) Integration Tips

-   **Deep links for proposals:** Generate
    `?topic=<CID>&date=YYYY-MM-DD&description=...` URLs from your own
    site or bot to streamline contributions.
-   **External calendars:** Point your community to
    this realm's URL to keep everyone synced automatically.
-   **Event pages:** If you want to link to "the next session"
    dynamically, just link the base route (no params) and let the realm
    compute it.
-   **Banner Support:** If you want to embed this realm in a
    banner or iframe, add `?embed=banner` to show the svg view of the next event.
-   **Thumbnail Support:** If you want to embed this realm as a thumbnail image, add `?embed=thumbnail` to show a logo + link to the next event.

------------------------------------------------------------------------

## 10) FAQ

-   **Q: What's a CID and where do I get one?**\
    A: It's a **content identifier** (CIDv1). If your topic lives in
    another realm or registry, use that object's CID. The realm
    validates CID form.

-   **Q: Can I propose without a wallet?**\
    A: You can view the **confirmation** page without a wallet, but
    submitting the proposal requires sending a transaction (wallet or
    CLI).

-   **Q: Why UTC?**\
    A: Using UTC avoids ambiguity and keeps recurring rules
    deterministic across regions. Your calendar app will localize after
    you subscribe.

------------------------------------------------------------------------

If you run into anything odd, send the exact URL you loaded and the
message you saw. Happy proposing!
