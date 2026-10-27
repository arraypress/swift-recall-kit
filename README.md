# Swift Recall Kit

One search across everything said and written on a Mac — Mail, Messages,
WhatsApp, calls, Calendar, Reminders, Notes and Voice Memos — by words, by
person, or both. Read-only, on this Mac: each source is read through its own
library, nothing is sent or kept.

```swift
import RecallKit

let found = try await Recall.search(RecallQuery(text: "boiler", person: "Alex", since: lastMonth))
for hit in found.hits {
    print(hit.date, hit.source, hit.from ?? "", hit.title ?? "", hit.excerpt)
}
found.found     // [.mail: 3, .messages: 7, .whatsapp: 0]
found.skipped   // [notes: notes have no sender]
found.person    // names: ["Alex Rivera"], phones: [...], emails: [...]
```

| Source | Read through | Matched on |
|---|---|---|
| Mail | [swift-apple-mail](https://github.com/arraypress/swift-apple-mail) | subject and sender; with `bodies`, the newest message files too |
| Messages | [swift-apple-messages](https://github.com/arraypress/swift-apple-messages) | the message text, including text Messages keeps only in its rich form |
| WhatsApp | [swift-whatsapp-messages](https://github.com/arraypress/swift-whatsapp-messages) | text, captions, file names and link titles |
| Calls | [swift-call-log](https://github.com/arraypress/swift-call-log) | a person only — "Missed FaceTime video call", "Outgoing call · 12 min" |
| Calendar | [swift-agenda-kit](https://github.com/arraypress/swift-agenda-kit) | title, place, notes and link; a person by invitees and organiser |
| Reminders | swift-agenda-kit | title, notes and link, done ones included |
| Notes | [swift-apple-notes](https://github.com/arraypress/swift-apple-notes) | title and opening lines; with `bodies`, whole notes |
| Voice Memos | [swift-voice-recordings](https://github.com/arraypress/swift-voice-recordings) | title, and what was said in Apple's transcript — with the moment (`at`) |

## A person is every address they have

A phone number or email address is searched as itself. A name is looked up in
Contacts ([swift-contacts](https://github.com/arraypress/swift-contacts)) and
every phone and email of every contact it matches is searched — the Messages
database holds addresses, never names. WhatsApp keeps its own names (the
address book's, the ones people chose for themselves), so its directory is
asked too, and each address is searched with its pair (WhatsApp gives some
people a second, `@lid`, address). Mail is searched by the person's email
addresses, or by name when Contacts has none. Notes have no sender: a person
search skips them, and says so — as do Reminders and Voice Memos. Calls are the
other way round: they hold no words, so only a person search finds them ("when
did Alex last call?"), matched by number (`+44 7700 900123` is `07700 900123`).
An event is a person's when they were invited (by email, or a name holding what
was asked) or organised it.

## Calendar

EventKit has no text search, so a stretch is fetched and filtered: two years
back and one ahead unless the query gives dates — the future counts ("when is
the dentist?"). A repeating event comes back once, the occurrence nearest
today, marked "(repeats)" — a weekly class would otherwise fill the results 150
times over. Calendar and Reminders access is asked for once, on first use.

## Nothing found is not the same as not looked

A source that can't be read — no Full Disk Access, WhatsApp not installed,
Contacts refused — is a `RecallSkip` with its reason, and the rest still
answer. Only when no source can be read does the search throw
(`RecallError.nothingSearched`, every reason listed). `Recall.availability()`
opens each store and closes it again, to say up front what can be read.

## Bodies

Mail's index holds subjects and senders, not bodies, and Spotlight indexes no
mail (measured in swift-apple-mail, which also found two-thirds of an IMAP
mailbox's bodies are not on the Mac at all). With `bodies: true`, the newest
`bodyBudget` candidates (500 by default) are read and searched; those only on
the server are counted in `unreadBodies`, not passed over in silence. Notes are
decoded whole the same way.

## Results

Hits from every source are merged newest first and cut to `limit`; a row found
twice (a person searched by two addresses) counts once, and ties sort by source
then row, so the same search prints the same list. Each hit carries its row in
its own store and its conversation, for opening it with that source's tool,
and an excerpt: about 160 characters around the first match on one line, cut at
word edges with "…", matched ignoring case and accents.

## Tested

The rules are tested with no store opened — excerpts, people, merging, a whole
search over stand-in sources, the mail rules — on invented names and messages:
20 tests, and every rule broken on purpose is caught (18 of 18 mutations).
Checked by hand on a real Mac (read-only, nothing recorded): all eight sources
readable, a common word found across them, an unknown name skipped with each
source's reason.

## Requirements

macOS 15 or later (swift-agenda-kit's floor); Swift 6.2. Reading Messages, Mail
and calls needs Full Disk Access for the app that runs it; names need Contacts
access; Calendar and Reminders their own.

## License

MIT — see [LICENSE](LICENSE).
